OPTION _EXPLICIT

CONST true = -1, false = 0

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
    start AS SINGLE
    duration AS SINGLE
    r AS INTEGER
    g AS INTEGER
    b AS INTEGER
END TYPE

DIM canvas AS LONG
canvas = _NEWIMAGE(600, 600, 32)

SCREEN canvas
_TITLE "Tic Tac Toe Ring"
_PRINTMODE _KEEPBACKGROUND

DIM peg(0 TO 12) AS object
DIM del(1 TO 9) AS object

DIM emptySet$
emptySet$ = MKI$(-1) + MKI$(-1) + MKI$(-1)
peg(0).set = emptySet$

'set pegs positions
DIM spacing AS INTEGER, l AS INTEGER
DIM i AS INTEGER, j AS SINGLE, k AS SINGLE
spacing = 6
l = -(_HEIGHT / spacing)
FOR i = 1 TO 12
    j = j + 1
    IF j > 3 THEN j = 1: l = l + (_HEIGHT / spacing)
    SELECT CASE j
        CASE 1: k = -_WIDTH / spacing
        CASE 2: k = 0
        CASE 3: k = _WIDTH / spacing
    END SELECT
    peg(i).x = _WIDTH / 2 + k
    peg(i).y = _HEIGHT / 2 + l
    peg(i).set = emptySet$
NEXT

'ring colors
DIM c(8) AS _UNSIGNED LONG: i = 0
i = i + 1: c(i) = _RGB32(0, 78, 249) 'blue
i = i + 1: c(i) = _RGB32(61, 205, 28) 'green
i = i + 1: c(i) = _RGB32(222, 61, 44) 'red
i = i + 1: c(i) = _RGB32(216, 216, 44) 'yellow
i = i + 1: c(i) = _RGB32(233, 139, 17) 'orange
i = i + 1: c(i) = _RGB32(222, 105, 161) 'pink
i = i + 1: c(i) = _RGB32(139, 11, 205) 'purple
i = i + 1: c(i) = _RGB32(55, 211, 211) 'cyan

'generate ring images
DIM circleImage(1 TO i, 1 TO 3) AS LONG
FOR j = 1 TO UBOUND(c)
    FOR k = 1 TO 3
        circleImage(j, k) = _NEWIMAGE(k * 22, k * 22, 32)
        _DEST circleImage(j, k)
        PAINT (0, 0), _RGB32(255, 0, 255)
        CircleFill _WIDTH / 2, _HEIGHT / 2, k * 10, c(j)
        CircleFill _WIDTH / 2, _HEIGHT / 2, k * (5 + k), _RGB32(255, 0, 255)
        _CLEARCOLOR _RGB32(255, 0, 255)
    NEXT
NEXT

'generate bg
_DEST _DISPLAY
DIM bg AS LONG
bg = _NEWIMAGE(_WIDTH, _HEIGHT, 32)
_DEST bg
FOR i = 0 TO _HEIGHT - 1 STEP _HEIGHT / 60
    LINE (0, 0)-(_WIDTH - 1, i), _RGB32(139, 116, 177, 5), BF
NEXT

'flash warning
_DEST _DISPLAY
_DONTBLEND
_PUTIMAGE (0, 0), bg
_BLEND
centerLarge (_HEIGHT / 2) - fontHeightLarge(2) / 2, "This game contains bright,", 2, false
centerLarge (_HEIGHT / 2) + fontHeightLarge(2) / 2, "rapidly flashing colors.", 2, false

j = TIMER
DO
    _DISPLAY
    _LIMIT 30
LOOP UNTIL TIMER - j > 2 OR _KEYHIT

'intro
RANDOMIZE TIMER
DIM x AS INTEGER, y AS INTEGER
DIM introRings(1 TO 30) AS object
FOR i = 1 TO UBOUND(introRings)
    introRings(i).xa = RND * _PI(2)
    introRings(i).xv = RND * 5
    introRings(i).r = RND * 30 + 50
    introRings(i).set = MKI$(_CEIL(RND * UBOUND(c))) + MKI$(_CEIL(RND * UBOUND(c))) + MKI$(_CEIL(RND * UBOUND(c)))
NEXT

