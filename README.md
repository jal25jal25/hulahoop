# Hulahoop

Some Terraform and some scripts to let you SSH home without any open firewall ports, using an ephemeral EC2 instance as a jump host. Built with a desire to minimise cost.

## Background

I used to allow SSH access to a home server behind my ISP-provided router/firewall. While I kept my OS up to date and took the usual precautions against compromise and SSH door handle rattlers, the router's performance just degraded when the inbound firewall ports were open and was receiving a constant barrage of requests.

I wanted a solution so that I could SSH home, but I didn't need any inbound firewall access. I also wanted to minimise cost.

In this document I do assume prior knowledge of AWS and Terraform, and using SSH in general.

## Warranty
I do not warrant that this code is bug-free and that it may not leave AWS resources running and incurring you cost. It is also up to you to decide if the code is secure and fits your needs. Use entirely at your own risk.

## Terminology
* **Protected Server** - The server on the inside of the firewall. Perhaps your home Linux box. It will have outbound SSH access, but not inbound
* **Jump Server** - an ephemeral EC2 instance used as an SSH jump host
* **Caller** - a machine running the script to create the EC2 instance which will also be allowed to connect to the Jump Server, and onwards to the Protected Server. This could be a laptop outside the network of the Protected Server. You could have multiple Callers, if you had multiple laptops, for example.

## Architecture

### Architecture Diagram
tbc

### Architecture Overview

This solution starts by creating some static AWS resources in Terraform: a basic VPC, EC2 Security Group (no rules), an SSM Parameter Store parameter containing SSH public keys, IAM users, roles, policies and instance profiles.

We run a script from cron on the Protected Server. The script will run periodically and check for a running EC2 Jump Server instance. If one exists, it will connect to it, once, via SSH and allow a reverse SSH tunnel.

Finally, on the Caller, we can run a script to create an EC2 instance and add the Security Group rules to allow connections from the Caller to the Jump Server, and from the Protected Server to the Jump Server.

The Jump Server will shut down when detects that either:
* It has been up for >30 minutes and nobody has connected
* There have previously been active SSH connections, but they have terminated

The latest Amazon Linux 2 AMI is used every tine, to get as fresh an image as possible

## Prerequisites

1. An AWS account
1. [Terraform](https://www.terraform.io/) installed
1. Authentication to an AWS account with sufficient privileges to run the Terraform
1. An S3 bucket to store Terraform state
1. Hostname in public DNS for protected server. A service like [Duck DNS](www.duckdns.org) will come in handy here. If you're looking at other ways of reaching your home server from outside, you are probably using a similar service anyway. There is a Todo item (below) to modify the script to take an IP address if you have a static one (PRs welcome!)

## Configuration

### On your "protected server" (part 1)
1. Create a user for running hulahoop, e.g. `hulahoop`
2. Ensure email for the new user is sent somewhere you will receive it, e.g. by using a `.forward` file or configuring your local MTA
1. Generate an SSH keypair for the new user, with `ssh-keygen`
1. Add the `hulahoop_connect.sh` script. I suggest in the `/home/hulahoop/bin` directory
1. Edit the configuration section at the top of the script to reflect your chosen AWS region 

### Deploy base infrastructure with Terraform
1. Rename `terraform/backend_config/hulahoop-EXAMPLE.tfvars` to `terraform/backend_config/hulahoop.tfvars`, setting the correct values for the prerequisite S3 bucket name and your chosen AWS region
1. Copy `terraform/parameters/hulahoop_public_keys-EXAMPLE.txt` to `terraform/parameters/hulahoop_public_keys.txt` and add the SSH public key for the hulahoop user on your Protected Server and for any users on Caller machines you may wish to use
1. `cd terraform`
1. `terraform init --backend-config=backend_config/1ulahoop.tfvars`
1. `terraform plan`
1. `terraform apply`

### In AWS (Console or CLI)
Manually create access keys for the two IAM users created by Terraform:

* `hulahoop_protected_server`
* `hulahoop_caller`

I prefer to do this manually, as to output credentials requires them to be stored in the Terraform state file.

### On your "protected server" (part 2)
1. Place the access key and secret access key for the `hulahoop_protected_server` IAM user on your protected server so that when the `hulahoop_connect.sh` script is run, it gains the correct AWS credentials, e.g. by creating an [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) file at `/home/hulahoop/.aws/credentials`:
1. Add a cron job to run `hulahoop_connect.sh` periodically. I would recommend something like:
```*/5 * * * * exec /home/hulahoop/bin/hulahoop_connect.sh```
(Note I use `exec` to prevent spawning another process, which becomes useful when tracking how many processes are running)

### On your Caller
1. Install the [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
1. Add the `hulahoop_launch.sh` and `user_data.txt` scripts to the same directory on your caller machine. 
1. Edit the configuration section at the top of `hulahoop_launch.sh` to reflect the resource IDs created by Terraform, your chosen AWS region and the DNS name of your Protected Server.
1. Place the access key and secret access key for the `hulahoop_caller` IAM user on your caller so that when the `hulahoop_launch.sh` script is run, it gains the correct AWS credentials. You could use an AWS credentials file as above, or environment variables, or some other means.

## Creating a tunnel
On the Caller, run `hulahoop_launch.sh`. This script will:

* Determine the latest Amazon Linux v2 AMI
* Launch an EC2 instance (the Jump Server) using that AMI into the VPC created by Terraform
* Attach an IAM instance profile to the Jump Server to give it the necessary AWS privileges to detach Security Group rules, etc
* Wait for the Jump Server to become ready and find its public IP address
* Find the current public IP address of the Protected Server via a DNS lookup 
* Add EC2 Security Group rules to allow SSH access to the Jump Server from both the Caller and the Protected Server IP addresses
* Wait for the Jump Server to have received an inbound connection from the Protected Host
* Output useful SSH / SCP strings demonstrating how to connect to the Protected Server

## Destroying a tunnel
Simply disconnect your last SSH session from the Caller to the Jump Host and the Jump Host will remove the security group rules and terminate within a few minutes

If you do not connect via SSH to the Jump Host within 30 minutes, it will remove the Security Group rules and terminate.

## Security
### AWS IAM
The IAM policies can be seen in the `terraform/policies` directory:
* `hulahoop_protected_server.json` for the `hulahoop_connect.sh` script running on the Protected Server
* `hulahoop_caller.tpl` for the `hulahoop_launch.sh` script running on the Caller
* `hulahoop_jump_server.tpl` for the Jump Server to read the SSM Parameter containing SSH public keys and for the `hulahoop_shutdown.sh` script running on the Jump Server to remove Security Group rules

I believe the IAM policies are as tight as possible, noting that a number of the permissons do not support resource constraints.

### SSH
By only exposing SSH ports on the ephemeral jump server, and then only to the specific IP addresses of the Caller and the Protected Server, I believe the attack surface is low. Even if an attacker were to gain access to the Jump Server, they would still need credentials to be able to SSH to the Protected Server.

## Todo
1. Identify the least-privilege IAM policy for deploying the Terraform
1. Modify the `hulahoop_launch.sh` script to accept an IP address as an alternative for hostname and skip the DNS lookup
