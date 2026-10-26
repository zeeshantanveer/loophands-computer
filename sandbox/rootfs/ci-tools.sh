#!/usr/bin/env bash
# Installs the pinned Syft and OSV-Scanner for the rootfs build (CI; run with sudo for /usr/local/bin).
#   ci-tools.sh [install-dir]
# To bump a tool: change the version and take the new sha256 from the release's checksums file.
set -euo pipefail
readonly SYFT_VERSION="1.55.0"
readonly SYFT_SHA256="bb65249542db5fedeeb4d3f9b018b75e7264dbfbbb10486f044581a92f90490d"
readonly OSV_VERSION="2.7.0"
readonly OSV_SHA256="160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b"

dest="${1:-/usr/local/bin}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

syft_tar="syft_${SYFT_VERSION}_linux_amd64.tar.gz"
curl -fsSL --retry 3 -o "$tmp/$syft_tar" \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/$syft_tar"
curl -fsSL --retry 3 -o "$tmp/osv-scanner" \
  "https://github.com/google/osv-scanner/releases/download/v${OSV_VERSION}/osv-scanner_linux_amd64"

# A mismatch fails the build (set -e).
(cd "$tmp" && printf '%s  %s\n%s  %s\n' \
  "$SYFT_SHA256" "$syft_tar" "$OSV_SHA256" "osv-scanner" | sha256sum -c -)

tar -xzf "$tmp/$syft_tar" -C "$tmp" syft
mkdir -p "$dest"
install -m 0755 "$tmp/syft" "$dest/syft"
install -m 0755 "$tmp/osv-scanner" "$dest/osv-scanner"
"$dest/syft" version
"$dest/osv-scanner" --version
