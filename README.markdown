#### Factery

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with factery](#setup)
    * [What factery affects](#what-factery-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with factery](#beginning-with-factery)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

Factery provides puppet-based tools for creating and overloading puppet facts.

## Puppet Factery

Factery provides a variety of features you've always wanted, possibly without realizing it:

* resource facts
* sticky facts
* historical facts
* exec_facts (templated facts from arbitrary shell commands)
* exported files
* key-value store facts
* fact events
* unmanaged resources
* curl facts
* exported facts

Sounds cool, huh? It's Puppet 4 / future parser only, so get to work updating
your code.

#### resource facts
Resource facts provide structured facts that described the current state of
resources you can enumerate with the `puppet resource` command. 

If you run `puppet resource mount` on a host, you'll get all the `mount`
resources puppet can discover, not just the ones you defined in a manifest.

What if there's an unmanaged resource you want information about? For example,
say you want to enable the `attr2` mount option if `/` is an XFS filesystem,
but not on EXT4 filesystems, since it's not a valid option. If you just create
a `mount` resource that mounts `/` as XFS with `attr2` enabled it works great
until you run it on a system that has EXT4 `/` and then you can't boot anymore.

For example, to set the `resource` fact to list all mounts and all users:

```puppet
factery::resource_fact { 'mount': }
factery::resource_fact { 'user': }
```

the mounts would be listed in a structured fact something like:

```yaml
{
  "resources": {
    "mount": [
      {
        "name": "/",
        "ensure": "mounted",
        "device": "/dev/mapper/localhost-root",
        "fstype": "ext3",
        "options": "errors=remount-ro",
        "pass": "1",
        "dump": "0",
        "target": "/etc/fstab"
      },
      {
        "name": "/boot",
        "ensure": "mounted",
        "device": "UUID=03f2131a-a980-43ec-9c35-3001f440830c",
        "fstype": "ext2",
        "options": "defaults",
        "pass": "2",
        "dump": "0",
        "target": "/etc/fstab"
      },
      {
        "name": "none",
        "ensure": "unmounted",
        "device": "/dev/mapper/localhost-swap_1",
        "fstype": "swap",
        "options": "sw",
        "pass": "0",
        "dump": "0",
        "target": "/etc/fstab"
      }
    ]
  }
}
```

Thanks to iteration in the puppet 4 DSL, you can iterate over it, figure out
what `/` is mounted as, and perform conditional logic accordingly.

All this data ends up in PuppetDB, so if you track packages with resource facts
you could (for example) use [puppetdbquery](https://github.com/dalen/node-puppetdbquery)
to search for all the nodes that *actually* have openssl installed, not just the
ones that manage it with Puppet.

If you use the excellent [puppetlabs-aws](https://github.com/puppetlabs/puppetlabs-aws)
module, you may have noticed that some AWS resources can be enumerated using
puppet resource but (frustratingly) can't get to that data. For example, say
you'd like to assign an available, unassigned elastic IP to a node. Problem is
that puppet doesn't know what that IP is during the compile, even though puppet
resource shows it. With resource facts, you can simply access the `resources`
structured fact, iterate over the elastic IP resources with puppet 4 iteration,
and pick an unused one.

Do you want to selectively purge resources? For example, perhaps you'd like to
remove AWS ec2 instances that don't conform to a certain tagging standard. You
can't just enable purge on all unmanaged `ec2_instance` resources because
no individual node is aware of all of them, and you're willing to tolerate
manually-provisioned nodes so long as they comply with your tagging rules.

If you track `ec2_instance` resources with factery, and you grok puppet 4
iteration, you're in luck. You can iterate over the `resources['ec2_instance']`
structured fact, select resources that do not include the correct data in the
`tags` parameter, and define new `ec2_instance` resources with those nodes set
to `ensure => absent`.

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

#### Exec facts
Everybody who writes custom facts has a few that do little more than wrap a
common shell command. There's no reason to copy a dozen lines of boilerplate
code anymore:

```puppet
# create a simple load fact of the 15 minute average
# this is equivalent to "cut -d ' ' -f 3 < /proc/loadavg"
factery::execfact {'load_15':
  command => 'cat /proc/loadavg',
  split   => ' ',
  field   => 3,
}

# let's say you want a structured fact that looks something like:
# $::load {
#   '1' => 0.00,
#   '5' => 0.01,
#   '15 => 0.05
# }
factery::execfact {'load':
  command => 'cat /proc/loadavg',
  split   => ' ',
  field   => [1,2,3],
  label   => ['1', '5', '15'],
}

# perhaps we want to know our reverse DNS
factery::execfact {'reversedns':
  command => "dig +short -x $::ipaddress",
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


If your module has a range of functionality (installation, configuration, management, etc.) this is the time to mention it.

## Setup

### What factery affects

* PuppetDB will cry if you're enthusiastic with resource facts
* A list of files, packages, services, or operations that the module will alter, impact, or execute on the system it's installed on.
* This is a great place to stick any warnings.
* Can be in list or paragraph form. 

### Setup Requirements **OPTIONAL**

If your module requires anything extra before setting up (pluginsync enabled, etc.), mention it here. 

### Beginning with factery

The very basic steps needed for a user to get the module up and running. 

If your most recent release breaks compatibility or requires particular steps for upgrading, you may wish to include an additional section here: Upgrading (For an example, see http://forge.puppetlabs.com/puppetlabs/firewall).

## Usage

Put the classes, types, and resources for customizing, configuring, and doing the fancy stuff with your module here. 

## Reference

Here, list the classes, types, providers, facts, etc contained in your module. This section should include all of the under-the-hood workings of your module so people know what the module is touching on their system but don't need to mess with things. (We are working on automating this section!)

## Limitations

This is where you list OS compatibility, version compatibility, etc.

## Development

Since your module is awesome, other users will want to play with it. Let them know what the ground rules for contributing are.

## Release Notes/Contributors/Etc **Optional**

If you aren't using changelog, put your release notes here (though you should consider using changelog). You may also add any additional sections you feel are necessary or important to include here. Please use the `## ` header. 
