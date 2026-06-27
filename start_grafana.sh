#!/bin/bash

set -e

COMMAND=$( [ -n "$1" ] && echo "$1" || echo "up" )

if [ $(grep "^user_allow_other" /etc/fuse.conf) ]; then
    echo "user_allow_other is already set in /etc/fuse.conf"
else
    echo "user_allow_other is not set in /etc/fuse.conf. Adding it now."
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi

REMOTE="maco@minimaco"

JUKKA_DB="/jukka/jukka.db"
GRAFANA_DB="/jukka/jukka-read.db"

SERVICE_NAME="jukka-grafana-backup"
SCRIPT_PATH="/usr/local/bin/jukka-backup.sh"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_PATH="/etc/systemd/system/${SERVICE_NAME}.timer"

create_backup_service() {
    echo "Installing SQLite backup service on $REMOTE (if not already installed)..."

    ssh $REMOTE bash -s <<EOF
set -e

if [ -f "$SERVICE_PATH" ]; then
echo "Service already exists. Skipping installation."
exit 0
fi

echo "Creating backup script..."
sudo tee $SCRIPT_PATH > /dev/null <<EOL
#!/usr/bin/env bash
set -e

sqlite3 "$JUKKA_DB" ".backup '$GRAFANA_DB'"
EOL

sudo chmod +x $SCRIPT_PATH

echo "Creating systemd service..."
sudo tee $SERVICE_PATH > /dev/null <<EOL
[Unit]
Description=SQLite Backup Service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
EOL

echo "Creating systemd timer..."
sudo tee $TIMER_PATH > /dev/null <<EOL
[Unit]
Description=Run SQLite Backup every 30 minutes

[Timer]
OnBootSec=5s
OnUnitActiveSec=1800s
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOL

echo "Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "Enabling and starting timer..."
sudo systemctl enable --now ${SERVICE_NAME}.timer

echo "Installation complete on remote host."
EOF

echo "Done!"
}

echo "Command: $COMMAND"
case $COMMAND in
    "up")
        echo "Mounting jukka directory"
        sshfs $REMOTE:/jukka ~/.sshfs/jukka \
            -o allow_other \
            -o uid=472 \
            -o gid=472
        create_backup_service
        echo "Starting Grafana with docker compose..."
        docker compose up -d
        echo "Visit http://localhost:3000 to access Grafana."
        ;;
    "down")
        echo "Stopping Grafana with docker compose..."
        docker compose down
        echo "unmounting jukka directory"
        fusermount -u ~/.sshfs/jukka || echo "Failed to unmount ~/.sshfs/jukka. It may already be unmounted."
        ;;
    *)
        echo "Invalid command. Use 'up' to start or 'down' to stop."
        exit 1
        ;;
esac
echo "Done."
