## Deploy a Best Practices Infrastructure in AWS

This project will deploy an end to end infrastructure in AWS that includes the below resources in `us-east-1`.

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

Take all instructions from [Setup](#setup) on and paste into a new "Issue" on your repository, this will allow you to check items off of the list as they're completed and track your progress.

- [ ] [Create a GitHub account](https://github.com/join) or use existing
- [ ] [Fork the best-practices repo](https://github.com/hashicorp/best-practices)
  - [ ] If you're working with a HashiCorp SE, add them as a collaborator on your forked repo
    - "Settings" -> "Collaborators & Teams" -> "Add collaborator"
- [ ] [Create an AWS account](https://portal.aws.amazon.com/gp/aws/developer/registration/index.html) or use existing
- [ ] [Generate AWS keys](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-aws-keys)
  - Depending on your security requirements, keys can be created in AWS IAM specific to their use case (Packer Builds, Terraform Environments, etc.)
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

There are certain resources in this project that require the use of keys and certs to validate identity such as Terraform's `remote-exec` provisioners and TLS in Consul/Vault. For the sake of quicker & easier onboarding, we've created a [gen\_cert.sh](../../../scripts/gen_cert.sh) and [gen\_key.sh](../../../scripts/gen_key.sh) script that can generate these for you.

**Note**: While your using this for PoC purposes, these keys and certs should suffice. However, as you start to move your actual applications into this infrastructure, you'll likely want to replace these self-signed certs with certs that are signed by a CA and use keys that are created with your security principles in mind.

- [ ] Generate certs
  - [ ] `sh gen_cert.sh YOUR_DOMAIN YOUR_COMPANY` in [scripts](../../../scripts) (e.g. `sh gen_cert.sh hashicorpdemo.com HashiCorp`)
    - This will generate 2 certs, one named `site` (external self-signed cert for browsers) and one named `consul` (internal self-signed cert for Consul/Vault TLS), within the [scripts/.](../../../scripts) directory
- [ ] Generate keys, or use existing (creates `.pub` key from `.pem` file specified)
  - [ ] `sh gen_key.sh site` or `sh gen_key.sh site ~/.ssh/my-existing-private-key.pem` in [scripts](../../../scripts)
    - These will place public and private key in the [scripts/.](../../../scripts) directory
  - [ ] Copy the `site.pem` file into the [terraform/modules/keys/.](../../modules/keys) module
    - **Note**: This is a temporary workaround **that is NOT best practices** until the `key_file` attribute of the `connection` block within `remote-exec` provisioners can accept file contents instead of just file paths, track that issue [here](https://github.com/hashicorp/terraform/pull/3846)
    - For the time being this key will be checked into GitHub, **this is not best practices and should only be done for demo purposes**, this will be updated after the next Terraform release
- [ ] Move all keys & certs created here out of the repo and to a secure location
  - Aside from the workaround mentioned above, no keys or certs should be checked into version control

### Create and Configure Artifacts with Packer in Atlas

Use the [New Build Configuration](https://atlas.hashicorp.com/builds/new) tool to create your Builds. Leave the **Automatically build on version uploads** box unchecked.

After creating each build configuration, there is some additional configuration you'll need to do.

Add environment variables...

- Go into "Variables" in the left navigation of the Build Configuration
  - `ATLAS_USERNAME`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`

Integrate with GitHub...

- Go into "Integrations" in the left navigation of the Build Configuration
- Select the `best-practices` GitHub repository you just forked
- Leave **Packer Directory** blank
- Enter the **Packer template** provided and click **Associate**

Once configuration is complete in all of your Build Configurations (Base and Child), commit to the `master` branch in your repository (`git commit --allow-empty -m "Force a change in Atlas"`). This will trigger Atlas to ingress the Packer templates from GitHub.

You can then go to "Builds" in the left navigation of each of the Build Configrations (except `aws-us-east-1-ubuntu-nodejs`) and click **Queue build**, this should successfully create a new artifact for each of your Build Configurations.

#### Base Artifact

- [ ] Create `aws-ubuntu-base` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-ubuntu-base`
  - [ ] In "Variables": Add environment variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/base.json`
- [ ] Commit to the `master` branch in your repository (`git commit --allow-empty -m "Force a change in Atlas"`) so Atlas ingresses the Packer templates from GitHub
- [ ] In "Builds": Click **Queue build** to create a new `base` artifact

#### Child Artifacts

Wait until the Base Artifact has been created before moving on to the child Build Configurations. These will fail with an error of `* A source_ami must be specified` until the Base Artifact has been created.

For child Build Configurations there is one additional step you need to take. In "Settings", set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base` for each.

- [ ] Create `aws-us-east-1-ubuntu-consul` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-consul`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": Add environment variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/consul.json`
- [ ] Create `aws-us-east-1-ubuntu-vault` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-vault`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": Add environment variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/vault.json`
- [ ] Create `aws-us-east-1-ubuntu-haproxy` Artifact
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-haproxy`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": Add environment variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/haproxy.json`
- [ ] Update `aws-us-east-1-ubuntu-nodejs` Build Configuration
  - [ ] [Create Build Configuration](https://atlas.hashicorp.com/builds/new): `aws-us-east-1-ubuntu-nodejs`
  - [ ] In "Settings": Set **Inject artifact ID during build**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": Add environment variables
    - [ ] `ATLAS_USERNAME`
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
    - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] In "Integrations": Setup GitHub Integration
    - **GitHub repository**: `best-practices`
    - **Packer template**: `packer/aws/ubuntu/nodejs.json`
  - Do **NOT** queue a new build, this Build Template will be used by your application
    - Queueing a build here **will fail** with the error `* Bad source 'app/': stat app/: no such file or directory`
- [ ] Commit to the `master` branch in your repository (`git commit --allow-empty -m "Force a change in Atlas"`) so Atlas ingresses the Packer templates from GitHub
- [ ] In "Builds": Click **Queue build** for each of the build configurations (except `aws-us-east-1-ubuntu-nodejs`) to create new artifacts for each.

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
    - [ ] `TF_ATLAS_DIR`: `providers/aws/global`
      - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
  - [ ] In "Variables": update all Terraform variables containing the value `REPLACE_IN_ATLAS`
    - [ ] Update `domain` with your domain (e.g. `hashicorpdemo.com`)
      - If you don't have a domain currently, you can make one up, or grab one from a service like [NameCheap](https://www.namecheap.com/) to do your testing on
      - We use this domain to create S3 buckets to host a static website, so if you're making a domain up, try to make it unique to your company to avoid S3 bucket naming conflicts
    - [ ] Update `admins` with a comma separated list of users you'd like added to the `admin` group in IAM (e.g. `cameron,jay,jon,kevin`)
      - Be sure that you don't use a name that already exists in IAM for this AWS account or you will see conflict errors
      - If you don't want any admin users to be created, just leave this field blank
  - [ ] Commit to the `master` branch in your repository (`git commit --allow-empty -m "Force a change in Atlas"`) so Atlas ingresses the Terraform templates from GitHub
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
    - [ ] `TF_ATLAS_DIR`: `providers/aws/us_east_1_staging`
      - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
  - [ ] In "Variables": update all Terraform variables containing the value `REPLACE_IN_ATLAS`, you will use the contents of the keys and certs created in [Generate Keys and Certs](#generate-keys-and-certs) as values for most of these variables
    - [ ] Update `atlas_token` with your Atlas token
    - [ ] Update `atlas_username` with your Atlas username
    - [ ] Update `site_public_key` with the contents of `site.pub`
    - [ ] Update `site_private_key` with the contents of `site.pem`
    - [ ] Update `site_ssl_cert` with the contents of `site.crt`
    - [ ] Update `site_ssl_key` with the contents of `site.key`
    - [ ] Update `vault_ssl_cert` with the contents of `vault.crt`
    - [ ] Update `vault_ssl_key` with the contents of `vault.key`
  - [ ] Commit to the `master` branch in your repository (`git commit --allow-empty -m "Force a change in Atlas"`) so Atlas ingresses the Terraform templates from GitHub
  - [ ] In "Changes": click **Queue plan** then `Confirm & Apply` to provision the `aws-us-east-1-staging` environment
    - You may see a notification regarding the OpenVPN AMI during the apply referring you to the AWS Marketplace, you'll need to opt-in to use this AMI for the apply to complete successfully

This [same process](#provision-the-us-east-1-staging-infrastructure-with-terraform-in-atlas) can be repeated for the `aws-us-east-1-production` environment as well as any other regions you would like to deploy infrastructure into. If you are deploying into a new region, be sure you have Artifacts created for it by following the steps [below](#multi-region).

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

### Multi-Region

If you'd like to expand outside of `us-east-1`, there are a few changes you need to make. We'll use the region `us-west-2` as an example of how to do this.

In the [base.json](../../../packer/aws/ubuntu/base.json) Packer template...

- Add a [new variable](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L7) for the new regions AMI and a [new variable](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L10) for the new Build name. Note that the AMI will need to be from the region you intend to use.

```
"us_west_2_ami":   "ami-8ee605bd",
"us_west_2_name":  "aws-us-west-2-ubuntu-base",
```

- Add an [additional builder](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L51-L69)

```
{
  "name":            "aws-us-west-2-ubuntu-base",
  "type":            "amazon-ebs",
  "access_key":      "{{user `aws_access_key`}}",
  "secret_key":      "{{user `aws_secret_key`}}",
  "region":          "us-west-2",
  "vpc_id":          "",
  "subnet_id":       "",
  "source_ami":      "{{user `us_west_2_ami`}}",
  "instance_type":   "t2.micro",
  "ssh_username":    "{{user `ssh_username`}}",
  "ssh_timeout":     "10m",
  "ami_name":        "{{user `us_west_2_name`}} {{timestamp}}",
  "ami_description": "{{user `us_west_2_name`}} AMI",
  "run_tags":        { "ami-create": "{{user `us_west_2_name`}}" },
  "tags":            { "ami": "{{user `us_west_2_name`}}" },
  "ssh_private_ip":  false,
  "associate_public_ip_address": true
}
```

- Add an [additional post-processor](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L114-L122) for the new region.

```
{
  "type": "atlas",
  "only": ["aws-us-west-2-ubuntu-base"],
  "artifact": "{{user `atlas_username`}}/{{user `us_west_2_name`}}",
  "artifact_type": "amazon.image",
  "metadata": {
    "created_at": "{{timestamp}}"
  }
}
```

Once the updates to [base.json](../../../packer/aws/ubuntu/base.json) have been completed and pushed to `master` (this should trigger a new build configuration to be sent to Atlas), complete the [Child Artifact](#child-artifacts) steps with the new region instead of `us-east-1` to build new artifacts in that region.

To deploy these new artifacts...

- Copy the [us\_east\_1\_staging](us_east_1_staging) and [us\_east\_1\_prod](us_east_1_prod) directories into new folders named `us_west_2_staging` and `us_west_2_prod`

In each of the new "us\_west\_2" `terraform.tfvars` files...

- Replace all instances of `us-east-1` with `us-west-2`.
- Update the OpenVPN ami from `ami-5fe36434` to `ami-9fe2f2af`
  - Go [here](https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/) to find an AMI for your region if it's not `us-west-2`
- You may need to update the `azs` variable depending on what the subnets in that region support

Finally, push these new environments to `master` and follow the [same steps](#provision-the-us-east-1-staging-infrastructure-with-terraform-in-atlas) you completed to deploy your environments in `us-east-1`.
