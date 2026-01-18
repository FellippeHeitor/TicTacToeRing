// Tic Tac Toe Ring - JavaScript Version
// Based on the QB64 original by Fellippe Heitor

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

// Game constants
const MODE_NORMAL = 0;
const MODE_EASIER = 1;

// Game state
let gameState = {
    score: 0,
    visibleScore: 0,
    highscore: 0,
    visibleHighScore: 0,
    level: 0,
    maxColors: 3,
    multiplier: 1,
    mode: MODE_NORMAL,
    gameOver: false,
    pauseGame: false,
    music: true,
    sfx: true
};

// Settings modal state
let showSettingsModal = false;
let settingsButtons = [];
let settingsModalAlpha = 0;

// Ring colors (10 colors)
const ringColors = [
    { r: 0, g: 78, b: 249 },     // blue
    { r: 0, g: 100, b: 0 },       // green
    { r: 222, g: 61, b: 44 },     // red
    { r: 216, g: 216, b: 44 },    // yellow
    { r: 233, g: 139, b: 17 },    // orange
    { r: 222, g: 105, b: 161 },   // pink
    { r: 139, g: 11, b: 205 },    // purple
    { r: 55, g: 211, b: 211 },    // cyan
    { r: 255, g: 255, b: 255 },   // white
    { r: 100, g: 100, b: 100 }    // dark gray
];

// Combo messages
const megaComboMsg = ['Fantastic', 'Outstanding', 'Amazing', 'Awesome', 'MEGA', 'SUPER'];

// Pegs (9 game board + 3 spawn area)
let pegs = [];
const emptySet = [-1, -1, -1];

// Particles
let particles = [];
const MAX_PARTICLES = 5000;

// Animations
let animations = [];

// Mouse state
let mouse = {
    x: 0,
    y: 0,
    down: false,
    dragging: -1,
    clicked: false
};

// Mouse coordinates (for modal)
let mouseX = 0;
let mouseY = 0;

// Buttons
let buttons = [];
let currentButton = -1;

// Audio
let sounds = {
    select: null,
    woosh: null,
    woodblock: null,
    track1: null,
    combo: []
};

// Ring images cache
let ringImages = {};

// Initialize pegs
function initPegs() {
    pegs = [];
    const spacing = 6;
    let l = -(canvas.height / spacing);
    let j = 0;
    
    // 12 pegs total (9 game board + 3 spawn area)
    for (let i = 0; i < 12; i++) {
        j++;
        if (j > 3) {
            j = 1;
            l += canvas.height / spacing;
        }
        
        let k;
        switch (j) {
            case 1: k = -canvas.width / spacing; break;
            case 2: k = 0; break;
            case 3: k = canvas.width / spacing; break;
        }
        
        pegs.push({
            x: canvas.width / 2 + k,
            y: canvas.height / 2 + l,
            rings: [...emptySet]
        });
    }
}

// Distance helper
function dist(x1, y1, x2, y2) {
    return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
}

// Map helper
function map(value, minRange, maxRange, newMinRange, newMaxRange) {
    return ((value - minRange) / (maxRange - minRange)) * (newMaxRange - newMinRange) + newMinRange;
}

// Lerp helper
function lerp(start, end, amt) {
    return start + (end - start) * amt;
}

// Add particles
function addParticles(x, y, count, color) {
    for (let i = 0; i < count && particles.length < MAX_PARTICLES; i++) {
        const angle = Math.random() * Math.PI * 2;
        particles.push({
            x: x,
            y: y,
            vx: Math.cos(angle) * (Math.random() * 10),
            vy: Math.sin(angle) * (Math.random() * 10),
            color: color,
            size: Math.ceil(Math.random() * 3),
            life: Math.random(),
            maxLife: Math.random(),
            active: true
        });
    }
}

// Draw filled circle
function drawCircle(x, y, radius, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
}

// Draw ring
function drawRing(x, y, size, colorIndex) {
    // Size 1 = smallest (inner), Size 2 = medium, Size 3 = largest (outer)
    const outerRadius = size * 14;
    const innerRadius = size * (8 + size);
    const ringWidth = outerRadius - innerRadius;
    const ringRadius = (outerRadius + innerRadius) / 2;
    const color = ringColors[colorIndex];
    const colorStr = `rgb(${color.r}, ${color.g}, ${color.b})`;
    
    // Draw ring as a thick stroke
    ctx.strokeStyle = colorStr;
    ctx.lineWidth = ringWidth;
    ctx.beginPath();
    ctx.arc(x, y, ringRadius, 0, Math.PI * 2);
    ctx.stroke();
}

// Update particles
function updateParticles(dt) {
    particles = particles.filter(p => {
        if (!p.active) return false;
        
        p.vy += 0.1; // gravity
        p.x += p.vx;
        p.y += p.vy;
        p.life -= dt * 2;
        
        if (p.x < 0 || p.x > canvas.width || p.y < 0 || p.y > canvas.height || p.life <= 0) {
            return false;
        }
        
        return true;
    });
}

