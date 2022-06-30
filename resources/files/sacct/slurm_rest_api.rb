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