DIM introTimer AS SINGLE
introTimer = TIMER
DO
    _DONTBLEND
    _PUTIMAGE (0, 0), bg
    _BLEND

    FOR i = 1 TO UBOUND(introRings)
        introRings(i).xa = introRings(i).xa + .01
        introRings(i).r = introRings(i).r + introRings(i).xv
        x = _WIDTH / 2 + COS(introRings(i).xa) * introRings(i).r
        y = _HEIGHT / 2 + SIN(introRings(i).xa) * introRings(i).r

        FOR j = 1 TO 3
            DIM thisColor AS INTEGER
            thisColor = CVI(MID$(introRings(i).set, j * 2 - 1, 2))
            IF thisColor > 0 THEN
                _PUTIMAGE (x - (_WIDTH(circleImage(thisColor, j)) / 2), y - (_HEIGHT(circleImage(thisColor, j)) / 2)), circleImage(thisColor, j)
            END IF
        NEXT
    NEXT

    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGB32(255, 60), BF

    COLOR _RGB32(0)
    centerLarge (_HEIGHT / 2) - fontHeightLarge(2) + 5, "Tic Tac Toe", 2, true
    centerLarge (_HEIGHT / 2) + 5, "Rings", 7, true

    COLOR _RGB32(255)
    centerLarge (_HEIGHT / 2) - fontHeightLarge(2), "Tic Tac Toe", 2, true
    centerLarge (_HEIGHT / 2), "Rings", 7, true

    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGB32(255, map(TIMER - introTimer, 0, 1.5, 255, 0)), BF
    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGB32(255, map(TIMER - introTimer, 4, 5, 0, 255)), BF
    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGB32(0, map(TIMER - introTimer, 5, 6, 0, 255)), BF

    _DISPLAY
    _LIMIT 60
LOOP UNTIL TIMER - introTimer > 6 OR _KEYHIT

'add divs to bg
_DEST bg
LINE (_WIDTH / 2 - (_WIDTH / spacing) * 2, _HEIGHT / 2 - (_HEIGHT / spacing) * 2)-STEP(_WIDTH / spacing * 4, _HEIGHT / spacing * 4), _RGB32(0, 50), BF
LINE (3 + peg(10).x - (_WIDTH / spacing / 2), 3 + peg(10).y - (_WIDTH / spacing / 2))-(3 + peg(12).x + (_WIDTH / spacing / 2), 3 + peg(12).y + (_WIDTH / spacing / 2)), _RGB32(255, 15), BF
LINE (peg(10).x - (_WIDTH / spacing / 2), peg(10).y - (_WIDTH / spacing / 2))-(peg(12).x + (_WIDTH / spacing / 2), peg(12).y + (_WIDTH / spacing / 2)), _RGB32(255, 15), BF

'game
DIM score AS _UNSIGNED LONG, highscore AS _UNSIGNED LONG
DIM level AS _UNSIGNED LONG, maxColors AS INTEGER
DIM animation(0 TO 7) AS object, gameOver AS _BYTE

animation(0).duration = .25 'board flash
FOR i = 1 TO 5
    animation(i).duration = .5 'matches
NEXT
animation(6).duration = 1 'new set spawn
animation(7).duration = 1 'combo info

DIM multiplier AS INTEGER
multiplier = 1

OPEN "tictactoering.score" FOR BINARY AS #1
IF LOF(1) THEN
    GET #1, 1, score
    GET #1, , highscore
    GET #1, , level
    GET #1, , gameOver
    IF gameOver = false THEN
        FOR i = 1 TO 12
            GET #1, , peg(i)
        NEXT
    ELSE
        gameOver = false
        score = 0
        level = 0
    END IF
END IF
CLOSE #1

_DEST _DISPLAY

