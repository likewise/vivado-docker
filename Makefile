VER=4.1.3

# Branch 4.1
# Podman
# Vivado Web Installer
# Release 4.1.0:
# Ubuntu 22.04
# Vivado Enterprise Edition 2025.1

# make build   = rebuild the container image
# make remote  = run the container image on the host you are logged in to via SSH.
mkfile_path := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))

# run all target command in the same shell instance
.ONESHELL:
# use the bash shell
SHELL=/bin/bash

# --cgroup-manager cgroupfs to work-around Debian 12 problem of
# --runtime=/usr/bin/runc with apt-get install runc
#
# sd-bus call: Interactive authentication required.: Permission denied
build:
	docker build --build-arg=TERM="linux" --network=host -t vivado:$(VER) .

# assures variable % is set (used for USER and DISPLAY)
guard-%:
	@if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

# assures GIT user.name and user.email is set outside of container
.PHONY: assert-gitconfig
assert-gitconfig:
	set -e
	(git config --global --list | grep -qe user.name) || \
	(echo 'Please configure GIT first:\ngit config --global user.name "FIRST_NAME LAST_NAME"'; false)
	(git config --global --list | grep -qe user.email) || \
	(echo 'Please configure GIT first:\ngit config --global user.email "MY_NAME@example.com"'; false)

# --user `id -u`:`id -g` is to match the container user to the host user, so if
# files are written to the host directory, they have the correct ownership.
run: #guard-DISPLAY guard-USER assert-gitconfig

	mkdir -p ~/.vscode-server

	docker --version | grep podman
	if [ $$? -eq 0 ]; then
		echo "Detected Podman"
# --userns=keep-id creates a map where your host user's UID/GID is identical to the container's user ID/GID. 
		export PODMAN_EXTRA_ARGS="--userns=keep-id --cap-add=NET_RAW,NET_ADMIN"
	else
		echo "Assuming Docker"
		export PODMAN_EXTRA_ARGS=
	fi

	echo $${PODMAN_EXTRA_ARGS}
#	echo "Make run is not well maintained, did you mean make remote?"
#	exit
	docker run -ti --rm \
	--name vivado-$(USER) \
	--user `id -u`:`id -g` \
	--cap-add=NET_ADMIN \
	$${PODMAN_EXTRA_ARGS} \
	-e HOST_USER_NAME=`id -nu $${USER}` \
	-e HOST_USER_ID=`id -u $${USER}` \
	-e HOST_GROUP_ID=`id -g $${USER}` \
	-e DISPLAY=$(DISPLAY) \
	--network=host \
	--device=/dev/bus \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v $$PWD:/project-on-host \
	-v $$HOME/.vscode-server:/home/vivado/.vscode-server \
	-w /project-on-host \
	vivado:$(VER)

#	-v $$PWD/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \

remote: guard-DISPLAY guard-USER assert-gitconfig

	mkdir -p ~/.vscode-server

	# Prepare target env
	export CONTAINER_DISPLAY="0"
	export CONTAINER_HOSTNAME="vivado-container"

	# Create a directory for the socket
	rm -rf $${X11TMPDIR}
	export X11TMPDIR=`mktemp -d`
	mkdir -p $${X11TMPDIR}/socket

	# Get the guest host DISPLAY slot
	export DISPLAY_NUMBER=$$(echo $$DISPLAY | cut -d. -f1 | cut -d: -f2)
	export XPORT=$$((6000 + $${DISPLAY_NUMBER}))
	echo "DISPLAY_NUMBER=$$DISPLAY_NUMBER on guest host port $$XPORT"

	xauth list
	echo "Filtered on host $$(hostname) and DISPLAY_NUMBER $${DISPLAY_NUMBER}:"
	echo "xauth list | grep -e ^$$(hostname):.*$${DISPLAY_NUMBER}"
	xauth list | grep -e "^$$(hostname).*:$${DISPLAY_NUMBER}"
	echo "---"

	# Extract authentication cookie for the guest host DISPLAY
	#export AUTH_COOKIE=$$(xauth list | grep -e "^$$(hostname)/unix:$${DISPLAY_NUMBER} " | awk '{print $$3}')
	#echo "AUTH_COOKIE=$$AUTH_COOKIE (for unix:$${DISPLAY_NUMBER})"
	#echo grep -e "^$$(hostname):$${DISPLAY_NUMBER} "
	# .* to also capture hostname/unix:10 besides hostname:10
	export AUTH_COOKIE=$$(xauth list | grep -e "^$$(hostname).*:$${DISPLAY_NUMBER} " | head -n1 | awk '{print $$3}')
	echo "AUTH_COOKIE=$$AUTH_COOKIE (for ip:$${DISPLAY_NUMBER})"

	: > "$$X11TMPDIR/Xauthority"

	# Add a specific entry for what the container will request: vivado-container/unix:0
	xauth -f "$$X11TMPDIR/Xauthority" add "$$CONTAINER_HOSTNAME/unix:$$CONTAINER_DISPLAY" MIT-MAGIC-COOKIE-1 "$$AUTH_COOKIE"
	xauth nlist "$$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$$X11TMPDIR/Xauthority" nmerge -
	
	chmod 0644 "$$X11TMPDIR/Xauthority"
	echo "$${X11TMPDIR}/Xauthority:"
	xauth -f $${X11TMPDIR}/Xauthority list

	# Proxy with the :0 DISPLAY
	# -d -d 
	socat UNIX-LISTEN:"$$X11TMPDIR/socket/X$$DISPLAY_NUMBER",unlink-early,mode=0777,fork TCP4:127.0.0.1:60$$DISPLAY_NUMBER &
	export PIDOF_SOCAT=$$!

	# if user id inside docker container differs from host id
	# we need to provide access for this other user
	# inspired by https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
	chmod ugo+rwx -R $${X11TMPDIR}
	# not sure why this is ALSO needed
	/usr/bin/setfacl -R -m user:1000:rwx $${X11TMPDIR}


