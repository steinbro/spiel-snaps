#!/bin/bash -x
#
# Basic regression test for the spiel snaps and their slots/plugs.
# Assumes that the orca-spiel, speech-provider-piper, and piper-voices-*
# snaps have been built and are available in the output/snaps directory.
#
# 1. Set up a fresh resolute container.
# 2. Perform minimal configuration of snapd, dbus, and pulseaudio.
# 3. Install the orca, piper, and voice snaps.
# 4. Connect the snaps' slots and plugs.
# 5. Trigger speech using the spiel binary.
#
C=spiel-snap-test  # Name of the test container
set -euo pipefail  # Exit on error, unset variable, or failed pipe

# Remove any existing container and create a new one
lxc delete $C --force || true
lxc launch ubuntu:26.04 $C

# Set up snapd
lxc exec $C -- systemctl start snapd.socket
lxc exec $C -- systemctl enable snapd.socket
lxc exec $C -- systemctl start snapd
# Enable feature flag needed for speech-provider-piper to run as a user daemon
lxc exec $C -- snap set system experimental.user-daemons=true

# Install dbus and other dependencies
lxc exec $C -- apt update
lxc exec $C -- apt install -y dbus-x11 make yq
# Tell systemd to keep user 0's session active permanently
lxc exec $C -- loginctl enable-linger 0
# Boot the systemd user instance for root
lxc exec $C -- systemctl start user@0.service

# Expose host audio to container
lxc exec $C -- bash -c "mkdir -p /run/user/0/pulse /root/.config/pulse && chmod 0700 /run/user/0"
HOST_PULSE_COOKIE="${XDG_CONFIG_HOME:-$HOME/.config}/pulse/cookie"
lxc config device add $C pulse-native proxy \
  listen=unix:/run/user/0/pulse/native \
  connect=unix:/run/user/$(id -u)/pulse/native \
  bind=container \
  uid=0 \
  gid=0 \
  mode=0600 || true
lxc file push "$HOST_PULSE_COOKIE" "$C/root/.config/pulse/cookie"

# Environment variables needed for spiel to find the dbus and pulseaudio sockets
lxc exec $C -- bash -c "printf '%s\n' \
  'export XDG_RUNTIME_DIR=/run/user/0/snap.orca-spiel' \
  'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus' \
  > /etc/profile.d/spiel-env.sh"

# Run Makefile targets in the container
lxc file push --recursive * $C/root
lxc exec $C -- bash -lc "make install"
lxc exec $C -- bash -lc "make connect"
lxc exec $C -- bash -lc "make speak"