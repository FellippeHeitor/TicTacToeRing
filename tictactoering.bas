OPTION _EXPLICIT

$EXEICON:'./assets/images/tttr.ico'
$RESIZE:STRETCH

$VERSIONINFO:FILEVERSION#=1,2,0,0
$VERSIONINFO:PRODUCTVERSION#=1,2,0,0
$VERSIONINFO:CompanyName=Fellippe Heitor
$VERSIONINFO:ProductName=Tic Tac Toe Ring
$VERSIONINFO:ProductVersion=1.2
$VERSIONINFO:Comments=Based on 'Rings.' by Gamezaur; Created with QB64.
$VERSIONINFO:Web=https://github.com/FellippeHeitor/TicTacToeRing
$VERSIONINFO:InternalName=tictactoering.bas

CONST true = -1, false = 0

CONST MODE_NORMAL = 0
CONST MODE_EASIER = 1

CONST GAME_OVER_GLOW = .8 'glow phase (with electric buzz)
CONST GAME_OVER_TREMBLE = .5 'tremble phase
CONST GAME_OVER_EXPLOSION = .3 'explosion phase
CONST GAME_OVER_NO_MOVES = 1
CONST GAME_OVER_QUIT = 2
CONST TUTORIAL_DELAY = 5 'show tutorial after 5 seconds of inactivity
CONST ELECTRIC_FADE_IN = .3
CONST ELECTRIC_FADE_OUT = .2
CONST MAX_MATCHES = 60

'millisecond timer from the QB64 runtime; TIMER is limited to 18.2Hz
DECLARE LIBRARY
    FUNCTION GetTicks&&
END DECLARE

'online scoreboard code
DIM SHARED auth AS STRING, host AS STRING, getboardpath AS STRING
DIM SHARED updateboardpath AS STRING, timelimit AS INTEGER, maxHighScores AS INTEGER
auth = CHR$(52) + CHR$(50) + CHR$(51) + CHR$(49) + CHR$(52)
host = CHR$(119) + CHR$(119) + CHR$(119) + CHR$(46) + CHR$(113) + CHR$(98) + CHR$(54) + CHR$(52) + CHR$(46) + CHR$(111) + CHR$(114) + CHR$(103)
getboardpath = CHR$(47) + CHR$(116) + CHR$(116) + CHR$(116) + CHR$(114) + CHR$(105) + CHR$(110) + CHR$(103) + CHR$(47) + CHR$(103) + CHR$(101) + CHR$(116) + CHR$(98) + CHR$(111) + CHR$(97) + CHR$(114) + CHR$(100) + CHR$(46) + CHR$(112) + CHR$(104) + CHR$(112)
updateboardpath = CHR$(47) + CHR$(116) + CHR$(116) + CHR$(116) + CHR$(114) + CHR$(105) + CHR$(110) + CHR$(103) + CHR$(47) + CHR$(117) + CHR$(112) + CHR$(100) + CHR$(97) + CHR$(116) + CHR$(101) + CHR$(98) + CHR$(111) + CHR$(97) + CHR$(114) + CHR$(100) + CHR$(46) + CHR$(112) + CHR$(104) + CHR$(112)
timelimit = 10
maxHighScores = 10


'Required shared variables for printLarge
DIM SHARED charSet(255, 1 TO 16, 1 TO 8) AS _BYTE

initializeCharSetPrintLarge

TYPE object
    x AS SINGLE
    y AS SINGLE
    xv AS SINGLE
    yv AS SINGLE
    xa AS SINGLE
    ya AS SINGLE
    set AS STRING * 6
    size AS SINGLE
    start AS SINGLE
    duration AS SINGLE
    state AS _BYTE
    text AS INTEGER
    w AS INTEGER
    h AS INTEGER
    r AS INTEGER
    g AS INTEGER
    b AS INTEGER
END TYPE

TYPE particleType
    x AS SINGLE
    y AS SINGLE
    xv AS SINGLE
    yv AS SINGLE
    size AS SINGLE
    start AS SINGLE
    duration AS SINGLE
    life AS SINGLE
    decay AS SINGLE
    rotation AS SINGLE
    rotationSpeed AS SINGLE
    shape AS INTEGER '0 = classic dot; 1 to 4 = combo burst shapes
    state AS _BYTE
    c AS _UNSIGNED LONG
END TYPE

TYPE starType
    x AS SINGLE
    y AS SINGLE
    xv AS SINGLE
    yv AS SINGLE
    size AS SINGLE
    speed AS SINGLE
END TYPE

TYPE ambientType
    x AS SINGLE
    y AS SINGLE
    xv AS SINGLE
    yv AS SINGLE
    size AS SINGLE
    hue AS SINGLE
    life AS SINGLE
END TYPE

TYPE rippleType
    x AS SINGLE
    y AS SINGLE
    radius AS SINGLE
    life AS SINGLE
    c AS _UNSIGNED LONG
    state AS _BYTE
END TYPE

TYPE sparkleType
    x AS SINGLE
    y AS SINGLE
    xv AS SINGLE
    yv AS SINGLE
    size AS SINGLE
    life AS SINGLE
    c AS _UNSIGNED LONG
    state AS _BYTE
END TYPE

TYPE matchType
    peg AS INTEGER
    slot AS INTEGER
    colr AS INTEGER
END TYPE

TYPE newHighScore
    player AS STRING * 8
    score AS _UNSIGNED LONG
END TYPE

DIM SHARED canvas AS LONG
canvas = _NEWIMAGE(900, 700, 32)

SCREEN canvas
_DELAY .1
_SCREENMOVE _MIDDLE
_TITLE "Tic Tac Toe Ring"
_PRINTMODE _KEEPBACKGROUND

DIM SHARED peg(0 TO 12) AS object
DIM SHARED del(1 TO 9) AS object

DIM SHARED emptySet$
emptySet$ = MKI$(-1) + MKI$(-1) + MKI$(-1)
DIM pegIndex AS INTEGER
FOR pegIndex = 0 TO 12
    peg(pegIndex).set = emptySet$
NEXT

'images
DIM SHARED ringColor(1 TO 10) AS _UNSIGNED LONG
DIM SHARED circleImage(1 TO 10, 1 TO 3) AS LONG, circleGlow(1 TO 10, 1 TO 3) AS LONG
DIM SHARED ringShadow(1 TO 3) AS LONG, pegImage AS LONG, crownIcon AS LONG
DIM SHARED bg AS LONG, spawnAreaImage AS LONG
DIM SHARED spawnX AS SINGLE, spawnY AS SINGLE, spawnW AS SINGLE, spawnH AS SINGLE

'sounds
DIM SHARED selectSound AS LONG, wooshSound AS LONG, woodblock AS LONG, electricSound AS LONG
DIM SHARED track(1 TO 1) AS LONG, comboSound(1 TO 8) AS LONG
DIM SHARED musicVolume AS SINGLE, sfxVolume AS SINGLE
DIM SHARED prevMusicVolume AS SINGLE, prevSfxVolume AS SINGLE
DIM SHARED mainTrackVolume AS SINGLE
DIM SHARED electricConnections AS _BYTE
DIM SHARED electricVolume AS SINGLE, electricTarget AS SINGLE

'game
DIM SHARED megaComboMsg$(1 TO 6), m$(1 TO 2)
DIM SHARED mode AS INTEGER
DIM SHARED score AS _UNSIGNED LONG, visibleScore AS SINGLE
DIM SHARED highscore AS _UNSIGNED LONG, visibleHighScore AS SINGLE
DIM SHARED level AS _UNSIGNED LONG, maxColors AS INTEGER
DIM SHARED animation(0 TO 8) AS object, multiplier AS INTEGER, totalMatches AS INTEGER
DIM SHARED gameOver AS _BYTE, gameOverDone AS _BYTE, gameOverReason AS INTEGER
DIM SHARED gameOverStart AS DOUBLE, exploded AS _BYTE
DIM SHARED pauseGame AS _BYTE, enterSettings AS _BYTE, userQuit AS _BYTE, keyb AS LONG
DIM SHARED dragging AS INTEGER, mouseDown AS _BYTE
DIM SHARED returnAnim(10 TO 12) AS object
DIM SHARED showTutorial AS _BYTE, tutorialTime AS SINGLE
DIM SHARED screenFlash AS SINGLE, screenZoom AS SINGLE, scoreShake AS SINGLE, frameDt AS SINGLE

'visual effects
DIM SHARED particle(5000) AS particleType
DIM SHARED star(1 TO 150) AS starType, ambient(1 TO 30) AS ambientType
DIM SHARED ripple(1 TO 40) AS rippleType, sparkle(1 TO 60) AS sparkleType

'electric connections between rings that would match
DIM SHARED match(1 TO MAX_MATCHES) AS matchType, matchCount AS INTEGER
DIM SHARED matchTarget AS INTEGER, matchStart AS DOUBLE
DIM SHARED lastMatch(1 TO MAX_MATCHES) AS matchType, lastMatchCount AS INTEGER
DIM SHARED lastMatchTarget AS INTEGER, lastMatchDrag AS INTEGER
DIM SHARED fadingOut AS _BYTE, fadeOutStart AS DOUBLE

'buttons
DIM SHARED button(100) AS object
DIM SHARED caption(100) AS STRING
DIM SHARED totalButtons AS INTEGER
DIM SHARED currentButton AS INTEGER

'set pegs positions
setPegs
generateSpawnArea

'set combo messages
setComboMessages

setRingColors
generateRingImages
generatePegImage
generateCrownIcon

_DEST _DISPLAY
generateBG
initBackgroundStars
initAmbientParticles

'flash warning
drawWarning

musicVolume = .7
sfxVolume = .7
prevMusicVolume = .7
prevSfxVolume = .7
electricConnections = true
mainTrackVolume = 1

loadGame
setPegs 'saves made by older versions stored the 600x600 layout

'load sounds
DIM loadStart AS DOUBLE
loadStart = clock
selectSound = _SNDOPEN("assets/sounds/select.ogg")
wooshSound = _SNDOPEN("assets/sounds/woosh.ogg")
woodblock = _SNDOPEN("assets/sounds/woodblock.wav")
electricSound = _SNDOPEN("assets/sounds/fridge-buzz-loop-39612.mp3")
track(1) = _SNDOPEN("assets/music/track1.ogg")

DIM i AS INTEGER, a$
RESTORE comboSoundFiles
FOR i = 1 TO 8
    READ a$
    comboSound(i) = _SNDOPEN("assets/sounds/" + a$)
NEXT

comboSoundFiles:
DATA do.ogg,re.ogg,mi.ogg,fa.ogg,sol.ogg,la.ogg,si.ogg,do2.ogg

'if loading sounds took more than 2 seconds, no need to pause
IF clock - loadStart < 2 THEN showWarning 2 - (clock - loadStart)

doIntro

RANDOMIZE TIMER

'game
animation(0).duration = .25 'board flash
FOR i = 1 TO 5
    animation(i).duration = .5 'matches
NEXT
animation(6).duration = 1 'new set spawn
animation(7).duration = 1.5 'combo info

multiplier = 1
screenZoom = 1

visibleScore = score
visibleHighScore = highscore
_DEST _DISPLAY

DIM highScore(maxHighScores) AS newHighScore
DIM totalHS AS INTEGER
DIM board$, filename$, prevbt AS INTEGER, lastFrame AS DOUBLE, currentMode AS INTEGER

DO
    'read highscores
    board$ = downloadBoard

    IF mode = 0 THEN filename$ = "highscores.dat"
    IF mode = 1 THEN filename$ = "highscores_easier.dat"

    IF LEN(board$) > 0 THEN 'WRITES THAT TO THE FILE
        OPEN filename$ FOR OUTPUT AS #1
        PRINT #1, board$
        CLOSE #1
    END IF

    IF _FILEEXISTS(filename$) THEN
        highscore = 0
        OPEN filename$ FOR INPUT AS #1
        FOR i = 1 TO maxHighScores
            IF EOF(1) THEN EXIT FOR
            INPUT #1, highScore(i).player
            INPUT #1, highScore(i).score
            IF highScore(i).score > highscore THEN highscore = highScore(i).score
            totalHS = i
        NEXT
        CLOSE #1
    END IF

    visibleHighScore = highscore
    addParticles _WIDTH / 2, _HEIGHT / 2, 5000, _RGB32(255)
    dragging = 0
    mouseDown = false
    gameOverDone = false
    lastFrame = clock

    DO 'main game loop
        'read mouse data
        WHILE _MOUSEINPUT: WEND

        'read keyboard
        keyb = _KEYHIT

        frameDt = clock - lastFrame
        lastFrame = clock
        IF frameDt <= 0 OR frameDt > .25 THEN frameDt = 1 / 60

        IF mainTrackVolume > .5 THEN
            mainTrackVolume = mainTrackVolume - .05
            applyMusicVolume
        END IF

        IF pauseGame = false THEN generateNewSets

        'redraw board
        drawBackground
        drawSpawnArea
        drawBoardSlots
        drawPegs

        createMainScreenButtons
        IF ABS(keyb) <> 27 AND pauseGame = false AND gameOver = false AND enterSettings = false AND dragging = 0 THEN
            checkButtons
        ELSE
            currentButton = 0
        END IF

        IF currentButton <> prevbt THEN
            IF currentButton > 0 THEN playSfx selectSound, .3
            prevbt = currentButton
        END IF

        IF pauseGame THEN
            'click anywhere to continue
            IF _MOUSEBUTTON(1) THEN
                mouseDown = true
            ELSEIF mouseDown OR keyb = 32 OR keyb = 13 THEN
                mouseDown = false
                pauseGame = false
                applyMusicVolume
                addParticles _MOUSEX, _MOUSEY, 30, _RGB32(255)
                addParticles _MOUSEX, _MOUSEY, 30, _RGB32(67, 172, 183)
            END IF
        ELSEIF gameOver = false THEN
            IF _MOUSEBUTTON(1) THEN
                IF NOT mouseDown THEN
                    'are we beginning to drag a ring or set of rings?
                    dragging = 0
                    FOR i = 10 TO 12
                        IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 40 AND peg(i).set <> emptySet$ THEN
                            dragging = i
                            returnAnim(i).state = false
                            showTutorial = false
                            tutorialTime = 0
                            EXIT FOR
                        END IF
                    NEXT

                    mouseDown = true
                END IF
            ELSEIF mouseDown THEN
                IF dragging = 0 THEN
                    SELECT CASE currentButton
                        CASE 1 'settings
                            enterSettings = true
                        CASE 2 'pause
                            pauseGame = true
                            applyMusicVolume
                            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(255)
                            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(67, 172, 183)
                        CASE 3 'quit
                            startGameOver GAME_OVER_QUIT
                    END SELECT
                ELSE
                    placeRings
                END IF
                mouseDown = false
                dragging = 0
            END IF
        END IF

        IF keyb = ASC("q") AND _KEYDOWN(100306) AND gameOver = false THEN startGameOver GAME_OVER_QUIT

        updateElectric
        IF gameOver = false AND pauseGame = false THEN generateSparkles

        drawElectricConnections
        updateSparkles
        drawRings
        drawGameOverEffects
        updateRipples
        doAnimations
        updateParticles
        drawHUD
        drawTutorial

        IF screenFlash > 0 THEN
            LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(screenFlash, 0, 1) * 255), BF
        END IF

        applyScreenZoom

        IF pauseGame THEN drawPauseOverlay

        'update display
        _DISPLAY

        IF pauseGame = false THEN
            updateScore

            IF screenFlash > 0 THEN screenFlash = screenFlash - frameDt * 2
            IF screenZoom > 1 THEN
                screenZoom = lerp(screenZoom, 1, frameDt * 5)
                IF screenZoom < 1.001 THEN screenZoom = 1
            END IF

            'tutorial shows up after a while without playing
            IF showTutorial = false AND dragging = 0 AND score = 0 AND gameOver = false THEN
                tutorialTime = tutorialTime + frameDt
                IF tutorialTime >= TUTORIAL_DELAY THEN showTutorial = true
            END IF

            'no more moves? wait for the score to finish counting first
            IF gameOver = false AND dragging = 0 THEN
                IF movesAvailable = false AND ABS(visibleScore - score) < 1 AND scoreFlying = false THEN
                    startGameOver GAME_OVER_NO_MOVES
                END IF
            END IF
        END IF

        IF gameOver THEN
            IF clock - gameOverStart >= GAME_OVER_GLOW + GAME_OVER_TREMBLE AND exploded = false THEN explodeSpawnedRings
            IF clock - gameOverStart >= GAME_OVER_GLOW + GAME_OVER_TREMBLE + GAME_OVER_EXPLOSION THEN gameOverDone = true
        END IF

        updateElectricSound

        IF enterSettings THEN
            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(255)
            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(67, 172, 183)
            currentMode = mode
            settingsScreen
            enterSettings = false
            IF currentMode <> mode THEN
                'restart game if mode changes
                resetGame
                GOTO outerLoop
            END IF
        END IF

        'limit fps
        _LIMIT 60

        userQuit = _EXIT
        IF keyb = -27 AND gameOver = false THEN EXIT DO
    LOOP UNTIL gameOverDone OR userQuit

    stopElectricNow
    dragging = 0
    saveGame

    IF userQuit THEN SYSTEM

    endScreen
    outerLoop:
