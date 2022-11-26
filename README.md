# vivado-docker

Vivado installed into a Docker image

## Build instructions

See Dockerfile

## Running

See Dockerfile

## Design

The Docker image is based on Ubuntu 22.04. The image has user "vivado" with user ID 1000.
Some tools are then installed as root, some as vivado.
User vivado has sudo rights inside the container.

The default user is vivado and the default work directory is /home/video (see Dockerfile:)
USER vivado
WORKDIR /home/vivado

Beyond this point, some more magic is performed, as an ENR