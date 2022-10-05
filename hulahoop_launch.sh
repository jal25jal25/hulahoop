#!/bin/bash
# This script is run from the client machine to launch the EC2 instance

### Begin Configuration ###
REGION="eu-west-1"
SECURITY_GROUP_ID="sg-12345678901234567"
VPC_ID="vpc-12345678901234567"
SUBNET_ID="subnet-12345678901234567"
INSTANCE_TYPE=t3.nano
IAM_INSTANCE_PROFILE="hulahoop_jump_server"
PROTECTED_SERVER_HOSTNAME="yourname.duckdns.org"
###  End Configuration  ###

# Get the ID of the latest Amazon Linux 2 AMI in our region
AMAZON_LINUX_LATEST=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --region ${REGION} --query 'Parameters[0].[Value]' --output text)

# Launch Hulahoop jump server instance
echo -n "Launching Hulahoop jump server... "
INSTANCE_ID=$(aws --region ${REGION} ec2 run-instances --image-id ${AMAZON_LINUX_LATEST} --count 1 --instance-type ${INSTANCE_TYPE} --security-group-ids ${SECURITY_GROUP_ID} --subnet-id ${SUBNET_ID} --user-data fileb://user_data.txt --instance-initiated-shutdown-behavior terminate --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} --tag-specifications ResourceType=instance,Tags='[{Key=Project,Value=Hulahoop},{Key=Name,Value=Hulahoop}]' --query "Instances[0].InstanceId" --output text)
echo "Done"

echo -n "Waiting for server to become running to find public IP address... "
# Find the public IP address of the host after it has entered the running state
while [ -z ${PUBLIC_IP} ]; do
  PUBLIC_IP=$(aws --region ${REGION} ec2 describe-instances --instance-ids ${INSTANCE_ID} --query "Reservations[*].Instances[*].PublicIpAddress" --output text)
  sleep 2
done
echo "Done"

# Find my current IP address
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Update security group to allow connection to jump server from caller
echo -n "Adding security group ingress rule for this IP address: ${MY_IP} ... "
aws --region ${REGION} ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr ${MY_IP}/32 --tag-specifications ResourceType=security-group-rule,Tags='[{Key=Project,Value=Hulahoop}]' >/dev/null
if [ $? -eq 0 ]; then echo "Done"; else echo "Error"; fi

# find the protected server's IP address
PROTECTED_SERVER_IP=$(dig +short ${PROTECTED_SERVER_HOSTNAME})

if [ ${MY_IP} == ${PROTECTED_SERVER_IP} ]; then
	echo "Skipping second security group rule as client and protected server IP addresses are identical (are you at home?)"
else
  # Update security group to allow connection to jump server from protected server
  echo -n "Adding security group ingress rule for protected server: ${PROTECTED_SERVER_IP} ... "
aws --region ${REGION} ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr ${PROTECTED_SERVER_IP}/32 --tag-specifications ResourceType=security-group-rule,Tags='[{Key=Project,Value=Hulahoop}]' >/dev/null
if [ $? -eq 0 ]; then echo "Done"; else echo "Error"; fi
fi 

echo "Public IP address of jump server is ${PUBLIC_IP}"
echo ""
echo "    SSH to protected server via jump server with: ssh -o ProxyCommand='ssh -W %h:%p ec2-user@${PUBLIC_IP}' protected_server_username@localhost -p 19876"
echo "    SCP with: scp -o ProxyCommand='ssh -W %h:%p ec2-user@${PUBLIC_IP}' -P 19876 protected_server_username@localhost:<file> <dest>"
echo ""

echo -n "Waiting for active tunnel from protected server to jump server"
while [ -z ${TUNNEL_FLAG_FILE} ]; do
  TUNNEL_FLAG_FILE=$(ssh ec2-user@${PUBLIC_IP} ls /tmp/hulahoop_protected_server_ssh_active 2>/dev/null)
  sleep 5
  echo -n "."
done
echo ""

#Could make more resilient to AZ problems by trying the second subnet
