#!/bin/bash

# Revert PM2 autostart setup on remote server

cleanup() {
  ssh-agent -k 2>/dev/null
  cd "$ORIGINAL_DIR" 2>/dev/null
}
trap cleanup EXIT

ORIGINAL_DIR=$(pwd)
source ./config.env

USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-$DEFAULT_RSA_PATH}
RSA_PATH="${RSA_PATH%$'\r'}"

if [[ ! -f "$RSA_PATH" ]]; then
  echo "Error: private key not found: $RSA_PATH"
  exit 1
fi

# start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add "$RSA_PATH"

# connect and undo PM2 + linger config
ssh -t -p 20127 "$USER@ieticloudpro.ieti.cat" << 'EOF'
set -e

REMOTE_USER=$(whoami)

# stop and disable user service
systemctl --user stop pm2-"$REMOTE_USER".service || true
systemctl --user disable pm2-"$REMOTE_USER".service || true

# remove PM2 startup hooks
sudo env PATH="$HOME/.npm-global/bin:$PATH" pm2 unstartup systemd -u "$REMOTE_USER" --hp "$HOME" || true

# kill PM2 daemon and clear dump
npx pm2 kill || true
rm -f ~/.pm2/dump.pm2

# disable user linger
sudo loginctl disable-linger "$REMOTE_USER" || true

# uninstall global pm2 if desired
sudo npm uninstall -g pm2 || true

echo "✔️  Autostart configuration undone."
EOF
