#!/bin/bash

source ./config.env

USER=${1:-$DEFAULT_USER}
RSA_PATH=${2:-$DEFAULT_RSA_PATH}

echo "User: $USER"
echo "Ruta RSA: $RSA_PATH"

if [[ ! -f "$RSA_PATH" ]]; then
  echo "Error: No s'ha trobat el fitxer de clau privada: $RSA_PATH"
  exit 1
fi

# Establir connexió SSH
ssh -i "$RSA_PATH" -p 20127 "$USER@ieticloudpro.ieti.cat"