// Draw particles
function drawParticles() {
    particles.forEach(p => {
        const alpha = Math.max(0, p.life / p.maxLife);
        const particleColor = `rgba(${p.color.r}, ${p.color.g}, ${p.color.b}, ${alpha})`;
        drawCircle(p.x, p.y, p.size, particleColor);
    });
}

// Draw background
function drawBackground() {
    // Gradient background
    const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
    gradient.addColorStop(0, '#1a0e2e');
    gradient.addColorStop(1, '#16162d');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Subtle scan lines
    ctx.fillStyle = 'rgba(139, 116, 177, 0.02)';
    for (let i = 0; i < canvas.height; i += 10) {
        ctx.fillRect(0, i, canvas.width, 1);
    }
}

// Draw board divisions
function drawBoardDivisions() {
    const spacing = 6;
    
    // Game board area
    ctx.strokeStyle = 'rgba(0, 50, 100, 0.3)';
    ctx.lineWidth = 2;
    ctx.strokeRect(
        canvas.width / 2 - (canvas.width / spacing) * 1.5,
        canvas.height / 2 - (canvas.height / spacing) * 1.5,
        canvas.width / spacing * 3,
        canvas.height / spacing * 3
    );
    
    // Spawn area
    ctx.strokeStyle = 'rgba(255, 150, 50, 0.2)';
    ctx.strokeRect(
        pegs[9].x - (canvas.width / spacing / 2),
        pegs[9].y - (canvas.height / spacing / 2),
        (pegs[11].x - pegs[9].x) + canvas.width / spacing,
        canvas.height / spacing
    );
}

// Draw pegs
function drawPegs() {
    for (let i = 0; i < 9; i++) {
        drawCircle(pegs[i].x, pegs[i].y, 3, '#fff');
    }
}

// Hover highlight effect
function drawHoverHighlight() {
    if (mouse.dragging >= 0) return;
    
    for (let i = 9; i < 12; i++) {
        if (pegs[i].rings.every(r => r === -1)) continue;
        
        if (dist(pegs[i].x, pegs[i].y, mouse.x, mouse.y) <= 40) {
            // Determine halo size based on largest ring present
            // Index 0 = largest, Index 1 = medium, Index 2 = smallest
            let halo = 12;
            if (pegs[i].rings[0] >= 0) halo = 40; // Large ring
            else if (pegs[i].rings[1] >= 0) halo = 25; // Medium ring
            else if (pegs[i].rings[2] >= 0) halo = 12; // Small ring
            
            // Pulsing glow effect
            const time = Date.now() / 100;
            const glow = 8 + Math.sin(time) * 4;
            
            for (let j = glow; j > 8; j -= 0.5) {
                const alpha = (j - 8) / 8;
                drawCircle(pegs[i].x, pegs[i].y, halo + (glow - j) * 0.8, `rgba(255, 255, 255, ${alpha * 0.3})`);
                drawCircle(pegs[i].x, pegs[i].y, (halo / 2) + (glow - j) * 0.8, `rgba(0, 0, 0, ${alpha * 0.3})`);
            }
            break;
        }
    }
}

// Draw rings on pegs
function drawRings() {
    for (let i = 0; i < pegs.length; i++) {
        const peg = pegs[i];
        let x = peg.x;
        let y = peg.y;
        
        // If dragging this peg, move to mouse
        if (mouse.dragging === i) {
            x = mouse.x;
            y = mouse.y;
        }
        
        // Draw rings from largest to smallest (so smaller appear on top/inside)
        // Index 0 = largest (size 3), Index 1 = medium (size 2), Index 2 = smallest (size 1)
        for (let ringIdx = 0; ringIdx < 3; ringIdx++) {
            const colorIndex = peg.rings[ringIdx];
            if (colorIndex >= 0) {
                const size = 3 - ringIdx; // Convert: 0→3, 1→2, 2→1
                drawRing(x, y, size, colorIndex);
            }
        }
    }
}

// Draw text (simple bitmap font simulation)
function drawText(text, x, y, size = 1, color = '#fff') {
    ctx.fillStyle = color;
    ctx.font = `${size * 16}px monospace`;
    ctx.fillText(text, x, y);
}

// Draw centered text
function drawCenteredText(text, y, size = 1, color = '#fff') {
    ctx.font = `${size * 16}px monospace`;
    const width = ctx.measureText(text).width;
    drawText(text, (canvas.width - width) / 2, y, size, color);
}
// Helper: rounded rectangle
function roundRect(ctx, x, y, width, height, radius) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
}

// Draw HUD
function drawHUD() {
    // Crown icon (simple)
    ctx.fillStyle = '#cda100';
    ctx.fillRect(25, 28, 20, 12);
    drawText(Math.floor(gameState.visibleHighScore), 52, 40, 1, '#c8c8c8');
    
    // Score
    drawText(Math.floor(gameState.visibleScore), 10, 90, 6, '#fff');
    
    // Multiplier
    if (gameState.multiplier > 1) {
        drawText(`x${gameState.multiplier}`, 52, 145, 1, '#fff');
    }
    
    // Buttons
    drawButtons();
}