LOOP

FUNCTION clock#
    'seconds since the program started (offset so that a zeroed .start is always in the past)
    clock# = GetTicks / 1000 + 1000
END FUNCTION

SUB setPegs
    DIM i AS INTEGER, col AS INTEGER, row AS INTEGER

    'board is 3x3 (pegs 1-9); spawn area is the fourth row (pegs 10-12)
    FOR i = 1 TO 12
        col = (i - 1) MOD 3
        row = (i - 1) \ 3
        peg(i).x = _WIDTH / 2 + (col - 1) * (_WIDTH / 6) + 20
        peg(i).y = _HEIGHT / 2 + (row - 1) * (_HEIGHT / 6)
    NEXT

    spawnX = peg(10).x - 60
    spawnY = peg(10).y - 60
    spawnW = peg(12).x - peg(10).x + 120
    spawnH = 120
END SUB

SUB setComboMessages
    DIM i AS INTEGER

    RESTORE megaComboMsgs
    FOR i = 1 TO UBOUND(megaComboMsg$)
        READ megaComboMsg$(i)
    NEXT
    megaComboMsgs:
    DATA Fantastic,Outstanding,Amazing,Awesome,MEGA,SUPER
END SUB

SUB setRingColors
    ringColor(1) = _RGB32(0, 120, 255) 'blue
    ringColor(2) = _RGB32(0, 200, 80) 'green
    ringColor(3) = _RGB32(255, 50, 50) 'red
    ringColor(4) = _RGB32(255, 230, 0) 'yellow
    ringColor(5) = _RGB32(255, 150, 0) 'orange
    ringColor(6) = _RGB32(255, 100, 200) 'pink
    ringColor(7) = _RGB32(180, 0, 255) 'purple
    ringColor(8) = _RGB32(0, 255, 255) 'cyan
    ringColor(9) = _RGB32(255, 255, 255) 'white
    ringColor(10) = _RGB32(80, 80, 80) 'dark gray
END SUB

SUB generateRingImages
    'rings are shaded like tubes lit from the top-left; a brighter copy is used for glowing
    DIM colr AS INTEGER, k AS INTEGER, pass AS INTEGER, img AS LONG, prevDest AS LONG
    DIM outerR AS SINGLE, innerR AS SINGLE, ringR AS SINGLE, ringW AS SINGLE
    DIM half AS INTEGER, sz AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM dx AS SINGLE, dy AS SINGLE, d AS SINGLE, e AS SINGLE, cover AS SINGLE
    DIM u AS SINGLE, tube AS SINGLE, dirLight AS SINGLE, lightF AS SINGLE, spec AS SINGLE
    DIM bright AS SINGLE, r AS SINGLE, g AS SINGLE, b AS SINGLE

    prevDest = _DEST
    FOR k = 1 TO 3
        outerR = k * 14
        innerR = k * (8 + k)
        ringR = (outerR + innerR) / 2
        ringW = outerR - innerR
        half = outerR + 2
        sz = half * 2 + 1

        'soft shadow, drawn a few pixels below each ring
        ringShadow(k) = _NEWIMAGE(sz + 8, sz + 8, 32)
        _DEST ringShadow(k)
        _DONTBLEND
        FOR py = 0 TO sz + 7
            FOR px = 0 TO sz + 7
                dx = px - (half + 4)
                dy = py - (half + 4)
                d = SQR(dx * dx + dy * dy)
                e = 0
                IF d < innerR THEN e = innerR - d
                IF d > outerR THEN e = d - outerR
                IF e < 4 THEN PSET (px, py), _RGBA32(0, 0, 0, 77 * (1 - e / 4))
            NEXT
        NEXT
        _BLEND

        FOR colr = 1 TO UBOUND(ringColor)
            FOR pass = 0 TO 1
                IF pass = 0 THEN bright = 1 ELSE bright = 1.5
                img = _NEWIMAGE(sz, sz, 32)
                _DEST img
                _DONTBLEND
                FOR py = 0 TO sz - 1
                    FOR px = 0 TO sz - 1
                        dx = px - half
                        dy = py - half
                        d = SQR(dx * dx + dy * dy)
                        cover = clampf(outerR + .5 - d, 0, 1) * clampf(d - innerR + .5, 0, 1)
                        IF cover > 0 THEN
                            u = (d - ringR) / (ringW / 2)
                            tube = SQR(1 - clampf(u * u, 0, 1))
                            IF d > 0 THEN dirLight = -(dx + dy) / (d * 1.4142) ELSE dirLight = 0
                            lightF = (.55 + .45 * tube + .25 * dirLight) * bright
                            spec = 0
                            IF dirLight > 0 THEN spec = (dirLight ^ 3) * (tube ^ 6) * .65
                            r = clampf(_RED32(ringColor(colr)) * lightF + 255 * spec, 0, 255)
                            g = clampf(_GREEN32(ringColor(colr)) * lightF + 255 * spec, 0, 255)
                            b = clampf(_BLUE32(ringColor(colr)) * lightF + 255 * spec, 0, 255)
                            PSET (px, py), _RGBA32(r, g, b, 255 * cover)
                        END IF
                    NEXT
                NEXT
                _BLEND
                IF pass = 0 THEN circleImage(colr, k) = img ELSE circleGlow(colr, k) = img
            NEXT
        NEXT
    NEXT
    _DEST prevDest
END SUB

SUB generatePegImage
    'small metallic peg with a soft shadow; center is at (8, 8)
    DIM px AS INTEGER, py AS INTEGER, prevDest AS LONG
    DIM d AS SINGLE, ds AS SINGLE, sa AS SINGLE, cover AS SINGLE, t AS SINGLE, v AS SINGLE, a AS SINGLE

    prevDest = _DEST
    pegImage = _NEWIMAGE(17, 19, 32)
    _DEST pegImage
    _DONTBLEND
    FOR py = 0 TO 18
        FOR px = 0 TO 16
            ds = dist(px, py, 8, 10)
            sa = 77 * clampf((7 - ds) / 3, 0, 1)
            d = dist(px, py, 8, 8)
            cover = clampf(4.5 - d, 0, 1)
            t = clampf(dist(px, py, 7, 7) / 5, 0, 1)
            IF t < .7 THEN v = lerp(255, 224, t / .7) ELSE v = lerp(224, 160, (t - .7) / .3)
            a = 255 * cover + sa * (1 - cover)
            IF a > 0 THEN
                v = v * 255 * cover / a
                PSET (px, py), _RGBA32(v, v, v, a)
            END IF
        NEXT
    NEXT
    _BLEND
    _DEST prevDest
END SUB

SUB generateCrownIcon
    DIM i AS INTEGER, j AS INTEGER
    DIM px AS INTEGER, prevDest AS LONG

    prevDest = _DEST
    RESTORE crownIconData
    crownIcon = _NEWIMAGE(24, 14, 32)
    _DEST crownIcon
    FOR i = 0 TO 13
        FOR j = 0 TO 23
            READ px
            SELECT CASE px
                CASE 1
                    PSET (j, i), _RGB32(0)
                CASE 2
                    PSET (j, i), _RGB32(255, 215, 0)
            END SELECT
        NEXT
    NEXT
    _DEST prevDest

    crownIconData:
    DATA 0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0
    DATA 0,1,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,1,1,0
    DATA 1,2,2,1,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,1,2,2,1
    DATA 1,2,2,1,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,1,2,2,1
    DATA 0,1,1,2,1,1,0,0,0,1,2,2,2,2,1,0,0,0,1,1,2,1,1,0
    DATA 0,0,1,2,2,2,1,1,0,1,2,2,2,2,1,0,1,1,2,2,2,1,0,0
    DATA 0,0,1,2,2,2,2,2,1,2,2,2,2,2,2,1,2,2,2,2,2,1,0,0
    DATA 0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,0,0,0
    DATA 0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,0,0,0
    DATA 0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,0,0,0,0
    DATA 0,0,0,0,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,0,0,0,0
    DATA 0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0
END SUB

SUB generateBG
    'static part of the background: diagonal gradient, vignette and scanlines
    DIM x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER, prevDest AS LONG
    DIM c1 AS _UNSIGNED LONG, c2 AS _UNSIGNED LONG, c3 AS _UNSIGNED LONG
    DIM ca AS _UNSIGNED LONG, cb AS _UNSIGNED LONG
    DIM t AS SINGLE, f AS SINGLE, v AS SINGLE, maxD AS SINGLE
    DIM r AS SINGLE, g AS SINGLE, b AS SINGLE

    w = _WIDTH
    h = _HEIGHT
    c1 = hsl(250, .6, .1, 255)
    c2 = hsl(260, .5, .12, 255)
    c3 = hsl(270, .55, .09, 255)
    maxD = w * .7
    IF h > w THEN maxD = h * .7

    prevDest = _DEST
    bg = _NEWIMAGE(w, h, 32)
    _DEST bg
    FOR y = 0 TO h - 1
        FOR x = 0 TO w - 1
            t = (x * w + y * h) / (w * w + h * h)
            IF t < .5 THEN
                ca = c1: cb = c2: f = t * 2
            ELSE
                ca = c2: cb = c3: f = (t - .5) * 2
            END IF
            r = lerp(_RED32(ca), _RED32(cb), f)
            g = lerp(_GREEN32(ca), _GREEN32(cb), f)
            b = lerp(_BLUE32(ca), _BLUE32(cb), f)

            v = 1 - clampf(dist(x, y, w / 2, h / 2) / maxD, 0, 1) * .4
            r = r * v: g = g * v: b = b * v

            IF y MOD 4 = 0 THEN
                r = r * .97 + 139 * .03
                g = g * .97 + 116 * .03
                b = b * .97 + 177 * .03
            END IF
            PSET (x, y), _RGB32(r, g, b)
        NEXT
    NEXT
    _DEST prevDest
END SUB

SUB generateSpawnArea
    'glassy panel behind the spawn pegs
    DIM px AS INTEGER, py AS INTEGER, w AS INTEGER, h AS INTEGER, prevDest AS LONG
    DIM cover AS SINGLE, t AS SINGLE, f AS SINGLE, maxR AS SINGLE
    DIM r AS SINGLE, g AS SINGLE, b AS SINGLE, a AS SINGLE

    w = spawnW
    h = spawnH
    maxR = w / 2
    IF h > w THEN maxR = h / 2

    prevDest = _DEST
    spawnAreaImage = _NEWIMAGE(w, h, 32)
    _DEST spawnAreaImage
    _DONTBLEND
    FOR py = 0 TO h - 1
        FOR px = 0 TO w - 1
            cover = roundRectCoverage(px + .5, py + .5, w, h, 25)
            IF cover > 0 THEN
                t = clampf(dist(px, py, w / 2, h / 2) / maxR, 0, 1)
                IF t < .5 THEN
                    f = t * 2
                    r = lerp(80, 60, f): g = lerp(120, 100, f): b = lerp(200, 180, f): a = lerp(.15, .1, f)
                ELSE
                    f = (t - .5) * 2
                    r = lerp(60, 40, f): g = lerp(100, 80, f): b = lerp(180, 160, f): a = lerp(.1, .05, f)
                END IF
                PSET (px, py), _RGBA32(r, g, b, a * 255 * cover)
            END IF
        NEXT
    NEXT
    _BLEND
    _DEST prevDest
END SUB

SUB initBackgroundStars
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(star)
        star(i).x = RND * _WIDTH
        star(i).y = RND * _HEIGHT
        star(i).size = RND * 2 + .5
        star(i).speed = RND * .3 + .1
        star(i).xv = 0
        star(i).yv = 0
    NEXT
END SUB

SUB initAmbientParticles
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(ambient)
        ambient(i).x = RND * _WIDTH
        ambient(i).y = RND * _HEIGHT
        ambient(i).xv = (RND - .5) * .5
        ambient(i).yv = (RND - .5) * .5
        ambient(i).size = RND * 3 + 1
        ambient(i).hue = RND * 60 + 180
        ambient(i).life = RND
    NEXT
END SUB

SUB disturbParticles (x AS SINGLE, y AS SINGLE, force AS SINGLE, radius AS SINGLE)
    'push ambient particles and stars away from an event
    DIM i AS INTEGER, d AS SINGLE, a AS SINGLE, push AS SINGLE

    FOR i = 1 TO UBOUND(ambient)
        d = dist(ambient(i).x, ambient(i).y, x, y)
        IF d < radius THEN
            a = _ATAN2(ambient(i).y - y, ambient(i).x - x)
            push = force * (1 - d / radius) * 8
            ambient(i).xv = ambient(i).xv + COS(a) * push
            ambient(i).yv = ambient(i).yv + SIN(a) * push
        END IF
    NEXT

    FOR i = 1 TO UBOUND(star)
        d = dist(star(i).x, star(i).y, x, y)
        IF d < radius THEN
            a = _ATAN2(star(i).y - y, star(i).x - x)
            push = force * (1 - d / radius) * 5
            star(i).xv = star(i).xv + COS(a) * push
            star(i).yv = star(i).yv + SIN(a) * push
        END IF
    NEXT
END SUB

SUB drawBackground
    DIM t AS DOUBLE, i AS INTEGER, a AS SINGLE, hue1 AS SINGLE, hue2 AS SINGLE

    t = clock
    _DONTBLEND
    _PUTIMAGE (0, 0), bg
    _BLEND

    'slowly shifting hue
    hue1 = 250 + SIN(t / 5) * 20
    hue2 = 270 + COS(t * .7 / 5) * 20
    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), hsl((hue1 + hue2) / 2, .6, .14, 40), BF

    'falling stars
    FOR i = 1 TO UBOUND(star)
        star(i).y = star(i).y + star(i).speed + star(i).yv
        star(i).x = star(i).x + star(i).xv
        star(i).xv = star(i).xv * .92
        star(i).yv = star(i).yv * .92

        IF star(i).y > _HEIGHT THEN
            star(i).y = 0
            star(i).x = RND * _WIDTH
            star(i).xv = 0
            star(i).yv = 0
        END IF
        IF star(i).x < 0 THEN star(i).x = _WIDTH
        IF star(i).x > _WIDTH THEN star(i).x = 0

        a = .3 + SIN(t + star(i).x) * .3
        IF a > 0 THEN LINE (star(i).x, star(i).y)-STEP(star(i).size, star(i).size), _RGBA32(200, 220, 255, a * 255), BF
    NEXT

    'ambient particles
    FOR i = 1 TO UBOUND(ambient)
        ambient(i).x = ambient(i).x + ambient(i).xv
        ambient(i).y = ambient(i).y + ambient(i).yv
        ambient(i).life = ambient(i).life + .01
        ambient(i).xv = ambient(i).xv * .95
        ambient(i).yv = ambient(i).yv * .95

        IF ambient(i).x < 0 THEN ambient(i).x = _WIDTH
        IF ambient(i).x > _WIDTH THEN ambient(i).x = 0
        IF ambient(i).y < 0 THEN ambient(i).y = _HEIGHT
        IF ambient(i).y > _HEIGHT THEN ambient(i).y = 0

        a = (SIN(ambient(i).life) + 1) * .15
        CircleFill ambient(i).x, ambient(i).y, ambient(i).size * 2.5, hsl(ambient(i).hue, 1, .7, a * 64)
        CircleFill ambient(i).x, ambient(i).y, ambient(i).size, hsl(ambient(i).hue, .8, .6, a * 255)
    NEXT
END SUB

SUB drawSpawnArea
    DIM pulse AS SINGLE, k AS INTEGER

    pulse = SIN(clock / 1.5) * .2 + .5
    _PUTIMAGE (spawnX, spawnY), spawnAreaImage

    FOR k = 1 TO 4 'outer glow
        roundRectLine spawnX - k, spawnY - k, spawnW + k * 2, spawnH + k * 2, 25 + k, _RGBA32(100, 150, 255, pulse * 60 * (1 - k / 5))
    NEXT
    roundRectLine spawnX, spawnY, spawnW, spawnH, 25, _RGBA32(100, 150, 255, pulse * 102)
    roundRectLine spawnX + 1, spawnY + 1, spawnW - 2, spawnH - 2, 24, _RGBA32(100, 150, 255, pulse * 102)
    roundRectLine spawnX + 5, spawnY + 5, spawnW - 10, spawnH - 10, 20, _RGBA32(150, 200, 255, pulse * 77)
END SUB

