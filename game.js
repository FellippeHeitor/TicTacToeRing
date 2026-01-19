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
    musicVolume: 0.7,
    sfxVolume: 0.7,
    prevMusicVolume: 0.7,
    prevSfxVolume: 0.7
};

// LocalStorage functions
function saveSettings() {
    try {
        const settings = {
            musicVolume: gameState.musicVolume,
            sfxVolume: gameState.sfxVolume,
            prevMusicVolume: gameState.prevMusicVolume,
            prevSfxVolume: gameState.prevSfxVolume,
            mode: gameState.mode
        };
        localStorage.setItem('tictactoering_settings', JSON.stringify(settings));
    } catch (e) {
        console.log('Could not save settings:', e);
    }
}

function loadSettings() {
    try {
        const saved = localStorage.getItem('tictactoering_settings');
        if (saved) {
            const settings = JSON.parse(saved);
            gameState.musicVolume = settings.musicVolume ?? 0.7;
            gameState.sfxVolume = settings.sfxVolume ?? 0.7;
            gameState.prevMusicVolume = settings.prevMusicVolume ?? 0.7;
            gameState.prevSfxVolume = settings.prevSfxVolume ?? 0.7;
            gameState.mode = settings.mode ?? MODE_NORMAL;
        }
    } catch (e) {
        console.log('Could not load settings:', e);
    }
}

function saveHighScore() {
    try {
        const key = gameState.mode === MODE_NORMAL ? 'tictactoering_highscore_normal' : 'tictactoering_highscore_easier';
        localStorage.setItem(key, gameState.highscore.toString());
    } catch (e) {
        console.log('Could not save high score:', e);
    }
}

function loadHighScore() {
    try {
        const key = gameState.mode === MODE_NORMAL ? 'tictactoering_highscore_normal' : 'tictactoering_highscore_easier';
        const saved = localStorage.getItem(key);
        if (saved) {
            gameState.highscore = parseInt(saved, 10) || 0;
            gameState.visibleHighScore = gameState.highscore;
        }
    } catch (e) {
        console.log('Could not load high score:', e);
    }
}

// Settings modal state
let showSettingsModal = false;
let settingsButtons = [];
let settingsModalAlpha = 0;
let draggingSlider = null;

// Confirmation modal state
let showConfirmModal = false;
let confirmModalAlpha = 0;
let confirmMessage = '';
let confirmCallback = null;

// HUD animation state
let scoreShake = 0;
let comboScale = 1;
let comboAlpha = 0;
let comboY = 0;
let highscoreGlow = 0;
let multiplierPulse = 0;

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

// Particle class for combo explosions
class Particle {
    constructor(x, y, color) {
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 8;
        this.vy = (Math.random() - 0.5) * 8 - 2;
        this.life = 1;
        this.decay = 0.015 + Math.random() * 0.015;
        this.size = 3 + Math.random() * 4;
        this.color = color;
        this.gravity = 0.15;
    }
    
    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.vy += this.gravity;
        this.life -= this.decay;
        return this.life > 0;
    }
    
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = this.life;
        ctx.fillStyle = this.color;
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

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
    const spacing = 8; // Aumentado para mais espaço
    const offsetX = 20; // Deslocamento para centralizar melhor
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
            x: canvas.width / 2 + k + offsetX,
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
            active: true,
            // Add methods for compatibility with Particle class
            update: function() {
                if (!this.active) return false;
                this.vy += 0.1; // gravity
                this.x += this.vx;
                this.y += this.vy;
                this.life -= 0.016 * 2; // dt
                
                if (this.x < 0 || this.x > canvas.width || this.y < 0 || this.y > canvas.height || this.life <= 0) {
                    return false;
                }
                return true;
            },
            draw: function(ctx) {
                if (this.active && this.life > 0) {
                    ctx.save();
                    ctx.globalAlpha = Math.min(this.life, 1);
                    ctx.fillStyle = this.color;
                    ctx.fillRect(this.x, this.y, this.size, this.size);
                    ctx.restore();
                }
            }
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
    const spacing = 8;
    const offsetX = 20;
    
    // Game board area
    ctx.strokeStyle = 'rgba(0, 50, 100, 0.3)';
    ctx.lineWidth = 2;
    ctx.strokeRect(
        canvas.width / 2 - (canvas.width / spacing) * 1.5 + offsetX,
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
    ctx.save();
    ctx.font = `${size * 16}px monospace`;
    ctx.fillStyle = color;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillText(text, canvas.width / 2, y);
    ctx.restore();
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

// Ease out cubic function
function easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
}

