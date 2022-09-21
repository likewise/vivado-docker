FROM ubuntu:18.04

#AS vivado:2020.2

MAINTAINER Leon Woestenberg <leon@sidebranch.com>

# Building the Docker image
#
# A HTTP(S) host must serve out the Xilinx_Unified_2020.2_1118_1232.tar.gz and petalinux-v2020.2-final-installer.run
# An easy way is to run a temporary server
# python3 -m http.server 8000
#
# build with
# docker build --network=host -t vivado .
#
# If "Downloading and extracting Xilinx_Unified_2020.2_1118_1232 from http://..." fails, check if the HTTP server
# is accessible.
#
# You can override the ARG default (see below) on the command line, or adapt this Dockerfile.
# docker build --network=host --build-arg VIVADO_TAR_HOST=http://host:port -t vivado .
#
ARG VIVADO_TAR_HOST="http://localhost:8000"
ARG VIVADO_TAR_FILE="Xilinx_Unified_2020.2_1118_1232"
ARG VIVADO_VERSION="2020.2"
ARG PETALINUX_RUN_FILE="petalinux-v2020.2-final-installer.run"

# Running the Docker image in a Docker container
#
# docker run -ti --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
# -v $PWD:/home/vivado/project -v $HOME/.Xilinx/Xilinx.lic:/home/vivado/.Xilinx/:ro -w /home/vivado/project vivado:latest
#
# The current directory on the host is mounted as read-write in the container.
# The license file of the host is mounted read-only. See the --mac-address= flag for docker run.


# Set BASH as the default shell
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg-reconfigure dash

ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# If apt-get install were in a separate RUN instruction, then it would reuse a layer added by apt-get update,
# which could had been created a long time ago.

# Update the apt-repo and upgrade and re-update while the apt-cache may be invalid
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  nano vim software-properties-common locales apt-utils

# Generate and configure the character set encoding to en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

RUN locale-gen --purge en_US.UTF-8
RUN echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale

#install dependences for:
# * downloading Vivado: wget
# * xsim: build-essential, which contains gcc and make)
# * MIG tool: libglib2.0-0 libsm6 libxi6 libxrender1 libxrandr2 libfreetype6 libfontconfig
# * CI git
#
# * PetaLinux: expect ... libncurses5-dev 
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
  wget \
  build-essential \
  libglib2.0-0 \
  libsm6 \
  libxi6 \
  libxrender1 \
  libxrandr2 \
  libfreetype6 \
  libfontconfig \
  libgtk3.0 \
  git \
  \
  expect gawk net-tools xterm autoconf libtool \
  texinfo zlib1g-dev gcc-multilib libncurses5-dev \
  \
  && ldconfig

#RUN DEBIAN_FRONTEND=noninteractive \
#  && apt-get clean \
#  && apt-get autoremove \
#  && rm -rf /var/lib/apt/lists/* \
#  && ldconfig

# download and run the install
RUN echo "Downloading and extracting ${VIVADO_TAR_FILE} from ${VIVADO_TAR_HOST}" && \
  wget -O- ${VIVADO_TAR_HOST}/${VIVADO_TAR_FILE}.tar.gz -q | \
  tar xzvf -

# copy installation configuration for Vitis
COPY install_config.txt /
RUN /${VIVADO_TAR_FILE}/xsetup --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA --batch Install --config install_config.txt && \
  rm -rf ${VIVADO_TAR_FILE}*

#RUN Xilinx_Unified_2020.2

#add vivado tools to path (root)
RUN echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /root/.profile

#copy in the license file (root)
RUN mkdir -p /root/.Xilinx
# We do not want our license file to be in the image, we mount it during run.
#COPY Xilinx.lic /root/.Xilinx/

# Uncomplete attempt to get DocNav (32-bit) running, did not work
#RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 && \
#apt-get update && \
#apt-get install -y \
#lib32stdc++6 \
#libgtk2.0-0:i386 \
#libfontconfig1:i386 \
#libx11-6:i386 \
#libxext6:i386 \
#libxrender1:i386 \
#libsm6:i386 \
#libqtgui4:i386 \
#libgl1-mesa-dev \
#libnss3 \
#libasound2

#make a Vivado user
RUN adduser --disabled-password --gecos '' vivado

RUN mkdir /etc/sudoers.d
RUN echo >/etc/sudoers.d/vivado 'vivado ALL = (ALL) NOPASSWD: SETENV: ALL'

# remaining build steps are run as this user; this is also the default user when the image is run.
USER vivado
WORKDIR /home/vivado

# copy in the license file
RUN mkdir -p .Xilinx

COPY --chown=vivado petalinux-accept-eula.sh /home/vivado

#USER root
#
# expect is required by petalinux-accept-eula.sh
# gawk is required by petalinux installer
# rest is required by PetaLinux
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y expect gawk net-tools xterm autoconf libtool libtool \
#  texinfo zlib1g-dev gcc-multilib libncurses5-dev

USER vivado
WORKDIR /home/vivado

RUN echo "Downloading and extracting ${PETALINUX_RUN_FILE} from ${VIVADO_TAR_HOST}" && \
  wget ${VIVADO_TAR_HOST}/${PETALINUX_RUN_FILE} -q

USER root
RUN chmod +x ${PETALINUX_RUN_FILE}

