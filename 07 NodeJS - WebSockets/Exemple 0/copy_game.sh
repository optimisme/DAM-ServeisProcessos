#!/bin/bash

echo "Copy game assets to 'server' and 'client'"
cp -r flag_game* client_flutter/assets
cp -r flag_game* server_nodejs/server