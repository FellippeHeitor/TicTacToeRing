Import Storage From "lib/web/storage.bas"
Import Sys From "lib/lang/system.bas"
Import GXS From "https://gxapi.boxgaming.co/v0/gxs.bas"
OPTION _EXPLICIT

'Tic Tac Toe Ring - QBJS (https://qbjs.org) port of tictactoering.bas
'Based on 'Rings.' by Gamezaur; Created with QB64.
'https://github.com/FellippeHeitor/TicTacToeRing
'
'Differences from the QB64 version:
'- the game state and a local copy of the high scores are kept in the browser's localStorage
'- the online scoreboard uses the QBJS leaderboard API (GXS) instead of raw TCP connections
'- sounds are loaded from the project's assets folder when present (e.g. when run
'  from a zipped QBJS project), otherwise straight from the GitHub repository

CONST True = -1, False = 0 'capitalized: QBJS emits "const true" otherwise, which is invalid JavaScript
CONST ASSETS_URL = "https://raw.githubusercontent.com/FellippeHeitor/TicTacToeRing/master/"

CONST MODE_NORMAL = 0
CONST MODE_EASIER = 1

CONST GAME_OVER_GLOW = .8 'glow phase (with electric buzz)
CONST GAME_OVER_TREMBLE = .5 'tremble phase
CONST GAME_OVER_EXPLOSION = 1 'explosion phase, while the board rings cascade out
CONST LAND_TIME = .12 'dropped rings flying onto their peg
CONST DYING_TIME = .3 'matched rings swelling and fading out
CONST BEAM_TIME = .5 'line match beam
CONST SPAWN_STAGGER = .08 'delay between new sets popping in
CONST GAME_OVER_NO_MOVES = 1
CONST GAME_OVER_QUIT = 2
CONST TUTORIAL_DELAY = 5 'show tutorial after 5 seconds of inactivity
CONST ELECTRIC_FADE_IN = .3
CONST ELECTRIC_FADE_OUT = .2
CONST MAX_MATCHES = 60

'online scoreboard (https://gxapi.boxgaming.co); an empty id keeps that mode's scores local only
CONST LEADERBOARD_NORMAL = "3d9ed3b6-1dcf-4a56-a5bc-6e6e845addc1"
CONST LEADERBOARD_EASIER = "31a36c93-eefb-4346-aa6f-18bd4ebd22a0"
DIM SHARED maxHighScores AS INTEGER, boardOnline AS _BYTE
maxHighScores = 10


'Required shared variables for printLarge
DIM SHARED charSet(255, 1 TO 16, 1 TO 8) AS _BYTE

initializeCharSetPrintLarge

TYPE gameObject 'not "object": that is a native type in QBJS
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
    shape AS INTEGER '0 = classic dot; 1 to 4 = combo burst shapes; 5 = shockwave; 6 = spark; 7 = imploding streak
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

TYPE dyingType
    x AS SINGLE
    y AS SINGLE
    slot AS INTEGER
    colr AS INTEGER
    start AS DOUBLE
    state AS _BYTE
END TYPE

TYPE beamType
    x1 AS SINGLE
    y1 AS SINGLE
    x2 AS SINGLE
    y2 AS SINGLE
    c AS _UNSIGNED LONG
    start AS DOUBLE
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

'QBJS passes numeric arguments by value, so routines that returned values through
'their parameters in QB64 use these shared variables instead
DIM SHARED blendR AS SINGLE, blendG AS SINGLE, blendB AS SINGLE, blendA AS SINGLE
DIM SHARED crownBand AS SINGLE, crownBall AS SINGLE
DIM SHARED matchPosX AS SINGLE, matchPosY AS SINGLE, matchPosDragged AS _BYTE

DIM SHARED canvas AS LONG
canvas = _NEWIMAGE(900, 700, 32)

SCREEN canvas
_DELAY .1
_TITLE "Tic Tac Toe Ring"
_PRINTMODE _KEEPBACKGROUND

DIM SHARED peg(0 TO 12) AS gameObject
DIM SHARED del(1 TO 9) AS gameObject

DIM SHARED emptySet$
emptySet$ = MKI$(-1) + MKI$(-1) + MKI$(-1)
DIM pegIndex AS INTEGER
FOR pegIndex = 0 TO 12
    peg(pegIndex).set = emptySet$
NEXT

'images
DIM SHARED ringColor(1 TO 10) AS _UNSIGNED LONG
DIM SHARED circleImage(1 TO 10, 1 TO 3) AS LONG, circleGlow(1 TO 10, 1 TO 3) AS LONG
DIM SHARED ringShadow(1 TO 3) AS LONG, pegImage AS LONG, crownIcon AS LONG, arrowIcon(0 TO 8) AS LONG
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
DIM SHARED megaComboMsg$(1 TO 6), comboMsg$(1 TO 2) 'was m$(): QBJS drops type suffixes, so it clashed with a local m
DIM SHARED mode AS INTEGER
DIM SHARED score AS _UNSIGNED LONG, visibleScore AS SINGLE
DIM SHARED highscore AS _UNSIGNED LONG, visibleHighScore AS SINGLE
DIM SHARED level AS _UNSIGNED LONG, maxColors AS INTEGER
DIM SHARED animation(0 TO 8) AS gameObject, multiplier AS INTEGER, totalMatches AS INTEGER
DIM SHARED gameOver AS _BYTE, gameOverDone AS _BYTE, gameOverReason AS INTEGER
DIM SHARED gameOverStart AS DOUBLE, exploded AS _BYTE
DIM SHARED pauseGame AS _BYTE, enterSettings AS _BYTE, enterScores AS _BYTE, userQuit AS _BYTE, keyb AS LONG
DIM SHARED dragging AS INTEGER, mouseDown AS _BYTE
DIM SHARED returnAnim(10 TO 12) AS gameObject
DIM SHARED showTutorial AS _BYTE, tutorialTime AS SINGLE
DIM SHARED screenFlash AS SINGLE, screenZoom AS SINGLE, scoreShake AS SINGLE, frameDt AS SINGLE
DIM SHARED frameStep AS SINGLE 'frameDt measured in 60fps frames, for per-frame motion
DIM SHARED zoomX AS SINGLE, zoomY AS SINGLE 'screen zoom focus point
DIM SHARED scorePop AS SINGLE, scorePopV AS SINGLE 'score panel spring
DIM SHARED comboLost AS INTEGER, comboLostStart AS DOUBLE
DIM SHARED pauseFade AS SINGLE, tutorialFade AS SINGLE, buttonHover(100) AS SINGLE

'ring handling
DIM SHARED dragX AS SINGLE, dragY AS SINGLE, dragLift AS SINGLE, ringLift AS SINGLE
DIM SHARED landing AS gameObject 'set flying from the cursor to its peg; .text = target peg
DIM SHARED pegPop(1 TO 9) AS DOUBLE

'visual effects
DIM SHARED particle(5000) AS particleType
DIM SHARED star(1 TO 150) AS starType, ambient(1 TO 30) AS ambientType
DIM SHARED ripple(1 TO 40) AS rippleType, sparkle(1 TO 60) AS sparkleType
DIM SHARED dying(1 TO 48) AS dyingType, beam(1 TO 12) AS beamType

'electric connections between rings that would match
DIM SHARED match(1 TO MAX_MATCHES) AS matchType, matchCount AS INTEGER
DIM SHARED matchTarget AS INTEGER, matchStart AS DOUBLE
DIM SHARED lastMatch(1 TO MAX_MATCHES) AS matchType, lastMatchCount AS INTEGER
DIM SHARED lastMatchTarget AS INTEGER, lastMatchDrag AS INTEGER
DIM SHARED fadingOut AS _BYTE, fadeOutStart AS DOUBLE

'buttons
DIM SHARED button(100) AS gameObject
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
generateArrowIcon

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
selectSound = loadSound("assets/sounds/select.ogg")
wooshSound = loadSound("assets/sounds/woosh.ogg")
woodblock = loadSound("assets/sounds/woodblock.wav")
electricSound = loadSound("assets/sounds/fridge-buzz-loop-39612.mp3")
track(1) = loadSound("assets/music/track1.ogg")

DIM i AS INTEGER, a$
RESTORE comboSoundFiles
FOR i = 1 TO 8
    READ a$
    comboSound(i) = loadSound("assets/sounds/" + a$)
NEXT

comboSoundFiles:
DATA "do.ogg","re.ogg","mi.ogg","fa.ogg","sol.ogg","la.ogg","si.ogg","do2.ogg"

'if loading sounds took more than 2 seconds, no need to pause
IF clock - loadStart < 2 THEN showWarning 2 - (clock - loadStart)

doIntro

RANDOMIZE TIMER

'game
animation(0).duration = .25 'board flash
animation(6).duration = 1 'new set spawn
animation(7).duration = 1.5 'combo info

multiplier = 1
screenZoom = 1
zoomX = _WIDTH / 2
zoomY = _HEIGHT / 2

visibleScore = score
visibleHighScore = highscore
_DEST _DISPLAY

DIM highScore(maxHighScores) AS newHighScore
DIM totalHS AS INTEGER
DIM board$, filename$, prevbt AS INTEGER, currentMode AS INTEGER, modeChanged AS _BYTE

DO
    'read highscores
    board$ = downloadBoard

    IF mode = 0 THEN filename$ = "highscores.dat"
    IF mode = 1 THEN filename$ = "highscores_easier.dat"

    'IF LEN(board$) > 0 THEN storageSet filename$, board$ 'WRITES THAT TO THE FILE
    IF LEN(board$) > 0 THEN Storage.Set filename$, board$ 'WRITES THAT TO THE FILE

    board$ = Storage.Get(filename$)
    IF LEN(board$) > 0 THEN
        highscore = 0
        FOR i = 1 TO maxHighScores
            IF i * 2 > csvCount(board$) THEN EXIT FOR
            highScore(i).player = csvField$(board$, i * 2 - 1)
            highScore(i).score = VAL(csvField$(board$, i * 2))
            IF highScore(i).score > highscore THEN highscore = highScore(i).score
            totalHS = i
        NEXT
    END IF

    visibleHighScore = highscore
    boardStartBurst
    dragging = 0
    mouseDown = false
    gameOverDone = false

    DO 'main game loop
        'read mouse data
        WHILE _MOUSEINPUT: WEND

        'read keyboard
        keyb = _KEYHIT

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
                    finishLanding 'a previous drop must settle before the board changes again
                    dragging = 0
                    FOR i = 10 TO 12
                        IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 40 AND peg(i).set <> emptySet$ THEN
                            dragging = i
                            dragX = peg(i).x
                            dragY = peg(i).y
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
                        CASE 3 'leaderboards
                            enterScores = true
                        CASE 4 'quit
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

        'dragged rings trail the cursor and lift off the board
        IF dragging > 0 THEN
            dragX = dragX + (_MOUSEX - dragX) * (1 - .65 ^ frameStep)
            dragY = dragY + (_MOUSEY - dragY) * (1 - .65 ^ frameStep)
            dragLift = clampf(dragLift + frameDt * 8, 0, 1)
        ELSE
            dragLift = 0
        END IF
        IF landing.state AND clock - landing.start >= landing.duration THEN finishLanding

        updateElectric
        IF gameOver = false AND pauseGame = false THEN generateSparkles

        drawElectricConnections
        updateSparkles
        updateBeams
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

        IF pauseGame THEN pauseFade = clampf(pauseFade + frameDt * 6, 0, 1) ELSE pauseFade = clampf(pauseFade - frameDt * 6, 0, 1)
        IF pauseFade > 0 THEN drawPauseOverlay pauseFade

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
            IF gameOver = false AND dragging = 0 AND landing.state = false THEN
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
                modeChanged = true 'QBJS has no GOTO; restart from the outer loop
                EXIT DO
            END IF
        END IF

        IF enterScores THEN
            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(255)
            addParticles _MOUSEX, _MOUSEY, 30, _RGB32(67, 172, 183)
            scoresScreen
            enterScores = false
        END IF

        'limit fps
        _LIMIT 60

        userQuit = false '_EXIT: not available in the browser
        IF keyb = -27 AND gameOver = false THEN EXIT DO
    LOOP UNTIL gameOverDone OR userQuit

    IF modeChanged THEN
        modeChanged = false
    ELSE
        finishLanding
        stopElectricNow
        dragging = 0
        saveGame

        IF userQuit THEN SYSTEM

        endScreen
    END IF
LOOP

FUNCTION clock#
    'seconds since the page loaded (offset so that a zeroed .start is always in the past)
    clock# = Sys.TimeInMillis / 1000 + 1000
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
    DATA "Fantastic","Outstanding","Amazing","Awesome","MEGA","SUPER"
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
        '_DONTBLEND (not supported in QBJS)
        FOR py = 0 TO sz + 7
            FOR px = 0 TO sz + 7
                dx = px - (half + 4)
                dy = py - (half + 4)
                d = SQR(dx * dx + dy * dy)
                e = 0
                IF d < innerR THEN e = innerR - d
                IF d > outerR THEN e = d - outerR
                IF e < 4 AND 77 * (1 - e / 4) >= 1 THEN PSET (px, py), _RGBA32(0, 0, 0, 77 * (1 - e / 4))
            NEXT
        NEXT
        '_BLEND (not supported in QBJS)

        FOR colr = 1 TO UBOUND(ringColor)
            FOR pass = 0 TO 1
                IF pass = 0 THEN bright = 1 ELSE bright = 1.5
                img = _NEWIMAGE(sz, sz, 32)
                _DEST img
                '_DONTBLEND (not supported in QBJS)
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
                '_BLEND (not supported in QBJS)
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
    '_DONTBLEND (not supported in QBJS)
    FOR py = 0 TO 18
        FOR px = 0 TO 16
            ds = dist(px, py, 8, 10)
            sa = 77 * clampf((7 - ds) / 3, 0, 1)
            d = dist(px, py, 8, 8)
            cover = clampf(4.5 - d, 0, 1)
            t = clampf(dist(px, py, 7, 7) / 5, 0, 1)
            IF t < .7 THEN v = lerp(255, 224, t / .7) ELSE v = lerp(224, 160, (t - .7) / .3)
            a = 255 * cover + sa * (1 - cover)
            IF a >= 1 THEN
                v = v * 255 * cover / a
                PSET (px, py), _RGBA32(v, v, v, a)
            END IF
        NEXT
    NEXT
    '_BLEND (not supported in QBJS)
    _DEST prevDest
END SUB

SUB generateCrownIcon
    'antialiased golden crown built from distance fields: three spiked body, jewel-tipped points
    'and a band set with gems, with a dark rim and a soft drop shadow
    DIM px AS INTEGER, py AS INTEGER, prevDest AS LONG
    DIM d AS SINGLE, dBand AS SINGLE, dBall AS SINGLE, dGem AS SINGLE, dShadow AS SINGLE
    DIM r AS SINGLE, g AS SINGLE, b AS SINGLE, a AS SINGLE
    DIM t AS SINGLE, f AS SINGLE, cover AS SINGLE, sheen AS SINGLE, gx AS SINGLE
    DIM fr AS SINGLE, fg AS SINGLE, fb AS SINGLE

    prevDest = _DEST
    crownIcon = _NEWIMAGE(32, 26, 32)
    _DEST crownIcon
    '_DONTBLEND (not supported in QBJS)
    FOR py = 0 TO 25
        FOR px = 0 TO 31
            blendR = 0: blendG = 0: blendB = 0: blendA = 0

            dShadow = crownShape(px - 1, py - 1.5, dBand, dBall)
            blendOver 0, 0, 0, .45 * clampf((2 - dShadow) / 3, 0, 1)

            d = crownShape(px, py, dBand, dBall)
            dBand = crownBand: dBall = crownBall
            blendOver 90, 50, 0, clampf(1.7 - d, 0, 1)

            cover = clampf(.5 - d, 0, 1)
            IF cover > 0 THEN
                'gold with a vertical gradient, a diagonal sheen and a darker rim
                t = clampf((py - 2) / 20, 0, 1)
                fr = lerp(255, 225, t): fg = lerp(240, 150, t): fb = lerp(150, 15, t)
                sheen = EXP(-((px - py * .5 - 8) ^ 2) / 6) * .45
                f = 1 - .3 * clampf(1 + d / 1.5, 0, 1)
                IF dBand < .5 THEN
                    'band: deeper gold with a highlight along its top edge
                    f = f * lerp(1, .85, clampf(.5 - dBand, 0, 1))
                    IF py >= 17 AND py <= 17.9 THEN sheen = sheen + .35
                END IF
                IF dBall < .5 THEN
                    'jewel tips: rounded with a bright specular spot
                    gx = crownBallLight(px, py)
                    f = f * (.9 + .25 * gx)
                    sheen = sheen + gx * gx * .6
                END IF
                fr = clampf(fr * f + 255 * sheen, 0, 255)
                fg = clampf(fg * f + 255 * sheen, 0, 255)
                fb = clampf(fb * f + 255 * sheen, 0, 255)
                blendOver fr, fg, fb, cover
            END IF

            'gems on the band: ruby in the middle, sapphires on the sides
            dGem = dist(px, py, 16, 19.5) - 2
            IF dGem < 1.2 THEN
                blendOver 110, 0, 20, clampf(1.1 - dGem, 0, 1)
                gx = 1 - clampf(dist(px, py, 15.3, 18.8) / 2.4, 0, 1)
                blendOver 220 + 35 * gx, 30 + 200 * gx * gx, 60 + 180 * gx * gx, clampf(.5 - dGem, 0, 1)
            END IF
            FOR f = 10 TO 22 STEP 12
                dGem = dist(px, py, f, 19.5) - 1.3
                IF dGem < 1.2 THEN
                    blendOver 0, 30, 90, clampf(1 - dGem, 0, 1)
                    gx = 1 - clampf(dist(px, py, f - .5, 19) / 1.8, 0, 1)
                    blendOver 60 + 190 * gx * gx, 150 + 100 * gx, 255, clampf(.5 - dGem, 0, 1)
                END IF
            NEXT

            r = blendR: g = blendG: b = blendB: a = blendA
            IF a * 255 >= 1 THEN PSET (px, py), _RGBA32(r, g, b, a * 255)
        NEXT
    NEXT
    '_BLEND (not supported in QBJS)
    _DEST prevDest
END SUB

FUNCTION crownShape! (px AS SINGLE, py AS SINGLE, dBand AS SINGLE, dBall AS SINGLE)
    'signed distance to the whole crown; also returns the distances to the band and to the tip balls
    DIM dPoly AS SINGLE, k AS INTEGER, inside AS _BYTE
    DIM vx(6) AS SINGLE, vy(6) AS SINGLE, j AS INTEGER, qx AS SINGLE, qy AS SINGLE

    vx(0) = 5: vy(0) = 19
    vx(1) = 4: vy(1) = 8
    vx(2) = 10.5: vy(2) = 13.5
    vx(3) = 16: vy(3) = 5
    vx(4) = 21.5: vy(4) = 13.5
    vx(5) = 28: vy(5) = 8
    vx(6) = 27: vy(6) = 19

    dPoly = 1000000000 '1E+09 (QBJS does not parse scientific notation)
    j = 6
    FOR k = 0 TO 6
        dPoly = minf(dPoly, sdSegment(px, py, vx(j), vy(j), vx(k), vy(k)))
        IF (vy(k) > py) <> (vy(j) > py) THEN
            IF px < (vx(j) - vx(k)) * (py - vy(k)) / (vy(j) - vy(k)) + vx(k) THEN inside = NOT inside
        END IF
        j = k
    NEXT
    IF inside THEN dPoly = -dPoly

    'rounded band, centered at (16, 19.5)
    qx = ABS(px - 16) - 11.5 + 1
    qy = ABS(py - 19.5) - 2.5 + 1
    dBand = SQR(maxf(qx, 0) ^ 2 + maxf(qy, 0) ^ 2) + minf(maxf(qx, qy), 0) - 1

    dBall = minf(dist(px, py, 4, 7) - 2.2, dist(px, py, 16, 4) - 2.5)
    dBall = minf(dBall, dist(px, py, 28, 7) - 2.2)

    crownBand = dBand
    crownBall = dBall
    crownShape! = minf(minf(dPoly, dBand), dBall)
END FUNCTION

FUNCTION crownBallLight! (px AS SINGLE, py AS SINGLE)
    'how close (px, py) is to the specular spot of the nearest tip ball (1 = right on it)
    DIM d AS SINGLE

    d = minf(dist(px, py, 3.3, 6.2), dist(px, py, 15.2, 3.1))
    d = minf(d, dist(px, py, 27.3, 6.2))
    crownBallLight! = 1 - clampf(d / 2.2, 0, 1)
END FUNCTION

SUB generateArrowIcon
    'antialiased tutorial arrow pointing down, with a soft glow baked in; one copy per fade level
    'the tip sits at (26, 57.5)
    DIM px AS INTEGER, py AS INTEGER, prevDest AS LONG, k AS INTEGER
    DIM d AS SINGLE, qx AS SINGLE, qy AS SINGLE, dShaft AS SINGLE, dHead AS SINGLE, dTri AS SINGLE
    DIM r AS SINGLE, g AS SINGLE, b AS SINGLE, a AS SINGLE
    DIM t AS SINGLE, f AS SINGLE, cover AS SINGLE, sheen AS SINGLE
    DIM fr AS SINGLE, fg AS SINGLE, fb AS SINGLE
    DIM inside AS _BYTE

    prevDest = _DEST
    FOR k = 0 TO UBOUND(arrowIcon)
        arrowIcon(k) = _NEWIMAGE(52, 70, 32)
    NEXT
    FOR py = 0 TO 69
        FOR px = 0 TO 51
            'shaft: rounded box from y = 10 to 40
            qx = ABS(px - 26) - 6 + 3
            qy = ABS(py - 25) - 15 + 3
            dShaft = SQR(maxf(qx, 0) ^ 2 + maxf(qy, 0) ^ 2) + minf(maxf(qx, qy), 0) - 3

            'head: triangle with rounded corners
            dTri = minf(sdSegment(px, py, 10, 36, 42, 36), sdSegment(px, py, 42, 36, 26, 56))
            dTri = minf(dTri, sdSegment(px, py, 26, 56, 10, 36))
            inside = py > 36 AND ABS(px - 26) < (56 - py) * 16 / 20
            IF inside THEN dTri = -dTri
            dHead = dTri - 1.5
            d = minf(dShaft, dHead)

            blendR = 0: blendG = 0: blendB = 0: blendA = 0
            IF d > 0 THEN blendOver 255, 230, 80, .4 * EXP(-d / 3.5)
            blendOver 70, 45, 0, clampf(2 - d, 0, 1) * .9

            cover = clampf(.5 - d, 0, 1)
            IF cover > 0 THEN
                t = clampf((py - 10) / 48, 0, 1)
                fr = 255: fg = lerp(255, 195, t): fb = lerp(175, 30, t)
                'rounded look: lit from the upper left, darker towards the rim
                sheen = clampf((26 - px) / 10, 0, 1) * .25 * clampf(-d / 2, 0, 1)
                f = 1 - .25 * clampf(1 + d / 2.5, 0, 1)
                IF dShaft < 0 AND px >= 22 AND px <= 23 AND py > 13 AND py < 36 THEN sheen = sheen + .45
                fr = clampf(fr * f + 255 * sheen, 0, 255)
                fg = clampf(fg * f + 255 * sheen, 0, 255)
                fb = clampf(fb * f + 255 * sheen, 0, 255)
                blendOver fr, fg, fb, cover
            END IF

            r = blendR: g = blendG: b = blendB: a = blendA
            IF a * 255 >= 1 THEN
                FOR k = 1 TO UBOUND(arrowIcon)
                    _DEST arrowIcon(k)
                    '_DONTBLEND (not supported in QBJS)
                    PSET (px, py), _RGBA32(r, g, b, a * 255 * k / UBOUND(arrowIcon))
                NEXT
            END IF
        NEXT
    NEXT
    FOR k = 0 TO UBOUND(arrowIcon)
        _DEST arrowIcon(k)
        '_BLEND (not supported in QBJS)
    NEXT
    _DEST prevDest
END SUB

FUNCTION sdSegment! (px AS SINGLE, py AS SINGLE, ax AS SINGLE, ay AS SINGLE, bx AS SINGLE, by AS SINGLE)
    'distance from (px, py) to the segment a-b
    DIM h AS SINGLE, dx AS SINGLE, dy AS SINGLE

    dx = bx - ax
    dy = by - ay
    h = clampf(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    sdSegment! = dist(px, py, ax + dx * h, ay + dy * h)
END FUNCTION

SUB blendOver (sr AS SINGLE, sg AS SINGLE, sb AS SINGLE, sa AS SINGLE)
    'composite color (sr, sg, sb) with alpha sa (0-1) over the accumulated (blendR, blendG, blendB, blendA)
    DIM na AS SINGLE

    IF sa <= 0 THEN EXIT SUB
    na = sa + blendA * (1 - sa)
    blendR = (sr * sa + blendR * blendA * (1 - sa)) / na
    blendG = (sg * sa + blendG * blendA * (1 - sa)) / na
    blendB = (sb * sa + blendB * blendA * (1 - sa)) / na
    blendA = na
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
    '_DONTBLEND (not supported in QBJS)
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
    '_BLEND (not supported in QBJS)
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

SUB updateFrameTime
    'seconds since the previous frame; long gaps (loading, screen changes) count as one frame
    STATIC lastFrame AS DOUBLE

    frameDt = clock - lastFrame
    lastFrame = clock
    IF frameDt <= 0 OR frameDt > .25 THEN frameDt = 1 / 60
    frameStep = frameDt * 60
END SUB

SUB drawBackground
    'every screen draws the background first, so this also starts the frame
    DIM t AS DOUBLE, i AS INTEGER, a AS SINGLE, hue1 AS SINGLE, hue2 AS SINGLE
    DIM starDrag AS SINGLE, ambientDrag AS SINGLE

    updateFrameTime
    starDrag = .92 ^ frameStep
    ambientDrag = .95 ^ frameStep
    t = clock
    '_DONTBLEND (not supported in QBJS)
    _PUTIMAGE (0, 0), bg
    '_BLEND (not supported in QBJS)

    'slowly shifting hue
    hue1 = 250 + SIN(t / 5) * 20
    hue2 = 270 + COS(t * .7 / 5) * 20
    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), hsl((hue1 + hue2) / 2, .6, .14, 40), BF

    'falling stars
    FOR i = 1 TO UBOUND(star)
        star(i).y = star(i).y + (star(i).speed + star(i).yv) * frameStep
        star(i).x = star(i).x + star(i).xv * frameStep
        star(i).xv = star(i).xv * starDrag
        star(i).yv = star(i).yv * starDrag

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
        ambient(i).x = ambient(i).x + ambient(i).xv * frameStep
        ambient(i).y = ambient(i).y + ambient(i).yv * frameStep
        ambient(i).life = ambient(i).life + .01 * frameStep
        ambient(i).xv = ambient(i).xv * ambientDrag
        ambient(i).yv = ambient(i).yv * ambientDrag

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
    DIM introRings(1 TO 30) AS gameObject
    DIM px(1 TO 30) AS SINGLE, py(1 TO 30) AS SINGLE, connected(1 TO 30) AS _BYTE
    DIM introTimer AS DOUBLE, t AS SINGLE, d AS SINGLE, intensity AS SINGLE, glowI AS SINGLE, banged AS _BYTE

    FOR i = 1 TO UBOUND(introRings)
        introRings(i).xa = RND * _PI(2)
        introRings(i).xv = RND * 5
        introRings(i).size = RND * 30 + 50
        introRings(i).w = _CEIL(RND * 3) 'ring size
        introRings(i).text = _CEIL(RND * UBOUND(ringColor)) 'ring color
    NEXT

    CONST INTRO_BANG = 1 'moment the implosion converges and the rings burst out

    introTimer = clock
    addImplosion _WIDTH / 2, _HEIGHT / 2, 400, introTimer + INTRO_BANG
    banged = false
    applyMusicVolume
    DO
        t = clock - introTimer
        drawBackground

        IF t >= INTRO_BANG AND banged = false THEN
            bigBang _WIDTH / 2, _HEIGHT / 2
            banged = true
        END IF

        FOR i = 1 TO UBOUND(introRings)
            IF banged THEN
                introRings(i).xa = introRings(i).xa + .01 * frameStep
                introRings(i).size = introRings(i).size + introRings(i).xv * frameStep
            END IF
            px(i) = _WIDTH / 2 + COS(introRings(i).xa) * introRings(i).size
            py(i) = _HEIGHT / 2 + SIN(introRings(i).xa) * introRings(i).size
            connected(i) = false
        NEXT

        'electric bolts between nearby rings of the same color
        IF t > INTRO_BANG + .4 AND t < 5 THEN
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
            IF banged = false THEN EXIT FOR
            IF connected(i) THEN
                drawRingAt px(i), py(i), introRings(i).w, introRings(i).text, glowI, true, 1
            ELSE
                drawRingAt px(i), py(i), introRings(i).w, introRings(i).text, 0, true, 1
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

        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, 0, .7, 255, 0), 0, 255)), BF
        IF banged THEN LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, INTRO_BANG, INTRO_BANG + .35, 200, 0), 0, 255)), BF 'bang flash
        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, clampf(map(t, 4, 5, 0, 255), 0, 255)), BF
        IF t > 5 THEN LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(0, 0, 0, clampf(map(t, 5, 6, 0, 255), 0, 255)), BF 'QBJS draws alpha 0 black as solid black

        WHILE _MOUSEINPUT: WEND
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL t > 6 OR _KEYHIT OR _MOUSEBUTTON(1)
END SUB

