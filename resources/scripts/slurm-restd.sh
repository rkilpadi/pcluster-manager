#!/bin/bash

set -x
set -e

mkdir -p /tmp/slurm_restd
pushd /tmp/slurm_restd

# Copy Slurm configuration files
source_path=https://raw.githubusercontent.com/aws-samples/pcluster-manager/main/resources/files
files=(slurmrestd.service slurm_restd.rb nginx.conf nginx.repo.erb)
for file in "${files[@]}"
do
    wget -qO- ${source_path}/sacct/${file} > ${file}
done

sudo cinc-client \
  --local-mode \
  --config /etc/chef/client.rb \
  --log_level auto \
  --force-formatter \
  --no-color \
  --chef-zero-port 8889 \
  -j /etc/chef/dna.json \
  -z slurm_restd.rb

set +e