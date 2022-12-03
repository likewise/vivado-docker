#!/bin/sh

# create-container-user.sh <user id> <user name>

useradd -m -s /bin/bash -u $1 -o -d /home/$2 $2
chown $2 $(tty)
echo 'source /opt/Xilinx/Vivado/2022.2/settings64.sh' > /home/$2/.bash_profile
echo 'export PATH=$PATH:/home/vivado/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc
# does not work (anymore in 2022.2?)
#echo 'alias vivado="vivado -stack 4000"' >> /home/$NEW_USER/.bash_profile
chown $2:$2 -R /home/$2/