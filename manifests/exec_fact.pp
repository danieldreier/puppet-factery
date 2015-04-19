# == Define: exec_fact
#
# Defined type to template out facts from simple shell commands
#
# === Parameters
#
# [*param*]
#
define factery::exec_fact (
  $fact_name   = $title,
  $command     = undef,
  $split       = undef,
  $labels      = undef,
  $break_lines = false,
  $first_line  = 0,
  $first_line_as_labels = false,
  ){
  include factery::exec_facts
  $fact_dir = $::settings::factpath.split(":")[0]
  $fact_file = "${fact_dir}/${fact_name}.rb"

  file { $fact_file:
    content => template('factery/exec_fact.rb.erb'),
    mode    => '0755',
    require => Class['factery::exec_facts'],
  }
}