SUB generateNewSets
    DIM i AS INTEGER
    DIM j AS INTEGER

    IF gameOver OR landing.state THEN EXIT SUB 'wait for dropped rings to settle on the board

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
                            peg(i).set = replaceAt$(peg(i).set, j * 2 - 1, MKI$(_CEIL(RND * maxColors)))
                        END IF
                    END IF
                NEXT
            LOOP WHILE peg(i).set = emptySet$ 'can't be empty
            IF INSTR(peg(i).set, MKI$(-1)) = 0 THEN 'can't be full
                j = _CEIL(RND * 3)
                peg(i).set = replaceAt$(peg(i).set, j * 2 - 1, MKI$(-1))
            END IF
        NEXT

        'sets pop into the spawn area one after the other (see drawRings)
        animation(6).start = clock
        FOR i = 10 TO 12
            addShockwave peg(i).x, peg(i).y, 4, .04, _RGB32(150, 200, 255), (i - 10) * SPAWN_STAGGER + .15
            addSparkBurst peg(i).x, peg(i).y, 18, .3, _RGB32(255), (i - 10) * SPAWN_STAGGER + .15
        NEXT
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
        'rings fly onto the peg first; finishLanding places them
        landing.state = true
        landing.x = dragX
        landing.y = dragY
        landing.set = peg(dragging).set
        landing.text = target
        landing.start = clock
        landing.duration = LAND_TIME
        peg(dragging).set = emptySet$
        stopElectricNow
    ELSE
        'misplaced rings bounce back to the spawn area
        returnAnim(dragging).state = true
        returnAnim(dragging).x = dragX
        returnAnim(dragging).y = dragY
        returnAnim(dragging).start = clock
        returnAnim(dragging).duration = .4
    END IF
