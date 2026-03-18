#!/bin/bash

DST_HOST="minimaco"
DST_DIR="/jukka"

set -e

SRC_FILES=(
    "target/i686-unknown-linux-gnu/release/jukka"
    "migrations"
)

DB_FILE="jukka.db"

[ -f "$DB_FILE" ] && touch $DB_FILE
sqlx migrate run --database-url "sqlite://$DB_FILE"

echo "Building release version of Jukka"
cargo build --release --target i686-unknown-linux-gnu

echo "Backing up existing files on $USER@$DST_HOST:$DST_DIR"
ssh $USER@$DST_HOST "[ -d $DST_DIR/backups ] || mkdir -p \"$DST_DIR/backups\""
ssh $USER@$DST_HOST "[ -f $DST_DIR/jukka ] && mv \"$DST_DIR/backups/jukka_$(date +%Y%m%d%H%M%S)\" || true"

for FILE in "${SRC_FILES[@]}"; do
    rsync -avz "$FILE" "$DST_HOST:$DST_DIR/"
done

echo "Deployment to $USER@$DST_HOST:$DST_DIR completed successfully."