// Draw HUD
function drawHUD() {
    // Animated background panel for scores
    ctx.save();
    
    // High score panel with glow effect
    const hsPanel = {
        x: 15,
        y: 15,
        width: 200,
        height: 50
    };
    
    // Glow effect for high score
    highscoreGlow = Math.sin(Date.now() / 500) * 0.3 + 0.7;
    ctx.shadowBlur = 15 * highscoreGlow;
    ctx.shadowColor = '#ffd700';
    
    const hsGradient = ctx.createLinearGradient(hsPanel.x, hsPanel.y, hsPanel.x, hsPanel.y + hsPanel.height);
    hsGradient.addColorStop(0, 'rgba(255, 215, 0, 0.15)');
    hsGradient.addColorStop(1, 'rgba(184, 134, 11, 0.1)');
    roundRect(ctx, hsPanel.x, hsPanel.y, hsPanel.width, hsPanel.height, 8);
    ctx.fillStyle = hsGradient;
    ctx.fill();
    
    ctx.strokeStyle = 'rgba(255, 215, 0, 0.4)';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Crown emoji
    ctx.font = '24px Arial';
    ctx.fillStyle = '#ffd700';
    ctx.shadowColor = '#ffa500';
    ctx.shadowBlur = 10 * highscoreGlow;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText('👑', 20, hsPanel.y + hsPanel.height / 2);
    
    // High score label
    ctx.shadowBlur = 0;
    ctx.font = 'bold 10px Arial';
    ctx.fillStyle = 'rgba(255, 215, 0, 0.7)';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText('RECORDE', 52, hsPanel.y + 10);
    
    // High score value
    ctx.font = 'bold 22px Arial';
    ctx.fillStyle = '#ffd700';
    ctx.shadowColor = '#ffa500';
    ctx.shadowBlur = 5;
    ctx.textBaseline = 'bottom';
    ctx.fillText(Math.floor(gameState.visibleHighScore).toString(), 52, hsPanel.y + hsPanel.height - 8);
    ctx.shadowBlur = 0;
    
    // Main score panel with dynamic effects
    const scorePanel = {
        x: 10,
        y: 80,
        width: 280,
        height: 120
    };
    
    // Score panel background
    ctx.shadowBlur = 20;
    ctx.shadowColor = 'rgba(100, 150, 255, 0.3)';
    const scoreGradient = ctx.createLinearGradient(scorePanel.x, scorePanel.y, scorePanel.x, scorePanel.y + scorePanel.height);
    scoreGradient.addColorStop(0, 'rgba(30, 50, 100, 0.3)');
    scoreGradient.addColorStop(1, 'rgba(20, 30, 60, 0.2)');
    roundRect(ctx, scorePanel.x, scorePanel.y, scorePanel.width, scorePanel.height, 12);
    ctx.fillStyle = scoreGradient;
    ctx.fill();
    
    ctx.strokeStyle = 'rgba(100, 150, 255, 0.5)';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Score label
    ctx.font = 'bold 12px Arial';
    ctx.fillStyle = 'rgba(150, 200, 255, 0.9)';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText('PONTUAÇÃO', scorePanel.x + 10, scorePanel.y + 10);
    
    // Animated score with shake effect when increasing
    ctx.save();
    const scoreX = scorePanel.x + 10 + (Math.random() * scoreShake * 4 - scoreShake * 2);
    const scoreY = scorePanel.y + 55 + (Math.random() * scoreShake * 4 - scoreShake * 2);
    
    // Score glow
    ctx.shadowColor = '#00ffff';
    ctx.shadowBlur = 15 + scoreShake * 10;
    
    // Main score
    ctx.font = 'bold 52px Arial';
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(Math.floor(gameState.visibleScore).toString(), scoreX, scoreY);
    
    ctx.shadowBlur = 0;
    ctx.restore();
    
    // Multiplier with pulse animation
    if (gameState.multiplier > 1) {
        const multX = scorePanel.x + 10;
        const multY = scorePanel.y + 95;
        
        multiplierPulse = Math.sin(Date.now() / 200) * 0.15 + 1;
        
        ctx.save();
        ctx.translate(multX, multY);
        ctx.scale(multiplierPulse, multiplierPulse);
        
        // Multiplier text with better alignment
        ctx.font = 'bold 20px Arial';
        ctx.fillStyle = '#ff5555';
        ctx.shadowColor = '#ff0000';
        ctx.shadowBlur = 10;
        ctx.textAlign = 'left';
        ctx.textBaseline = 'middle';
        ctx.fillText(`×${gameState.multiplier} COMBO!`, 0, 0);
        
        ctx.shadowBlur = 0;
        ctx.restore();
    }
    
    ctx.restore();
    
    // Buttons
    drawButtons();
}

// Create main screen buttons
function createMainButtons() {
    buttons = [
        { x: canvas.width - 100, y: 20, w: 80, h: 35, text: 'Settings' },
        { x: canvas.width - 100, y: 65, w: 80, h: 35, text: 'Pause' }
    ];
}

