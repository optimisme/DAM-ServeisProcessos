#!/bin/bash

# Reverts port redirection from 80

source ./config.env

USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-"$DEFAULT_RSA_PATH"}
SERVER_PORT=${3:-$DEFAULT_SERVER_PORT}
RSA_PATH="${RSA_PATH%$'\r'}"

echo "User: $USER"
echo "Ruta RSA: $RSA_PATH"
echo "Server port: $SERVER_PORT"

if [[ ! -f "${RSA_PATH}" ]]; then
  echo "Error: No s'ha trobat el fitxer de clau privada: $RSA_PATH"
  exit 1
fi

read -s -p "Introdueix la contrasenya de sudo per al servidor remot: " SUDO_PASSWORD
echo ""

eval "$(ssh-agent -s)"
ssh-add "${RSA_PATH}"

ssh -t -p 20127 "$USER@ieticloudpro.ieti.cat" << EOF
    # Remove all NAT redirections from port 80 to your \$SERVER_PORT
    echo "Eliminant redireccions al port 80 cap al port $SERVER_PORT..."
    while echo "$SUDO_PASSWORD" | sudo -S iptables-save -t nat \
          | grep -q -- "--dport 80.*--to-ports $SERVER_PORT"; do
        echo "$SUDO_PASSWORD" | sudo -S iptables -t nat -D PREROUTING \
             -p tcp --dport 80 -j REDIRECT --to-ports $SERVER_PORT
    done

    # Persist the empty/patched rules
    echo "$SUDO_PASSWORD" | sudo -S rm -r /etc/iptables/rules.v4

    echo "✔️  Configuració desactivada i redirecció eliminada."
EOF

ssh-agent -k
