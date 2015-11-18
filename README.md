## Best Practices Ops

Below are the infrastructures we currently have best practices for. Navigate to each provider to see what will be provisioned.

- [AWS](terraform/providers/aws/README.md)

### Getting Started

This repository contains best-practice infrastructures across different cloud providers, regions, environments, and operating systems.

You can think of this as a library of Packer templates and Terraform modules that allow you to provision unique infrastructures by referencing the different templates and modules. We've tried to set this repository up in a way that we don't have to duplicate code, allowing templates and modules to be used across multiple environments.

Each environment is a best practices guide for how to use HashiCorp tooling to provision that specific type of infrastructure. Use each as a reference when building your own infrastructure. The best way to get started is to pick an environment that resembles an infrastructure you are looking to build, get it up and running, then configure and modify it to meet your specific needs.

No example will be exactly what you need, but it should provide you with enough examples to get you headed in the right direction.

A couple things to keep in mind...

- Each environment's README will reference different sections in [General Setup](https://github.com/hashicorp/atlas-examples/blob/master/setup/general.md) to get your environment properly setup to build the infrastructure at hand.
- Each environment will assume you're using Atlas. If you plan on doing anything locally, there are portions of environments that may not work due to the extra features Atlas provides that we are taking advantage of.
- Each environment's instructional documentation is based off of the assumption that certain information will be saved as environment variables. If you do not wish to use environment variables, there are different ways to pass this information, but you may have to take extra undocumented steps to get commands to work properly.
- Any `packer push` commands must be performed in the base [packer/.](packer) directory.
- Any `terraform push` commands must be performed in the appropriate Terraform environment directory (e.g. [terraform/providers/aws/us\_east\_1\_staging](terraform/providers/aws/us_east_1_staging)).
