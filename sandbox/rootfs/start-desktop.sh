#!/bin/sh
# Starts the bot's desktop: Xvnc on 127.0.0.1 only, with the one-session password LoopHands
# passes on stdin (never stored on the Windows side), and XFCE inside it.
#   loophands-desktop <display-number> <port>
set -eu
display="${1:-1}"
port="${2:-5901}"
umask 077
# WSLg injects Wayland, PulseAudio and runtime-dir variables into every WSL process; with them
# set, GTK would draw on the Windows desktop instead of inside Xvnc.
unset WAYLAND_DISPLAY PULSE_SERVER XDG_RUNTIME_DIR
export GDK_BACKEND=x11 XDG_SESSION_TYPE=x11
# The distro's boot command (wsl.conf [boot]) masks WSLg's /mnt/wslg and /tmp/.X11-unix; it runs
# alongside the first command, so give it a moment (up to ~3 s) before the desktop starts.
tries=0
while { [ -e /mnt/wslg/runtime-dir ] || [ -e /mnt/wslg/.X11-unix ]; } && [ "$tries" -lt 15 ]; do
  tries=$((tries + 1))
  sleep 0.2
done
if [ -e /mnt/wslg/runtime-dir ] || [ -e /mnt/wslg/.X11-unix ]; then
  echo "loophands-desktop: warning: WSLg is still visible in the guest" >&2
fi
mkdir -p "$HOME/.vnc"
# The password arrives on stdin and is written only inside the sandbox.
vncpasswd -f > "$HOME/.vnc/passwd"
exec Xvnc ":$display" \
  -rfbport "$port" \
  -localhost yes \
  -interface 127.0.0.1 \
  -SecurityTypes VncAuth \
  -PasswordFile "$HOME/.vnc/passwd" \
  -geometry 1280x800 -depth 24 \
  -AlwaysShared=0 -NeverShared=1 &
# Wait (up to ~10 s) for the X server's socket before starting XFCE. Under WSLg /tmp/.X11-unix is
# a read-only tmpfs, so Xvnc only has the abstract socket; accept either form.
tries=0
while [ ! -e "/tmp/.X11-unix/X$display" ] \
  && ! grep -qE "@/tmp/\.X11-unix/X${display}\$" /proc/net/unix \
  && [ "$tries" -lt 50 ]; do
  tries=$((tries + 1))
  sleep 0.2
done
DISPLAY=":$display" exec dbus-launch --exit-with-session startxfce4
