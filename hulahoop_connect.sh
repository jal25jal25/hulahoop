#!/bin/bash
# This script runs from cron on the protected server

### Begin Configuration ###
REGION="eu-west-1"
USER="ec2-user"
###  End Configuration  ###

BASENAME=$(basename $0)
PROCESSES=$(pgrep -f ${BASENAME})
PROCESSES_ARRAY=($PROCESSES)

if [ ${#PROCESSES_ARRAY[@]} -gt 1 ]; then
  # Another identical process is running - exit
  exit 2
fi

# Find any Hulahoop instances by tag and by running state
INSTANCE_IDS=$(/usr/local/bin/aws --region ${REGION} ec2 describe-instances --query "Reservations[].Instances[].InstanceId[]" --filters Name=tag-key,Values="Project" Name=tag-value,Values="Hulahoop" Name="instance-state-name",Values="running" --output text)

LATEST_LAUNCH_TIME_EPOCH=0
INSTANCE_IDS_ARRAY=($INSTANCE_IDS)
if [ ${#INSTANCE_IDS_ARRAY[@]} -eq 0 ]; then
  # No Hulahoop instances running
  exit
elif [ ${#INSTANCE_IDS_ARRAY[@]} -gt 1 ]; then
  echo "More than one Hulahoop instance running!"
  for instance_id in ${INSTANCE_IDS}; do
    # Get the startup time
    LAUNCH_TIME=$(/usr/local/bin/aws --region ${REGION} ec2 describe-instances --query "Reservations[].Instances[].LaunchTime" --filters Name="instance-id",Values=${instance_id} --output text)
    echo "Launch time: ${LAUNCH_TIME}"
    LAUNCH_TIME_EPOCH=$(date -d ${LAUNCH_TIME} +%s)
    echo "Launch time: ${LAUNCH_TIME_EPOCH}"
    if [ ${LAUNCH_TIME_EPOCH} -gt ${LATEST_LAUNCH_TIME_EPOCH} ]; then
      LATEST_LAUNCH_TIME_EPOCH=${LAUNCH_TIME_EPOCH}
      INSTANCE_ID_TO_USE=${instance_id}
    fi
  done
  echo "Will use most recently-launched instance: ${INSTANCE_ID_TO_USE}"
else
  # One Hulahoop jump server running
  INSTANCE_ID_TO_USE=${INSTANCE_IDS_ARRAY[0]}
  echo "Only one Hulahoop jump server running: ${INSTANCE_ID_TO_USE}"
fi

# Connect and create the tunnel
while [ -z ${PUBLIC_IP} ]; do
  PUBLIC_IP=$(/usr/local/bin/aws --region ${REGION} ec2 describe-instances --instance-ids ${INSTANCE_ID_TO_USE} --query "Reservations[].Instances[].PublicIpAddress" --output text)
  sleep 2
  echo "Connecting to Hulahoop jump server at ${PUBLIC_IP}. 'c' will appear every 30 seconds while connected"
  ssh -o StrictHostKeyChecking=no -R 19876:localhost:22 ${USER}@${PUBLIC_IP} 'touch /tmp/hulahoop_protected_server_ssh_active && while true; do sleep 30; echo -n "c"; done'
done  

echo "Connection ended. Sleeping for 300 seconds"
sleep 300

# Find any Hulahoop instances by tag and by running state
REMAINING_INSTANCE_IDS=$(/usr/local/bin/aws --region ${REGION} ec2 describe-instances --query "Reservations[].Instances[].InstanceId[]" --filters Name=tag-key,Values="Project" Name=tag-value,Values="Hulahoop" Name="instance-state-name",Values="running" --output text)
REMAINING_INSTANCE_IDS_ARRAY=($REMAINING_INSTANCE_IDS)

if [ ${#REMAINING_INSTANCE_IDS_ARRAY[@]} -eq 0 ]; then
  echo "No Hulahoop jump servers left running"
else
  # This warning should be received in the cron email, if email is enabled as advised in the README
  echo "WARNING: ${#REMAINING_INSTANCE_IDS_ARRAY[@]} Hulahoop jump server instances still running"
  echo "Running instance IDs: $REMAINING_INSTANCE_IDS_ARRAY"
  echo "Region: $REGION"
fi
