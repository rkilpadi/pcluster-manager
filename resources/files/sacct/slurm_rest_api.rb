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

group node['cluster']['slurmrestd']['group'] do
    comment 'slurmrestd group'
    gid node['cluster']['slurmrestd']['group']
    system true
    action :create
end

user node['cluster']['slurmrestd']['user'] do
    comment 'slurmrestd user'
    uid node['cluster']['slurmrestd']['user_id']
    gid node['cluster']['slurmrestd']['group_id']
    system true
    action :create
end

file '/etc/systemd/system/slurmrestd.service' do
  owner 'slurmrestd'
  group 'slurmrestd'
  mode '0644'
  content ::File.open('/tmp/slurm_rest_api/slurmrestd.service').read
end

ruby_block 'add slurm accounting to slurm.conf' do
  block do
    file = Chef::Util::FileEdit.new("#{slurm_etc}/slurm.conf")
    file.insert_line_if_no_match('/include slurm_sacct.conf/', 'include slurm_sacct.conf')
    file.write_file
  end
  not_if "grep -q slurm_sacct.conf #{slurm_etc}/slurm.conf"
end

ruby_block 'Update name of cluster in slurm to that of the cluster name' do
  block do
    file = Chef::Util::FileEdit.new("#{slurm_etc}/slurm.conf")
    file.search_file_replace_line(/ClusterName=.*/, "ClusterName=#{node['cluster']['stack_name']}")
    file.write_file
  end
end

file '/var/spool/slurm.state/clustername' do
  action :delete
  only_if { File.exist? '/var/spool/slurm.state/clustername' }
end

service 'slurmrestd' do
  action :start
end

service 'slurmctld' do
  action :restart
end