// Create main screen buttons
function createMainButtons() {
    buttons = [
        { x: canvas.width - 80, y: 20, w: 60, h: 30, text: 'Settings' },
        { x: canvas.width - 80, y: 60, w: 60, h: 30, text: 'Pause' }
    ];
}

// Draw buttons
function drawButtons() {
    buttons.forEach((btn, i) => {
        const isHovered = currentButton === i;
        ctx.fillStyle = isHovered ? 'rgba(67, 172, 183, 0.5)' : 'rgba(50, 50, 50, 0.5)';
        ctx.fillRect(btn.x, btn.y, btn.w, btn.h);
        ctx.strokeStyle = isHovered ? '#43acb7' : '#888';
        ctx.lineWidth = 2;
        ctx.strokeRect(btn.x, btn.y, btn.w, btn.h);
        
        ctx.fillStyle = '#fff';
        ctx.font = '12px monospace';
        const textWidth = ctx.measureText(btn.text).width;
        ctx.fillText(btn.text, btn.x + (btn.w - textWidth) / 2, btn.y + 20);
    });
}

// Check button hover
function checkButtonHover() {
    let hovering = -1;
    buttons.forEach((btn, i) => {
        if (mouse.x >= btn.x && mouse.x <= btn.x + btn.w &&
            mouse.y >= btn.y && mouse.y <= btn.y + btn.h) {
            hovering = i;
        }
    });
    currentButton = hovering;
}

// Generate new sets in spawn area
function generateNewSets() {
    // Check if all 3 spawn pegs are empty
    let allEmpty = true;
    for (let i = 9; i < 12; i++) {
        if (!pegs[i].rings.every(r => r === -1)) {
            allEmpty = false;
            break;
        }
    }
    
    if (allEmpty) {
        gameState.level++;
        
        // Calculate max colors based on mode
        if (gameState.mode === MODE_NORMAL) {
            gameState.maxColors = Math.floor(map(gameState.level, 1, 45, 3, ringColors.length));
        } else {
            gameState.maxColors = Math.floor(map(gameState.score, 1, 500, 3, ringColors.length));
        }
        gameState.maxColors = Math.max(3, Math.min(ringColors.length, gameState.maxColors));
        
        // Generate 3 new sets based on board state
        let pegsUsed = [];
        
        for (let i = 9; i < 12; i++) {
            pegs[i].rings = [...emptySet];
            
            // Choose a random board peg that has empty slots
            let newPeg = Math.floor(Math.random() * 9);
            let thisPeg = newPeg;
            let found = false;
            
            // Find a board peg with at least one empty slot
            do {
                const hasEmptySlot = pegs[thisPeg].rings.some(r => r === -1);
                const notUsed = !pegsUsed.includes(thisPeg);
                
                if (hasEmptySlot && notUsed) {
                    found = true;
                    break;
                }
                
                thisPeg = (thisPeg + 1) % 9;
                if (thisPeg === newPeg) break; // Full circle
            } while (true);
            
            if (found) {
                pegsUsed.push(thisPeg);
            } else {
                thisPeg = 0; // Will generate random set
            }
            
            // Generate rings based on chosen peg's empty slots
            // Spawn sets should have 1-2 rings only
            do {
                pegs[i].rings = [...emptySet];
                
                if (found && thisPeg >= 0) {
                    // Generate based on empty slots in chosen board peg
                    for (let j = 0; j < 3; j++) {
                        if (pegs[thisPeg].rings[j] === -1) {
                            // 30% chance to add a ring in this position
                            if (Math.random() * 100 < 30) {
                                pegs[i].rings[j] = Math.floor(Math.random() * gameState.maxColors);
                            }
                        }
                    }
                } else {
                    // Random generation - pick 1 or 2 random positions
                    const numRings = Math.random() < 0.6 ? 2 : 1;
                    const positions = [0, 1, 2].sort(() => Math.random() - 0.5).slice(0, numRings);
                    positions.forEach(pos => {
                        pegs[i].rings[pos] = Math.floor(Math.random() * gameState.maxColors);
                    });
                }
            } while (pegs[i].rings.every(r => r === -1)); // Can't be completely empty
            
            // Make sure we don't have all 3 slots filled (max 2 rings per spawn set)
            const filledCount = pegs[i].rings.filter(r => r >= 0).length;
            if (filledCount > 2) {
                // Remove random ring to ensure max 2 rings
                const filled = [];
                pegs[i].rings.forEach((r, idx) => { if (r >= 0) filled.push(idx); });
                const removeIdx = filled[Math.floor(Math.random() * filled.length)];
                pegs[i].rings[removeIdx] = -1;
            }
        }
        
        // Flash effect
        animations.push({
            type: 'spawn',
            startTime: Date.now(),
            duration: 1000
        });
    }
}

