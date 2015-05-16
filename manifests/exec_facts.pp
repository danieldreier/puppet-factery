# == Class: factery::exec_facts
#
# Class to provide prerequisities for factery::exec_fact defined type
#
class factery::exec_facts {
  $fact_dir = split($::settings::factpath, ':')
  file {$fact_dir[0]:
    ensure => directory
  }
}