SUB drawBoardSlots
    DIM i AS INTEGER, k AS INTEGER, p AS SINGLE, t AS DOUBLE

    t = clock
    FOR i = 1 TO 9
        p = SIN(t / .8 + i * .3) * .1 + .15
        CircleFill peg(i).x, peg(i).y, 35, _RGBA32(100, 150, 255, p * 255)
        FOR k = 1 TO 4
            CIRCLE (peg(i).x, peg(i).y), 35 + k, _RGBA32(100, 150, 255, p * 150 * (1 - k / 5))
        NEXT
    NEXT
END SUB

SUB drawPegs
    DIM i AS INTEGER
    FOR i = 1 TO 9
        _PUTIMAGE (peg(i).x - 8, peg(i).y - 8), pegImage
    NEXT
END SUB

SUB drawWarning
    drawBackground
    COLOR _RGB32(255)
    centerLarge (_HEIGHT / 2) - fontHeightLarge(2) / 2, "This game contains bright,", 2
    centerLarge (_HEIGHT / 2) + fontHeightLarge(2) / 2, "rapidly flashing colors.", 2
END SUB

SUB showWarning (duration AS SINGLE)
    'keep the warning up, with the stars already moving behind it
    DIM start AS DOUBLE
    start = clock
    DO
        drawWarning
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > duration OR _KEYHIT
END SUB

SUB doIntro
    DIM x AS SINGLE, y AS SINGLE, i AS INTEGER, j AS INTEGER
    DIM introRings(1 TO 30) AS object
    DIM px(1 TO 30) AS SINGLE, py(1 TO 30) AS SINGLE, connected(1 TO 30) AS _BYTE
    DIM introTimer AS DOUBLE, t AS SINGLE, d AS SINGLE, intensity AS SINGLE, glowI AS SINGLE

    FOR i = 1 TO UBOUND(introRings)
        introRings(i).xa = RND * _PI(2)
        introRings(i).xv = RND * 5
        introRings(i).size = RND * 30 + 50
        introRings(i).w = _CEIL(RND * 3) 'ring size
        introRings(i).text = _CEIL(RND * UBOUND(ringColor)) 'ring color
    NEXT

    addParticles _WIDTH / 2, _HEIGHT / 2, 5000, _RGB32(255)

    introTimer = clock
    applyMusicVolume
    DO
        t = clock - introTimer
        drawBackground

        FOR i = 1 TO UBOUND(introRings)
            introRings(i).xa = introRings(i).xa + .01
            introRings(i).size = introRings(i).size + introRings(i).xv
            px(i) = _WIDTH / 2 + COS(introRings(i).xa) * introRings(i).size
            py(i) = _HEIGHT / 2 + SIN(introRings(i).xa) * introRings(i).size
            connected(i) = false
        NEXT

        'electric bolts between nearby rings of the same color
        IF t > 1 AND t < 5 THEN
            FOR i = 1 TO UBOUND(introRings) - 1
                FOR j = i + 1 TO UBOUND(introRings)
                    IF introRings(i).text = introRings(j).text THEN
                        d = dist(px(i), py(i), px(j), py(j))
                        IF d <= 250 THEN
                            connected(i) = true
                            connected(j) = true
                            intensity = 1 - d / 250
                            drawBolt px(i), py(i), px(j), py(j), 4 + INT(intensity * 3), 10 + intensity * 15, 1 + intensity * 2, (.3 + intensity * .6) * (.7 + RND * .3)
                        END IF
                    END IF
                NEXT
            NEXT
        END IF

        glowI = .5 + SIN(clock / .15) * .3
        FOR i = 1 TO UBOUND(introRings)
            IF connected(i) THEN
                drawRingAt px(i), py(i), introRings(i).w, introRings(i).text, glowI, true
            ELSE
                drawRingAt px(i), py(i), introRings(i).w, introRings(i).text, 0, true
            END IF
        NEXT

        updateParticles

        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, 4, 6, 0, 255), 0, 255)), BF

        COLOR _RGB32(0)
        centerLarge (_HEIGHT / 2) - fontHeightLarge(2) + 3, "Tic Tac Toe", 2
        centerLarge (_HEIGHT / 2) + 3, "Rings", 7
        centerLarge _HEIGHT - fontHeightLarge(2) + 3, "Fellippe Heitor, 2020-2026", 1

        COLOR _RGB32(255)
        centerLarge (_HEIGHT / 2) - fontHeightLarge(2), "Tic Tac Toe", 2
        centerLarge (_HEIGHT / 2), "Rings", 7
        centerLarge _HEIGHT - fontHeightLarge(2), "Fellippe Heitor, 2020-2026", 1

        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, 0, 1.5, 255, 0), 0, 255)), BF
        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, 4, 5, 0, 255), 0, 255)), BF
        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(0, 0, 0, clampf(map(t, 5, 6, 0, 255), 0, 255)), BF

        WHILE _MOUSEINPUT: WEND
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL t > 6 OR _KEYHIT OR _MOUSEBUTTON(1)
END SUB

SUB generateNewSets
    DIM i AS INTEGER
    DIM j AS INTEGER

    IF gameOver THEN EXIT SUB

    'new sets must be generated according to
    'current board's available positions
    IF peg(10).set + peg(11).set + peg(12).set = emptySet$ + emptySet$ + emptySet$ THEN
        level = level + 1
        IF mode = MODE_NORMAL THEN
            maxColors = map(level, 1, 45, 3, UBOUND(ringColor)) 'as level goes up, add more colors
        ELSEIF mode = MODE_EASIER THEN
            maxColors = map(score, 1, 500, 3, UBOUND(ringColor)) 'as score goes up, add more colors
        END IF
        IF maxColors < 3 THEN maxColors = 3
        IF maxColors > UBOUND(ringColor) THEN maxColors = UBOUND(ringColor)

        DIM pegsUsed AS STRING, thisPeg AS INTEGER, newPeg AS INTEGER
        pegsUsed = ""
        FOR i = 10 TO 12
            'reset this peg
            peg(i).set = emptySet$

            'choose an existing peg randomly
            newPeg = _CEIL(RND * 9)
            thisPeg = newPeg
            DO
                IF INSTR(peg(thisPeg).set, MKI$(-1)) > 0 AND INSTR(pegsUsed, MKI$(thisPeg)) = 0 THEN
                    'found a peg with an empty slot or more
                    EXIT DO
                END IF
                thisPeg = thisPeg + 1
                IF thisPeg > 9 THEN thisPeg = 1
                IF thisPeg = newPeg THEN
                    'full circle
                    thisPeg = 0
                    EXIT DO
                END IF
            LOOP

            'store the chosen peg's id
            IF thisPeg > 0 THEN pegsUsed = pegsUsed + MKI$(thisPeg)

            'generate a set, with random colors
            DO
                FOR j = 1 TO 3
                    IF MID$(peg(thisPeg).set, j * 2 - 1, 2) = MKI$(-1) THEN
                        IF RND * 100 < 30 THEN
                            MID$(peg(i).set, j * 2 - 1, 2) = MKI$(_CEIL(RND * maxColors))
                        END IF
                    END IF
                NEXT
            LOOP WHILE peg(i).set = emptySet$ 'can't be empty
            IF INSTR(peg(i).set, MKI$(-1)) = 0 THEN 'can't be full
                j = _CEIL(RND * 3)
                MID$(peg(i).set, j * 2 - 1, 2) = MKI$(-1)
            END IF
        NEXT
        animation(6).start = clock
    END IF
END SUB

SUB placeRings
    DIM i AS INTEGER, j AS INTEGER, target AS INTEGER, placed AS _BYTE

    target = 0
    FOR i = 1 TO 9
        IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 40 THEN target = i: EXIT FOR
    NEXT

    'check that the chosen peg can hold the current set of rings
    placed = false
    IF target > 0 THEN
        placed = true
        FOR j = 1 TO 3
            IF slotColor(peg(dragging).set, j) > 0 AND slotColor(peg(target).set, j) > 0 THEN
                placed = false
                EXIT FOR
            END IF
        NEXT
    END IF

    IF placed THEN
        playSfx woodblock, 1
        FOR j = 1 TO 3
            IF slotColor(peg(dragging).set, j) > 0 THEN
                MID$(peg(target).set, j * 2 - 1, 2) = MID$(peg(dragging).set, j * 2 - 1, 2)
                addRipple peg(target).x, peg(target).y, slotColor(peg(dragging).set, j)
            END IF
        NEXT
        peg(dragging).set = emptySet$
        disturbParticles peg(target).x, peg(target).y, .5, 150
        stopElectricNow
        checkMatches target
    ELSE
        'misplaced rings bounce back to the spawn area
        returnAnim(dragging).state = true
        returnAnim(dragging).x = _MOUSEX
        returnAnim(dragging).y = _MOUSEY
        returnAnim(dragging).start = clock
        returnAnim(dragging).duration = .4
    END IF
END SUB

SUB checkMatches (target AS INTEGER)
    DIM r(1 TO 3) AS INTEGER, previousScore AS _UNSIGNED LONG, increase AS LONG
    DIM s$, found1 AS INTEGER, found2 AS INTEGER, scored AS _BYTE
    DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, m AS INTEGER, p AS INTEGER, checks AS INTEGER
    DIM nextPeg(0 TO 2) AS INTEGER

    FOR j = 1 TO 9
        'prepare backup copies for deletion tagging
        del(j) = peg(j)
    NEXT

    totalMatches = 0
    previousScore = score

    'look for 3 same-color rings on the target peg --> ((o))
    FOR j = 1 TO 3
        r(j) = slotColor(peg(target).set, j)
    NEXT
    IF r(1) > 0 AND r(1) = r(2) AND r(2) = r(3) THEN
        score = score + 3 * multiplier
        animation(0).start = clock
        animation(5).start = clock
        animation(5).x = peg(target).x
        animation(5).y = peg(target).y
        animation(5).r = _RED32(ringColor(r(1)))
        animation(5).g = _GREEN32(ringColor(r(1)))
        animation(5).b = _BLUE32(ringColor(r(1)))
        animation(8).r = _RED32(ringColor(r(1)))
        animation(8).g = _GREEN32(ringColor(r(1)))
        animation(8).b = _BLUE32(ringColor(r(1)))
        del(target).set = emptySet$
        addParticles peg(target).x, peg(target).y, 70, ringColor(r(1))
        addParticles peg(target).x, peg(target).y, 30, lighter(ringColor(r(1)), 30)
        disturbParticles peg(target).x, peg(target).y, 2, 250
        totalMatches = totalMatches + 1
    END IF

    'look for line matches |, -, /, \
    FOR m = 1 TO 4
        SELECT CASE m
            CASE 1 'across
                checks = 3
                r(1) = 1
                r(2) = 4
                r(3) = 7
                nextPeg(1) = 1
                nextPeg(2) = 2
            CASE 2 'down
                checks = 3
                r(1) = 1
                r(2) = 2
                r(3) = 3
                nextPeg(1) = 3
                nextPeg(2) = 6
            CASE 3 'diagonal \
                checks = 1
                r(1) = 1
                nextPeg(1) = 4
                nextPeg(2) = 8
            CASE 4 'diagonal /
                checks = 1
                r(1) = 3
                nextPeg(1) = 2
                nextPeg(2) = 4
        END SELECT

        FOR i = 1 TO checks
            'look at each ring on the first peg of each row
            FOR j = 1 TO 3
                scored = false
                s$ = MID$(peg(r(i)).set, j * 2 - 1, 2)
                IF s$ = MKI$(-1) THEN _CONTINUE
                found1 = INSTR(peg(r(i) + nextPeg(1)).set, s$)
                found2 = INSTR(peg(r(i) + nextPeg(2)).set, s$)
                IF found1 > 0 AND found2 > 0 THEN
                    'match! clear all rings of the same color in this group of pegs
                    FOR k = 0 TO 2
                        p = r(i) + nextPeg(k)
                        found1 = INSTR(del(p).set, s$)
                        DO WHILE found1
                            MID$(del(p).set, found1, 2) = MKI$(-1)
                            addParticles del(p).x, del(p).y, 23, ringColor(CVI(s$))
                            addParticles del(p).x, del(p).y, 10, lighter(ringColor(CVI(s$)), 30)
                            score = score + multiplier
                            found1 = INSTR(del(p).set, s$)
                        LOOP
                        disturbParticles peg(p).x, peg(p).y, 2.5, 300
                    NEXT
                    scored = true
                    totalMatches = totalMatches + 1
                    animation(0).start = clock
                    animation(m).start = clock
                    animation(m).x = peg(r(i)).x
                    animation(m).y = peg(r(i)).y
                    animation(m).r = _RED32(ringColor(CVI(s$)))
                    animation(m).g = _GREEN32(ringColor(CVI(s$)))
                    animation(m).b = _BLUE32(ringColor(CVI(s$)))
                    animation(8).r = _RED32(ringColor(CVI(s$)))
                    animation(8).g = _GREEN32(ringColor(CVI(s$)))
                    animation(8).b = _BLUE32(ringColor(CVI(s$)))
                END IF

                IF scored THEN MID$(del(r(i)).set, j * 2 - 1, 2) = MKI$(-1)
            NEXT
        NEXT
    NEXT

    FOR j = 1 TO 9
        'perform deletion, if any items were marked = MKI$(-1)
        peg(j) = del(j)
    NEXT

    IF previousScore < score THEN
        increase = score - previousScore
        IF increase > 5 THEN
            'big scores shake the score, flash the screen and, for long combos, zoom in
            scoreShake = increase / 10
            IF scoreShake > 2 THEN scoreShake = 2
            screenFlash = .4
            IF multiplier > 3 THEN screenZoom = 1.05 + (multiplier - 3) * .01
        END IF

        playSfx wooshSound, .5

        multiplier = multiplier + 1

        IF multiplier - 1 <= UBOUND(comboSound) THEN
            playSfx comboSound(multiplier - 1), 1
        ELSE
            playSfx comboSound(UBOUND(comboSound)), 1
        END IF

        m$(1) = megaComboMsg$(_CEIL(RND * UBOUND(megaComboMsg$)))
        m$(2) = LTRIM$(STR$(multiplier)) + "x combo!"
        animation(7).start = clock
        animation(8).start = clock
        animation(8).x = _MOUSEX
        animation(8).y = _MOUSEY
        animation(8).xa = increase
        animation(8).ya = dist(_MOUSEX, _MOUSEY, scoreTargetX, scoreTargetY)
        IF animation(8).ya < 1 THEN animation(8).ya = 1
        animation(8).duration = 5

        addComboBurst _WIDTH / 2, _HEIGHT / 2, 30 + multiplier * 10
    ELSE
        multiplier = 1
    END IF
    IF score > highscore THEN highscore = score
END SUB

FUNCTION movesAvailable%
    'false when the spawn area has sets but none of them fits the board
    DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, fits AS _BYTE, anySpawn AS _BYTE

    movesAvailable% = true
    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN
            anySpawn = true
            FOR j = 1 TO 9
                fits = true
                FOR k = 1 TO 3
                    IF slotColor(peg(i).set, k) > 0 AND slotColor(peg(j).set, k) > 0 THEN
                        fits = false
                        EXIT FOR
                    END IF
                NEXT
                IF fits THEN EXIT FUNCTION
            NEXT
        END IF
    NEXT
    IF anySpawn THEN movesAvailable% = false
END FUNCTION

SUB startGameOver (reason AS INTEGER)
    gameOver = true
    gameOverReason = reason
    gameOverStart = clock
    exploded = false
    dragging = 0
    mouseDown = false
    showTutorial = false
    matchCount = 0
    fadingOut = false
    IF sfxVolume > 0 THEN
        electricVolume = sfxVolume * .5
        electricTarget = electricVolume
    END IF
END SUB

SUB explodeSpawnedRings
    DIM i AS INTEGER, j AS INTEGER, colr AS INTEGER, first AS INTEGER

    exploded = true
    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN
            first = 0
            FOR j = 1 TO 3
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN
                    IF first = 0 THEN first = colr
                    addParticles peg(i).x, peg(i).y, 150, ringColor(colr)
                    addParticles peg(i).x, peg(i).y, 80, lighter(ringColor(colr), 30)
                END IF
            NEXT
            addParticles peg(i).x, peg(i).y, 100, _RGB32(255)
            addRipple peg(i).x, peg(i).y, first
            disturbParticles peg(i).x, peg(i).y, 3, 250
            peg(i).set = emptySet$
            returnAnim(i).state = false
        END IF
    NEXT

    screenFlash = .8
    stopElectricNow
    playSfx wooshSound, .5
END SUB