// Check for matches
function checkMatches(pegIndex) {
    let totalScore = 0;
    let scored = false;
    
    // Create backup copies for deletion marking
    let delPegs = pegs.slice(0, 9).map(p => ({ rings: [...p.rings] }));
    
    // Check for 3 same-color rings on same peg
    const rings = delPegs[pegIndex].rings;
    if (rings[0] >= 0 && rings[0] === rings[1] && rings[1] === rings[2]) {
        totalScore += 3;
        delPegs[pegIndex].rings = [...emptySet];
        scored = true;
        
        // Add particles
        const ringColor = ringColors[rings[0]];
        addParticles(pegs[pegIndex].x, pegs[pegIndex].y, 70, ringColor);
        addParticles(pegs[pegIndex].x, pegs[pegIndex].y, 30, {
            r: Math.min(255, ringColor.r + 30),
            g: Math.min(255, ringColor.g + 30),
            b: Math.min(255, ringColor.b + 30)
        });
        
        // Add animation
        animations.push({
            type: 'peg',
            peg: pegIndex,
            color: ringColor,
            startTime: Date.now(),
            duration: 500
        });
    }
    
    // Check lines (horizontal, vertical, diagonal)
    const lineConfigs = [
        // Horizontal
        { lines: [[0, 1, 2], [3, 4, 5], [6, 7, 8]], type: 'horizontal' },
        // Vertical
        { lines: [[0, 3, 6], [1, 4, 7], [2, 5, 8]], type: 'vertical' },
        // Diagonal
        { lines: [[0, 4, 8]], type: 'diagonal1' },
        { lines: [[2, 4, 6]], type: 'diagonal2' }
    ];
    
    lineConfigs.forEach(config => {
        config.lines.forEach(line => {
            // Get all colors present in each peg of the line
            const peg0Colors = delPegs[line[0]].rings.filter(c => c >= 0);
            const peg1Colors = delPegs[line[1]].rings.filter(c => c >= 0);
            const peg2Colors = delPegs[line[2]].rings.filter(c => c >= 0);
            
            // Find colors that appear in all three pegs
            const commonColors = peg0Colors.filter(color => 
                peg1Colors.includes(color) && peg2Colors.includes(color)
            );
            
            // For each common color, mark all rings of that color for deletion
            commonColors.forEach(matchColor => {
                // Mark all rings of this color in these pegs for deletion
                line.forEach(pegIdx => {
                    for (let s = 0; s < 3; s++) {
                        if (delPegs[pegIdx].rings[s] === matchColor) {
                            delPegs[pegIdx].rings[s] = -1;
                            totalScore++;
                            scored = true;
                            
                            // Add particles
                            const lineColor = ringColors[matchColor];
                            addParticles(pegs[pegIdx].x, pegs[pegIdx].y, 23, lineColor);
                            addParticles(pegs[pegIdx].x, pegs[pegIdx].y, 10, {
                                r: Math.min(255, lineColor.r + 30),
                                g: Math.min(255, lineColor.g + 30),
                                b: Math.min(255, lineColor.b + 30)
                            });
                        }
                    }
                });
                
                // Add line animation
                animations.push({
                    type: config.type,
                    line: line,
                    color: ringColors[matchColor],
                    startTime: Date.now(),
                    duration: 500
                });
            });
        });
    });
    
    // Apply deletions to actual pegs
    if (scored) {
        for (let i = 0; i < 9; i++) {
            pegs[i].rings = [...delPegs[i].rings];
        }
        
        // Update score
        gameState.score += totalScore * gameState.multiplier;
        gameState.multiplier++;
        
        // Play sounds
        if (sounds.woosh) playSound(sounds.woosh);
        
        const comboIndex = Math.min(gameState.multiplier - 2, sounds.combo.length - 1);
        if (comboIndex >= 0 && sounds.combo[comboIndex]) {
            playSound(sounds.combo[comboIndex]);
        }
        
        // Add board flash
        animations.push({
            type: 'flash',
            startTime: Date.now(),
            duration: 250
        });
        
        // Add combo animation
        if (gameState.multiplier > 1) {
            const msg = megaComboMsg[Math.floor(Math.random() * megaComboMsg.length)];
            animations.push({
                type: 'combo',
                message: `${msg}\n${gameState.multiplier}x combo!`,
                startTime: Date.now(),
                duration: 3000
            });
        }
        
        if (gameState.score > gameState.highscore) {
            gameState.highscore = gameState.score;
        }
    } else {
        gameState.multiplier = 1;
    }
    
    return scored;
}

