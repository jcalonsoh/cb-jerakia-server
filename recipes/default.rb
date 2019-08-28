#
# Cookbook:: jerakia
# Recipe:: default
#
# Copyright:: 2019, The Authors, All Rights Reserved.

%w(yum-utils libcurl-devel gcc unzip centos-release-scl perl-libwww-perl gperftools).each do |pac|
  package(pac) { action :nothing }.run_action(:install)
end

%w(sqlite-devel gcc-c++ unzip).each do |pac|
  package(pac) { action :nothing }.run_action(:install)
end

global_version = '2.6.3'

rbenv_system_install 'system'

rbenv_user_install 'vagrant'

rbenv_ruby global_version do
  user 'vagrant'
  verbose true
end

rbenv_gem 'bundle' do
  user 'vagrant'
  rbenv_version global_version
end

rbenv_gem 'jerakia' do
  version '2.5.0'
  user 'vagrant'
  rbenv_version global_version
end

%w(/etc/jerakia/policy.d /var/lib/jerakia/plugins /var/db/jerakia/common /var/log/jerakia).each do |dir|
  directory dir do
    owner 'vagrant'
    group 'vagrant'
    mode '0755'
    recursive true
  end
end

template '/etc/jerakia/jerakia.yaml' do
  source 'jerakia.yaml.erb'
  owner 'vagrant'
  group 'vagrant'
  mode '0755'
end

template '/etc/jerakia/startup.sh' do
  source 'startup.sh.erb'
  owner 'vagrant'
  group 'vagrant'
  mode '0755'
end

cookbook_file '/etc/jerakia/policy.d/default.rb' do
  source 'policy_default.rb'
  owner 'vagrant'
  group 'vagrant'
  mode '0755'
  action :create
end

cookbook_file '/var/db/jerakia/common/webserver.yaml' do
  source 'sample_webserver.yaml'
  owner 'vagrant'
  group 'vagrant'
  mode '0755'
  action :create
end

consul_version = '1.5.3'

remote_file "#{Chef::Config['file_cache_path']}/consul.zip" do
  source "https://releases.hashicorp.com/consul/#{consul_version}/consul_#{consul_version}_linux_amd64.zip"
  owner 'vagrant'
  group 'vagrant'
  mode '0755'
  action :create
end

execute 'unzip_condul' do
  command <<-EOF
    unzip #{Chef::Config['file_cache_path']}/consul.zip
    chmod +x consul
    mv consul /usr/bin/consul
  EOF
end

%w(/etc/consul.d/server /etc/consul.d/bootstrap /var/consul ).each do |dir|
  directory dir do
    mode '0755'
    recursive true
  end
end

systemd_unit 'consul-server.service' do
  content(Unit: {
            Description: 'Consul Server',
            Requires: 'network.target',
            After: 'network.target',
          },
          Service: {
            Environment: 'GOMAXPROCS=2',
            ExecStart: '/usr/bin/consul agent -server -ui \
              -data-dir=/var/consul \
              -bootstrap-expect=1 \
              -node=vagrant \
              -config-dir=/etc/consul.d/server \
              -client=0.0.0.0 ',
            Restart: 'on-failure',
            ExecReload: '/bin/kill -HUP $MAINPID',
            KillSignal: 'SIGTERM',
          },
          Install: {
            WantedBy: 'multi-user.target',
          })
  action [:create, :enable, :start]
end

systemd_unit 'jerakia-server.service' do
  content(Unit: {
            Description: 'Jerakia Server',
            After: 'consul-server.target',
          },
          Service: {
            Environment: 'RUBYOPT=-W0',
            User: 'vagrant',
            Group: 'vagrant',
            StandardOutput: 'journal',
            ExecStart: '/etc/jerakia/startup.sh',
            Type: 'simple',
            Restart: 'always',
            KillMode: 'process',
            TimeoutSec: 900,
            RestartSec: 900,
          },
          Install: {
            WantedBy: 'multi-user.target',
          })
  verify true
  action [:create, :enable, :start]
end

service "firewalld" do
  action [:stop, :disable]
end
