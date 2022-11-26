#!/bin/bash

# Create user on the fly that matches the user starting the container
# on the host. Then switch to that user.

# This entry point should be run as container root.

# Based on https://github.com/phwl/docker-vivado/blob/master/2021.2/Dockerfile

CONTAINER_USER_ID=`id -u`
if [[ "$CONTAINER_USER_ID" -eq 0 ]]; then
  echo "Do not run this container as root."
fi

if [[ "$HOST_USER_ID" -eq 1001 ]]; then
  echo "Do not run this container as max."
fi

echo "Entering entrypoint.sh as container user ID `id -u` with CMD $@."

user_exists(){ id "$1" &>/dev/null; } # silent, it just sets the exit code

echo HOST_USER_ID=$HOST_USER_ID
echo HOST_USER_NAME=$HOST_USER_NAME

# User ID of the host is given?
if [[ -n "$HOST_USER_ID" ]]; then
  if user_exists "$HOST_USER_ID"; then
    echo "Container user ID $HOST_USER_ID matches host user ID $HOST_USER_ID already."
    echo "Exiting entrypoint.sh with exec vivado $@"
    exec "$@"
  else
    echo "Creating container user that matches host user ID $HOST_USER_ID."
    if [[ -n "$HOST_USER_NAME" ]]; then
      HOST_USER_NAME=$HOST_USER_NAME
    else
      HOST_USER_NAME=user
    fi

    echo HOST_USER_NAME=$HOST_USER_NAME
    echo sudo create-container-user.sh $HOST_USER_ID $HOST_USER_NAME
    sudo create-container-user.sh $HOST_USER_ID $HOST_USER_NAME

    echo "Exiting entrypoint.sh with sudo gosu $HOST_USER_NAME $@"
    sudo gosu $HOST_USER_NAME "$@"
  fi
else
  echo "Exiting entrypoint.sh with exec vivado $@"
  exec gosu vivado "$@"
fi

echo
