Facter.add(:resources) do
  require 'puppet'
  require 'json'
  require 'yaml'
  Puppet::Type.loadall
  resources = {}

  # load config file if it's been put in place
  config_file = File.join(File.dirname(Puppet.settings[:config]),'resource_facts.yaml')
  if File.file?(config_file)
      conf = YAML::load_file(config_file)
      conf = [] if conf == false
  else
    conf = []
  end

  #desired_resource_types = ["mount", "service", "host"]
  # if config is set, restrict resources to the ones listed in the config file
  # otherwise list all resources
  # the second case is needed so that resources can be enumerated on the first
  # puppet run before the config file is created
  if conf.count > 0
    desired_resource_types = conf
  else
    desired_resource_types = nil
  end

  Puppet::Type.eachtype { |type|
    begin
      if desired_resource_types.is_a?(Array)
        next unless desired_resource_types.include? type.name.to_s
      end

      # some types can't be enumerated and I'm not sure how to detect those
      # other types error out if a gem is missing, but we still want to gather
      # as much data as possible
      next if Puppet::Type.type(type.name).instances.count == 0
      resources[type.name.to_s] = Puppet::Type.type(type.name).instances.map {|x| JSON.parse(x.retrieve_resource.to_hash.select {|k, v| v != nil && v != :absent}.to_json)}
    rescue
    end
  }

  setcode do
    resources
  end

  Facter.add(:foo) do
    "bar"
  end

end
