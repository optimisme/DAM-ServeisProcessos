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

if [[ ! -f "$RSA_PATH" ]]; then
  echo "Error: private key not found: $RSA_PATH"
  exit 1
fi

cd ..
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" . -x "proxmox/*" "node_modules/*" "data/*" ".git*"

eval "$(ssh-agent -s)"
ssh-add "$RSA_PATH"
scp -P 20127 "$ZIP_NAME" "$USER@ieticloudpro.ieti.cat:~/"

ssh -t -p 20127 "$USER@ieticloudpro.ieti.cat" << 'EOF'
set -e

REMOTE_USER=$(whoami)

# prepare deployment dir
cd ~/nodejs_server || mkdir ~/nodejs_server && cd ~/nodejs_server

# stop old process
npm run pm2stop || true

# wait for port to free
for i in {1..10}; do
  ss -tln | grep -q ":$SERVER_PORT" && sleep 1 || break
done

# cleanup old files
find . -mindepth 1 -maxdepth 1 ! -name ".pm2" -exec rm -rf {} +

# unpack new code
unzip -o ~/server-package.zip
rm ~/server-package.zip

# install deps
npm install --production

# install pm2 CLI globally so systemd can find it
sudo npm install -g pm2

# enable user lingering
sudo loginctl enable-linger "$REMOTE_USER"

# start app
npm run pm2start

# save and setup startup
npx pm2 save
sudo env PATH="$HOME/.npm-global/bin:$PATH" pm2 startup systemd -u "$REMOTE_USER" --hp "$HOME" | tail -1 | bash
npx pm2 save

# enable & start the user service immediately
systemctl --user enable pm2-"$REMOTE_USER".service
systemctl --user start pm2-"$REMOTE_USER".service

echo "✔️  Autostart configured via npx + linger + global pm2."
EOF
