# == Class: factery::exec_facts
#
# Class to provide prerequisities for factery::exec_fact defined type
#
class factery::exec_facts (
  $fact_dir = $::settings::factpath.split(":")[0]
  ) {
  file {$fact_dir:
    ensure => directory
  }
}