// Check available moves
function checkAvailableMoves() {
    if (mouse.dragging >= 0) return true;
    
    // Check if there are any sets in spawn area
    let hasSpawnSets = false;
    for (let i = 9; i < 12; i++) {
        if (!pegs[i].rings.every(r => r === -1)) {
            hasSpawnSets = true;
            break;
        }
    }
    
    if (!hasSpawnSets) return true; // Will generate new sets
    
    // Check if any spawn set can fit anywhere on the board
    let canMove = false;
    for (let s = 9; s < 12; s++) {
        const spawnSet = pegs[s].rings;
        if (spawnSet.every(r => r === -1)) continue;
        
        for (let b = 0; b < 9; b++) {
            const boardSet = pegs[b].rings;
            let canPlace = true;
            
            for (let i = 0; i < 3; i++) {
                if (spawnSet[i] >= 0 && boardSet[i] >= 0) {
                    canPlace = false;
                    break;
                }
            }
            
            if (canPlace) {
                canMove = true;
                break;
            }
        }
        if (canMove) break;
    }
    
    if (canMove) return true;
    
    // Check if board is completely full
    let boardString = '';
    for (let i = 0; i < 9; i++) {
        boardString += pegs[i].rings.join(',');
    }
    
    return boardString.includes('-1');
}

// Update score animation
function updateScore(dt) {
    if (gameState.visibleScore < gameState.score) {
        gameState.visibleScore += dt * 20;
        if (gameState.visibleScore > gameState.score) {
            gameState.visibleScore = gameState.score;
        }
    }
    
    if (gameState.visibleHighScore < gameState.highscore) {
        gameState.visibleHighScore += dt * 20;
        if (gameState.visibleHighScore > gameState.highscore) {
            gameState.visibleHighScore = gameState.highscore;
        }
    }
}

// Update animations
function updateAnimations() {
    const now = Date.now();
    
    animations.forEach(anim => {
        const elapsed = now - anim.startTime;
        const progress = Math.min(1, elapsed / anim.duration);
        
        if (anim.type === 'spawn') {
            const alpha = Math.sin(progress * Math.PI) * 0.5;
            ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
            ctx.lineWidth = 2;
            for (let i = 9; i < 12; i++) {
                const size = 50 * (1 - progress);
                ctx.beginPath();
                ctx.arc(pegs[i].x, pegs[i].y, size, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(pegs[i].x, pegs[i].y, size * 1.5, 0, Math.PI * 2);
                ctx.stroke();
            }
        } else if (anim.type === 'flash') {
            const alpha = map(progress, 0, 1, 100, 0);
            ctx.fillStyle = `rgba(255, 255, 255, ${alpha / 255})`;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        } else if (anim.type === 'horizontal') {
            const animSize = map(progress, 0, 1, 50, 0);
            for (let x = 0; x < canvas.width; x += canvas.width / 30) {
                for (let k = 1; k < animSize; k += 5) {
                    const alpha = 20 / 255;
                    const animColor = `rgba(${anim.color.r}, ${anim.color.g}, ${anim.color.b}, ${alpha})`;
                    drawCircle(x, pegs[anim.line[0]].y, k, animColor);
                }
            }
        } else if (anim.type === 'vertical') {
            const animSize = map(progress, 0, 1, 50, 0);
            for (let y = 0; y < canvas.height; y += canvas.height / 30) {
                for (let k = 1; k < animSize; k += 5) {
                    const alpha = 20 / 255;
                    const animColor = `rgba(${anim.color.r}, ${anim.color.g}, ${anim.color.b}, ${alpha})`;
                    drawCircle(pegs[anim.line[0]].x, y, k, animColor);
                }
            }
        } else if (anim.type === 'diagonal1') {
            const animSize = map(progress, 0, 1, 50, 0);
            for (let xy = 0; xy < canvas.width; xy += canvas.width / 30) {
                for (let k = 1; k < animSize; k += 5) {
                    const alpha = 20 / 255;
                    const animColor = `rgba(${anim.color.r}, ${anim.color.g}, ${anim.color.b}, ${alpha})`;
                    drawCircle(xy, xy, k, animColor);
                }
            }
        } else if (anim.type === 'diagonal2') {
            const animSize = map(progress, 0, 1, 50, 0);
            for (let xy = 0; xy < canvas.width; xy += canvas.width / 30) {
                for (let k = 1; k < animSize; k += 5) {
                    const alpha = 20 / 255;
                    const animColor = `rgba(${anim.color.r}, ${anim.color.g}, ${anim.color.b}, ${alpha})`;
                    drawCircle(xy, canvas.height - xy, k, animColor);
                }
            }
        } else if (anim.type === 'peg') {
            const animSize = map(progress, 0, 1, 50, 0);
            for (let k = 1; k < animSize * 2; k++) {
                const alpha = 20 / 255;
                const animColor = `rgba(${anim.color.r}, ${anim.color.g}, ${anim.color.b}, ${alpha})`;
                drawCircle(pegs[anim.peg].x, pegs[anim.peg].y, k, animColor);
            }
        } else if (anim.type === 'combo' && progress < 1) {
            const size = Math.floor(map(1 - progress, 0, 0.2, 1, 4));
            const lines = anim.message.split('\n');
            ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
            ctx.shadowBlur = 10;
            lines.forEach((line, i) => {
                drawCenteredText(line, canvas.height / 2 + i * 40 - 20, size, '#fff');
            });
            ctx.shadowBlur = 0;
        }
    });
    
    animations = animations.filter(a => (now - a.startTime) < a.duration);
}

// Play sound
function playSound(sound) {
    if (!gameState.sfx || !sound) return;
    const clone = sound.cloneNode();
    clone.play().catch(() => {});
}

// Mouse handlers
canvas.addEventListener('mousemove', (e) => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left;
    mouse.y = e.clientY - rect.top;
    mouseX = mouse.x;
    mouseY = mouse.y;
});

