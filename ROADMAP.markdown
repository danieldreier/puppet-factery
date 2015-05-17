#### Factery Roadmap

### Planned Functionality

* sticky facts
* historical facts
* exported files
* exported facts
* key-value store facts
* fact events
* unmanaged resources
* curl facts

#### sticky facts

Normal puppet facts discover system state. Sticky facts assert a state using
a resource. For example, you might use puppetdbquery or exported resources to
discover backend nodes for a load balancer. This works great until one day
somebody stops puppet on the backend nodes, they expire out of puppetdb, and
the load balancer purges all backends. Using sticky facts, you might:

```puppet
# find web servers in puppetdb. This creates an array of ip addresses.
$query_results = query_nodes('Class[Apache]', ipaddress)

# if we find at least three web servers, set a sticky fact to
# save them for a rainy day
if $query_results.count >= 3 {
  sticky_fact {'sticky_webnodes':
    value => $query_results
  }
}

# if the sticky fact has more than 3 members but puppetdb turned up no results
# we can assume something went wrong and we should use the cached sticky facts
if ($query_results.count == 0) and ($::sticky_webnodes.count >= 3) {
  $effective_webnodes = $::sticky_webnodes
} else {
  $effective_webnodes = $query_results
}

# iterate over the web nodes and create load balancer resources
# in reality, you probably want to use 
$effective_webnodes.each |$webnode| {
  haproxy::balancermember { $webnode:
    listening_service => "website",
    ipaddresses       => $webnode,
    ports             => '80',
    # this is incomplete for the sake of brevity
  }
}
```

#### historical facts

Ever wonder if a fact changed recently? This is a more general case of sticky
facts. Let's say you want to know if your SSH key changes.

```puppet
historical_facts {'sshdsakey':
  retain => '2'
}

if $::historical_facts['sshdsakey'].unique.count > 1 {
  exec { 'shameful use of exec':
    command => "You're a terrible sysadmin | mail -s 'sshdsakey changed' root",
  }
}
```

#### Unmanaged resources

Unmanaged resources compares the contents of the `puppet resource` output for a
given resource with the list of those resources in the node's most recent
catalog. This is pretty imperfect because so many resources can't be listed.

However, in conjunction with historical facts, you could generate a list of
new packages which were added outside of puppet, and `ensure => absent` on
them.

It is important to note that the list of managed resources is from the
*previous* puppet run, not the current one, so there will be some edge cases
where this results in unexpected behavior.

#### Exported Facts

Sometimes you just want to share data between nodes.

Example 1:
```puppet
node 'node1' {
  factery::export {'mysql_master'
    value => $::fqdn
  }
}

node 'node2', 'node3' {
  factery_collect('mysql_master')
}
```

On nodes 2 and 3, a `$::mysql_master` fact will become available
which contains the fqdn of node 1 as a string.


Example 2:

```puppet
node 'node1' {
  factery::export {'mysql_role'
    key   => $::certname,
    value => 'master'
  }
  factery_collect('mysql_role')
}

node 'node2', 'node3' {
  factery::export {'mysql_role'
    key   => $::certname,
    value => 'slave'
  }
  factery_collect('mysql_role')
}
```

After puppet runs a few times (no way around this... aside from kvstore facts)
all of the nodes end up with facts like:
```puppet
  $::mysql_role {
    node1 => 'master',
    node2 => 'slave',
    node3 => 'slave',
  }

```
