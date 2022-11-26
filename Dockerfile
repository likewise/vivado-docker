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
  echo "export PATH=$PATH:$PWD/PipelineC/src" >> /home/vivado/.bashrc

#RUN curl -O- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-10-26/oss-cad-suite-linux-x64-20221026.tgz | tar xzvf && \
RUN wget -qO- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-11-25/oss-cad-suite-linux-x64-20221125.tgz | tar xzv
RUN sed -i 's@OSS_CAD_SUITE_PATH = .*@OSS_CAD_SUITE_PATH = "/home/vivado/oss-cad-suite"@' PipelineC/src/OPEN_TOOLS.py


# VexRiscv
USER root
WORKDIR /root

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  software-properties-common \
  scala build-essential git make autoconf g++ flex bison \
  autoconf \
  x11-apps gosu \
  curl

RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
RUN curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  sbt

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  libftdi1 libftdi1-dev libusb-1.0.0-dev make libtool pkg-config \ 
  libz-dev gdb \
  locales autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev \
  pkg-config libtool libyaml-dev libftdi-dev libusb-1.0.0

RUN curl -sL "https://nav.dl.sourceforge.net/project/openocd/openocd/0.12.0-rc1/openocd-0.12.0-rc1.tar.bz2" | tar xj
RUN cd openocd-0.12.0-rc1 && ./configure --enable-ftdi && make install -j8

RUN git clone https://github.com/SpinalHDL/openocd_riscv && cd openocd_riscv && \
./bootstrap && ./configure --enable-xlnx-pcie-xvc --prefix=/opt/openocd-vexriscv && make -j16 install && cd ..

# killall netstat lsusb. default-jdk to build simulation support for verilator (jni.h was missing)
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  psmisc net-tools usbutils default-jdk-headless \
  openjdk-11-jdk \
  srecord \
  python3-setuptools libevent-dev libjson-c-dev verilator # Litex

# download vexriscv and instantiate to download the dependencies
# the SBT cache at ~/.ivy2 will be populated
RUN git clone https://github.com/SpinalHDL/VexRiscv.git vexriscv && \
cd vexriscv && \
sbt "runMain vexriscv.demo.VexRiscvAxi4WithIntegratedJtag" && \
cd ~/ && rm -rf vexriscv

# Yosys, netlistsvg (depends on npm) to generate RTL netlist images
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  npm yosys
RUN npm install -g netlistsvg

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  gtkwave

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  python3 python3-pip iverilog gtkwave
RUN pip3 install cocotb cocotb-bus cocotb-test cocotbext-axi cocotbext-eth cocotbext-pcie pytest scapy tox pytest-xdist pytest-sugar

RUN cd /opt && ln -snf riscv64-unknown-elf-gcc-20171231-x86_64-linux-centos6 riscv

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  bsdmainutils telnet \
  inotify-tools gconf2 # gtkwave refresh attempt

# Symbiyosys symbiyosys-build
###RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
###  build-essential clang bison flex libreadline-dev \
###  gawk tcl-dev libffi-dev git mercurial graphviz   \
###  xdot pkg-config python python3 libftdi-dev gperf \
###  libboost-program-options-dev autoconf libgmp-dev \
###  cmake python-dev python3-dev

# https://github.com/five-embeddev/riscv-scratchpad/blob/master/cmake/cmake/riscv.cmake
# https://keithp.com/picolibc/
# https://crosstool-ng.github.io/docs/build/

# Install dependencies for:
# crosstool-ng
# picolibc
# qemu
# (dependencies per line)
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
unzip help2man libtool-bin libncurses5-dev \
python3 meson \
libglib2.0 libpixman-1-dev device-tree-compiler
# device-tree-compiler is not a dependency but can be used
# to modify virtual machines in qemu using a modified dtb

# build and install qemu to /opt
RUN git clone https://github.com/qemu/qemu.git && cd qemu && ./configure --target-list=riscv32-softmmu --prefix=/opt && make -j8 install && cd .. && rm -rf qemu

# build and install ct-ng to /opt
RUN (curl http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.xz | tar xJ) && \
cd crosstool-ng-1.25.0 && ./configure --prefix=/opt && make -j8 install && cd .. && rm -rf crosstool-ng-1.25.0

# copy ct-ng configuration to build a cross toolchain for riscv, with picolibc companion library enabled
RUN ls -al /opt/share/crosstool-ng/samples/ | grep riscv

# add crosstool configuration for riscv with newlib and picolibc, this contains the install path also
# wow, the ADD/COPY command syntax is really horrible if you want to copy directories recursively...#
ADD riscv32-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc

# switch to picolib 1.7.9
RUN sed -ri 's@^CT_PICOLIBC_DEVEL_BRANCH=.*@CT_PICOLIBC_DEVEL_BRANCH="1.7.9"@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config && \
grep -e 'CT_PICOLIBC_DEVEL_BRANCH="1.7.9"' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
# enable GCC test suite
RUN sed -ri 's@^(# CT_TEST_SUITE_GCC is not set|CT_TEST_SUITE_GCC=.*)@CT_TEST_SUITE_GCC=y@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config

#ADD riscv64-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv64-unknown-elf-picolibc

# verify that the configuration is in place
RUN head /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config

# switch to user to build the cross toolchain
USER vivado
WORKDIR /home/vivado

# configure crosstool-ng to build a riscv32 picolibc toolchain and fetch sources
RUN mkdir crosstool-riscv32 && cd crosstool-riscv32 && /opt/bin/ct-ng riscv32-unknown-elf-picolibc && /opt/bin/ct-ng source \
&& /opt/bin/ct-ng build

#RUN echo 'export PATH=$PATH:/home/vexriscv/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc
RUN echo 'export PATH=$PATH:/home/vivado/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc

# make cross toolchain and qemu available during container build
ENV PATH="${PATH}:/home/vivado/x-tools/riscv32-unknown-elf/bin:/opt/bin"

# build the hello world example, run it semihosted in qemu and verify it runs correctly
RUN git clone --branch=1.7.9 --depth=1 https://github.com/picolibc/picolibc.git && \
cd picolibc/hello-world && sed -i 's@riscv64@riscv32@' Makefile && make hello-world-riscv.elf && ./run-riscv 2>&1 | grep -e 'hello, world'

RUN chmod go+rx /home/vivado 

# Entrypoint
#USER root
#WORKDIR /root

# Alveo U50 board files
RUN wget ${VIVADO_TAR_HOST}/au50_boardfiles_v1_3_20211104.zip && \
cd /opt/Xilinx/Vivado/2022.2/data/xhub/boards/XilinxBoardStore/boards/Xilinx/ && \
unzip /home/vivado/au50_boardfiles_v1_3_20211104.zip && \
chmod ugo+rx -R . && \
cd && rm au50_boardfiles_v1_3_20211104.zip



COPY create-container-user.sh /usr/local/bin/create-container-user.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
#RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-l"]