#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-/tmp/mission-control-deb-build}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/dist}"
PACKAGE_NAME="mission-control"

ARCH_RAW="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64) DEB_ARCH="amd64" ;;
  aarch64|arm64) DEB_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture for .deb packaging: $ARCH_RAW" >&2
    exit 1
    ;;
esac

VERSION="$(node -p "require('$PROJECT_ROOT/package.json').version")"
STAGE_DIR="$BUILD_ROOT/${PACKAGE_NAME}_${VERSION}_${DEB_ARCH}"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN" \
  "$STAGE_DIR/opt/mission-control" \
  "$STAGE_DIR/etc/default" \
  "$STAGE_DIR/etc/mission-control" \
  "$STAGE_DIR/lib/systemd/system" \
  "$STAGE_DIR/var/lib/mission-control" \
  "$STAGE_DIR/var/log/mission-control"

echo "==> building standalone bundle"
cd "$PROJECT_ROOT"
pnpm build

echo "==> staging app files"
cp -R .next/standalone/. "$STAGE_DIR/opt/mission-control/"
mkdir -p "$STAGE_DIR/opt/mission-control/.next"
cp -R .next/static "$STAGE_DIR/opt/mission-control/.next/static"
cp -R public "$STAGE_DIR/opt/mission-control/public"
cp .env.example "$STAGE_DIR/opt/mission-control/.env.example"
cp scripts/generate-env.sh "$STAGE_DIR/opt/mission-control/generate-env.sh"
chmod 0755 "$STAGE_DIR/opt/mission-control/generate-env.sh"

cat > "$STAGE_DIR/etc/default/mission-control" <<'EODEFAULT'
PORT=3000
HOSTNAME=0.0.0.0
MISSION_CONTROL_DATA_DIR=/var/lib/mission-control
EODEFAULT

cp packaging/deb/systemd/mission-control.service "$STAGE_DIR/lib/systemd/system/mission-control.service"

cp packaging/deb/DEBIAN/config "$STAGE_DIR/DEBIAN/config"
cp packaging/deb/DEBIAN/postinst "$STAGE_DIR/DEBIAN/postinst"
cp packaging/deb/DEBIAN/prerm "$STAGE_DIR/DEBIAN/prerm"
cp packaging/deb/DEBIAN/postrm "$STAGE_DIR/DEBIAN/postrm"
cp packaging/deb/DEBIAN/templates "$STAGE_DIR/DEBIAN/templates"
cp packaging/deb/DEBIAN/conffiles "$STAGE_DIR/DEBIAN/conffiles"
chmod 0755 "$STAGE_DIR/DEBIAN/config" "$STAGE_DIR/DEBIAN/postinst" "$STAGE_DIR/DEBIAN/prerm" "$STAGE_DIR/DEBIAN/postrm"

cat > "$STAGE_DIR/DEBIAN/control" <<EOFCONTROL
Package: mission-control
Version: $VERSION
Section: web
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Mission Control Maintainers <maintainers@builderz.dev>
Depends: debconf (>= 1.5.0)
Description: Mission Control local orchestration dashboard
 Open-source dashboard for AI agent orchestration.
 Installs Mission Control as a local systemd service.
EOFCONTROL

find "$STAGE_DIR" -type d -exec chmod 0755 {} +
chmod 0644 "$STAGE_DIR/DEBIAN/control" "$STAGE_DIR/DEBIAN/templates" "$STAGE_DIR/DEBIAN/conffiles"
chmod 0644 "$STAGE_DIR/lib/systemd/system/mission-control.service" "$STAGE_DIR/etc/default/mission-control"

mkdir -p "$OUT_DIR"
DEB_PATH="$OUT_DIR/${PACKAGE_NAME}_${VERSION}_${DEB_ARCH}.deb"

echo "==> building package $DEB_PATH"
dpkg-deb --build "$STAGE_DIR" "$DEB_PATH"

echo "Done: $DEB_PATH"
