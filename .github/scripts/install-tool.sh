#!/usr/bin/env bash
# Installs a pipeline tool at an exact version and checks its SHA256 before use.
# usage: install-tool.sh terraform|infracost
set -euo pipefail

tool=$1
dest=${RUNNER_TEMP:-/tmp}/bin
mkdir -p "$dest"
work=$(mktemp -d)

case "$tool" in
  terraform)
    version=1.17.1
    sha256=4638628058e71a55212b1c563712eac03b902128f40740f3dc8174df12135061
    url=https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip
    curl -fsSL -o "$work/pkg" "$url"
    echo "$sha256  $work/pkg" | sha256sum -c -
    unzip -q -o "$work/pkg" terraform -d "$dest"
    ;;
  infracost)
    version=v0.10.47
    sha256=df098d5565b78cc23de57e1dac9f2a02491691322cbd690dca9b197e3e02fe93
    url=https://github.com/infracost/infracost/releases/download/${version}/infracost-linux-amd64.tar.gz
    curl -fsSL -o "$work/pkg" "$url"
    echo "$sha256  $work/pkg" | sha256sum -c -
    tar -xzf "$work/pkg" -C "$work"
    install -m 0755 "$work/infracost-linux-amd64" "$dest/infracost"
    ;;
  *)
    echo "unknown tool $tool" >&2
    exit 2
    ;;
esac

rm -rf "$work"
if [ -n "${GITHUB_PATH:-}" ]; then echo "$dest" >> "$GITHUB_PATH"; fi
"$dest/$tool" --version | head -1
