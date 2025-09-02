#!/bin/sh
XAUTHORITY= XDG_RUNTIME_DIR=/run/user/$(id -u) xpra start \
--bind-tcp=0.0.0.0:14500 \
--start-child=gnome-terminal --start-child=vivado \
--terminate-children=yes --exit-with-children=no \
--audio=no --printing=no --webcam=no --no-tray --mdns=no \
--enable-pings \
--html=on \
--sharing=yes \
--daemon=yes
/bin/echo
PUBLIC_IP=$(curl -s -m 2 ifconfig.me || echo "")
/bin/echo -n "Connect your (HTML5 compatible) browser to $PUBLIC_IP:14500\n"
/bin/bash
