#!/bin/bash

# Connects to the remote server, uploads the server package, and sets it up

# Function for cleanup on script exit
cleanup() {
    local exit_code=$?
    echo "Performing cleanup..."
    [[ -n "$ZIP_NAME" ]] && rm -f "../$ZIP_NAME"
    ssh-agent -k 2>/dev/null
    cd "$ORIGINAL_DIR" 2>/dev/null
    exit $exit_code
}
trap cleanup EXIT

# Store original directory
ORIGINAL_DIR=$(pwd)

source ./config.env

USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-"$DEFAULT_RSA_PATH"}
SERVER_PORT=${3:-$DEFAULT_SERVER_PORT}
RSA_PATH="${RSA_PATH%$'\r'}" 

echo "User: $USER"
echo "Ruta RSA: $RSA_PATH"
echo "Server port: $SERVER_PORT"

ZIP_NAME="server-package.zip"

cd ..

if [[ ! -f "$RSA_PATH" ]]; then
    echo "Error: No s'ha trobat el fitxer de clau privada: $RSA_PATH"
    exit 1
fi

rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" . -x "proxmox/*" "node_modules/*" "data/*" ".gitignore"

eval "$(ssh-agent -s)"
ssh-add "${RSA_PATH}"

scp -P 20127 "$ZIP_NAME" "$USER@ieticloudpro.ieti.cat:~/"
if [[ $? -ne 0 ]]; then
    echo "Error durant l'enviament SCP"
    exit 1
fi

rm -f "$ZIP_NAME"

ssh -t -p 20127 "$USER@ieticloudpro.ieti.cat" << EOF
    mkdir -p "\$HOME/nodejs_server"
    cd "\$HOME/nodejs_server"

    echo "Configurant el PATH per a Node.js..."
    export PATH="\$HOME/.npm-global/bin:/usr/local/bin:\$PATH"

    echo "Aturant el servidor amb Node.js..."
    if command -v node &>/dev/null; then
        node --run pm2stop || echo "Error en aturar el servidor. Intentant forçar..."
    fi

    pkill -f "node" || echo "No s'ha trobat cap procés de Node.js en execució."

    echo "Comprovant si el port $SERVER_PORT està alliberat..."
    MAX_RETRIES=10
    RETRIES=0
    while netstat -an | grep -q ":$SERVER_PORT.*LISTEN"; do
        echo "Esperant que el port $SERVER_PORT es desalliberi..."
        sleep 1
        RETRIES=\$((RETRIES + 1))
        if [[ \$RETRIES -ge \$MAX_RETRIES ]]; then
            echo "Error: El port $SERVER_PORT no es desallibera."
            exit 1
        fi
    done
    echo "Port $SERVER_PORT desalliberat."

    echo "Netejant el directori del servidor..."
    find . -mindepth 1 \( -name "node_modules" -o -name "data" -o -path "./.ssh" \) -prune -o -exec rm -rf {} + 2>/dev/null || true

    echo "Comprovant i instal·lant unzip si cal..."
    if ! command -v unzip &>/dev/null; then
        sudo apt update && sudo apt install -y unzip
    fi

    echo "Descomprimint el paquet..."
    unzip ../$ZIP_NAME -d .
    rm -f ../$ZIP_NAME

    echo "Configurant permissions..."
    chmod -R u+rw "\$HOME/nodejs_server"

    echo "Instal·lant dependències..."
    if [[ -f "package.json" ]]; then
        npm install
    else
        echo "Error: No s'ha trobat el fitxer package.json."
        exit 1
    fi

    echo "Reiniciant el servidor amb Node.js..."
    node --run pm2start || echo "Error en reiniciar el servidor amb Node.js."
EOF