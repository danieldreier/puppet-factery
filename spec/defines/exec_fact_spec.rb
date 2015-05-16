require 'spec_helper'

describe 'factery::exec_fact', :type => :define do
  let :title do
    'test'
  end

  before :each do
    Puppet[:parser] = 'future'
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context "factery::exec_fact class with basic parameters" do
          let(:params) {{
            :command              => 'test',
            :split                => ' ',
            :break_lines          => true,
            :first_line_as_labels => true,
            :labels               => ['foo','bar'] # this is added to the test as a dumb hack to make it work under puppet 3.x
          }}
          it {
            Puppet::Util::Log.level = :debug
            Puppet::Util::Log.newdestination(:console)

            is_expected.to compile.with_all_deps }
        end
      end
    end
  end

end
