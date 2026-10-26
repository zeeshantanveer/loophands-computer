# LoopHands computer image

This repo holds the build recipe for the LoopHands virtual computer image: a Debian 12 (bookworm)
root filesystem with a small desktop (Xvnc and XFCE), Chromium and xdotool. LoopHands imports it
into WSL as the computer the bot works on.

## How it is built

`sandbox/rootfs/build.sh` builds the image with Docker from a base image pinned by digest and a
fixed Debian snapshot date, so two clean builds give the same SHA-256. The `rootfs` workflow in
`.github/workflows/rootfs.yml` runs the build twice on every push and fails if the two hashes differ.
A push builds a throwaway `ci` image. A manual run (`workflow_dispatch` with a version number)
builds a release candidate.

CI holds no secrets and never signs anything. Images are signed offline and published on
LoopHands-releases.

## Source code for the Debian packages

The image contains Debian packages, some of them under the GPL. The Debian source packages and
versions in each image are listed in that release's `loophands-rootfs-<version>.sources.txt`
file. The matching sources are available from the Debian snapshot archive
(https://snapshot.debian.org) for the snapshot date recorded in the release's `build-info.txt`.

## Notice

See [NOTICE](NOTICE).
