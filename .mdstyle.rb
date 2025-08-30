all
rule 'MD003', :style => :setext_with_atx
exclude_rule 'MD004'
exclude_rule 'MD012'
rule "MD013", :tables => false
rule "MD024", :allow_different_nesting => true
rule 'MD025', :level => 2
exclude_rule 'MD026'
exclude_rule 'MD029'
exclude_rule 'MD034'
exclude_rule 'MD041'
# Disable codeblock_style because we use a mix of fenced and indented in the doc
#rule 'MD046', :style => :consistent
exclude_rule 'MD046'