SUB drawGameOverEffects
    'spawn rings glow, then tremble, before exploding
    DIM t AS SINGLE, i AS INTEGER, j AS INTEGER, k AS INTEGER, colr AS INTEGER
    DIM glowI AS SINGLE, radius AS SINGLE, shake AS SINGLE, x AS SINGLE, y AS SINGLE

    IF gameOver = false OR exploded THEN EXIT SUB

    t = clock - gameOverStart
    IF t < GAME_OVER_GLOW THEN
        glowI = SIN(t / GAME_OVER_GLOW * _PI * 6) * .5 + .5
    ELSE
        glowI = .7 + SIN(t * 10) * .3
        shake = (t - GAME_OVER_GLOW) / GAME_OVER_TREMBLE * 10
    END IF

    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN
            x = peg(i).x + SIN(t * 30 + i) * shake
            y = peg(i).y + COS(t * 39 + i) * shake
            FOR j = 1 TO 3
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN
                    radius = 35 + (3 - j) * 15 + glowI * 5
                    FOR k = 1 TO 8
                        CIRCLE (x, y), radius + k + 1, _RGBA32(255, 255, 255, glowI * 90 * (1 - k / 9))
                        CIRCLE (x, y), radius - k - 2, _RGBA32(255, 255, 255, glowI * 60 * (1 - k / 9))
                    NEXT
                    FOR k = -1 TO 2
                        CIRCLE (x, y), radius + k, _RGBA32(_RED32(ringColor(colr)), _GREEN32(ringColor(colr)), _BLUE32(ringColor(colr)), glowI * 255)
                    NEXT
                END IF
            NEXT
        END IF
    NEXT
END SUB

SUB resetGame
    DIM i AS INTEGER

    restartMusic
    gameOver = false
    gameOverDone = false
    score = 0
    visibleScore = 0
    level = 0
    multiplier = 1
    animation(0).start = clock
    FOR i = 1 TO 12
        peg(i).set = emptySet$
    NEXT
    FOR i = 10 TO 12
        returnAnim(i).state = false
    NEXT
    matchCount = 0
    lastMatchCount = 0
    fadingOut = false
    showTutorial = false
    tutorialTime = 0
    pauseGame = false
END SUB

SUB drawRingAt (x AS SINGLE, y AS SINGLE, slot AS INTEGER, colr AS INTEGER, glow AS SINGLE, withShadow AS _BYTE)
    DIM half AS INTEGER, outerR AS INTEGER, k AS INTEGER, n AS INTEGER
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER

    outerR = slot * 14
    half = outerR + 2
    r = _RED32(ringColor(colr))
    g = _GREEN32(ringColor(colr))
    b = _BLUE32(ringColor(colr))

    IF withShadow THEN _PUTIMAGE (x - half - 4, y - half - 1), ringShadow(slot)

    IF glow > 0 THEN
        'pulsing glow for rings being dragged or about to match
        FOR k = 1 TO 10
            CIRCLE (x, y), outerR + k, _RGBA32(r, g, b, glow * 140 * (1 - k / 11))
        NEXT
        CIRCLE (x, y), outerR + 8 + glow * 12, _RGBA32(r, g, b, (.2 + glow * .2) * 255)
        CIRCLE (x, y), outerR + 9 + glow * 12, _RGBA32(r, g, b, (.2 + glow * .2) * 255)
        _PUTIMAGE (x - half, y - half), circleGlow(colr, slot)
    ELSE
        IF multiplier > 2 THEN
            'neon glow for high multipliers
            n = 4 + multiplier
            IF n > 12 THEN n = 12
            FOR k = 1 TO n
                CIRCLE (x, y), outerR + k, _RGBA32(r, g, b, 90 * (1 - k / (n + 1)))
            NEXT
        END IF
        _PUTIMAGE (x - half, y - half), circleImage(colr, slot)
    END IF
END SUB

SUB drawRings
    DIM i AS INTEGER, j AS INTEGER, colr AS INTEGER
    DIM x AS SINGLE, y AS SINGLE, p AS SINGLE, e AS SINGLE, t AS SINGLE
    DIM glowI AS SINGLE, shake AS SINGLE

    glowI = .5 + SIN(clock / .15) * .3

    IF gameOver AND exploded = false THEN
        t = clock - gameOverStart
        IF t >= GAME_OVER_GLOW THEN shake = (t - GAME_OVER_GLOW) / GAME_OVER_TREMBLE * 10
    END IF

    FOR i = 1 TO 12
        IF i >= 10 THEN
            IF returnAnim(i).state THEN _CONTINUE
        END IF

        IF i = dragging THEN
            x = _MOUSEX
            y = _MOUSEY
        ELSE
            x = peg(i).x
            y = peg(i).y
        END IF

        IF shake > 0 AND i >= 10 THEN
            x = x + SIN(t * 30 + i) * shake
            y = y + COS(t * 39 + i) * shake
        END IF

        FOR j = 3 TO 1 STEP -1
            colr = slotColor(peg(i).set, j)
            IF colr > 0 THEN
                IF i = dragging OR isMatching(i, j) THEN
                    drawRingAt x, y, j, colr, glowI, (i <> dragging)
                ELSE
                    drawRingAt x, y, j, colr, 0, true
                END IF
            END IF
        NEXT
    NEXT

    'rings bouncing back to the spawn area are drawn on top
    FOR i = 10 TO 12
        IF returnAnim(i).state THEN
            p = (clock - returnAnim(i).start) / returnAnim(i).duration
            IF p >= 1 THEN
                returnAnim(i).state = false
                p = 1
            END IF
            e = easeOutCubic(p)
            x = returnAnim(i).x + (peg(i).x - returnAnim(i).x) * e
            y = returnAnim(i).y + (peg(i).y - returnAnim(i).y) * e
            FOR j = 3 TO 1 STEP -1
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN drawRingAt x, y, j, colr, 0, true
            NEXT
        END IF
    NEXT
END SUB

