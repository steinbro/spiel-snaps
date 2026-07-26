#!/bin/bash -x
#
# Basic regression test for the spiel snaps and their slots/plugs.
# This is not a comprehensive test, but it does verify that the snaps can be installed and run on a fresh system.
#
# 1. Set up a fresh resolute container.
# 2. Perform minimal configuration of snapd and dbus.
# 3. Install the orca, piper, and voice snaps.
# 4. Connect the snaps' slots and plugs.
# 5. Verify that the spiel binary reports one provider and one voice.
#
C=spiel-snap-test

# Remove any existing container and create a new one
lxc delete $C --force || true
lxc launch ubuntu:26.04 $C

# Set up snapd
lxc exec $C -- systemctl start snapd.socket
lxc exec $C -- systemctl enable snapd.socket
lxc exec $C -- systemctl start snapd
# Enable feature flag needed for speech-provider-piper to run as a user daemon
lxc exec $C -- snap set system experimental.user-daemons=true

# Install dbus
lxc exec $C -- apt update
lxc exec $C -- apt install -y dbus-x11
# Tell systemd to keep user 0's session active permanently
lxc exec $C -- loginctl enable-linger 0
# Boot the systemd user instance for root
lxc exec $C -- systemctl start user@0.service

# Install snaps for orca, piper, and a voice
lxc file push orca-spiel/orca-spiel_*.snap $C/root/
lxc exec $C -- bash -c "snap install /root/orca-spiel_*.snap --dangerous --devmode"
lxc file push speech-provider-piper/speech-provider-piper_*.snap $C/root/
lxc exec $C -- bash -c "snap install /root/speech-provider-piper_*.snap --dangerous"
lxc file push speech-provider-piper-voices-en-us/speech-provider-piper-voices-en-us_*.snap $C/root/
lxc exec $C -- bash -c "snap install /root/speech-provider-piper-voices-en-us_*.snap --dangerous"

# Connect voice to piper, and piper to orca
lxc exec $C -- snap connect speech-provider-piper:piper-voices speech-provider-piper-voices-en-us:piper-voices
lxc exec $C -- snap connect orca-spiel:speech-provider-piper speech-provider-piper:speech-provider

# spiel binary should show one provider and one voice
lxc exec $C -- env \
  XDG_RUNTIME_DIR=/run/user/0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus \
  orca-spiel.spiel -P
lxc exec $C -- env \
  XDG_RUNTIME_DIR=/run/user/0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus \
  orca-spiel.spiel -V