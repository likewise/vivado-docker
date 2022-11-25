FROM ubuntu:22.04

# Building the Docker image
#
# A HTTP(S) host must serve out the Xilinx_Unified_2020.2_1118_1232.tar.gz and petalinux-v2020.2-final-installer.run
# An easy way is to run a temporary server
# python3 -m http.server 8000
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
# without .tar.gz suffix
ARG VIVADO_TAR_FILE="Xilinx_Unified_2022.2_1014_8888"
ARG VIVADO_VERSION="2022.2"
ARG PETALINUX_RUN_FILE="petalinux-v2022.2-10141622-installer.run"

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

RUN  locale-gen --purge en_US.UTF-8
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

# copy in the license file
RUN mkdir -p .Xilinx

COPY --chown=vivado petalinux-accept-eula.sh /home/vivado

#RUN /${VIVADO_TAR_FILE}/xsetup --agree 3rdPartyEULA,XilinxEULA --batch Install --config install_config.txt && \
#  rm -rf ${VIVADO_TAR_FILE}*

#add vivado tools to path (root)
#RUN echo "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" >> /home/vivado/.bashrc

#copy in the license file (root)
#RUN mkdir -p /root/.Xilinx
RUN mkdir -p /home/vivado/.Xilinx

# download and run the install
RUN echo "Downloading and extracting ${VIVADO_TAR_FILE} from ${VIVADO_TAR_HOST}" && \
  wget -O- ${VIVADO_TAR_HOST}/${VIVADO_TAR_FILE}.tar.gz -q | \
  tar xzvf -

# If the following fails for a newer version of Xilinx, because of new configuration
# options, look for the latest image and manually create a new install_config.txt.
# docker image ls -a
# docker run -ti <latest-image> /bin/bash
# And then inside the container run:
# ./xsetup -b ConfigGen

# copy installation configuration for Vitis
COPY install_config.txt /
RUN cp -a /install_config.txt .
RUN ${VIVADO_TAR_FILE}/xsetup --agree XilinxEULA,3rdPartyEULA  --batch Install --config install_config.txt && \
  rm -rf ${VIVADO_TAR_FILE}*

USER root
WORKDIR /root

# Install Xilinx cable drivers
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  udev usbutils
RUN cd /opt/Xilinx/Vivado/2022.2/data/xicom/cable_drivers/lin64/install_script/install_drivers && ./install_drivers

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  dbus-x11 

#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  libnotify4 libnss3 libxss1 xdg-utils libsecret-1-0
#RUN wget https://github.com/jgraph/drawio-desktop/releases/download/v20.3.0/drawio-amd64-20.3.0.deb && \
#  dpkg -i drawio-amd64-20.3.0.deb && rm drawio-amd64-20.3.0.deb

USER vivado
WORKDIR /home/vivado

# Install 'pipelinec' executable
RUN git clone https://github.com/JulianKemmerer/PipelineC.git && \
  echo "export PATH=$PATH:PipelineC/src" >> /home/vivado/.bashrc

#RUN curl -O- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-10-26/oss-cad-suite-linux-x64-20221026.tgz | tar xzvf && \
RUN wget -qO- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-11-25/oss-cad-suite-linux-x64-20221125.tgz | tar xzv
RUN sed -i 's@OSS_CAD_SUITE_PATH = .*@OSS_CAD_SUITE_PATH = "/home/vivado/oss-cad-suite"@' PipelineC/src/OPEN_TOOLS.py

USER root
WORKDIR /root

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  x11-apps gosu

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-l"]