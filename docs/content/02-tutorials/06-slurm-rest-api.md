+++
title = "f. Slurm REST API 🌀"
weight = 26
+++

Enable the Slurm REST API. Requires Slurm Accounting.

## Step 1 - Setup Slurm Accounting

Slurm Accounting is required to enable the Slurm REST API. Follow the [instructions](https://pcluster.cloud/02-tutorials/02-slurm-accounting.html) to enable Slurm Accounting but **do not begin cluster creation** after completing Step 4.

## Step 2 - Create a Security Group to allow inbound HTTPS traffic

By default, your cluster will not be able to accept incoming HTTPS requests to the REST API. You will need to [create a security group](https://console.aws.amazon.com/ec2/v2/home?#CreateSecurityGroup:) to change this.

1. Under `Security group name`, enter "Slurm REST API" (or another name of your choosing)
2. Ensure `VPC` matches the cluster's VPC
3. Delete any rules that may have been automatically generated
4. Add an inbound rule and select `HTTPS` under `Type` and `Anywhere-IPv4` under `Destination`
5. Click `Create security group`

## Step 3 - Configure your cluster

In your cluster configuration, return to the Head Node section and add your security group. 

Under `Advanced options`, you should have already added a script for Slurm Accounting. In the same multi-runner, click `Add Script` and select `Slurm REST API`.

Create your cluster. Make sure you followed the Slurm Accounting tutorial for the rest of the configuration.

## Step 4 - Test (manually - eventually frontend will be implemented)

Go to [AWS Secrets Manager](https://console.aws.amazon.com/secretsmanager/listsecrets?#). You should see a new secret named `slurm_token_[your-cluster]`. Click on this secret and then select `Retrieve secret value`. Copy the value to your clipboard.

Open up your terminal and run `export SLURM_JWT=[secret_value]`.

Go to your [EC2 Instances](https://console.aws.amazon.com/ec2/v2/home?#Instances:instanceState=running). Find your cluster and copy the corresponding value under `Public IPv4 DNS` to your clipboard.

In your terminal, run `export ip=[public_ipv4_dns]`

In your terminal, run diagnostics on your cluster through the Slurm REST API:  
`curl -H "X-SLURM-USER-NAME:ec2-user" -H "X-SLURM-USER-TOKEN:$SLURM_JWT" https://$ip/slurm/v0.0.36/diag -k`

If your cluster is running Ubuntu, you may need to add the `--http1.1` flag