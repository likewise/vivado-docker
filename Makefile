VER=2.0.0

.ONESHELL:

build:
	docker build --network=host -t vivado:$(VER) .
run:
	docker run -ti --rm -e DISPLAY=$(DISPLAY) -v /tmp/.X11-unix:/tmp/.X11-unix -v $$PWD:/home/vivado/project -v ~/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro -w /home/vivado/project vivado:$(VER)

remote:
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

	# Launch the container
	docker run -it --rm \
	-u `id -u`:`id -g` \
	--mac-address="00:30:48:29:6b:04" \
	-e DISPLAY=:$${CONTAINER_DISPLAY} \
	-e XAUTHORITY=/tmp/.Xauthority \
	-v $${X11TMPDIR}/socket:/tmp/.X11-unix \
	-v $${X11TMPDIR}/Xauthority:/tmp/.Xauthority \
	-v $$PWD:/home/vivado/project \
	-v ~/.Xilinx/100G.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
	--hostname $${CONTAINER_HOSTNAME} \
	-w /home/vivado/project \
	--device-cgroup-rule 'c 188:* rmw' \
	--device-cgroup-rule 'c 189:* rmw' \
	-v /dev/ttyUSB0:/dev/ttyUSB0:rw \
	-v /dev/ttyUSB1:/dev/ttyUSB1:rw \
	-v /dev/ttyUSB2:/dev/ttyUSB2:rw \
	-v /dev/ttyUSB3:/dev/ttyUSB3:rw \
	-v /dev:/dev:rw \
	vivado:$(VER)

	rm -rf $${X11TMPDIR}


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