END SUB

SUB finishLanding
    'dropped rings reach their peg: place them and look for matches
    DIM j AS INTEGER, target AS INTEGER

    IF landing.state = false THEN EXIT SUB
    landing.state = false
    target = landing.text

    playSfx woodblock, 1
    FOR j = 1 TO 3
        IF slotColor(landing.set, j) > 0 THEN
            peg(target).set = replaceAt$(peg(target).set, j * 2 - 1, MID$(landing.set, j * 2 - 1, 2))
            addRipple peg(target).x, peg(target).y, slotColor(landing.set, j)
        END IF
    NEXT
    pegPop(target) = clock
    disturbParticles peg(target).x, peg(target).y, .5, 150
    checkMatches target
END SUB

SUB checkMatches (target AS INTEGER)
    DIM r(1 TO 3) AS INTEGER, previousScore AS _UNSIGNED LONG, increase AS LONG
    DIM s$, found1 AS INTEGER, found2 AS INTEGER, scored AS _BYTE
    DIM i AS INTEGER, j AS INTEGER, k AS INTEGER, m AS INTEGER, p AS INTEGER, checks AS INTEGER
    DIM nextPeg(0 TO 2) AS INTEGER

    FOR j = 1 TO 9
        'prepare backup copies for deletion tagging
        copyObject del(j), peg(j)
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
        animation(8).r = _RED32(ringColor(r(1)))
        animation(8).g = _GREEN32(ringColor(r(1)))
        animation(8).b = _BLUE32(ringColor(r(1)))
        del(target).set = emptySet$
        FOR j = 1 TO 3
            addDyingRing peg(target).x, peg(target).y, j, r(1), (3 - j) * .04 'inner ring goes first
        NEXT
        addShockwave peg(target).x, peg(target).y, 9, .03, ringColor(r(1)), 0
        addShockwave peg(target).x, peg(target).y, 6, .035, _RGB32(255), .06
        addSparkBurst peg(target).x, peg(target).y, 70, .55, ringColor(r(1)), 0
        addSparkBurst peg(target).x, peg(target).y, 30, .55, _RGB32(255), 0
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
                    'match! clear all rings of the same color in this group of pegs,
                    'one peg after the other, following the beam
                    addBeam peg(r(i)).x, peg(r(i)).y, peg(r(i) + nextPeg(2)).x, peg(r(i) + nextPeg(2)).y, ringColor(CVI(s$))
                    FOR k = 0 TO 2
                        p = r(i) + nextPeg(k)
                        found1 = INSTR(del(p).set, s$)
                        DO WHILE found1
                            del(p).set = replaceAt$(del(p).set, found1, MKI$(-1))
                            addDyingRing peg(p).x, peg(p).y, (found1 + 1) \ 2, CVI(s$), k * .06
                            addSparkBurst peg(p).x, peg(p).y, 23, .45, ringColor(CVI(s$)), k * .06
                            addSparkBurst peg(p).x, peg(p).y, 10, .45, _RGB32(255), k * .06
                            score = score + multiplier
                            found1 = INSTR(del(p).set, s$)
                        LOOP
                        addShockwave peg(p).x, peg(p).y, 7, .035, ringColor(CVI(s$)), k * .06
                        disturbParticles peg(p).x, peg(p).y, 2.5, 300
                    NEXT
                    scored = true
                    totalMatches = totalMatches + 1
                    animation(0).start = clock
                    animation(8).r = _RED32(ringColor(CVI(s$)))
                    animation(8).g = _GREEN32(ringColor(CVI(s$)))
                    animation(8).b = _BLUE32(ringColor(CVI(s$)))
                END IF

                IF scored THEN del(r(i)).set = replaceAt$(del(r(i)).set, j * 2 - 1, MKI$(-1))
            NEXT
        NEXT
    NEXT

    FOR j = 1 TO 9
        'perform deletion, if any items were marked = MKI$(-1)
        copyObject peg(j), del(j)
    NEXT

    IF previousScore < score THEN
        increase = score - previousScore
        IF increase > 5 THEN
            'big scores shake the score, flash the screen and, for long combos, zoom in
            scoreShake = increase / 10
            IF scoreShake > 2 THEN scoreShake = 2
            screenFlash = .4
            IF multiplier > 3 THEN
                screenZoom = 1.05 + (multiplier - 3) * .01
                zoomX = peg(target).x
                zoomY = peg(target).y
            END IF
        END IF

        playSfx wooshSound, .5

        multiplier = multiplier + 1

        IF multiplier - 1 <= UBOUND(comboSound) THEN
            playSfx comboSound(multiplier - 1), 1
        ELSE
            playSfx comboSound(UBOUND(comboSound)), 1
        END IF

        comboMsg$(1) = megaComboMsg$(_CEIL(RND * UBOUND(megaComboMsg$)))
        comboMsg$(2) = LTRIM$(STR$(multiplier)) + "x combo!"
        animation(7).start = clock
        animation(8).start = clock
        animation(8).x = peg(target).x 'flight origin
        animation(8).y = peg(target).y - 30
        animation(8).xa = increase
        animation(8).size = .75 'flight time
        animation(8).duration = 5

        addComboBurst _WIDTH / 2, _HEIGHT / 2, 30 + multiplier * 10
    ELSE
        IF multiplier > 1 THEN
            'combo broken: its label falls off the HUD
            comboLost = multiplier
            comboLostStart = clock
        END IF
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
    finishLanding
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
        electricVolume = clampf(sfxVolume * 1.2, 0, 1)
        electricTarget = electricVolume
    END IF
