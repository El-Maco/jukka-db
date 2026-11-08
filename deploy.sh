#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DST_HOST="${DST_HOST:-minimaco}"
DST_DIR="${DST_DIR:-/jukka}"
DB_FILE="$ROOT/jukka.db"
TARGET="i686-unknown-linux-gnu"
BUILD_IMAGE="jukka-build:i686"
BUILD_DIR="$ROOT/target/docker-i686"
BIN="$BUILD_DIR/$TARGET/release/jukka"
STAMP="$(date +%Y%m%d%H%M%S)"

die() { echo "error: $*" >&2; exit 1; }

echo "Checking local dependencies"
for cmd in docker sqlx ssh rsync python3; do
    command -v "$cmd" >/dev/null || die "missing '$cmd'"
done
docker info >/dev/null 2>&1 || die "docker daemon not reachable"

echo "Checking server dependencies"
ssh "$DST_HOST" 'command -v python3 sqlite3 rsync >/dev/null && sudo -n true' \
    || die "server missing python3/sqlite3/rsync or passwordless sudo"

echo "Ensuring local build database"
touch "$DB_FILE"
sqlx migrate run --database-url "sqlite://$DB_FILE"

echo "Running API self-check"
python3 "$ROOT/web/api/test_api.py"

# minimaco runs Debian 12 (glibc 2.36); build there so the local newer glibc isn't required.
echo "Building release version of Jukka for Debian 12 (glibc 2.36)"
if ! docker image inspect "$BUILD_IMAGE" >/dev/null 2>&1; then
    docker build -t "$BUILD_IMAGE" - <<'EOF'
FROM rust:1-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends gcc-multilib && rm -rf /var/lib/apt/lists/*
RUN rustup target add i686-unknown-linux-gnu
EOF
fi
mkdir -p "$BUILD_DIR"
docker run --rm \
    -v "$ROOT":/src -w /src \
    -v "$BUILD_DIR":/target \
    -v jukka-cargo-registry:/usr/local/cargo/registry \
    -e CARGO_TARGET_DIR=/target \
    "$BUILD_IMAGE" cargo build --release --target "$TARGET"
[ -x "$BIN" ] || die "binary not found at $BIN"

echo "Backing up existing files on $DST_HOST:$DST_DIR"
ssh "$DST_HOST" bash -s -- "$DST_DIR" "$STAMP" <<'EOF'
set -e
mkdir -p "$1/backups"
if [ -f "$1/jukka.db" ]; then
    sqlite3 "$1/jukka.db" ".backup '$1/backups/jukka_$2.db'"
fi
if [ -f "$1/jukka" ]; then
    mv "$1/jukka" "$1/backups/jukka_$2"
fi
EOF

echo "Deploying daemon"
rsync -avz "$BIN" "$DST_HOST:$DST_DIR/"
ssh "$DST_HOST" "sudo systemctl restart jukka.service"

echo "Deploying web UI and API"
"$ROOT/web/deploy.sh"

echo "Verifying services"
ssh "$DST_HOST" 'systemctl is-active --quiet jukka.service && systemctl is-active --quiet jukka-api.service' \
    || die "services not active after deploy"
ssh "$DST_HOST" "python3 -c 'import urllib.request; urllib.request.urlopen(\"http://127.0.0.1:8789/api?range=24h\", timeout=5)'" \
    || die "API health check failed"

echo "Deployed to http://$DST_HOST/"
