#!/bin/bash

set -e

COMMAND=$( [ -n "$1" ] && echo "$1" || echo "up" )

if [ $(grep "^user_allow_other" /etc/fuse.conf) ]; then
    echo "user_allow_other is already set in /etc/fuse.conf"
else
    echo "user_allow_other is not set in /etc/fuse.conf. Adding it now."
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi

echo "Command: $COMMAND"
case $COMMAND in
    "up")
        echo "Mounting jukka directory"
        sshfs maco@minimaco:/jukka ~/.sshfs/jukka \
            -o allow_other \
            -o uid=472 \
            -o gid=472
        echo "Starting Grafana with docker compose..."
        docker compose up -d
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