FUNCTION isMatching% (p AS INTEGER, slot AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO matchCount
        IF match(i).peg = p AND match(i).slot = slot THEN isMatching% = true: EXIT FUNCTION
    NEXT
END FUNCTION

SUB computeCombo (target AS INTEGER, drg AS INTEGER)
    'simulates dropping the dragged set on the target peg and lists the rings that would match
    DIM sim(1 TO 9) AS STRING, lines(1 TO 8, 1 TO 3) AS INTEGER
    DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, l AS INTEGER, colr AS INTEGER, hasTarget AS _BYTE

    matchCount = 0
    IF target < 1 OR target > 9 OR drg < 10 OR drg > 12 THEN EXIT SUB

    FOR j = 1 TO 3
        IF slotColor(peg(drg).set, j) > 0 AND slotColor(peg(target).set, j) > 0 THEN EXIT SUB
    NEXT

    FOR i = 1 TO 9
        sim(i) = peg(i).set
    NEXT
    FOR j = 1 TO 3
        IF slotColor(peg(drg).set, j) > 0 THEN MID$(sim(target), j * 2 - 1, 2) = MID$(peg(drg).set, j * 2 - 1, 2)
    NEXT

    'three rings of the same color on one peg
    IF slotColor(sim(target), 1) > 0 AND slotColor(sim(target), 1) = slotColor(sim(target), 2) AND slotColor(sim(target), 2) = slotColor(sim(target), 3) THEN
        FOR j = 1 TO 3
            addMatch target, j, slotColor(sim(target), j)
        NEXT
    END IF

    'rows, columns and diagonals going through the target peg
    RESTORE comboLines
    FOR l = 1 TO 8
        FOR k = 1 TO 3
            READ lines(l, k)
        NEXT
    NEXT
    comboLines:
    DATA 1,2,3,4,5,6,7,8,9,1,4,7,2,5,8,3,6,9,1,5,9,3,5,7

    FOR l = 1 TO 8
        hasTarget = false
        FOR k = 1 TO 3
            IF lines(l, k) = target THEN hasTarget = true
        NEXT
        IF hasTarget THEN
            FOR j = 1 TO 3
                colr = slotColor(sim(lines(l, 1)), j)
                IF colr > 0 THEN
                    IF INSTR(sim(lines(l, 2)), MKI$(colr)) > 0 AND INSTR(sim(lines(l, 3)), MKI$(colr)) > 0 THEN
                        FOR k = 1 TO 3
                            FOR i = 1 TO 3
                                IF slotColor(sim(lines(l, k)), i) = colr THEN addMatch lines(l, k), i, colr
                            NEXT
                        NEXT
                    END IF
                END IF
            NEXT
        END IF
    NEXT
END SUB

SUB addMatch (p AS INTEGER, slot AS INTEGER, colr AS INTEGER)
    DIM i AS INTEGER
    IF matchCount >= MAX_MATCHES THEN EXIT SUB
    FOR i = 1 TO matchCount
        IF match(i).peg = p AND match(i).slot = slot THEN EXIT SUB
    NEXT
    matchCount = matchCount + 1
    match(matchCount).peg = p
    match(matchCount).slot = slot
    match(matchCount).colr = colr
END SUB

SUB updateElectric
    'track which rings would match if the dragged set were dropped where it is now
    DIM i AS INTEGER, found AS INTEGER, prevCount AS INTEGER, changed AS _BYTE, d AS SINGLE
    DIM oldMatch(1 TO MAX_MATCHES) AS matchType

    prevCount = matchCount
    FOR i = 1 TO prevCount
        oldMatch(i) = match(i)
    NEXT

    found = 0
    IF dragging > 0 AND electricConnections AND gameOver = false THEN
        FOR i = 1 TO 9
            IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 40 THEN found = i: EXIT FOR
        NEXT
    END IF

    matchCount = 0
    IF found > 0 THEN computeCombo found, dragging

    IF matchCount > 0 THEN
        fadingOut = false
        changed = (matchCount <> prevCount)
        IF changed = false THEN
            FOR i = 1 TO matchCount
                IF match(i).peg <> oldMatch(i).peg OR match(i).slot <> oldMatch(i).slot OR match(i).colr <> oldMatch(i).colr THEN changed = true: EXIT FOR
            NEXT
        END IF
        IF changed THEN matchStart = clock
        matchTarget = found

        d = dist(_MOUSEX, _MOUSEY, peg(found).x, peg(found).y)
        IF (clampf(1 - d / 300, 0, 1) ^ 2) > .3 AND sfxVolume > 0 THEN electricTarget = sfxVolume * .3
    ELSE
        IF prevCount > 0 AND fadingOut = false THEN
            fadingOut = true
            fadeOutStart = clock
            FOR i = 1 TO prevCount
                lastMatch(i) = oldMatch(i)
            NEXT
            lastMatchCount = prevCount
            lastMatchTarget = matchTarget
            lastMatchDrag = dragging
        END IF
        electricTarget = 0
    END IF

    IF gameOver AND exploded = false THEN electricTarget = sfxVolume * .5
END SUB

SUB updateElectricSound
    'fade the electric buzz in and out
    IF electricSound = 0 THEN EXIT SUB

    IF electricVolume < electricTarget THEN
        electricVolume = electricVolume + frameDt * 1.5
        IF electricVolume > electricTarget THEN electricVolume = electricTarget
    ELSEIF electricVolume > electricTarget THEN
        electricVolume = electricVolume - frameDt * 2
        IF electricVolume < electricTarget THEN electricVolume = electricTarget
    END IF

    IF electricVolume > 0 THEN
        IF NOT _SNDPLAYING(electricSound) THEN _SNDLOOP electricSound
        _SNDVOL electricSound, electricVolume
    ELSE
        IF _SNDPLAYING(electricSound) THEN _SNDSTOP electricSound
    END IF
END SUB

SUB stopElectricNow
    electricVolume = 0
    electricTarget = 0
    IF electricSound > 0 THEN
        IF _SNDPLAYING(electricSound) THEN _SNDSTOP electricSound
    END IF
END SUB

SUB getMatchPos (mt AS matchType, target AS INTEGER, drg AS INTEGER, x AS SINGLE, y AS SINGLE, isDragged AS _BYTE)
    'rings coming from the dragged set are drawn at the mouse position
    isDragged = false
    x = peg(mt.peg).x
    y = peg(mt.peg).y
    IF drg >= 10 AND mt.peg = target THEN
        IF slotColor(peg(drg).set, mt.slot) > 0 THEN
            x = _MOUSEX
            y = _MOUSEY
            isDragged = true
        END IF
    END IF
END SUB

SUB drawElectricConnections
    DIM fadeAlpha AS SINGLE, intensity AS SINGLE

    IF matchCount > 0 THEN
        fadeAlpha = clampf((clock - matchStart) / ELECTRIC_FADE_IN, 0, 1)
        intensity = clampf(1 - dist(_MOUSEX, _MOUSEY, peg(matchTarget).x, peg(matchTarget).y) / 300, 0, 1) ^ 2
        drawBolts match(), matchCount, matchTarget, dragging, intensity, fadeAlpha, false
    ELSEIF fadingOut THEN
        fadeAlpha = 1 - (clock - fadeOutStart) / ELECTRIC_FADE_OUT
        IF fadeAlpha <= 0 THEN
            fadingOut = false
            lastMatchCount = 0
            EXIT SUB
        END IF
        drawBolts lastMatch(), lastMatchCount, lastMatchTarget, lastMatchDrag, 1, fadeAlpha, true
    END IF
END SUB

SUB drawBolts (mlist() AS matchType, count AS INTEGER, target AS INTEGER, drg AS INTEGER, intensity AS SINGLE, alphaMul AS SINGLE, fixedStyle AS _BYTE)
    'lightning between every pair of matching rings of the same color
    DIM a AS INTEGER, b AS INTEGER, bolt AS INTEGER, bolts AS INTEGER, segs AS INTEGER
    DIM x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, d1 AS _BYTE, d2 AS _BYTE
    DIM opacity AS SINGLE, w AS SINGLE, jit AS SINGLE

    FOR a = 1 TO count - 1
        FOR b = a + 1 TO count
            IF mlist(a).colr = mlist(b).colr THEN
                getMatchPos mlist(a), target, drg, x1, y1, d1
                getMatchPos mlist(b), target, drg, x2, y2, d2
                IF dist(x1, y1, x2, y2) >= 2 THEN
                    IF fixedStyle THEN
                        bolts = 2: opacity = .6: w = 2: segs = 6: jit = 15
                    ELSEIF d1 OR d2 THEN
                        bolts = INT(1 + intensity * 4)
                        opacity = .3 + intensity * .7
                        w = 1 + intensity * 3
                        segs = INT(4 + intensity * 4)
                        jit = 15 + intensity * 15
                    ELSE
                        bolts = 2: opacity = .6: w = 2: segs = 6: jit = 15 + intensity * 15
                    END IF
                    FOR bolt = 1 TO bolts
                        drawBolt x1, y1, x2, y2, segs, jit, w + RND, (opacity + RND * .2) * alphaMul
                    NEXT
                END IF
            END IF
        NEXT
    NEXT
END SUB

SUB drawBolt (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, segments AS INTEGER, jitter AS SINGLE, w AS SINGLE, alpha AS SINGLE)
    'one jagged lightning bolt with a soft glow
    DIM px(0 TO 16) AS SINGLE, py(0 TO 16) AS SINGLE
    DIM s AS INTEGER, n AS INTEGER, t AS SINGLE, ang AS SINGLE, nx AS SINGLE, ny AS SINGLE, j AS SINGLE, a AS SINGLE

    n = segments
    IF n > 16 THEN n = 16
    IF n < 1 THEN n = 1
    a = clampf(alpha, 0, 1) * 255

    ang = _ATAN2(y2 - y1, x2 - x1)
    nx = COS(ang + _PI / 2)
    ny = SIN(ang + _PI / 2)
    px(0) = x1
    py(0) = y1
    FOR s = 1 TO n
        t = s / n
        j = (RND - .5) * jitter * SIN(t * _PI)
        px(s) = x1 + (x2 - x1) * t + nx * j
        py(s) = y1 + (y2 - y1) * t + ny * j
    NEXT

    FOR s = 1 TO n
        thickLine px(s - 1), py(s - 1), px(s), py(s), w + 6, _RGBA32(150, 220, 255, a * .18)
    NEXT
    FOR s = 1 TO n
        thickLine px(s - 1), py(s - 1), px(s), py(s), w, _RGBA32(150, 220, 255, a)
    NEXT
    FOR s = 1 TO n
        LINE (px(s - 1), py(s - 1))-(px(s), py(s)), _RGBA32(255, 255, 255, a * .7)
    NEXT
END SUB

SUB generateSparkles
    DIM i AS INTEGER, k AS INTEGER, n AS INTEGER, s AS INTEGER, fadeIn AS SINGLE
    DIM x AS SINGLE, y AS SINGLE, a AS SINGLE, radius AS SINGLE, isDragged AS _BYTE

    IF matchCount = 0 OR electricConnections = false OR fadingOut THEN EXIT SUB
    IF countSparkles > 50 THEN EXIT SUB

    fadeIn = clampf((clock - matchStart) / ELECTRIC_FADE_IN, 0, 1)
    IF RND >= .15 * fadeIn THEN EXIT SUB

    FOR i = 1 TO matchCount
        getMatchPos match(i), matchTarget, dragging, x, y, isDragged
        n = INT(RND * 2) + 1
        FOR k = 1 TO n
            FOR s = 1 TO UBOUND(sparkle)
                IF sparkle(s).state = false THEN
                    a = RND * _PI(2)
                    radius = 20 + RND * 25
                    sparkle(s).state = true
                    sparkle(s).x = x + COS(a) * radius
                    sparkle(s).y = y + SIN(a) * radius
                    sparkle(s).xv = (RND - .5) * 4
                    sparkle(s).yv = -RND * 4 - 2
                    sparkle(s).life = 1
                    sparkle(s).size = RND * .8 + .4
                    sparkle(s).c = ringColor(match(i).colr)
                    EXIT FOR
                END IF
            NEXT
        NEXT
    NEXT
END SUB

FUNCTION countSparkles%
    DIM i AS INTEGER, n AS INTEGER
    FOR i = 1 TO UBOUND(sparkle)
        IF sparkle(i).state THEN n = n + 1
    NEXT
    countSparkles% = n
END FUNCTION

SUB updateSparkles
    DIM i AS INTEGER, a AS SINGLE, sz AS SINGLE
    FOR i = 1 TO UBOUND(sparkle)
        IF sparkle(i).state THEN
            sparkle(i).x = sparkle(i).x + sparkle(i).xv
            sparkle(i).y = sparkle(i).y + sparkle(i).yv
            sparkle(i).life = sparkle(i).life - .04
            IF sparkle(i).life <= 0 THEN
                sparkle(i).state = false
            ELSE
                a = sparkle(i).life * .9 * 255
                sz = sparkle(i).size * sparkle(i).life * 3
                CircleFill sparkle(i).x, sparkle(i).y, sz, _RGBA32(_RED32(sparkle(i).c), _GREEN32(sparkle(i).c), _BLUE32(sparkle(i).c), a)
                CircleFill sparkle(i).x, sparkle(i).y, sz * .4, _RGBA32(255, 255, 255, a * .6)
            END IF
        END IF
    NEXT
END SUB

SUB addRipple (x AS SINGLE, y AS SINGLE, colr AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(ripple)
        IF ripple(i).state = false THEN
            ripple(i).state = true
            ripple(i).x = x
            ripple(i).y = y
            ripple(i).radius = 0
            ripple(i).life = 1
            IF colr > 0 THEN ripple(i).c = ringColor(colr) ELSE ripple(i).c = _RGB32(255)
            EXIT SUB
        END IF
    NEXT
END SUB

SUB updateRipples
    DIM i AS INTEGER, a AS SINGLE, r AS INTEGER, g AS INTEGER, b AS INTEGER
    FOR i = 1 TO UBOUND(ripple)
        IF ripple(i).state THEN
            ripple(i).radius = ripple(i).radius + 4
            ripple(i).life = ripple(i).life - .02
            IF ripple(i).life <= 0 OR ripple(i).radius > 80 THEN
                ripple(i).state = false
            ELSE
                r = _RED32(ripple(i).c): g = _GREEN32(ripple(i).c): b = _BLUE32(ripple(i).c)
                a = ripple(i).life * 255
                CIRCLE (ripple(i).x, ripple(i).y), ripple(i).radius - 1, _RGBA32(r, g, b, a)
                CIRCLE (ripple(i).x, ripple(i).y), ripple(i).radius, _RGBA32(r, g, b, a)
                CIRCLE (ripple(i).x, ripple(i).y), ripple(i).radius + 1, _RGBA32(r, g, b, a)
                CIRCLE (ripple(i).x, ripple(i).y), ripple(i).radius + 3, _RGBA32(r, g, b, a * .3)
                CIRCLE (ripple(i).x, ripple(i).y), ripple(i).radius * .7, _RGBA32(r, g, b, a * .5)
            END IF
        END IF
    NEXT
END SUB

SUB doAnimations
    DIM i AS INTEGER, j AS SINGLE, k AS SINGLE, o AS SINGLE, now AS DOUBLE
    DIM p AS SINGLE, animSize AS SINGLE, slope AS SINGLE, maxDim AS SINGLE, col AS _UNSIGNED LONG
    DIM tt AS SINGLE, scale AS SINGLE, alpha AS SINGLE, yOff AS SINGLE, bounce AS SINGLE
    DIM a AS SINGLE, tx AS SINGLE, ty AS SINGLE, cy AS SINGLE

    now = clock
    FOR i = 0 TO UBOUND(animation)
        IF animation(i).start > 0 AND now - animation(i).start <= animation(i).duration THEN
            p = (now - animation(i).start) / animation(i).duration
            animSize = map(p, 0, 1, 50, 0)
            col = _RGBA32(animation(i).r, animation(i).g, animation(i).b, 20)
            SELECT CASE i
                CASE 0 'board flash
                    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(p, 0, 1, 100, 0)), BF
                CASE 1 'across
                    FOR j = 0 TO _WIDTH STEP _WIDTH / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill j, animation(i).y, k, col
                        NEXT
                    NEXT
                CASE 2 'down
                    FOR j = 0 TO _HEIGHT STEP _HEIGHT / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill animation(i).x, j, k, col
                        NEXT
                    NEXT
                CASE 3, 4 'diagonals, through the center peg
                    IF i = 3 THEN
                        slope = (peg(9).y - peg(1).y) / (peg(9).x - peg(1).x)
                    ELSE
                        slope = (peg(7).y - peg(3).y) / (peg(7).x - peg(3).x)
                    END IF
                    maxDim = _WIDTH
                    IF _HEIGHT > maxDim THEN maxDim = _HEIGHT
                    FOR o = -maxDim TO maxDim STEP maxDim / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill peg(5).x + o, peg(5).y + o * slope, k, col
                        NEXT
                    NEXT
                CASE 5 'single peg ((o))
                    FOR k = 1 TO animSize * 2
                        CircleFill animation(i).x, animation(i).y, k, col
                    NEXT
                CASE 6 'new peg set
                    FOR k = 10 TO 12
                        CIRCLE (peg(k).x, peg(k).y), animSize * 1.5, _RGBA32(255, 255, 255, animSize / 2)
                        CIRCLE (peg(k).x, peg(k).y), animSize, _RGBA32(255, 255, 255, animSize)
                    NEXT
                CASE 7 'combo info: bounce in, hold, fade out
                    IF p < .3 THEN
                        tt = p / .3
                        bounce = SIN(tt * _PI * 2) * (1 - tt) * .3
                        scale = easeOutCubic(tt) * (1 + bounce)
                        alpha = easeOutCubic(tt)
                        yOff = (1 - easeOutCubic(tt)) * -50
                    ELSEIF p > .7 THEN
                        tt = (p - .7) / .3
                        scale = 1 - tt * .5
                        alpha = 1 - easeOutCubic(tt)
                        yOff = -tt * 30
                    ELSE
                        tt = (p - .3) / .4
                        scale = 1 + SIN(tt * _PI * 4) * .05
                        alpha = 1
                        yOff = 0
                    END IF
                    cy = _HEIGHT / 2 + yOff
                    IF totalMatches > 1 THEN
                        drawScaledText m$(1), _WIDTH / 2, cy - 26, 2, scale * 1.15, _RGBA32(255, 255, 255, alpha * 255), _RGBA32(255, 85, 0, alpha * 200), 0
                        drawScaledText m$(2), _WIDTH / 2, cy + 22, 3, scale, _RGBA32(255, 255, 0, alpha * 255), _RGBA32(255, 0, 0, alpha * 200), 0
                    ELSE
                        drawScaledText m$(2), _WIDTH / 2, cy, 3, scale, _RGBA32(255, 255, 0, alpha * 255), _RGBA32(255, 0, 0, alpha * 200), 0
                    END IF
                CASE 8 'score increase
                    tx = scoreTargetX
                    ty = scoreTargetY
                    animation(8).x = lerp(animation(8).x, tx, .06)
                    animation(8).y = lerp(animation(8).y, ty, .06)
                    a = dist(animation(8).x, animation(8).y, tx, ty)
                    IF a <= 30 THEN
                        animation(8).start = 0
                    END IF
                    a = clampf(map(a, 0, animation(8).ya, 0, 1024), 0, 255)
                    COLOR _RGBA32(animation(8).r, animation(8).g, animation(8).b, a)
                    printLarge 2 + animation(8).x, 2 + animation(8).y, LTRIM$(STR$(animation(8).xa)), 4
                    COLOR _RGBA32(255, 255, 255, a)
                    printLarge animation(8).x, animation(8).y, LTRIM$(STR$(animation(8).xa)), 4
            END SELECT
        END IF
    NEXT
END SUB

FUNCTION scoreFlying%
    scoreFlying% = (animation(8).start > 0 AND clock - animation(8).start <= animation(8).duration)
END FUNCTION

FUNCTION scoreTargetX!
    scoreTargetX! = 22 + printWidthLarge(LTRIM$(STR$(INT(visibleScore))), 3) / 2
END FUNCTION

FUNCTION scoreTargetY!
    scoreTargetY! = 111
END FUNCTION

SUB drawHUD
    DIM t AS DOUBLE, glow AS SINGLE, k AS INTEGER, s$, sx AS SINGLE, sy AS SINGLE, pulse AS SINGLE

    t = clock

    'high score panel
    glow = SIN(t / .5) * .3 + .7
    FOR k = 1 TO 5
        roundRectLine 15 - k, 15 - k, 200 + k * 2, 50 + k * 2, 8 + k, _RGBA32(255, 215, 0, 40 * glow * (1 - k / 6))
    NEXT
    roundRectFill 15, 15, 200, 50, 8, _RGBA32(255, 215, 0, 38), _RGBA32(184, 134, 11, 26)
    roundRectLine 15, 15, 200, 50, 8, _RGBA32(255, 215, 0, 102)
    roundRectLine 16, 16, 198, 48, 7, _RGBA32(255, 215, 0, 102)
    _PUTIMAGE (22, 33), crownIcon

    _FONT 8
    COLOR _RGBA32(255, 215, 0, 180)
    _PRINTSTRING (56, 24), "HIGH SCORE"
    _FONT 16
    COLOR _RGB32(255, 215, 0)
    _PRINTSTRING (56, 40), LTRIM$(STR$(INT(visibleHighScore)))

    'score panel
    FOR k = 1 TO 5
        roundRectLine 10 - k, 80 - k, 280 + k * 2, 120 + k * 2, 12 + k, _RGBA32(100, 150, 255, 25 * (1 - k / 6))
    NEXT
    roundRectFill 10, 80, 280, 120, 12, _RGBA32(30, 50, 100, 77), _RGBA32(20, 30, 60, 51)
    roundRectLine 10, 80, 280, 120, 12, _RGBA32(100, 150, 255, 128)
    roundRectLine 11, 81, 278, 118, 11, _RGBA32(100, 150, 255, 128)

    _FONT 8
    COLOR _RGBA32(150, 200, 255, 230)
    _PRINTSTRING (22, 92), "SCORE"
    _FONT 16

    'score shakes when increasing
    s$ = LTRIM$(STR$(INT(visibleScore)))
    sx = 22 + (RND * scoreShake * 4 - scoreShake * 2)
    sy = 111 + (RND * scoreShake * 4 - scoreShake * 2)
    COLOR _RGBA32(0, 255, 255, clampf(40 + scoreShake * 40, 0, 255))
    printLarge sx - 2, sy, s$, 3
    printLarge sx + 2, sy, s$, 3
    printLarge sx, sy - 2, s$, 3
    printLarge sx, sy + 2, s$, 3
    COLOR _RGB32(255)
    printLarge sx, sy, s$, 3

    'multiplier with pulse animation
    IF multiplier > 1 THEN
        pulse = SIN(t / .2) * .15 + 1
        drawScaledText "x" + LTRIM$(STR$(multiplier)) + " COMBO!", 22, 177, 1, 1.25 * pulse, _RGB32(255, 85, 85), _RGBA32(255, 0, 0, 150), 1
    END IF

    doButtons
END SUB

SUB drawTutorial
    DIM i AS INTEGER, target AS INTEGER, ax AS SINGLE, ay AS SINGLE

    IF showTutorial = false OR gameOver THEN EXIT SUB

    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN target = i: EXIT FOR
    NEXT
    IF target = 0 THEN EXIT SUB

    'bouncing arrow pointing at the spawn area
    ax = peg(target).x
    ay = peg(target).y - 80 + SIN(clock / .5) * 10
    thickLine ax, ay, ax, ay + 30, 10, _RGBA32(255, 255, 100, 50)
    thickLine ax, ay, ax, ay + 30, 4, _RGBA32(255, 255, 100, 230)
    fillTriangle ax, ay + 30, ax - 10, ay + 15, ax + 10, ay + 15, _RGBA32(255, 255, 100, 230)

    outlinedText "Drag these rings", ax, ay - 30
    outlinedText "to the board", ax, ay - 10
END SUB

SUB outlinedText (text$, cx AS SINGLE, cy AS SINGLE)
    DIM x AS SINGLE, y AS SINGLE, ox AS INTEGER, oy AS INTEGER

    x = cx - _PRINTWIDTH(text$) / 2
    y = cy - _FONTHEIGHT / 2
    COLOR _RGBA32(0, 0, 0, 200)
    FOR oy = -2 TO 2 STEP 2
        FOR ox = -2 TO 2 STEP 2
            IF ox <> 0 OR oy <> 0 THEN _PRINTSTRING (x + ox, y + oy), text$
        NEXT
    NEXT
    COLOR _RGB32(255)
    _PRINTSTRING (x, y), text$
END SUB

SUB drawPauseOverlay
    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(0, 0, 0, 153), BF
    COLOR _RGBA32(255, 255, 255, 50)
    centerLarge _HEIGHT / 2 - 62 - 3, "PAUSED", 4
    centerLarge _HEIGHT / 2 - 62 + 3, "PAUSED", 4
    COLOR _RGB32(255)
    centerLarge _HEIGHT / 2 - 62, "PAUSED", 4
    drawScaledText "Click to continue", _WIDTH / 2, _HEIGHT / 2 + 30, 1, 1.5, _RGB32(255), _RGBA32(255, 255, 255, 60), 0
END SUB

SUB applyScreenZoom
    DIM img AS LONG, w AS SINGLE, h AS SINGLE

    IF screenZoom <= 1.001 THEN EXIT SUB
    img = _COPYIMAGE(_DISPLAY)
    w = _WIDTH * screenZoom
    h = _HEIGHT * screenZoom
    _DONTBLEND
    _PUTIMAGE ((_WIDTH - w) / 2, (_HEIGHT - h) / 2)-STEP(w, h), img
    _BLEND
    _FREEIMAGE img
END SUB

SUB drawScaledText (text$, x AS SINGLE, y AS SINGLE, fontSize AS INTEGER, scale AS SINGLE, col AS _UNSIGNED LONG, shadowCol AS _UNSIGNED LONG, align AS INTEGER)
    'printLarge into a temporary image, then scale it; align 0 = centered, 1 = x is the left edge
    DIM w AS INTEGER, h AS INTEGER, shadowOff AS INTEGER, img AS LONG, prevDest AS LONG
    DIM sw AS SINGLE, sh AS SINGLE

    IF scale <= .01 OR LEN(text$) = 0 THEN EXIT SUB
    shadowOff = fontSize
    IF shadowOff > 3 THEN shadowOff = 3
    w = printWidthLarge(text$, fontSize) + shadowOff
    h = fontHeightLarge(fontSize) + shadowOff

    prevDest = _DEST
    img = _NEWIMAGE(w, h, 32)
    _DEST img
    _PRINTMODE _KEEPBACKGROUND
    IF _ALPHA32(shadowCol) > 0 THEN
        COLOR shadowCol
        printLarge shadowOff, shadowOff, text$, fontSize
    END IF
    COLOR col
    printLarge 0, 0, text$, fontSize
    _DEST prevDest

    sw = w * scale
    sh = h * scale
    IF align = 0 THEN
        _PUTIMAGE (x - sw / 2, y - sh / 2)-STEP(sw, sh), img
    ELSE
        _PUTIMAGE (x, y - sh / 2)-STEP(sw, sh), img
    END IF
    _FREEIMAGE img
END SUB

SUB saveGame
    DIM i AS INTEGER, signature AS STRING, a$, crctest AS STRING, l%

    IF _FILEEXISTS("tictactoering.dat") THEN KILL "tictactoering.dat"
    OPEN "tictactoering.dat" FOR BINARY AS #1
    signature = "tttrng2"
    PUT #1, 1, signature
    PUT #1, , musicVolume
    PUT #1, , sfxVolume
    PUT #1, , prevMusicVolume
    PUT #1, , prevSfxVolume
    PUT #1, , electricConnections
    PUT #1, , score
    PUT #1, , highscore
    PUT #1, , level
    PUT #1, , gameOver
    IF gameOver = false THEN
        FOR i = 1 TO 12
            PUT #1, , peg(i).set
        NEXT
    END IF
    PUT #1, , mode
    CLOSE #1

    'save crc
    OPEN "tictactoering.dat" FOR BINARY AS #1
    a$ = SPACE$(LOF(1))
    GET #1, 1, a$

    crctest = _DEFLATE$(LTRIM$(STR$(crc32(a$))))
    l% = LEN(crctest)
    PUT #1, , l%
    PUT #1, , crctest
    CLOSE #1
END SUB

SUB loadGame
    DIM i AS INTEGER, signature AS STRING, a$, crctest AS STRING, l%
    DIM legacyMusic AS _BYTE, legacySfx AS _BYTE, legacyPeg AS object

    OPEN "tictactoering.dat" FOR BINARY AS #1
    IF LOF(1) THEN
        signature = SPACE$(7)
        GET #1, 1, signature
        IF signature = "tttring" THEN
            'save file from version 1.1 or earlier: music/sfx were just on/off
            GET #1, , legacyMusic
            GET #1, , legacySfx
            IF legacyMusic THEN musicVolume = .7 ELSE musicVolume = 0
            IF legacySfx THEN sfxVolume = .7 ELSE sfxVolume = 0
        ELSEIF signature = "tttrng2" THEN
            GET #1, , musicVolume
            GET #1, , sfxVolume
            GET #1, , prevMusicVolume
            GET #1, , prevSfxVolume
            GET #1, , electricConnections
        ELSE
            CLOSE #1
            EXIT SUB
        END IF
        GET #1, , score
        GET #1, , highscore
        GET #1, , level
        GET #1, , gameOver

        IF gameOver = false THEN
            FOR i = 1 TO 12
                IF signature = "tttring" THEN
                    GET #1, , legacyPeg
                    peg(i).set = legacyPeg.set
                ELSE
                    GET #1, , peg(i).set
                END IF
            NEXT
            GET #1, , mode
        ELSE
            GET #1, , mode
            gameOver = false
            score = 0
            level = 0
        END IF

        'test crc
        GET #1, , l%
        CLOSE #1

        OPEN "tictactoering.dat" FOR BINARY AS #1
        a$ = SPACE$(LOF(1))
        GET #1, 1, a$
        CLOSE #1

        crctest = _DEFLATE$(LTRIM$(STR$(crc32(LEFT$(a$, LEN(a$) - (l% + 2))))))
        IF crctest <> RIGHT$(a$, l%) THEN
            'crc failed - data file has been tampered with
            KILL "tictactoering.dat"
            musicVolume = .7
            sfxVolume = .7
            prevMusicVolume = .7
            prevSfxVolume = .7
            electricConnections = true
            score = 0
            highscore = 0
            level = 0
            gameOver = false
            mode = MODE_NORMAL
            FOR i = 1 TO 12
                peg(i).set = peg(0).set
            NEXT
            EXIT SUB
        END IF
    END IF
    CLOSE #1
END SUB

FUNCTION crc32~& (buf AS STRING)
    'adapted from https://rosettacode.org/wiki/CRC-32
    STATIC table(255) AS _UNSIGNED LONG
    STATIC have_table AS _BYTE
    DIM crc AS _UNSIGNED LONG, k AS _UNSIGNED LONG
    DIM i AS LONG, j AS LONG

    IF have_table = 0 THEN
        FOR i = 0 TO 255
            k = i
            FOR j = 0 TO 7
                IF (k AND 1) THEN
                    k = _SHR(k, 1)
                    k = k XOR &HEDB88320
                ELSE
                    k = _SHR(k, 1)
                END IF
                table(i) = k
            NEXT
        NEXT
        have_table = -1
    END IF

    crc = NOT crc ' crc = &Hffffffff

    FOR i = 1 TO LEN(buf)
        crc = (_SHR(crc, 8)) XOR table((crc AND &HFF) XOR ASC(buf, i))
    NEXT

    crc32~& = NOT crc
END FUNCTION

SUB addParticles (x AS SINGLE, y AS SINGLE, total AS INTEGER, c AS _UNSIGNED LONG)
    DIM addedP AS INTEGER, p AS INTEGER
    DIM a AS SINGLE

    addedP = 0: p = 0
    DO
        p = p + 1
        IF p > UBOUND(particle) THEN EXIT DO
        IF particle(p).state = true THEN _CONTINUE
        addedP = addedP + 1
        particle(p).state = true
        particle(p).shape = 0
        particle(p).x = x
        particle(p).y = y
        a = RND * _PI(2)
        particle(p).xv = COS(a) * (RND * 10)
        particle(p).yv = SIN(a) * (RND * 10)
        particle(p).c = c
        particle(p).size = _CEIL(RND * 3)
        particle(p).start = clock
        particle(p).duration = RND
    LOOP UNTIL addedP >= total
END SUB

SUB addComboBurst (x AS SINGLE, y AS SINGLE, total AS INTEGER)
    'shaped particles (circles, stars, squares, triangles) bursting from the center
    DIM addedP AS INTEGER, p AS INTEGER

    FOR p = 1 TO UBOUND(particle)
        IF addedP >= total THEN EXIT FOR
        IF particle(p).state = false THEN
            addedP = addedP + 1
            particle(p).state = true
            particle(p).x = x
            particle(p).y = y
            particle(p).xv = (RND - .5) * 12
            particle(p).yv = (RND - .5) * 12 - 3
            particle(p).life = 1
            particle(p).decay = .015 + RND * .015
            particle(p).size = 3 + RND * 5
            particle(p).rotation = RND * _PI(2)
            particle(p).rotationSpeed = (RND - .5) * .3
            particle(p).shape = INT(RND * 4) + 1
            SELECT CASE INT(RND * 6)
                CASE 0: particle(p).c = _RGB32(255, 85, 0)
                CASE 1: particle(p).c = _RGB32(255, 136, 0)
                CASE 2: particle(p).c = _RGB32(255, 170, 0)
                CASE 3: particle(p).c = _RGB32(255, 255, 0)
                CASE 4: particle(p).c = _RGB32(255, 0, 0)
                CASE ELSE: particle(p).c = _RGB32(255, 51, 51)
            END SELECT
        END IF
    NEXT
END SUB

SUB updateParticles
    DIM i AS INTEGER, a AS SINGLE, now AS DOUBLE

    now = clock
    FOR i = 1 TO UBOUND(particle)
        CONST gravity = .1
        IF particle(i).state THEN
            IF particle(i).shape = 0 THEN
                particle(i).yv = particle(i).yv + gravity
                particle(i).x = particle(i).x + particle(i).xv
                particle(i).y = particle(i).y + particle(i).yv
                a = map(now - particle(i).start, 0, particle(i).duration, 255, 0)

                IF particle(i).x > _WIDTH OR particle(i).x < 0 OR particle(i).y > _HEIGHT OR particle(i).y < 0 OR a <= 0 THEN
                    particle(i).state = false
                ELSE
                    CircleFill particle(i).x, particle(i).y, particle(i).size, _RGBA32(_RED32(particle(i).c), _GREEN32(particle(i).c), _BLUE32(particle(i).c), a)
                END IF
            ELSE
                particle(i).x = particle(i).x + particle(i).xv
                particle(i).y = particle(i).y + particle(i).yv
                particle(i).yv = particle(i).yv + .2
                particle(i).rotation = particle(i).rotation + particle(i).rotationSpeed
                particle(i).life = particle(i).life - particle(i).decay
                IF particle(i).life <= 0 OR particle(i).y > _HEIGHT + 20 THEN
                    particle(i).state = false
                ELSE
                    drawShapedParticle i
                END IF
            END IF
        END IF
    NEXT
END SUB

SUB drawShapedParticle (i AS INTEGER)
    DIM x AS SINGLE, y AS SINGLE, s AS SINGLE, r AS SINGLE, col AS _UNSIGNED LONG, k AS INTEGER
    DIM ax(1 TO 4) AS SINGLE, ay(1 TO 4) AS SINGLE

    x = particle(i).x
    y = particle(i).y
    s = particle(i).size
    r = particle(i).rotation
    col = _RGBA32(_RED32(particle(i).c), _GREEN32(particle(i).c), _BLUE32(particle(i).c), particle(i).life * 255)

    SELECT CASE particle(i).shape
        CASE 1 'circle
            CircleFill x, y, s, col
        CASE 2 'star
            FOR k = 1 TO 3
                ax(k) = x + COS(r + k * _PI(2) / 3) * s
                ay(k) = y + SIN(r + k * _PI(2) / 3) * s
            NEXT
            fillTriangle ax(1), ay(1), ax(2), ay(2), ax(3), ay(3), col
            FOR k = 1 TO 3
                ax(k) = x + COS(r + _PI / 3 + k * _PI(2) / 3) * s
                ay(k) = y + SIN(r + _PI / 3 + k * _PI(2) / 3) * s
            NEXT
            fillTriangle ax(1), ay(1), ax(2), ay(2), ax(3), ay(3), col
        CASE 3 'square
            FOR k = 1 TO 4
                ax(k) = x + COS(r + _PI / 4 + k * _PI / 2) * s * .707
                ay(k) = y + SIN(r + _PI / 4 + k * _PI / 2) * s * .707
            NEXT
            fillTriangle ax(1), ay(1), ax(2), ay(2), ax(3), ay(3), col
            fillTriangle ax(1), ay(1), ax(3), ay(3), ax(4), ay(4), col
        CASE 4 'triangle
            FOR k = 1 TO 3
                ax(k) = x + COS(r - _PI / 2 + k * _PI(2) / 3) * s
                ay(k) = y + SIN(r - _PI / 2 + k * _PI(2) / 3) * s
            NEXT
            fillTriangle ax(1), ay(1), ax(2), ay(2), ax(3), ay(3), col
    END SELECT
END SUB

SUB updateScore
    STATIC lastTick AS DOUBLE
    DIM before AS LONG, stp AS SINGLE

    IF scoreFlying = false THEN
        IF visibleScore < score THEN
            before = INT(visibleScore)
            stp = (score - visibleScore) * frameDt * 5
            IF stp < frameDt * 8 THEN stp = frameDt * 8
            visibleScore = visibleScore + stp
            IF visibleScore > score THEN visibleScore = score
            IF INT(visibleScore) - before > 5 THEN scoreShake = 1
            IF INT(visibleScore) <> before AND clock - lastTick > .05 THEN
                playSfx woodblock, 1
                lastTick = clock
            END IF
        ELSEIF visibleScore > score THEN
            visibleScore = score
        END IF

        IF visibleHighScore < highscore THEN
            stp = (highscore - visibleHighScore) * frameDt * 3
            IF stp < frameDt * 8 THEN stp = frameDt * 8
            visibleHighScore = visibleHighScore + stp
            IF visibleHighScore > highscore THEN visibleHighScore = highscore
        END IF
    END IF

    IF scoreShake > 0 THEN
        scoreShake = scoreShake - frameDt * 3
        IF scoreShake < 0 THEN scoreShake = 0
    END IF
END SUB

SUB playSfx (handle AS LONG, baseVolume AS SINGLE)
    IF handle > 0 AND sfxVolume > 0 THEN _SNDPLAYCOPY handle, baseVolume * sfxVolume
END SUB

SUB applyMusicVolume
    DIM v AS SINGLE

    IF track(1) = 0 THEN EXIT SUB
    IF musicVolume <= 0 THEN
        IF _SNDPLAYING(track(1)) THEN _SNDSTOP track(1)
    ELSE
        v = musicVolume * mainTrackVolume
        IF pauseGame AND v > .05 THEN v = .05
        _SNDVOL track(1), v
        IF NOT _SNDPLAYING(track(1)) THEN _SNDLOOP track(1)
    END IF
END SUB

SUB restartMusic
    IF track(1) = 0 OR musicVolume <= 0 THEN EXIT SUB
    _SNDSTOP track(1)
    applyMusicVolume
END SUB

SUB setMusicVolume (v AS SINGLE)
    musicVolume = clampf(v, 0, 1)
    IF musicVolume > 0 THEN prevMusicVolume = musicVolume
    applyMusicVolume
END SUB

SUB setSfxVolume (v AS SINGLE)
    sfxVolume = clampf(v, 0, 1)
    IF sfxVolume > 0 THEN prevSfxVolume = sfxVolume
END SUB

SUB toggleMusic
    IF musicVolume > 0 THEN
        prevMusicVolume = musicVolume
        musicVolume = 0
    ELSE
        IF prevMusicVolume <= 0 THEN prevMusicVolume = .7
        musicVolume = prevMusicVolume
    END IF
    applyMusicVolume
END SUB

SUB toggleSfx
    IF sfxVolume > 0 THEN
        prevSfxVolume = sfxVolume
        sfxVolume = 0
    ELSE
        IF prevSfxVolume <= 0 THEN prevSfxVolume = .7
        sfxVolume = prevSfxVolume
        playSfx wooshSound, .5
    END IF
END SUB

SUB CircleFill (x AS LONG, y AS LONG, R AS LONG, C AS _UNSIGNED LONG)
    DIM x0 AS SINGLE, y0 AS SINGLE
    DIM e AS SINGLE

    x0 = R
    y0 = 0
    e = -R
    DO WHILE y0 < x0
        IF e <= 0 THEN
            y0 = y0 + 1
            LINE (x - x0, y + y0)-(x + x0, y + y0), C, BF
            LINE (x - x0, y - y0)-(x + x0, y - y0), C, BF
            e = e + 2 * y0
        ELSE
            LINE (x - y0, y - x0)-(x + y0, y - x0), C, BF
            LINE (x - y0, y + x0)-(x + y0, y + x0), C, BF
            x0 = x0 - 1
            e = e - 2 * x0
        END IF
    LOOP
    LINE (x - R, y)-(x + R, y), C, BF
END SUB

SUB thickLine (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, w AS SINGLE, col AS _UNSIGNED LONG)
    DIM ang AS SINGLE, nx AS SINGLE, ny AS SINGLE, o AS SINGLE

    ang = _ATAN2(y2 - y1, x2 - x1)
    nx = -SIN(ang)
    ny = COS(ang)
    FOR o = -w / 2 TO w / 2 STEP 1
        LINE (x1 + nx * o, y1 + ny * o)-(x2 + nx * o, y2 + ny * o), col
    NEXT
END SUB

SUB fillTriangle (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, x3 AS SINGLE, y3 AS SINGLE, col AS _UNSIGNED LONG)
    DIM ax AS SINGLE, ay AS SINGLE, bx AS SINGLE, by AS SINGLE, cx AS SINGLE, cy AS SINGLE
    DIM y AS LONG, xa AS SINGLE, xb AS SINGLE

    ax = x1: ay = y1: bx = x2: by = y2: cx = x3: cy = y3
    IF by < ay THEN SWAP ax, bx: SWAP ay, by
    IF cy < ay THEN SWAP ax, cx: SWAP ay, cy
    IF cy < by THEN SWAP bx, cx: SWAP by, cy
    IF cy - ay < .5 THEN EXIT SUB

    FOR y = _CEIL(ay) TO INT(cy)
        xa = ax + (cx - ax) * (y - ay) / (cy - ay)
        IF y < by THEN
            IF by - ay > 0 THEN xb = ax + (bx - ax) * (y - ay) / (by - ay) ELSE xb = bx
        ELSE
            IF cy - by > 0 THEN xb = bx + (cx - bx) * (y - by) / (cy - by) ELSE xb = bx
        END IF
        IF xa > xb THEN SWAP xa, xb
        LINE (xa, y)-(xb, y), col
    NEXT
END SUB

SUB roundRectFill (x AS SINGLE, y AS SINGLE, w AS SINGLE, h AS SINGLE, r AS SINGLE, c1 AS _UNSIGNED LONG, c2 AS _UNSIGNED LONG)
    'filled rounded rectangle with a vertical gradient, drawn one scanline at a time
    DIM yy AS INTEGER, inset AS SINGLE, dy AS SINGLE, t AS SINGLE, col AS _UNSIGNED LONG

    FOR yy = 0 TO h - 1
        inset = 0
        IF yy < r THEN
            dy = r - yy - .5
            inset = r - SQR(clampf(r * r - dy * dy, 0, r * r))
        ELSEIF yy > h - 1 - r THEN
            dy = yy + .5 - (h - r)
            inset = r - SQR(clampf(r * r - dy * dy, 0, r * r))
        END IF
        IF x + inset <= x + w - 1 - inset THEN
            t = yy / h
            col = _RGBA32(lerp(_RED32(c1), _RED32(c2), t), lerp(_GREEN32(c1), _GREEN32(c2), t), lerp(_BLUE32(c1), _BLUE32(c2), t), lerp(_ALPHA32(c1), _ALPHA32(c2), t))
            LINE (x + inset, y + yy)-(x + w - 1 - inset, y + yy), col
        END IF
    NEXT
END SUB

SUB roundRectLine (x AS SINGLE, y AS SINGLE, w AS SINGLE, h AS SINGLE, r AS SINGLE, col AS _UNSIGNED LONG)
    LINE (x + r, y)-(x + w - r, y), col
    LINE (x + r, y + h)-(x + w - r, y + h), col
    LINE (x, y + r)-(x, y + h - r), col
    LINE (x + w, y + r)-(x + w, y + h - r), col
    CIRCLE (x + r, y + r), r, col, _PI / 2, _PI
    CIRCLE (x + w - r, y + r), r, col, 0, _PI / 2
    CIRCLE (x + r, y + h - r), r, col, _PI, _PI * 1.5
    CIRCLE (x + w - r, y + h - r), r, col, _PI * 1.5, _PI * 2
END SUB

FUNCTION roundRectCoverage! (px AS SINGLE, py AS SINGLE, w AS SINGLE, h AS SINGLE, r AS SINGLE)
    'how much of pixel (px, py) is inside a w x h rounded rectangle
    DIM cx AS SINGLE, cy AS SINGLE

    cx = clampf(px, r, w - r)
    cy = clampf(py, r, h - r)
    roundRectCoverage! = clampf(r + .5 - dist(px, py, cx, cy), 0, 1)
END FUNCTION

FUNCTION slotColor% (s$, slot AS INTEGER)
    slotColor% = CVI(MID$(s$, slot * 2 - 1, 2))
END FUNCTION

FUNCTION lighter~& (c AS _UNSIGNED LONG, amount AS INTEGER)
    lighter~& = _RGB32(clampf(_RED32(c) + amount, 0, 255), clampf(_GREEN32(c) + amount, 0, 255), clampf(_BLUE32(c) + amount, 0, 255))
END FUNCTION

FUNCTION hsl~& (h AS SINGLE, s AS SINGLE, l AS SINGLE, a AS SINGLE)
    DIM hh AS SINGLE, cc AS SINGLE, hp AS SINGLE, x AS SINGLE, m AS SINGLE
    DIM r AS SINGLE, g AS SINGLE, b AS SINGLE

    hh = h - 360 * INT(h / 360)
    cc = (1 - ABS(2 * l - 1)) * s
    hp = hh / 60
    x = cc * (1 - ABS(hp - 2 * INT(hp / 2) - 1))
    SELECT CASE INT(hp)
        CASE 0: r = cc: g = x
        CASE 1: r = x: g = cc
        CASE 2: g = cc: b = x
        CASE 3: g = x: b = cc
        CASE 4: r = x: b = cc
        CASE ELSE: r = cc: b = x
    END SELECT
    m = l - cc / 2
    hsl~& = _RGBA32((r + m) * 255, (g + m) * 255, (b + m) * 255, clampf(a, 0, 255))
END FUNCTION

FUNCTION clampf! (v AS SINGLE, lo AS SINGLE, hi AS SINGLE)
    IF v < lo THEN
        clampf! = lo
    ELSEIF v > hi THEN
        clampf! = hi
    ELSE
        clampf! = v
    END IF
END FUNCTION

FUNCTION easeOutCubic! (t AS SINGLE)
    easeOutCubic! = 1 - (1 - t) ^ 3
END FUNCTION

FUNCTION map! (value!, minRange!, maxRange!, newMinRange!, newMaxRange!)
    map! = ((value! - minRange!) / (maxRange! - minRange!)) * (newMaxRange! - newMinRange!) + newMinRange!
END FUNCTION

FUNCTION lerp! (start!, stp!, amt!)
    lerp! = start! + (stp! - start!) * amt!
END FUNCTION

FUNCTION dist! (x1!, y1!, x2!, y2!)
    dist! = _HYPOT((x2! - x1!), (y2! - y1!))
END FUNCTION

SUB printLarge (x AS SINGLE, y AS SINGLE, text$, fontSize AS INTEGER)
    DIM i AS LONG, j AS LONG, c AS LONG, char AS _UNSIGNED _BYTE

    IF fontSize = 0 THEN fontSize = 1

    FOR c = 1 TO LEN(text$)
        char = ASC(text$, c)
        FOR i = 1 TO 16
            FOR j = 1 TO 8
                IF charSet(char, i, j) THEN
                    IF _PRINTMODE <> 2 THEN
                        LINE ((x - fontSize) + j * fontSize + ((c - 1) * (fontSize * 8)), (y - fontSize) + i * fontSize)-STEP(fontSize - 1, fontSize - 1), _DEFAULTCOLOR, BF
                    END IF
                ELSE
                    IF _PRINTMODE = 3 OR _PRINTMODE = 2 THEN
                        LINE ((x - fontSize) + j * fontSize + ((c - 1) * (fontSize * 8)), (y - fontSize) + i * fontSize)-STEP(fontSize - 1, fontSize - 1), _BACKGROUNDCOLOR, BF
                    END IF
                END IF
            NEXT
        NEXT
    NEXT
END SUB

SUB centerLarge (y AS SINGLE, text$, fontSize AS INTEGER)
    printLarge (_WIDTH - printWidthLarge(text$, fontSize)) / 2, y, text$, fontSize
END SUB

SUB centerText (y AS SINGLE, text$)
    _PRINTSTRING ((_WIDTH - _PRINTWIDTH(text$)) / 2, y), text$
END SUB

FUNCTION fontHeightLarge (fontSize AS INTEGER)
    fontHeightLarge = fontSize * 16
END FUNCTION

FUNCTION fontWidthLarge (fontSize AS INTEGER)
    fontWidthLarge = fontSize * 8
END FUNCTION

FUNCTION printWidthLarge (text$, fontSize AS INTEGER)
    printWidthLarge = fontWidthLarge(fontSize) * LEN(text$)
END FUNCTION

SUB initializeCharSetPrintLarge
    DIM char, row, column
    RESTORE charSet8x16
    FOR char = 0 TO 255
        FOR row = 1 TO 16
            FOR column = 1 TO 8
                READ charSet(char, row, column)
            NEXT
        NEXT
    NEXT

    charSet8x16:
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,-1,0,0,0,0,0,0,-1,-1,0,-1,0,0,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    DATA -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,0,0,0,0,-1,0,0,-1,0,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,0,0,0,-1,-1,0,0,-1,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0
    DATA -1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1
    DATA 0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,0,0,-1,-1,-1,0,0,-1,-1,-1,0,0,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1
    DATA -1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1
    DATA 0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1
    DATA -1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0
    DATA -1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1
    DATA -1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1
    DATA -1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,0
    DATA 0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0
    DATA 0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0
    DATA -1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0
    DATA -1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1
    DATA -1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0
    DATA 0,-1,-1,0,0,0,-1,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0
    DATA -1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0
    DATA 0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1
    DATA -1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0
    DATA -1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1
    DATA -1,-1,-1,-1,0,0,-1,0,-1,-1,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1
    DATA -1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0
    DATA 0,-1,-1,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0
    DATA 0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1
    DATA 0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1
    DATA 0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1
    DATA 0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0
    DATA -1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1
    DATA -1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,0,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0
    DATA 0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1
    DATA 0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA -1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1
    DATA -1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0
    DATA -1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0
    DATA -1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1
    DATA -1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1
    DATA -1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1
    DATA 0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1
    DATA -1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1
    DATA -1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0
    DATA -1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,0,-1,0,0,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,0,0,-1,0,0,0,-1,0,-1,0,0,0,-1,0,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,0,-1,0,-1,0,-1,0,-1,-1,0,-1,0,-1,0,-1,0,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1
    DATA -1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,-1,-1,0,-1,-1,-1,0,-1,0,-1,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0
    DATA 0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1
    DATA 0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1
    DATA -1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1
    DATA -1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0
    DATA -1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0
    DATA 0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1
    DATA -1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0
    DATA -1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1
    DATA -1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1
    DATA 0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    DATA -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1
    DATA -1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,0,0,0,-1,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1
    DATA 0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,-1,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,-1,-1,0,0,0,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,-1,-1,-1,-1,-1,-1,0,-1
    DATA -1,0,-1,-1,0,-1,-1,-1,-1,0,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,-1,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1
    DATA -1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,-1,-1,0,-1,-1,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,0,0,0,0,-1,-1,0,0,-1,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,0,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,0,0,0,0,-1,-1,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,0,0,0,-1,-1,0,0,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DATA 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
END SUB

SUB endScreen
    DIM k AS INTEGER, i AS INTEGER, s AS SINGLE, start AS DOUBLE
    DIM screenshot AS LONG, screenshot2 AS LONG
    DIM board$, filename$, insertAt AS LONG, temp$, blink AS INTEGER
    DIM highScore(maxHighScores) AS newHighScore, totalHS AS INTEGER
    DIM fireworksX AS INTEGER, fireworksY AS INTEGER, shootFireworks AS INTEGER
    DIM tableX AS INTEGER, mx AS INTEGER, my AS INTEGER, prevbt AS INTEGER, startX AS INTEGER

    IF gameOver OR keyb = -27 THEN
        'flash and screenshot
        screenshot = _COPYIMAGE(_DISPLAY)

        start = clock
        DO
            s = map(clock - start, 0, .5, 1, .25)
            IF s < .25 THEN s = .25
            drawBackground
            _PUTIMAGE ((_WIDTH - _WIDTH * s) / 2, 0)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
            IF clock - start < .3 THEN
                LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(clock - start, 0, .3, 0, 255)), BF
            END IF
            updateParticles
            _DISPLAY
            _LIMIT 60
        LOOP UNTIL clock - start > .75

        IF gameOver THEN
            COLOR _RGB32(255)
            centerLarge 440, "Game Over", 4
            IF gameOverReason = GAME_OVER_NO_MOVES THEN
                COLOR _RGB32(255, 150, 170)
                centerText 508, "No more moves"
            END IF
            COLOR _RGB32(255)
            centerLarge 530, "Final Score:" + STR$(score), 2

            screenshot2 = _COPYIMAGE(_DISPLAY)

            centerText 200, "Connecting to server..."
            _DISPLAY

            'highscores
            board$ = downloadBoard

            _PUTIMAGE (0, 0), screenshot2
            _FREEIMAGE screenshot2

            IF mode = 0 THEN filename$ = "highscores.dat"
            IF mode = 1 THEN filename$ = "highscores_easier.dat"

            IF LEN(board$) > 0 THEN 'WRITES THAT TO THE FILE
                OPEN filename$ FOR OUTPUT AS #1
                PRINT #1, board$
                CLOSE #1
            END IF

            IF _FILEEXISTS(filename$) THEN
                OPEN filename$ FOR INPUT AS #1
                FOR i = 1 TO maxHighScores
                    IF EOF(1) THEN EXIT FOR
                    INPUT #1, highScore(i).player
                    INPUT #1, highScore(i).score
                    IF highScore(i).score > highscore THEN highscore = highScore(i).score
                    totalHS = i
                NEXT
                CLOSE #1
            END IF

            IF score > 0 AND score >= highscore THEN
                COLOR _RGB32(255, 215, 0)
                centerText 570, "New High Score!"
            END IF

            saveGame

            tableX = _WIDTH / 2 - 88
            COLOR _RGB32(255)
            IF score > 0 AND (totalHS < maxHighScores OR (totalHS > 0 AND score > highScore(totalHS).score)) THEN
                _KEYCLEAR
                centerText 200, "You made it to the scoreboard!"

                'insert new score into table
                IF totalHS = 0 THEN
                    totalHS = 1
                    insertAt = 1
                    highScore(insertAt).score = score
                ELSE
                    IF totalHS < maxHighScores THEN
                        FOR i = totalHS TO 1 STEP -1
                            IF score > highScore(i).score THEN
                                insertAt = i
                            END IF
                        NEXT

                        totalHS = totalHS + 1
                        IF insertAt = 0 THEN
                            insertAt = totalHS
                            highScore(totalHS).score = score
                        ELSE
                            FOR i = totalHS - 1 TO insertAt STEP -1
                                highScore(i + 1) = highScore(i)
                            NEXT
                            highScore(insertAt).score = score
                        END IF
                    ELSEIF totalHS = maxHighScores THEN
                        FOR i = totalHS TO 1 STEP -1
                            IF score > highScore(i).score THEN
                                insertAt = i
                            END IF
                        NEXT

                        FOR i = totalHS - 1 TO insertAt STEP -1
                            highScore(i + 1) = highScore(i)
                        NEXT
                        highScore(insertAt).score = score
                    END IF
                END IF

                highScore(insertAt).player = ""

                centerText 232, "******** HIGH  SCORES ********"
                FOR i = 1 TO totalHS
                    printHighScore tableX, 248 + i * 16, highScore(i).player, highScore(i).score
                NEXT

                screenshot2 = _COPYIMAGE(_DISPLAY)
                DO 'custom input loop
                    _PUTIMAGE (0, 0), screenshot2

                    IF shootFireworks = 0 THEN
                        fireworksX = RND * _WIDTH
                        fireworksY = RND * _HEIGHT
                        addParticles fireworksX, fireworksY, 60, _RGB32(255)
                        addParticles fireworksX, fireworksY, 120, _RGB32(RND * 255, RND * 255, RND * 255)
                    END IF
                    shootFireworks = (shootFireworks + 1) MOD 120

                    updateParticles

                    COLOR _RGB32(255)
                    blink = (blink + 1) MOD 60
                    IF blink <= 30 THEN
                        _PRINTSTRING (tableX, 248 + insertAt * 16), temp$ + "_"
                    ELSE
                        _PRINTSTRING (tableX, 248 + insertAt * 16), temp$
                    END IF

                    keyb = _KEYHIT
                    SELECT CASE keyb
                        CASE 8
                            IF LEN(temp$) > 0 THEN temp$ = LEFT$(temp$, LEN(temp$) - 1)
                        CASE 13
                            EXIT DO
                        CASE 27
                            temp$ = "PLAYER"
                            EXIT DO
                        CASE 65 TO 90, 97 TO 122, 48 TO 57
                            IF LEN(temp$) < 8 THEN temp$ = temp$ + UCASE$(CHR$(keyb))
                    END SELECT

                    _DISPLAY
                    _LIMIT 60
                    IF _EXIT THEN SYSTEM
                LOOP
                _PUTIMAGE (0, 0), screenshot2
                COLOR _RGB32(255)
                _PRINTSTRING (tableX, 248 + insertAt * 16), temp$
                _FREEIMAGE screenshot2
                highScore(insertAt).player = temp$
                _KEYCLEAR

                OPEN filename$ FOR OUTPUT AS #1
                board$ = ""
                FOR i = 1 TO totalHS
                    WRITE #1, highScore(i).player, highScore(i).score,
                    'build the new score line for upload
                    board$ = board$ + CHR$(34) + RTRIM$(highScore(i).player) + CHR$(34) + "," + LTRIM$(STR$(highScore(i).score))
                    IF i < totalHS THEN board$ = board$ + ","
                NEXT
                CLOSE #1

                screenshot2 = _COPYIMAGE(_DISPLAY)

                centerText 424, "Updating scoreboard..."
                _DISPLAY
                uploadBoard board$
                _PUTIMAGE (0, 0), screenshot2
                _FREEIMAGE screenshot2
            ELSE
                centerText 232, "******** HIGH  SCORES ********"
                FOR i = 1 TO totalHS
                    printHighScore tableX, 248 + i * 16, highScore(i).player, highScore(i).score
                NEXT
            END IF
        END IF

        screenshot2 = _COPYIMAGE(_DISPLAY)

        'end screen buttons
        currentButton = 0
        totalButtons = 2
        FOR i = 1 TO 2
            button(i).h = 35
            button(i).w = 120
            button(i).state = 0
        NEXT

        startX = (_WIDTH - button(1).w * totalButtons - 20) / 2
        FOR i = 1 TO totalButtons
            button(i).y = _HEIGHT - 90
            button(i).x = startX
            startX = startX + button(i).w + 20
        NEXT

        IF gameOver THEN
            caption(1) = "Play Again"
            caption(2) = "Quit"
        ELSE
            caption(1) = "Continue"
            caption(2) = "Restart"
        END IF

        DO WHILE _KEYHIT <> 0 OR _KEYDOWN(13): _LIMIT 10: LOOP
        mouseDown = false
        DO
            IF mainTrackVolume < 1 THEN
                mainTrackVolume = mainTrackVolume + .05
                applyMusicVolume
            END IF

            keyb = _KEYHIT
            WHILE _MOUSEINPUT: WEND
            mx = _MOUSEX
            my = _MOUSEY

            _PUTIMAGE (0, 0), screenshot2
            doButtons
            checkButtons

            IF currentButton <> prevbt THEN
                IF currentButton > 0 THEN playSfx selectSound, .3
                prevbt = currentButton
            END IF

            SELECT CASE keyb
                CASE 19200 'left
                    currentButton = 1
                CASE 19712 'right
                    currentButton = 2
                CASE -13
                    mouseDown = true
                CASE -27
                    EXIT DO
            END SELECT

            IF _MOUSEBUTTON(1) THEN
                mouseDown = true
            ELSE
                IF mouseDown THEN
                    SELECT CASE currentButton
                        CASE 1
                            keyb = -121
                            EXIT DO
                        CASE 2
                            keyb = -110
                            EXIT DO
                    END SELECT
                    addParticles mx, my, 30, _RGB32(255)
                    addParticles mx, my, 30, _RGB32(122, 89, 144)
                END IF
                mouseDown = false
            END IF

            updateParticles

            userQuit = _EXIT
            _DISPLAY
            _LIMIT 30
        LOOP UNTIL keyb = -13 OR keyb = -27 OR keyb = -110 OR keyb = -78 OR keyb = -121 OR keyb = -89 OR userQuit
        mouseDown = false

        IF (gameOver AND (keyb = -110 OR keyb = -78)) OR userQuit THEN SYSTEM

        IF (gameOver AND (keyb = -13 OR keyb = -121 OR keyb = -89)) OR (gameOver = false AND (keyb = -110 OR keyb = -78)) THEN
            resetGame
        ELSE
            'bring screenshot back to front
            start = clock
            DO
                s = map(clock - start, 0, .5, 2 / 3, 1)
                IF s > 1 THEN s = 1
                drawBackground
                _PUTIMAGE ((_WIDTH - _WIDTH * s) / 2, 0)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
                IF clock - start <= .3 THEN
                    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(clock - start, 0, .3, 0, 255)), BF
                END IF
                _DISPLAY
                _LIMIT 60
            LOOP UNTIL clock - start > .5
        END IF

        _FREEIMAGE screenshot
        _FREEIMAGE screenshot2
        _KEYCLEAR
        currentButton = 0
    END IF
