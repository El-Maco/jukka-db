#!/bin/bash
set -euo pipefail

REMOTE="${REMOTE:-maco@minimaco}"
WEB_ROOT="/var/www/html"
API_DIR="/jukka-api"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/web"

echo "Backing up current site"
ssh "$REMOTE" "sudo test -f $WEB_ROOT/index.html.bak || sudo cp $WEB_ROOT/index.html $WEB_ROOT/index.html.bak"

echo "Uploading site"
ssh "$REMOTE" "rm -rf /tmp/jukka-web && mkdir -p /tmp/jukka-web"
rsync -az "$WEB/index.html" "$WEB/assets" "$WEB"/favicon* "$REMOTE:/tmp/jukka-web/"
ssh "$REMOTE" "sudo rm -rf $WEB_ROOT/api $WEB_ROOT/apache $WEB_ROOT/systemd $WEB_ROOT/deploy.sh && \
    sudo cp -a /tmp/jukka-web/. $WEB_ROOT/"

echo "Uploading API"
ssh "$REMOTE" "rm -rf /tmp/jukka-api && mkdir -p /tmp/jukka-api"
rsync -az "$WEB/api/jukka-api.py" "$ROOT/moist.sql" "$ROOT/moist-avg.sql" "$REMOTE:/tmp/jukka-api/"
ssh "$REMOTE" "sudo mkdir -p $API_DIR && sudo cp -a /tmp/jukka-api/. $API_DIR/ && sudo chown -R maco:maco $API_DIR"

echo "Installing service and Apache proxy"
rsync -az "$WEB/systemd/jukka-api.service" "$WEB/apache/maco-status.conf" "$REMOTE:/tmp/"
ssh "$REMOTE" "sudo install -m 644 /tmp/jukka-api.service /etc/systemd/system/jukka-api.service && \
    sudo install -m 644 /tmp/maco-status.conf /etc/apache2/conf-available/maco-status.conf && \
    sudo systemctl daemon-reload && \
    sudo systemctl enable --now jukka-api.service && \
    sudo systemctl restart jukka-api.service && \
    sudo apache2ctl configtest && \
    sudo systemctl reload apache2"

echo "Deployed to http://minimaco/"
