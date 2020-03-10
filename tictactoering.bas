$NOPREFIX

TYPE vector
    x AS SINGLE
    y AS SINGLE
END TYPE

TYPE rings
    x AS SINGLE
    y AS SINGLE
    r1 AS UNSIGNED LONG
    r2 AS UNSIGNED LONG
    r3 AS UNSIGNED LONG
END TYPE

DIM canvas AS LONG
canvas = NEWIMAGE(600, 600, 32)

SCREEN canvas

DIM peg(1 TO 9) AS vector

spacing = 6
l = -HEIGHT / spacing
FOR i = 1 TO 9
    j = j + 1
    IF j > 3 THEN j = 1: l = l + HEIGHT / spacing
    SELECT CASE j
        CASE 1: k = -WIDTH / spacing
        CASE 2: k = 0
        CASE 3: k = WIDTH / spacing
    END SELECT
    peg(i).x = WIDTH / 2 + k
    peg(i).y = HEIGHT / 2 + l
NEXT

DIM c(7) AS UNSIGNED LONG: i = 0
i = i + 1: c(i) = RGB32(55, 105, 183) 'blue
i = i + 1: c(i) = RGB32(122, 177, 83) 'green
i = i + 1: c(i) = RGB32(222, 61, 44) 'red
i = i + 1: c(i) = RGB32(216, 216, 133) 'yellow
i = i + 1: c(i) = RGB32(222, 155, 161) 'pink
i = i + 1: c(i) = RGB32(222, 133, 44) 'orange
i = i + 1: c(i) = RGB32(139, 11, 205) 'purple

DIM circleImage(1 TO i, 1 TO 3) AS LONG
FOR j = 1 TO i
    FOR k = 1 TO 3
        circleImage(j, k) = NEWIMAGE(k * 21, k * 21, 32)
        DEST circleImage(j, k)
        PAINT (0, 0), RGB32(255, 0, 255)
        CircleFill WIDTH / 2, HEIGHT / 2, k * 10, c(j)
        CircleFill WIDTH / 2, HEIGHT / 2, k * (5 + k), RGB32(255, 0, 255)
        CLEARCOLOR RGB32(255, 0, 255)
    NEXT
NEXT

RANDOMIZE TIMER
DEST DISPLAY
DO
    CLS , RGB32(50)
    FOR i = 1 TO 9
        CircleFill peg(i).x, peg(i).y, 3, RGB32(255)
    NEXT
    FOR i = 1 TO _CEIL(RND * 3)
        j = j + 1
        IF j > UBOUND(c) THEN j = 1
        k = _CEIL(RND * 3)
        PUTIMAGE ((WIDTH - WIDTH(circleImage(j, k))) / 2, (HEIGHT - HEIGHT(circleImage(j, k))) / 2), circleImage(j, k)
    NEXT
    LIMIT 1
LOOP


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

FUNCTION dist! (x1!, y1!, x2!, y2!)
    dist! = _HYPOT((x2! - x1!), (y2! - y1!))
END FUNCTION

FUNCTION distB! (v1 AS vector, v2 AS vector)
    distB! = dist!(v1.x, v1.y, v2.x, v2.y)
END FUNCTION