#	-v ~/../shared/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
#	-v ~/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
#	-u `id -u`:`id -g` \
# replaced by -e HOST_USER_ID what is picked up by entrypoint.sh to
# create a matching user in the container, on the fly, and become that user
#--user `id -u`:`id -g` \
#	--mac-address="00:30:48:29:6b:04" \
#	--mac-address="00:30:48:29:6b:04" \
	find $${X11TMPDIR}

# adapt for root-less podman vs root-full docker
	docker --version | grep podman
	if [ $$? -eq 0 ]; then
		echo "Detected Podman"
		export PODMAN_EXTRA_ARGS="--userns=keep-id:uid=1000,gid=1000 --cap-add=NET_RAW"
	else
		echo "Assuming Docker"
		export PODMAN_EXTRA_ARGS=
	fi

	echo $${PODMAN_EXTRA_ARGS}

#	--net=bridge \
#	--mac-address="00:30:48:29:6b:04" \
#	--net=host \
#
#	--name vivado-$(USER) \
#	--name vivado-`basename $${PWD}` \
#   container has X display on unix socket, we need to socat it
#	-e DISPLAY=:$${CONTAINER_DISPLAY} \
#   container has direct connection to host port (forwarded by SSH)
#	-e DISPLAY=localhost:$${DISPLAY_NUMBER} \
	-e DISPLAY=localhost:$${DISPLAY_NUMBER} \
#
#
#  --user is often redundant if you already used --userns=keep-id,
# since in that case your host UID will usually be mapped 1:1.

#	-e HOST_USER_NAME=`id -nu $${USER}` \
#	-e HOST_USER_ID=`id -u $${USER}` \
#	-e HOST_GROUP_ID=`id -g $${USER}` \


	echo CONTAINER_HOSTNAME=$${CONTAINER_HOSTNAME}

	# Launch the container
	docker run -it --rm \
	--log-level=debug \
	--name vivado-$(USER) \
	--cap-add=NET_ADMIN \
	--net=host \
	$${PODMAN_EXTRA_ARGS} \
	-e DISPLAY=:$${DISPLAY_NUMBER} \
	-e XAUTHORITY=/tmp/.Xauthority \
	-v $${X11TMPDIR}/socket:/tmp/.X11-unix \
	-v $${X11TMPDIR}/Xauthority:/tmp/.Xauthority \
	-v $${PWD}:/project-on-host \
	--hostname $${CONTAINER_HOSTNAME} \
	--add-host $${CONTAINER_HOSTNAME}:127.0.0.1 \
	\
	-w /project-on-host \
	-v $$HOME/.vscode-server:/home/vivado/.vscode-server \
	-v ~/.ssh:/home/vivado/.ssh:ro \
	-v ~/.ssh:/home/vivado-docker-`id -u $${USER}`/.ssh:ro \
	-v ~/.gitconfig:/home/vivado/.gitconfig:ro \
	-v ~/.gitconfig:/home/vivado-docker-`id -u $${USER}`/.gitconfig:ro \
	-v $(mkfile_path)/Vivado_init.tcl:/home/vivado/.Xilinx/Vivado/Vivado_init.tcl:ro \
	-e XILINXD_LICENSE_FILE="$$(cat $(mkfile_path)/XILINXD_LICENSE_FILE):$$(cat XILINXD_LICENSE_FILE):$$(echo $${XILINXD_LICENSE_FILE:-''})" \
	\
	--group-add keep-groups \
	--security-opt label=disable \
	--expose 14500 \
	\
	vivado:$(VER) \
	|| echo ERROR $$?
    #2> /tmp/podman-debug.log

	rm -rf $${X11TMPDIR}
	kill -9 $${PIDOF_SOCAT}

#
#	--device /dev/bus/usb:/dev/bus/usb:rw \
#	-v /home/leon/sandbox/vivado-docker/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
#	--device /dev/ttyUSB0:/dev/ttyUSB0:rw \
#	--device /dev/ttyUSB1:/dev/ttyUSB1:rw \
#	--device /dev/ttyUSB2:/dev/ttyUSB2:rw \
#	--device /dev/ttyUSB3:/dev/ttyUSB3:rw \
#
#
#	-v /sys/devices:/sys/devices:ro \
#	-v /dev:/dev:rw \



#	-v ~/../shared/.Xilinx/100G.lic:/home/vivado-docker-`id -u $${USER}`/.Xilinx/Xilinx.lic:ro \
#	--device-cgroup-rule 'c 188:* rmw' \
#	--device-cgroup-rule 'c 189:* rmw' \


#	-v /dev/bus/usb:/dev/bus/usb \
#	-v /dev/bus/usb/003:/dev/bus/usb/003 \
#	--mac-address="aa:bb:cc:dd:ee:ff" \
#	-v ~/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
# 	-v ~/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
#	--volume="/etc/machine-id:/etc/machine-id" \
#	-u `id -u`:`id -g` \
#	--net=host \

#	 sudo chmod o+rw /var/run/docker.sock

#visudo
# Cmnd alias specification
#Cmnd_Alias DOCKER_CMD=/usr/bin/docker run *
#someuser ALL=(root) NOPASSWD: DOCKER_CMD
