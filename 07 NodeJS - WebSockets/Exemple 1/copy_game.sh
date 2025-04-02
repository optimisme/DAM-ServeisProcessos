#!/bin/bash

echo "Copy game assets to 'server' and 'client'"
cp -r platform_game* client_flutter/assets
cp -r platform_game* server_nodejs/server