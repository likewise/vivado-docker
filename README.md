# vivado-docker

Vivado installed into a Docker image

## Build prerequisites

Docker or Podman.

The Dockerfile will try to download the Vivado installer from a (local)
web server. So run a HTTP server that hosts the Vivado stand-alone (full)
installer or the Vivado web-based installer.

For example; run `python3 -m http.server` in the folder with the Vivado
installer .tar or .bin file (See Dockerfile and Makefile).

Sometimes `--bind 127.0.0.1` is needed in addition to this.

## Build instructions

Run `make build` to create the container image.

## Running

Run `make remote` to start a container on the host. The host current working
directory is mounted as /project-on-host inside the container. The container
is accessible even from other peer hosts.

## Design

The Docker image is based on Ubuntu 22.04. The image has user "vivado" with user ID 1000.
Some tools are then installed as root, some as vivado.
User vivado has sudo rights inside the container.

The default user is vivado and the default work directory is /home/video (see Dockerfile:)
USER vivado
WORKDIR /home/vivado

Beyond this point, some more magic is performed.

# Future work

Podman rootless is in a branch now

https://www.redhat.com/sysadmin/debug-rootless-podman-mounted-volumes

LD_LIBRARY_PATH=/opt/Xilinx/Vivado/2023.1/lib/lnx64.o /opt/Xilinx/Vivado/2023.1/bin/unwrapped/lnx64.o/hw_server -L- -e "set always-open-jtag 1"

LD_LIBRARY_PATH=/opt/Xilinx/Vivado/2023.1/lib/lnx64.o strace /opt/Xilinx/Vivado/2023.1/bin/unwrapped/lnx64.o/hw_server -L- -e "set always-open-jtag 1"

# Linux 6.2.13/14 kernel issue with Vivado

https://jia.je/software/2023/05/06/linux-regression-vivado-en/

# Future versions 2025.1+ only support the web installer

https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Acquire-Authentication-Token

# 

# 
```
Select a Product from the list:
1. Vitis
2. Vivado
3. Vitis Embedded Development
4. BootGen
5. Lab Edition
6. Hardware Server
7. Power Design Manager (PDM)
8. On-Premises Install for Cloud Deployments
9. PetaLinux
10. Documentation Navigator (Standalone)
```