END SUB

SUB explodeSpawnedRings
    DIM i AS INTEGER, j AS INTEGER, colr AS INTEGER, first AS INTEGER, delay AS SINGLE

    exploded = true
    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN
            first = 0
            FOR j = 1 TO 3
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN
                    IF first = 0 THEN first = colr
                    addSparkBurst peg(i).x, peg(i).y, 120, .8, ringColor(colr), 0
                END IF
            NEXT
            addSparkBurst peg(i).x, peg(i).y, 60, .8, _RGB32(255), 0
            addShockwave peg(i).x, peg(i).y, 12, .025, ringColor(first), 0
            addShockwave peg(i).x, peg(i).y, 8, .03, _RGB32(255), .06
            disturbParticles peg(i).x, peg(i).y, 3, 250
            peg(i).set = emptySet$
            returnAnim(i).state = false
        END IF
    NEXT

    'the board follows, peg by peg from the center out
    FOR i = 1 TO 9
        IF peg(i).set <> emptySet$ THEN
            delay = .15 + dist(peg(i).x, peg(i).y, peg(5).x, peg(5).y) / 700
            FOR j = 1 TO 3
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN
                    addDyingRing peg(i).x, peg(i).y, j, colr, delay
                    addSparkBurst peg(i).x, peg(i).y, 15, .4, ringColor(colr), delay
                END IF
            NEXT
            addShockwave peg(i).x, peg(i).y, 5, .04, _RGB32(255), delay
            peg(i).set = emptySet$
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
    FOR i = 1 TO UBOUND(dying)
        dying(i).state = false
    NEXT
    FOR i = 1 TO UBOUND(beam)
        beam(i).state = false
    NEXT
    landing.state = false
    comboLostStart = 0
    scorePop = 0
    scorePopV = 0
    matchCount = 0
    lastMatchCount = 0
    fadingOut = false
    showTutorial = false
    tutorialTime = 0
    pauseGame = false
END SUB

SUB putScaled (img AS LONG, x AS SINGLE, y AS SINGLE, ox AS SINGLE, oy AS SINGLE, s AS SINGLE)
    'draw img with its top-left corner at offset (ox, oy) from (x, y), scaled around (x, y)
    IF s = 1 THEN
        _PUTIMAGE (x + ox, y + oy), img
    ELSE
        'putImageStep x + ox * s, y + oy * s, _WIDTH(img) * s - 1, _HEIGHT(img) * s - 1, img
        _PUTIMAGE (x + ox * s, y + oy * s)-STEP(_WIDTH(img) * s - 1, _HEIGHT(img) * s - 1), img
    END IF
END SUB

SUB drawRingAt (x AS SINGLE, y AS SINGLE, slot AS INTEGER, colr AS INTEGER, glow AS SINGLE, withShadow AS _BYTE, scale AS SINGLE)
    'ringLift > 0 pushes the shadow away, for rings held above the board
    DIM half AS INTEGER, outerR AS SINGLE, k AS INTEGER, n AS INTEGER
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER

    IF scale <= .02 THEN EXIT SUB
    outerR = slot * 14 * scale
    half = slot * 14 + 2
    r = _RED32(ringColor(colr))
    g = _GREEN32(ringColor(colr))
    b = _BLUE32(ringColor(colr))

    IF withShadow THEN putScaled ringShadow(slot), x + ringLift * 6, y + ringLift * 10, -half - 4, -half - 1, scale

    IF glow > 0 THEN
        'pulsing glow for rings being dragged or about to match
        FOR k = 1 TO 10
            CIRCLE (x, y), outerR + k, _RGBA32(r, g, b, glow * 140 * (1 - k / 11))
        NEXT
        CIRCLE (x, y), outerR + 8 + glow * 12, _RGBA32(r, g, b, (.2 + glow * .2) * 255)
        CIRCLE (x, y), outerR + 9 + glow * 12, _RGBA32(r, g, b, (.2 + glow * .2) * 255)
        putScaled circleGlow(colr, slot), x, y, -half, -half, scale
    ELSE
        IF multiplier > 2 THEN
            'neon glow for high multipliers
            n = 4 + multiplier
            IF n > 12 THEN n = 12
            FOR k = 1 TO n
                CIRCLE (x, y), outerR + k, _RGBA32(r, g, b, 90 * (1 - k / (n + 1)))
            NEXT
        END IF
        putScaled circleImage(colr, slot), x, y, -half, -half, scale
    END IF
END SUB

SUB drawRings
    DIM i AS INTEGER, j AS INTEGER, colr AS INTEGER
    DIM x AS SINGLE, y AS SINGLE, p AS SINGLE, e AS SINGLE, t AS SINGLE
    DIM glowI AS SINGLE, shake AS SINGLE, scale AS SINGLE, now AS DOUBLE

    now = clock
    glowI = .5 + SIN(now / .15) * .3

    IF gameOver AND exploded = false THEN
        t = now - gameOverStart
        IF t >= GAME_OVER_GLOW THEN shake = (t - GAME_OVER_GLOW) / GAME_OVER_TREMBLE * 10
    END IF

    FOR i = 1 TO 12
        IF i = dragging THEN _CONTINUE 'drawn last, above everything else
        IF i >= 10 THEN
            IF returnAnim(i).state THEN _CONTINUE
        END IF

        x = peg(i).x
        y = peg(i).y
        scale = 1

        IF i <= 9 THEN
            'squash after rings land on this peg
            p = (now - pegPop(i)) / .18
            IF p >= 0 AND p < 1 THEN scale = 1 + .1 * SIN(p * _PI) * (1 - p * .5)
        ELSEIF animation(6).start > 0 THEN
            'new sets pop in one after the other, rising into place
            p = (now - animation(6).start - (i - 10) * SPAWN_STAGGER) / .35
            IF p < 0 THEN _CONTINUE
            IF p < 1 THEN
                scale = easeOutBack(p)
                y = y + (1 - easeOutCubic(p)) * 60
            END IF
        END IF

        IF shake > 0 AND i >= 10 THEN
            x = x + SIN(t * 30 + i) * shake
            y = y + COS(t * 39 + i) * shake
        END IF

        FOR j = 3 TO 1 STEP -1
            colr = slotColor(peg(i).set, j)
            IF colr > 0 THEN
                IF isMatching(i, j) THEN
                    drawRingAt x, y, j, colr, glowI, true, scale
                ELSE
                    drawRingAt x, y, j, colr, 0, true, scale
                END IF
            END IF
        NEXT
    NEXT

    drawDyingRings

    'rings bouncing back to the spawn area are drawn on top
    FOR i = 10 TO 12
        IF returnAnim(i).state THEN
            p = (now - returnAnim(i).start) / returnAnim(i).duration
            IF p >= 1 THEN
                returnAnim(i).state = false
                p = 1
            END IF
            e = easeOutCubic(p)
            x = returnAnim(i).x + (peg(i).x - returnAnim(i).x) * e
            y = returnAnim(i).y + (peg(i).y - returnAnim(i).y) * e
            ringLift = 1 - e
            FOR j = 3 TO 1 STEP -1
                colr = slotColor(peg(i).set, j)
                IF colr > 0 THEN drawRingAt x, y, j, colr, 0, true, 1 + .06 * (1 - e)
            NEXT
            ringLift = 0
        END IF
    NEXT

    'rings dropping onto their peg speed up as they fall in
    IF landing.state THEN
        p = clampf((now - landing.start) / landing.duration, 0, 1)
        e = p * p
        x = landing.x + (peg(landing.text).x - landing.x) * e
        y = landing.y + (peg(landing.text).y - landing.y) * e
        ringLift = 1 - e
        FOR j = 3 TO 1 STEP -1
            colr = slotColor(landing.set, j)
            IF colr > 0 THEN drawRingAt x, y, j, colr, 0, true, 1 + .06 * (1 - e)
        NEXT
        ringLift = 0
    END IF

    'the dragged set floats above the board, trailing the cursor
    IF dragging > 0 THEN
        ringLift = dragLift
        FOR j = 3 TO 1 STEP -1
            colr = slotColor(peg(dragging).set, j)
            IF colr > 0 THEN drawRingAt dragX, dragY, j, colr, glowI, true, 1 + .06 * dragLift
        NEXT
        ringLift = 0
    END IF
END SUB

SUB addDyingRing (x AS SINGLE, y AS SINGLE, slot AS INTEGER, colr AS INTEGER, delay AS SINGLE)
    'a ring that has already left the board, shown swelling and fading away
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(dying)
        IF dying(i).state = false THEN
            dying(i).state = true
            dying(i).x = x
            dying(i).y = y
            dying(i).slot = slot
            dying(i).colr = colr
            dying(i).start = clock + delay
            EXIT SUB
        END IF
    NEXT
END SUB

SUB drawDyingRings
    DIM i AS INTEGER, k AS INTEGER, p AS SINGLE, s AS SINGLE, a AS SINGLE
    DIM innerR AS SINGLE, outerR AS SINGLE, c AS _UNSIGNED LONG

    FOR i = 1 TO UBOUND(dying)
        IF dying(i).state THEN
            p = (clock - dying(i).start) / DYING_TIME
            IF p < 0 THEN
                'waiting for its turn: still looks like a regular ring
                drawRingAt dying(i).x, dying(i).y, dying(i).slot, dying(i).colr, 0, true, 1
            ELSEIF p >= 1 THEN
                dying(i).state = false
            ELSE
                s = 1 + .4 * easeOutCubic(p)
                IF p < .2 THEN
                    'brief bright flash before fading
                    putScaled circleGlow(dying(i).colr, dying(i).slot), dying(i).x, dying(i).y, -(dying(i).slot * 14 + 2), -(dying(i).slot * 14 + 2), s
                ELSE
                    a = (1 - (p - .2) / .8) * 230
                    c = lighter(ringColor(dying(i).colr), 60)
                    outerR = dying(i).slot * 14 * s
                    innerR = dying(i).slot * (8 + dying(i).slot) * s
                    FOR k = innerR TO outerR
                        CIRCLE (dying(i).x, dying(i).y), k, _RGBA32(_RED32(c), _GREEN32(c), _BLUE32(c), a)
                    NEXT
                    CIRCLE (dying(i).x, dying(i).y), outerR + 1, _RGBA32(255, 255, 255, a * .5)
                END IF
            END IF
        END IF
    NEXT
END SUB

SUB addBeam (x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE, c AS _UNSIGNED LONG)
    DIM i AS INTEGER
    FOR i = 1 TO UBOUND(beam)
        IF beam(i).state = false THEN
            beam(i).state = true
            beam(i).x1 = x1
            beam(i).y1 = y1
            beam(i).x2 = x2
            beam(i).y2 = y2
            beam(i).c = c
            beam(i).start = clock
            EXIT SUB
        END IF
    NEXT
END SUB

