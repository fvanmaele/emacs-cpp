#!/bin/sh
# Install or upgrade the local MacPorts ports of packaging/macports (D-180, D-181).
#
# MacPorts reads a root-owned copy of the tree, never the repository: a file://
# source inside a git work tree gets `git pull --rebase --autostash` on every
# `port selfupdate` (D-181). Steps, each stopping the script on failure:
#   1. show what root will run: the diff against the installed copy, or every
#      Portfile on the first run; ask before going on;
#   2. replace the copy (sudo cp -R, so root owns it) and run portindex in it;
#   3. add the copy's file:// line above the rsync line of sources.conf, once
#      (sources.conf.emacs-cpp-orig keeps the file as it was);
#   4. install each port, or upgrade it when installed; print its version.
# Usage: sh scripts/install-macos-ports.sh   (as the owner; sudo asks once)

set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
tree="$repo/packaging/macports"
dest=/opt/local/var/macports/sources/emacs-cpp/ports
conf=/opt/local/etc/macports/sources.conf
line="file://$dest"
rsync_line='rsync://rsync.macports.org/macports/release/tarballs/ports.tar.gz [default]'

fail() { echo "install-macos-ports: $*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "macOS only (D-180)"
command -v port >/dev/null || fail "no port command: MacPorts is not installed (D-053)"
[ "$(id -u)" -ne 0 ] || fail "run as the owner, not root; the script calls sudo"
[ -d "$tree" ] || fail "no $tree"
grep -qxF "$rsync_line" "$conf" || fail "$conf has no line '$rsync_line'; add $line by hand"

# Ports: category/name directories holding a Portfile.
ports=$(cd "$tree" && find . -mindepth 3 -maxdepth 3 -name Portfile | sed 's|^\./[^/]*/||; s|/Portfile$||' | sort)
[ -n "$ports" ] || fail "no */*/Portfile under $tree"

# 1. Review.
if [ -d "$dest" ]; then
    if diff -r -x 'PortIndex*' "$dest" "$tree"; then
        echo "install-macos-ports: $dest matches the repository"
    fi
else
    for portfile in "$tree"/*/*/Portfile; do
        echo "==== $portfile"
        cat "$portfile"
    done
fi
printf 'Root will run the Portfiles above. Go on? [y/N] '
read -r answer
[ "$answer" = y ] || fail "stopped, nothing changed"

sudo -v

# 2. The root-owned copy.
sudo mkdir -p "$(dirname "$dest")"
sudo rm -rf "$dest"
sudo cp -R "$tree" "$dest"
sudo find "$dest" -name 'PortIndex*' -delete
(cd "$dest" && sudo portindex)

# 3. sources.conf, once.
if ! grep -qxF "$line" "$conf"; then
    [ -e "$conf.emacs-cpp-orig" ] || sudo cp -p "$conf" "$conf.emacs-cpp-orig"
    tmp=$(mktemp)
    awk -v line="$line" -v rsync_line="$rsync_line" \
        '$0 == rsync_line { print line } { print }' "$conf" > "$tmp"
    grep -qxF "$line" "$tmp" || { rm -f "$tmp"; fail "could not place $line in $conf"; }
    sudo install -m 0644 -o root -g wheel "$tmp" "$conf"
    rm -f "$tmp"
    echo "install-macos-ports: added $line to $conf"
fi

# 4. Install or upgrade.
for name in $ports; do
    version=$(port info --version "$name" | sed 's/^version: *//')
    echo "install-macos-ports: $name @$version"
    if port -q installed "$name" | grep -q .; then
        sudo port upgrade "$name"
    else
        sudo port install "$name"
    fi
    port -q installed "$name"
done
