FROM ubuntu:22.04

# Building the Docker image
#
# A HTTP(S) host must serve out the Xilinx_Unified_2020.2_1118_1232.tar.gz and petalinux-v2020.2-final-installer.run
# An easy way is to run a temporary server
# python3 -m http.server --bind 127.0.0.1 8000
#
# build with
# docker build --network=host -t radiant .
#
# If "Downloading and extracting Xilinx_Unified_2021.2_1021_0703 from http://..." fails, check if the HTTP server
# is accessible.
#
# You can override the ARG default (see below) on the command line, or adapt this Dockerfile.
# docker build --network=host --build-arg RADIANT_ZIP_HOST=http://host:port -t radiant .
#
ARG RADIANT_ZIP_HOST="http://localhost:8000"
# without .zip suffix
ARG RADIANT_ZIP_FILE="2025.1.0.39.0_Radiant_Programmer_lin" 
#ARG UPDATE_ZIP_FILE="2023.2.1.288.0_Radiant_update_lin"
#ARG RADIANT_VERSION="2025.1"
ARG RADIANT_VERSION="2025.1.0.39.0"
#ARG UPDATE_VERSION="2023.2.1.288.0"

# only available during build
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true

# Running the Docker image in a Docker container
#
# docker run -ti --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
# -v $PWD:/home/radiant/project -v $HOME/.Xilinx/Xilinx.lic:/home/radiant/.Xilinx/:ro -w /home/radiant/project radiant:latest
#
# The current directory on the host is mounted as read-write in the container.
# The license file of the host is mounted read-only. See the --mac-address= flag for docker run.

# Update the apt-repo and upgrade and re-update while the apt-cache may be invalid
RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y -qq \
  nano vim software-properties-common locales localepurge apt-utils

# Set BASH as the default shell
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true dpkg-reconfigure dash

ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN locale-gen "en_US.UTF-8"
RUN update-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en"

# Generate and configure the character set encoding to en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

# If apt-get install were in a separate RUN instruction, then it would reuse a layer added by apt-get update,
# which could had been created a long time ago.

#install dependences for:
# * downloading radiant: wget
# * xsim: build-essential, which contains gcc and make)
# * MIG tool: libglib2.0-0 libsm6 libxi6 libxrender1 libxrandr2 libfreetype6 libfontconfig
# * CI git
#
# * PetaLinux: expect ... libncurses5-dev 
RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y -qq \
  wget \
  curl \
  libarchive-tools \
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


# make a new user called radiant
RUN adduser --disabled-password --gecos '' radiant

RUN mkdir /etc/sudoers.d
RUN echo >/etc/sudoers.d/radiant 'radiant ALL = (ALL) NOPASSWD: SETENV: ALL'

RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
  apt-utils sudo nano

# remaining build steps are run as this user; this is also the default user when the image is run.
USER radiant
WORKDIR /home/radiant

## copy in the license file
#RUN mkdir -p .Xilinx

#COPY --chown=radiant petalinux-accept-eula.sh /home/radiant

#RUN /${RADIANT_ZIP_FILE}/xsetup --agree 3rdPartyEULA,XilinxEULA --batch Install --config install_config.txt && \
#  rm -rf ${RADIANT_ZIP_FILE}*

#copy in the license file (root)
#RUN mkdir -p /root/.Xilinx
#RUN mkdir -p /home/radiant/.Xilinx

RUN netstat -lt4n

# download and run the install
RUN echo "Downloading and extracting ${RADIANT_ZIP_FILE} from ${RADIANT_ZIP_HOST}" && \
wget -O- ${RADIANT_ZIP_HOST}/${RADIANT_ZIP_FILE}.zip -q | \
bsdtar xvf - && \
chmod +x ${RADIANT_ZIP_FILE}.run

#RUN echo "Downloading and extracting ${UPDATE_ZIP_FILE} from ${RADIANT_ZIP_HOST}" && \
#  wget -O- ${RADIANT_ZIP_HOST}/${UPDATE_ZIP_FILE}.zip -q | \
#  bsdtar xvf - && \
#  chmod +x ${UPDATE_VERSION}_Radiant_update.run

RUN ls -ald 2025*

