.ONESHELL:

build:
	docker build --network=host -t vivado .
run:
	docker run -ti --rm -e DISPLAY=$(DISPLAY) -v /tmp/.X11-unix:/tmp/.X11-unix -v $$PWD:/home/vivado/project -v ~/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro -w /home/vivado/project vivado:latest

remote:
	# Prepare target env
	export CONTAINER_DISPLAY="0"
	export CONTAINER_HOSTNAME="vivado-container"

	# Create a directory for the socket
	rm -rf display
	mkdir -p display/socket
	touch display/Xauthority

	# Get the DISPLAY slot
	export DISPLAY_NUMBER=$$(echo $$DISPLAY | cut -d. -f1 | cut -d: -f2)
	echo "DISPLAY_NUMER=$$DISPLAY_NUMBER"

	# Extract current authentication cookie
	export AUTH_COOKIE=$$(xauth list | grep "^$$(hostname)/unix:$${DISPLAY_NUMBER} " | awk '{print $$3}')
	echo "AUTH_COOKIE=$$AUTH_COOKIE"

	# Create the new X Authority file
	xauth -f display/Xauthority add $${CONTAINER_HOSTNAME}/unix:$${CONTAINER_DISPLAY} MIT-MAGIC-COOKIE-1 $${AUTH_COOKIE}

	# Proxy with the :0 DISPLAY
	socat UNIX-LISTEN:display/socket/X$${CONTAINER_DISPLAY},fork TCP4:localhost:60$${DISPLAY_NUMBER} &

	# if user id inside docker container differs from host id
	# we need to provide access for this other user
	# inspired by https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
	chmod ugo+rwx -R display
	# not sure why this is ALSO needed
	setfacl -R -m user:1000:rwx display

	# Launch the container
	docker run -it --rm \
	-u `id -u`:`id -g` \
	-e DISPLAY=:$${CONTAINER_DISPLAY} \
	-e XAUTHORITY=/tmp/.Xauthority \
	-v $${PWD}/display/socket:/tmp/.X11-unix \
	-v $${PWD}/display/Xauthority:/tmp/.Xauthority \
	-v $$PWD:/home/vivado/project \
	-v ~/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro \
	--hostname $${CONTAINER_HOSTNAME} \
	-w /home/vivado/project \
	vivado
