## Deploy a Best Practices Infrastructure in Google Cloud Engine

This project is intended to deploy a complete, end to end, infrastructure in [Google Cloud Engine](cloud.google.com). It includes the templates needed to build, deploy, and manage the included resources. The design of this repository is intended to serve as a set of best practices for GCE, and will evolve as more features are added.

### Management with Atlas

The infrastructure in this repository is designed to be managed through Atlas. All of the build and deployment steps can be done directly in Atlas (see below) with the exception of one build step. This is due to a current [limitation of the way GCE does authentication](https://github.com/mitchellh/packer/issues/2970), and will be fixed soon.

While this repository is designed with Atlas in mind, the principles can be applied to use without management through Atlas.

### Design

- Network
  - Public subnets
  - Private subnets
  - NAT
  - Bastion host
- Data
  - Consul cluster
  - Vault HA with Consul backend
- Compute
  - Node.js web app servers
  - HAProxy for load balancing
- DNS

### Setup

Take all instructions from [Setup](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#setup) forward and paste into a new "Issue" on your repository, this will allow you to check items off the list as they're completed and track your progress.

- [ ] [Create a GitHub account](https://github.com/join) or use existing
- [ ] [Fork the best-practices repo](https://github.com/hashicorp/best-practices)
  - [ ] If you're working with a HashiCorp SE, add them as a collaborator on your forked repo
    - "Settings" -> "Collaborators & Teams" -> "Add collaborator"
    - Make sure they have permissions to create "Issues" on the repository
- [ ] [Create an GCE account](https://console.cloud.google.com/freetrial) or use existing
- [ ] [Create Service Account Credentials](https://cloud.google.com/compute/docs/authentication)
  - A service account will allow you to access other Google Cloud Platform resources from within GCE
  - If needed, you can create multiple service accounts and scope access to a specific service
  - Some commands will need to be run specifically **on** instances within GCE. It will be noted when this is required
  <!---- Remove when packer is fixed https://github.com/hashicorp/roadmap/issues/1533 --->
- [ ] [Create an Atlas account](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#create-atlas-account)
  - [ ] If you're working with a HashiCorp SE, add them to the "owners" team in your organization
    - You may need to [create a new](https://atlas.hashicorp.com/help/organizations/create) or [migrate an existing](https://atlas.hashicorp.com/help/organizations/migrate) organization
    - If you would not like to add the SE to the owner team, you can alternatively create a new team and make sure that team is added to all appropriate resources
    - [Settings](https://atlas.hashicorp.com/settings) -> Your Organization -> "Teams" -> "Manage" or "Create" -> "Add user"
- [ ] [Generate an Atlas API token](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#generate-atlas-token)

**Note**: Terraform creates real resources in GCE that **cost money**. Don't forget to [destroy](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#terraform-destroy) your PoC environment when finished to avoid unnecessary expenses.

##### Set Local Environment Variables

Set the below environment variables if you'll be using Packer or Terraform locally.

    export ATLAS_TOKEN=YOUR_ATLAS_TOKEN
    export GCE_PROJECT_ID=name-of-your-gce-project
    export GCE_DEFAULT_ZONE=default-zone (like us-central1-c)
    export GCE_SOURCE_IMAGE=ubuntu-1404-trusty-v20160314
    export GOOGLE_CREDENTIALS=(The raw JSON of your service account credentials. This is can be downloaded from the GCE portal)
    export ATLAS_USERNAME=atlas-username

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

Due the above mentioned conflict with [GCE authentication and Packer](https://github.com/mitchellh/packer/issues/2970), artifacts will need to be built locally. Ideally, this should be a machine in GCE (to access service account authorizations), but can be any a properly authenticated machine with [`packer`](https://packer.io).

##### Create the Base Artifact
The artifacts in this repository are designed to pull from a common base. Before any subsequent artifacts can be created, this base artifact must be built. It will then be inherited for later builds.

Make sure that you have your environment variables set (see above), and navigate to [packer/](packer/). You must run all `build` commands from here.

Build the `base.json` artifact:
```shell
packer build gce/ubuntu/base.json
```

This will provision a GCE instance and build the required artifact. Once completed, the resulting image will be uploaded to Atlas and stored in the GCE image registry. To check that the image exists you can run:

```shell
gcloud compute images list
```
You should see output like the following:

```shell
packer-gce-us-central1-c-ubuntu-base-1458939727
```

##### Build the Child Artifacts
Now that the base artifact has been built, the child artifacts can be generated. Again, the `build` commands should be run from the same directory.

```shell
packer build gce/ubuntu/consul.json
packer build gce/ubuntu/haproxy.json
packer build gce/ubuntu/vault.json
```

**NOTE**: We are _not_ building `gce/ubuntu/nodejs.json` as this template will be used directly by the application later in the process.

In order for the `nodejs.json` build to be accessible later, it will need to uploaded to Atlas. This can be accomplished with a `packer push`.

```shell
packer push gce/ubuntu/nodejs.json
```

For now there is no build needed.

Once all of these builds complete, the images should be uploaded to Atlas and GCE. You can check with the same method as above.

<!---
ATLAS AUTOBUILDS ARE CURRENT NOT POSSIBLE DUE TO THE PACKER AUTH BUG
https://github.com/mitchellh/packer/issues/2970

Use the [New Build Configuration](https://atlas.hashicorp.com/builds/new) tool to create each new Build Configuration below. Enter the names provided **as you go through the checklist** and be sure to leave the **Automatically build on version uploads** and **Connect build configuration to a GitHub repository** boxes _unchecked_ for each.

After creating each Build Configuration, there is some additional configuration you'll need to do. The summary of what will need to be completed for each Build Configuration is below, the relevant values are provided **as you go through the checklist**.

##### Add Environment Variables

- Go into "Variables" in the left navigation of the Build Configuration and set the below Environment Variables with their appropriate values. These variables should mirror those you set in your environment earlier
  - `ATLAS_USERNAME`
  - `GCE_PROJECT_ID`
  - `GCE_SOURCE_IMAGE`
  - `GCE_DEFAULT_ZONE`: `us-central1-c`
  - `GOOGLE_CREDENTIALS`

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
--->
### Deploy a Node.js Application

**Note**: Artifacts and settings will contain the name of the `zone` they are built/deployed in. The default for this guide is `us-central1-c` but can be changed with the `GCE_DEFAULT_ZONE` environment variable.

- [ ] Fork the [`demo-app-nodejs` repo](https://github.com/hashicorp/demo-app-nodejs)
- [ ] Use the [New Application](https://atlas.hashicorp.com/applications/new) tool to create your Node.js Application
  - [ ] **Choose a name for the application**: `gce-us-central1-c-nodejs`
  - [ ] **Compile Application**: checked
  - [ ] **Build Template**: `gce-us-central1-c-ubuntu-nodejs`
  - [ ] **Connect application to a GitHub repository**
    - [ ] **GitHub repository**: `demo-app-nodejs`
    - [ ] Leave both **Application directory** and **Application Template** blank


Upload new versions of the application by merging a commit into master from your forked repo. This will upload your latest app code and trigger a Packer build to create a new compiled application artifact.

If you don't have a change to make, you can force an application ingress into Atlas with an empty commit.

    $ git commit --allow-empty -m "Force a change in Atlas"

If you want to create artifacts in other zones, complete these same steps but select a Build Template from the region you'd like.

### Provision the `gce-global` Environment

- [ ] Use the [Import Terraform Configuration from GitHub](https://atlas.hashicorp.com/configurations/import) tool to import the `gce-global` Environment from GitHub
  - [ ] **Name the environment**: `YOUR_ATLAS_ORG/gce-global`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] [`terraform push`](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) your environment to Atlas to set the Terraform variables, the GitHub Ingress does not currently pull in variables
  - [ ] [Set local environment variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#set-local-environment-variables)
  - [ ] From the [root directory](https://github.com/hashicorp/best-practices), navigate to the [`global` folder](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/global): `cd terraform/providers/gce/global/.`
  - [ ] Configure & pull remote state: `terraform remote config -backend-config name=$ATLAS_USERNAME/gce-global`
  - [ ] Get latest modules: `terraform get`
  - [ ] Push to Atlas: `terraform push -name $ATLAS_USERNAME/gce-global -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"`
    - The plan in Atlas **will** fail, this is okay
- [ ] Navigate to the `gce-global` [environment](https://atlas.hashicorp.com/environments)
- [ ] In "Settings": check **Plan on artifact uploads** and click **Save**
- [ ] In "Variables": add the below Environment Variables with appropriate values
  - [ ] `ATLAS_USERNAME`
  - [ ] `GCE_PROJECT_ID`
  - [ ] `GCE_DEFAULT_ZONE`
  - [ ] `GCE_SOURCE_IMAGE`
  - [ ] `GOOGLE_CREDENTIALS`
  - [ ] `TF_ATLAS_DIR`: `providers/gce/global`
    - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
- [ ] In "Variables": update all Terraform variables containing the value `REPLACE_IN_ATLAS`
  - [ ] Update `domain` with your domain (e.g. `hashicorpdemo.com`)
    - If you don't have a domain currently, you can make one up, or grab one from a service like [NameCheap](https://www.namecheap.com/) to do your testing on
    - We use this domain to create Google Storage buckets to host a static website, so if you're making a domain up, try to make it unique to your company to avoid Google Storage bucket naming conflicts
  - [ ] Update `atlas_username` with your Atlas username
- [ ] In "Integrations": under "GitHub Integration" click **Update GitHub settings** to pull the latest configuration from master
- [ ] In "Changes": click **Queue plan** if one has not already been queued, then **Confirm & Apply** to provision the `gce-global` environment

### Provision the `prod` Environment

- [ ] Use the [Import Terraform Configuration from GitHub](https://atlas.hashicorp.com/configurations/import) tool to import the `prod` Environment from GitHub
  - [ ] **Name the environment**: `YOUR_ATLAS_ORG/gce-us-central1-c-prod`
  - [ ] **GitHub repository**: `YOUR_GITHUB_USERNAME/best-practices`
  - [ ] **Path to directory of Terraform files**: `terraform`
- [ ] [`terraform push`](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md#deploy-with-terraform) your environment to Atlas to set the Terraform variables, the GitHub Ingress does not currently pull in variables
  - [ ] [Set local environment variables](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#set-local-environment-variables)
  - [ ] From the [root directory](https://github.com/hashicorp/best-practices), navigate to the [`prod` folder](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/us_east_1_prod): `cd terraform/providers/gce/prod/.`
  - [ ] Configure & pull remote state: `terraform remote config -backend-config name=$ATLAS_USERNAME/gce-us-central1-c-prod`
  - [ ] Get latest modules: `terraform get`
  - [ ] Push to Atlas: `terraform push -name $ATLAS_USERNAME/gce-us-central1-c-prod -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"`
    - The plan in Atlas **will** fail, this is okay
- [ ] Navigate to the `gce-us-central1-c-prod` [environment](https://atlas.hashicorp.com/environments)
- [ ] In "Settings": check **Plan on artifact uploads** and click **Save**
- [ ] In "Variables": add the below Environment Variables with appropriate values
  - [ ] `ATLAS_USERNAME`
  - [ ] `GCE_PROJECT_ID`
  - [ ] `GCE_DEFAULT_ZONE`
  - [ ] `GCE_SOURCE_IMAGE`
  - [ ] `GOOGLE_CREDENTIALS`
  - [ ] `TF_ATLAS_DIR`: `providers/gce/prod`
    - Atlas uses the `TF_ATLAS_DIR` variable to identify where it should run Terraform commands within the repo
- [ ] In "Variables": update all Terraform Variables containing the value `REPLACE_IN_ATLAS`, you will use the contents of the keys and certs created in [Generate Keys and Certs](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#generate-keys-and-certs) as values for most of these variables
  - [ ] Update `atlas_token` with your Atlas token
  - [ ] Update `atlas_username` with your Atlas username
  - [ ] Update `site_public_key` with the contents of `site.pub`
  - [ ] Update `site_private_key` with the contents of `site.pem`
  - [ ] Update `site_ssl_cert` with the contents of `site.crt`
  - [ ] Update `site_ssl_key` with the contents of `site.key`
  - [ ] Update `vault_ssl_cert` with the contents of `vault.crt`
  - [ ] Update `vault_ssl_key` with the contents of `vault.key`
- [ ] In "Integrations": under "GitHub Integration" click **Update GitHub settings** to pull the latest configuration from master
- [ ] In "Changes": click **Queue plan** if one has not already been queued, then **Confirm & Apply** to provision the `prod` environment
  - On a successful apply, there will be instructions output in a green font that will tell you how to interact with your new infrastructure

This [same process](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/gce/README.md#provision-the-aws-us-east-1-staging-environment) can be repeated for the `staging` environment as well as any other groups you would like to deploy infrastructure into. If you are deploying into a new group, be sure you have Artifacts created for it by following the [Multi-Region steps below](https://github.com/hashicorp/best-practices/blob/master/terraform/providers/aws/README.md#multi-region).

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

- [ ] In "Variables" of the `prod` environment: Update `vault_token` with the `root-token`
- [ ] Commit a new change (`git commit --allow-empty -m "Force a change in Atlas"`) to your [`demo-app-nodejs` repo](https://github.com/hashicorp/demo-app-nodejs), this should trigger a new "plan" in `prod` after a new artifact is built
- [ ] In "Changes" of the the `prod` environment: Queue a new plan and apply the changes to deploy the new application to see the Vault/Consul Template integration at work

You'll eventually want to [configure Vault](https://vaultproject.io/docs/index.html) specifically to your needs and setup appropriate ACLs.

### Terraform Destroy

If you want to destroy the environment, run the following command in the appropriate environment's directory

    $ terraform destroy -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"

**Note:** `terraform destroy` deletes real resources, it is important that you take extra precaution when using this command. Verify that you are in the correct environment, verify that you are using the correct keys, and set any extra configuration necessary to prevent someone from accidentally destroying infrastructure.
