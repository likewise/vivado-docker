#!/bin/sh
XAUTHORITY= xpra start --bind-tcp=0.0.0.0:14500 --start-child-after-connect=gnome-terminal --terminate-children=yes --exit-with-children=no --daemon=yes --audio=no --webcam=no --no-tray --mdns=no --html=on --enable-pings --printing=no
/bin/bash
