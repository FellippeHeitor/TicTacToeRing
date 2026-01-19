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
    prevSfxVolume: 0.7,
    pausedMusicVolume: 0,
    electricConnections: true
};

// LocalStorage functions
function saveSettings() {
    try {
        const settings = {
            musicVolume: gameState.musicVolume,
            sfxVolume: gameState.sfxVolume,
            prevMusicVolume: gameState.prevMusicVolume,
            prevSfxVolume: gameState.prevSfxVolume,
            mode: gameState.mode,
            electricConnections: gameState.electricConnections
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
            gameState.electricConnections = settings.electricConnections ?? true;
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

// Game over modal state
let showGameOverModal = false;
let gameOverModalAlpha = 0;

// HUD animation state
let scoreShake = 0;
let comboScale = 1;
let comboAlpha = 0;
let comboY = 0;
let highscoreGlow = 0;
let multiplierPulse = 0;

// Visual effects state
let backgroundStars = [];
let screenFlash = 0;
let screenZoom = 1;
let lastElectricSoundTime = 0;
let electricSoundActive = false;
let electricSoundFading = false;
let electricSoundInterval = null;
let dragTrails = [];
let rippleEffects = [];
let ambientParticles = [];
let timeOffset = 0;
let vignettePulse = 0;

// Ring colors (10 colors) - Enhanced saturation
const ringColors = [
    { r: 0, g: 120, b: 255 },     // bright blue
    { r: 0, g: 200, b: 80 },       // vibrant green
    { r: 255, g: 50, b: 50 },     // bright red
    { r: 255, g: 230, b: 0 },    // vivid yellow
    { r: 255, g: 150, b: 0 },    // vibrant orange
    { r: 255, g: 100, b: 200 },   // hot pink
    { r: 180, g: 0, b: 255 },    // vivid purple
    { r: 0, g: 255, b: 255 },    // bright cyan
    { r: 255, g: 255, b: 255 },   // white
    { r: 80, g: 80, b: 80 }    // dark gray
];

// Combo messages
const megaComboMsg = ['Fantastic', 'Outstanding', 'Amazing', 'Awesome', 'MEGA', 'SUPER'];

// Particle class for combo explosions with varied shapes
class Particle {
    constructor(x, y, color) {
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 12;
        this.vy = (Math.random() - 0.5) * 12 - 3;
        this.life = 1;
        this.decay = 0.015 + Math.random() * 0.015;
        this.size = 3 + Math.random() * 5;
        this.color = color;
        this.gravity = 0.2;
        this.rotation = Math.random() * Math.PI * 2;
        this.rotationSpeed = (Math.random() - 0.5) * 0.3;
        this.shape = Math.floor(Math.random() * 4); // 0: circle, 1: star, 2: square, 3: triangle
    }
    
    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.vy += this.gravity;
        this.rotation += this.rotationSpeed;
        this.life -= this.decay;
        return this.life > 0;
    }
    
    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = this.life;
        ctx.translate(this.x, this.y);
        ctx.rotate(this.rotation);
        
        if (this.shape === 0) {
            // Circle
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 10;
            ctx.shadowColor = this.color;
            ctx.beginPath();
            ctx.arc(0, 0, this.size, 0, Math.PI * 2);
            ctx.fill();
        } else if (this.shape === 1) {
            // Star
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 10;
            ctx.shadowColor = this.color;
            ctx.beginPath();
            for (let i = 0; i < 5; i++) {
                const angle = (i * 4 * Math.PI) / 5;
                const r = i % 2 === 0 ? this.size : this.size / 2;
                const px = Math.cos(angle) * r;
                const py = Math.sin(angle) * r;
                if (i === 0) ctx.moveTo(px, py);
                else ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.fill();
        } else if (this.shape === 2) {
            // Square
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 10;
            ctx.shadowColor = this.color;
            ctx.fillRect(-this.size / 2, -this.size / 2, this.size, this.size);
        } else {
            // Triangle
            ctx.fillStyle = this.color;
            ctx.shadowBlur = 10;
            ctx.shadowColor = this.color;
            ctx.beginPath();
            ctx.moveTo(0, -this.size);
            ctx.lineTo(this.size, this.size);
            ctx.lineTo(-this.size, this.size);
            ctx.closePath();
            ctx.fill();
        }
        
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
    combo: [],
    electric: null
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

// Draw ring with 3D effect, gradients, reflections
function drawRing(x, y, size, colorIndex) {
    // Size 1 = smallest (inner), Size 2 = medium, Size 3 = largest (outer)
    const outerRadius = size * 14;
    const innerRadius = size * (8 + size);
    const ringWidth = outerRadius - innerRadius;
    const ringRadius = (outerRadius + innerRadius) / 2;
    const color = ringColors[colorIndex];
    
    // Enhanced saturation for multiplier
    const satBoost = Math.min(1.5, 1 + gameState.multiplier * 0.05);
    const r = Math.min(255, color.r * satBoost);
    const g = Math.min(255, color.g * satBoost);
    const b = Math.min(255, color.b * satBoost);
    
    ctx.save();
    
    // Ring shadow (projected below)
    if (mouse.dragging === -1 || y !== mouse.y) {
        ctx.beginPath();
        ctx.arc(x, y + 3, ringRadius, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(0, 0, 0, 0.3)';
        ctx.lineWidth = ringWidth;
        ctx.shadowBlur = 8;
        ctx.shadowColor = 'rgba(0, 0, 0, 0.4)';
        ctx.stroke();
    }
    
    // Main ring with 3D gradient
    ctx.shadowBlur = 0;
    const gradient = ctx.createRadialGradient(
        x - ringRadius * 0.3, y - ringRadius * 0.3, innerRadius,
        x, y, outerRadius
    );
    gradient.addColorStop(0, `rgb(${Math.min(255, r + 40)}, ${Math.min(255, g + 40)}, ${Math.min(255, b + 40)})`);
    gradient.addColorStop(0.5, `rgb(${r}, ${g}, ${b})`);
    gradient.addColorStop(1, `rgb(${r * 0.6}, ${g * 0.6}, ${b * 0.6})`);
    
    ctx.strokeStyle = gradient;
    ctx.lineWidth = ringWidth;
    ctx.beginPath();
    ctx.arc(x, y, ringRadius, 0, Math.PI * 2);
    ctx.stroke();
    
    // Inner shadow for depth
    ctx.beginPath();
    ctx.arc(x, y, innerRadius + 2, 0, Math.PI * 2);
    ctx.strokeStyle = `rgba(0, 0, 0, 0.3)`;
    ctx.lineWidth = 3;
    ctx.stroke();
    
    // Highlight/reflection on top
    const highlightGradient = ctx.createRadialGradient(
        x - ringRadius * 0.4, y - ringRadius * 0.4, 0,
        x - ringRadius * 0.4, y - ringRadius * 0.4, ringRadius * 0.6
    );
    highlightGradient.addColorStop(0, 'rgba(255, 255, 255, 0.6)');
    highlightGradient.addColorStop(0.5, 'rgba(255, 255, 255, 0.2)');
    highlightGradient.addColorStop(1, 'rgba(255, 255, 255, 0)');
    
    ctx.beginPath();
    ctx.arc(x, y, ringRadius, -Math.PI * 0.75, -Math.PI * 0.25);
    ctx.strokeStyle = highlightGradient;
    ctx.lineWidth = ringWidth * 0.5;
    ctx.stroke();
    
    // Neon glow for high multipliers
    if (gameState.multiplier > 2) {
        ctx.shadowBlur = 15 + gameState.multiplier * 2;
        ctx.shadowColor = `rgba(${r}, ${g}, ${b}, ${0.6})`;
        ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, 0.3)`;
        ctx.lineWidth = ringWidth;
        ctx.beginPath();
        ctx.arc(x, y, ringRadius, 0, Math.PI * 2);
        ctx.stroke();
    }
    
    ctx.restore();
}

// Add drag trail
function addDragTrail(x, y, colorIndex) {
    const color = ringColors[colorIndex];
    dragTrails.push({
        x, y,
        color: `rgb(${color.r}, ${color.g}, ${color.b})`,
        life: 1,
        size: 15 + Math.random() * 10
    });
}

// Add ripple effect
function addRipple(x, y, colorIndex) {
    const color = ringColors[colorIndex];
    rippleEffects.push({
        x, y,
        radius: 0,
        maxRadius: 80,
        color: `rgb(${color.r}, ${color.g}, ${color.b})`,
        life: 1
    });
}

// Draw trails
function drawDragTrails() {
    ctx.save();
    dragTrails = dragTrails.filter(trail => {
        trail.life -= 0.05;
        if (trail.life <= 0) return false;
        
        ctx.globalAlpha = trail.life * 0.5;
        ctx.fillStyle = trail.color;
        ctx.shadowBlur = 15;
        ctx.shadowColor = trail.color;
        ctx.beginPath();
        ctx.arc(trail.x, trail.y, trail.size * trail.life, 0, Math.PI * 2);
        ctx.fill();
        
        return true;
    });
    ctx.restore();
}

// Draw ripple effects
function drawRipples() {
    ctx.save();
    rippleEffects = rippleEffects.filter(ripple => {
        ripple.radius += 4;
        ripple.life -= 0.02;
        if (ripple.life <= 0 || ripple.radius > ripple.maxRadius) return false;
        
        ctx.strokeStyle = ripple.color;
        ctx.globalAlpha = ripple.life;
        ctx.lineWidth = 3;
        ctx.shadowBlur = 10;
        ctx.shadowColor = ripple.color;
        ctx.beginPath();
        ctx.arc(ripple.x, ripple.y, ripple.radius, 0, Math.PI * 2);
        ctx.stroke();
        
        // Inner ripple
        ctx.globalAlpha = ripple.life * 0.5;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(ripple.x, ripple.y, ripple.radius * 0.7, 0, Math.PI * 2);
        ctx.stroke();
        
        return true;
    });
    ctx.restore();
}

// Initialize background stars
function initBackgroundStars() {
    backgroundStars = [];
    for (let i = 0; i < 150; i++) {
        backgroundStars.push({
            x: Math.random() * canvas.width,
            y: Math.random() * canvas.height,
            size: Math.random() * 2 + 0.5,
            speed: Math.random() * 0.3 + 0.1,
            brightness: Math.random(),
            vx: 0,
            vy: 0
        });
    }
}

// Initialize ambient particles
function initAmbientParticles() {
    ambientParticles = [];
    for (let i = 0; i < 30; i++) {
        ambientParticles.push({
            x: Math.random() * canvas.width,
            y: Math.random() * canvas.height,
            vx: (Math.random() - 0.5) * 0.5,
            vy: (Math.random() - 0.5) * 0.5,
            size: Math.random() * 3 + 1,
            hue: Math.random() * 60 + 180,
            life: Math.random()
        });
    }
}

// Disturb ambient particles near a position
function disturbParticles(x, y, force = 1, radius = 200) {
    // Disturb ambient particles
    ambientParticles.forEach(p => {
        const dx = p.x - x;
        const dy = p.y - y;
        const distance = Math.sqrt(dx * dx + dy * dy);
        
        if (distance < radius) {
            const angle = Math.atan2(dy, dx);
            const distanceFactor = 1 - (distance / radius);
            const pushForce = force * distanceFactor * 8;
            
            p.vx += Math.cos(angle) * pushForce;
            p.vy += Math.sin(angle) * pushForce;
        }
    });
    
    // Disturb background stars
    backgroundStars.forEach(star => {
        const dx = star.x - x;
        const dy = star.y - y;
        const distance = Math.sqrt(dx * dx + dy * dy);
        
        if (distance < radius) {
            const angle = Math.atan2(dy, dx);
            const distanceFactor = 1 - (distance / radius);
            const pushForce = force * distanceFactor * 5; // Stars move less than particles
            
            star.vx += Math.cos(angle) * pushForce;
            star.vy += Math.sin(angle) * pushForce;
        }
    });
}

// Draw background
function drawBackground() {
    // Animated gradient background
    const time = Date.now() / 5000;
    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    
    // Shifting colors
    const hue1 = 250 + Math.sin(time) * 20;
    const hue2 = 270 + Math.cos(time * 0.7) * 20;
    
    gradient.addColorStop(0, `hsl(${hue1}, 60%, 10%)`);
    gradient.addColorStop(0.5, `hsl(${(hue1 + hue2) / 2}, 50%, 12%)`);
    gradient.addColorStop(1, `hsl(${hue2}, 55%, 9%)`);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Vignette effect
    const vignetteGradient = ctx.createRadialGradient(
        canvas.width / 2, canvas.height / 2, 0,
        canvas.width / 2, canvas.height / 2, Math.max(canvas.width, canvas.height) * 0.7
    );
    vignetteGradient.addColorStop(0, 'rgba(0, 0, 0, 0)');
    vignetteGradient.addColorStop(1, `rgba(0, 0, 0, ${0.3 + vignettePulse * 0.2})`);
    ctx.fillStyle = vignetteGradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Update and draw background stars
    ctx.save();
    backgroundStars.forEach(star => {
        star.y += star.speed + star.vy;
        star.x += star.vx;
        
        // Apply damping
        star.vx *= 0.92;
        star.vy *= 0.92;
        
        if (star.y > canvas.height) {
            star.y = 0;
            star.x = Math.random() * canvas.width;
            star.vx = 0;
            star.vy = 0;
        }
        
        // Wrap horizontally
        if (star.x < 0) star.x = canvas.width;
        if (star.x > canvas.width) star.x = 0;
        
        star.brightness = 0.3 + Math.sin(Date.now() / 1000 + star.x) * 0.3;
        
        ctx.fillStyle = `rgba(200, 220, 255, ${star.brightness})`;
        ctx.shadowBlur = star.size * 2;
        ctx.shadowColor = 'rgba(150, 200, 255, 0.8)';
        ctx.fillRect(star.x, star.y, star.size, star.size);
    });
    ctx.shadowBlur = 0;
    ctx.restore();
    
    // Update and draw ambient particles
    ctx.save();
    ambientParticles.forEach(p => {
        p.x += p.vx;
        p.y += p.vy;
        p.life += 0.01;
        
        // Apply damping to velocities
        p.vx *= 0.95;
        p.vy *= 0.95;
        
        // Wrap around
        if (p.x < 0) p.x = canvas.width;
        if (p.x > canvas.width) p.x = 0;
        if (p.y < 0) p.y = canvas.height;
        if (p.y > canvas.height) p.y = 0;
        
        const alpha = (Math.sin(p.life) + 1) * 0.15;
        ctx.fillStyle = `hsla(${p.hue}, 80%, 60%, ${alpha})`;
        ctx.shadowBlur = p.size * 3;
        ctx.shadowColor = `hsla(${p.hue}, 100%, 70%, 0.5)`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
    });
    ctx.shadowBlur = 0;
    ctx.restore();
    
    // Scanlines
    ctx.fillStyle = 'rgba(139, 116, 177, 0.03)';
    for (let i = 0; i < canvas.height; i += 4) {
        ctx.fillRect(0, i, canvas.width, 1);
    }
}

// Draw board divisions
function drawBoardDivisions() {
    const spacing = 8;
    const offsetX = 20;
    const pulse = Math.sin(Date.now() / 1000) * 0.15 + 0.35;
    
    // Game board area with glow
    ctx.save();
    ctx.strokeStyle = `rgba(100, 150, 255, ${pulse})`;
    ctx.lineWidth = 2;
    ctx.shadowBlur = 15;
    ctx.shadowColor = `rgba(100, 150, 255, ${pulse * 0.8})`;
    ctx.strokeRect(
        canvas.width / 2 - (canvas.width / spacing) * 1.5 + offsetX,
        canvas.height / 2 - (canvas.height / spacing) * 1.5,
        canvas.width / spacing * 3,
        canvas.height / spacing * 3
    );
    
    // Inner glow
    ctx.strokeStyle = `rgba(100, 150, 255, ${pulse * 0.5})`;
    ctx.lineWidth = 1;
    ctx.shadowBlur = 25;
    ctx.strokeRect(
        canvas.width / 2 - (canvas.width / spacing) * 1.5 + offsetX,
        canvas.height / 2 - (canvas.height / spacing) * 1.5,
        canvas.width / spacing * 3,
        canvas.height / spacing * 3
    );
    ctx.restore();
    
    // Spawn area with warm glow
    ctx.save();
    ctx.strokeStyle = `rgba(255, 180, 100, ${pulse * 0.8})`;
    ctx.lineWidth = 2;
    ctx.shadowBlur = 12;
    ctx.shadowColor = `rgba(255, 150, 50, ${pulse * 0.6})`;
    ctx.strokeRect(
        pegs[9].x - (canvas.width / spacing / 2),
        pegs[9].y - (canvas.height / spacing / 2),
        (pegs[11].x - pegs[9].x) + canvas.width / spacing,
        canvas.height / spacing
    );
    ctx.restore();
    
    // Draw slot indicators
    ctx.save();
    for (let i = 0; i < 9; i++) {
        const slotPulse = Math.sin(Date.now() / 800 + i * 0.3) * 0.1 + 0.15;
        ctx.fillStyle = `rgba(100, 150, 255, ${slotPulse})`;
        ctx.shadowBlur = 8;
        ctx.shadowColor = `rgba(100, 150, 255, ${slotPulse})`;
        ctx.beginPath();
        ctx.arc(pegs[i].x, pegs[i].y, 35, 0, Math.PI * 2);
        ctx.fill();
    }
    ctx.restore();
}

// Draw pegs
function drawPegs() {
    for (let i = 0; i < 9; i++) {
        // Peg shadow
        ctx.save();
        ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
        ctx.shadowBlur = 8;
        ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
        ctx.beginPath();
        ctx.arc(pegs[i].x, pegs[i].y + 2, 4, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
        
        // Peg with 3D gradient
        const pegGradient = ctx.createRadialGradient(
            pegs[i].x - 1, pegs[i].y - 1, 0,
            pegs[i].x, pegs[i].y, 5
        );
        pegGradient.addColorStop(0, '#ffffff');
        pegGradient.addColorStop(0.7, '#e0e0e0');
        pegGradient.addColorStop(1, '#a0a0a0');
        
        ctx.fillStyle = pegGradient;
        ctx.shadowBlur = 4;
        ctx.shadowColor = 'rgba(255, 255, 255, 0.5)';
        ctx.beginPath();
        ctx.arc(pegs[i].x, pegs[i].y, 4, 0, Math.PI * 2);
        ctx.fill();
        ctx.shadowBlur = 0;
    }
}

// Hover highlight effect
// Draw electric connections between matching rings
function drawElectricConnections(comboInfo, dragPegIndex, targetPegIndex) {
    if (!comboInfo.hasCombo) return;
    
    const time = Date.now() / 200; // Slower pulsation
    const dragX = mouse.x;
    const dragY = mouse.y;
    const dragSet = pegs[dragPegIndex].rings;
    
    // Calculate distance factor (0 to 1, where 1 is closest)
    const targetPeg = pegs[targetPegIndex];
    const distance = dist(dragX, dragY, targetPeg.x, targetPeg.y);
    const maxDistance = 300; // Maximum distance to show effect
    const distanceFactor = Math.max(0, 1 - (distance / maxDistance));
    const intensity = distanceFactor * distanceFactor; // Squared for more dramatic falloff
    
    // Start electric sound with fade in if not already playing
    if (sounds.electric && !electricSoundActive && intensity > 0.3) {
        electricSoundActive = true;
        electricSoundFading = false;
        sounds.electric.loop = true;
        sounds.electric.volume = 0;
        sounds.electric.currentTime = 0;
        sounds.electric.play().catch(() => {});
        
        // Fade in over 200ms
        const fadeInSteps = 20;
        const fadeInInterval = 10;
        const targetVolume = gameState.sfxVolume * 0.3;
        let step = 0;
        
        if (electricSoundInterval) clearInterval(electricSoundInterval);
        electricSoundInterval = setInterval(() => {
            if (sounds.electric && step < fadeInSteps) {
                step++;
                sounds.electric.volume = (step / fadeInSteps) * targetVolume;
            } else {
                clearInterval(electricSoundInterval);
                electricSoundInterval = null;
            }
        }, fadeInInterval);
    }
    
    ctx.save();
    
    // Group matching rings by color for proper connections
    const ringsByColor = {};
    comboInfo.matchingRings.forEach(match => {
        if (!ringsByColor[match.color]) {
            ringsByColor[match.color] = [];
        }
        
        // Check if this ring belongs to the peg being dragged
        const isDraggingThisPeg = match.pegIdx === dragPegIndex;
        
        if (isDraggingThisPeg) {
            ringsByColor[match.color].push({
                x: dragX,
                y: dragY,
                pegIdx: match.pegIdx,
                ringIdx: match.ringIdx,
                isDragged: true
            });
        } else {
            const targetPeg = pegs[match.pegIdx];
            ringsByColor[match.color].push({
                x: targetPeg.x,
                y: targetPeg.y,
                pegIdx: match.pegIdx,
                ringIdx: match.ringIdx,
                isDragged: false
            });
        }
    });
    
    // Draw lightning connections between ALL rings of the same color
    Object.values(ringsByColor).forEach(rings => {
        // Draw connections between every pair of rings
        for (let i = 0; i < rings.length; i++) {
            for (let j = i + 1; j < rings.length; j++) {
                const ring1 = rings[i];
                const ring2 = rings[j];
                
                // Determine if this connection involves the dragged ring
                const involvesDrag = ring1.isDragged || ring2.isDragged;
                
                // Scale bolt properties based on distance
                const boltIntensity = involvesDrag ? intensity : 1;
                const numBolts = involvesDrag ? Math.floor(1 + intensity * 4) : 2; // 1-5 bolts when dragging
                const baseOpacity = involvesDrag ? 0.3 + intensity * 0.7 : 0.6;
                const baseWidth = involvesDrag ? 1 + intensity * 3 : 2;
                const baseShadow = involvesDrag ? 10 + intensity * 20 : 15;
                
                for (let b = 0; b < numBolts; b++) {
                    // Scale opacity and width based on intensity
                    ctx.strokeStyle = `rgba(150, 220, 255, ${baseOpacity + Math.random() * 0.2})`;
                    ctx.lineWidth = baseWidth + Math.random() * 1;
                    ctx.shadowBlur = baseShadow;
                    ctx.shadowColor = `rgba(150, 220, 255, ${0.5 + intensity * 0.4})`;
                    ctx.lineCap = 'round';
                    ctx.lineJoin = 'round';
                    
                    ctx.beginPath();
                    ctx.moveTo(ring1.x, ring1.y);
                    
                    // Create jagged lightning path - more segments when stronger
                    const segments = involvesDrag ? Math.floor(4 + intensity * 4) : 6;
                    for (let s = 1; s <= segments; s++) {
                        const t = s / segments;
                        const px = ring1.x + (ring2.x - ring1.x) * t;
                        const py = ring1.y + (ring2.y - ring1.y) * t;
                        const jitter = (Math.random() - 0.5) * (15 + intensity * 15) * Math.sin(t * Math.PI);
                        const angle = Math.atan2(ring2.y - ring1.y, ring2.x - ring1.x);
                        
                        ctx.lineTo(
                            px + Math.cos(angle + Math.PI / 2) * jitter,
                            py + Math.sin(angle + Math.PI / 2) * jitter
                        );
                    }
                    
                    ctx.stroke();
                }
            }
        }
        
        // Draw glows at each ring position
        rings.forEach((ring, idx) => {
            const ringSize = 3 - ring.ringIdx;
            const ringRadius = ringSize * 7;
            const glowIntensity = ring.isDragged ? intensity : 0.5;
            const glowRadius = ringRadius + 12 + Math.sin(time * 1.5 + idx) * 3 + glowIntensity * 10;
            
            // Outer glow - more translucent, scales with intensity
            const ringGlow = ctx.createRadialGradient(
                ring.x, ring.y, ringRadius - 5,
                ring.x, ring.y, glowRadius
            );
            const glowAlpha = 0.15 + glowIntensity * 0.25;
            ringGlow.addColorStop(0, `rgba(150, 220, 255, ${glowAlpha + Math.sin(time * 1.5 + idx * 0.5) * 0.1})`);
            ringGlow.addColorStop(0.6, `rgba(100, 200, 255, ${glowAlpha * 0.5})`);
            ringGlow.addColorStop(1, 'rgba(100, 200, 255, 0)');
            ctx.fillStyle = ringGlow;
            ctx.beginPath();
            ctx.arc(ring.x, ring.y, glowRadius, 0, Math.PI * 2);
            ctx.fill();
            
            // Bright inner core - more translucent, scales with intensity
            if (ring.isDragged) {
                const coreRadius = 20 + intensity * 15;
                const coreGlow = ctx.createRadialGradient(ring.x, ring.y, 0, ring.x, ring.y, coreRadius);
                const coreAlpha = 0.2 + intensity * 0.4;
                coreGlow.addColorStop(0, `rgba(200, 240, 255, ${coreAlpha + Math.sin(time * 1.2) * 0.15})`);
                coreGlow.addColorStop(1, 'rgba(150, 220, 255, 0)');
                ctx.fillStyle = coreGlow;
                ctx.beginPath();
                ctx.arc(ring.x, ring.y, coreRadius, 0, Math.PI * 2);
                ctx.fill();
            }
        });
    });
    
    // Draw pulsing glow at each matching peg - scales with intensity
    comboInfo.matchingPegs.forEach((pegIdx, idx) => {
        const peg = pegs[pegIdx];
        const isTarget = pegIdx === targetPegIndex;
        const pegIntensity = isTarget ? intensity : 0.5;
        const pulseRadius = 45 + pegIntensity * 20 + Math.sin(time * 1.2 + idx * 0.7) * 8;
        
        const pegGlow = ctx.createRadialGradient(peg.x, peg.y, 15, peg.x, peg.y, pulseRadius);
        const pegAlpha = 0.1 + pegIntensity * 0.2;
        pegGlow.addColorStop(0, `rgba(100, 200, 255, ${pegAlpha})`);
        pegGlow.addColorStop(0.5, `rgba(150, 220, 255, ${pegAlpha * 0.5})`);
        pegGlow.addColorStop(1, 'rgba(200, 240, 255, 0)');
        
        ctx.fillStyle = pegGlow;
        ctx.beginPath();
        ctx.arc(peg.x, peg.y, pulseRadius, 0, Math.PI * 2);
        ctx.fill();
    });
    
    ctx.shadowBlur = 0;
    ctx.restore();
}

function stopElectricSound() {
    if (sounds.electric && electricSoundActive && !electricSoundFading) {
        electricSoundFading = true;
        
        // Fade out over 150ms
        const fadeOutSteps = 15;
        const fadeOutInterval = 10;
        const startVolume = sounds.electric.volume;
        let step = 0;
        
        if (electricSoundInterval) clearInterval(electricSoundInterval);
        electricSoundInterval = setInterval(() => {
            if (sounds.electric && step < fadeOutSteps) {
                step++;
                sounds.electric.volume = startVolume * (1 - step / fadeOutSteps);
            } else {
                if (sounds.electric) {
                    sounds.electric.pause();
                    sounds.electric.currentTime = 0;
                }
                electricSoundActive = false;
                electricSoundFading = false;
                clearInterval(electricSoundInterval);
                electricSoundInterval = null;
            }
        }, fadeOutInterval);
    }
}

function drawHoverHighlight() {
    // Check for combo effect when dragging
    if (mouse.dragging >= 0 && gameState.electricConnections) {
        let foundCombo = false;
        // Check each board peg for potential combo
        for (let i = 0; i < 9; i++) {
            if (dist(pegs[i].x, pegs[i].y, mouse.x, mouse.y) <= 40) {
                const comboInfo = wouldCreateCombo(i, mouse.dragging);
                if (comboInfo.hasCombo) {
                    drawElectricConnections(comboInfo, mouse.dragging, i);
                    foundCombo = true;
                }
                break;
            }
        }
        if (!foundCombo) {
            stopElectricSound();
        }
        return;
    } else if (mouse.dragging >= 0) {
        stopElectricSound();
        return;
    }
    
    stopElectricSound();
    
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
            
            // Add drag trail for each ring
            for (let ringIdx = 0; ringIdx < 3; ringIdx++) {
                const colorIndex = peg.rings[ringIdx];
                if (colorIndex >= 0 && Math.random() < 0.3) {
                    addDragTrail(x, y, colorIndex);
                }
            }
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

function easeOutElastic(t) {
    const p = 0.3;
    return Math.pow(2, -10 * t) * Math.sin((t - p / 4) * (2 * Math.PI) / p) + 1;
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
    ctx.fillText('SCORE', scorePanel.x + 10, scorePanel.y + 10);
    
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
        
        // Flash effect and spawn animation
        animations.push({
            type: 'spawn',
            startTime: Date.now(),
            duration: 1000
        });
        
        // Add scale animation for new spawns
        for (let i = 9; i < 12; i++) {
            animations.push({
                type: 'spawn-scale',
                pegIdx: i,
                startTime: Date.now(),
                duration: 500,
                scale: 0
            });
        }
    }
}

// Check if placing would create a combo (without actually placing)
// Returns object with: { hasCombo: boolean, matchingPegs: [pegIndexes], matchingRings: [{pegIdx, ringIdx, color}] }
function wouldCreateCombo(targetPegIndex, dragPegIndex) {
    if (targetPegIndex < 0 || targetPegIndex >= 9 || dragPegIndex < 9 || dragPegIndex >= 12) {
        return { hasCombo: false, matchingPegs: [], matchingRings: [] };
    }
    
    // Simulate placement
    const targetSet = [...pegs[targetPegIndex].rings];
    const dragSet = pegs[dragPegIndex].rings;
    
    // Check if can place
    for (let j = 0; j < 3; j++) {
        if (dragSet[j] >= 0 && targetSet[j] >= 0) {
            return { hasCombo: false, matchingPegs: [], matchingRings: [] };
        }
    }
    
    // Simulate the placement
    for (let j = 0; j < 3; j++) {
        if (dragSet[j] >= 0) {
            targetSet[j] = dragSet[j];
        }
    }
    
    let matchingPegs = [];
    let matchingRings = [];
    
    // Check if this creates a match on the peg (3 same color)
    if (targetSet[0] >= 0 && targetSet[0] === targetSet[1] && targetSet[1] === targetSet[2]) {
        matchingPegs.push(targetPegIndex);
        for (let j = 0; j < 3; j++) {
            matchingRings.push({ pegIdx: targetPegIndex, ringIdx: j, color: targetSet[j] });
        }
        // Don't return yet - continue checking lines in case this peg is also part of a line combo
    }
    
    // Check lines
    const lineConfigs = [
        [[0, 1, 2], [3, 4, 5], [6, 7, 8]], // Horizontal
        [[0, 3, 6], [1, 4, 7], [2, 5, 8]], // Vertical
        [[0, 4, 8], [2, 4, 6]]              // Diagonals
    ];
    
    for (let configLines of lineConfigs) {
        for (let line of configLines) {
            if (!line.includes(targetPegIndex)) continue;
            
            // Check if line would create a match
            const simulatedPegs = pegs.slice(0, 9).map(p => ({ rings: [...p.rings] }));
            simulatedPegs[targetPegIndex].rings = targetSet;
            
            const peg0Colors = simulatedPegs[line[0]].rings.filter(c => c >= 0);
            const peg1Colors = simulatedPegs[line[1]].rings.filter(c => c >= 0);
            const peg2Colors = simulatedPegs[line[2]].rings.filter(c => c >= 0);
            
            const commonColors = peg0Colors.filter(color => 
                peg1Colors.includes(color) && peg2Colors.includes(color)
            );
            
            if (commonColors.length > 0) {
                // Collect all matching rings
                line.forEach(pegIdx => {
                    if (!matchingPegs.includes(pegIdx)) matchingPegs.push(pegIdx);
                    for (let ringIdx = 0; ringIdx < 3; ringIdx++) {
                        const ringColor = simulatedPegs[pegIdx].rings[ringIdx];
                        if (commonColors.includes(ringColor)) {
                            matchingRings.push({ pegIdx, ringIdx, color: ringColor });
                        }
                    }
                });
            }
        }
    }
    
    return { 
        hasCombo: matchingRings.length > 0, 
        matchingPegs, 
        matchingRings 
    };
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
        
        // Disturb ambient particles strongly
        disturbParticles(pegs[pegIndex].x, pegs[pegIndex].y, 2, 250);
        
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
                // Disturb particles along the entire line strongly
                line.forEach(pegIdx => {
                    disturbParticles(pegs[pegIdx].x, pegs[pegIdx].y, 2.5, 300);
                });
                
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
        
        // Trigger screen shake and effects for big scores
        if (scoreIncrease > 5) {
            scoreShake = Math.min(2, scoreIncrease / 10);
            
            // Screen flash with color
            const avgColor = ringColors[Math.floor(Math.random() * gameState.maxColors)];
            screenFlash = 0.4;
            
            // Screen zoom effect for huge combos
            if (gameState.multiplier > 3) {
                screenZoom = 1.05 + (gameState.multiplier - 3) * 0.01;
            }
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
        } else if (anim.type === 'spawn-scale') {
            // Scale animation for spawn entries
            const scale = easeOutElastic(progress);
            const pegX = pegs[anim.pegIdx].x;
            const pegY = pegs[anim.pegIdx].y;
            
            // Store scale for drawRings to use
            anim.scale = scale;
        } else if (anim.type === 'bounce') {
            // Bounce animation when placing rings
            const bounceAmount = Math.sin(progress * Math.PI) * 10;
            anim.bounceY = -bounceAmount;
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
    
    // Check if paused - click anywhere to unpause
    if (gameState.pauseGame && !showSettingsModal && !showConfirmModal && !showGameOverModal) {
        gameState.pauseGame = false;
        // Restore music volume
        if (sounds.track1) {
            sounds.track1.volume = gameState.pausedMusicVolume;
        }
        mouse.down = false;
        mouse.dragging = -1;
        return;
    }
    
    // Check game over modal first
    if (handleGameOverClick(mouse.x, mouse.y)) {
        mouse.down = false;
        mouse.dragging = -1;
        return;
    }
    
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
                            
                            // Add ripple effect for each placed ring
                            addRipple(pegs[i].x, pegs[i].y, dragSet[j]);
                        }
                    }
                    pegs[mouse.dragging].rings = [...emptySet];
                    
                    // Disturb ambient particles
                    disturbParticles(pegs[i].x, pegs[i].y, 0.5, 150);
                    
                    if (sounds.woodblock) playSound(sounds.woodblock);
                    
                    // Stop electric sound immediately (combo is happening)
                    if (sounds.electric && electricSoundActive) {
                        sounds.electric.pause();
                        sounds.electric.currentTime = 0;
                        sounds.electric.volume = 0;
                        electricSoundActive = false;
                        electricSoundFading = false;
                        if (electricSoundInterval) {
                            clearInterval(electricSoundInterval);
                            electricSoundInterval = null;
                        }
                    }
                    
                    // Add bounce animation for placed rings
                    animations.push({
                        type: 'bounce',
                        pegIdx: i,
                        startTime: Date.now(),
                        duration: 300
                    });
                    
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
        
        // Reduce music volume when pausing
        if (gameState.pauseGame && sounds.track1) {
            gameState.pausedMusicVolume = gameState.musicVolume;
            if (gameState.musicVolume > 0.05) {
                sounds.track1.volume = 0.05;
            }
        } else if (!gameState.pauseGame && sounds.track1) {
            // Restore music volume when unpausing
            sounds.track1.volume = gameState.pausedMusicVolume;
        }
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
    const modalHeight = 480;
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
            label: `⚡ Conexões Elétricas: ${gameState.electricConnections ? 'ON' : 'OFF'}`,
            action: 'electric'
        },
        {
            x: startX,
            y: y + spacing * 3,
            width: buttonWidth,
            height: buttonHeight,
            label: `⚔ Modo: ${gameState.mode === MODE_NORMAL ? 'Normal' : 'Fácil'}`,
            action: 'mode'
        },
        {
            x: startX,
            y: y + spacing * 4,
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
    
    // Semi-transparent overlay with blur effect
    ctx.fillStyle = `rgba(0, 0, 0, ${0.6 * settingsModalAlpha})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Modal dimensions
    const modalWidth = 500;
    const modalHeight = 480;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    // Glassmorphism effect
    ctx.save();
    
    // Modal background with frosted glass effect
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    
    // Multiple layers for glass effect
    const glassGradient = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    glassGradient.addColorStop(0, `rgba(255, 255, 255, ${0.15 * settingsModalAlpha})`);
    glassGradient.addColorStop(0.5, `rgba(255, 255, 255, ${0.08 * settingsModalAlpha})`);
    glassGradient.addColorStop(1, `rgba(255, 255, 255, ${0.05 * settingsModalAlpha})`);
    ctx.fillStyle = glassGradient;
    ctx.fill();
    
    // Inner shadow for depth
    ctx.shadowBlur = 30 * settingsModalAlpha;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
    ctx.shadowOffsetY = 10;
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.strokeStyle = `rgba(100, 150, 255, ${0.3 * settingsModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.shadowOffsetY = 0;
    
    // Outer glow
    ctx.shadowBlur = 40 * settingsModalAlpha;
    ctx.shadowColor = `rgba(100, 150, 255, ${0.4 * settingsModalAlpha})`;
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.strokeStyle = `rgba(150, 200, 255, ${0.6 * settingsModalAlpha})`;
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    ctx.restore();
    
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
    
    // Glassmorphism background with frosted glass layers
    ctx.shadowBlur = 40 * confirmModalAlpha;
    ctx.shadowColor = 'rgba(0, 0, 0, 0.8)';
    
    // Layer 1: Backdrop blur simulation (lighter)
    const gradient1 = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient1.addColorStop(0, `rgba(255, 255, 255, ${0.15 * confirmModalAlpha})`);
    gradient1.addColorStop(1, `rgba(255, 255, 255, ${0.05 * confirmModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient1;
    ctx.fill();
    
    // Layer 2: Frosted glass effect
    const gradient2 = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient2.addColorStop(0, `rgba(255, 255, 255, ${0.08 * confirmModalAlpha})`);
    gradient2.addColorStop(1, `rgba(255, 255, 255, ${0.03 * confirmModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient2;
    ctx.fill();
    
    // Layer 3: Subtle highlight
    const gradient3 = ctx.createLinearGradient(modalX, modalY, modalX + modalWidth, modalY);
    gradient3.addColorStop(0, `rgba(255, 255, 255, ${0.05 * confirmModalAlpha})`);
    gradient3.addColorStop(0.5, `rgba(255, 255, 255, ${0.02 * confirmModalAlpha})`);
    gradient3.addColorStop(1, `rgba(255, 255, 255, ${0.05 * confirmModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient3;
    ctx.fill();
    
    ctx.shadowBlur = 0;
    
    // Glass reflection border
    ctx.strokeStyle = `rgba(255, 255, 255, ${0.2 * confirmModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.shadowBlur = 10 * confirmModalAlpha;
    ctx.shadowColor = `rgba(255, 200, 100, ${confirmModalAlpha})`;
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
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
    ctx.fillText('✓ Yes', btn1X + btnWidth / 2, btnY + btnHeight / 2);
    
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
    ctx.fillText('✕ No', btn2X + btnWidth / 2, btnY + btnHeight / 2);
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

// Draw game over modal
function drawGameOverModal() {
    if (!showGameOverModal && gameOverModalAlpha <= 0) return;
    
    // Animate alpha
    if (showGameOverModal && gameOverModalAlpha < 1) {
        gameOverModalAlpha = Math.min(1, gameOverModalAlpha + 0.05);
    } else if (!showGameOverModal && gameOverModalAlpha > 0) {
        gameOverModalAlpha = Math.max(0, gameOverModalAlpha - 0.1);
    }
    
    // Semi-transparent overlay (lighter to see board behind)
    ctx.fillStyle = `rgba(0, 0, 0, ${0.4 * gameOverModalAlpha})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    // Modal dimensions
    const modalWidth = 500;
    const modalHeight = 350;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    // Glassmorphism background with frosted glass layers
    ctx.shadowBlur = 40 * gameOverModalAlpha;
    ctx.shadowColor = 'rgba(255, 0, 100, 0.5)';
    
    // Layer 1: Backdrop blur simulation (lighter)
    const gradient1 = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient1.addColorStop(0, `rgba(255, 255, 255, ${0.15 * gameOverModalAlpha})`);
    gradient1.addColorStop(1, `rgba(255, 255, 255, ${0.05 * gameOverModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient1;
    ctx.fill();
    
    // Layer 2: Frosted glass effect
    const gradient2 = ctx.createLinearGradient(modalX, modalY, modalX, modalY + modalHeight);
    gradient2.addColorStop(0, `rgba(255, 255, 255, ${0.08 * gameOverModalAlpha})`);
    gradient2.addColorStop(1, `rgba(255, 255, 255, ${0.03 * gameOverModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient2;
    ctx.fill();
    
    // Layer 3: Subtle highlight
    const gradient3 = ctx.createLinearGradient(modalX, modalY, modalX + modalWidth, modalY);
    gradient3.addColorStop(0, `rgba(255, 255, 255, ${0.05 * gameOverModalAlpha})`);
    gradient3.addColorStop(0.5, `rgba(255, 255, 255, ${0.02 * gameOverModalAlpha})`);
    gradient3.addColorStop(1, `rgba(255, 255, 255, ${0.05 * gameOverModalAlpha})`);
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.fillStyle = gradient3;
    ctx.fill();
    
    ctx.shadowBlur = 0;
    
    // Glass reflection border
    ctx.strokeStyle = `rgba(255, 100, 150, ${0.6 * gameOverModalAlpha})`;
    ctx.lineWidth = 3;
    ctx.shadowBlur = 15 * gameOverModalAlpha;
    ctx.shadowColor = `rgba(255, 50, 100, ${gameOverModalAlpha})`;
    roundRect(ctx, modalX, modalY, modalWidth, modalHeight, 20);
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    // Title
    ctx.font = 'bold 48px Arial';
    ctx.fillStyle = `rgba(255, 100, 150, ${gameOverModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.shadowBlur = 10 * gameOverModalAlpha;
    ctx.shadowColor = 'rgba(255, 0, 100, 0.8)';
    ctx.fillText('Game Over!', canvas.width / 2, modalY + 40);
    ctx.shadowBlur = 0;
    
    // Score
    ctx.font = 'bold 24px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${gameOverModalAlpha})`;
    ctx.fillText(`Final Score: ${Math.floor(gameState.score)}`, canvas.width / 2, modalY + 120);
    
    // High score message
    if (gameState.score >= gameState.highscore) {
        ctx.font = 'bold 20px Arial';
        ctx.fillStyle = `rgba(255, 215, 0, ${gameOverModalAlpha})`;
        ctx.shadowBlur = 10 * gameOverModalAlpha;
        ctx.shadowColor = 'rgba(255, 165, 0, 0.8)';
        ctx.fillText('🎉 New High Score! 🎉', canvas.width / 2, modalY + 160);
        ctx.shadowBlur = 0;
    }
    
    // Buttons
    const btnWidth = 180;
    const btnHeight = 50;
    const btnY = modalY + modalHeight - 80;
    const btnSpacing = 20;
    const btn1X = modalX + (modalWidth / 2) - btnWidth - btnSpacing / 2;
    const btn2X = modalX + (modalWidth / 2) + btnSpacing / 2;
    
    // Play again button
    const playHovered = mouseX >= btn1X && mouseX <= btn1X + btnWidth &&
                       mouseY >= btnY && mouseY <= btnY + btnHeight;
    
    if (playHovered) {
        ctx.shadowBlur = 20 * gameOverModalAlpha;
        ctx.shadowColor = 'rgba(100, 255, 100, 0.8)';
    } else {
        ctx.shadowBlur = 10 * gameOverModalAlpha;
        ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
    }
    
    const playGradient = ctx.createLinearGradient(btn1X, btnY, btn1X, btnY + btnHeight);
    if (playHovered) {
        playGradient.addColorStop(0, `rgba(80, 200, 80, ${gameOverModalAlpha})`);
        playGradient.addColorStop(1, `rgba(50, 150, 50, ${gameOverModalAlpha})`);
    } else {
        playGradient.addColorStop(0, `rgba(60, 160, 60, ${gameOverModalAlpha})`);
        playGradient.addColorStop(1, `rgba(40, 120, 40, ${gameOverModalAlpha})`);
    }
    
    roundRect(ctx, btn1X, btnY, btnWidth, btnHeight, 10);
    ctx.fillStyle = playGradient;
    ctx.fill();
    ctx.strokeStyle = `rgba(100, 255, 100, ${0.6 * gameOverModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    ctx.font = 'bold 20px Arial';
    ctx.fillStyle = `rgba(255, 255, 255, ${gameOverModalAlpha})`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Play Again', btn1X + btnWidth / 2, btnY + btnHeight / 2);
    
    // Menu button
    const menuHovered = mouseX >= btn2X && mouseX <= btn2X + btnWidth &&
                       mouseY >= btnY && mouseY <= btnY + btnHeight;
    
    if (menuHovered) {
        ctx.shadowBlur = 20 * gameOverModalAlpha;
        ctx.shadowColor = 'rgba(255, 150, 100, 0.8)';
    } else {
        ctx.shadowBlur = 10 * gameOverModalAlpha;
        ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
    }
    
    const menuGradient = ctx.createLinearGradient(btn2X, btnY, btn2X, btnY + btnHeight);
    if (menuHovered) {
        menuGradient.addColorStop(0, `rgba(180, 100, 50, ${gameOverModalAlpha})`);
        menuGradient.addColorStop(1, `rgba(130, 70, 30, ${gameOverModalAlpha})`);
    } else {
        menuGradient.addColorStop(0, `rgba(150, 80, 40, ${gameOverModalAlpha})`);
        menuGradient.addColorStop(1, `rgba(100, 50, 20, ${gameOverModalAlpha})`);
    }
    
    roundRect(ctx, btn2X, btnY, btnWidth, btnHeight, 10);
    ctx.fillStyle = menuGradient;
    ctx.fill();
    ctx.strokeStyle = `rgba(255, 150, 100, ${0.6 * gameOverModalAlpha})`;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.shadowBlur = 0;
    
    ctx.fillStyle = `rgba(255, 255, 255, ${gameOverModalAlpha})`;
    ctx.fillText('Menu', btn2X + btnWidth / 2, btnY + btnHeight / 2);
}

// Handle game over modal clicks
function handleGameOverClick(x, y) {
    if (!showGameOverModal || gameOverModalAlpha < 0.9) return false;
    
    const modalWidth = 500;
    const modalHeight = 350;
    const modalX = (canvas.width - modalWidth) / 2;
    const modalY = (canvas.height - modalHeight) / 2;
    
    const btnWidth = 180;
    const btnHeight = 50;
    const btnY = modalY + modalHeight - 80;
    const btnSpacing = 20;
    const btn1X = modalX + (modalWidth / 2) - btnWidth - btnSpacing / 2;
    const btn2X = modalX + (modalWidth / 2) + btnSpacing / 2;
    
    // Play again button
    if (x >= btn1X && x <= btn1X + btnWidth &&
        y >= btnY && y <= btnY + btnHeight) {
        showGameOverModal = false;
        gameOverModalAlpha = 0;
        
        // Reset game
        gameState.score = 0;
        gameState.visibleScore = 0;
        gameState.level = 0;
        gameState.multiplier = 1;
        gameState.maxColors = 3;
        gameState.gameOver = false;
        
        // Restart music if volume > 0
        if (sounds.track1 && gameState.musicVolume > 0) {
            sounds.track1.currentTime = 0;
            sounds.track1.loop = true;
            sounds.track1.volume = gameState.musicVolume;
            sounds.track1.play().catch(() => {});
        }
        
        initGame();
        return true;
    }
    
    // Menu button
    if (x >= btn2X && x <= btn2X + btnWidth &&
        y >= btnY && y <= btnY + btnHeight) {
        showGameOverModal = false;
        gameOverModalAlpha = 0;
        gameState.gameOver = false;
        
        // Stop music
        if (sounds.track1) {
            sounds.track1.pause();
            sounds.track1.currentTime = 0;
        }
        
        // Reset to intro
        showIntro = true;
        introTime = 0;
        mouse.clicked = false; // Reset to prevent skipping intro
        initIntro();
        return true;
    }
    
    return false;
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
                
                if (btn.action === 'electric') {
                    // Toggle electric connections
                    gameState.electricConnections = !gameState.electricConnections;
                    saveSettings();
                    createSettingsButtons();
                    return true;
                } else if (btn.action === 'mode') {
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
    // Add particle burst at center
    for (let i = 0; i < 200; i++) {
        const angle = Math.random() * Math.PI * 2;
        const speed = Math.random() * 3 + 1;
        const color = ringColors[Math.floor(Math.random() * ringColors.length)];
        particles.push(new Particle(
            canvas.width / 2,
            canvas.height / 2,
            Math.cos(angle) * speed,
            Math.sin(angle) * speed,
            color
        ));
    }
    
    for (let i = 0; i < 30; i++) {
        introRings.push({
            angle: Math.random() * Math.PI * 2,
            speed: Math.random() * 5,
            radius: Math.random() * 30 + 50,
            color: Math.floor(Math.random() * ringColors.length),
            size: Math.floor(Math.random() * 3) // 0, 1, or 2
        });
    }
}

function updateIntro(dt) {
    introTime += dt;
    
    drawBackground();
    
    // Draw electric bolts between same-colored intro rings that are close
    if (introTime > 1 && introTime < 5) {
        ctx.save();
        
        // Check all pairs of rings
        for (let i = 0; i < introRings.length; i++) {
            for (let j = i + 1; j < introRings.length; j++) {
                const ring1 = introRings[i];
                const ring2 = introRings[j];
                
                // Only connect rings of the same color
                if (ring1.color !== ring2.color) continue;
                
                const x1 = canvas.width / 2 + Math.cos(ring1.angle) * ring1.radius;
                const y1 = canvas.height / 2 + Math.sin(ring1.angle) * ring1.radius;
                const x2 = canvas.width / 2 + Math.cos(ring2.angle) * ring2.radius;
                const y2 = canvas.height / 2 + Math.sin(ring2.angle) * ring2.radius;
                
                // Calculate distance between rings
                const distance = Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
                const maxDistance = 250;
                
                // Only draw bolt if rings are close enough
                if (distance > maxDistance) continue;
                
                // Calculate intensity based on distance
                const intensity = 1 - (distance / maxDistance);
                const boltAlpha = (0.3 + intensity * 0.6) * (0.7 + Math.random() * 0.3);
                
                // Draw lightning bolt
                ctx.strokeStyle = `rgba(150, 220, 255, ${boltAlpha})`;
                ctx.lineWidth = 1 + intensity * 2;
                ctx.shadowBlur = 15 + intensity * 20;
                ctx.shadowColor = `rgba(150, 220, 255, ${0.6 + intensity * 0.4})`;
                ctx.lineCap = 'round';
                
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                
                const segments = 4 + Math.floor(intensity * 3);
                for (let s = 1; s <= segments; s++) {
                    const t = s / segments;
                    const px = x1 + (x2 - x1) * t;
                    const py = y1 + (y2 - y1) * t;
                    const jitter = (Math.random() - 0.5) * (10 + intensity * 15) * Math.sin(t * Math.PI);
                    const angle = Math.atan2(y2 - y1, x2 - x1);
                    
                    ctx.lineTo(
                        px + Math.cos(angle + Math.PI / 2) * jitter,
                        py + Math.sin(angle + Math.PI / 2) * jitter
                    );
                }
                
                ctx.stroke();
            }
        }
        ctx.shadowBlur = 0;
        ctx.restore();
    }
    
    // Animate rings
    introRings.forEach(ring => {
        ring.angle += 0.01;
        ring.radius += ring.speed * dt * 60;
        const x = canvas.width / 2 + Math.cos(ring.angle) * ring.radius;
        const y = canvas.height / 2 + Math.sin(ring.angle) * ring.radius;
        drawRing(x, y, ring.size, ring.color);
    });
    
    // Update and draw particles
    updateAnimations();
    
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
    ctx.fillText('Fellippe Heitor, 2020-2026', canvas.width / 2, canvas.height - 60);
    
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
        
        // Initialize visual effects
        initBackgroundStars();
        initAmbientParticles();
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
        // Update effects
        if (screenFlash > 0) screenFlash -= dt * 2;
        if (screenZoom > 1) screenZoom = lerp(screenZoom, 1, dt * 5);
        vignettePulse = Math.sin(Date.now() / 2000) * 0.5 + 0.5;
        
        // Apply zoom transform
        ctx.save();
        if (screenZoom !== 1) {
            ctx.translate(canvas.width / 2, canvas.height / 2);
            ctx.scale(screenZoom, screenZoom);
            ctx.translate(-canvas.width / 2, -canvas.height / 2);
        }
        
        // Update
        if (!gameState.pauseGame && !showSettingsModal) {
            updateScore(dt);
            generateNewSets();
            
            // Check game over after score is fully updated
            if (!gameState.gameOver && !checkAvailableMoves()) {
                // Wait for score animation to complete
                if (Math.abs(gameState.visibleScore - gameState.score) < 1) {
                    gameState.gameOver = true;
                }
            }
        }
        
        // Draw
        drawBackground();
        drawBoardDivisions();
        drawPegs();
        drawDragTrails();
        drawHoverHighlight();
        drawRings();
        drawRipples();
        updateAnimations();
        drawHUD();
        
        // Screen flash effect
        if (screenFlash > 0) {
            ctx.globalAlpha = screenFlash;
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.globalAlpha = 1;
        }
        
        // Restore zoom transform
        ctx.restore();
        
        // Draw pause overlay if paused
        if (gameState.pauseGame) {
            ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.font = 'bold 60px Arial';
            ctx.fillStyle = '#ffffff';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.shadowBlur = 20;
            ctx.shadowColor = 'rgba(255, 255, 255, 0.8)';
            ctx.fillText('PAUSADO', canvas.width / 2, canvas.height / 2 - 30);
            
            ctx.font = '24px Arial';
            ctx.shadowBlur = 10;
            ctx.fillText('Clique para continuar', canvas.width / 2, canvas.height / 2 + 30);
            ctx.shadowBlur = 0;
        }
        
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
        
        // Game over modal
        if (gameState.gameOver && !showGameOverModal) {
            showGameOverModal = true;
        }
        
        if (showGameOverModal || gameOverModalAlpha > 0) {
            drawGameOverModal();
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
            electric: 'assets/sounds/fridge-buzz-loop-39612.mp3',
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
