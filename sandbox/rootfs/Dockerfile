# LoopHands sandbox base image (ADR-007, CHECKLIST P7 "Debian-based rootfs build pipeline").
# A small Debian 12 desktop for a bot's own computer: Xvnc (TigerVNC), XFCE, Chromium,
# xdotool for computer use, and the libraries Playwright needs. Built in CI, exported as a tar
# rootfs, signed, and imported per bot with `wsl --import`.
# Reproducible: the base is pinned by digest and the packages come from a dated Debian snapshot.
# To take security updates, bump BASE (new digest) and SNAPSHOT together, on purpose, in one commit.
ARG BASE=debian:12-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8
FROM ${BASE}

ARG DEBIAN_FRONTEND=noninteractive
ARG SNAPSHOT=20261025T000000Z
ARG SOURCE_DATE_EPOCH
RUN test -n "$SOURCE_DATE_EPOCH" || { echo "SOURCE_DATE_EPOCH is required: build with build.sh" >&2; exit 1; }

# apt verifies the archive signatures itself, so plain http is fine (slim has no ca-certificates yet).
RUN rm -f /etc/apt/sources.list.d/debian.sources \
 && printf '%s\n' \
      "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT bookworm main" \
      "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/$SNAPSHOT bookworm-updates main" \
      "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/$SNAPSHOT bookworm-security main" \
      > /etc/apt/sources.list \
 && echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retries

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates locales tzdata dbus-x11 \
      tigervnc-standalone-server tigervnc-tools \
      xfce4-session xfwm4 xfce4-panel xfdesktop4 xfce4-terminal thunar \
      chromium fonts-dejavu-core fonts-liberation \
      xdotool x11-utils scrot \
      python3 python3-venv nodejs \
      libnss3 libatk-bridge2.0-0 libgbm1 libasound2 libxkbcommon0 libxshmfence1 \
 && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# The bot works as an unprivileged user: no password, and no sudo installed at all. useradd stamps
# today into /etc/shadow, so set that date from SOURCE_DATE_EPOCH and drop the backup files.
RUN useradd --create-home --shell /bin/bash bot \
 && chage -d "$(date -u -d "@$SOURCE_DATE_EPOCH" +%F)" bot \
 && rm -f /etc/shadow- /etc/gshadow- /etc/passwd- /etc/group- \
 && mkdir -p /home/bot/drop /home/bot/.vnc \
 && chown -R bot:bot /home/bot

# Hardening (threat model S1.5 VM-T4): no Windows drives, no running Windows programs, no
# Windows PATH, the bot user by default, and WSLg hidden at every boot (loophands-boot masks
# /mnt/wslg and the WSLg /tmp/.X11-unix). Checked again after every import.
COPY wsl.conf /etc/wsl.conf
COPY loophands-boot.sh /usr/local/sbin/loophands-boot
COPY start-desktop.sh /usr/local/bin/loophands-desktop
RUN chmod 0644 /etc/wsl.conf \
 && chmod 0755 /usr/local/sbin/loophands-boot /usr/local/bin/loophands-desktop

# A clean desktop: no top panel, one small centred dock (Chromium, Thunar, terminal), no desktop
# icons, one workspace and the LoopHands wallpaper (system-wide XFCE defaults, see xfce/).
COPY xfce/xfce4-panel.xml xfce/xfce4-desktop.xml xfce/xfwm4.xml \
     /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
COPY wallpaper.png /usr/share/backgrounds/loophands/wallpaper.png
# Chromium adds --no-sandbox only where the guest kernel lacks user namespaces.
COPY chromium-flags /etc/chromium.d/loophands
RUN chmod 0644 /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml \
      /usr/share/backgrounds/loophands/wallpaper.png /etc/chromium.d/loophands

ENV LANG=en_US.UTF-8

# Last step: delete what differs between two builds of the same commit (logs, caches, bytecode, the
# random D-Bus machine id) so the image is reproducible. Each bot gets its own id at boot.
RUN rm -rf /var/log/apt/* /var/log/dpkg.log /var/log/alternatives.log /var/log/bootstrap.log \
      /var/cache/ldconfig/aux-cache /var/lib/dpkg/*-old /var/cache/debconf/*-old \
      /var/cache/fontconfig/* /var/lib/apt/lists/* /var/cache/apt/*.bin \
 && find /usr -name __pycache__ -prune -exec rm -rf {} + \
 && : > /etc/machine-id \
 && rm -f /var/lib/dbus/machine-id
