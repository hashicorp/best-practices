# Deploy a Complete Infrastructure in AWS

This project will deploy an end to end infrastructure in AWS that includes the below resources.

- Network
  - VPC
  - Public subnets
  - Private subnets
  - Ephemeral subnets
    - Ephemeral nodes (nodes that are recycled often like ASG nodes), need to be in separate subnets from long-running nodes (like ElastiCache and RDS) because AWS maintains an ARP cache with a semi-long expiration time. So if node A with IP 10.0.0.123 gets terminated, and node B comes in and picks up 10.0.0.123 in a relatively short period of time, the stale ARP cache entry will still be there, so traffic will just fail to reach the new node.
  - NAT
  - OpenVPN
  - Bastion host
- Data
  - Consul cluster
  - Vault HA with Consul backend
- Compute
  - Node.js web app servers
  - HAProxy for load balancing
- DNS

## Prerequisites

- [ ] [Create a GitHub account](https://github.com/join)
- [ ] [Create an AWS account](https://portal.aws.amazon.com/gp/aws/developer/registration/index.html)
- [ ] [Generate AWS keys](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-aws-keys) and set environment variables
  - [ ] `export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID`
  - [ ] `export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY`
  - [ ] `export AWS_DEFAULT_REGION=us-east-1`
- [ ] [Create an Atlas account](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#create-atlas-account) and set the environment variable
  - [ ] `export ATLAS_USERNAME=YOUR_ATLAS_USERNAME`
- [ ] [Generate an Atlas API token](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-atlas-token) and set the environment variable
  - [ ] `export ATLAS_TOKEN=YOUR_ATLAS_TOKEN`

## General Setup

Read the [Getting Started](../../../README.md#getting-started) section first. Be sure to follow all instructions closely, many of these steps require pre/post work to be completed or it won't work.

- [ ] [Fork the best-practices repo](https://github.com/hashicorp/best-practices)
- [ ] Generate certs, these will be placed in the [scripts/.](../../../scripts) directory and will be moved later
  - [ ] `sh gen_cert.sh hashicorpdemo.com site HashiCorp` from [scripts/.](../../../scripts)
  - [ ] `sh gen_cert.sh consul vault HashiCorp` from [scripts/.](../../../scripts)
- [ ] Generate keys, these will be placed in the [scripts/.](../../../scripts) directory and will be moved later
  - [ ] `sh gen_key.sh site` or `sh gen_key.sh site ~/.ssh/my-existing-private-key.pem` from the [scripts/.](../../../scripts) directory

## Create a `us-east-1` Base Artifact with Packer in Atlas

First read the [Building Images with Packer](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#building-images-with-packer) docs.

Then, follow the [Packer base template docs](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#base-packer-templates) to run the below commands.

Remember, all `packer push` commands must be performed in the base directory.

    $ packer push packer/aws/ubuntu/base.json

- [ ] Create the `aws-us-east-1-ubuntu-base` artifact

## Create `us-east-1` Child Artifacts with Packer in Atlas

After your base artifact has been created, push the rest of your `us-east-1` Packer templates that depend on it.

Follow the [Packer child template](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#child-packer-templates) docs to run the below commands.

Remember, all `packer push` commands must be performed in the base directory.

    $ AWS_DEFAULT_REGION=us-east-1 packer push packer/aws/ubuntu/consul.json
    $ AWS_DEFAULT_REGION=us-east-1 packer push packer/aws/ubuntu/vault.json
    $ AWS_DEFAULT_REGION=us-east-1 packer push packer/aws/ubuntu/haproxy.json
    $ AWS_DEFAULT_REGION=us-east-1 packer push packer/aws/ubuntu/nodejs.json

- [ ] Create the `aws-us-east-1-ubuntu-consul` artifact
- [ ] Create the `aws-us-east-1-ubuntu-vault` artifact
- [ ] Create the `aws-us-east-1-ubuntu-haproxy` artifact
- [ ] Upload the `aws-us-east-1-ubuntu-nodejs` build configuration (build is expected to fail)

If you decide to update any of the artifact names, be sure those name changes are reflected in your `terraform.tfvars` file.

If you'd like to create artifacts in other regions, replicate the `us-east-1` builder and post-processor in `base.json`. Be sure the `source_ami` is from the correct region.

## Deploy a `us-east-1` Node.js Application with Atlas

Follow the [Upload Applications](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#upload-applications) docs to ingress and link your application to an associated Build Template following the below steps.

This demo assumes you're using the [GitHub Integration](https://atlas.hashicorp.com/help/applications/uploading#github). If you are unable to do so, you can alternatively use [Vagrant Push](https://atlas.hashicorp.com/help/applications/uploading#vagrant-push) or the [Atlas Upload CLI](https://atlas.hashicorp.com/help/applications/uploading#upload-cli).

- [ ] Fork the [Node.js app repo](https://github.com/hashicorp/demo-app-nodejs)
- [ ] Create a compiled "Application" named `aws-us-east-1-nodejs`
- [ ] Link to the `aws-us-east-1-ubuntu-nodejs` Build Template in "Settings"
- [ ] Using the [GitHub Integration](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#github-integration), select the [Node.js app repo](https://github.com/hashicorp/demo-app-nodejs) GitHub repository you just forked and leave both "Application directory" and "Application Template" blank

Upload new versions of the application by merging a commit into master from the your forked repo. This will upload your latest app code and trigger a Packer build to create a new application artifact.

If you don't have a change to make, you can force an application ingress into Atlas with an empty commit.

    $ git commit --allow-empty -m "Force a change in Atlas"

If you'd like to create artifacts in other regions, complete these same steps with the region of your choice. Make sure that you've added that region as a `builder` and `post-processor` to your `base.json` Packer template.

## Provision the `global` Resources with Terraform

Follow the [Deploy with Terraform docs](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) to run the below commands.

From the base directory, navigate to `terraform/providers/aws/global/.`

    $ cd terraform/providers/aws/aws-global

If this is the first time you have run Terraform in this project, you will need to setup the remote config and download the modules.

If you updated the `atlas_environment` variable in `terraform.tfvars` from `aws-global`, be sure that change is reflected in the below `terraform remote config` and `terraform push` commands.

    $ terraform remote config -backend-config name=$ATLAS_USERNAME/aws-global
    $ terraform get

If everything looks good, run

    $ terraform push -name $ATLAS_USERNAME/aws-global -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"

As mentioned in the [Terraform docs](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform), the initial plan will fail, you'll need to set the below environment variables.

## Provision the `us-east-1` Staging Infrastructure with Terraform in Atlas

Follow the [Deploy with Terraform docs](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) to run the below commands.

From the base directory, navigate to `terraform/providers/aws/us_east_1_staging/.`

    $ cd terraform/providers/aws/us_east_1_staging

If this is the first time you have run Terraform in this project, you will need to setup the remote config and download the modules.

If you updated the `atlas_environment` variable in `terraform.tfvars` from `aws-us-east-1-staging`, be sure that change is reflected in the below `terraform remote config` and `terraform push` commands.

    $ terraform remote config -backend-config name=$ATLAS_USERNAME/aws-us-east-1-staging
    $ terraform get

If everything looks good, run

    $ terraform push -name $ATLAS_USERNAME/aws-us-east-1-staging -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"

As mentioned in the [Terraform docs](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform), the initial plan will fail, you'll need to set the below environment variables.

### Update Environment Variables

- [ ] Set AWS environment vars
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_DEFAULT_REGION`
- [ ] Set Atlas environment vars
  - [ ] `ATLAS_USERNAME`

### Update Terraform Variables

You'll notice that there were a few places in the `terraform.tfvars` file that had a value of `REPLACE_IN_ATLAS`, we'll update those in the Atlas `aws-us-east-1-staging` environment with the certs and keys generated in [General Setup](#general-setup).

- [ ] Update `site_ssl_cert` with the contents of the `site.crt` ssl cert you created with `gen_cert.sh`
- [ ] Update `site_ssl_key` with the contents of the `site.key` ssl key you created with `gen_cert.sh`
- [ ] Update `vault_ssl_cert` with the contents of the `vault.crt` ssl cert you created with `gen_cert.sh`
- [ ] Update `vault_ssl_key` with the contents of the `vault.key` ssl key you created with `gen_cert.sh`
- [ ] Update `site_public_key` with the contents of the `site.pub` public key you created with `gen_key.sh`
- [ ] Update `site_private_key` with the contents of the `site.pem` private key you created with `gen_key.sh`

### Copy Private Key

- [ ] Copy the `site.pem` file into [terraform/modules/keys/.](../../modules/keys)
  - This is a temporary workaround until the `key_file` attribute of the `connection` block within `remote-exec` provisioners can accept file contents instead of just file paths

This same process can be repeated for other regions you've created artifacts for.

## Setup Vault

Initialize Vault

    $ vault init | tee /tmp/vault.init > /dev/null

Retrieve the unseal keys and root token from `/tmp/vault.init` and store these in a safe place.

Once they keys and token are stored in a safe place, run the below to destroy them

    $ shred /tmp/vault.init

Use the unseal keys you just retrieved to unseal Vault

    $ vault unseal YOUR_UNSEAL_KEY_1
    $ vault unseal YOUR_UNSEAL_KEY_2
    $ vault unseal YOUR_UNSEAL_KEY_3

Authenticate with Vault by entering your root token

    $ vault auth YOUR_ROOT_TOKEN

Mount the transit backend

    $ vault mount transit

Shred the token

    $ shred -u -z ~/.vault-token

Now you'll want to [configure Vault](https://vaultproject.io/docs/index.html) specific to your needs.

Update the `vault_token` variable in your Atlas `aws-us-east-1-staging` environment with the `root-token`. Now, next time you deploy, you should see the Vault/Consul Template integration working in your Node.js app!
