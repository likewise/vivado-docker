VER=2.0.8

# make build   = rebuild the container image
# make remote  = run the container image on the host you are logged in to via SSH.

.ONESHELL:

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
run: guard-DISPLAY guard-USER assert-gitconfig
	echo "Make run is not well maintained, did you mean make remote?"
	exit
	docker run -ti --rm \
	--name vivado-$(USER) \
	--user `id -u`:`id -g` \
	--cap-add=NET_ADMIN \
	-e HOST_USER_NAME=`id -nu $${USER}` \
	-e HOST_USER_ID=`id -u $${USER}` \
	-e HOST_GROUP_ID=`id -g $${USER}` \
	-e DISPLAY=$(DISPLAY) \
	--network="host" \
	--device=/dev/bus \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v $$PWD:/project-on-host \
	-v ~/../shared/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
	-w /project-on-host \
	vivado:$(VER)

remote: guard-DISPLAY guard-USER assert-gitconfig
	# Prepare target env
	export CONTAINER_DISPLAY="0"
	export CONTAINER_HOSTNAME="vivado-container"

	# Create a directory for the socket
	rm -rf $${X11TMPDIR}
	export X11TMPDIR=`mktemp -d`
	mkdir -p $${X11TMPDIR}/socket
	touch $${X11TMPDIR}/Xauthority

	# Get the DISPLAY slot
	export DISPLAY_NUMBER=$$(echo $$DISPLAY | cut -d. -f1 | cut -d: -f2)
	echo "DISPLAY_NUMBER=$$DISPLAY_NUMBER"

	# Extract current authentication cookie
	export AUTH_COOKIE=$$(xauth list | grep "^$$(hostname)/unix:$${DISPLAY_NUMBER} " | awk '{print $$3}')
	echo "AUTH_COOKIE=$$AUTH_COOKIE"

	# Create the new X Authority file
	xauth -f $${X11TMPDIR}/Xauthority add $${CONTAINER_HOSTNAME}/unix:$${CONTAINER_DISPLAY} MIT-MAGIC-COOKIE-1 $${AUTH_COOKIE}

	# Proxy with the :0 DISPLAY
	socat UNIX-LISTEN:$${X11TMPDIR}/socket/X$${CONTAINER_DISPLAY},fork TCP4:localhost:60$${DISPLAY_NUMBER} &

	# if user id inside docker container differs from host id
	# we need to provide access for this other user
	# inspired by https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
	chmod ugo+rwx -R $${X11TMPDIR}
	# not sure why this is ALSO needed
	setfacl -R -m user:1000:rwx $${X11TMPDIR}

#	-v ~/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
#	-u `id -u`:`id -g` \
# replaced by -e HOST_USER_ID what is picked up by entrypoint.sh to
# create a matching user in the container, on the fly, and become that user
#--user `id -u`:`id -g` \

	# Launch the container
	docker run -it --rm \
	--name vivado-$(USER) \
	--user `id -u`:`id -g` \
	--cap-add=NET_ADMIN \
	-e HOST_USER_NAME=`id -nu $${USER}` \
	-e HOST_USER_ID=`id -u $${USER}` \
	-e HOST_GROUP_ID=`id -g $${USER}` \
	--mac-address="00:30:48:29:6b:04" \
	-e DISPLAY=:$${CONTAINER_DISPLAY} \
	-e XAUTHORITY=/tmp/.Xauthority \
	-v $${X11TMPDIR}/socket:/tmp/.X11-unix \
	-v $${X11TMPDIR}/Xauthority:/tmp/.Xauthority \
	-v $$PWD:/project-on-host \
	--hostname $${CONTAINER_HOSTNAME} \
	-w /project-on-host \
	--device-cgroup-rule 'c 188:* rmw' \
	--device-cgroup-rule 'c 189:* rmw' \
	-v /dev/ttyUSB0:/dev/ttyUSB0:rw \
	-v /dev/ttyUSB1:/dev/ttyUSB1:rw \
	-v /dev/ttyUSB2:/dev/ttyUSB2:rw \
	-v /dev/ttyUSB3:/dev/ttyUSB3:rw \
	-v /dev:/dev:rw \
	-v ~/../shared/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
	-v ~/../shared/wireguard:/etc/wireguard:ro \
	-v ~/.ssh:/home/vivado/.ssh:ro \
	-v ~/.ssh:/home/vivado-docker-`id -u $${USER}`/.ssh:ro \
	-v ~/.gitconfig:/home/vivado/.gitconfig:ro \
	-v ~/.gitconfig:/home/vivado-docker-`id -u $${USER}`/.gitconfig:ro \
	vivado:$(VER) || echo ERROR $$?

	rm -rf $${X11TMPDIR}


#	-v ~/../shared/.Xilinx/100G.lic:/home/vivado-docker-`id -u $${USER}`/.Xilinx/Xilinx.lic:ro \


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
