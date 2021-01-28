.ONESHELL:

build:
	docker build --network=host -t vivado .
run:
	docker run -ti --rm -e DISPLAY=$(DISPLAY) -v /tmp/.X11-unix:/tmp/.X11-unix -v $$PWD:/home/vivado/project -v ~/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/Xilinx.lic:ro -w /home/vivado/project vivado:latest