SUB updateBeams
    'line matches: a beam sweeps through the matched pegs, then thins out
    DIM i AS INTEGER, p AS SINGLE, head AS SINGLE, fade AS SINGLE, w AS SINGLE, d AS SINGLE
    DIM ux AS SINGLE, uy AS SINGLE, sx AS SINGLE, sy AS SINGLE, ex AS SINGLE, ey AS SINGLE
    DIM hx AS SINGLE, hy AS SINGLE, r AS INTEGER, g AS INTEGER, b AS INTEGER

    FOR i = 1 TO UBOUND(beam)
        IF beam(i).state THEN
            p = (clock - beam(i).start) / BEAM_TIME
            IF p >= 1 THEN
                beam(i).state = false
            ELSE
                d = dist(beam(i).x1, beam(i).y1, beam(i).x2, beam(i).y2)
                IF d < 1 THEN d = 1
                ux = (beam(i).x2 - beam(i).x1) / d
                uy = (beam(i).y2 - beam(i).y1) / d
                sx = beam(i).x1 - ux * 60: sy = beam(i).y1 - uy * 60
                ex = beam(i).x2 + ux * 60: ey = beam(i).y2 + uy * 60

                head = easeOutCubic(clampf(p / .3, 0, 1))
                hx = sx + (ex - sx) * head
                hy = sy + (ey - sy) * head
                fade = 1 - clampf((p - .3) / .7, 0, 1)
                w = 3 + 11 * fade
                r = _RED32(beam(i).c): g = _GREEN32(beam(i).c): b = _BLUE32(beam(i).c)

                thickLine sx, sy, hx, hy, w + 14, _RGBA32(r, g, b, fade * 45)
                thickLine sx, sy, hx, hy, w, _RGBA32(r, g, b, fade * 170)
                thickLine sx, sy, hx, hy, w / 3 + 1, _RGBA32(255, 255, 255, fade * 230)
                drawBolt sx, sy, hx, hy, 10, 20, 1.5, fade * .6
                IF p < .3 THEN CircleFill hx, hy, 6 + 6 * (1 - p / .3), _RGBA32(255, 255, 255, 200)
            END IF
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
        IF slotColor(peg(drg).set, j) > 0 THEN sim(target) = replaceAt$(sim(target), j * 2 - 1, MID$(peg(drg).set, j * 2 - 1, 2))
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
        copyMatch oldMatch(i), match(i)
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
        IF (clampf(1 - d / 300, 0, 1) ^ 2) > .3 AND sfxVolume > 0 THEN electricTarget = clampf(sfxVolume * .9, 0, 1)
    ELSE
        IF prevCount > 0 AND fadingOut = false THEN
            fadingOut = true
            fadeOutStart = clock
            FOR i = 1 TO prevCount
                copyMatch lastMatch(i), oldMatch(i)
            NEXT
            lastMatchCount = prevCount
            lastMatchTarget = matchTarget
            lastMatchDrag = dragging
        END IF
        electricTarget = 0
    END IF

    IF gameOver AND exploded = false THEN electricTarget = clampf(sfxVolume * 1.2, 0, 1)
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
    'results are returned in matchPosX, matchPosY and matchPosDragged
    isDragged = false
    x = peg(mt.peg).x
    y = peg(mt.peg).y
    IF drg >= 10 AND mt.peg = target THEN
        IF slotColor(peg(drg).set, mt.slot) > 0 THEN
            x = dragX
            y = dragY
            isDragged = true
        END IF
    END IF
    matchPosX = x
    matchPosY = y
    matchPosDragged = isDragged
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
                x1 = matchPosX: y1 = matchPosY: d1 = matchPosDragged
                getMatchPos mlist(b), target, drg, x2, y2, d2
                x2 = matchPosX: y2 = matchPosY: d2 = matchPosDragged
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
    IF RND >= .15 * fadeIn * frameStep THEN EXIT SUB

    FOR i = 1 TO matchCount
        getMatchPos match(i), matchTarget, dragging, x, y, isDragged
        x = matchPosX: y = matchPosY: isDragged = matchPosDragged
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
            sparkle(i).x = sparkle(i).x + sparkle(i).xv * frameStep
            sparkle(i).y = sparkle(i).y + sparkle(i).yv * frameStep
            sparkle(i).life = sparkle(i).life - .04 * frameStep
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
            ripple(i).radius = ripple(i).radius + 4 * frameStep
            ripple(i).life = ripple(i).life - .02 * frameStep
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
    DIM i AS INTEGER, now AS DOUBLE, p AS SINGLE, col AS _UNSIGNED LONG
    DIM tt AS SINGLE, scale AS SINGLE, alpha AS SINGLE, yOff AS SINGLE, bounce AS SINGLE
    DIM tx AS SINGLE, ty AS SINGLE, cx AS SINGLE, cy AS SINGLE
    DIM e AS SINGLE, u AS SINGLE, x AS SINGLE, y AS SINGLE

    now = clock
    FOR i = 0 TO UBOUND(animation)
        IF animation(i).start > 0 AND now - animation(i).start <= animation(i).duration THEN
            p = (now - animation(i).start) / animation(i).duration
            SELECT CASE i
                CASE 0 'board flash
                    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, map(p, 0, 1, 100, 0)), BF
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
                        drawScaledText comboMsg$(1), _WIDTH / 2, cy - 26, 2, scale * 1.15, _RGBA32(255, 255, 255, alpha * 255), _RGBA32(255, 85, 0, alpha * 200), 0
                        drawScaledText comboMsg$(2), _WIDTH / 2, cy + 22, 3, scale, _RGBA32(255, 255, 0, alpha * 255), _RGBA32(255, 0, 0, alpha * 200), 0
                    ELSE
                        drawScaledText comboMsg$(2), _WIDTH / 2, cy, 3, scale, _RGBA32(255, 255, 0, alpha * 255), _RGBA32(255, 0, 0, alpha * 200), 0
                    END IF
                CASE 8 'score increase: arcs up and over into the score panel
                    tx = scoreTargetX
                    ty = scoreTargetY
                    tt = (now - animation(8).start) / animation(8).size
                    col = _RGB32(animation(8).r, animation(8).g, animation(8).b)
                    IF tt >= 1 THEN
                        animation(8).start = 0
                        kickScore 3 + clampf(animation(8).xa / 10, 0, 5)
                        scoreShake = 1
                        addSparkBurst tx, ty, 30, .35, col, 0
                        addShockwave tx, ty, 5, .04, col, 0
                    ELSE
                        e = tt * tt * (3 - 2 * tt)
                        cx = (animation(8).x + tx) / 2
                        cy = animation(8).y
                        IF ty < cy THEN cy = ty
                        cy = cy - 100
                        u = 1 - e
                        x = u * u * animation(8).x + 2 * u * e * cx + e * e * tx
                        y = u * u * animation(8).y + 2 * u * e * cy + e * e * ty
                        scale = 1.3 - .7 * e
                        IF tt < .15 THEN scale = scale * easeOutBack(tt / .15)
                        drawScaledText LTRIM$(STR$(animation(8).xa)), x, y, 4, scale, _RGB32(255), col, 0
                    END IF
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
    scoreTargetY! = 111 + fontHeightLarge(3) / 2
END FUNCTION

SUB kickScore (amount AS SINGLE)
    'push the score panel's spring; it overshoots and settles back
    scorePopV = scorePopV + amount
END SUB

SUB drawScore (s$, x AS SINGLE, y AS SINGLE, scale AS SINGLE)
    'score with a cyan halo, scaled from its left edge around its vertical center
    DIM img AS LONG, prevDest AS LONG, w AS INTEGER, h AS INTEGER

    w = printWidthLarge(s$, 3) + 4
    h = fontHeightLarge(3) + 4
    prevDest = _DEST
    img = _NEWIMAGE(w, h, 32)
    _DEST img
    _PRINTMODE _KEEPBACKGROUND
    COLOR _RGBA32(0, 255, 255, clampf(40 + scoreShake * 40, 0, 255))
    printLarge 0, 2, s$, 3
    printLarge 4, 2, s$, 3
    printLarge 2, 0, s$, 3
    printLarge 2, 4, s$, 3
    COLOR _RGB32(255)
    printLarge 2, 2, s$, 3
    _DEST prevDest

    IF ABS(scale - 1) < .005 THEN
        _PUTIMAGE (x - 2, y - 2), img
    ELSE
        'putImageStep x - 2 * scale, y + h / 2 - 2 - h * scale / 2, w * scale - 1, h * scale - 1, img
        _PUTIMAGE (x - 2 * scale, y + h / 2 - 2 - h * scale / 2)-STEP(w * scale - 1, h * scale - 1), img
    END IF
    _FREEIMAGE img
END SUB

SUB drawHUD
    DIM t AS DOUBLE, glow AS SINGLE, k AS INTEGER, sx AS SINGLE, sy AS SINGLE, pulse AS SINGLE, tt AS SINGLE

    t = clock

    'high score panel
    glow = SIN(t / .5) * .3 + .7
    FOR k = 1 TO 5
        roundRectLine 15 - k, 15 - k, 200 + k * 2, 50 + k * 2, 8 + k, _RGBA32(255, 215, 0, 40 * glow * (1 - k / 6))
    NEXT
    roundRectFill 15, 15, 200, 50, 8, _RGBA32(255, 215, 0, 38), _RGBA32(184, 134, 11, 26)
    roundRectLine 15, 15, 200, 50, 8, _RGBA32(255, 215, 0, 102)
    roundRectLine 16, 16, 198, 48, 7, _RGBA32(255, 215, 0, 102)
    _PUTIMAGE (19, 27), crownIcon

    'every few seconds a glint twinkles on the crown's center jewel
    tt = t - INT(t / 4) * 4
    IF tt < .6 THEN
        pulse = SIN(tt / .6 * _PI)
        thickLine 34 - 6 * pulse, 30, 36 + 6 * pulse, 30, 1, _RGBA32(255, 255, 230, 220 * pulse)
        thickLine 35, 29 - 6 * pulse, 35, 31 + 6 * pulse, 1, _RGBA32(255, 255, 230, 220 * pulse)
        CircleFill 35, 30, 1, _RGBA32(255, 255, 255, 255 * pulse)
    END IF

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

    'score pops (springs) when increasing; its halo brightens
    drawScore LTRIM$(STR$(INT(visibleScore))), 22, 111, clampf(1 + scorePop, .7, 1.6)

    'multiplier with pulse animation
    IF multiplier > 1 THEN
        pulse = SIN(t / .2) * .15 + 1
        drawScaledText "x" + LTRIM$(STR$(multiplier)) + " COMBO!", 22, 177, 1, 1.25 * pulse, _RGB32(255, 85, 85), _RGBA32(255, 0, 0, 150), 1
    ELSEIF comboLostStart > 0 AND t - comboLostStart < .7 THEN
        'a broken combo shudders, then drops off the panel
        tt = (t - comboLostStart) / .7
        sx = 22
        IF tt < .3 THEN sx = sx + SIN(tt * 80) * 4 * (1 - tt / .3)
        sy = 177 + 320 * tt * tt
        drawScaledText "x" + LTRIM$(STR$(comboLost)) + " COMBO!", sx, sy, 1, 1.25 * (1 - .3 * tt), _RGBA32(200, 90, 90, (1 - tt) * 255), _RGBA32(80, 0, 0, (1 - tt) * 150), 1
    END IF

    doButtons
END SUB

SUB drawTutorial
    DIM i AS INTEGER, target AS INTEGER, ax AS SINGLE, ay AS SINGLE, a AS SINGLE
    DIM bounce AS SINGLE, s AS SINGLE

    'fades in when it is due and out as soon as the player starts dragging
    IF showTutorial AND gameOver = false THEN
        tutorialFade = clampf(tutorialFade + frameDt * 4, 0, 1)
    ELSE
        tutorialFade = clampf(tutorialFade - frameDt * 6, 0, 1)
    END IF
    IF tutorialFade <= 0 THEN EXIT SUB

    FOR i = 10 TO 12
        IF peg(i).set <> emptySet$ THEN target = i: EXIT FOR
    NEXT
    IF target = 0 THEN EXIT SUB

    'bouncing arrow pointing at the spawn area
    'it hops towards the rings and pops in/out with a little overshoot
    a = easeOutCubic(tutorialFade)
    bounce = ABS(SIN(clock * 3.5))
    ax = peg(target).x
    ay = peg(target).y - 48 - bounce * 12 - (1 - a) * 15 'tip of the arrow
    s = .8 * easeOutBack(tutorialFade) * (1 + .05 * (1 - bounce))
    IF s > .01 THEN putScaled arrowIcon(_CEIL(tutorialFade * UBOUND(arrowIcon))), ax, ay, -26, -57.5, s

    outlinedText "Drag these rings", ax, ay - 74, a
    outlinedText "to the board", ax, ay - 54, a
END SUB

SUB outlinedText (text$, cx AS SINGLE, cy AS SINGLE, alpha AS SINGLE)
    DIM x AS SINGLE, y AS SINGLE, ox AS INTEGER, oy AS INTEGER

    x = cx - _PRINTWIDTH(text$) / 2
    y = cy - _FONTHEIGHT / 2
    IF 200 * alpha >= 1 THEN
        COLOR _RGBA32(0, 0, 0, 200 * alpha)
        FOR oy = -2 TO 2 STEP 2
            FOR ox = -2 TO 2 STEP 2
                IF ox <> 0 OR oy <> 0 THEN _PRINTSTRING (x + ox, y + oy), text$
            NEXT
        NEXT
    END IF
    COLOR _RGBA32(255, 255, 255, 255 * alpha)
    _PRINTSTRING (x, y), text$