RUN ./${RADIANT_ZIP_FILE}.run --console --prefix=/opt/lattice --verbose
#RUN find /opt | grep check
#RUN ./${UPDATE_VERSION}_Radiant_update.run --console --prefix=/opt/lattice --verbose
#RUN bash /opt/lattice/bin/lin64/check_systemlibrary_radiant.bash
#RUN cat check_systemlibrary.log | grep -e "is missing" | sed 's@[^\s]is missing@@' | sed 's@ i386@:i386@' | sed 's@\sin the system.*@@'

# If the following fails for a newer version of Xilinx, because of new configuration
# options, look for the latest image and manually create a new install_config.txt.
# docker image ls -a
# docker run -ti <latest-image> /bin/bash
# And then inside the container run:
# ./xsetup -b ConfigGen

# copy installation configuration for radiant
#COPY install_config.txt /
#RUN cp -a /install_config.txt .
#RUN ${RADIANT_ZIP_FILE}/xsetup --agree XilinxEULA,3rdPartyEULA  --batch Install --config install_config.txt && \
#  rm -rf ${RADIANT_ZIP_FILE}*
#
USER root
WORKDIR /root

RUN apt-cache search libtheora 

RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y -qq \
libjpeg-dev \
libieee1284-3 \
libusb-0.1.4 \
lsb-core \
libnss3 \
# added .1
libxslt1.1 \
libxss1 \
pulseaudio \
libxcb-xinput0 \
libxcb-image0 \
libxcb-keysyms1 \
libxcb-render-util0 \
libxcb-xkb1 \
libxcb-xinerama0 \
libxkbcommon-x11-0 \
libxcb-icccm4 \
cdparanoia \
# added lib...0
libopus0 \
# added 0
libtheora0 \
# added -0.4.0
libvisual-0.4.0 \
gstreamer1.0-plugins-base \
libgl1-mesa-glx \
# rename libstdc++6:i386 to libx32stdc++6
libx32stdc++6 \
#libstdc++6:i386 \
bzip2:i386 \
libfontconfig1:i386 \
libexpat1:i386 \
libfreetype6:i386 \
libncurses5:i386 \
zlib1g:i386 \
libpng16-16:i386 \
libuuid1:i386 \
libxcb1:i386 \
libxau6:i386 \
libx11-6:i386 \
libxext6:i386 \
libxft2:i386 \
libxrender1:i386 \
libegl1-mesa \
libopengl0 \
libxcb-cursor0



RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y -qq \
iproute2 usbutils

RUN DEBIAN_FRONTEND=noninteractive dpkg --add-architecture i386 
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y -qq \
strace libusb-1.0.0
#
## Install Xilinx cable drivers
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  udev usbutils
#RUN cd /opt/Xilinx/radiant/${RADIANT_VERSION}/data/xicom/cable_drivers/lin64/install_script/install_drivers && ./install_drivers
#


#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y cairo
#
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#atk \
#cairo \
#pango \
#pulseaudio \
#libc6 \
#libjpeg-dev \
#libieee1284-3 \
#libusb-0.1.4 \
#lsb-core \
#libnss3 \
#libice \
#libgl \
#libgl1 \
#libglx0 \
#libgl-mesa-glx \
#libsm \
#libxt \
#libxtst6 \
#libdbus-1-3 \
#libxext \
#libxrender \
#libxi \
#libxft \
#libxslt \
#libxrandr \
#libxfixes \
#libxdamage \
#libxcursor \
#libxcomposite \
#libxinerama \
#libxss1 \
#libxcb-image0 \
#libxcb-keysyms1 \
#libxcb-render-util0 \
#libxcb-xkb1 \
#libxcb-shape0 \
#libxcb-xinput0 \
#libxcb-xinerama0 \
#libxkbcommon0 \
#libxkbcommon-x11-0 \
#libxcb-icccm4 \
#libx11 \
#libgl1-mesa-dri \
#libgstreamer1.0-0 \
#libxv1 \
#cdparanoia \
#opus \
#libtheora \
#iso-codes \
##libvisual \
#gstreamer1.0-plugins-base
#
#USER radiant
#WORKDIR /home/radiant
#RUN ./2023.1.0.43.3_Radiant_lin.run
#

