require 'json'
return if node['cluster']['node_type'] != 'HeadNode'

slurm_etc = '/opt/slurm/etc'
state_save_location = '/var/spool/slurm.state'
key_location = state_save_location + '/jwt_hs256.key'
id = 2005

ruby_block 'Create JWT key file' do
  block do
    shell_out!("dd if=/dev/random of=#{key_location} bs=32 count=1")
  end
end

group 'slurmrestd' do
    comment 'slurmrestd group'
    gid id
    system true
end

user 'slurmrestd' do
  comment 'slurmrestd user'
  uid id
  gid id
  home '/home/slurm'
  system true
  shell '/bin/bash'
end

file "#{key_location}" do
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
    file.insert_line_after_match(/AuthType=*/, "AuthAltParameters=jwt_key=#{key_location}")
    file.insert_line_after_match(/AuthType=*/, "AuthAltTypes=auth/jwt")      
    file.write_file
  end
  not_if "grep -q auth/jwt #{slurm_etc}/slurm.conf"
end

ruby_block 'Add JWT configuration to slurmdbd.conf' do
  block do
    file = Chef::Util::FileEdit.new("#{slurm_etc}/slurmdbd.conf")
    file.insert_line_after_match(/AuthType=*/, "AuthAltParameters=jwt_key=#{key_location}")
    file.insert_line_after_match(/AuthType=*/, "AuthAltTypes=auth/jwt")
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
    token_name = "slurm_token_" + node['cluster']['stack_name'] + " --region #{node['cluster']['region']}"
    region_parameter = "--region " + node['cluster']['region']
    jwt_token = shell_out!("/opt/slurm/bin/scontrol token lifespan=9999999999 | grep -oP '^SLURM_JWT\\s*\\=\\s*\\K(.+)'").run_command.stdout
    secrets = shell_out!("aws secretsmanager list-secrets --filter Key=""name"",Values=""#{token_name}"" #{region_parameter} --query ""SecretList""").run_command.stdout
    
    if JSON.parse(secrets).empty?
      shell_out!("aws secretsmanager create-secret --name #{token_name} #{region_parameter} --secret-string #{jwt_token}").run_command
    else
      shell_out!("aws secretsmanager update-secret --secret-id #{token_name} #{region_parameter} --secret-string #{jwt_token}").run_command
    end
  end
end
