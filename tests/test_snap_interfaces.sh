#!/bin/bash -x
#
# Basic regression test for the spiel snaps and their slots/plugs.
# Assumes that the orca-spiel, speech-provider-piper, and piper-voices-*
# snaps have been built and are available in the output/snaps directory.
#
# 1. Restore the reusable base container snapshot (creating it via
#    setup_base_container.sh if it doesn't exist yet), which already has
#    snapd and dbus configured.
# 2. Expose host audio (pulseaudio) to the container.
# 3. Install the orca, piper, and voice snaps.
# 4. Connect the snaps' slots and plugs.
# 5. Trigger speech using the spiel binary.
#
C=spiel-snap-test  # Name of the test container
SNAPSHOT=base      # Name of the reusable base snapshot
set -euo pipefail  # Exit on error, unset variable, or failed pipe

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create the base container/snapshot if it doesn't exist yet, otherwise
# restore it to reset the container to a clean, pre-configured state.
if lxc query "/1.0/instances/$C/snapshots/$SNAPSHOT" >/dev/null 2>&1; then
  lxc restore $C $SNAPSHOT
  # Restoring a snapshot leaves the container stopped, so start it back up
  if [ "$(lxc list $C --format csv -c s)" != "RUNNING" ]; then
    lxc start $C
  fi
else
  "$SCRIPT_DIR/setup_base_container.sh"
fi

# Make sure snapd and the user session manager (needed for XDG_RUNTIME_DIR,
# D-Bus, and the pulseaudio proxy target directory below) are actually up.
# `systemctl start` blocks until the unit finishes (re)activating, so this
# also acts as a readiness barrier: on a freshly booted/restored container
# these are only auto-started in the background (via socket activation /
# linger), and racing ahead of them left audio silently non-functional.
#
# Immediately after the container itself (re)starts -- e.g. right after a
# host reboot, when LXD autostarts the container -- the container's own
# systemd/D-Bus may not have finished initializing yet, so `lxc exec`
# can race ahead of it: systemctl fails with "Failed to connect to system
# scope bus via local transport: No such file or directory" until
# /run/dbus/system_bus_socket exists. This is transient, so retry for a
# bit instead of failing the whole test run.
tries=0
until lxc exec $C -- systemctl start snapd.socket snapd user@0.service; do
  tries=$((tries + 1))
  if [ "$tries" -ge 30 ]; then
    echo "Timed out waiting for $C's systemd/D-Bus to become ready" >&2
    exit 1
  fi
  sleep 1
done

# Expose host audio to container. This has to happen after the container is
# running (rather than being baked into the base snapshot) because it binds
# to a path under /run/user/0, which is tmpfs and doesn't survive a
# container restart/restore.
lxc exec $C -- bash -c "mkdir -p /run/user/0/pulse /root/.config/pulse && chmod 0700 /run/user/0"
HOST_PULSE_COOKIE="${XDG_CONFIG_HOME:-$HOME/.config}/pulse/cookie"
lxc config device remove $C pulse-native 2>/dev/null || true
lxc config device add $C pulse-native proxy \
  listen=unix:/run/user/0/pulse/native \
  connect=unix:/run/user/$(id -u)/pulse/native \
  bind=container \
  uid=0 \
  gid=0 \
  mode=0600
lxc file push "$HOST_PULSE_COOKIE" "$C/root/.config/pulse/cookie"

# Run Makefile targets in the container
lxc file push --recursive * $C/root
lxc exec $C -- bash -lc "make \
  SNAPS=\"speech-provider-piper orca-spiel\" \
  PIPER_VOICES=en-US \
  install connect speak
"
