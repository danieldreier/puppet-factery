factery::exec_fact { 'foo':
  command => '/usr/bin/uptime',
  split   => ' ',
  labels  => ['field1', 'field2', 'field3'],
}
factery::exec_fact { 'lvs':
  command              => 'lvs',
  split                => ' ',
  break_lines          => true,
  first_line_as_labels => true,
}
factery::exec_fact { 'listening':
  command              => 'netstat -ltnp',
  split                => ' ',
  break_lines          => true,
  first_line           => 1,
  first_line_as_labels => true,
}
