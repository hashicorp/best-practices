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

### Setup

- [ ] [Create a GitHub account](https://github.com/join) or use existing
- [ ] [Fork the best-practices repo](https://github.com/hashicorp/best-practices)
  - [ ] If you're working with a HashiCorp SE, add them as a collaborator on your forked repo
    - "Settings" -> "Collaborators & Teams" -> "Add collaborator"
- [ ] [Create an AWS account](https://portal.aws.amazon.com/gp/aws/developer/registration/index.html) or use existing
- [ ] [Generate AWS keys](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-aws-keys)
- [ ] [Create an Atlas account](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#create-atlas-account)
  - [ ] If you're working with a HashiCorp SE, add them to a team in your organization
    - [Settings](https://atlas.hashicorp.com/settings) -> Your Organization -> "Teams" -> "Manage" or "Create" -> "Add user"
- [ ] [Generate an Atlas API token](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-atlas-token)
- [ ] Ensure your VPC is [setup properly](https://github.com/hashicorp/atlas-examples/blob/master/setup/vpc.md) for Packer builds

Set the below environment variables if you'd like to use Packer & Terraform locally

    $ export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
    $ export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
    $ export AWS_DEFAULT_REGION=us-east-1
    $ export ATLAS_USERNAME=YOUR_ATLAS_USERNAME
    $ export ATLAS_TOKEN=YOUR_ATLAS_TOKEN

### Generate Keys and Certs

- [ ] Generate certs
  - [ ] `sh gen_cert.sh hashicorpdemo.com site HashiCorp` in [scripts](../../../scripts)
  - [ ] `sh gen_cert.sh consul vault HashiCorp` in [scripts](../../../scripts)
    - These will be placed in a folder called `certs` within the [scripts/.](../../../scripts) directory
- [ ] Generate keys
  - [ ] `sh gen_key.sh site` or `sh gen_key.sh site ~/.ssh/my-existing-private-key.pem` in [scripts](../../../scripts)
    - These will be placed in a folder called `keys` within the [scripts/.](../../../scripts) directory
  - [ ] Copy the `site.pem` file into [terraform/modules/keys/.](../../modules/keys)
    - This is a temporary workaround until the `key_file` attribute of the `connection` block within `remote-exec` provisioners can accept file contents instead of just file paths, for the time being this key will be checked into GitHub
- [ ] Move all keys & certs created here out of the repo and to a secure location
  - Aside from the workaround mentioned above, no keys or certs should be checked into version control

### Create and Configure Artifacts with Packer in Atlas

Use the [New Build Configuration](https://atlas.hashicorp.com/builds/new) tool to create your Builds. Leave the **Automatically build on version uploads** box unchecked.

After creating each build configuration, there is some additional configuration you'll need to do.

To integrate with GitHub...

- Go into "Integrations" in the left navigation of the Build Configuration
- Select the `best-practices` GitHub repository you just forked
- Leave **Packer Directory** blank
- Enter the **Packer template** provided and click **Associate**

Once configuration is complete you'll want to go to "Builds" in the left navigation and click **Queue build**, this should successfully create a new artifact.

- [ ] Create `aws-ubuntu-base` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-ubuntu-base`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/base.json`
  - [ ] Queue new build to create artifact in "Builds"

Wait until the Base Artifact has been created before moving on to the child Build Configurations. These will fail with an error of `* A source_ami must be specified` until the Base Artifact has been created.

For child Build Configurations there is one additional step you need to take. In "Settings", set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base` for each.

- [ ] Create `aws-us-east-1-ubuntu-consul` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-consul`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/consul.json`
  - [ ] Queue new build to create artifact in "Builds"
- [ ] Create `aws-us-east-1-ubuntu-vault` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-vault`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/vault.json`
  - [ ] Queue new build to create artifact in "Builds"
- [ ] Create `aws-us-east-1-ubuntu-haproxy` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-haproxy`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/haproxy.json`
  - [ ] Queue new build to create artifact in "Builds"
- [ ] Update `aws-us-east-1-ubuntu-nodejs` Build Configuration
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-nodejs`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/nodejs.json`
  - Do _not_ queue a new build, this Build Template will be used by your application, queueing a build here _will_ fail

We will be building artifacts for the `us-east-1` region in this walkthrough. If you'd like to add another region, simply replicate the `builder` and `post-processor` in the [base.json](../../../packer/aws/ubuntu/base.json) Packer template for the specified region. Be sure the `source_ami` is from the correct region.

If you decide to update any of the artifact names, be sure those name changes are reflected in your `terraform.tfvars` file.

### Deploy a `us-east-1` Node.js Application with Atlas

- [ ] Fork the [`demo-app-nodejs` repo](https://github.com/hashicorp/demo-app-nodejs)
- [ ] Use the [New Application](https://atlas.hashicorp.com/applications/new) tool to create your Node.js Application
  - [ ] **Choose a name for the application**: `aws-us-east-1-nodejs`
  - [ ] **Compile Application**: checked
  - [ ] **Build Template**: `aws-us-east-1-ubuntu-nodejs`
  - [ ] **Connect application to a GitHub repository**
    - [ ] **GitHub repository**: `demo-app-nodejs`
    - [ ] Leave both **Application directory** and **Application Template** blank

Upload new versions of the application by merging a commit into master from the your forked repo. This will upload your latest app code and trigger a Packer build to create a new compiled application artifact.

If you don't have a change to make, you can force an application ingress into Atlas with an empty commit.

    $ git commit --allow-empty -m "Force a change in Atlas"

If you'd like to create artifacts in other regions, complete these same steps but select a Build Template from that region.

### Provision the `global` Resources with Terraform

- [ ] Use the [Terraform Configuration Import](https://atlas.hashicorp.com/configurations/import) tool to import the `aws-global` Environment
  - [ ] **Name the environment**: `aws-global`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] Configure and provision the `aws-global` environment
  - [ ] In "Settings": check **Plan on artifact uploads**, and click `Save`
  - [ ] In "Variables": add the below Environment Variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`
    - [ ] `TF_ATLAS_DIR`: `providers/aws/aws-global`
      - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
  - [ ] In "Changes": click **Queue plan** then **Confirm & Apply** to provision the `aws-global` environment

### Provision the `us-east-1` Staging Infrastructure with Terraform in Atlas


- [ ] Use the [Terraform Configuration Import](https://atlas.hashicorp.com/configurations/import) tool to import the `aws-us-east-1-staging` Environment
  - [ ] **Name the environment**: `aws-us-east-1-staging`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] Configure and provision the `aws-us-east-1-staging` environment
  - [ ] In "Settings": check **Plan on artifact uploads**, and click `Save`
  - [ ] In "Variables": add the below Environment Variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`
    - [ ] `TF_ATLAS_DIR`: `providers/aws/aws-us-east-1-staging`
      - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
  - [ ] In "Variables":  update the keys and certs containing the value `REPLACE_IN_ATLAS` with the certs and keys created in [Generate Keys and Certs](#generate-keys-and-certs).
    - [ ] Update `site_ssl_cert` with the contents of `site.crt`
    - [ ] Update `site_ssl_key` with the contents of `site.key`
    - [ ] Update `vault_ssl_cert` with the contents of `vault.crt`
    - [ ] Update `vault_ssl_key` with the contents of `vault.key`
    - [ ] Update `site_public_key` with the contents of `site.pub`
    - [ ] Update `site_private_key` with the contents of `site.pem`
  - [ ] In "Changes": click **Queue plan** then `Confirm & Apply` to provision the `aws-us-east-1-staging` environment

### Setup Vault

- [ ] Initialize Vault

    $ vault init | tee /tmp/vault.init > /dev/null

- [ ] Retrieve the unseal keys and root token from `/tmp/vault.init` and store these in a safe place
- [ ] Shred keys and token once they are stored in a safe place

    $ shred /tmp/vault.init

- [ ] Use the unseal keys you just retrieved to unseal Vault

    $ vault unseal YOUR_UNSEAL_KEY_1
    $ vault unseal YOUR_UNSEAL_KEY_2
    $ vault unseal YOUR_UNSEAL_KEY_3

- [ ] Authenticate with Vault by entering your root token

    $ vault auth YOUR_ROOT_TOKEN

- [ ] Mount the transit backend

    $ vault mount transit

- [ ] Shred the token

    $ shred -u -z ~/.vault-token

After Vault is initialized and unsealed, update the `vault_token` variable in your Atlas `aws-us-east-1-staging` environment with the `root-token`. Now, next time you deploy, you should see the Vault/Consul Template integration working in your Node.js app!

You'll eventually want to [configure Vault](https://vaultproject.io/docs/index.html) specific to your needs.
