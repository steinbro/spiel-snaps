#!/bin/bash -x
#
# Creates a reusable base LXD container for spiel snap testing.
# The container is snapshotted at the end so that other tests can
# restore this known-good state instead of repeating this setup (and
# its snap/apt installs) on every test run.
#
C=spiel-snap-test    # Name of the test container
SNAPSHOT=base         # Name of the reusable base snapshot
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
# Install some large base snaps to avoid downloading them during the test
lxc exec $C -- snap install snapd core26

# Install dbus and other dependencies
lxc exec $C -- apt update
lxc exec $C -- apt install -y dbus-x11 make yq
# Tell systemd to keep user 0's session active permanently
lxc exec $C -- loginctl enable-linger 0
# Boot the systemd user instance for root
lxc exec $C -- systemctl start user@0.service

# Environment variables needed for spiel to find the dbus and pulseaudio sockets
lxc exec $C -- bash -c "printf '%s\n' \
  'export XDG_RUNTIME_DIR=/run/user/0/snap.orca-spiel' \
  'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus' \
  > /etc/profile.d/spiel-env.sh"

# Snapshot the configured container so it can be reused as a clean base
lxc snapshot $C $SNAPSHOT
