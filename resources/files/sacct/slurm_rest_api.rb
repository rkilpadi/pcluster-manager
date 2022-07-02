require 'json'
return if node['cluster']['node_type'] != 'HeadNode'

# Get Slurm database credentials
secret = JSON.parse(shell_out!("aws secretsmanager get-secret-value --secret-id #{node['slurm_accounting']['secret_id']} --region #{node['cluster']['region']} --query SecretString --output text").stdout)

slurm_etc = '/opt/slurm/etc'
state_save_location = '/var/spool/slurm.state'

default['cluster']['slurm']['restd_user'] = 'slurmrestd'
default['cluster']['slurm']['restd_group'] = node['cluster']['slurm']['restd_user']
default['cluster']['slurm']['restd_user_id'] = node['cluster']['reserved_base_uid'] + 5
default['cluster']['slurm']['restd_group_id'] = node['cluster']['slurm']['restd_user_id']

# TODO set group/user with node attributes:
=begin
# Setup slurm restd group
group node['cluster']['slurm']['restd_group'] do
    comment 'slurm restd group'
    gid node['cluster']['slurm']['restd_group_id']
    system true
end
  
  # Setup slurm restd user
user node['cluster']['slurm']['restd_user'] do
    comment 'slurm restd user'
    uid node['cluster']['slurm']['restd_user_id']
    gid node['cluster']['slurm']['restd_group_id']
    home "/home/#{node['cluster']['slurm']['user']}"
    system true
    shell '/bin/bash'
end
=end
group 'slurmrestd' do
    comment 'slurmrestd group'
    gid '2000'
    system true
    action :create
end

user 'slurmrestd' do
    comment 'slurmrestd user'
    uid '2000'
    gid '2000'
    system true
    action :create
end

file "#{state_save_location}/jwt_hs256.key" do
  owner 'slurm'
  group 'slurm'
  mode '0600'
end

directory "#{state_save_location}" do
  owner 'slurm'
  group 'slurm'
  mode '0755'
end

file '/etc/systemd/system/slurmrestd.service' do
  owner 'slurmrestd'
  group 'slurmrestd'
  mode '0644'
  content ::File.open('/tmp/slurm_rest_api/slurmrestd.service').read
end

ruby_block 'Add JWT configuration to slurm.conf' do
    block do
      file = Chef::Util::FileEdit.new("#{slurm_etc}/slurm.conf")
      file.insert_line_after_match(/AuthType=*/, "AuthAltTypes=auth/jwt")      
      file.insert_line_after_match(/AuthAltTypes=*/, "AuthAltParameters=jwt_key=#{state_save_location}/jwt_hs256.key")
      file.write_file
    end
    not_if "grep -q AuthAlt #{slurm_etc}/slurm.conf"
end

service 'slurmrestd' do
  action :start
end

service 'slurmctld' do
  action :restart
end