DO 'main game loop
    'redraw board
    _DONTBLEND
    _PUTIMAGE (0, 0), bg
    _BLEND

    'print osd
    COLOR _RGB32(200)
    _PRINTSTRING (52, 28), "*" + STR$(highscore)

    COLOR _RGB32(255)
    printLarge 0, 45, STR$(score), 6, false

    IF multiplier > 1 THEN
        COLOR _RGB32(200)
        _PRINTSTRING (52, 132), "x" + LTRIM$(STR$(multiplier))
    END IF

    'draw pegs
    FOR i = 1 TO 9
        CircleFill peg(i).x, peg(i).y, 3, _RGB32(255)
    NEXT

    'generate new sets;
    'new sets must be generated according to
    'current board's available positions
    IF peg(10).set + peg(11).set + peg(12).set = emptySet$ + emptySet$ + emptySet$ THEN
        level = level + 1
        maxColors = map(level, 1, 30, 3, UBOUND(c)) 'as level goes up, add more colors
        IF maxColors < 3 THEN maxColors = 3
        IF maxColors > UBOUND(c) THEN maxColors = UBOUND(c)

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
        animation(6).start = TIMER
    END IF

    'read mouse data
    WHILE _MOUSEINPUT: WEND

    'read keyboard
    DIM keyb AS LONG
    keyb = _KEYHIT

    IF _MOUSEBUTTON(1) THEN
        'drag?
        DIM dragging AS INTEGER
        DIM mouseDown AS _BYTE
        IF NOT mouseDown THEN
            'are we beginning to drag a ring or set of rings?
            dragging = 0
            FOR i = 10 TO 12
                IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 30 AND peg(i).set <> emptySet$ THEN
                    dragging = i
                    EXIT FOR
                END IF
            NEXT

            mouseDown = true
        END IF
    ELSE
        IF mouseDown THEN
            'place rings
            DIM placed AS _BYTE
            placed = false

            IF dragging THEN
                FOR i = 1 TO 9
                    IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 30 THEN
                        'check that the chosen peg can hold the current set of rings
                        placed = true
                        FOR j = 1 TO 3
                            IF CVI(MID$(peg(dragging).set, j * 2 - 1, 2)) > 0 AND CVI(MID$(peg(i).set, j * 2 - 1, 2)) > 0 THEN
                                placed = false
                                EXIT FOR
                            END IF
                        NEXT
                        IF placed THEN
                            FOR j = 1 TO 3
                                IF CVI(MID$(peg(dragging).set, j * 2 - 1, 2)) > 0 THEN
                                    MID$(peg(i).set, j * 2 - 1, 2) = MID$(peg(dragging).set, j * 2 - 1, 2)
                                END IF
                            NEXT
                            peg(dragging).set = emptySet$
                            EXIT FOR
                        ELSE
                            EXIT FOR
                        END IF
                    END IF
                NEXT
            END IF

            FOR j = 1 TO 9
                'prepare backup copies for deletion tagging
                del(j) = peg(j)
            NEXT

            'check matches
            DIM r(1 TO 3) AS INTEGER, previousScore AS _UNSIGNED LONG
            DIM s$, found1 AS INTEGER, found2 AS INTEGER, scored AS _BYTE
            previousScore = score
            IF placed THEN
                'look for 3 same-color rings on peg(i) --> ((o))
                FOR j = 1 TO 3
                    r(j) = CVI(MID$(peg(i).set, j * 2 - 1, 2))
                NEXT
                IF r(1) = r(2) AND r(2) = r(3) THEN
                    score = score + 3 * multiplier
                    animation(0).start = TIMER
                    animation(5).start = TIMER
                    animation(5).x = peg(i).x
                    animation(5).y = peg(i).y
                    animation(5).r = _RED32(c(r(1)))
                    animation(5).g = _GREEN32(c(r(1)))
                    animation(5).b = _BLUE32(c(r(1)))
                    del(i).set = emptySet$
                END IF

                'look for line matches |, -, /, \
                DIM m AS INTEGER, checks AS INTEGER
                DIM nextPeg(0 TO 2) AS INTEGER
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
                                    found1 = INSTR(del(r(i) + nextPeg(k)).set, s$)
                                    DO WHILE found1
                                        MID$(del(r(i) + nextPeg(k)).set, found1, 2) = MKI$(-1)
                                        score = score + multiplier
                                        found1 = INSTR(del(r(i) + nextPeg(k)).set, s$)
                                    LOOP
                                NEXT
                                scored = true
                                animation(0).start = TIMER
                                animation(m).start = TIMER
                                animation(m).x = peg(r(i)).x
                                animation(m).y = peg(r(i)).y
                                animation(m).r = _RED32(c(CVI(s$)))
                                animation(m).g = _GREEN32(c(CVI(s$)))
                                animation(m).b = _BLUE32(c(CVI(s$)))
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
                    multiplier = multiplier + 1
                    animation(7).start = TIMER
                ELSE
                    multiplier = 1
                END IF
                IF score > highscore THEN highscore = score

            END IF
        ELSE
            'highlight the hovered set in the shelf
            DIM highLit AS INTEGER
            IF highLit > 0 THEN l = l - 1 ELSE l = 8
            IF l < 0 THEN l = 0

            FOR i = 10 TO 12
                highLit = 0
                IF dist(peg(i).x, peg(i).y, _MOUSEX, _MOUSEY) <= 30 AND peg(i).set <> emptySet$ THEN
                    k = 0
                    FOR j = 12 TO l STEP -.5
                        k = k + .5
                        CircleFill peg(i).x, peg(i).y, 30 + k, _RGB32(255, j)
                    NEXT
                    highLit = i
                    EXIT FOR
                END IF
            NEXT
        END IF
        mouseDown = false
        dragging = 0
    END IF

    'check available moves
    IF dragging = 0 THEN
        IF peg(10).set <> emptySet$ OR peg(11).set <> emptySet$ OR peg(12).set <> emptySet$ THEN
            gameOver = true 'glass is half empty; consider no more moves
            FOR i = 10 TO 12
                IF peg(i).set <> emptySet$ THEN
                    'can this set fit the board?
                    FOR j = 1 TO 9
                        placed = true
                        FOR k = 1 TO 3
                            IF CVI(MID$(peg(i).set, k * 2 - 1, 2)) > 0 AND CVI(MID$(peg(j).set, k * 2 - 1, 2)) > 0 THEN
                                placed = false
                                EXIT FOR
                            END IF
                        NEXT
                        IF placed THEN gameOver = false: EXIT FOR
                    NEXT
                END IF
                IF gameOver = false THEN EXIT FOR 'no need to test further, there's still hope
            NEXT
        END IF

        IF gameOver = false THEN
            'is board full?
            'that means we used all sets and no matches were found = game over
            DIM board$
            board$ = ""
            FOR i = 1 TO 9
                board$ = board$ + peg(i).set
            NEXT
            IF INSTR(board$, MKI$(-1)) = 0 THEN gameOver = true
        END IF
    END IF

    'redraw rings
    FOR i = 1 TO 12
        IF i = dragging THEN
            x = _MOUSEX
            y = _MOUSEY
        ELSE
            x = peg(i).x
            y = peg(i).y
        END IF

        FOR j = 1 TO 3
            thisColor = CVI(MID$(peg(i).set, j * 2 - 1, 2))
            IF thisColor > 0 THEN
                _PUTIMAGE (x - (_WIDTH(circleImage(thisColor, j)) / 2), y - (_HEIGHT(circleImage(thisColor, j)) / 2)), circleImage(thisColor, j)
            END IF
        NEXT
    NEXT

    'board animations
    FOR i = 0 TO 7
        IF TIMER - animation(i).start <= animation(i).duration THEN
            DIM animSize AS SINGLE
            animSize = map(TIMER - animation(i).start, 0, animation(i).duration, 50, 0)
            SELECT CASE i
                CASE 0 'board flash
                    LINE (0, 0)-(_WIDTH - 1, _HEIGHT - 1), _RGB32(255, map(TIMER - animation(i).start, 0, animation(i).duration, 100, 0)), BF
                CASE 1 'across
                    FOR j = 0 TO _WIDTH STEP _WIDTH / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill j, animation(i).y, k, _RGB32(animation(i).r, animation(i).g, animation(i).b, 20)
                        NEXT
                    NEXT
                CASE 2 'down
                    FOR j = 0 TO _WIDTH STEP _WIDTH / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill animation(i).x, j, k, _RGB32(animation(i).r, animation(i).g, animation(i).b, 20)
                        NEXT
                    NEXT
                CASE 3 'diagonal \
                    FOR j = 0 TO _WIDTH STEP _WIDTH / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill j, j, k, _RGB32(animation(i).r, animation(i).g, animation(i).b, 20)
                        NEXT
                    NEXT
                CASE 4 'diagonal /
                    FOR j = 0 TO _WIDTH STEP _WIDTH / 30
                        FOR k = 1 TO animSize STEP 5
                            CircleFill j, _HEIGHT - j, k, _RGB32(animation(i).r, animation(i).g, animation(i).b, 20)
                        NEXT
                    NEXT
                CASE 5 'single peg ((o))
                    FOR k = 1 TO animSize
                        CircleFill animation(i).x, animation(i).y, k, _RGB32(animation(i).r, animation(i).g, animation(i).b, 20)
                    NEXT
                CASE 6 'new peg set
                    FOR k = 10 TO 12
                        CIRCLE (peg(k).x, peg(k).y), animSize * 1.5, _RGB32(255, animSize / 2)
                        CIRCLE (peg(k).x, peg(k).y), animSize, _RGB32(255, animSize)
                    NEXT
                CASE 7 'combo info
                    k = INT(map(animSize, 50, 40, 1, 4))
                    IF k < 1 THEN k = 1
                    IF k > 4 THEN k = 4
                    DIM m$
                    m$ = LTRIM$(STR$(multiplier)) + "x combo!"
                    COLOR _RGB32(0)
                    FOR l = -5 TO 5 STEP 5
                        printLarge (l + _WIDTH - printWidthLarge(m$, k)) / 2, (l + _HEIGHT - fontHeightLarge(k)) / 2, m$, k, true
                    NEXT
                    COLOR _RGB32(255)
                    printLarge (_WIDTH - printWidthLarge(m$, k)) / 2, (_HEIGHT - fontHeightLarge(k)) / 2, m$, k, true
            END SELECT
        END IF
    NEXT

    'update display
    _DISPLAY

    'limit fps
    _LIMIT 60

    DIM userQuit AS _BYTE
    userQuit = _EXIT
    IF userQuit = 0 THEN userQuit = (keyb = -27)