END SUB

SUB drawPauseOverlay (fade AS SINGLE)
    DIM a AS SINGLE, s AS SINGLE

    a = easeOutCubic(fade)
    s = .9 + .1 * a
    IF 153 * a >= 1 THEN LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(0, 0, 0, 153 * a), BF
    drawScaledText "PAUSED", _WIDTH / 2, _HEIGHT / 2 - 62 + fontHeightLarge(4) / 2, 4, s, _RGBA32(255, 255, 255, 255 * a), _RGBA32(255, 255, 255, 50 * a), 0
    drawScaledText "Click to continue", _WIDTH / 2, _HEIGHT / 2 + 30, 1, 1.5 * s, _RGBA32(255, 255, 255, 255 * a), _RGBA32(255, 255, 255, 60 * a), 0
END SUB

SUB applyScreenZoom
    DIM img AS LONG, w AS SINGLE, h AS SINGLE

    IF screenZoom <= 1.001 THEN EXIT SUB
    img = _COPYIMAGE(_DISPLAY)
    w = _WIDTH * screenZoom
    h = _HEIGHT * screenZoom
    '_DONTBLEND (not supported in QBJS)
    _PUTIMAGE (zoomX * (1 - screenZoom), zoomY * (1 - screenZoom))-STEP(w, h), img 'zoomX, zoomY stay put
    '_BLEND (not supported in QBJS)
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
        'putImageStep x - sw / 2, y - sh / 2, sw, sh, img
        _PUTIMAGE (x - sw / 2, y - sh / 2)-STEP(sw, sh), img
    ELSE
        'putImageStep x, y - sh / 2, sw, sh, img
        _PUTIMAGE (x, y - sh / 2)-STEP(sw, sh), img
    END IF
    _FREEIMAGE img
END SUB

SUB saveGame
    'the game state is kept in the browser's localStorage as comma-separated values
    DIM i AS INTEGER, j AS INTEGER, a$

    a$ = "tttrng2"
    a$ = a$ + "," + numStr$(musicVolume) + "," + numStr$(sfxVolume)
    a$ = a$ + "," + numStr$(prevMusicVolume) + "," + numStr$(prevSfxVolume)
    a$ = a$ + "," + numStr$(electricConnections)
    a$ = a$ + "," + numStr$(score) + "," + numStr$(highscore) + "," + numStr$(level)
    a$ = a$ + "," + numStr$(gameOver) + "," + numStr$(mode)
    IF gameOver = false THEN
        FOR i = 1 TO 12
            FOR j = 1 TO 3
                a$ = a$ + "," + numStr$(slotColor(peg(i).set, j))
            NEXT
        NEXT
    END IF

    'save crc
    a$ = a$ + "," + numStr$(crc32(a$))
    Storage.Set "tictactoering.dat", a$
END SUB

SUB loadGame
    DIM i AS INTEGER, j AS INTEGER, a$, n AS INTEGER, s$

    a$ = Storage.Get("tictactoering.dat")
    n = csvCount(a$)
    IF n < 12 THEN EXIT SUB
    IF csvField$(a$, 1) <> "tttrng2" THEN EXIT SUB

    'test crc
    IF numStr$(crc32(LEFT$(a$, _INSTRREV(a$, ",") - 1))) <> csvField$(a$, n) THEN
        'crc failed - data has been tampered with
        Storage.Set "tictactoering.dat", ""
        EXIT SUB
    END IF

    musicVolume = VAL(csvField$(a$, 2))
    sfxVolume = VAL(csvField$(a$, 3))
    prevMusicVolume = VAL(csvField$(a$, 4))
    prevSfxVolume = VAL(csvField$(a$, 5))
    electricConnections = VAL(csvField$(a$, 6))
    score = VAL(csvField$(a$, 7))
    highscore = VAL(csvField$(a$, 8))
    level = VAL(csvField$(a$, 9))
    gameOver = VAL(csvField$(a$, 10))
    mode = VAL(csvField$(a$, 11))

    IF gameOver = false AND n >= 12 + 36 THEN
        FOR i = 1 TO 12
            s$ = ""
            FOR j = 1 TO 3
                s$ = s$ + MKI$(VAL(csvField$(a$, 11 + (i - 1) * 3 + j)))
            NEXT
            peg(i).set = s$
        NEXT
    ELSE
        gameOver = false
        score = 0
        level = 0
    END IF
END SUB

FUNCTION loadSound& (file$)
    'use the project's own assets when available, or fetch them from the GitHub repository
    IF _FILEEXISTS(file$) THEN
        loadSound& = _SNDOPEN(file$)
    ELSE
        loadSound& = _SNDOPEN(ASSETS_URL + file$)
    END IF
END FUNCTION

FUNCTION numStr$ (v AS DOUBLE)
    numStr$ = _TRIM$(STR$(v))
END FUNCTION

FUNCTION csvCount (s$)
    'number of comma-separated fields in s$
    DIM i AS LONG, n AS INTEGER
    IF LEN(s$) = 0 THEN EXIT FUNCTION
    n = 1
    FOR i = 1 TO LEN(s$)
        IF MID$(s$, i, 1) = "," THEN n = n + 1
    NEXT
    csvCount = n
END FUNCTION

FUNCTION csvField$ (s$, index AS INTEGER)
    'field number index of the comma-separated s$, without quotes
    DIM i AS LONG, n AS INTEGER, start AS LONG, f$
    n = 1
    start = 1
    FOR i = 1 TO LEN(s$) + 1
        IF i > LEN(s$) OR MID$(s$, i, 1) = "," THEN
            IF n = index THEN
                f$ = MID$(s$, start, i - start)
                IF LEFT$(f$, 1) = CHR$(34) THEN f$ = MID$(f$, 2)
                IF RIGHT$(f$, 1) = CHR$(34) THEN f$ = LEFT$(f$, LEN(f$) - 1)
                csvField$ = f$
                EXIT FUNCTION
            END IF
            n = n + 1
            start = i + 1
        END IF
    NEXT
END FUNCTION

'replacements for QB64 features QBJS doesn't have
FUNCTION replaceAt$ (s$, position AS INTEGER, v$)
    'same as MID$(s$, position, LEN(v$)) = v$
    replaceAt$ = LEFT$(s$, position - 1) + v$ + MID$(s$, position + LEN(v$))
END FUNCTION

SUB copyObject (dst AS gameObject, src AS gameObject)
    'dst = src (QBJS assigns user-defined types by reference)
    dst.x = src.x: dst.y = src.y
    dst.xv = src.xv: dst.yv = src.yv
    dst.xa = src.xa: dst.ya = src.ya
    dst.set = src.set
    dst.size = src.size: dst.start = src.start: dst.duration = src.duration
    dst.state = src.state: dst.text = src.text
    dst.w = src.w: dst.h = src.h
    dst.r = src.r: dst.g = src.g: dst.b = src.b
END SUB

SUB copyMatch (dst AS matchType, src AS matchType)
    'dst = src (QBJS assigns user-defined types by reference)
    dst.peg = src.peg: dst.slot = src.slot: dst.colr = src.colr
END SUB

FUNCTION minf! (a AS SINGLE, b AS SINGLE)
    IF a < b THEN minf! = a ELSE minf! = b
END FUNCTION

FUNCTION maxf! (a AS SINGLE, b AS SINGLE)
    IF a > b THEN maxf! = a ELSE maxf! = b
END FUNCTION

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

FUNCTION freeParticle%
    'first inactive slot in the particle pool (0 if the pool is full)
    DIM p AS INTEGER
    FOR p = 1 TO UBOUND(particle)
        IF particle(p).state = false THEN freeParticle% = p: EXIT FUNCTION
    NEXT
END FUNCTION

SUB addShockwave (x AS SINGLE, y AS SINGLE, speed AS SINGLE, decay AS SINGLE, c AS _UNSIGNED LONG, delay AS SINGLE)
    'expanding ring that slows down and thins out as it fades
    DIM p AS INTEGER

    p = freeParticle
    IF p = 0 THEN EXIT SUB
    particle(p).state = true
    particle(p).shape = 5
    particle(p).x = x
    particle(p).y = y
    particle(p).size = 0 'radius
    particle(p).xv = speed
    particle(p).life = 1
    particle(p).decay = decay
    particle(p).duration = 2 + speed * .4 'ring thickness
    particle(p).c = c
    particle(p).start = clock + delay
END SUB

SUB addSparkBurst (x AS SINGLE, y AS SINGLE, total AS INTEGER, power AS SINGLE, c AS _UNSIGNED LONG, delay AS SINGLE)
    'glowing sparks thrown outwards in a shell, slowed down by drag; c = 0 mixes white with ring colors
    DIM addedP AS INTEGER, p AS INTEGER, a AS SINGLE, spd AS SINGLE

    FOR p = 1 TO UBOUND(particle)
        IF addedP >= total THEN EXIT FOR
        IF particle(p).state = false THEN
            addedP = addedP + 1
            particle(p).state = true
            particle(p).shape = 6
            particle(p).x = x
            particle(p).y = y
            a = RND * _PI(2)
            spd = (3 + (1 - RND ^ 4) * 15) * power 'most sparks travel near the leading edge
            particle(p).xv = COS(a) * spd
            particle(p).yv = SIN(a) * spd
            particle(p).size = 1 + RND * 2.5
            particle(p).life = 1
            particle(p).decay = .008 + RND * .012
            IF c <> 0 THEN
                particle(p).c = c
            ELSEIF RND < .55 THEN
                particle(p).c = _RGB32(255)
            ELSE
                particle(p).c = ringColor(_CEIL(RND * 8))
            END IF
            particle(p).start = clock + delay
        END IF
    NEXT
END SUB

SUB addImplosion (x AS SINGLE, y AS SINGLE, total AS INTEGER, arrival AS DOUBLE)
    'streaks that rush in from all around and all reach (x, y) at the same moment
    DIM addedP AS INTEGER, p AS INTEGER, a AS SINGLE, d AS SINGLE

    FOR p = 1 TO UBOUND(particle)
        IF addedP >= total THEN EXIT FOR
        IF particle(p).state = false THEN
            addedP = addedP + 1
            particle(p).state = true
            particle(p).shape = 7
            a = RND * _PI(2)
            d = 250 + RND * 450
            particle(p).x = x + COS(a) * d 'origin
            particle(p).y = y + SIN(a) * d
            particle(p).xv = -COS(a) * d 'path to the target
            particle(p).yv = -SIN(a) * d
            particle(p).size = 1 + RND * 2
            particle(p).duration = .45 + RND * .45
            particle(p).start = arrival - particle(p).duration
            IF RND < .5 THEN particle(p).c = _RGB32(255) ELSE particle(p).c = ringColor(_CEIL(RND * 8))
        END IF
    NEXT
END SUB

SUB bigBang (x AS SINGLE, y AS SINGLE)
    'intro explosion: layered shockwaves in ring colors plus a shell of sparks
    addShockwave x, y, 24, .012, _RGB32(255), 0
    addShockwave x, y, 17, .014, ringColor(_CEIL(RND * 8)), .08
    addShockwave x, y, 12, .016, ringColor(_CEIL(RND * 8)), .16
    addSparkBurst x, y, 1200, 1, 0, 0
    disturbParticles x, y, 6, _WIDTH
END SUB

SUB boardStartBurst
    'game start: a wave leaves the center of the board and lights each peg up as it passes
    DIM i AS INTEGER, delay AS SINGLE, c AS _UNSIGNED LONG

    addShockwave peg(5).x, peg(5).y, 16, .02, _RGB32(255), 0
    addSparkBurst peg(5).x, peg(5).y, 400, .8, 0, 0
    disturbParticles peg(5).x, peg(5).y, 4, _WIDTH

    FOR i = 1 TO 9
        delay = dist(peg(i).x, peg(i).y, peg(5).x, peg(5).y) / 800 'roughly when the wave reaches it
        c = ringColor(_CEIL(RND * 3))
        addShockwave peg(i).x, peg(i).y, 5, .035, c, delay
        addSparkBurst peg(i).x, peg(i).y, 25, .3, c, delay
        addSparkBurst peg(i).x, peg(i).y, 15, .3, _RGB32(255), delay
    NEXT
