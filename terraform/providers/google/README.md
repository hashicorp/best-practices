### Create a Google Cloud account

* Create a project
* Generate json credentials file
  * Navigate to `API Manger / Credentials / Create credentials / Service account key` in the console.
  * Select `Compute Engine default service account` and key type `JSON`
* Add a public key to the project
  * Navigate to `Compute Engine / Metadata / SSH Keys` in the console.
  
### Create an Atlas account
  
Create an account and an API token.

### Set up your local environment

Initialize a Vagrant and SSH in:

```bash
$ vagrant init ubuntu/trusty64
$ vagrant up && vagrant ssh
```

Install dependencies

* Install Packer, Terraform & git
* Add packer and terraform to your `PATH`

Clone the repo:

```bash
$ git clone https://github.com/hashicorp/best-practices.git
$ cd best-practices
```

Set environment variables:

```bash
$ export ATLAS_TOKEN="TOKEN"
$ export ATLAS_USERNAME="USERNAME"
```

Generate keys and certs:

```bash
$ cd setup
$ sh gen_key.sh site
$ sh gen_cert.sh hashicorpdemo.com hashicorp
```

### Generate Packer artifacts

Push the Packer build configurations to Atlas:

```bash
$ cd ..
$ packer push -token $ATLAS_TOKEN -name $ATLAS_USERNAME/google-ubuntu-base packer/google/ubuntu/base.json
$ packer push -token $ATLAS_TOKEN -name $ATLAS_USERNAME/google-ubuntu-consul packer/google/ubuntu/consul.json
$ packer push -token $ATLAS_TOKEN -name $ATLAS_USERNAME/google-ubuntu-vault packer/google/ubuntu/vault.json
$ packer push -token $ATLAS_TOKEN -name $ATLAS_USERNAME/google-ubuntu-haproxy packer/google/ubuntu/haproxy.json
$ packer push -token $ATLAS_TOKEN -name $ATLAS_USERNAME/google-ubuntu-nodejs packer/google/ubuntu/nodejs.json
```

Set the following variables in Atlas for each build configuration:

* ATLAS_USERNAME: YOUR_ATLAS_USERNAME
* GCE_DEFAULT_ZONE: us-central1-a
* GCE_PROJECT_ID: YOUR_GOOGLE_PROJECT_ID
* GCE_SOURCE_IMAGE: ubuntu-1404-trusty-v20160114e (`google-ubuntu-base` configuration only)
* GCE_CREDENTIALS: YOUR_GOOGLE_CREDENTIALS_FILE_AS_A_SINGLE_LINE_OF_TEXT

For each build configuration other than `google-ubuntu-base`, set `Inject artifact ID during build` to `google-ubuntu-base` in Settings.
    
Queue a build for each build configuration. Start with`google-ubuntu-base` and wait until it completes before kicking off the others.

### Configure Terraform & provision

Configure the remote and push the configuration:

```bash
$ cd terraform/providers/google/us_central1_prod
$ terraform remote config -backend-config access_token=$ATLAS_TOKEN -backend-config name=$ATLAS_USERNAME/google-us-central1-prod
$ terraform get
$ terraform push -name $ATLAS_USERNAME/google-us-central1-prod
 ```
 
Update the following variables in Atlas:
 
* atlas_token, atlas_username
* credentials (contents of account.json)
* project (google project id)
* site_ssl_cert (contents of setup/site.crt)
* site_ssl_key (contents of setup/site.key)
* ssh_keys (your public key)
* vault_ssl_cert (contents of setup/vault.crt)
* vault_ssl_key (contents of setup/vault.key)
* Leave vault_token as is for now
 
Queue a plan & apply

### Set up the Bastion

SSH to the bastion host and add your private key to enable SSH into the other instances.

### Set up Vault

SSH to prod-vault-0 and run:

```bash
$ vault init
$ vault unseal (x3)
```

SSH to prod-vault-1 and run:

```bash
$ vault unseal (x3)
```

Update the `vault_token` variable in Atlas and then queue a plan and apply.

### Test the nodejs application

Visit the webpage at the HaProxy URL in your apply output.