END SUB

SUB printHighScore (x AS INTEGER, y AS INTEGER, player$, value AS _UNSIGNED LONG)
    DIM v$
    v$ = LTRIM$(STR$(value))
    _PRINTSTRING (x, y), player$
    _PRINTSTRING (x + 176 - _PRINTWIDTH(v$), y), v$
END SUB

SUB settingsScreen
    DIM screenshot AS LONG, s AS SINGLE, sw AS SINGLE, sh AS SINGLE, start AS DOUBLE
    DIM i AS INTEGER, mx AS INTEGER, my AS INTEGER, currentMode AS INTEGER, prevbt AS INTEGER
    DIM sliderDrag AS INTEGER, activate AS INTEGER, done AS _BYTE
    DIM bw AS INTEGER, bh AS INTEGER, x0 AS INTEGER, y0 AS INTEGER

    currentMode = mode

    'flash and screenshot
    screenshot = _COPYIMAGE(_DISPLAY)

    start = clock
    DO
        s = map(clock - start, 0, .5, 1, 1 / 3)
        IF s < 1 / 3 THEN s = 1 / 3
        sw = _WIDTH * s
        sh = _HEIGHT * s
        drawBackground
        _PUTIMAGE (0, (_HEIGHT - sh) / 2)-STEP(sw, sh), screenshot
        IF clock - start < .3 THEN
            LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(clock - start, 0, .3, 0, 255)), BF
        END IF

        updateParticles
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > .75

    'settings controls
    bw = 360
    bh = 35
    x0 = _WIDTH - _WIDTH / 3 - bw / 2
    y0 = (_HEIGHT - 5 * 45) / 2

    currentButton = 0
    totalButtons = 8
    FOR i = 1 TO totalButtons
        button(i).state = 0
        button(i).h = bh
        button(i).w = bw
        button(i).x = x0
    NEXT

    button(1).y = y0 'difficulty
    button(2).y = y0 + 45: button(2).w = bw - 60: button(2).state = 1 'music slider
    button(3).y = y0 + 45: button(3).x = x0 + bw - 50: button(3).w = 50 'music on/off
    button(4).y = y0 + 90: button(4).w = bw - 60: button(4).state = 1 'sfx slider
    button(5).y = y0 + 90: button(5).x = x0 + bw - 50: button(5).w = 50 'sfx on/off
    button(6).y = y0 + 135 'electric connections
    button(7).y = y0 + 180 'return

    'the screenshot is also a button
    button(8).x = 0
    button(8).y = (_HEIGHT - sh) / 2
    button(8).w = sw
    button(8).h = sh
    button(8).state = 2

    caption(2) = "Music"
    caption(4) = "Sound effects"
    caption(7) = "Return to game"
    caption(8) = ""

    mouseDown = false
    DO
        drawBackground
        _PUTIMAGE (0, (_HEIGHT - sh) / 2)-STEP(sw, sh), screenshot

        WHILE _MOUSEINPUT: WEND
        mx = _MOUSEX
        my = _MOUSEY
        keyb = _KEYHIT
        userQuit = _EXIT

        SELECT CASE mode
            CASE MODE_NORMAL
                caption(1) = "Difficulty: NORMAL"
            CASE MODE_EASIER
                caption(1) = "Difficulty: EASIER"
        END SELECT

        IF musicVolume > 0 THEN caption(3) = "ON" ELSE caption(3) = "OFF"
        IF sfxVolume > 0 THEN caption(5) = "ON" ELSE caption(5) = "OFF"
        IF electricConnections THEN
            caption(6) = "Electric connections: ON"
        ELSE
            caption(6) = "Electric connections: OFF"
        END IF

        IF sliderDrag = 0 THEN checkButtons

        IF currentButton <> prevbt THEN
            IF currentButton > 0 THEN playSfx selectSound, .3
            prevbt = currentButton
        END IF

        activate = 0
        SELECT CASE keyb
            CASE 18432 'up
                SELECT CASE currentButton
                    CASE 0 TO 3: currentButton = 1
                    CASE 4, 5: currentButton = 2
                    CASE 6: currentButton = 4
                    CASE 7: currentButton = 6
                    CASE 8: currentButton = 7
                END SELECT
            CASE 20480 'down
                SELECT CASE currentButton
                    CASE 0: currentButton = 1
                    CASE 1: currentButton = 2
                    CASE 2, 3: currentButton = 4
                    CASE 4, 5: currentButton = 6
                    CASE 6: currentButton = 7
                    CASE 7, 8: currentButton = 8
                END SELECT
            CASE 19200 'left
                SELECT CASE currentButton
                    CASE 2, 3: setMusicVolume musicVolume - .1
                    CASE 4, 5
                        setSfxVolume sfxVolume - .1
                        playSfx selectSound, .3
                    CASE 8
                    CASE ELSE: currentButton = 8
                END SELECT
            CASE 19712 'right
                SELECT CASE currentButton
                    CASE 2, 3: setMusicVolume musicVolume + .1
                    CASE 4, 5
                        setSfxVolume sfxVolume + .1
                        playSfx selectSound, .3
                    CASE 8: currentButton = 1
                END SELECT
            CASE -13
                activate = currentButton
                IF currentButton > 0 THEN
                    mx = button(currentButton).x + button(currentButton).w / 2
                    my = button(currentButton).y + button(currentButton).h / 2
                END IF
            CASE -27
                EXIT DO
        END SELECT

        IF _MOUSEBUTTON(1) THEN
            IF NOT mouseDown THEN
                mouseDown = true
                IF currentButton = 2 OR currentButton = 4 THEN
                    IF mx >= sliderTrackX(currentButton) - 10 THEN sliderDrag = currentButton
                END IF
            END IF
            IF sliderDrag = 2 THEN setMusicVolume (mx - sliderTrackX(2)) / sliderTrackW(2)
            IF sliderDrag = 4 THEN setSfxVolume (mx - sliderTrackX(4)) / sliderTrackW(4)
        ELSEIF mouseDown THEN
            mouseDown = false
            IF sliderDrag THEN
                IF sliderDrag = 4 THEN playSfx selectSound, .3
                sliderDrag = 0
            ELSE
                activate = currentButton
            END IF
        END IF

        IF activate > 0 THEN
            SELECT CASE activate
                CASE 1
                    mode = mode + 1
                    IF mode > 1 THEN mode = 0
                CASE 2, 3
                    toggleMusic
                CASE 4, 5
                    toggleSfx
                CASE 6
                    electricConnections = NOT electricConnections
                CASE 7, 8
                    done = true
            END SELECT
            addParticles mx, my, 30, _RGB32(255)
            addParticles mx, my, 30, _RGB32(67, 172, 183)
        END IF

        doButtons
        drawSlider 2, musicVolume
        drawSlider 4, sfxVolume

        'game title
        COLOR _RGB32(0)
        centerLarge (_HEIGHT / 7) + 3, "Settings", 4
        centerLarge (_HEIGHT - _HEIGHT / 4) - fontHeightLarge(2) + 3, "Tic Tac Toe", 2
        centerLarge (_HEIGHT - _HEIGHT / 4) + 3, "Rings", 7

        COLOR _RGB32(255)
        centerLarge (_HEIGHT / 7), "Settings", 4
        centerLarge (_HEIGHT - _HEIGHT / 4) - fontHeightLarge(2), "Tic Tac Toe", 2
        centerLarge (_HEIGHT - _HEIGHT / 4), "Rings", 7

        updateParticles

        IF currentMode <> mode THEN
            centerLarge _HEIGHT - fontHeightLarge(1), "Current game will be lost if you change mode", 1
        END IF

        _DISPLAY
        _LIMIT 60
    LOOP UNTIL done OR userQuit

    IF userQuit THEN
        saveGame
        SYSTEM
    END IF

    'bring screenshot back to front
    start = clock
    DO
        s = map(clock - start, 0, .5, 2 / 3, 1)
        IF s > 1 THEN s = 1
        drawBackground
        _PUTIMAGE (0, (_HEIGHT - _HEIGHT * s) / 2)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
        IF clock - start <= .3 THEN
            LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(clock - start, 0, .3, 0, 255)), BF
        END IF
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > .5

    _FREEIMAGE screenshot
    _KEYCLEAR
    mouseDown = false
    currentButton = 0