#
##RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
##  libnotify4 libnss3 libxss1 xdg-utils libsecret-1-0
##RUN wget https://github.com/jgraph/drawio-desktop/releases/download/v20.3.0/drawio-amd64-20.3.0.deb && \
##  dpkg -i drawio-amd64-20.3.0.deb && rm drawio-amd64-20.3.0.deb
#
## VexRiscv
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  software-properties-common \
#  scala build-essential git make autoconf g++ flex bison \
#  autoconf \
#  x11-apps gosu \
#  curl
#
#RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
#RUN echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | sudo tee /etc/apt/sources.list.d/sbt_old.list
#RUN curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
#
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  sbt
#
## OpenOCD mainstream
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  libftdi1 libftdi1-dev libusb-1.0.0-dev make libtool pkg-config \ 
#  libz-dev gdb \
#  locales autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev \
#  pkg-config libtool libyaml-dev libftdi-dev libusb-1.0.0
#
#RUN curl -sL "https://nav.dl.sourceforge.net/project/openocd/openocd/0.12.0-rc2/openocd-0.12.0-rc2.tar.bz2" | tar xj
#RUN cd openocd-0.12.0-rc2 && ./configure --enable-ftdi && make install -j16
#
## OpenOCD VexRiscv fork
#RUN git clone https://github.com/SpinalHDL/openocd_riscv openocd_vexriscv && cd openocd_vexriscv && \
#./bootstrap && ./configure --enable-xlnx-pcie-xvc --prefix=/opt/openocd-vexriscv && make -j16 install && cd ..
#
## killall netstat lsusb. default-jdk to build simulation support for verilator (jni.h was missing)
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  psmisc net-tools usbutils default-jdk-headless \
#  openjdk-11-jdk \
#  srecord \
#  python3-setuptools libevent-dev libjson-c-dev
## verilator # Litex
#
## download vexriscv and instantiate to download the dependencies
## the SBT cache at ~/.ivy2 will be populated
#RUN git clone https://github.com/SpinalHDL/VexRiscv.git vexriscv && \
#cd vexriscv && \
#sbt "runMain vexriscv.demo.VexRiscvAxi4WithIntegratedJtag" && \
#cd ~/ && rm -rf vexriscv
#
## Yosys, netlistsvg (depends on npm) to generate RTL netlist images
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  npm yosys
#RUN npm install -g netlistsvg
#
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  gtkwave
#
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  python3 python3-pip iverilog gtkwave
#RUN pip3 install cocotb cocotb-bus cocotb-test cocotbext-axi cocotbext-eth cocotbext-pcie cocotbext-uart pytest scapy tox pytest-xdist pytest-sugar
#
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#  bsdmainutils telnet \
#  inotify-tools gconf2 # gtkwave refresh attempt
#
## Symbiyosys symbiyosys-build
####RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
####  build-essential clang bison flex libreadline-dev \
####  gawk tcl-dev libffi-dev git mercurial graphviz   \
####  xdot pkg-config python python3 libftdi-dev gperf \
####  libboost-program-options-dev autoconf libgmp-dev \
####  cmake python-dev python3-dev
#
## https://github.com/five-embeddev/riscv-scratchpad/blob/master/cmake/cmake/riscv.cmake
## https://keithp.com/picolibc/
## https://crosstool-ng.github.io/docs/build/
#
## Install dependencies for:
## crosstool-ng
## picolibc
## qemu
## (dependencies per line)
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#unzip help2man libtool-bin libncurses5-dev \
#python3 meson \
#libglib2.0 libpixman-1-dev device-tree-compiler
## device-tree-compiler is not a hard dependency but can be used
## to modify virtual machines in qemu using a modified dtb
#
#USER radiant
#WORKDIR /home/radiant
#
## build and install qemu to /opt
#RUN git clone --depth=1 https://github.com/qemu/qemu.git && cd qemu && \
#./configure --target-list=riscv32-softmmu --prefix=/opt && \
#make -j8 install && cd .. && rm -rf qemu
#
## build and install ct-ng to /opt
#RUN (curl http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.xz | tar xJ) && \
#cd crosstool-ng-1.25.0 && ./configure --prefix=/opt && make -j8 install && cd .. && rm -rf crosstool-ng-1.25.0
#
## copy ct-ng configuration to build a cross toolchain for riscv, with picolibc companion library enabled
#RUN ls -al /opt/share/crosstool-ng/samples/ | grep riscv
#
## add crosstool configuration for riscv with newlib and picolibc, this contains the install path also
## wow, the ADD/COPY command syntax is really horrible if you want to copy directories recursively...#
#ADD --chown=radiant:radiant riscv32-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc
#
## switch to picolib 1.7.9
#RUN sed -ri 's@^CT_PICOLIBC_DEVEL_BRANCH=.*@CT_PICOLIBC_DEVEL_BRANCH="1.7.9"@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config && \
#grep -e 'CT_PICOLIBC_DEVEL_BRANCH="1.7.9"' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
## enable GCC test suite
#RUN sed -ri 's@^(# CT_TEST_SUITE_GCC is not set|CT_TEST_SUITE_GCC=.*)@CT_TEST_SUITE_GCC=y@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
#
## verify that the configuration is in place
#RUN head /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
#
## switch to user to build the cross toolchain
#USER radiant
#WORKDIR /home/radiant
#
## configure crosstool-ng to build a riscv32 picolibc toolchain and fetch sources
#RUN mkdir crosstool-riscv32 && cd crosstool-riscv32 && /opt/bin/ct-ng riscv32-unknown-elf-picolibc && /opt/bin/ct-ng source \
#&& /opt/bin/ct-ng build
#
## make cross toolchain and qemu available during container build
#ENV PATH="${PATH}:/opt/x-tools/riscv32-unknown-elf/bin:/opt/bin"
#
## build the hello world example, run it semihosted in qemu and verify it runs correctly
#RUN git clone --branch=1.7.9 --depth=1 https://github.com/picolibc/picolibc.git && \
#cd picolibc/hello-world && sed -i 's@riscv64@riscv32@' Makefile && make hello-world-riscv.elf && ./run-riscv 2>&1 | grep -e 'hello, world'
#
#RUN chmod go+rx /home/radiant 
#
## Entrypoint
##USER root
##WORKDIR /root
#
## Alveo U50 board files
#RUN wget ${RADIANT_ZIP_HOST}/au50_boardfiles_v1_3_20211104.zip && \
#cd /opt/Xilinx/radiant/${RADIANT_VERSION}/data/xhub/boards/XilinxBoardStore/boards/Xilinx/ && \
#unzip /home/radiant/au50_boardfiles_v1_3_20211104.zip && \
#chmod ugo+rx -R . && \
#cd && rm au50_boardfiles_v1_3_20211104.zip
#
#COPY create-container-user.sh /usr/local/bin/create-container-user.sh
#
#USER root
#WORKDIR /root
#
## use double quotes so that the variables get expanded during docker build
#RUN echo "source /opt/Xilinx/radiant/${RADIANT_VERSION}/settings64.sh" >> /etc/bash.bashrc
#
## use single quotes so that the variables do not get expanded during docker build
#RUN echo 'export PATH=$PATH:/opt/x-tools/riscv32-unknown-elf/bin:/opt/bin' >> /etc/bash.bashrc
#
#RUN adduser --disabled-password --gecos '' radiant-docker-1001
#RUN adduser --disabled-password --gecos '' radiant-docker-1002
#RUN adduser --disabled-password --gecos '' radiant-docker-1003
#
## Verilator 4.100
#RUN git clone http://git.veripool.org/git/verilator && cd verilator && git checkout v4.100 && \
#  autoconf && ./configure && make -j8 && make install
#
## GHDL
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#build-essential libboost-dev git gnat \
## for GHDL LLVM backend
#clang llvm
#
## GHDL LLVM backend with backtrace support via libbacktrace from GCC
#RUN git clone --single-branch --branch master --depth=1 https://github.com/gcc-mirror/gcc.git && \
#cd gcc/libbacktrace && ./configure && make -j16 && cp -a .libs/libbacktrace.a ../..
#
## GHDL LLVM backend with backtrace support via libbacktrace from GCC
#RUN git clone https://github.com/ghdl/ghdl.git && \
#cd ghdl && mkdir build && cd build && ../configure --with-llvm-config --prefix=/usr/local --with-backtrace-lib=../../libbacktrace.a && make -j8 && make install
#
## Something drags in verilator as a dependency, but an older version (v4.038) than the one we 
## built above (which is in /usr/local). Remove the one in /usr/
#RUN apt-get remove verilator
#
## Surelog dependencies
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#build-essential cmake git pkg-config tclsh swig uuid-dev libgoogle-perftools-dev python3 python3-orderedmultidict python3-psutil python3-dev default-jre lcov
#
#USER root
#WORKDIR /
#
## to create TAP0 for testing purposes (CocoTB)
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#iproute2 uml-utilities iputils-ping netcat \
## to create Wireguard packets from within container
#wireguard-tools
#
## we used this once, then we stored the private key here -- this is the private key of the container guest
##RUN cd /etc/wireguard/ && wg genkey > /etc/wireguard/private.key && chmod go= /etc/wireguard/private.key && \
#
##RUN cd /etc/wireguard/ && echo "MIuE1NHyNFf++dzYbFkn3pn9ouRVUtSHShYL791NcEg=" > /etc/wireguard/private.key && chmod go= /etc/wireguard/private.key && \
##cat /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key && echo -en "[Interface]\nPrivateKey = " > /etc/wireguard/wg0.conf && \
##chmod go= /etc/wireguard/wg0.conf && \
##cat private.key >> /etc/wireguard/wg0.conf && echo -en "Address = 10.8.0.1/24\n\n" >> /etc/wireguard/wg0.conf && \
##echo -en "[Peer]\nPublicKey = X6NJW+IznvItD3B5TseUasRPjPzF0PkM5+GaLIjdBG4=\nAllowedIPs = 10.8.0.0/24\nEndpoint = 192.168.255.2:51820\n" >> /etc/wireguard/wg0.conf
### matches the hard-coded private key inside wg_lwip.
#
## we might not copy/create this directory with COPY, but need it later
#RUN mkdir -p /etc/wireguard
##COPY wireguard/wg0.conf /etc/wireguard/wg0.conf
#
## This will copy the folder contents, even if empty.
#COPY wireguard/. /etc/wireguard/
## If a wg0.conf was provided, protect it.
#RUN if [ -f /etc/wireguard/wg0.conf ]; then chmod go= /etc/wireguard/wg0.conf; fi
#
#USER radiant
#WORKDIR /home/radiant
#
## Workaround for https://support.xilinx.com/s/article/000034450
## https://support.xilinx.com/s/question/0D54U00005Sgst2SAB/failed-batch-mode-execution-in-linux-docker-running-under-windows-host?language=en_US&t=1670020489603
#RUN sed -i 's@export XILINX_radiant@export XILINX_radiant\nexport LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1@' /opt/Xilinx/radiant/${RADIANT_VERSION}/bin/radiant
#
## Install 'pipelinec' executable
#RUN git clone https://github.com/JulianKemmerer/PipelineC.git && \
#  echo 'export PATH=$PATH:$PWD/PipelineC/src' >> /home/radiant/.bashrc
#
## @TODO Document if/how we need OSS CAD Suite.
##
##RUN curl -O- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-10-26/oss-cad-suite-linux-x64-20221026.tgz | tar xzvf && \
#RUN wget -qO- https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2022-11-25/oss-cad-suite-linux-x64-20221125.tgz | tar xzv
#RUN sed -i 's@OSS_CAD_SUITE_PATH = .*@OSS_CAD_SUITE_PATH = "/home/radiant/oss-cad-suite"@' PipelineC/src/OPEN_TOOLS.py
#
#RUN mkdir -p .Xilinx
## This will copy the folder contents, even if empty.
## We put our private license in it, but not in GIT.
#COPY .Xilinx/. .Xilinx/
#
#USER root
#WORKDIR /
#
## Verilator 5.002, build from source
#RUN git clone http://git.veripool.org/git/verilator && cd verilator && git checkout v5.002 && \
#  autoconf && ./configure && make -j `nproc` && make install && cd .. && rm -rf verilator
#
## Build dependencies for GTKWave 3 build from source
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#tcl-dev tk-dev libgtk2.0-dev libbz2-dev
#
# # GTKWave 3, build from source
#RUN git clone --branch=lts --depth=1 https://github.com/gtkwave/gtkwave.git && cd gtkwave/gtkwave3-gtk3 && ./autogen.sh && \
#./configure && make -j16 && make install && cd .. && rm -rf gtkwave
#
## Remove build dependencies for GTKWave 3 build
#RUN apt-get remove -y \
#tcl-dev tk-dev libgtk2.0-dev libbz2-dev
#
## tcpdump and arping for network analysis
## graphviz and eog for binary tree analysis
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#tcpdump arping eog graphviz
#
## frug for generating IP address prefixes
##RUN (wget -O- https://sites.google.com/site/thilangane/frug.tar.gz?attredirects=0 | tar xz) && \
##cd frug && make && cp -a frug /usr/local/bin
#
## Needed if applications want to set up TAP0
#RUN echo "ALL ALL = NOPASSWD:/usr/sbin/setcap cap_net_admin=+pe" >>/etc/sudoers.d/cap_net
## Needed if Makefile's and scripts want to set up TAP0
#RUN echo "ALL ALL = NOPASSWD:/usr/sbin/ip" >>/etc/sudoers.d/ip
#
#RUN adduser --disabled-password --gecos '' radiant-docker-1004
#RUN adduser --disabled-password --gecos '' radiant-docker-1005
#RUN adduser --disabled-password --gecos '' vivado-docker-1006
#RUN adduser --disabled-password --gecos '' vivado-docker-1007
#RUN adduser --disabled-password --gecos '' vivado-docker-1008
#RUN adduser --disabled-password --gecos '' vivado-docker-1009
#RUN adduser --disabled-password --gecos '' vivado-docker-1010
#RUN adduser --disabled-password --gecos '' vivado-docker-1011
#RUN adduser --disabled-password --gecos '' vivado-docker-1012
#RUN adduser --disabled-password --gecos '' vivado-docker-1013
#
## Not the best solution, but symlink to the 100G license.
## @TODO run this as a for loop as root, but make sure ownership is on users
#USER vivado-docker-1001
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1002
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1003
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1004
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1005
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1006
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1007
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1008
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1009
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1010
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1011
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1012
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#USER vivado-docker-1013
#RUN mkdir -p ~/.Xilinx; ln -snf /home/vivado/.Xilinx/Xilinx.lic ~/.Xilinx/Xilinx.lic
#
#USER root
#WORKDIR /
#
## for pvpn 
#RUN pip3 install pproxy pycryptodome
#
## inspect UART and Ethernet, venv support for Python3
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#picocom wireshark python3-venv
#
##RUN git clone https://github.com/ghdl/ghdl-yosys-plugin.git && cd ghdl-yosys-plugin && make -j16
#
## Yosys
#RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
#	libreadline-dev gawk tcl-dev libffi-dev git \
#	graphviz xdot pkg-config python3 libboost-system-dev \
#	libboost-python-dev libboost-filesystem-dev zlib1g-dev
#
## Yosys 0.25
#RUN git clone --depth=1 --branch yosys-0.25 https://github.com/YosysHQ/yosys.git && cd yosys && make config-gcc && make -j16 && \
##make -j16 test && \
#make install && cd .. && rm -rf yosys
#
## ghdl-yosys-plugin: brings VHDL synthesis to Yosys
#RUN git clone https://github.com/ghdl/ghdl-yosys-plugin.git && cd ghdl-yosys-plugin && \
#git checkout d7b09b78b15e69c8f55d0461ef9254421c879010 && \
#make -j16 && make install && cd .. && rm -rf ghdl-yosys-plugin
#
#USER vivado
#WORKDIR /home/vivado
#
## apt install -y curl gcc make build-essential
#RUN (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y) && \
#(source "$HOME/.cargo/env" && \
#rustup update && \
#rustup component add llvm-tools-preview && \
#rustup target list \
#)
#
WORKDIR /project-on-host/
#
##COPY entrypoint.sh /usr/local/bin/entrypoint.sh
##ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
##CMD ["/bin/bash", "-l"]
#
#RUN find /home/vivado/.cache | grep sbt-bloop || true
#

USER radiant
WORKDIR /home/radiant