# This list is taken from 
RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 && \
apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
iproute2 gawk python3 python build-essential gcc git make net-tools libncurses5-dev tftpd zlib1g-dev libssl-dev flex bison libselinux1 gnupg \
wget git-core diffstat chrpath socat xterm autoconf libtool tar unzip texinfo zlib1g-dev gcc-multilib automake zlib1g:i386 screen pax gzip cpio \
python3-pip python3-pexpect xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev pylint3

#COPY plnx-env-setup.sh /tmp/
#RUN chmod +x /tmp/plnx-env-setup.sh
#RUN /tmp/plnx-env-setup.sh

USER vivado
WORKDIR /home/vivado

RUN /home/vivado/petalinux-accept-eula.sh /home/vivado/${PETALINUX_RUN_FILE} /home/vivado/petalinux-2020.2
RUN rm -v ${PETALINUX_RUN_FILE}

# We do not want our license file to be in the image, we mount it during run.
#COPY Xilinx.lic .Xilinx/
# add Vivado tools to path

#RUN echo "export LD_LIBRARY_PATH=/opt/Xilinx/DocNav/lib/" >> /home/vivado/.profile
#RUN echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /home/vivado/.profile
#RUN echo "source /opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh" >> /home/vivado/.profile

#RUN echo "export LD_LIBRARY_PATH=/opt/Xilinx/DocNav/lib/" >> /home/vivado/.basrc
#RUN echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /home/vivado/.basrc
#RUN echo "source /opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh" >> /home/vivado/.bashrc

USER root

RUN apt-get install -y make gcc g++ python3 python3-dev python3-pip

RUN adduser --disabled-password --gecos '' vivado-docker-1001
RUN adduser --disabled-password --gecos '' vivado-docker-1002

RUN echo "export LD_LIBRARY_PATH=/opt/Xilinx/DocNav/lib/" > /etc/profile.d/vivado && \
echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /etc/profile.d/vivado && \
echo "source /opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh" >> /etc/profile.d/vivado && \
echo "export LD_LIBRARY_PATH=/opt/Xilinx/DocNav/lib/" > /etc/bash.bashrc && \
echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /etc/bash.bashrc &&\
echo "source /opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh" >> /etc/bash.bashrc && \
echo "#!/bin/sh" > /usr/local/bin/vivado_gui.sh && \
echo "export LD_LIBRARY_PATH=/opt/Xilinx/DocNav/lib/" >> /usr/local/bin/vivado_gui.sh && \
echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /usr/local/bin/vivado_gui.sh && \
echo "source /opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh" >> /usr/local/bin/vivado_gui.sh && \
echo "vivado" >> /usr/local/bin/vivado_gui.sh && \
chmod +x /usr/local/bin/vivado_gui.sh

RUN apt-get install -y python3 iverilog gtkwave
RUN pip3 install cocotb cocotb-bus cocotb-test cocotbext-axi cocotbext-eth cocotbext-pcie pytest scapy tox pytest-xdist pytest-sugar

# Not sure if this is going to break Vivado
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN apt-get install -y dbus-x11
RUN apt-get install -y udev usbutils
RUN cd /opt/Xilinx/Vivado/2020.2/data/xicom/cable_drivers/lin64/install_script/install_drivers && ./install_drivers

#RUN adduser vivado dialout
RUN usermod -aG dialout vivado

RUN python3 -m pip install --user -U pip setuptools

# Ibex FuseSoC
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
    autoconf bison build-essential clang-format cmake curl \
    doxygen flex g++ git golang lcov libelf1 libelf-dev libftdi1-2 \
    libftdi1-dev libncurses5 libssl-dev libudev-dev libusb-1.0-0 lsb-release \
    make ninja-build perl pkgconf python3 python3-pip python3-setuptools \
    python3-wheel srecord tree xsltproc zlib1g-dev xz-utils \
    srecord

COPY --chown=vivado fusesoc-python-requirements.txt .
RUN pip3 install -r fusesoc-python-requirements.txt
#RUN pip3 install Mako fusesoc markupsafe

#COPY vivado.xml /home/vivado/.Xilinx/Vivado/2020.2/vivado.xml
#RUN chown -R vivado:vivado /home/vivado/.Xilinx


# Digilent (Arty) board files https://reference.digilentinc.com/reference/software/vivado/board-files
# https://github.com/Digilent/vivado-boards/archive/master.zip
RUN curl --output /tmp/master.zip -L https://github.com/Digilent/vivado-boards/archive/master.zip?_ga=2.203386514.2020720558.1643112254-1582227075.1643112254 && cd /tmp/ && unzip master.zip && \
  cp -a vivado-boards-master/new/board_files/* /opt/Xilinx/Vivado/2020.2/data/boards/board_files/

RUN adduser --disabled-password --gecos '' vivado-docker-1003
RUN adduser --disabled-password --gecos '' vivado-docker-1004
RUN adduser --disabled-password --gecos '' vivado-docker-1005
RUN adduser --disabled-password --gecos '' vivado-docker-1006

USER vivado
WORKDIR /home/vivado

#COPY --chown=vivado fusesoc-python-requirements.txt .
#RUN pip3 install --user -U -r fusesoc-python-requirements.txt
#RUN pip3 install --user -U Mako fusesoc

#RUN pip3 install --user cocotb cocotb-bus

ENV COLORTERM="truecolor"
ENV TERM="xterm-256color"
RUN sed -i 's/01;32/01;33/g' /home/vivado/.bashrc

#USER root