END SUB

FUNCTION sliderTrackX! (i AS INTEGER)
    sliderTrackX! = button(i).x + 120
END FUNCTION

FUNCTION sliderTrackW! (i AS INTEGER)
    sliderTrackW! = button(i).w - 168
END FUNCTION

SUB drawSlider (i AS INTEGER, value AS SINGLE)
    DIM tx AS SINGLE, tw AS SINGLE, ty AS SINGLE, hx AS SINGLE, pct$

    drawButtonBox i
    COLOR _RGB32(255)
    _PRINTSTRING (button(i).x + 10, button(i).y + (button(i).h - _FONTHEIGHT) / 2), caption(i)

    tx = sliderTrackX(i)
    tw = sliderTrackW(i)
    ty = button(i).y + button(i).h / 2
    roundRectFill tx, ty - 4, tw, 8, 4, _RGB32(40, 40, 60), _RGB32(40, 40, 60)
    IF tw * value >= 2 THEN roundRectFill tx, ty - 4, tw * value, 8, 4, _RGB32(100, 150, 255), _RGB32(50, 100, 200)

    hx = tx + tw * value
    IF i = currentButton THEN CircleFill hx, ty, 12, _RGBA32(100, 150, 255, 80)
    CircleFill hx, ty, 8, _RGB32(200, 220, 255)
    CIRCLE (hx, ty), 8, _RGB32(100, 150, 255)
    CIRCLE (hx, ty), 9, _RGB32(100, 150, 255)

    pct$ = LTRIM$(STR$(INT(value * 100 + .5))) + "%"
    COLOR _RGB32(200, 200, 220)
    _PRINTSTRING (button(i).x + button(i).w - 8 - _PRINTWIDTH(pct$), button(i).y + (button(i).h - _FONTHEIGHT) / 2), pct$
