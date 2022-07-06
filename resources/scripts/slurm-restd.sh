#!/bin/bash

set -x
set -e

mkdir -p /tmp/slurm_rest_api
pushd /tmp/slurm_rest_api

# Copy Slurm configuration files
source_path=https://raw.githubusercontent.com/rkilpadi/pcluster-manager/develop/resources/files
files=(slurmrestd.service slurm_rest_api.rb)
for file in "${files[@]}"
do
    wget -qO- ${source_path}/sacct/${file} > ${file}
done

# Add JWT key to controller in StateSaveLocation
StateSaveLocation="/var/spool/slurm.state"
dd if=/dev/random of=${StateSaveLocation}/jwt_hs256.key bs=32 count=1

sudo cinc-client \
  --local-mode \
  --config /etc/chef/client.rb \
  --log_level auto \
  --force-formatter \
  --no-color \
  --chef-zero-port 8889 \
  -j dna_combined.json \
  -z slurm_restd.rb

set +e
