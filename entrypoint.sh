#!/bin/bash

# Create user on the fly that matches the user starting the container
# on the host. Then switch to that user.

# Based on https://github.com/phwl/docker-vivado/blob/master/2021.2/Dockerfile

echo "Entering entrypoint.sh"

UART_GROUP_ID=${UART_GROUP_ID:-20}
if ! grep -q "x:${UART_GROUP_ID}:" /etc/group; then
  echo "Creating UART group."
  groupadd -g "$UART_GROUP_ID" uart
fi
UART_GROUP=$(grep -Po "^\\w+(?=:x:${UART_GROUP_ID}:)" /etc/group)

user_exists(){ id "$1" &>/dev/null; } # silent, it just sets the exit code

echo HOST_USER_NAME=$HOST_USER_NAME


# User ID of the host is given?
if [[ -n "$HOST_USER_ID" ]]; then
  if user_exists "$HOST_USER_ID"; then
    echo "Container user ID $HOST_USER_ID matches host user ID $HOST_USER_ID already."
    echo "Exiting entrypoint.sh"
    exec "$@"
  else
    echo "Creating container user that matches host user ID $HOST_USER_ID."
    if [[ -n "$HOST_USER_NAME" ]]; then
      NEW_USER=$HOST_USER_NAME
    else
      NEW_USER=user
    fi

    echo NEW_USER=$NEW_USER
    useradd -m -s /bin/bash -u "$HOST_USER_ID" -o -d /home/$NEW_USER $NEW_USER
    #usermod -aG sudo $NEW_USER
    usermod -aG "$UART_GROUP" "$NEW_USER"
    chown $NEW_USER $(tty)
    echo 'source /opt/Xilinx/Vivado/2022.2/settings64.sh' > /home/$NEW_USER/.bash_profile
    echo 'export PATH=$PATH:/home/vivado/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc
    # does not work (anymore in 2022.2?)
    #echo 'alias vivado="vivado -stack 4000"' >> /home/$NEW_USER/.bash_profile
    chown $NEW_USER:$NEW_USER -R /home/$NEW_USER/
    echo "Exiting entrypoint.sh"
    #exec gosu $NEW_USER xeyes &
    exec gosu $NEW_USER "$@"
  fi
else
  echo "Exiting entrypoint.sh"
  exec "$@"
fi

echo