END SUB

SUB updateBurstParticle (i AS INTEGER, now AS DOUBLE)
    DIM r AS INTEGER, g AS INTEGER, b AS INTEGER, k AS INTEGER, w AS INTEGER
    DIM t AS SINGLE, e AS SINGLE, e0 AS SINGLE, s AS SINGLE, a AS SINGLE

    IF now < particle(i).start THEN EXIT SUB 'not started yet

    r = _RED32(particle(i).c): g = _GREEN32(particle(i).c): b = _BLUE32(particle(i).c)
    SELECT CASE particle(i).shape
        CASE 5 'shockwave
            particle(i).size = particle(i).size + particle(i).xv * frameStep
            particle(i).xv = particle(i).xv * .96 ^ frameStep
            particle(i).life = particle(i).life - particle(i).decay * frameStep
            IF particle(i).life <= 0 THEN particle(i).state = false: EXIT SUB

            a = particle(i).life
            w = 1 + particle(i).duration * a
            FOR k = -w TO w
                CIRCLE (particle(i).x, particle(i).y), particle(i).size + k, _RGBA32(r, g, b, a * 150 * (1 - ABS(k) / (w + 1)))
            NEXT
            CIRCLE (particle(i).x, particle(i).y), particle(i).size, _RGBA32(255, 255, 255, a * 200)
            CIRCLE (particle(i).x, particle(i).y), particle(i).size * .8, _RGBA32(r, g, b, a * 50)
        CASE 6 'spark
            particle(i).x = particle(i).x + particle(i).xv * frameStep
            particle(i).y = particle(i).y + particle(i).yv * frameStep
            particle(i).xv = particle(i).xv * .95 ^ frameStep
            particle(i).yv = particle(i).yv * .95 ^ frameStep + .02 * frameStep
            particle(i).life = particle(i).life - particle(i).decay * frameStep
            IF particle(i).life <= 0 OR particle(i).x < -20 OR particle(i).x > _WIDTH + 20 OR particle(i).y < -20 OR particle(i).y > _HEIGHT + 20 THEN
                particle(i).state = false: EXIT SUB
            END IF

            a = particle(i).life
            s = particle(i).size * (.4 + .6 * a)
            CircleFill particle(i).x, particle(i).y, s * 2.5, _RGBA32(r, g, b, a * 40)
            CircleFill particle(i).x, particle(i).y, s, _RGBA32(r, g, b, a * 255)
        CASE 7 'imploding streak
            t = (now - particle(i).start) / particle(i).duration
            IF t >= 1 THEN particle(i).state = false: EXIT SUB

            e = t * t * t 'accelerates into the target
            e0 = t - .1: IF e0 < 0 THEN e0 = 0
            e0 = e0 * e0 * e0
            a = t * 255
            thickLine particle(i).x + particle(i).xv * e0, particle(i).y + particle(i).yv * e0, particle(i).x + particle(i).xv * e, particle(i).y + particle(i).yv * e, particle(i).size, _RGBA32(r, g, b, a * .6)
            CircleFill particle(i).x + particle(i).xv * e, particle(i).y + particle(i).yv * e, particle(i).size, _RGBA32(r, g, b, a)
    END SELECT
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
                particle(i).yv = particle(i).yv + gravity * frameStep
                particle(i).x = particle(i).x + particle(i).xv * frameStep
                particle(i).y = particle(i).y + particle(i).yv * frameStep
                a = map(now - particle(i).start, 0, particle(i).duration, 255, 0)

                IF particle(i).x > _WIDTH OR particle(i).x < 0 OR particle(i).y > _HEIGHT OR particle(i).y < 0 OR a <= 0 THEN
                    particle(i).state = false
                ELSE
                    CircleFill particle(i).x, particle(i).y, particle(i).size, _RGBA32(_RED32(particle(i).c), _GREEN32(particle(i).c), _BLUE32(particle(i).c), a)
                END IF
            ELSEIF particle(i).shape >= 5 THEN
                updateBurstParticle i, now
            ELSE
                particle(i).x = particle(i).x + particle(i).xv * frameStep
                particle(i).y = particle(i).y + particle(i).yv * frameStep
                particle(i).yv = particle(i).yv + .2 * frameStep
                particle(i).rotation = particle(i).rotation + particle(i).rotationSpeed * frameStep
                particle(i).life = particle(i).life - particle(i).decay * frameStep
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
    DIM before AS LONG, stp AS SINGLE, dt AS SINGLE

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
                kickScore .8
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

    'damped spring pulling the score scale back to 1
    dt = frameDt
    IF dt > 1 / 30 THEN dt = 1 / 30
    scorePopV = scorePopV + (-300 * scorePop - 14 * scorePopV) * dt
    scorePop = scorePop + scorePopV * dt
END SUB

SUB playSfx (handle AS LONG, baseVolume AS SINGLE)
    IF handle > 0 AND sfxVolume > 0 THEN
        'QBJS ignores _SNDPLAYCOPY's volume; copies take the volume of the original instead
        _SNDVOL handle, clampf(baseVolume * sfxVolume, 0, 1)
        _SNDPLAYCOPY handle, baseVolume * sfxVolume
    END IF
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

FUNCTION easeOutBack! (t AS SINGLE)
    'overshoots a little before settling at 1
    CONST c1 = 1.70158
    easeOutBack! = 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
END FUNCTION

FUNCTION mixColor~& (c1 AS _UNSIGNED LONG, c2 AS _UNSIGNED LONG, t AS SINGLE)
    mixColor~& = _RGBA32(_RED32(c1) + (_RED32(c2) - _RED32(c1)) * t, _GREEN32(c1) + (_GREEN32(c2) - _GREEN32(c1)) * t, _BLUE32(c1) + (_BLUE32(c2) - _BLUE32(c1)) * t, _ALPHA32(c1) + (_ALPHA32(c2) - _ALPHA32(c1)) * t)
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
    DIM tableBg AS LONG, oldBoard$, best AS _UNSIGNED LONG

    IF gameOver OR keyb = -27 THEN
        'flash and screenshot
        screenshot = _COPYIMAGE(_DISPLAY)

        start = clock
        DO
            s = 1 - .75 * easeOutCubic(clampf((clock - start) / .5, 0, 1))
            drawBackground
            'putImageStep (_WIDTH - _WIDTH * s) / 2, 0, _WIDTH * s, _HEIGHT * s, screenshot
            _PUTIMAGE ((_WIDTH - _WIDTH * s) / 2, 0)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
            transitionFlash clock - start
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

            IF LEN(board$) > 0 THEN Storage.Set filename$, board$ 'WRITES THAT TO THE FILE

            board$ = Storage.Get(filename$)
            IF LEN(board$) > 0 THEN
                FOR i = 1 TO maxHighScores
                    IF i * 2 > csvCount(board$) THEN EXIT FOR
                    highScore(i).player = csvField$(board$, i * 2 - 1)
                    highScore(i).score = VAL(csvField$(board$, i * 2))
                    IF highScore(i).score > highscore THEN highscore = highScore(i).score
                    totalHS = i
                NEXT
            END IF

            IF score > 0 AND score >= highscore THEN
                COLOR _RGB32(255, 215, 0)
                centerText 570, "New High Score!"
            END IF

            saveGame

            tableX = _WIDTH / 2 - 88
            oldBoard$ = board$
            tableBg = _COPYIMAGE(_DISPLAY) 'to redraw the table once the server has the new score
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
                                highScore(i + 1).player = highScore(i).player: highScore(i + 1).score = highScore(i).score
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
                            highScore(i + 1).player = highScore(i).player: highScore(i + 1).score = highScore(i).score
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
                    'IF _EXIT THEN SYSTEM (QBJS: no window close event)
                LOOP
                _PUTIMAGE (0, 0), screenshot2
                COLOR _RGB32(255)
                _PRINTSTRING (tableX, 248 + insertAt * 16), temp$
                _FREEIMAGE screenshot2
                highScore(insertAt).player = temp$
                _KEYCLEAR

                IF LEN(_TRIM$(temp$)) = 0 THEN temp$ = "PLAYER"

                centerText 424, "Updating scoreboard..."
                _DISPLAY
                uploadScore temp$, score

                'the leaderboard keeps one entry per player (their best score), so show
                'what it holds now instead of the table built above
                board$ = downloadBoard
                IF boardOnline = false THEN board$ = mergeScore$(oldBoard$, temp$, score)
                Storage.Set filename$, board$

                _PUTIMAGE (0, 0), tableBg
                best = 0
                FOR i = 1 TO csvCount(board$) \ 2
                    IF UCASE$(csvField$(board$, i * 2 - 1)) = UCASE$(temp$) THEN best = VAL(csvField$(board$, i * 2)): EXIT FOR
                NEXT
                IF best > score THEN
                    COLOR _RGB32(255, 215, 0)
                    centerText 200, temp$ + "'s best score of" + STR$(best) + " still stands!"
                ELSEIF best = score THEN
                    COLOR _RGB32(255)
                    centerText 200, "You made it to the scoreboard!"
                END IF
                drawHighScoreTable board$, tableX, temp$
            ELSE
                centerText 232, "******** HIGH  SCORES ********"
                FOR i = 1 TO totalHS
                    printHighScore tableX, 248 + i * 16, highScore(i).player, highScore(i).score
                NEXT
            END IF
            _FREEIMAGE tableBg
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

            userQuit = false '_EXIT: not available in the browser
            _DISPLAY
            _LIMIT 30
        LOOP UNTIL keyb = -13 OR keyb = -27 OR keyb = -110 OR keyb = -78 OR keyb = -121 OR keyb = -89 OR userQuit
        mouseDown = false

        IF gameOver AND (keyb = -110 OR keyb = -78) THEN
            'quit: a browser page can't close itself, so go back to the intro and start over
            _FREEIMAGE screenshot
            _FREEIMAGE screenshot2
            _KEYCLEAR
            currentButton = 0
            resetGame
            doIntro
            EXIT SUB
        END IF

        IF (gameOver AND (keyb = -13 OR keyb = -121 OR keyb = -89)) OR (gameOver = false AND (keyb = -110 OR keyb = -78)) THEN
            resetGame
        ELSE
            'bring screenshot back to front
            start = clock
            DO
                s = .25 + .75 * easeOutCubic(clampf((clock - start) / .5, 0, 1))
                drawBackground
                'putImageStep (_WIDTH - _WIDTH * s) / 2, 0, _WIDTH * s, _HEIGHT * s, screenshot
                _PUTIMAGE ((_WIDTH - _WIDTH * s) / 2, 0)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
                transitionFlash clock - start
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

SUB drawHighScoreTable (board$, x AS INTEGER, highlight$)
    'board$ is "name",score,...; the highlighted player's row is drawn in gold
    DIM i AS INTEGER, n AS INTEGER, player$

    COLOR _RGB32(255)
    centerText 232, "******** HIGH  SCORES ********"
    n = csvCount(board$) \ 2
    IF n > maxHighScores THEN n = maxHighScores
    FOR i = 1 TO n
        player$ = csvField$(board$, i * 2 - 1)
        IF UCASE$(player$) = UCASE$(highlight$) THEN COLOR _RGB32(255, 215, 0) ELSE COLOR _RGB32(255)
        printHighScore x, 248 + i * 16, player$, VAL(csvField$(board$, i * 2))
    NEXT
    COLOR _RGB32(255)
END SUB

