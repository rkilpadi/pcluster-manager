#!/bin/bash

set -x
set -e

# Set variables from post-install args
secret_id=$1

mkdir -p /tmp/slurm_rest_api
pushd /tmp/slurm_rest_api

cat <<EOF > sacct_attrs.json
{
  "slurm_rest_api": {
  "secret_id": "${secret_id}"}
}
EOF

jq -s '.[0] * .[1]' /etc/chef/dna.json sacct_attrs.json > dna_combined.json

# Copy Slurm configuration files
source_path=https://raw.githubusercontent.com/rkilpadi/pcluster-manager/develop/resources/files
files=(slurmrestd.service slurm_rest_api.rb)
for file in "${files[@]}"
do
    wget -qO- ${source_path}/sacct/${file} > ${file}
done

# Add JWT key to controller in StateSaveLocation
SaveStateLocation=`scontrol show config | grep -oP "^StateSaveLocation\\s*\\=\\s*\\K(.+)"`
dd if=/dev/random of=${StateSaveLocation}/jwt_hs256.key bs=32 count=1

chown slurm:slurm ${StateSaveLocation}/jwt_hs256.key
chmod 0600 ${StateSaveLocation}/jwt_hs256.key
chown slurm:slurm ${StateSaveLocation}
chmod 0755 ${StateSaveLocation}

sudo cinc-client \
  --local-mode \
  --config /etc/chef/client.rb \
  --log_level auto \
  --force-formatter \
  --no-color \
  --chef-zero-port 8889 \
  -j dna_combined.json \
  -z slurm_rest_api.rb

SLURM_JWT=`scontrol token | grep -oP "^SLURM_JWT\\s*\\=\\s*\\K(.+)"`
export $SLURM_JWT
set +e