// Draw buttons
function drawButtons() {
    ctx.save();
    buttons.forEach((btn, i) => {
        const isHovered = currentButton === i;
        ctx.fillStyle = isHovered ? 'rgba(67, 172, 183, 0.5)' : 'rgba(50, 50, 50, 0.5)';
        ctx.fillRect(btn.x, btn.y, btn.w, btn.h);
        ctx.strokeStyle = isHovered ? '#43acb7' : '#888';
        ctx.lineWidth = 2;
        ctx.strokeRect(btn.x, btn.y, btn.w, btn.h);
        
        ctx.fillStyle = '#fff';
        ctx.font = '12px monospace';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'alphabetic';
        const textWidth = ctx.measureText(btn.text).width;
        ctx.fillText(btn.text, btn.x + (btn.w - textWidth) / 2, btn.y + 20);
    });
    ctx.restore();
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
            
            // Find a board peg with at least one empty slot that hasn't been used yet
            do {
                const hasEmptySlot = pegs[thisPeg].rings.some(r => r === -1);
                const notUsed = !pegsUsed.includes(thisPeg);
                
                if (hasEmptySlot && notUsed) {
                    found = true;
                    break;
                }
                
                thisPeg = (thisPeg + 1) % 9;
                if (thisPeg === 0) thisPeg = 1; // Skip 0, start from 1
                if (thisPeg === newPeg) {
                    // Full circle - no available pegs
                    thisPeg = 0;
                    break;
                }
            } while (true);
            
            if (found && thisPeg > 0) {
                pegsUsed.push(thisPeg);
            } else {
                thisPeg = 0;
            }
            
            // Generate rings based on chosen peg's empty slots
            do {
                pegs[i].rings = [...emptySet];
                
                if (thisPeg > 0) {
                    // Generate ONLY in slots that are empty in the chosen board peg
                    for (let j = 0; j < 3; j++) {
                        if (pegs[thisPeg].rings[j] === -1) {
                            // 30% chance to add a ring in this empty position
                            if (Math.random() * 100 < 30) {
                                pegs[i].rings[j] = Math.floor(Math.random() * gameState.maxColors);
                            }
                        }
                    }
                } else {
                    // Fallback: random generation (shouldn't happen often)
                    const numRings = Math.random() < 0.6 ? 2 : 1;
                    const positions = [0, 1, 2].sort(() => Math.random() - 0.5).slice(0, numRings);
                    positions.forEach(pos => {
                        pegs[i].rings[pos] = Math.floor(Math.random() * gameState.maxColors);
                    });
                }
            } while (pegs[i].rings.every(r => r === -1)); // Can't be completely empty
            
            // Make sure we don't have all 3 slots filled (at least 1 must be empty)
            if (pegs[i].rings.every(r => r >= 0)) {
                // Remove a random ring to ensure at least 1 empty slot
                const removeIdx = Math.floor(Math.random() * 3);
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
        
        // Update score with animation trigger
        const scoreIncrease = totalScore * gameState.multiplier;
        gameState.score += scoreIncrease;
        gameState.multiplier++;
        
        // Trigger screen shake for big scores
        if (scoreIncrease > 5) {
            scoreShake = Math.min(2, scoreIncrease / 10);
        }
        
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
                duration: 1500
            });
            
            // Create explosion particles
            const centerX = canvas.width / 2;
            const centerY = canvas.height / 2;
            const particleCount = 30 + gameState.multiplier * 10;
            const colors = ['#ff5500', '#ff8800', '#ffaa00', '#ffff00', '#ff0000', '#ff3333'];
            
            for (let i = 0; i < particleCount; i++) {
                const color = colors[Math.floor(Math.random() * colors.length)];
                particles.push(new Particle(centerX, centerY, color));
            }
        }
        
        if (gameState.score > gameState.highscore) {
            gameState.highscore = gameState.score;
            saveHighScore();
        }
    } else {
        gameState.multiplier = 1;
    }
    
    return scored;
}

// Check available moves
function checkAvailableMoves() {
    if (mouse.dragging >= 0) return true;
    
    // Count non-empty spawn sets
    let spawnSets = [];
    for (let i = 9; i < 12; i++) {
        if (!pegs[i].rings.every(r => r === -1)) {
            spawnSets.push(i);
        }
    }
    
    // If no spawn sets exist, new ones will be generated
    if (spawnSets.length === 0) return true;
    
    // Check if at least one spawn set can be placed on the board
    let canPlaceAny = false;
    
    for (let spawnIdx of spawnSets) {
        const spawnSet = pegs[spawnIdx].rings;
        
        // Check each board position
        for (let boardIdx = 0; boardIdx < 9; boardIdx++) {
            const boardSet = pegs[boardIdx].rings;
            let canPlace = true;
            
            // Check if this spawn set can fit on this board peg
            for (let slot = 0; slot < 3; slot++) {
                if (spawnSet[slot] >= 0 && boardSet[slot] >= 0) {
                    // Both slots occupied - can't place
                    canPlace = false;
                    break;
                }
            }
            
            if (canPlace) {
                canPlaceAny = true;
                break;
            }
        }
        
        if (canPlaceAny) break;
    }
    
    // Game is over if:
    // 1. There are spawn sets available
    // 2. None of them can be placed anywhere on the board
    // 3. Board has at least some rings (not empty)
    if (!canPlaceAny) {
        // Additional check: make sure board actually has rings
        let boardHasRings = false;
        for (let i = 0; i < 9; i++) {
            if (pegs[i].rings.some(r => r >= 0)) {
                boardHasRings = true;
                break;
            }
        }
        
        // Only game over if board has rings and no moves available
        return !boardHasRings;
    }
    
    return true;
}

