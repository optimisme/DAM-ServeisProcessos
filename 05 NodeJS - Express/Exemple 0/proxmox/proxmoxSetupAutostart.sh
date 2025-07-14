#!/bin/bash

cleanup() {
  ssh-agent -k 2>/dev/null
  cd "$ORIGINAL_DIR" 2>/dev/null
}
trap cleanup EXIT

ORIGINAL_DIR=$(pwd)
source ./config.env

USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-$DEFAULT_RSA_PATH}
SERVER_PORT=${3:-$DEFAULT_SERVER_PORT}
RSA_PATH="${RSA_PATH%$'\r'}"
ZIP_NAME="server-package.zip"

# validate SSH key
if [[ ! -f "$RSA_PATH" ]]; then
  echo "Error: private key not found: $RSA_PATH"
  exit 1
fi

# package up sources, excluding proxmox scripts, node_modules, data and git
cd ..
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" . -x "proxmox/*" "node_modules/*" "data/*" ".git*"

# start SSH agent and copy archive
eval "$(ssh-agent -s)"
ssh-add "$RSA_PATH"
scp -P 20127 "$ZIP_NAME" "$USER@ieticloudpro.ieti.cat:~/"

# remote deploy & autostart setup
ssh -t -p 20127 "$USER@ieticloudpro.ieti.cat" << 'EOF'
set -e

REMOTE_USER=$(whoami)

cd ~/nodejs_server || mkdir ~/nodejs_server && cd ~/nodejs_server

# stop old PM2 process if running
npm run pm2stop || true

# wait for port to free
for i in {1..10}; do
  ss -tln | grep -q ":$SERVER_PORT" && sleep 1 || break
done

# clean old files EXCEPT .pm2 and data
# -> preserve ./data across deploys
find . -mindepth 1 -maxdepth 1 \
  ! -name ".pm2" \
  ! -name "data" \
  -exec rm -rf {} +

# unpack new code
unzip -o ~/server-package.zip
rm ~/server-package.zip

# install production deps
npm install --production

# ensure pm2 CLI exists for systemd unit
sudo npm install -g pm2

# enable lingering so --user services run at boot
sudo loginctl enable-linger "$REMOTE_USER"

# start app via npm script
npm run pm2start

# save process list and configure startup
npx pm2 save
sudo env PATH="$HOME/.npm-global/bin:$PATH" \
  pm2 startup systemd -u "$REMOTE_USER" --hp "$HOME" | tail -1 | bash
npx pm2 save

# enable & start the per-user pm2 service now
systemctl --user enable pm2-"$REMOTE_USER".service
systemctl --user start pm2-"$REMOTE_USER".service

echo "✔️  Autostart configured via npx + linger; carpeta data preservada."
EOF