FUNCTION mergeScore$ (board$, player$, value AS _UNSIGNED LONG)
    'adds a result the way the online leaderboard does: one entry per player, keeping their best
    DIM n AS INTEGER, i AS INTEGER, j AS INTEGER, found AS _BYTE, r$, n$, s AS _UNSIGNED LONG

    n = csvCount(board$) \ 2
    DIM names(1 TO n + 1) AS STRING, scores(1 TO n + 1) AS _UNSIGNED LONG
    FOR i = 1 TO n
        names(i) = csvField$(board$, i * 2 - 1)
        scores(i) = VAL(csvField$(board$, i * 2))
        IF UCASE$(names(i)) = UCASE$(player$) THEN
            found = true
            IF value > scores(i) THEN scores(i) = value
        END IF
    NEXT
    IF found = false THEN
        n = n + 1
        names(n) = player$
        scores(n) = value
    END IF

    FOR i = 1 TO n - 1
        FOR j = i + 1 TO n
            IF scores(j) > scores(i) THEN
                s = scores(i): scores(i) = scores(j): scores(j) = s
                n$ = names(i): names(i) = names(j): names(j) = n$
            END IF
        NEXT
    NEXT

    IF n > maxHighScores THEN n = maxHighScores
    FOR i = 1 TO n
        r$ = r$ + CHR$(34) + names(i) + CHR$(34) + "," + LTRIM$(STR$(scores(i)))
        IF i < n THEN r$ = r$ + ","
    NEXT
    mergeScore$ = r$
END FUNCTION

SUB printHighScore (x AS INTEGER, y AS INTEGER, player$, value AS _UNSIGNED LONG)
    DIM v$
    v$ = LTRIM$(STR$(value))
    _PRINTSTRING (x, y), player$
    _PRINTSTRING (x + 176 - _PRINTWIDTH(v$), y), v$
END SUB

SUB transitionFlash (t AS SINGLE)
    'quick white flash at the start of a screen transition
    IF t < .35 THEN LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(255, 255, 255, 200 * (1 - t / .35) ^ 2), BF
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
        s = 1 - (2 / 3) * easeOutCubic(clampf((clock - start) / .5, 0, 1))
        sw = _WIDTH * s
        sh = _HEIGHT * s
        drawBackground
        'putImageStep 0, (_HEIGHT - sh) / 2, sw, sh, screenshot
        _PUTIMAGE (0, (_HEIGHT - sh) / 2)-STEP(sw, sh), screenshot
        transitionFlash clock - start

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
        'putImageStep 0, (_HEIGHT - sh) / 2, sw, sh, screenshot
        _PUTIMAGE (0, (_HEIGHT - sh) / 2)-STEP(sw, sh), screenshot

        WHILE _MOUSEINPUT: WEND
        mx = _MOUSEX
        my = _MOUSEY
        keyb = _KEYHIT
        userQuit = false '_EXIT: not available in the browser

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
        s = 1 / 3 + (2 / 3) * easeOutCubic(clampf((clock - start) / .5, 0, 1))
        drawBackground
        'putImageStep 0, (_HEIGHT - _HEIGHT * s) / 2, _WIDTH * s, _HEIGHT * s, screenshot
        _PUTIMAGE (0, (_HEIGHT - _HEIGHT * s) / 2)-STEP(_WIDTH * s, _HEIGHT * s), screenshot
        transitionFlash clock - start
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > .5

    _FREEIMAGE screenshot
    _KEYCLEAR
    mouseDown = false
    currentButton = 0
END SUB

SUB scoresScreen
    'online leaderboards for both modes, reachable from the game at any time
    DIM screenshot AS LONG, start AS DOUBLE, a AS SINGLE
    DIM boards$(1 TO 2), online(1 TO 2) AS _BYTE, title$(1 TO 2), id$, file$
    DIM m AS INTEGER, i AS INTEGER, n AS INTEGER, cx AS INTEGER, x AS INTEGER, y AS INTEGER, v$
    DIM done AS _BYTE, down AS _BYTE, prevbt AS INTEGER

    screenshot = _COPYIMAGE(_DISPLAY)

    'dim the game while the scores load
    start = clock
    DO
        a = easeOutCubic(clampf((clock - start) / .3, 0, 1))
        _PUTIMAGE (0, 0), screenshot
        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(10, 5, 30, 1 + 214 * a), BF
        transitionFlash clock - start
        updateParticles
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > .35
    COLOR _RGB32(255)
    centerText _HEIGHT / 2, "Connecting to server..."
    _DISPLAY

    title$(1) = "NORMAL"
    title$(2) = "EASIER"
    FOR m = 1 TO 2
        IF m = 1 THEN
            id$ = LEADERBOARD_NORMAL: file$ = "highscores.dat"
        ELSE
            id$ = LEADERBOARD_EASIER: file$ = "highscores_easier.dat"
        END IF
        boards$(m) = downloadBoardFrom$(id$)
        online(m) = boardOnline
        IF online(m) THEN
            Storage.Set file$, boards$(m)
        ELSE
            boards$(m) = Storage.Get(file$)
        END IF
    NEXT

    currentButton = 0
    totalButtons = 1
    caption(1) = "Return to game"
    button(1).w = 200
    button(1).h = 35
    button(1).x = (_WIDTH - button(1).w) / 2
    button(1).y = _HEIGHT - 90
    button(1).state = 0

    _KEYCLEAR
    down = _MOUSEBUTTON(1)
    DO
        drawBackground
        LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(10, 5, 30, 120), BF

        WHILE _MOUSEINPUT: WEND
        keyb = _KEYHIT
        checkButtons
        IF currentButton <> prevbt THEN
            IF currentButton > 0 THEN playSfx selectSound, .3
            prevbt = currentButton
        END IF

        COLOR _RGB32(0)
        centerLarge 53, "High Scores", 4
        COLOR _RGB32(255)
        centerLarge 50, "High Scores", 4

        FOR m = 1 TO 2
            cx = _WIDTH * (2 * m - 1) / 4
            IF m - 1 = mode THEN COLOR _RGB32(255, 215, 0) ELSE COLOR _RGB32(150, 200, 255)
            printLarge cx - printWidthLarge(title$(m), 2) / 2, 150, title$(m), 2
            IF m - 1 = mode THEN
                COLOR _RGBA32(255, 215, 0, 180)
                centerAt cx, 186, "(current mode)"
            END IF
            IF online(m) = false THEN
                COLOR _RGB32(255, 150, 170)
                centerAt cx, 204, "offline - showing saved scores"
            END IF

            n = csvCount(boards$(m)) \ 2
            IF n > maxHighScores THEN n = maxHighScores
            x = cx - 120
            IF n = 0 THEN
                COLOR _RGB32(200, 200, 220)
                centerAt cx, 250, "No scores yet"
            END IF
            FOR i = 1 TO n
                y = 222 + i * 26
                IF i = 1 THEN COLOR _RGB32(255, 215, 0) ELSE COLOR _RGB32(255)
                v$ = LTRIM$(STR$(i)) + "."
                _PRINTSTRING (x + 24 - _PRINTWIDTH(v$), y), v$
                _PRINTSTRING (x + 36, y), csvField$(boards$(m), i * 2 - 1)
                v$ = csvField$(boards$(m), i * 2)
                _PRINTSTRING (x + 240 - _PRINTWIDTH(v$), y), v$
            NEXT
        NEXT

        doButtons
        updateParticles

        'click anywhere, Enter, Space or Esc to go back
        IF _MOUSEBUTTON(1) THEN
            down = true
        ELSEIF down THEN
            down = false
            done = true
        END IF
        IF ABS(keyb) = 13 OR ABS(keyb) = 27 OR ABS(keyb) = 32 THEN done = true

        _DISPLAY
        _LIMIT 60
    LOOP UNTIL done

    addParticles _MOUSEX, _MOUSEY, 30, _RGB32(255)
    addParticles _MOUSEX, _MOUSEY, 30, _RGB32(67, 172, 183)
    start = clock
    DO
        a = 1 - easeOutCubic(clampf((clock - start) / .3, 0, 1))
        _PUTIMAGE (0, 0), screenshot
        IF a > 0 THEN LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGBA32(10, 5, 30, 1 + 214 * a), BF
        updateParticles
        _DISPLAY
        _LIMIT 60
    LOOP UNTIL clock - start > .3

    _FREEIMAGE screenshot
    _KEYCLEAR
    mouseDown = false
    currentButton = 0
END SUB

SUB centerAt (cx AS SINGLE, y AS SINGLE, text$)
    _PRINTSTRING (cx - _PRINTWIDTH(text$) / 2, y), text$
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

    totalButtons = 4
    caption(1) = "Settings"
    caption(2) = "Pause"
    caption(3) = "Scores"
    caption(4) = "Quit"
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
                updateButtonHover i
                IF buttonHover(i) > 0 THEN LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), _RGBA32(255, 255, 255, 80 * buttonHover(i)), BF
                LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), mixColor(_RGB32(136), _RGB32(67, 172, 183), buttonHover(i)), B
        END SELECT
    NEXT
END SUB

SUB updateButtonHover (i AS INTEGER)
    'hover highlight eases in and out instead of switching instantly
    IF i = currentButton THEN
        buttonHover(i) = clampf(buttonHover(i) + frameDt * 10, 0, 1)
    ELSE
        buttonHover(i) = clampf(buttonHover(i) - frameDt * 6, 0, 1)
    END IF
END SUB

SUB drawButtonBox (i AS INTEGER)
    DIM h AS SINGLE, edge AS _UNSIGNED LONG

    updateButtonHover i
    h = buttonHover(i)
    edge = mixColor(_RGB32(136), _RGB32(67, 172, 183), h)
    LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), mixColor(_RGBA32(50, 50, 50, 128), _RGBA32(67, 172, 183, 128), h), BF
    LINE (button(i).x, button(i).y)-STEP(button(i).w, button(i).h), edge, B
    LINE (button(i).x + 1, button(i).y + 1)-STEP(button(i).w - 2, button(i).h - 2), edge, B
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

FUNCTION leaderboardId$
    IF mode = MODE_EASIER THEN leaderboardId$ = LEADERBOARD_EASIER ELSE leaderboardId$ = LEADERBOARD_NORMAL
END FUNCTION

FUNCTION downloadBoard$
    downloadBoard$ = downloadBoardFrom$(leaderboardId$)
END FUNCTION

FUNCTION downloadBoardFrom$ (id$)
    'top scores from an online leaderboard as "name",score,"name",score,...
    'returns "" when offline (boardOnline = false), so the local copy is used instead
    DIM result AS INTEGER, total AS INTEGER, i AS INTEGER, j AS INTEGER
    DIM board$, n$, s AS _UNSIGNED LONG

    downloadBoardFrom$ = ""
    boardOnline = false
    IF LEN(id$) = 0 THEN EXIT FUNCTION

    REDIM entries(0) AS OBJECT
    result = GXS.LeaderboardGet(id$, entries())
    IF result <> 200 THEN EXIT FUNCTION
    boardOnline = true
    total = UBOUND(entries)
    IF total = 0 THEN EXIT FUNCTION

    'highest scores first (don't rely on the server's order)
    DIM names(1 TO total) AS STRING, scores(1 TO total) AS _UNSIGNED LONG
    FOR i = 1 TO total
        names(i) = entries(i).name
        scores(i) = entries(i).score
    NEXT
    FOR i = 1 TO total - 1
        FOR j = i + 1 TO total
            IF scores(j) > scores(i) THEN
                s = scores(i): scores(i) = scores(j): scores(j) = s
                n$ = names(i): names(i) = names(j): names(j) = n$
            END IF
        NEXT
    NEXT

    IF total > maxHighScores THEN total = maxHighScores
    FOR i = 1 TO total
        'keep names short and free of the characters the CSV format uses
        n$ = cleanName$(names(i))
        IF LEN(n$) = 0 THEN n$ = "PLAYER"
        board$ = board$ + CHR$(34) + n$ + CHR$(34) + "," + LTRIM$(STR$(scores(i)))
        IF i < total THEN board$ = board$ + ","
    NEXT
    downloadBoardFrom$ = board$
END FUNCTION

FUNCTION cleanName$ (n$)
    DIM i AS INTEGER, c$, r$
    FOR i = 1 TO LEN(n$)
        c$ = MID$(n$, i, 1)
        IF c$ <> "," AND c$ <> CHR$(34) THEN r$ = r$ + c$
    NEXT
    cleanName$ = LEFT$(_TRIM$(r$), 12)
END FUNCTION

SUB uploadScore (player$, value AS _UNSIGNED LONG)
    'adds this result to the online leaderboard (the local copy is saved by the caller)
    DIM id$, result AS INTEGER

    id$ = leaderboardId$
    IF LEN(id$) = 0 OR value = 0 THEN EXIT SUB
    result = GXS.LeaderboardUpdate(id$, value, player$)
END SUB