// Update score animation
function updateScore(dt) {
    const oldScore = gameState.visibleScore;
    
    // Smooth easing for score increase
    if (gameState.visibleScore < gameState.score) {
        const diff = gameState.score - gameState.visibleScore;
        gameState.visibleScore += diff * dt * 5;
        
        if (gameState.visibleScore > gameState.score) {
            gameState.visibleScore = gameState.score;
        }
        
        // Trigger shake when score increases significantly
        if (gameState.visibleScore - oldScore > 5) {
            scoreShake = 1;
        }
    }
    
    // Decay shake effect
    if (scoreShake > 0) {
        scoreShake = Math.max(0, scoreShake - dt * 3);
    }
    
    // Smooth high score animation
    if (gameState.visibleHighScore < gameState.highscore) {
        const diff = gameState.highscore - gameState.visibleHighScore;
        gameState.visibleHighScore += diff * dt * 3;
        
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
            // Smooth elastic bounce animation for combo text
            let scale, alpha, yOffset;
            
            if (progress < 0.3) {
                // Bounce in
                const t = progress / 0.3;
                const bounce = Math.sin(t * Math.PI * 2) * (1 - t) * 0.3;
                scale = easeOutCubic(t) * (1 + bounce);
                alpha = easeOutCubic(t);
                yOffset = (1 - easeOutCubic(t)) * -50;
            } else if (progress > 0.7) {
                // Fade out
                const t = (progress - 0.7) / 0.3;
                scale = 1 - t * 0.5;
                alpha = 1 - easeOutCubic(t);
                yOffset = -t * 30;
            } else {
                // Hold
                const t = (progress - 0.3) / 0.4;
                scale = 1 + Math.sin(t * Math.PI * 4) * 0.05;
                alpha = 1;
                yOffset = 0;
            }
            
            ctx.save();
            const centerY = canvas.height / 2 + yOffset;
            const lines = anim.message.split('\n');
            
            // Draw text with scale (no background)
            ctx.globalAlpha = alpha;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            
            // Calculate centered Y position for both lines
            const line1Y = centerY - 20;
            const line2Y = centerY + 20;
            
            // First line (message)
            ctx.font = `bold ${Math.floor(36 * scale)}px Arial`;
            ctx.fillStyle = '#ffffff';
            ctx.shadowColor = '#ff5500';
            ctx.shadowBlur = 15;
            ctx.fillText(lines[0], canvas.width / 2, line1Y);
            
            // Second line (multiplier)
            if (lines[1]) {
                ctx.font = `bold ${Math.floor(48 * scale)}px Arial`;
                ctx.fillStyle = '#ffff00';
                ctx.shadowColor = '#ff0000';
                ctx.shadowBlur = 20;
                ctx.fillText(lines[1], canvas.width / 2, line2Y);
            }
            
            ctx.shadowBlur = 0;
            ctx.restore();
        }
    });
    
    animations = animations.filter(a => (now - a.startTime) < a.duration);
    
    // Update and draw particles
    particles = particles.filter(p => {
        const alive = p.update();
        if (alive) p.draw(ctx);
        return alive;
    });
}

// Play sound
function playSound(sound) {
    if (gameState.sfxVolume === 0 || !sound) return;
    const clone = sound.cloneNode();
    clone.volume = gameState.sfxVolume;
    clone.play().catch(() => {});
}

// Mouse handlers
canvas.addEventListener('mousemove', (e) => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left;
    mouse.y = e.clientY - rect.top;
    mouseX = mouse.x;
    mouseY = mouse.y;
    
    // Handle slider dragging
    handleSliderDrag(mouseX, mouseY);
});

canvas.addEventListener('mousedown', (e) => {
    mouse.down = true;
    mouse.clicked = false;
    
    // Check if clicking on spawn area ring
    if (pegs.length >= 12) {
        for (let i = 9; i < 12; i++) {
            if (dist(pegs[i].x, pegs[i].y, mouse.x, mouse.y) <= 40) {
                if (!pegs[i].rings.every(r => r === -1)) {
                    mouse.dragging = i;
                    break;
                }
            }
        }
    }
});

