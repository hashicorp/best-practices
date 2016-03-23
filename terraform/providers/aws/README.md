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

Take all instructions from [Setup](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#setup) forward and paste into a new "Issue" on your repository, this will allow you to check items off the list as they're completed and track your progress.

- [ ] [Create a GitHub account](https://github.com/join) or use existing
- [ ] [Fork the best-practices repo](https://github.com/hashicorp/best-practices)
  - [ ] If you're working with a HashiCorp SE, add them as a collaborator on your forked repo
    - "Settings" -> "Collaborators & Teams" -> "Add collaborator"
    - Make sure they have permissions to create "Issues" on the repository
- [ ] [Create an AWS account](https://portal.aws.amazon.com/gp/aws/developer/registration/index.html) or use existing
- [ ] [Generate AWS keys](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-aws-keys)
  - These credentials will need `FullAccess` to EC2, S3, Route53, and IAM in order for Terraform to create all of the resources
  - Depending on your security requirements, keys can be created in AWS IAM specific to their use case (Packer Builds, Terraform Environments, etc.)
- [ ] [Create an Atlas account](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#create-atlas-account)
  - [ ] If you're working with a HashiCorp SE, add them to the "owners" team in your organization
    - You may need to [create a new](https://atlas.hashicorp.com/help/organizations/create) or [migrate an existing](https://atlas.hashicorp.com/help/organizations/migrate) organization
    - If you would not like to add the SE to the owner team, you can alternatively create a new team and make sure that team is added to all appropriate resources
    - [Settings](https://atlas.hashicorp.com/settings) -> Your Organization -> "Teams" -> "Manage" or "Create" -> "Add user"
- [ ] [Generate an Atlas API token](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-atlas-token)

**Note**: Terraform creates real resources in AWS that **cost money**. Don't forget to [destroy](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#terraform-destroy) your PoC environment when finished to avoid unnecessary expenses.

##### Set Local Environment Variables

Set the below environment variables if you'll be using Packer or Terraform locally.

    $ export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
    $ export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
    $ export AWS_DEFAULT_REGION=us-east-1
    $ export ATLAS_USERNAME=YOUR_ORGANIZATION_NAME
    $ export ATLAS_TOKEN=YOUR_ATLAS_TOKEN

> Note: The environment variable `ATLAS_USERNAME` can be set to your individual username or your
organization name in Atlas. Typically, this should be set to your organization name - e.g. _hashicorp_.

### Generate Keys and Certs

There are certain resources in this project that require the use of keys and certs to validate identity, such as Terraform's `remote-exec` provisioners and TLS in Consul/Vault. For the sake of quicker & easier onboarding, we've created a [gen\_key.sh](../../../setup/gen_key.sh) and [gen\_cert.sh](../../../setup/gen_cert.sh) script that can generate these for you.

**Note**: While using this for PoC purposes, these keys and certs should suffice. However, as you start to move your actual applications into this infrastructure, you'll likely want to replace these self-signed certs with certs that are signed by a CA and use keys that are created with your security principles in mind.

- [ ] Generate `site` keys
  - [ ] Run `sh gen_key.sh site` in [setup](../../../setup)
    - If you enter the path of an existing private key as an optional second parameter, it will create a public (`.pub`) key from the existing private (`.pem`) key specified (e.g. `sh gen_key.sh site ~/.ssh/my-existing-private-key.pem`)
    - This will generate a public (`.pub`) and private (`.pem`) key in the [setup/.](../../../setup) directory
- [ ] Generate `site` and `vault` certs
  - [ ] Run `sh gen_cert.sh YOUR_DOMAIN YOUR_COMPANY` in [setup](../../../setup) (e.g. `sh gen_cert.sh hashicorpdemo.com HashiCorp`)
    - If you don't have a domain currently, you can make one up, or grab one from a service like [NameCheap](https://www.namecheap.com/) to do your testing on
    - This will generate 2 certs, one named `site` (external self-signed cert for browsers) and one named `vault` (internal self-signed cert for Consul/Vault TLS), both within the [setup/.](../../../setup) directory
- [ ] Move all keys & certs created here out of the repository and into a secure location
  - No keys or certs should ever be checked into version control

### Create and Configure Artifacts

Use the [New Build Configuration](https://atlas.hashicorp.com/builds/new) tool to create each new Build Configuration below. Enter the names provided **as you go through the checklist** and be sure to leave the **Automatically build on version uploads** and **Connect build configuration to a GitHub repository** boxes _unchecked_ for each.

After creating each Build Configuration, there is some additional configuration you'll need to do. The summary of what will need to be completed for each Build Configuration is below, the relevant values are provided **as you go through the checklist**.

##### Add Environment Variables

- Go into "Variables" in the left navigation of the Build Configuration and set the below Environment Variables with their appropriate values
  - `ATLAS_USERNAME`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`: `us-east-1`

##### Integrate with GitHub

- Go into "Integrations" in the left navigation of the Build Configuration
- Select the `best-practices` GitHub repository you just forked
- Enter `packer` for **Packer Directory**
- Enter the appropriate **Packer template** _(provided below)_ and click **Associate**

##### Queue Build

You can then go to "Builds" in the left navigation of each of the Build Configuration(s) and click **Queue build**, this should create new artifact(s). You'll need to wait for the `base` artifact to be created before you queue any of the child builds as we take advantage of [Base Artifact Variable Injection](https://atlas.hashicorp.com/help/packer/builds/build-environment#base-artifact-variable-injection).

You do **NOT** want to queue builds for `aws-us-east-1-ubuntu-nodejs` because this Build Template will be used by the application. Queueing a build for `aws-us-east-1-ubuntu-nodejs` **will fail** with the error `* Bad source 'app/': stat app/: no such file or directory`.

#### Base Artifact

- [ ] Create `aws-us-east-1-ubuntu-base` Artifact
  - [ ] [Create New Build Configuration](https://atlas.hashicorp.com/builds/new) for `aws-us-east-1-ubuntu-base`
    - **Name**: `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": [Add Environment Variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#add-environment-variables) mentioned above
  - [ ] In "Integrations": [Setup GitHub Integration](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#integrate-with-github) for the `best-practices` repo
    - **Packer directory**: `packer`
    - **Packer template**: `aws/ubuntu/base.json`
- [ ] In "GitHub": [Ingress Packer template](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#trigger-packer-template-ingress)
- [ ] In "Builds": [Click **Queue build**](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#queue-build) to create a new `base` artifact

#### Child Artifacts

**Wait** until the Base Artifact has been created _before_ moving on to the child Build Configurations. These will fail with an error of `* A source_ami must be specified` until the Base Artifact has been created and selected.

For child Build Configurations, there is one additional step you need to take. In "Settings", set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base` for each.

- [ ] Create `aws-us-east-1-ubuntu-consul` Artifact
  - [ ] [Create New Build Configuration](https://atlas.hashicorp.com/builds/new) for `aws-us-east-1-ubuntu-consul`
    - **Name**: `aws-us-east-1-ubuntu-consul`
  - [ ] In "Settings": Set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": [Add Environment Variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#add-environment-variables) mentioned above
  - [ ] In "Integrations": [Setup GitHub Integration](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#integrate-with-github) for the `best-practices` repo
    - **Packer directory**: `packer`
    - **Packer template**: `aws/ubuntu/consul.json`
- [ ] Create `aws-us-east-1-ubuntu-vault` Artifact
  - [ ] [Create New Build Configuration](https://atlas.hashicorp.com/builds/new) for `aws-us-east-1-ubuntu-vault`
    - **Name**: `aws-us-east-1-ubuntu-vault`
  - [ ] In "Settings": Set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": [Add Environment Variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#add-environment-variables) mentioned above
  - [ ] In "Integrations": [Setup GitHub Integration](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#integrate-with-github) for the `best-practices` repo
    - **Packer directory**: `packer`
    - **Packer template**: `aws/ubuntu/vault.json`
- [ ] Create `aws-us-east-1-ubuntu-haproxy` Artifact
  - [ ] [Create New Build Configuration](https://atlas.hashicorp.com/builds/new) for `aws-us-east-1-ubuntu-haproxy`
    - **Name**: `aws-us-east-1-ubuntu-haproxy`
  - [ ] In "Settings": Set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": [Add Environment Variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#add-environment-variables) mentioned above
  - [ ] In "Integrations": [Setup GitHub Integration](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#integrate-with-github) for the `best-practices` repo
    - **Packer directory**: `packer`
    - **Packer template**: `aws/ubuntu/haproxy.json`
- [ ] Create `aws-us-east-1-ubuntu-nodejs` Build Configuration
  - [ ] [Create New Build Configuration](https://atlas.hashicorp.com/builds/new) for `aws-us-east-1-ubuntu-nodejs`
    - **Name**: `aws-us-east-1-ubuntu-nodejs`
  - [ ] In "Settings": Set **Inject artifact ID during build** to `aws-us-east-1-ubuntu-base`
  - [ ] In "Variables": [Add Environment Variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#add-environment-variables) mentioned above
  - [ ] In "Integrations": [Setup GitHub Integration](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#integrate-with-github) for the `best-practices` repo
    - **Packer directory**: `packer`
    - **Packer template**: `aws/ubuntu/nodejs.json`
- [ ] In "GitHub": [Ingress Packer templates](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#trigger-packer-template-ingress)
- [ ] [Click **Queue build**](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#queue-build) in "Builds" for each of the below Build Configurations to create new artifacts for each (remember, we will not do this for `aws-us-east-1-ubuntu-nodejs`)
  - [ ] `aws-us-east-1-ubuntu-consul`
  - [ ] `aws-us-east-1-ubuntu-vault`
  - [ ] `aws-us-east-1-ubuntu-haproxy`

We built artifacts for the `us-east-1` region in this walkthrough. If you'd like to add another region, follow the [Multi-Region](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#multi-region) setup instructions below.

If you decide to update any of the artifact names, be sure those name changes are reflected in your `terraform.tfvars` file(s).

### Deploy a `us-east-1` Node.js Application

- [ ] Fork the [`demo-app-nodejs` repo](https://github.com/hashicorp/demo-app-nodejs)
- [ ] Use the [New Application](https://atlas.hashicorp.com/applications/new) tool to create your Node.js Application
  - [ ] **Choose a name for the application**: `aws-us-east-1-nodejs`
  - [ ] **Compile Application**: checked
  - [ ] **Build Template**: `aws-us-east-1-ubuntu-nodejs`
  - [ ] **Connect application to a GitHub repository**
    - [ ] **GitHub repository**: `demo-app-nodejs`
    - [ ] Leave both **Application directory** and **Application Template** blank

Upload new versions of the application by merging a commit into master from your forked repo. This will upload your latest app code and trigger a Packer build to create a new compiled application artifact.

If you don't have a change to make, you can force an application ingress into Atlas with an empty commit.

    $ git commit --allow-empty -m "Force a change in Atlas"

If you want to create artifacts in other regions, complete these same steps but select a Build Template from the region you'd like.

### Provision the `aws-global` Environment

- [ ] Use the [Import Terraform Configuration from GitHub](https://atlas.hashicorp.com/configurations/import) tool to import the `aws-global` Environment from GitHub
  - [ ] **Name the environment**: `YOUR_ATLAS_ORG/aws-global`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] [`terraform push`](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) your environment to Atlas to set the Terraform variables, the GitHub Ingress does not currently pull in variables
  - [ ] [Set local environment variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#set-local-environment-variables)
  - [ ] From the [root directory](https://github.com/hashicorp/best-practices), navigate to the [`global` folder](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/global): `cd terraform/providers/aws/global/.`
  - [ ] Configure & pull remote state: `terraform remote config -backend-config name=$ATLAS_USERNAME/aws-global`
  - [ ] Get latest modules: `terraform get`
  - [ ] Push to Atlas: `terraform push -name $ATLAS_USERNAME/aws-global -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"`
    - The plan in Atlas **will** fail, this is okay
- [ ] Navigate to the `aws-global` [environment](https://atlas.hashicorp.com/environments)
- [ ] In "Settings": check **Plan on artifact uploads** and click **Save**
- [ ] In "Variables": add the below Environment Variables with appropriate values
  - [ ] `ATLAS_USERNAME`
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] `TF_ATLAS_DIR`: `providers/aws/global`
    - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
- [ ] In "Variables": update all Terraform variables containing the value `REPLACE_IN_ATLAS`
  - [ ] Update `domain` with your domain (e.g. `hashicorpdemo.com`)
    - If you don't have a domain currently, you can make one up, or grab one from a service like [NameCheap](https://www.namecheap.com/) to do your testing on
    - We use this domain to create S3 buckets to host a static website, so if you're making a domain up, try to make it unique to your company to avoid S3 bucket naming conflicts
  - [ ] Update `atlas_username` with your Atlas username
  - [ ] Update `iam_admins` with a comma separated list of users you'd like added to the `admin` group in IAM (e.g. `cameron,jay,jon,kevin`)
    - This is defaulted to a user named `global-admin`
    - Be sure that you don't use a name that already exists in IAM for this AWS account or you will see conflict errors
    - If you don't want any admin users to be created, just leave this blank
- [ ] In "Integrations": under "GitHub Integration" click **Update GitHub settings** to pull the latest configuration from master
- [ ] In "Changes": click **Queue plan** if one has not already been queued, then **Confirm & Apply** to provision the `aws-global` environment

### Provision the `aws-us-east-1-prod` Environment

- [ ] Use the [Import Terraform Configuration from GitHub](https://atlas.hashicorp.com/configurations/import) tool to import the `aws-us-east-1-prod` Environment from GitHub
  - [ ] **Name the environment**: `YOUR_ATLAS_ORG/aws-us-east-1-prod`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] [`terraform push`](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) your environment to Atlas to set the Terraform variables, the GitHub Ingress does not currently pull in variables
  - [ ] [Set local environment variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#set-local-environment-variables)
  - [ ] From the [root directory](https://github.com/hashicorp/best-practices), navigate to the [`us_east_1_prod` folder](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/us_east_1_prod): `cd terraform/providers/aws/us_east_1_prod/.`
  - [ ] Configure & pull remote state: `terraform remote config -backend-config name=$ATLAS_USERNAME/aws-us-east-1-prod`
  - [ ] Get latest modules: `terraform get`
  - [ ] Push to Atlas: `terraform push -name $ATLAS_USERNAME/aws-us-east-1-prod -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"`
    - The plan in Atlas **will** fail, this is okay
- [ ] Navigate to the `aws-us-east-1-prod` [environment](https://atlas.hashicorp.com/environments)
- [ ] In "Settings": check **Plan on artifact uploads** and click **Save**
- [ ] In "Variables": add the below Environment Variables with appropriate values
  - [ ] `ATLAS_USERNAME`
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_DEFAULT_REGION`: `us-east-1`
  - [ ] `TF_ATLAS_DIR`: `providers/aws/us_east_1_prod`
    - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
- [ ] In "Variables": update all Terraform Variables containing the value `REPLACE_IN_ATLAS`, you will use the contents of the keys and certs created in [Generate Keys and Certs](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#generate-keys-and-certs) as values for most of these variables
  - [ ] Update `atlas_token` with your Atlas token
  - [ ] Update `atlas_username` with your Atlas username
  - [ ] Update `site_public_key` with the contents of `site.pub`
  - [ ] Update `site_private_key` with the contents of `site.pem`
  - [ ] Update `site_ssl_cert` with the contents of `site.crt`
  - [ ] Update `site_ssl_key` with the contents of `site.key`
  - [ ] Update `vault_ssl_cert` with the contents of `vault.crt`
  - [ ] Update `vault_ssl_key` with the contents of `vault.key`
- [ ] In "Integrations": under "GitHub Integration" click **Update GitHub settings** to pull the latest configuration from master
- [ ] In "Changes": click **Queue plan** if one has not already been queued, then **Confirm & Apply** to provision the `aws-us-east-1-prod` environment
  - **Note**: You'll likely see an error related to the OpenVPN AMI during the apply, you'll need to follow the link to the AWS Marketplace provided and complete the steps to opt-in to the OpenVPN AMI for the apply to complete successfully
  - On a successful apply, there will be instructions output in a green font that will tell you how to interact with your new infrastructure

This [same process](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#provision-the-aws-us-east-1-staging-environment) can be repeated for the `aws-us-east-1-staging` environment as well as any other regions you would like to deploy infrastructure into. If you are deploying into a new region, be sure you have Artifacts created for it by following the [Multi-Region steps below](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#multi-region).

### Setup Vault

A HA Vault should have already been provisioned, but you'll need to initialize and unseal Vault to make it work. To do so, SSH into each of the newly provisioned Vault instances and follow the below instructions. The output from your apply in Atlas will tell you how to SSH into Vault.

- [ ] Initialize Vault

    `$ vault init | tee /tmp/vault.init > /dev/null`

- [ ] Retrieve the unseal keys and root token from `/tmp/vault.init` and store these in a safe place
- [ ] Shred keys and token once they are stored in a safe place

    `$ shred /tmp/vault.init`

- [ ] Use the unseal keys you just retrieved to unseal Vault

    ```
    $ vault unseal YOUR_UNSEAL_KEY_1
    $ vault unseal YOUR_UNSEAL_KEY_2
    $ vault unseal YOUR_UNSEAL_KEY_3
    ```

- [ ] Authenticate with Vault by entering your root token retrieved earlier

    `$ vault auth`

- [ ] Shred the token

    `$ shred -u -z ~/.vault-token`

After Vault is initialized and unsealed, update the below variable(s) and apply the changes. Next time you deploy your application, you should see the Vault/Consul Template integration working in your Node.js website!

- [ ] In "Variables" of the `aws-us-east-1-prod` environment: Update `vault_token` with the `root-token`
- [ ] Commit a new change (`git commit --allow-empty -m "Force a change in Atlas"`) to your [`demo-app-nodejs` repo](https://github.com/hashicorp/demo-app-nodejs), this should trigger a new "plan" in `aws-us-east-1-prod` after a new artifact is built
- [ ] In "Changes" of the the `aws-us-east-1-prod` environment: Queue a new plan and apply the changes to deploy the new application to see the Vault/Consul Template integration at work

You'll eventually want to [configure Vault](https://vaultproject.io/docs/index.html) specific to your needs and setup appropriate ACLs.

### Multi-Region

If you'd like to expand outside of `us-east-1`, there are a few changes you need to make. We'll use the region `us-west-2` as an example of how to do this.

In the [base.json](../../../packer/aws/ubuntu/base.json) Packer template...

Add a [new variable](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L7) for the new region's AMI and a [new variable](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L10) for the new Build name. Note that the AMI will need to be from the region you intend to use.

```
"us_west_2_ami":   "ami-8ee605bd",
"us_west_2_name":  "aws-us-west-2-ubuntu-base",
```

Add an [additional builder](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L51-L69) for the new region

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

Add an [additional post-processor](https://gist.github.com/bensojona/aeb5976ae4e756e35518#file-base-json-L114-L122) for the new region

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

Once the updates to [base.json](../../../packer/aws/ubuntu/base.json) have been completed and pushed to `master` (this should trigger a new Build Configuration to be sent to Atlas), complete the [Child Artifact](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#child-artifacts) steps with the new region instead of `us-east-1` to build new artifacts in that region.

To deploy these new artifacts...

- Copy the [us\_east\_1\_prod](us_east_1_prod) and [us\_east\_1\_prod](us_east_1_prod) directories into new folders named `us_west_2_prod` and `us_west_2_prod`

In each of the new "us\_west\_2" `terraform.tfvars` files...

- Replace all instances of `us-east-1` with `us-west-2`.
- Update the OpenVPN ami from `ami-5fe36434` to `ami-9fe2f2af`
  - Go to the [OpenVPN Amazon EC2 Appliance (AMI) Quick Start Quide](https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/) to find an OpenVPN AMI for any region
- You may need to update the `azs` variable depending on what the subnets in that region support

Finally, push these new environments to `master` and follow the [same steps](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#provision-the-us-east-1-prod-infrastructure-with-terraform-in-atlas) you completed to deploy your environments in `us-east-1`.

### Terraform Destroy

If you want to destroy the environment, run the following command in the appropriate environment's directory

    $ terraform destroy -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"

There is currently an [issue](https://github.com/hashicorp/terraform/issues/3747) when destroying the `aws_internet_gateway` resource that requires you to run `terraform destroy` a second time as it fails the first.

**Note:** `terraform destroy` deletes real resources, it is important that you take extra precaution when using this command. Verify that you are in the correct environment, verify that you are using the correct keys, and set any extra configuration necessary to prevent someone from accidentally destroying infrastructure.
