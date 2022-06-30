require 'json'
return if node['cluster']['node_type'] != 'HeadNode'

# Get Slurm database credentials
secret = JSON.parse(shell_out!("aws secretsmanager get-secret-value --secret-id #{node['slurm_accounting']['secret_id']} --region #{node['cluster']['region']} --query SecretString --output text").stdout)

slurm_etc = '/opt/slurm/etc'

case node['platform']
when 'ubuntu'
  package 'mysql-client'
when 'amazon', 'centos'
  package 'mysql'
end

# Setup slurm restd group
group node['cluster']['slurm']['restd_group'] do
    comment 'slurm restd group'
    id node['cluster']['slurm']['restd_group_id']
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

file '/etc/systemd/system/slurmrestd.service' do
  owner 'slurmrestd'
  group 'slurmrestd'
  mode '0644'
  content ::File.open('/tmp/slurm_rest_api/slurmrestd.service').read
end

service 'slurmrestd' do
  action :start
end

service 'slurmctld' do
  action :restart
end
