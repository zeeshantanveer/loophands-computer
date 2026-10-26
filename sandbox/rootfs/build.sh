#!/usr/bin/env bash
# Builds the sandbox rootfs tar (CI, Linux with Docker). Reproducible: pinned base and Debian
# snapshot (see the Dockerfile), SOURCE_DATE_EPOCH from the commit time, rewritten timestamps.
# Outputs, in ./out:
#   loophands-rootfs-<version>.tar.gz        the rootfs for `wsl --import`
#   loophands-rootfs-<version>.contents.txt  one line per tar member, for diffing two builds
#   loophands-rootfs-<version>.spdx.json     SBOM (Syft)
#   loophands-rootfs-<version>.osv.json      vulnerability scan of the SBOM (OSV-Scanner)
#   loophands-rootfs-<version>.sources.txt   the Debian source packages (GPL source offer)
#   build-info.txt                           commit, dates, base, snapshot and tool versions
#   SHA256SUMS                               SHA-256 of every file above
# CI never signs. Signing happens separately, offline, with the release key, outside this repo.
set -euo pipefail
usage="usage: build.sh <version>   (ci, or a whole number >= 1)"
version="${1:?$usage}"
if [[ "$version" != "ci" && ! "$version" =~ ^[1-9][0-9]*$ ]]; then
  echo "$usage" >&2
  exit 2
fi
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"
mkdir -p "$out"
image="loophands-rootfs:$version"
name="loophands-rootfs-$version"

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$here" log -1 --format=%ct)}"
export SOURCE_DATE_EPOCH
# The snapshot date comes from the Dockerfile; SNAPSHOT in the environment overrides it.
args=(--build-arg SOURCE_DATE_EPOCH)
[[ -n "${SNAPSHOT:-}" ]] && args+=(--build-arg "SNAPSHOT=$SNAPSHOT")

# The tar comes straight from the build (not `docker export`), so it has no .dockerenv, hostname,
# hosts or resolv.conf. The base is pinned by digest, so no --pull.
docker buildx build "${args[@]}" \
  --output "type=tar,dest=$out/$name.tar,rewrite-timestamp=true" "$here"
gzip -n -9 < "$out/$name.tar" > "$out/$name.tar.gz"
rm -f "$out/$name.tar"
# The same build again (cached), loaded for the checks, SBOM and source list.
docker buildx build "${args[@]}" --load --tag "$image" "$here"

# One sorted line per member (type, mode, uid, gid, mtime, size, sha256, name), and sanity checks.
python3 - "$out/$name.tar.gz" "$out/$name.contents.txt" "$SOURCE_DATE_EPOCH" <<'PY'
import hashlib
import sys
import tarfile

src, dest, epoch = sys.argv[1], sys.argv[2], int(sys.argv[3])
kinds = {tarfile.REGTYPE: "f", tarfile.AREGTYPE: "f", tarfile.DIRTYPE: "d",
         tarfile.SYMTYPE: "l", tarfile.LNKTYPE: "h"}
lines, errors = [], []
with tarfile.open(src, "r:gz") as tar:
    for m in tar:
        n = m.name[2:] if m.name.startswith("./") else m.name
        n = n.rstrip("/") or "."
        if m.isfile():
            digest = hashlib.sha256(tar.extractfile(m).read()).hexdigest()
        elif m.issym() or m.islnk():
            digest = m.linkname
        else:
            digest = "-"
        lines.append(f"{kinds.get(m.type, '?')} {m.mode:04o} {m.uid} {m.gid} {int(m.mtime)} "
                     f"{m.size} {digest} {n}")
        if n == ".dockerenv":
            errors.append("the image contains .dockerenv")
        if n == "home/bot" and m.uid != 1000:
            errors.append(f"home/bot is uid {m.uid}, expected 1000")
        if n == "etc/shadow" and (m.mode not in (0o640, 0o600) or m.uid != 0):
            errors.append(f"etc/shadow is mode {m.mode:04o} uid {m.uid}, expected 0640 or 0600, uid 0")
        if m.mtime > epoch:
            errors.append(f"{n} is newer than SOURCE_DATE_EPOCH ({int(m.mtime)} > {epoch})")
with open(dest, "w", encoding="utf-8") as f:
    f.write("\n".join(sorted(lines, key=lambda l: l.split(" ", 7)[7])) + "\n")
for e in errors:
    print(f"build.sh: {e}", file=sys.stderr)
sys.exit(1 if errors else 0)
PY

syft "docker:$image" -o "spdx-json=$out/$name.spdx.json"
osv-scanner scan --sbom "$out/$name.spdx.json" --format json > "$out/$name.osv.json" || true
docker run --rm "$image" dpkg-query -W -f='${source:Package} ${source:Version}\n' \
  | sort -u > "$out/$name.sources.txt"

default_snapshot="$(sed -n 's/^ARG SNAPSHOT=//p' "$here/Dockerfile")"
{
  echo "version: $version"
  echo "commit: $(git -C "$here" rev-parse HEAD)"
  echo "source_date_epoch: $SOURCE_DATE_EPOCH ($(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%dT%H:%M:%SZ))"
  echo "base: $(sed -n 's/^ARG BASE=//p' "$here/Dockerfile")"
  echo "snapshot: ${SNAPSHOT:-$default_snapshot}"
  echo "docker: $(docker version --format '{{.Server.Version}}')"
  echo "buildx: $(docker buildx version)"
  echo "syft: $(syft version | sed -n 's/^Version: *//p')"
  echo "osv-scanner: $(osv-scanner --version | head -n 1)"
} > "$out/build-info.txt"

# Plain names, sorted, so `sha256sum -c SHA256SUMS` works inside the folder.
sums="$(cd "$out" && find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' | LC_ALL=C sort \
  | xargs sha256sum)"
printf '%s\n' "$sums" > "$out/SHA256SUMS"
grep "  $name.tar.gz\$" "$out/SHA256SUMS"
