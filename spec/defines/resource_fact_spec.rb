require 'spec_helper'

describe 'factery::resource_fact', :type => :define do
  let :title do
    'user'
  end
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context "factery::resource_fact class without any parameters" do
          let(:params) {{ }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_concat__fragment('resource_fact_user_user') }
          it { is_expected.to contain_concat('/etc/puppet/resource_facts.yaml') }
        end
      end
    end
  end

end
