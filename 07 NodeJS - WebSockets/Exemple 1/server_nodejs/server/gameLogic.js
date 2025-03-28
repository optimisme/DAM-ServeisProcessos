'use strict';
const fs = require('fs');
const gameData = JSON.parse(fs.readFileSync("server/platform_game/game_data.json", "utf8"));
const gameLevel = gameData.levels[0];

const COLORS = ['green', 'blue', 'orange', 'red', 'purple'];
const FOCUS_WIDTH = 1000;
const FOCUS_HEIGHT = 500;
const PLAYER_RADIUS = 32;
const FRICTION_FLOOR = 350;
const FRICTION_ICE = 50;
const FRICTION_AIR = 5;
const GRAVITY = 500;
const HORIZONTAL_SPEED = 100;
const JUMP_IMPULSE = 400;

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
            onFloor: false,
            direction: "none",
            color,
            radius: PLAYER_RADIUS
        });

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
            case "jump":
                let client = this.players.get(id);
                if (client && client.onFloor) {
                    client.speedY = -JUMP_IMPULSE;
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
        this.players.forEach(client => {
            let moveVector = DIRECTIONS[client.direction];
            if (moveVector.dx !== 0) {
                client.speedX = moveVector.dx * HORIZONTAL_SPEED;
            } else {
                let friction = FRICTION_AIR;
                if (client.onFloor) {
                    friction = FRICTION_FLOOR;
                    if (gameLevel && gameLevel.zones) {
                        gameLevel.zones.forEach(zone => {
                            let seg0start = { x: client.x, y: client.y }
                            let seg0end = { x: client.x, y: (client.y + client.radius + 10) }
                            let seg1start = { x: zone.x, y: zone.y }
                            let seg1end = { x: zone.x + zone.width, y: zone.y }
                            if (["ice"].includes(zone.type) &&
                                this.segmentsIntersect(seg0start, seg0end, seg1start, seg1end)) {
                                friction = FRICTION_ICE;
                            }
                        });
                    }
                }
                if (client.speedX > 0) {
                    client.speedX = Math.max(0, client.speedX - friction * deltaTime);
                } else if (client.speedX < 0) {
                    client.speedX = Math.min(0, client.speedX + friction * deltaTime);
                }
            }
            client.x += client.speedX * deltaTime;

            // Vertical collision check
            let nextY = client.y + client.speedY * deltaTime;
            let verticalCollision = false;
            let collidedZone = null;
            if (gameLevel && gameLevel.zones) {
                gameLevel.zones.forEach(zone => {
                    let seg0start = { x: client.x, y: client.y }
                    let seg0end = { x: client.x, y: (nextY + client.radius) }
                    let seg1start = { x: zone.x, y: zone.y }
                    let seg1end = { x: zone.x + zone.width, y: zone.y }
                    if (["floor", "ice"].includes(zone.type) &&
                        this.segmentsIntersect(seg0start, seg0end, seg1start, seg1end)) {
                        verticalCollision = true;
                        collidedZone = zone;
                    }
                });
            }
            if (verticalCollision && client.speedY >= 0) {
                client.speedY = 0;
                client.onFloor = true;
                client.y = collidedZone.y - (client.radius / 2);
            } else {
                client.speedY += GRAVITY * deltaTime;
                client.onFloor = false;
                client.y = nextY;
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
        let assignedColors = new Set(Array.from(this.players.values()).map(client => client.color));
        let availableColors = COLORS.filter(color => !assignedColors.has(color));
        return availableColors.length > 0 
          ? availableColors[Math.floor(Math.random() * availableColors.length)]
          : COLORS[Math.floor(Math.random() * COLORS.length)];
    }

    // Diu si dos segments de recta, interseccionen
    segmentsIntersect(p, q, r, s) { 
        function orientation(a, b, c) {
            const val = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
            return val === 0 ? 0 : (val > 0 ? 1 : 2);
        }
        function onSegment(a, b, c) {
            return c.x <= Math.max(a.x, b.x) && c.x >= Math.min(a.x, b.x) &&
                    c.y <= Math.max(a.y, b.y) && c.y >= Math.min(a.y, b.y);
        }
        const o1 = orientation(p, q, r);
        const o2 = orientation(p, q, s);
        const o3 = orientation(r, s, p); 
        const o4 = orientation(r, s, q);
        if (o1 !== o2 && o3 !== o4) return true;
        if (o1 === 0 && onSegment(p, q, r)) return true;
        if (o2 === 0 && onSegment(p, q, s)) return true;
        if (o3 === 0 && onSegment(r, s, p)) return true;
        if (o4 === 0 && onSegment(r, s, q)) return true;
        return false;
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
            level: "Level 0",
            players: Array.from(this.players.values())
        };
    }
}

module.exports = GameLogic;