canvas.addEventListener('mouseup', (e) => {
    // Stop slider dragging
    stopSliderDrag();
    
    // Check confirmation modal first
    if (handleConfirmClick(mouse.x, mouse.y)) {
        mouse.down = false;
        mouse.dragging = -1;
        return;
    }
    
    // Check settings modal
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
    
    const sliderWidth = 250;
    const toggleWidth = 50;
    const buttonHeight = 50;
    const buttonWidth = sliderWidth + toggleWidth + 10;
    const startX = modalX + (modalWidth - buttonWidth) / 2;
    let y = modalY + 100;
    const spacing = 80;
    
    settingsButtons = [
        {
            x: startX,
            y: y,
            width: sliderWidth,
            height: 40,
            label: `♪ Música`,
            action: 'music-slider',
            type: 'slider',
            value: gameState.musicVolume
        },
        {
            x: startX + sliderWidth + 10,
            y: y,
            width: toggleWidth,
            height: 40,
            label: gameState.musicVolume > 0 ? 'ON' : 'OFF',
            action: 'music-toggle',
            type: 'toggle'
        },
        {
            x: startX,
            y: y + spacing,
            width: sliderWidth,
            height: 40,
            label: `🔊 Efeitos`,
            action: 'sfx-slider',
            type: 'slider',
            value: gameState.sfxVolume
        },
        {
            x: startX + sliderWidth + 10,
            y: y + spacing,
            width: toggleWidth,
            height: 40,
            label: gameState.sfxVolume > 0 ? 'ON' : 'OFF',
            action: 'sfx-toggle',
            type: 'toggle'
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
        if (btn.type === 'slider') {
            // Draw slider label
            ctx.font = 'bold 18px Arial';
            ctx.fillStyle = `rgba(255, 255, 255, ${settingsModalAlpha})`;
            ctx.textAlign = 'left';
            ctx.textBaseline = 'top';
            ctx.fillText(btn.label, btn.x, btn.y - 25);
            
            // Slider track
            const trackHeight = 8;
            const trackY = btn.y + btn.height / 2 - trackHeight / 2;
            
            ctx.shadowBlur = 5 * settingsModalAlpha;
            ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
            roundRect(ctx, btn.x, trackY, btn.width, trackHeight, 4);
            ctx.fillStyle = `rgba(40, 40, 60, ${settingsModalAlpha})`;
            ctx.fill();
            ctx.shadowBlur = 0;
            
            // Slider fill (active part)
            const fillWidth = btn.width * btn.value;
            if (fillWidth > 0) {
                roundRect(ctx, btn.x, trackY, fillWidth, trackHeight, 4);
                const fillGradient = ctx.createLinearGradient(btn.x, trackY, btn.x + fillWidth, trackY);
                fillGradient.addColorStop(0, `rgba(100, 150, 255, ${settingsModalAlpha})`);
                fillGradient.addColorStop(1, `rgba(50, 100, 200, ${settingsModalAlpha})`);
                ctx.fillStyle = fillGradient;
                ctx.fill();
            }
            
            // Slider handle
            const handleX = btn.x + btn.width * btn.value;
            const handleRadius = 12;
            const isHovered = mouseX >= handleX - handleRadius && mouseX <= handleX + handleRadius &&
                            mouseY >= btn.y && mouseY <= btn.y + btn.height;
            
            ctx.shadowBlur = isHovered ? 15 * settingsModalAlpha : 10 * settingsModalAlpha;
            ctx.shadowColor = 'rgba(100, 150, 255, 0.8)';
            ctx.beginPath();
            ctx.arc(handleX, btn.y + btn.height / 2, handleRadius, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(200, 220, 255, ${settingsModalAlpha})`;
            ctx.fill();
            ctx.strokeStyle = `rgba(100, 150, 255, ${settingsModalAlpha})`;
            ctx.lineWidth = 2;
            ctx.stroke();
            ctx.shadowBlur = 0;
            
            // Volume percentage
            ctx.font = '14px Arial';
            ctx.fillStyle = `rgba(200, 200, 220, ${settingsModalAlpha})`;
            ctx.textAlign = 'right';
            ctx.textBaseline = 'top';
            ctx.fillText(`${Math.round(btn.value * 100)}%`, btn.x + btn.width, btn.y - 25);
        } else if (btn.type === 'toggle') {
            // Toggle button (ON/OFF)
            const isHovered = mouseX >= btn.x && mouseX <= btn.x + btn.width &&
                             mouseY >= btn.y && mouseY <= btn.y + btn.height;
            const isOn = btn.label === 'ON';
            
            // Button shadow
            if (isHovered) {
                ctx.shadowBlur = 15 * settingsModalAlpha;
                ctx.shadowColor = 'rgba(100, 150, 255, 0.8)';
            } else {
                ctx.shadowBlur = 8 * settingsModalAlpha;
                ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
            }
            
            // Button background
            const btnGradient = ctx.createLinearGradient(btn.x, btn.y, btn.x, btn.y + btn.height);
            if (isOn) {
                btnGradient.addColorStop(0, `rgba(50, 180, 80, ${settingsModalAlpha})`);
                btnGradient.addColorStop(1, `rgba(30, 130, 50, ${settingsModalAlpha})`);
            } else {
                btnGradient.addColorStop(0, `rgba(120, 120, 130, ${settingsModalAlpha})`);
                btnGradient.addColorStop(1, `rgba(80, 80, 90, ${settingsModalAlpha})`);
            }
            
            roundRect(ctx, btn.x, btn.y, btn.width, btn.height, 8);
            ctx.fillStyle = btnGradient;
            ctx.fill();
            
            // Button border
            ctx.strokeStyle = isOn ? `rgba(100, 255, 150, ${0.6 * settingsModalAlpha})` : `rgba(150, 150, 160, ${0.5 * settingsModalAlpha})`;
            ctx.lineWidth = 2;
            ctx.stroke();
            ctx.shadowBlur = 0;
            
            // Button text
            ctx.font = 'bold 14px Arial';
            ctx.fillStyle = `rgba(255, 255, 255, ${settingsModalAlpha})`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(btn.label, btn.x + btn.width / 2, btn.y + btn.height / 2);
        } else {
            // Regular button (mode, close)
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
        }
    });
}

// Draw confirmation modal
function drawConfirmModal() {
    if (!showConfirmModal && confirmModalAlpha <= 0) return;
    
    // Animate alpha
    if (showConfirmModal && confirmModalAlpha < 1) {
        confirmModalAlpha = Math.min(1, confirmModalAlpha + 0.1);
    } else if (!showConfirmModal && confirmModalAlpha > 0) {
        confirmModalAlpha = Math.max(0, confirmModalAlpha - 0.1);
    }
    
    // Semi-transparent overlay
    ctx.fillStyle = `rgba(0, 0, 0, ${0.8 * confirmModalAlpha})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Modal dimensions
    const modalWidth = 450;
    const modalHeight = 200;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    // Modal background with gradient
    const gradient = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient.addColorStop(0, `rgba(40, 40, 60, ${confirmModalAlpha})`);
    gradient.addColorStop(1, `rgba(30, 30, 45, ${confirmModalAlpha})`);
    
    ctx.shadowBlur = 40 * confirmModalAlpha;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient;
    ctx.fill();
    ctx.shadowBlur = 0;
    
    // Modal border
    ctx.strokeStyle = `rgba(255, 200, 100, ${0.6 * confirmModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.shadowBlur = 10 * confirmModalAlpha;
    ctx.shadowColor = `rgba(255, 200, 100, ${confirmModalAlpha})`;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Message text
    ctx.font = 'bold 18px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${confirmModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    
    const lines = confirmMessage.split('\n');
    lines.forEach((line, i) => {
        ctx.fillText(line, canvas.width / 2, modalY + 40 + i * 25);
    });
    
    // Buttons
    const btnWidth = 120;
    const btnHeight = 45;
    const btnSpacing = 20;
    const btn1X = modalX + (modalWidth / 2) - btnWidth - btnSpacing / 2;
    const btn2X = modalX + (modalWidth / 2) + btnSpacing / 2;
    const btnY = modalY + modalHeight - 70;
    
    const isHover1 = mouseX >= btn1X && mouseX <= btn1X + btnWidth &&
                     mouseY >= btnY && mouseY <= btnY + btnHeight;
    const isHover2 = mouseX >= btn2X && mouseX <= btn2X + btnWidth &&
                     mouseY >= btnY && mouseY <= btnY + btnHeight;
    
    // Confirm button (green)
    ctx.shadowBlur = isHover1 ? 20 * confirmModalAlpha : 10 * confirmModalAlpha;
    ctx.shadowColor = isHover1 ? 'rgba(100, 255, 100, 0.8)' : 'rgba(0, 0, 0, 0.5)';
    
    const btn1Gradient = ctx.createLinearGradient(btn1X, btnY, btn1X, btnY + btnHeight);
    if (isHover1) {
        btn1Gradient.addColorStop(0, `rgba(80, 200, 80, ${confirmModalAlpha})`);
        btn1Gradient.addColorStop(1, `rgba(50, 150, 50, ${confirmModalAlpha})`);
    } else {
        btn1Gradient.addColorStop(0, `rgba(60, 150, 60, ${confirmModalAlpha})`);
        btn1Gradient.addColorStop(1, `rgba(40, 100, 40, ${confirmModalAlpha})`);
    }
    
    roundRect(ctx, btn1X, btnY, btnWidth, btnHeight, 10);
    ctx.fillStyle = btn1Gradient;
    ctx.fill();
    ctx.strokeStyle = `rgba(100, 255, 100, ${0.6 * confirmModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    ctx.font = 'bold 18px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${confirmModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('✓ Sim', btn1X + btnWidth / 2, btnY + btnHeight / 2);
    
    // Cancel button (red)
    ctx.shadowBlur = isHover2 ? 20 * confirmModalAlpha : 10 * confirmModalAlpha;
    ctx.shadowColor = isHover2 ? 'rgba(255, 100, 100, 0.8)' : 'rgba(0, 0, 0, 0.5)';
    
    const btn2Gradient = ctx.createLinearGradient(btn2X, btnY, btn2X, btnY + btnHeight);
    if (isHover2) {
        btn2Gradient.addColorStop(0, `rgba(200, 80, 80, ${confirmModalAlpha})`);
        btn2Gradient.addColorStop(1, `rgba(150, 50, 50, ${confirmModalAlpha})`);
    } else {
        btn2Gradient.addColorStop(0, `rgba(150, 60, 60, ${confirmModalAlpha})`);
        btn2Gradient.addColorStop(1, `rgba(100, 40, 40, ${confirmModalAlpha})`);
    }
    
    roundRect(ctx, btn2X, btnY, btnWidth, btnHeight, 10);
    ctx.fillStyle = btn2Gradient;
    ctx.fill();
    ctx.strokeStyle = `rgba(255, 100, 100, ${0.6 * confirmModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    ctx.font = 'bold 18px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${confirmModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('✕ Não', btn2X + btnWidth / 2, btnY + btnHeight / 2);
}

// Handle confirmation modal clicks
function handleConfirmClick(x, y) {
    if (!showConfirmModal || confirmModalAlpha < 0.9) return false;
    
    const modalWidth = 450;
    const modalHeight = 200;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    const btnWidth = 120;
    const btnHeight = 45;
    const btnSpacing = 20;
    const btn1X = modalX + (modalWidth / 2) - btnWidth - btnSpacing / 2;
    const btn2X = modalX + (modalWidth / 2) + btnSpacing / 2;
    const btnY = modalY + modalHeight - 70;
    
    // Check confirm button
    if (x >= btn1X && x <= btn1X + btnWidth &&
        y >= btnY && y <= btnY + btnHeight) {
        showConfirmModal = false;
        if (confirmCallback) {
            confirmCallback(true);
            confirmCallback = null;
        }
        return true;
    }
    
    // Check cancel button
    if (x >= btn2X && x <= btn2X + btnWidth &&
        y >= btnY && y <= btnY + btnHeight) {
        showConfirmModal = false;
        if (confirmCallback) {
            confirmCallback(false);
            confirmCallback = null;
        }
        return true;
    }
    
    return false;
}

// Show confirmation dialog
function showConfirm(message, callback) {
    confirmMessage = message;
    confirmCallback = callback;
    showConfirmModal = true;
}

// Handle settings button clicks
function handleSettingsClick(x, y) {
    if (!showSettingsModal || settingsModalAlpha < 0.9) return false;
    
    for (let btn of settingsButtons) {
        if (btn.type === 'slider') {
            // Check if clicking in slider area
            if (x >= btn.x && x <= btn.x + btn.width &&
                y >= btn.y && y <= btn.y + btn.height) {
                // Start dragging
                draggingSlider = btn;
                // Immediately update value
                const newValue = Math.max(0, Math.min(1, (x - btn.x) / btn.width));
                btn.value = newValue;
                
                if (btn.action === 'music-slider') {
                    gameState.musicVolume = newValue;
                    if (newValue > 0) {
                        gameState.prevMusicVolume = newValue;
                    }
                    if (sounds.track1) {
                        sounds.track1.volume = newValue;
                        if (newValue > 0 && sounds.track1.paused) {
                            sounds.track1.loop = true;
                            sounds.track1.play().catch(e => console.log('Cannot play music'));
                        } else if (newValue === 0) {
                            sounds.track1.pause();
                        }
                    }
                    saveSettings();
                } else if (btn.action === 'sfx-slider') {
                    gameState.sfxVolume = newValue;
                    if (newValue > 0) {
                        gameState.prevSfxVolume = newValue;
                    }
                    // Play test sound
                    if (newValue > 0 && sounds.select) {
                        playSound(sounds.select);
                    }
                    saveSettings();
                }
                
                createSettingsButtons();
                return true;
            }
        } else if (btn.type === 'toggle') {
            // Toggle button
            if (x >= btn.x && x <= btn.x + btn.width &&
                y >= btn.y && y <= btn.y + btn.height) {
                
                if (btn.action === 'music-toggle') {
                    if (gameState.musicVolume > 0) {
                        // Turn off - save current volume
                        gameState.prevMusicVolume = gameState.musicVolume;
                        gameState.musicVolume = 0;
                        if (sounds.track1) {
                            sounds.track1.pause();
                        }
                    } else {
                        // Turn on - restore previous volume
                        gameState.musicVolume = gameState.prevMusicVolume;
                        if (sounds.track1) {
                            sounds.track1.volume = gameState.musicVolume;
                            sounds.track1.loop = true;
                            sounds.track1.play().catch(e => console.log('Cannot play music'));
                        }
                    }
                    saveSettings();
                } else if (btn.action === 'sfx-toggle') {
                    if (gameState.sfxVolume > 0) {
                        // Turn off - save current volume
                        gameState.prevSfxVolume = gameState.sfxVolume;
                        gameState.sfxVolume = 0;
                    } else {
                        // Turn on - restore previous volume
                        gameState.sfxVolume = gameState.prevSfxVolume;
                        // Play test sound
                        if (sounds.select) {
                            playSound(sounds.select);
                        }
                    }
                    saveSettings();
                }
                
                createSettingsButtons();
                return true;
            }
        } else {
            // Regular button
            if (x >= btn.x && x <= btn.x + btn.width &&
                y >= btn.y && y <= btn.y + btn.height) {
                
                if (btn.action === 'mode') {
                    // Confirm mode change with user
                    const newMode = gameState.mode === MODE_NORMAL ? 'Fácil' : 'Normal';
                    const confirmMsg = `Trocar para modo ${newMode}?\n\nO jogo será reiniciado.`;
                    
                    showConfirm(confirmMsg, (confirmed) => {
                        if (confirmed) {
                            // Change mode
                            gameState.mode = gameState.mode === MODE_NORMAL ? MODE_EASIER : MODE_NORMAL;
                            saveSettings();
                            
                            // Reset game state
                            gameState.score = 0;
                            gameState.visibleScore = 0;
                            gameState.level = 0;
                            gameState.multiplier = 1;
                            gameState.maxColors = 3;
                            gameState.gameOver = false;
                            
                            // Load high score for new mode
                            loadHighScore();
                            
                            // Close settings and restart
                            toggleSettings();
                            initGame();
                        }
                    });
                    return true;
                } else if (btn.action === 'close') {
                    toggleSettings();
                    return true;
                }
                
                // Update button labels
                createSettingsButtons();
                return true;
            }
        }
    }
    
    return false;
}

// Handle slider dragging
function handleSliderDrag(x, y) {
    if (!draggingSlider || !mouse.down) return;
    
    const newValue = Math.max(0, Math.min(1, (x - draggingSlider.x) / draggingSlider.width));
    draggingSlider.value = newValue;
    
    if (draggingSlider.action === 'music-slider') {
        gameState.musicVolume = newValue;
        if (newValue > 0) {
            gameState.prevMusicVolume = newValue;
        }
        if (sounds.track1) {
            sounds.track1.volume = newValue;
            if (newValue > 0 && sounds.track1.paused) {
                sounds.track1.loop = true;
                sounds.track1.play().catch(e => console.log('Cannot play music'));
            } else if (newValue === 0) {
                sounds.track1.pause();
            }
        }
        saveSettings();
    } else if (draggingSlider.action === 'sfx-slider') {
        gameState.sfxVolume = newValue;
        if (newValue > 0) {
            gameState.prevSfxVolume = newValue;
        }
        saveSettings();
    }
    
    createSettingsButtons();
}

// Stop slider dragging
function stopSliderDrag() {
    draggingSlider = null;
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
    
    // Fade in/out text
    let alpha = 1;
    if (introTime < 1.5) {
        alpha = introTime / 1.5;
    } else if (introTime > 4.5) {
        alpha = Math.max(0, 1 - (introTime - 4.5) / 1.5);
    }
    
    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    
    // Title
    ctx.font = 'bold 32px monospace';
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fillText('Tic Tac Toe', canvas.width / 2, canvas.height / 2 - 60);
    
    // Rings (large)
    ctx.font = 'bold 112px monospace';
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fillText('Rings', canvas.width / 2, canvas.height / 2 + 20);
    
    // Author
    ctx.font = '16px monospace';
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.7})`;
    ctx.fillText('Fellippe Heitor, 2020', canvas.width / 2, canvas.height - 60);
    
    ctx.restore();
    
    if (introTime > 6 || mouse.clicked) {
        showIntro = false;
        initGame();
    }
}

// Init game
function initGame() {
    // Load settings and high score on first init
    if (!pegs || pegs.length === 0) {
        loadSettings();
        loadHighScore();
    }
    
    initPegs();
    
    // Reset spawn rings
    for (let i = 9; i < 12; i++) {
        pegs[i].rings = [...emptySet];
    }
    
    createMainButtons();
    addParticles(canvas.width / 2, canvas.height / 2, 500, { r: 255, g: 255, b: 255 });
    generateNewSets();
    
    // Start music
    if (sounds.track1 && gameState.musicVolume > 0) {
        sounds.track1.loop = true;
        sounds.track1.volume = gameState.musicVolume;
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
        drawHUD();
        
        // Check hover
        checkButtonHover();
        
        // Draw settings modal on top
        if (showSettingsModal || settingsModalAlpha > 0) {
            drawSettingsModal();
        }
        
        // Draw confirmation modal on top of everything
        if (showConfirmModal || confirmModalAlpha > 0) {
            drawConfirmModal();
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
