#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  version="$1"
else
  version=$(
    curl -fsSL \
      https://api.github.com/repos/devsy-org/devsy/releases/latest |
      jq -r '.tag_name | sub("^v"; "")'
  )
fi

current_version=$(
  awk -F= '/^pkgver=/ { print $2; exit }' devsy-bin/PKGBUILD
)

if [[ "$version" == "$current_version" ]]; then
  echo "Already up to date (${version})"
  exit 0
fi

echo "Updating ${current_version} -> ${version}"

base_url="https://github.com/devsy-org/devsy/releases/download/v${version}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL \
  -o "$tmpdir/devsy" \
  "${base_url}/devsy-linux-amd64"

curl -fsSL \
  -o "$tmpdir/Devsy_linux_x86_64.AppImage" \
  "${base_url}/Devsy_linux_x86_64.AppImage"

cli_sha=$(sha256sum "$tmpdir/devsy" | cut -d' ' -f1)
app_sha=$(sha256sum "$tmpdir/Devsy_linux_x86_64.AppImage" | cut -d' ' -f1)

update_pkgbuild() {
  local pkg="$1"
  local sha="$2"

  sed -Ei \
    -e "s/^pkgver=.*/pkgver=${version}/" \
    -e "0,/'[0-9a-f]{64}'/s//'${sha}'/" \
    "$pkg/PKGBUILD"

  (
    cd "$pkg"
    makepkg --printsrcinfo > .SRCINFO
  )
}

update_pkgbuild devsy-bin "$cli_sha"
update_pkgbuild devsy-desktop-bin "$app_sha"

echo "Updated to ${version}"
