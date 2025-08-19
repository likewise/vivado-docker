FROM ubuntu:22.04

# Building the Docker image
#
# A HTTP(S) host must serve out the Xilinx_Unified_2020.2_1118_1232.tar.gz and petalinux-v2020.2-final-installer.run
# An easy way is to run a temporary server
# python3 -m http.server --bind 127.0.0.1 8000
#
# build with
# docker build --network=host -t vivado .
#
# If "Downloading and extracting Xilinx_Unified_2021.2_1021_0703 from http://..." fails, check if the HTTP server
# is accessible.
#
# You can override the ARG default (see below) on the command line, or adapt this Dockerfile.
# docker build --network=host --build-arg VIVADO_TAR_HOST=http://host:port -t vivado .
#
ARG VIVADO_TAR_HOST="http://localhost:8000"
# without .tar(.gz) suffix
#ARG VIVADO_TAR_FILE="Xilinx_Unified_2021.2_1021_0703"
#ARG VIVADO_TAR_FILE="Xilinx_Unified_2023.1_0507_1903"
ARG VIVADO_BIN_FILE="FPGAs_AdaptiveSoCs_Unified_SDI_2025.1_0530_0145_Lin64.bin"
ARG VIVADO_VERSION="2025.1"
#ARG PETALINUX_RUN_FILE="petalinux-v2022.2-10141622-installer.run"

# only available during build
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
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
  libtinfo5 \
  git \
  expect \
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

RUN chmod ugo+rwx /opt

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


# make a new user called vivado
RUN adduser --disabled-password --gecos '' vivado

RUN mkdir /etc/sudoers.d
RUN echo >/etc/sudoers.d/vivado 'vivado ALL = (ALL) NOPASSWD: SETENV: ALL'

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  apt-utils sudo nano

# remaining build steps are run as this user; this is also the default user when the image is run.
USER vivado
WORKDIR /home/vivado

# create user settings directory for Xilinx, i.e. where to copy in the license file etc.
RUN mkdir -p .Xilinx

COPY --chown=vivado petalinux-accept-eula.sh /home/vivado

#RUN /${VIVADO_TAR_FILE}/xsetup --agree 3rdPartyEULA,XilinxEULA --batch Install --config install_config.txt && \
#  rm -rf ${VIVADO_TAR_FILE}*

# download and run the full installer
#RUN echo "Downloading and extracting ${VIVADO_TAR_FILE} from ${VIVADO_TAR_HOST}" && \
#  wget -O- ${VIVADO_TAR_HOST}/${VIVADO_TAR_FILE}.bin -q | \
#  tar xvf -

# download and run the full installer
RUN echo "Downloading and extracting ${VIVADO_BIN_FILE} from ${VIVADO_TAR_HOST}" && \
  wget ${VIVADO_TAR_HOST}/${VIVADO_BIN_FILE}

RUN chmod +x ${VIVADO_BIN_FILE}
RUN ./${VIVADO_BIN_FILE} --keep --noexec --target ./web-installer

WORKDIR /home/vivado/web-installer
COPY authtokengen.expect .
COPY email-password.secret .
COPY install_config.txt .
RUN ./authtokengen.expect `cat email-password.secret | tr '\n' ' '`
RUN rm -f authtokengen.expect email-password.secret
RUN ./xsetup -a XilinxEULA,3rdPartyEULA --batch Install --config install_config.txt
WORKDIR /home/vivado
RUN rm -rf ./${VIVADO_BIN_FILE} web-installer

# If the above fails for a newer version of Xilinx, because of new configuration
# options, look for the latest image and manually create a new install_config.txt.
# docker image ls -a
# docker run -ti <latest-image> /bin/bash
# And then inside the container run:
# ./xsetup -b ConfigGen

USER root
WORKDIR /root

# Install Xilinx cable drivers
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  udev usbutils
RUN cd /opt/Xilinx/${VIVADO_VERSION}/Vivado/data/xicom/cable_drivers/lin64/install_script/install_drivers && ./install_drivers

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  dbus-x11 

USER vivado
WORKDIR /home/vivado

# Alveo U50 board files
#RUN wget ${VIVADO_TAR_HOST}/au50_boardfiles_v1_3_20211104.zip && \
#cd /opt/Xilinx/Vivado/${VIVADO_VERSION}/data/xhub/boards/XilinxBoardStore/boards/Xilinx/ && \
#unzip /home/vivado/au50_boardfiles_v1_3_20211104.zip && \
#chmod ugo+rx -R . && \
#cd && rm au50_boardfiles_v1_3_20211104.zip

COPY create-container-user.sh /usr/local/bin/create-container-user.sh

RUN mkdir -p .Xilinx/Vivado
RUN ls -ald .Xilinx
RUN ls -ald .Xilinx/Vivado

USER root
WORKDIR /root

# use double quotes so that the variables get expanded during docker build
RUN echo "source /opt/Xilinx/${VIVADO_VERSION}/Vivado/settings64.sh" >> /etc/bash.bashrc

RUN adduser --disabled-password --gecos '' vivado-docker-1001
RUN adduser --disabled-password --gecos '' vivado-docker-1002
RUN adduser --disabled-password --gecos '' vivado-docker-1003

# Workaround for https://support.xilinx.com/s/article/000034450
# https://adaptivesupport.amd.com/s/article/000034450?language=en_US
# https://support.xilinx.com/s/question/0D54U00005Sgst2SAB/failed-batch-mode-execution-in-linux-docker-running-under-windows-host?language=en_US&t=1670020489603
RUN sed -i 's@export XILINX_VIVADO@export XILINX_VIVADO\nexport LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1@' /opt/Xilinx/${VIVADO_VERSION}/Vivado/bin/vivado

RUN adduser --disabled-password --gecos '' vivado-docker-1004
RUN adduser --disabled-password --gecos '' vivado-docker-1005
RUN adduser --disabled-password --gecos '' vivado-docker-1006
RUN adduser --disabled-password --gecos '' vivado-docker-1007
RUN adduser --disabled-password --gecos '' vivado-docker-1008
RUN adduser --disabled-password --gecos '' vivado-docker-1009
RUN adduser --disabled-password --gecos '' vivado-docker-1010
RUN adduser --disabled-password --gecos '' vivado-docker-1011
RUN adduser --disabled-password --gecos '' vivado-docker-1012
RUN adduser --disabled-password --gecos '' vivado-docker-1013

RUN apt-get install -y \
  iputils-ping iproute2

# Not the best solution, but symlink to the 100G license.
# @TODO run this as a for loop as root, but make sure ownership is on users
USER vivado-docker-1001
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1002
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1003
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1004
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1005
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1006
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1007
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1008
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1009
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1010
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1011
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1012
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
USER vivado-docker-1013
RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic

WORKDIR /project-on-host/

USER root
WORKDIR /root

# Yocto
RUN apt-get install -y \
build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd

# xpra
RUN apt-get install -y \
dialog

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
keyboard-configuration

RUN mkdir -p /run/user/1000/xpra
RUN chown vivado:vivado /run/user/1000/xpra

#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
#xpra
#xfce4

RUN wget -O "/usr/share/keyrings/xpra.asc" https://xpra.org/xpra.asc
RUN cd /etc/apt/sources.list.d && wget https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/jammy/xpra.sources
RUN DEBIAN_FRONTEND=noninteractive apt update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q xpra

USER vivado
WORKDIR /project-on-host/

RUN xpra --version


#COPY entrypoint.sh /usr/local/bin/entrypoint.sh
#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
#CMD ["/bin/bash", "-l"]

