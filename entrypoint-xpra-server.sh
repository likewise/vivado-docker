#!/bin/sh
XAUTHORITY= xpra start --bind-tcp=0.0.0.0:14500 --start-child=gnome-terminal --start-child=vivado --terminate-children=yes --exit-with-children=no --audio=no --webcam=no --no-tray --mdns=no --html=on --enable-pings --printing=no --daemon=yes
/bin/echo
PUBLIC_IP=$(curl -m 2 ifconfig.me || echo "this host's")
/bin/echo -n "Connect your (Chrome) browser to $PUBLIC_IP port 14500"
/bin/bash
