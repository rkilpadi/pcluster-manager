require 'json'
return if node['cluster']['node_type'] != 'HeadNode'

slurm_etc = '/opt/slurm/etc'
state_save_location = '/var/spool/slurm.state'

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
  content ::File.open('/tmp/slurm_restd/slurmrestd.service').read
end

ruby_block 'Add JWT configuration to slurm.conf' do
  block do
    file = Chef::Util::FileEdit.new("#{slurm_etc}/slurm.conf")
    file.insert_line_after_match(/AuthType=*/, "AuthAltTypes=auth/jwt")      
    file.insert_line_after_match(/AuthAltTypes=*/, "AuthAltParameters=jwt_key=#{state_save_location}/jwt_hs256.key")
    file.write_file
  end
  not_if "grep -q auth/jwt #{slurm_etc}/slurm.conf"
end

ruby_block 'Add JWT configuration to slurmdbd.conf' do
  block do
    file = Chef::Util::FileEdit.new("#{slurm_etc}/slurmdbd.conf")
    file.insert_line_after_match(/AuthType=*/, "AuthAltTypes=auth/jwt")      
    file.insert_line_after_match(/AuthAltTypes=*/, "AuthAltParameters=jwt_key=#{state_save_location}/jwt_hs256.key")
    file.write_file
  end
  not_if "grep -q auth/jwt #{slurm_etc}/slurmdbd.conf"
end

service 'slurmrestd' do
  action :start
end

service 'slurmctld' do
  action :restart
end

ruby_block 'Generate JWT token and create/update AWS secret' do
  block do
    jwt_token = shell_out!("/opt/slurm/bin/scontrol token | grep -oP '^SLURM_JWT\\s*\\=\\s*\\K(.+)'").run_command.stdout
    find_cluster = shell_out!("aws secretsmanager list-secrets --filter Key=""name"",Values=slurm_token_#{node['cluster']['stack_name']} --region #{node['cluster']['region']}").run_command.stdout
    if JSON.parse(find_cluster)['SecretList'].empty?
      shell_out!("aws secretsmanager create-secret --name slurm_token_#{node['cluster']['stack_name']} --secret-string \" #{jwt_token} \" --region #{node['cluster']['region']}").run_command
    else
      shell_out!("aws secretsmanager update-secret --secret-id slurm_token_#{node['cluster']['stack_name']} --secret-string \" #{jwt_token} \" --region #{node['cluster']['region']}").run_command
    end
  end
end
