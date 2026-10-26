#!/bin/sh
# Runs as root when the bot's distro boots (wsl.conf [boot] command). Hides WSLg from the guest
# so nothing in it can draw on, or listen to, the Windows desktop (threat model S1.5, VM-T4):
# /mnt/wslg (Wayland, PulseAudio, the WSLg X socket) and the WSLg /tmp/.X11-unix bind mount are
# unmounted where possible, then masked with empty tmpfs either way. Xvnc makes its own socket in
# the fresh /tmp/.X11-unix (and the abstract one), so the bot's desktop is unaffected.
set -u
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# The image ships an empty machine id so it stays reproducible; give this bot its own
# (dbus-launch in loophands-desktop needs one).
dbus-uuidgen --ensure=/etc/machine-id 2>/dev/null || true
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure 2>/dev/null || true
# Unmount everything at or under /mnt/wslg and /tmp/.X11-unix, deepest first.
awk '$2 == "/tmp/.X11-unix" || $2 == "/mnt/wslg" || index($2, "/mnt/wslg/") == 1 { print $2 }' \
  /proc/self/mounts | sort -r | while read -r m; do
  umount -l "$m" 2>/dev/null || true
done
# Mask both paths whatever happened above: an empty root-only /mnt/wslg, and a fresh
# /tmp/.X11-unix that only holds the guest's own X sockets.
mkdir -p /mnt/wslg /tmp/.X11-unix
mount -t tmpfs -o mode=0700,size=64k,nosuid,nodev,noexec tmpfs /mnt/wslg
mount -t tmpfs -o mode=1777,size=1m,nosuid,nodev,noexec tmpfs /tmp/.X11-unix
