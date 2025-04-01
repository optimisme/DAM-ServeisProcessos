'use strict';
const fs = require('fs');
const gameData = JSON.parse(fs.readFileSync("server/flag_game/game_data.json", "utf8"));
const gameLevel = gameData.levels[0];

const COLORS = ['green', 'blue', 'orange', 'red', 'purple'];
const TICK_FPS = 25;
const FOCUS_WIDTH = 1000;
const FOCUS_HEIGHT = 500;
const PLAYER_RADIUS = 32;
const FRICTION_FLOOR = 350;
const FRICTION_ICE = 50;
const MOVEMENT_SPEED = 100;

const DIRECTIONS = {
    "up":         { dx: 0, dy: -1 },
    "upLeft":     { dx: -1, dy: -1 },
    "left":       { dx: -1, dy: 0 },
    "downLeft":   { dx: -1, dy: 1 },
    "down":       { dx: 0, dy: 1 },
    "downRight":  { dx: 1, dy: 1 },
    "right":      { dx: 1, dy: 0 },
    "upRight":    { dx: 1, dy: -1 },
    "none":       { dx: 0, dy: 0 }
};
 
class GameLogic {
    constructor() {
        this.players = new Map();
        this.tickCounter = 0;
    }

    // Es connecta un client/jugador
    addClient(id) {
        let pos = this.getValidPosition();
        let color = this.getAvailableColor();

        this.players.set(id, {
            id,
            x: pos.x,
            y: pos.y,
            speedX: 0,
            speedY: 0,
            direction: "none",
            color,
            radius: PLAYER_RADIUS,
            onIce: false
        });
        this.flagOwnerId = "";

        return this.players.get(id);
    }

    // Es desconnecta un client/jugador
    removeClient(id) {
        this.players.delete(id);
    }

    // Tractar un missatge d'un client/jugador
    handleMessage(id, msg) {
        try {
            let obj = JSON.parse(msg);
            if (!obj.type) return;
            switch (obj.type) {
            case "direction":
                if (this.players.has(id) && DIRECTIONS[obj.value]) {
                    this.players.get(id).direction = obj.value;
                }
                break;
            default:
                break;
            }
        } catch (error) {}
    }

    // Blucle de joc (funció que s'executa contínuament)
    updateGame(fps) {
        let deltaTime = 1 / fps;

        this.tickCounter = (this.tickCounter + 1) % TICK_FPS;

        this.players.forEach(player => {
            let moveVector = DIRECTIONS[player.direction];
            
            // Check if player is on ice
            player.onIce = false;
            if (gameLevel && gameLevel.zones) {
                gameLevel.zones.forEach(zone => {
                    if (zone.type === "ice" && this.isCircleRectColliding(
                        player.x, player.y, player.radius, 
                        zone.x, zone.y, zone.width, zone.height)) {
                        player.onIce = true;
                    }
                });
            }
            
            // Apply movement and friction based on surface
            const friction = player.onIce ? FRICTION_ICE : FRICTION_FLOOR;
            
            // Handle X movement
            if (moveVector.dx !== 0) {
                player.speedX = moveVector.dx * MOVEMENT_SPEED;
            } else {
                if (player.speedX > 0) {
                    player.speedX = Math.max(0, player.speedX - friction * deltaTime);
                } else if (player.speedX < 0) {
                    player.speedX = Math.min(0, player.speedX + friction * deltaTime);
                }
            }
            
            // Handle Y movement
            if (moveVector.dy !== 0) {
                player.speedY = moveVector.dy * MOVEMENT_SPEED;
            } else {
                if (player.speedY > 0) {
                    player.speedY = Math.max(0, player.speedY - friction * deltaTime);
                } else if (player.speedY < 0) {
                    player.speedY = Math.min(0, player.speedY + friction * deltaTime);
                }
            }
            
            // Calculate next position
            let nextX = player.x + player.speedX * deltaTime;
            let nextY = player.y + player.speedY * deltaTime;
            
            // Check collisions with floor areas (unwalkable)
            let canMoveX = true;
            let canMoveY = true;
            
            if (gameLevel && gameLevel.zones) {
                gameLevel.zones.forEach(zone => {
                    if (zone.type === "stone") {
                        // Check X collision
                        if (this.isCircleRectColliding(
                            nextX, player.y, player.radius, 
                            zone.x, zone.y, zone.width, zone.height)) {
                            canMoveX = false;
                        }
                        
                        // Check Y collision
                        if (this.isCircleRectColliding(
                            player.x, nextY, player.radius, 
                            zone.x, zone.y, zone.width, zone.height)) {
                            canMoveY = false;
                        }
                    }
                });
            }
            
            // Apply movement if allowed
            if (canMoveX) {
                player.x = nextX;
            } else {
                player.speedX = 0;
            }
            
            if (canMoveY) {
                player.y = nextY;
            } else {
                player.speedY = 0;
            }
            
            // Check flag collision
            if (this.flagOwnerId == "") {
                let flag = gameLevel.sprites.find(sprite => sprite.type === 'flag');
                if (flag && this.isCircleRectColliding(player.x, player.y, player.radius, flag.x, flag.y, flag.width, flag.height)) {
                    this.flagOwnerId = player.id;
                }
            }
        });
    }

    // Obtenir una posició on no hi h ha ni objectes ni jugadors
    getValidPosition() {
        let x = FOCUS_WIDTH / 2;
        let y = FOCUS_HEIGHT / 2;
        
        return { x, y };
    }
    
    // Obtenir un color aleatori que no ha estat escollit abans
    getAvailableColor() {
        let assignedColors = new Set(Array.from(this.players.values()).map(player => player.color));
        let availableColors = COLORS.filter(color => !assignedColors.has(color));
        return availableColors.length > 0 
          ? availableColors[Math.floor(Math.random() * availableColors.length)]
          : COLORS[Math.floor(Math.random() * COLORS.length)];
    }

    // Detectar si un cercle i un rectangle es sobreposen
    isCircleRectColliding(cx, cy, r, rx, ry, rw, rh) {
        let closestX = Math.max(rx, Math.min(cx, rx + rw));
        let closestY = Math.max(ry, Math.min(cy, ry + rh));
        let dx = cx - closestX;
        let dy = cy - closestY;
        return (dx * dx + dy * dy) <= (r * r);
    }

    // Detectar si dos cercles es sobreposen
    isCircleCircleColliding(x1, y1, r1, x2, y2, r2) {
        let dx = x1 - x2;
        let dy = y1 - y2;
        return (dx * dx + dy * dy) <= ((r1 + r2) * (r1 + r2));
    }

    // Retorna l'estat del joc (per enviar-lo als clients/jugadors)
    getGameState() {
        return {
            tickCounter: this.tickCounter,
            level: "Level 0",
            players: Array.from(this.players.values()),
            flagOwnerId: this.flagOwnerId
        };
    }
}

module.exports = GameLogic;