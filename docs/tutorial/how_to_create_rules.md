# context

In this section, i will create a new paitr of rules (B015/T015).

Let say we want to fix issue [#19](https://github.com/pmpetit/pglinter/issues/19), about odd triggers.

here is a trigger definition i saw few time ago

```sql
CREATE OR REPLACE FUNCTION odd.trigger_odd_revision_event()
    RETURNS trigger
    LANGUAGE plpgsql
AS $function$
DECLARE
    event_payload  JSONB;
    odd_ids varchar;
    id_odd int8;

BEGIN
    odd_ids := NULL;

    IF (UPPER(TG_TABLE_NAME) = 'T1') THEN
        select STRING_AGG(NEW.id::TEXT, ',' ) into odd_ids;
    END IF;
    IF (UPPER(TG_TABLE_NAME) = 'T2') THEN
        select STRING_AGG(distinct id::TEXT, ',' ) into odd_ids
        from (
                 select distinct b.id
                 from t1 b
                          inner join t4 lpm on lpm.id_surface = b.surface_id
                 where lpm.id_item_concept = NEW.id
                 union
                 select distinct b.id
                 from t1 b
                          inner join t2 pm on pm.parent_item_conception_id = b.item_id
                 where pm.id=NEW.id and b.surface_id is null
             ) as all_odds;
    END IF;
    IF (UPPER(TG_TABLE_NAME) = 'T3') THEN
        select STRING_AGG(distinct id::TEXT, ',' ) into odd_ids
        from (
                 select distinct b.id
                 from t1 b
                          inner join t4 lpm on lpm.id_surface = b.surface_id
                          inner join t2 pm on pm.id = lpm.id_item_concept
                          inner join t3 pa on (pa.id = NEW.id and pm.id = pa.parent_item_concept_id)
                 union
                 select distinct b.id
                 from t1 b
                          inner join t2 pm on pm.parent_item_conception_id = b.item_id
                          inner join t3 pa on (pa.id = NEW.id and pa.parent_item_concept_id = pm.id)
                 where b.surface_id is null
             ) as all_odds;
    END IF;
    IF (UPPER(TG_TABLE_NAME) = 'T4') THEN
        select STRING_AGG(distinct b.id::TEXT, ',' ) into odd_ids
        from t1 b
        where b.surface_id= COALESCE(NEW.id_surface,OLD.id_surface);
    END IF;

    IF (odd_ids is not null) THEN
        FOREACH id_odd IN array string_to_array(odd_ids::TEXT, ',')
            LOOP
                with concepts_agg_from_surface as (select b.id  as odd_id,
                                                          json_agg(json_build_object(
                                                                  'code', pm.item_code,
                                                                  'items', (select COALESCE(json_agg(json_build_object('code', pa.item_code)), '[]'::json) as items
                                                                            from t3 pa
                                                                            where pa.parent_item_concept_id = pm.id
                                                                            group by pa.parent_item_concept_id))) as concepts
                                                   from t1 b
                                                            inner join t4 lpm on lpm.id_surface = b.surface_id
                                                            inner join t2 pm   on (pm.id = lpm.id_item_concept and pm.parent_item_conception_id = b.item_id)
                                                   where b.id = id_odd
                                                   group by b.id),
                     concepts_agg_from_item as (select b.id as odd_id,
                                                        json_agg(json_build_object(
                                                                'code', pm.item_code,
                                                                'items', (select COALESCE(json_agg(json_build_object('code', pa.item_code)),'[]'::json) as items
                                                                          from t3 pa
                                                                          where pa.parent_item_concept_id = pm.id
                                                                          group by pa.parent_item_concept_id))) as concepts
                                                 from t1 b
                                                          inner join t2 pm on pm.parent_item_conception_id = b.item_id
                                                 where b.id = id_odd
                                                 group by b.id)
                -- objet final
                select jsonb_build_object(
                               'id', b.id,
                               'number', NULL,
                               'status', bs.code,
                               'concepts', (case
                                              when b.surface_id is not null then
                                                  (select COALESCE(m.concepts, '[]'::json) from concepts_agg_from_surface m where b.id = m.odd_id)
                                              else
                                                  (select COALESCE(m.concepts, '[]'::json) from concepts_agg_from_item m where b.id = m.odd_id)
                            end
                                   ),
                               'creation_date', b.creation_date,
                               'update_date', b.update_date,
                               'approval_date', NULL,
                               'comment', NULL,
                               'is_deleted', b.deleted_flag,
                               'creation_user', jsonb_build_object(
                                       'id', b.creation_user_id ,
                                       'name', creation_user.name
                                                ),
                               'update_user', jsonb_build_object(
                                       'id', b.update_user_id ,
                                       'name', update_user.name
                                              ),
                               'approval_user', null
                       )
                INTO event_payload
                from t1 b
                         inner join odd_status bs on bs.id = b.odd_status_id
                         left join fwkuser creation_user on b.creation_user_id = creation_user.userid
                         left join fwkuser update_user on b.update_user_id  = update_user.userid
                where b.id = id_odd;

                INSERT INTO relay_odd_revision_event
                ( creation_date, creator_id, event_status, sent_date, error_id, payload, odd_id, triggered_by)
                VALUES( now(), 'ODD', 'TO_SEND', NULL, NULL, event_payload,id_odd, TG_NAME);
            END LOOP;
    END IF;

    RETURN NULL;
END;
$function$
;
```

According to me this is not a good approach because:

- Versions are complicated to manage (for example v1 is for table T1, if you want to add a new table T2 you must create a version 2 that has no sense with T1.)
- You will have to deal with conflict resolution, each dev will work on the same file.
- Hard to read.

## Create the rules B015 and T015

The rule number will be 15, so we will create B015 (for base checking) and T015 (for table checking)

### B015

This base checking will be use later to create a global indicator of the database health (not implemented for the moment).

#### find the queries

The concept is to compare all tables that have trigger with tables that have the same triggering function.

- q1: will count all tables with trigger.
- q2: will count all tables with the same triggering function.

Then we will compare them to calculate a ratio, and raise warning/critical error message if the ratio is over.

q1 should be

```sql
SELECT
    COUNT(DISTINCT event_object_table) as table_using_trigger
FROM
    information_schema.triggers t
WHERE
    t.trigger_schema NOT IN (
    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
)
```

q2 should be

```sql
SELECT
    COUNT(DISTINCT t.event_object_table) AS table_using_same_trigger
FROM (
    SELECT
        t.event_object_table ,
        -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
        'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
    )
) t
GROUP BY
    t.trigger_function_name
HAVING
    COUNT(DISTINCT t.event_object_table) > 1
```

#### update rules.sql for B015

go to sql/rules.sql and add

```sql
INSERT INTO pglinter.rules (
    id,
    name,
    code,
    warning_level,
    error_level,
    scope,
    description,
    message,
    fixes
) VALUES
(
    45, 'HowManyTableSharingSameTrigger', 'B015', 20, 80, 'BASE',
    'Count number of table that use the same trigger vs nb table with their own triggers.',
    '{0}/{1} table(s) using the same trigger function exceed the {2} threshold: {3}%.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
);

-- =============================================================================
-- B015 - Tables With same trigger
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    COALESCE(COUNT(DISTINCT event_object_table), 0)::BIGINT as table_using_trigger
FROM
    information_schema.triggers t
WHERE
    t.trigger_schema NOT IN (
    'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
)
$$
WHERE code = 'B015';

-- =============================================================================
-- B015 - Tables With same trigger
-- =============================================================================
UPDATE pglinter.rules
SET q2 = $$
SELECT
    COALESCE(SUM(shared_table_count), 0)::BIGINT AS table_using_same_trigger
FROM (
    SELECT
        COUNT(DISTINCT t.event_object_table) AS shared_table_count
    FROM (
        SELECT
            t.event_object_table,
            -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
            SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
        FROM
            information_schema.triggers t
        WHERE
            t.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
    ) t
    GROUP BY
        t.trigger_function_name
    HAVING
        COUNT(DISTINCT t.event_object_table) > 1
) shared_triggers
$$
WHERE code = 'B015';

```

### T015

This table check is for dev/ops/dba, that needs to know which table(s) are concerned by this rule, to fix the trouble.

"T" rules (table) do not need any warning or critical threshold, it only returns the message.

That's why T* rules only have one q1 query.

In our case it could be

```sql
SELECT
    t.trigger_schema::text || '.' || t.event_object_table::text ||
    ' shares trigger function ' || t.trigger_function_name::text ||
    ' with other tables' AS problematic_object
FROM (
    SELECT
        t.trigger_schema,
        t.event_object_table,
        -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
) t
WHERE t.trigger_function_name IN (
    -- Subquery to find trigger functions shared by multiple tables
    SELECT
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS shared_function
    FROM
        information_schema.triggers t2
    WHERE
        t2.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
    GROUP BY
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)')
    HAVING
        COUNT(DISTINCT t2.event_object_table) > 1
)
ORDER BY t.trigger_function_name, t.event_object_table
```

#### update rules.sql for T015

so update the sql/rules.sql file with

```sql
(
    32, 'TableSharingSameTrigger', 'T015', 1, 1, 'TABLE',
    'Table shares the same trigger function with other tables.',
    'Table shares trigger function with other tables.',
    ARRAY[
        'For more readability and other considerations use one trigger function per table.',
        'Sharing the same trigger function add more complexity.'
    ]
),
```

and

```sql
-- =============================================================================
-- T015 - Tables Sharing Same Trigger Function
-- =============================================================================
UPDATE pglinter.rules
SET q1 = $$
SELECT
    t.trigger_schema::text || '.' || t.event_object_table::text ||
    ' shares trigger function ' || t.trigger_function_name::text ||
    ' with other tables' AS problematic_object
FROM (
    SELECT
        t.trigger_schema,
        t.event_object_table,
        -- Extracts the function name from the action_statement (e.g., 'public.my_func()')
        SUBSTRING(t.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS trigger_function_name
    FROM
        information_schema.triggers t
    WHERE
        t.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
) t
WHERE t.trigger_function_name IN (
    -- Subquery to find trigger functions shared by multiple tables
    SELECT
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)') AS shared_function
    FROM
        information_schema.triggers t2
    WHERE
        t2.trigger_schema NOT IN (
            'pg_toast', 'pg_catalog', 'information_schema', 'pglinter'
        )
    GROUP BY
        SUBSTRING(t2.action_statement FROM 'EXECUTE FUNCTION ([^()]+)')
    HAVING
        COUNT(DISTINCT t2.event_object_table) > 1
)
ORDER BY t.trigger_function_name, t.event_object_table
$$
WHERE code = 'T015';
```

### regression test

Now create some regress files, where you can raise the rule B015 and T015 message, for example

tests/sql/b015_trigger_sharing.sql

- create 10 tables
  - 5 of them with their own trigger.
  - 3 of them with the same trigger function.
  - 2 without any trigger.

edit the Makefile, to add the test:

```bash
(...)
REGRESS_TESTS+= b015_trigger_sharing
(...)
```

run only this test

```bash
make installcheck REGRESS=b015_trigger_sharing
```

copy the result file

```bash
cp results/b015_trigger_sharing.out tests/expected
```

test all the regress test using

```bash
make install
make installcheck
```
