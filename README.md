# vivado-docker

Vivado installed into a Docker image

## Build prerequisites

Docker or Podman.

The Dockerfile will try to download the Vivado installer from a (local)
web server. So run a HTTP server that hosts the Vivado stand-alone (full)
installer.

For example; run `python3 -m http.server --bind 127.0.0.1` in the folder
with the Vivado installer .tar file.

## Build instructions

Run `make build`.

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