END SUB

SUB createMainScreenButtons
    DIM i AS INTEGER

    totalButtons = 3
    caption(1) = "Settings"
    caption(2) = "Pause"
    caption(3) = "Quit"
    FOR i = 1 TO totalButtons
        button(i).w = 80
        button(i).h = 35
        button(i).x = _WIDTH - button(i).w - 10
        button(i).y = 20 + (i - 1) * 45
        button(i).state = 0
    NEXT
END SUB

SUB doButtons
    'button(i).state: 0 = regular button, 1 = drawn elsewhere, 2 = outline only
    DIM i AS INTEGER

    FOR i = 1 TO totalButtons
        SELECT CASE button(i).state
            CASE 0
                drawButtonBox i
                COLOR _RGB32(255)
                _PRINTSTRING (button(i).x + (button(i).w - _PRINTWIDTH(caption(i))) / 2, button(i).y + (button(i).h - _FONTHEIGHT) / 2), caption(i)
            CASE 2
                IF i = currentButton THEN
                    LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGBA32(255, 255, 255, 80), BF
                    LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGB32(67, 172, 183), B
                ELSE
                    LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGB32(136), B
                END IF
        END SELECT
    NEXT
END SUB

SUB drawButtonBox (i AS INTEGER)
    IF i = currentButton THEN
        LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGBA32(67, 172, 183, 128), BF
        LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGB32(67, 172, 183), B
        LINE (button(i).x + 1, button(i).y + 1)-STEP(button(i).w - 2, button(i).h - 2), _RGB32(67, 172, 183), B
    ELSE
        LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGBA32(50, 50, 50, 128), BF
        LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGB32(136), B
        LINE (button(i).x + 1, button(i).y + 1)-STEP(button(i).w - 2, button(i).h - 2), _RGB32(136), B
    END IF
END SUB

SUB checkButtons
    DIM i AS INTEGER
    STATIC lastMouseX AS INTEGER, lastMouseY AS INTEGER

    IF _MOUSEX <> lastMouseX OR _MOUSEY <> lastMouseY THEN
        lastMouseX = _MOUSEX
        lastMouseY = _MOUSEY

        currentButton = 0
        FOR i = 1 TO totalButtons
            IF _MOUSEX > button(i).x AND _MOUSEX < button(i).x + button(i).w AND _MOUSEY > button(i).y AND _MOUSEY < button(i).y + button(i).h THEN
                currentButton = i
                EXIT FOR
            END IF
        NEXT
    END IF
END SUB

FUNCTION downloadBoard$
    DIM board$, randomvalue$, client AS INTEGER
    DIM crlf$, request$, t!, a$, a2$
    DIM p1 AS LONG, p2 AS LONG
    STATIC disableScoreboard AS _BYTE

    IF disableScoreboard THEN EXIT FUNCTION

    randomvalue$ = LTRIM$(STR$(INT(RND * 1000000)))
    client = _OPENCLIENT("TCP/IP:80:" + host)
    IF client = 0 THEN EXIT FUNCTION
    crlf$ = CHR$(13) + CHR$(10)
    request$ = "GET " + getboardpath + "?rand=" + randomvalue$ + "&mode=" + _TRIM$(STR$(mode)) + "&auth=" + auth + " HTTP/1.1" + crlf$
    request$ = request$ + "Host: " + host + crlf$ + crlf$
    PUT #client, , request$
    t! = TIMER
    DO
        _DELAY .05
        GET #client, , a2$
        a$ = a$ + a2$
        IF INSTR(a$, crlf$) THEN EXIT DO
        IF TIMER > t! + timelimit THEN disableScoreboard = true: EXIT DO
    LOOP
    CLOSE client

    p1 = INSTR(a$, "<p>")
    IF p1 > 0 THEN
        p2 = INSTR(p1 + 1, a$, "</p>")
        IF p2 = 0 THEN EXIT FUNCTION
    END IF

    board$ = MID$(a$, p1 + 3, p2 - p1 - 3)
    downloadBoard$ = board$
END FUNCTION

SUB uploadBoard (newboard$)
    DIM result$, randomvalue$, client AS INTEGER
    DIM crlf$, request$, t!, a$, a2$
    DIM p1 AS LONG, p2 AS LONG

    randomvalue$ = LTRIM$(STR$(INT(RND * 1000000)))
    client = _OPENCLIENT("TCP/IP:80:" + host)
    IF client = 0 THEN EXIT SUB
    crlf$ = CHR$(13) + CHR$(10)
    request$ = "GET " + updateboardpath + "?rand=" + randomvalue$ + "&mode=" + _TRIM$(STR$(mode)) + "&auth=" + auth + "&newboard=" + newboard$ + " HTTP/1.1" + crlf$
    request$ = request$ + "Host: " + host + crlf$ + crlf$
    PUT #client, , request$
    t! = TIMER
    DO
        _DELAY .05
        GET #client, , a2$
        a$ = a$ + a2$
        IF INSTR(a$, crlf$) THEN EXIT DO
    LOOP UNTIL TIMER > t! + timelimit
    CLOSE client

    p1 = INSTR(a$, "<p>")
    IF p1 > 0 THEN
        p2 = INSTR(p1 + 1, a$, "</p>")
        IF p2 = 0 THEN EXIT SUB
    END IF

    result$ = MID$(a$, p1 + 3, p2 - p1 - 3)
    IF result$ = "success" THEN EXIT SUB
END SUB
