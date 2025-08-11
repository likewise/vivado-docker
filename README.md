# vivado-docker

Vivado installed into a Docker image

## Build prerequisites

Docker or Podman.

The Dockerfile will try to download the Vivado installer from a (local)
web server. So run a HTTP server that hosts the Vivado stand-alone (full)
installer.

For example; run `python3 -m http.server --bind 127.0.0.1` in the folder
with the Vivado installer .tar file (See Makefile).

## Build instructions

Run `make build` to create the container image.

## Running

Run `make remote` to start a container on the host. The host current working
directory is mounted as /project-on-host inside the container. The container
is accessible even from other peer hosts.

## Design

The Docker image is based on Ubuntu 22.04. The image has user "vivado" with user ID 1000.
Some tools are then installed as root, some as vivado.
User vivado has sudo rights inside the container.

The default user is vivado and the default work directory is /home/video (see Dockerfile:)
USER vivado
WORKDIR /home/vivado

Beyond this point, some more magic is performed.

# Future work

Podman rootless is in a branch now

https://www.redhat.com/sysadmin/debug-rootless-podman-mounted-volumes

LD_LIBRARY_PATH=/opt/Xilinx/Vivado/2023.1/lib/lnx64.o /opt/Xilinx/Vivado/2023.1/bin/unwrapped/lnx64.o/hw_server -L- -e "set always-open-jtag 1"

LD_LIBRARY_PATH=/opt/Xilinx/Vivado/2023.1/lib/lnx64.o strace /opt/Xilinx/Vivado/2023.1/bin/unwrapped/lnx64.o/hw_server -L- -e "set always-open-jtag 1"

# Linux 6.2.13/14 kernel issue with Vivado

https://jia.je/software/2023/05/06/linux-regression-vivado-en/

# Future versions 2025+2 only support the web installer

https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Acquire-Authentication-Token