# Lab Terraform for AWS

This is a Terraform template for building a lab environment in AWS.

## Requirements

- Amazon Web Services (AWS) account
- Terraform

### Optional

- Ansible

## Installation

### AWS Credentials

You'll need to have an AWS account, and you'll want to set up configuration and credentials files on your system as outlined in the guide here:

https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html

### Terraform

Once you've configured your AWS credentials file, you'll need to install Terraform.  If you've never used Terraform before, they provide detailed documentation and tutorials here:

https://learn.hashicorp.com/terraform#getting-started

## How-to Run

1. Set up the configuration parameters in the **[terraform.tfvars](terraform.tfvars)** file.
    - Configuration variables and their default values are described [here](#configuration-parameters).
2. Initialize Terraform by running `terraform init` from the root directory of this repository.
3. Verify the Terraform configuration by running `terraform plan` to preview the changes that will be made.
4. Once verified, simply run `terraform apply` to deploy your infrastructure.
5. During deployment, a config.json and inventory.cfg file will be created in the ansible directory.  These can be used to run Ansible playbooks to provision the instances.

Once Terraform deploys the infrastructure, you can provision software/configuration using Ansible.  The Ansible command will be similar to below:

> `ansible-playbook -i ansible/inventory.cfg --private-key <private/key/location> -u <username> [ansible playbooks ...]`

## Configuration Parameters

Once you clone this repository, you'll want to edit the **[terraform.tfvars](terraform.tfvars)** file to specify configuration for your Lab.  Configuration variables are as follows:

- availability_zone_count:  The number of availability zones in which to deploy.
  - Default: 1
  - Type: Integer
- dns_zone:  [OPTIONAL] The domain zone in which to deploy a Route 53 record.
  - Default: ""
  - Type: String
- instance_ami:  The AMI to use when provisioning EC2 instances.
  - Default: ""
  - Type: String
- instance_key_name:  The AWS Key Pair name to use when provisioning EC2 instances.
  - Default: ""
  - Type: String
- instance_key_path:  The path to the private AWS key.
  - Default: ""
  - Type: String
- instance_size:  The EC2 instance size to use when provisioning instances.
  - Default: "t3.small"
  - Type: String
- instance_username:  The username that is tied to the AWS Key Pair.
  - Default: ""
  - Type: String
- instances_per_az:  The number of EC2 instance to deploy in each Availability Zone.
  - Default: 1
  - Type: Integer
- lacework_access_token:  The access token to use when provisioning the Lacework Agent.
  - Default: ""
  - Type: String
- region:  The AWS Region in which to deploy.
  - Default: "us-east-1"
  - Type: String
- vpc_name:  The desired name of the VPC that will be created.
  - Default: "Lab"
  - Type: String
- vpc_subnet:  The CIDR network that should be used to assign subnets in AWS.
  - Default: "10.150.0.0/16"
  - Type: String