```
INFO  - Cleaning the download folder: /opt/Xilinx/Downloads/Vivado_2025.1 
WARN  - Couldn't remove all downloaded files in /opt/Xilinx/Downloads/Vivado_2025.1, please remove them manually. 
WARN  - Failed copying from: /home/vivado/web-installer/data to: /opt/Xilinx/Downloads/Vivado_2025.1/data 
java.nio.file.NoSuchFileException: /opt/Xilinx/Downloads/Vivado_2025.1/data
        at java.base/sun.nio.fs.UnixException.translateToIOException(UnixException.java:92)
        at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:106)
        at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:111)
        at java.base/sun.nio.fs.UnixFileSystem.copyDirectory(UnixFileSystem.java:522)
        at java.base/sun.nio.fs.UnixFileSystem.copy(UnixFileSystem.java:1066)
        at java.base/sun.nio.fs.UnixFileSystemProvider.copy(UnixFileSystemProvider.java:300)
        at java.base/java.nio.file.Files.copy(Files.java:1304)
        at com.xilinx.installer.utils.g.a(Unknown Source)
        at com.xilinx.installer.utils.g.preVisitDirectory(Unknown Source)
        at java.base/java.nio.file.Files.walkFileTree(Files.java:2792)
        at com.xilinx.installer.utils.FileUtilities.a(Unknown Source)
        at com.xilinx.installer.workflow.j.g(Unknown Source)
        at com.xilinx.installer.workflow.j.d(Unknown Source)
        at com.xilinx.installer.workflow.j.c(Unknown Source)
        at com.xilinx.installer.workflow.k.run(Unknown Source)
WARN  - Failed copying idata file under /home/vivado/web-installer/data/idata.dat 
java.nio.file.NoSuchFileException: /opt/Xilinx/Downloads/Vivado_2025.1/data/idata.dat
        at java.base/sun.nio.fs.UnixException.translateToIOException(UnixException.java:92)
        at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:106)
        at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:111)
        at java.base/sun.nio.fs.UnixFileSystem.copyFile(UnixFileSystem.java:668)
        at java.base/sun.nio.fs.UnixFileSystem.copy(UnixFileSystem.java:1075)
        at java.base/sun.nio.fs.UnixFileSystemProvider.copy(UnixFileSystemProvider.java:300)
        at java.base/java.nio.file.Files.copy(Files.java:1304)
        at com.xilinx.installer.workflow.j.g(Unknown Source)
        at com.xilinx.installer.workflow.j.d(Unknown Source)
        at com.xilinx.installer.workflow.j.c(Unknown Source)
        at com.xilinx.installer.workflow.k.run(Unknown Source)
javax.xml.bind.JAXBException
 - with linked exception:
[java.io.FileNotFoundException: /opt/Xilinx/Downloads/Vivado_2025.1/data/downloadRecord.dat (No such file or directory)]
        at javax.xml.bind.helpers.AbstractMarshallerImpl.marshal(AbstractMarshallerImpl.java:123)
        at com.xilinx.installer.data.postInst.a.b(Unknown Source)
        at com.xilinx.installer.workflow.Workflow.h(Unknown Source)
        at com.xilinx.installer.workflow.j.d(Unknown Source)
        at com.xilinx.installer.workflow.j.c(Unknown Source)
        at com.xilinx.installer.workflow.k.run(Unknown Source)
Caused by: java.io.FileNotFoundException: /opt/Xilinx/Downloads/Vivado_2025.1/data/downloadRecord.dat (No such file or directory)
        at java.base/java.io.FileOutputStream.open0(Native Method)
        at java.base/java.io.FileOutputStream.open(FileOutputStream.java:289)
        at java.base/java.io.FileOutputStream.<init>(FileOutputStream.java:230)
        at java.base/java.io.FileOutputStream.<init>(FileOutputStream.java:179)
        at javax.xml.bind.helpers.AbstractMarshallerImpl.marshal(AbstractMarshallerImpl.java:116)
        ... 5 more
INFO  - Tool installation completed.To run the tool successfully, please run the script "installLibs.sh" under /opt/Xilinx/2025.1/Vivado/scripts to install the necessary OS packages, which requires the root privilege. 
```

```
sudo apt-get install -y \
libc6-dev-i386 net-tools \
graphviz \
make
# Vitis
sudo apt-get install -y \
unzip \
zip \
g++ \
libtinfo5 \
xvfb \
git \
libncurses5-dev \
libc6-dev-i386 \
libnss3-dev \
libgdk-pixbuf2.0-dev \
libgtk-3-dev \
libxss-dev \
libasound2 \
fdisk  \
libsecret-1-dev
```
This one is not available: 

```
compat-openssl10 \
```
See https://adaptivesupport.amd.com/s/question/0D54U00008vYLcRSAW/unable-to-install-compatopenssl10-in-ubuntu-2404-vm?language=en_US

### Issue Debian 12 no systemd user session available

docker --runtime=/usr/bin/runc build --build-arg=TERM="linux" --network=host -t vivado:4.1.0 .
Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg.
WARN[0000] The cgroupv2 manager is set to systemd but there is no systemd user session available 
WARN[0000] For using systemd, you may need to login using an user session 
WARN[0000] Alternatively, you can enable lingering with: `loginctl enable-linger 1000` (possibly as root) 
WARN[0000] Falling back to --cgroup-manager=cgroupfs 

Changing /etc/container/libpod.conf from crun to runc did not make a difference, nor did any suggestions.

This worked (but is a work-around?)

systemctl --user start dbus