LOOP UNTIL gameOver OR userQuit

IF gameOver THEN PRINT "no more moves;"

OPEN "tictactoering.score" FOR BINARY AS #1
PUT #1, 1, score
PUT #1, , highscore
PUT #1, , level
PUT #1, , gameOver
FOR i = 1 TO 12
    PUT #1, , peg(i)
NEXT
CLOSE #1

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

FUNCTION map! (value!, minRange!, maxRange!, newMinRange!, newMaxRange!)
    map! = ((value! - minRange!) / (maxRange! - minRange!)) * (newMaxRange! - newMinRange!) + newMinRange!
END FUNCTION

FUNCTION lerp! (start!, stp!, amt!)
    lerp! = amt! * (stp! - start!) + start!
END FUNCTION

FUNCTION dist! (x1!, y1!, x2!, y2!)
    dist! = _HYPOT((x2! - x1!), (y2! - y1!))
END FUNCTION

FUNCTION distB! (v1 AS object, v2 AS object)
    distB! = dist!(v1.x, v1.y, v2.x, v2.y)
END FUNCTION

SUB printLarge (x AS SINGLE, y AS SINGLE, text$, fontSize AS INTEGER, bold AS _BYTE)
    DIM i AS LONG, j AS LONG, c AS LONG, char AS _UNSIGNED _BYTE

    IF fontSize = 0 THEN fontSize = 1
    bold = NOT bold

    FOR c = 1 TO LEN(text$)
        char = ASC(text$, c)
        FOR i = 1 TO 16
            FOR j = 1 TO 8
                IF charSet(char, i, j) THEN
                    IF _PRINTMODE <> 2 THEN
                        LINE ((x - fontSize) + j * fontSize + ((c - 1) * (fontSize * 8)), (y - fontSize) + i * fontSize)-STEP(fontSize - ABS(bold), fontSize - ABS(bold)), _DEFAULTCOLOR, BF
                    END IF
                ELSE
                    IF _PRINTMODE = 3 OR _PRINTMODE = 2 THEN
                        LINE ((x - fontSize) + j * fontSize + ((c - 1) * (fontSize * 8)), (y - fontSize) + i * fontSize)-STEP(fontSize - ABS(bold), fontSize - ABS(bold)), _BACKGROUNDCOLOR, BF
                    END IF
                END IF
            NEXT
        NEXT
    NEXT
END SUB

SUB centerLarge (y AS SINGLE, text$, fontSize AS INTEGER, bold AS _BYTE)
    printLarge (_WIDTH - printWidthLarge(text$, fontSize)) / 2, y, text$, fontSize, bold
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