canvas.addEventListener('mousedown', (e) => {
    mouse.down = true;
    mouse.clicked = false;
    
    // Check if clicking on spawn area ring
    for (let i = 9; i < 12; i++) {
        if (dist(pegs[i].x, pegs[i].y, mouse.x, mouse.y) <= 40) {
            if (!pegs[i].rings.every(r => r === -1)) {
                mouse.dragging = i;
                break;
            }
        }
    }
});

canvas.addEventListener('mouseup', (e) => {
    // Check settings modal first
    if (handleSettingsClick(mouse.x, mouse.y)) {
        mouse.down = false;
        mouse.dragging = -1;
        return;
    }
    
    if (mouse.dragging >= 0) {
        // Try to place on board
        let placed = false;
        
        for (let i = 0; i < 9; i++) {
            if (dist(pegs[i].x, pegs[i].y, mouse.x, mouse.y) <= 40) {
                // Check if can place - rings can stack (smaller fits inside larger)
                // Size 0 = largest, Size 1 = medium, Size 2 = smallest
                let canPlace = true;
                const dragSet = pegs[mouse.dragging].rings;
                const targetSet = pegs[i].rings;
                
                // Check each ring size in the drag set
                for (let j = 0; j < 3; j++) {
                    if (dragSet[j] >= 0) {
                        // Can't place if same size slot is already occupied
                        if (targetSet[j] >= 0) {
                            canPlace = false;
                            break;
                        }
                    }
                }
                
                if (canPlace) {
                    // Place rings
                    for (let j = 0; j < 3; j++) {
                        if (dragSet[j] >= 0) {
                            pegs[i].rings[j] = dragSet[j];
                        }
                    }
                    pegs[mouse.dragging].rings = [...emptySet];
                    
                    if (sounds.woodblock) playSound(sounds.woodblock);
                    
                    // Check for matches
                    checkMatches(i);
                    
                    placed = true;
                }
                break;
            }
        }
    } else {
        // Check button clicks
        buttons.forEach((btn, i) => {
            if (mouse.x >= btn.x && mouse.x <= btn.x + btn.w &&
                mouse.y >= btn.y && mouse.y <= btn.y + btn.h) {
                handleButtonClick(i);
            }
        });
    }
    
    mouse.down = false;
    mouse.dragging = -1;
});

// Handle button clicks
function handleButtonClick(index) {
    if (index === 0) {
        // Settings
        toggleSettings();
    } else if (index === 1) {
        // Pause
        gameState.pauseGame = !gameState.pauseGame;
    }
}

// Toggle settings modal
function toggleSettings() {
    showSettingsModal = !showSettingsModal;
    if (showSettingsModal) {
        createSettingsButtons();
    }
}

// Create settings buttons
function createSettingsButtons() {
    const modalWidth = 500;
    const modalHeight = 400;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    const buttonWidth = 200;
    const buttonHeight = 50;
    const startX = modalX + (modalWidth - buttonWidth) / 2;
    let y = modalY + 100;
    const spacing = 70;
    
    settingsButtons = [
        {
            x: startX,
            y: y,
            width: buttonWidth,
            height: buttonHeight,
            label: `♪ Música: ${gameState.music ? 'ON' : 'OFF'}`,
            action: 'music'
        },
        {
            x: startX,
            y: y + spacing,
            width: buttonWidth,
            height: buttonHeight,
            label: `🔊 Efeitos: ${gameState.sfx ? 'ON' : 'OFF'}`,
            action: 'sfx'
        },
        {
            x: startX,
            y: y + spacing * 2,
            width: buttonWidth,
            height: buttonHeight,
            label: `⚔ Modo: ${gameState.mode === MODE_NORMAL ? 'Normal' : 'Fácil'}`,
            action: 'mode'
        },
        {
            x: startX,
            y: y + spacing * 3,
            width: buttonWidth,
            height: buttonHeight,
            label: '✕ Fechar',
            action: 'close'
        }
    ];
}

