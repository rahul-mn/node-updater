#!/bin/bash

# Configuration
IMAGE_NAME="nethermind/nethermind:latest-chiseled"
CONTAINER_NAME="volta-test"  # Name of the container
ALERT_URL="<slack-webhook-url-here>"  # Webhook URL

# Function to send alerts
send_alert() {
  local status=$1
  local message=$2

  curl -X POST -H "Content-Type: application/json" -d '{
    "status": "'"$status"'",
    "message": "'"$message"'"
  }' "$ALERT_URL"
}

# Pull the latest image and get its digest
REMOTE_DIGEST=$(docker pull $IMAGE_NAME 2>/dev/null | grep "Digest:" | awk '{print $2}')
if [ -z "$REMOTE_DIGEST" ]; then
  send_alert "ERROR" "Failed to fetch the latest image digest for $IMAGE_NAME."
  echo "Error: Unable to fetch the digest for the remote image."
  exit 1
fi

echo "Remote image digest: $REMOTE_DIGEST"

# Get the digest of the image used by the running container
CONTAINER_DIGEST=$(docker inspect --format='{{.Image}}' $CONTAINER_NAME 2>/dev/null)

if [ -z "$CONTAINER_DIGEST" ]; then
  send_alert "ERROR" "Failed to retrieve the image digest for the running container $CONTAINER_NAME."
  echo "Error: No running container found with name $CONTAINER_NAME."
  exit 1
fi

echo "Container image digest: $CONTAINER_DIGEST"

# Compare remote and container image digests
if [ "$REMOTE_DIGEST" != "$CONTAINER_DIGEST" ]; then
  echo "The running container is NOT up to date with the latest image."
else
  echo "The running container is up to date with the latest image."
  send_alert "INFO" "The running container $CONTAINER_NAME is already up to date."
  exit 0
fi

echo "A new image is available. Proceeding with the update."
random_time=$((RANDOM % 60 ))
  
# Sleep for the generated random time in seconds
echo "Sleeping for $random_time seconds..."
sleep "$random_time"

# Stop the running container
echo "Stopping the running container..."
docker stop $CONTAINER_NAME || {
  send_alert "ERROR" "Failed to stop the container $CONTAINER_NAME."
  echo "Error: Failed to stop the container."
  exit 1
}

# Backup current container configuration
echo "Backing up the current container configuration..."
docker rename $CONTAINER_NAME "$CONTAINER_NAME"_backup

# Run the new container with the updated image
echo "Starting the new container with the updated image..."
docker run -it --name $CONTAINER_NAME -d --mount type=bind,source=/home/rahul/bitscrunch/data,target=/nethermind/data_dir nethermind/nethermind:latest-chiseled --data-dir /nethermind/data_dir -c volta || {
echo "Error: Failed to start the new container. Reverting to the old version."

  # Revert to the old container
  docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME
  docker rename "$CONTAINER_NAME"_backup "$CONTAINER_NAME"
  docker start "$CONTAINER_NAME"
  if [ $? -ne 0 ]; then
    send_alert "CRITICAL" "Revert failed. Manual intervention required for $CONTAINER_NAME."
    echo "Critical Error: $CONTAINER_NAME failed to start. Manual intervention required."
    exit 1
  fi
  echo "Reverted to the old version successfully."
  send_alert "INFO" "Reverted to the old container version successfully for $CONTAINER_NAME."
  exit 1
  }

# If everything goes well
echo "Container updated successfully."
send_alert "SUCCESS" "The container $CONTAINER_NAME was updated successfully to the latest version."