// Draw settings modal
function drawSettingsModal() {
    if (!showSettingsModal && settingsModalAlpha <= 0) return;
    
    // Animate alpha
    if (showSettingsModal && settingsModalAlpha < 1) {
        settingsModalAlpha = Math.min(1, settingsModalAlpha + 0.1);
    } else if (!showSettingsModal && settingsModalAlpha > 0) {
        settingsModalAlpha = Math.max(0, settingsModalAlpha - 0.1);
    }
    
    // Semi-transparent overlay
    ctx.fillStyle = `rgba(0, 0, 0, ${0.7 * settingsModalAlpha})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Modal dimensions
    const modalWidth = 500;
    const modalHeight = 400;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    // Modal background with gradient
    const gradient = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient.addColorStop(0, `rgba(30, 30, 50, ${settingsModalAlpha})`);
    gradient.addColorStop(1, `rgba(20, 20, 35, ${settingsModalAlpha})`);
    
    ctx.shadowBlur = 40 * settingsModalAlpha;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient;
    ctx.fill();
    ctx.shadowBlur = 0;
    
    // Modal border with glow
    ctx.strokeStyle = `rgba(100, 150, 255, ${0.5 * settingsModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.shadowBlur = 10 * settingsModalAlpha;
    ctx.shadowColor = `rgba(100, 150, 255, ${settingsModalAlpha})`;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Title
    ctx.font = 'bold 36px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${settingsModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.shadowBlur = 5 * settingsModalAlpha;
    ctx.shadowColor = 'rgba(100, 150, 255, 0.8)';
    ctx.fillText('⚙ Configurações', canvas.width / 2, modalY + 30);
    ctx.shadowBlur = 0;
    
    // Draw buttons
    settingsButtons.forEach((btn, index) => {
        const isHovered = mouseX >= btn.x && mouseX <= btn.x + btn.width &&
                         mouseY >= btn.y && mouseY <= btn.y + btn.height;
        
        // Button shadow
        if (isHovered) {
            ctx.shadowBlur = 20 * settingsModalAlpha;
            ctx.shadowColor = 'rgba(100, 150, 255, 0.8)';
        } else {
            ctx.shadowBlur = 10 * settingsModalAlpha;
            ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
        }
        
        // Button background
        const btnGradient = ctx.createLinearGradient(btn.x, btn.y, btn.x, btn.y + btn.height);
        if (btn.action === 'close') {
            btnGradient.addColorStop(0, `rgba(180, 50, 50, ${settingsModalAlpha})`);
            btnGradient.addColorStop(1, `rgba(130, 30, 30, ${settingsModalAlpha})`);
        } else if (isHovered) {
            btnGradient.addColorStop(0, `rgba(80, 120, 200, ${settingsModalAlpha})`);
            btnGradient.addColorStop(1, `rgba(50, 80, 150, ${settingsModalAlpha})`);
        } else {
            btnGradient.addColorStop(0, `rgba(60, 90, 150, ${settingsModalAlpha})`);
            btnGradient.addColorStop(1, `rgba(40, 60, 100, ${settingsModalAlpha})`);
        }
        
        roundRect(ctx, btn.x, btn.y, btn.width, btn.height, 10);
        ctx.fillStyle = btnGradient;
        ctx.fill();
        
        // Button border
        ctx.strokeStyle = `rgba(100, 150, 255, ${0.6 * settingsModalAlpha})`;
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.shadowBlur = 0;
        
        // Button text
        ctx.font = 'bold 20px Arial';
        ctx.fillStyle = `rgba(255, 255, 255, ${settingsModalAlpha})`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(btn.label, btn.x + btn.width / 2, btn.y + btn.height / 2);
    });
}

// Handle settings button clicks
function handleSettingsClick(x, y) {
    if (!showSettingsModal || settingsModalAlpha < 0.9) return false;
    
    for (let btn of settingsButtons) {
        if (x >= btn.x && x <= btn.x + btn.width &&
            y >= btn.y && y <= btn.y + btn.height) {
            
            if (btn.action === 'music') {
                gameState.music = !gameState.music;
                if (gameState.music && sounds.track1) {
                    sounds.track1.loop = true;
                    sounds.track1.play().catch(e => console.log('Cannot play music'));
                } else if (sounds.track1) {
                    sounds.track1.pause();
                }
            } else if (btn.action === 'sfx') {
                gameState.sfx = !gameState.sfx;
            } else if (btn.action === 'mode') {
                gameState.mode = gameState.mode === MODE_NORMAL ? MODE_EASIER : MODE_NORMAL;
            } else if (btn.action === 'close') {
                toggleSettings();
                return true;
            }
            
            // Update button labels
            createSettingsButtons();
            return true;
        }
    }
    
    return false;
}

// Show pause menu
function showPauseMenu() {
    const message = 'Game Paused\n\nClick OK to continue';
    alert(message);
    gameState.pauseGame = false;
}

// Intro animation
let introTime = 0;
let showIntro = true;
let introRings = [];

function initIntro() {
    for (let i = 0; i < 30; i++) {
        introRings.push({
            angle: Math.random() * Math.PI * 2,
            speed: Math.random() * 5,
            radius: Math.random() * 30 + 50,
            color: Math.floor(Math.random() * ringColors.length)
        });
    }
}

function updateIntro(dt) {
    introTime += dt;
    
    drawBackground();
    
    // Animate rings
    introRings.forEach(ring => {
        ring.angle += 0.01;
        ring.radius += ring.speed * dt * 60;
        const x = canvas.width / 2 + Math.cos(ring.angle) * ring.radius;
        const y = canvas.height / 2 + Math.sin(ring.angle) * ring.radius;
        drawRing(x, y, 2, ring.color);
    });
    
    updateParticles(dt);
    drawParticles();
    
    // Fade in/out text
    let alpha = 1;
    if (introTime < 1.5) {
        alpha = introTime / 1.5;
    } else if (introTime > 4.5) {
        alpha = Math.max(0, 1 - (introTime - 4.5) / 1.5);
    }
    
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    drawCenteredText('Tic Tac Toe', canvas.height / 2 - 30, 2, ctx.fillStyle);
    drawCenteredText('Rings', canvas.height / 2 + 10, 7, ctx.fillStyle);
    drawCenteredText('Fellippe Heitor, 2020', canvas.height - 60, 1, ctx.fillStyle);
    
    if (introTime > 6 || mouse.clicked) {
        showIntro = false;
        initGame();
    }
}

// Init game
function initGame() {
    initPegs();
    createMainButtons();
    addParticles(canvas.width / 2, canvas.height / 2, 500, { r: 255, g: 255, b: 255 });
    generateNewSets();
    
    // Start music
    if (sounds.track1 && gameState.music) {
        sounds.track1.loop = true;
        sounds.track1.volume = 0.5;
        sounds.track1.play().catch(() => {});
    }
}

// Main game loop
let lastTime = Date.now();

function gameLoop() {
    const now = Date.now();
    const dt = (now - lastTime) / 1000;
    lastTime = now;
    
    if (showIntro) {
        updateIntro(dt);
    } else {
        // Update
        if (!gameState.pauseGame && !showSettingsModal) {
            updateParticles(dt);
            updateScore(dt);
            generateNewSets();
            
            if (!checkAvailableMoves()) {
                gameState.gameOver = true;
            }
        }
        
        // Draw
        drawBackground();
        drawBoardDivisions();
        drawPegs();
        drawHoverHighlight();
        drawRings();
        updateAnimations();
        drawParticles();
        drawHUD();
        
        // Check hover
        checkButtonHover();
        
        // Draw settings modal on top
        if (showSettingsModal || settingsModalAlpha > 0) {
            drawSettingsModal();
        }
        
        // Game over
        if (gameState.gameOver) {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            drawCenteredText('Game Over!', canvas.height / 2 - 40, 4, '#fff');
            drawCenteredText(`Score: ${Math.floor(gameState.score)}`, canvas.height / 2 + 20, 2, '#fff');
            drawCenteredText('Click to restart', canvas.height / 2 + 60, 1, '#aaa');
            
            if (mouse.clicked) {
                // Reset game
                gameState.score = 0;
                gameState.visibleScore = 0;
                gameState.level = 0;
                gameState.multiplier = 1;
                gameState.gameOver = false;
                initGame();
            }
        }
    }
    
    mouse.clicked = false;
    requestAnimationFrame(gameLoop);
}

// Click detection
canvas.addEventListener('click', () => {
    mouse.clicked = true;
});

// Load assets and start
async function loadAssets() {
    const loadingEl = document.getElementById('loading');
    
    try {
        // Load sounds (optional, will fail gracefully)
        const audioFiles = {
            select: 'assets/sounds/select.ogg',
            woosh: 'assets/sounds/woosh.ogg',
            woodblock: 'assets/sounds/woodblock.wav',
            track1: 'assets/music/track1.ogg',
            combo: [
                'assets/sounds/do.ogg',
                'assets/sounds/re.ogg',
                'assets/sounds/mi.ogg',
                'assets/sounds/fa.ogg',
                'assets/sounds/sol.ogg',
                'assets/sounds/la.ogg',
                'assets/sounds/si.ogg',
                'assets/sounds/do2.ogg'
            ]
        };
        
        // Try to load audio
        for (let key in audioFiles) {
            if (key === 'combo') {
                sounds.combo = [];
                for (let file of audioFiles.combo) {
                    const audio = new Audio(file);
                    audio.volume = 0.5;
                    sounds.combo.push(audio);
                }
            } else {
                const audio = new Audio(audioFiles[key]);
                audio.volume = 0.5;
                sounds[key] = audio;
            }
        }
    } catch (e) {
        console.log('Audio files not loaded, continuing without sound');
    }
    
    // Hide loading screen
    loadingEl.classList.add('hidden');
    
    // Initialize
    initIntro();
    addParticles(canvas.width / 2, canvas.height / 2, 500, { r: 255, g: 255, b: 255 });
    
    // Start game loop
    gameLoop();
}

// Start when page loads
window.addEventListener('load', loadAssets);
