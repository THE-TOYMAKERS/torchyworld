-- Cronobreak
-- A Smash Hit-style game for Playdate
-- Crank=Rotate, A=Jump, B=Shoot, D-pad=Slow-motion

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"

local gfx <const> = playdate.graphics

import "player"
import "world"
import "obstacles"
import "hud"
import "sound"

-- ============================================================
-- GAME STATE
-- ============================================================

local STATE_MENU = 1
local STATE_HOWTOPLAY = 2
local STATE_PLAYING = 3
local STATE_GAMEOVER = 4
local STATE_READY = 5
local STATE_SCORE_TALLY = 6

local gameState = STATE_MENU
local score = 0
local highScore = 0
local gameSpeed = 1.0
local effectiveSpeed = 1.0  -- After slow-motion applied
local distance = 0
local frameCount = 0
local obstaclesDestroyed = 0

local player = nil
local world = nil
local obstacleManager = nil
local hudDisplay = nil
local soundManager = nil

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240
local CENTER_X <const> = SCREEN_W / 2
local CENTER_Y <const> = SCREEN_H / 2

local titleBounce = 0
local titleDir = 1
local titleSkaterAngle = 0
local titleFlameFrame = 0
local readyTimer = 0
local shakeAmount = 0
local shakeDuration = 0

-- Time Wizard state
local wizardFrame = 0
local wizardMouthOpen = false
local wizardEmoteTimer = 0
local wizardEmoteText = ""

-- Slow-motion visual
local slowMoActive = false

-- Menu state
local menuSelection = 1  -- 1 = Play, 2 = How to Play

-- Game over menu
local gameOverSelection = 1  -- 1 = Retry, 2 = Main Menu

-- Score tally state
local tallyPhase = 0       -- 0=waiting, 1=distance, 2=destroy, 3=speed, 4=total, 5=done
local tallyTimer = 0
local tallyDistanceScore = 0
local tallyDestroyScore = 0
local tallySpeedMultiplier = 0
local tallyTotal = 0
local tallyDisplayDist = 0
local tallyDisplayDestroy = 0
local tallyDisplayTotal = 0
local tallyFinalScore = 0
local tallyFinalDistance = 0
local tallyFinalDestroyed = 0
local tallyFinalSpeed = 0

soundManager = SoundManager()

-- ============================================================
-- HELPERS
-- ============================================================

local function triggerShake(amount, duration)
    shakeAmount = amount
    shakeDuration = duration
end

local function updateShake()
    if shakeDuration > 0 then
        shakeDuration = shakeDuration - 1
        gfx.setDrawOffset(math.random(-shakeAmount, shakeAmount), math.random(-shakeAmount, shakeAmount))
    else
        shakeAmount = 0
        gfx.setDrawOffset(0, 0)
    end
end

-- ============================================================
-- TIME WIZARD DRAWING (center boss, inspired by Time Wizard from Yu-Gi-Oh)
-- Clock face body, wizard hat, angry expressions, staff
-- ============================================================

local function drawTimeWizard(cx, cy, frame, difficulty, angerTimer)
    wizardFrame = frame

    -- === CLOCK BODY ===
    local bodyR = 14
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(cx, cy, bodyR)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx, cy, bodyR - 2)

    -- Clock tick marks
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for i = 0, 11 do
        local a = math.rad(i * 30)
        local iR = bodyR - 4
        local oR = bodyR - 2
        gfx.drawLine(cx + iR*math.cos(a), cy + iR*math.sin(a),
                      cx + oR*math.cos(a), cy + oR*math.sin(a))
    end

    -- Spinning clock hands
    local hourAngle = math.rad(frame * 1.5)
    local minAngle = math.rad(frame * 6)
    gfx.setLineWidth(2)
    gfx.drawLine(cx, cy, cx + 6*math.cos(hourAngle), cy + 6*math.sin(hourAngle))
    gfx.setLineWidth(1)
    gfx.drawLine(cx, cy, cx + 9*math.cos(minAngle), cy + 9*math.sin(minAngle))

    -- Center pin
    gfx.fillCircleAtPoint(cx, cy, 1.5)

    -- === WIZARD HAT ===
    gfx.setColor(gfx.kColorBlack)
    -- Hat base (wide brim)
    gfx.fillRect(cx - 12, cy - bodyR - 2, 24, 4)
    -- Hat cone
    gfx.fillPolygon(
        cx - 8, cy - bodyR - 2,
        cx + 8, cy - bodyR - 2,
        cx, cy - bodyR - 16
    )
    -- Star on hat tip
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx, cy - bodyR - 14, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(cx, cy - bodyR - 14, 1)

    -- === FACE (drawn over clock) ===
    -- Eyes - angrier at higher difficulty
    local eyeY = cy - 2
    local eyeSpread = 4

    if angerTimer > 0 then
        -- FURIOUS: X eyes
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawLine(cx - eyeSpread - 2, eyeY - 2, cx - eyeSpread + 2, eyeY + 2)
        gfx.drawLine(cx - eyeSpread + 2, eyeY - 2, cx - eyeSpread - 2, eyeY + 2)
        gfx.drawLine(cx + eyeSpread - 2, eyeY - 2, cx + eyeSpread + 2, eyeY + 2)
        gfx.drawLine(cx + eyeSpread + 2, eyeY - 2, cx + eyeSpread - 2, eyeY + 2)
        gfx.setLineWidth(1)
    else
        -- Normal angry eyes (angrier with difficulty)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(cx - eyeSpread, eyeY, 2.5)
        gfx.fillCircleAtPoint(cx + eyeSpread, eyeY, 2.5)
        -- White glint
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(cx - eyeSpread - 0.5, eyeY - 0.5, 1)
        gfx.fillCircleAtPoint(cx + eyeSpread - 0.5, eyeY - 0.5, 1)

        -- Eyebrows (angrier with difficulty)
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(1)
        local browAnger = math.min(3, difficulty * 0.3)
        gfx.drawLine(cx - eyeSpread - 3, eyeY - 4 - browAnger, cx - eyeSpread + 2, eyeY - 4)
        gfx.drawLine(cx + eyeSpread + 3, eyeY - 4 - browAnger, cx + eyeSpread - 2, eyeY - 4)
    end

    -- Mouth
    local mouthY = cy + 5
    gfx.setColor(gfx.kColorBlack)
    if angerTimer > 0 then
        -- Shouting (open mouth)
        gfx.fillRect(cx - 3, mouthY - 1, 6, 4)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(cx - 2, mouthY, 4, 2)
    elseif difficulty >= 7 then
        -- Gritting teeth
        gfx.drawLine(cx - 4, mouthY, cx + 4, mouthY)
        gfx.drawLine(cx - 2, mouthY - 1, cx - 2, mouthY + 1)
        gfx.drawLine(cx, mouthY - 1, cx, mouthY + 1)
        gfx.drawLine(cx + 2, mouthY - 1, cx + 2, mouthY + 1)
    elseif difficulty >= 4 then
        -- Angry frown
        gfx.drawLine(cx - 3, mouthY, cx, mouthY + 2)
        gfx.drawLine(cx + 3, mouthY, cx, mouthY + 2)
    else
        -- Slight frown
        gfx.drawLine(cx - 3, mouthY + 1, cx, mouthY)
        gfx.drawLine(cx + 3, mouthY + 1, cx, mouthY)
    end

    -- === STAFF (right side) ===
    local staffX = cx + bodyR + 3
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(staffX, cy - 10, staffX, cy + 12)
    gfx.setLineWidth(1)
    -- Staff orb on top
    gfx.fillCircleAtPoint(staffX, cy - 12, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(staffX, cy - 12, 1.5)

    -- === EMOTE TEXT (!! or >:( etc) ===
    if angerTimer > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        local font = gfx.getSystemFont(gfx.font.kVariantBold)
        gfx.setFont(font)
        if angerTimer % 10 < 7 then
            gfx.drawTextAligned("!!", cx - bodyR - 10, cy - bodyR - 8, kTextAlignment.center)
        end
    end

    gfx.setLineWidth(1)
end

-- ============================================================
-- BIG TIME WIZARD for menu (based on sketch)
-- Clock head, boxy hat w/ hourglass, mustache, armored body,
-- cape, spring legs, big boots, gloved magic hand w/ lightning
-- ============================================================

local function drawTimeWizardBig(cx, cy, frame)
    local bob = math.sin(frame * 0.06) * 3  -- gentle idle bob
    cy = cy + bob

    -- === CAPE (behind body) ===
    gfx.setColor(gfx.kColorBlack)
    local capeSway = math.sin(frame * 0.08) * 3
    -- Left cape panel
    gfx.fillPolygon(
        cx - 18, cy - 4,
        cx - 30 - capeSway, cy + 40,
        cx - 22 - capeSway, cy + 50,
        cx - 10, cy + 20
    )
    -- Right cape panel
    gfx.fillPolygon(
        cx + 18, cy - 4,
        cx + 30 + capeSway, cy + 40,
        cx + 22 + capeSway, cy + 50,
        cx + 10, cy + 20
    )
    -- Cape bottom curve (flowing)
    gfx.setDitherPattern(0.3, gfx.image.kDitherTypeBayer4x4)
    gfx.fillPolygon(
        cx - 22 - capeSway, cy + 50,
        cx - 14 - capeSway * 0.5, cy + 56,
        cx, cy + 48,
        cx + 14 + capeSway * 0.5, cy + 56,
        cx + 22 + capeSway, cy + 50,
        cx + 10, cy + 20,
        cx - 10, cy + 20
    )

    -- === ARMORED BODY ===
    gfx.setColor(gfx.kColorBlack)
    -- Main torso shape
    gfx.fillPolygon(
        cx - 16, cy - 6,
        cx + 16, cy - 6,
        cx + 14, cy + 22,
        cx - 14, cy + 22
    )
    -- Inner armor (white area with hourglass)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(
        cx - 12, cy - 2,
        cx + 12, cy - 2,
        cx + 10, cy + 18,
        cx - 10, cy + 18
    )
    -- Hourglass emblem on chest
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    -- Top triangle of hourglass
    gfx.fillPolygon(cx - 5, cy + 2, cx + 5, cy + 2, cx, cy + 8)
    -- Bottom triangle of hourglass
    gfx.fillPolygon(cx - 5, cy + 16, cx + 5, cy + 16, cx, cy + 10)
    -- Hourglass center dot
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx, cy + 9, 1)
    -- Armor edge lines
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.drawLine(cx - 16, cy - 6, cx - 14, cy + 22)
    gfx.drawLine(cx + 16, cy - 6, cx + 14, cy + 22)

    -- === SPRING/SEGMENTED LEGS ===
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    local legSpread = 6
    for seg = 0, 4 do
        local segY = cy + 22 + seg * 5
        local zigzag = (seg % 2 == 0) and 3 or -3
        -- Left leg
        gfx.drawLine(cx - legSpread + zigzag, segY, cx - legSpread - zigzag, segY + 5)
        -- Right leg
        gfx.drawLine(cx + legSpread + zigzag, segY, cx + legSpread - zigzag, segY + 5)
    end

    -- === BIG ROUND BOOTS ===
    local bootY = cy + 47
    gfx.setColor(gfx.kColorBlack)
    -- Left boot
    gfx.fillCircleAtPoint(cx - legSpread - 1, bootY, 7)
    gfx.fillRect(cx - legSpread - 8, bootY - 2, 14, 6)
    -- Boot sole
    gfx.fillRect(cx - legSpread - 9, bootY + 3, 16, 3)
    -- Boot highlight
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx - legSpread - 2, bootY - 2, 2)
    -- Right boot
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(cx + legSpread + 1, bootY, 7)
    gfx.fillRect(cx + legSpread - 6, bootY - 2, 14, 6)
    gfx.fillRect(cx + legSpread - 7, bootY + 3, 16, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx + legSpread, bootY - 2, 2)

    -- === LEFT ARM - GLOVED MAGIC HAND (raised) ===
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    -- Upper arm
    gfx.drawLine(cx - 16, cy, cx - 26, cy - 12)
    -- Forearm (raised up)
    gfx.drawLine(cx - 26, cy - 12, cx - 28, cy - 28)

    -- Glove (cartoon style - round palm + fingers)
    local gloveX, gloveY = cx - 28, cy - 32
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(gloveX, gloveY, 6) -- palm
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(gloveX, gloveY, 4) -- white glove interior
    -- Fingers (3 stubby fingers + thumb)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(gloveX - 4, gloveY - 5, 2.5) -- left finger
    gfx.fillCircleAtPoint(gloveX, gloveY - 7, 2.5)      -- middle finger
    gfx.fillCircleAtPoint(gloveX + 4, gloveY - 5, 2.5)  -- right finger
    gfx.fillCircleAtPoint(gloveX + 6, gloveY - 1, 2)    -- thumb
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(gloveX - 4, gloveY - 5, 1)
    gfx.fillCircleAtPoint(gloveX, gloveY - 7, 1)
    gfx.fillCircleAtPoint(gloveX + 4, gloveY - 5, 1)

    -- === LIGHTNING BOLTS from hand ===
    local sparkPhase = frame % 20
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    if sparkPhase < 15 then
        -- Bolt 1 (zigzag upward-left)
        local bx, by = gloveX - 4, gloveY - 12
        gfx.drawLine(bx, by, bx - 3, by - 6)
        gfx.drawLine(bx - 3, by - 6, bx + 1, by - 8)
        gfx.drawLine(bx + 1, by - 8, bx - 2, by - 14)
    end
    if sparkPhase < 10 or sparkPhase > 14 then
        -- Bolt 2 (zigzag upward)
        local bx, by = gloveX + 2, gloveY - 12
        gfx.drawLine(bx, by, bx + 2, by - 5)
        gfx.drawLine(bx + 2, by - 5, bx - 1, by - 7)
        gfx.drawLine(bx - 1, by - 7, bx + 3, by - 13)
    end
    -- Small sparks/dots
    if frame % 6 < 4 then
        gfx.fillCircleAtPoint(gloveX - 6, gloveY - 16, 1)
        gfx.fillCircleAtPoint(gloveX + 5, gloveY - 15, 1)
    end

    -- === RIGHT ARM - COILED/GAUNTLET ARM ===
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    -- Upper arm
    gfx.drawLine(cx + 16, cy, cx + 24, cy + 4)
    -- Coiled forearm (spring pattern)
    local armX = cx + 24
    for coil = 0, 3 do
        local coilY = cy + 4 + coil * 5
        gfx.drawLine(armX - 2, coilY, armX + 4, coilY + 2)
        gfx.drawLine(armX + 4, coilY + 2, armX - 2, coilY + 5)
    end
    -- Fist at end
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(armX + 1, cy + 26, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(armX, cy + 25, 2)

    -- === CLOCK FACE HEAD ===
    local headR = 16
    local headY = cy - 16
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(cx, headY, headR)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx, headY, headR - 2)

    -- Clock tick marks
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for i = 0, 11 do
        local a = math.rad(i * 30)
        local iR = headR - 5
        local oR = headR - 2
        gfx.drawLine(cx + iR*math.cos(a), headY + iR*math.sin(a),
                      cx + oR*math.cos(a), headY + oR*math.sin(a))
    end

    -- Spinning clock hands
    local hourAngle = math.rad(frame * 1.5)
    local minAngle = math.rad(frame * 6)
    gfx.setLineWidth(2)
    gfx.drawLine(cx, headY, cx + 7*math.cos(hourAngle), headY + 7*math.sin(hourAngle))
    gfx.setLineWidth(1)
    gfx.drawLine(cx, headY, cx + 11*math.cos(minAngle), headY + 11*math.sin(minAngle))
    -- Center pin
    gfx.fillCircleAtPoint(cx, headY, 2)

    -- === FACE on clock ===
    -- Left eye (big, visible)
    local eyeX, eyeY = cx - 4, headY - 1
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(eyeX, eyeY, 3.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(eyeX, eyeY, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(eyeX + 0.5, eyeY, 1.5) -- pupil
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(eyeX - 0.5, eyeY - 1, 0.7) -- glint

    -- Right eye (slightly hidden by clock hand sometimes)
    local reyeX = cx + 4
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(reyeX, eyeY, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(reyeX, eyeY, 1.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(reyeX + 0.5, eyeY, 1) -- pupil

    -- Angry eyebrows
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(cx - 8, headY - 6, cx - 2, headY - 4) -- left brow (angled down inward)
    gfx.drawLine(cx + 8, headY - 6, cx + 2, headY - 4) -- right brow

    -- Mouth (slight angry smirk)
    gfx.setLineWidth(1)
    gfx.drawLine(cx - 4, headY + 6, cx - 1, headY + 8)
    gfx.drawLine(cx + 4, headY + 6, cx - 1, headY + 8)

    -- === BIG SWOOPING MUSTACHE ===
    gfx.setColor(gfx.kColorBlack)
    -- Left mustache curl
    gfx.setLineWidth(3)
    gfx.drawLine(cx - 2, headY + 8, cx - 8, headY + 6)
    gfx.drawLine(cx - 8, headY + 6, cx - 14, headY + 10)
    gfx.drawLine(cx - 14, headY + 10, cx - 16, headY + 8) -- curl up at tip
    -- Fill left mustache
    gfx.setLineWidth(1)
    gfx.fillPolygon(
        cx - 1, headY + 7,
        cx - 8, headY + 4,
        cx - 14, headY + 8,
        cx - 16, headY + 7,
        cx - 14, headY + 12,
        cx - 8, headY + 9,
        cx - 1, headY + 10
    )
    -- Right mustache curl
    gfx.setLineWidth(3)
    gfx.drawLine(cx + 2, headY + 8, cx + 8, headY + 6)
    gfx.drawLine(cx + 8, headY + 6, cx + 14, headY + 10)
    gfx.drawLine(cx + 14, headY + 10, cx + 16, headY + 8)
    gfx.fillPolygon(
        cx + 1, headY + 7,
        cx + 8, headY + 4,
        cx + 14, headY + 8,
        cx + 16, headY + 7,
        cx + 14, headY + 12,
        cx + 8, headY + 9,
        cx + 1, headY + 10
    )

    -- === BOXY WIZARD HAT ===
    local hatBase = headY - headR + 1
    gfx.setColor(gfx.kColorBlack)
    -- Wide brim
    gfx.fillRect(cx - 18, hatBase - 3, 36, 5)
    -- Boxy hat body
    gfx.fillRect(cx - 12, hatBase - 18, 24, 16)
    -- Hat interior detail (lighter band)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(cx - 10, hatBase - 16, 20, 3)
    -- Hourglass symbol on hat
    gfx.setColor(gfx.kColorWhite)
    gfx.setLineWidth(1)
    local hgX, hgY = cx, hatBase - 10
    gfx.drawLine(hgX - 3, hgY - 3, hgX + 3, hgY - 3)
    gfx.drawLine(hgX - 3, hgY - 3, hgX, hgY)
    gfx.drawLine(hgX + 3, hgY - 3, hgX, hgY)
    gfx.drawLine(hgX - 3, hgY + 3, hgX + 3, hgY + 3)
    gfx.drawLine(hgX - 3, hgY + 3, hgX, hgY)
    gfx.drawLine(hgX + 3, hgY + 3, hgX, hgY)
    -- Small antenna/point on top
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(cx, hatBase - 18, cx, hatBase - 24)
    gfx.fillCircleAtPoint(cx, hatBase - 25, 2)
    -- Small clock on antenna ball
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(cx, hatBase - 25, 1)

    gfx.setLineWidth(1)
end

-- ============================================================
-- MENU (Home Screen)
-- ============================================================

local function drawMenuBackground()
    gfx.clear(gfx.kColorWhite)
    titleFlameFrame = titleFlameFrame + 1

    -- Floating clock particles in background
    for i = 0, 11 do
        local angle = (frameCount * 2 + i * 30) % 360
        local radius = (frameCount * 1.5 + i * 18) % 180
        local rad = math.rad(angle)
        local px = CENTER_X + radius*math.cos(rad)
        local py = CENTER_Y + radius*math.sin(rad)
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer4x4)
        local sz = math.max(1, math.floor(radius / 90))
        gfx.fillCircleAtPoint(px, py, sz)
        -- Tiny clock hand on larger particles
        if sz >= 2 then
            local tinyAngle = math.rad(frameCount * 8 + i * 60)
            gfx.setColor(gfx.kColorBlack)
            gfx.setLineWidth(1)
            gfx.drawLine(px, py, px + sz*math.cos(tinyAngle), py + sz*math.sin(tinyAngle))
        end
    end

    -- Title banner
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(60, 4 + titleBounce, 280, 42, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRoundRect(60, 4 + titleBounce, 280, 42, 8)

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.setFont(gfx.getSystemFont(gfx.font.kVariantBold))
    gfx.drawTextAligned("CRONOBREAK", CENTER_X, 9 + titleBounce, kTextAlignment.center)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawTextAligned("vs. The Time Wizard!", CENTER_X, 28 + titleBounce, kTextAlignment.center)

    -- BIG Time Wizard in center of menu
    drawTimeWizardBig(CENTER_X, 120, titleFlameFrame)

    titleBounce = titleBounce + titleDir * 0.3
    if titleBounce > 3 or titleBounce < -3 then titleDir = -titleDir end
    titleSkaterAngle = (titleSkaterAngle + 3) % 360
end

local function updateMenu()
    frameCount = frameCount + 1
    drawMenuBackground()

    local bf = gfx.getSystemFont(gfx.font.kVariantBold)
    local nf = gfx.getSystemFont()

    -- Menu options
    local menuY = 178
    local options = {"Play", "How to Play"}

    for i, label in ipairs(options) do
        local y = menuY + (i - 1) * 24
        local tw = bf:getTextWidth(label) + 40

        if i == menuSelection then
            -- Selected: filled background
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.setFont(bf)
            gfx.drawTextAligned(label, CENTER_X, y, kTextAlignment.center)

            -- Arrow indicator
            local arrowX = CENTER_X - tw/2 - 2
            if frameCount % 20 < 14 then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillPolygon(arrowX - 8, y + 4, arrowX - 8, y + 14, arrowX - 2, y + 9)
            end
        else
            -- Unselected
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            gfx.setFont(nf)
            gfx.drawTextAligned(label, CENTER_X, y, kTextAlignment.center)
        end
    end

    -- High score
    if highScore > 0 then
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.setFont(nf)
        gfx.drawTextAligned("Best: " .. highScore, CENTER_X, 228, kTextAlignment.center)
    end

    -- Input
    if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonDown) then
        menuSelection = menuSelection == 1 and 2 or 1
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        if menuSelection == 1 then
            gameState = STATE_READY; readyTimer = 90; initGame()
        else
            gameState = STATE_HOWTOPLAY
        end
    end
end

-- ============================================================
-- HOW TO PLAY
-- ============================================================

local function updateHowToPlay()
    frameCount = frameCount + 1
    gfx.clear(gfx.kColorWhite)

    local bf = gfx.getSystemFont(gfx.font.kVariantBold)
    local nf = gfx.getSystemFont()

    -- Title
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(60, 8, 280, 28, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawRoundRect(60, 8, 280, 28, 6)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.setFont(bf)
    gfx.drawTextAligned("HOW TO PLAY", CENTER_X, 13, kTextAlignment.center)

    -- Controls
    gfx.setFont(nf)
    local startY = 48
    local lineH = 22

    local controls = {
        {"Crank", "Rotate around the ring"},
        {"A Button", "Jump over gaps"},
        {"B Button", "Shoot fireballs inward"},
        {"D-Pad", "Hold for slow motion"},
    }

    for i, ctrl in ipairs(controls) do
        local y = startY + (i - 1) * lineH

        -- Control name (bold)
        gfx.setFont(bf)
        gfx.drawText(ctrl[1], 50, y)

        -- Description
        gfx.setFont(nf)
        gfx.drawText(ctrl[2], 150, y)

        -- Separator line
        if i < #controls then
            gfx.setColor(gfx.kColorBlack)
            gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
            gfx.drawLine(50, y + lineH - 4, 350, y + lineH - 4)
        end
    end

    -- Tips section
    local tipsY = startY + #controls * lineH + 8
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.drawLine(50, tipsY, 350, tipsY)

    gfx.setFont(bf)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.drawText("Tips:", 50, tipsY + 6)

    gfx.setFont(nf)
    gfx.drawText("- Destroy enemies to earn ammo", 50, tipsY + 24)
    gfx.drawText("- Grab bubbles for a shield", 50, tipsY + 40)
    gfx.drawText("- Slow-mo costs ammo over time", 50, tipsY + 56)
    gfx.drawText("- Speed increases with distance", 50, tipsY + 72)

    -- Back prompt
    if frameCount % 30 < 22 then
        gfx.setFont(nf)
        gfx.drawTextAligned("Press B to go back", CENTER_X, 222, kTextAlignment.center)
    end

    if playdate.buttonJustPressed(playdate.kButtonB) or playdate.buttonJustPressed(playdate.kButtonA) then
        gameState = STATE_MENU
    end
end

-- ============================================================
-- INIT
-- ============================================================

function initGame()
    score = 0; distance = 0; gameSpeed = 1.0; effectiveSpeed = 1.0
    frameCount = 0; shakeAmount = 0; shakeDuration = 0; obstaclesDestroyed = 0
    wizardEmoteTimer = 0; slowMoActive = false

    player = Player(CENTER_X, CENTER_Y)
    world = World()
    obstacleManager = ObstacleManager()
    hudDisplay = HUD()
    soundManager:startMusic()
end

-- ============================================================
-- READY
-- ============================================================

local startScoreTally  -- forward declaration

local function updateReady()
    gfx.clear(gfx.kColorWhite)
    world:draw(CENTER_X, CENTER_Y, gameSpeed)
    player:draw()
    drawTimeWizard(CENTER_X, CENTER_Y, readyTimer, 1, 0)

    local s = math.ceil(readyTimer / 30)
    local ct = s <= 0 and "GO!" or tostring(s)
    local bf = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(bf); gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    local tw = bf:getTextWidth(ct)
    gfx.setColor(gfx.kColorWhite); gfx.fillRoundRect(CENTER_X-tw/2-20, CENTER_Y-45, tw+40, 30, 6)
    gfx.setColor(gfx.kColorBlack); gfx.drawRoundRect(CENTER_X-tw/2-20, CENTER_Y-45, tw+40, 30, 6)
    gfx.drawTextAligned(ct, CENTER_X, CENTER_Y - 42, kTextAlignment.center)

    gfx.setFont(gfx.getSystemFont())
    gfx.drawTextAligned("Crank=Rotate A=Jump B=Shoot", CENTER_X, CENTER_Y + 30, kTextAlignment.center)

    local cc = playdate.getCrankChange()
    player:updateAngle(cc)
    soundManager:updateWhoosh(cc)
    soundManager:updateMusic(gameSpeed)

    readyTimer = readyTimer - 1
    if readyTimer <= -30 then gameState = STATE_PLAYING end
end

-- ============================================================
-- PLAYING
-- ============================================================

local function updatePlaying()
    frameCount = frameCount + 1

    gameSpeed = 1.0 + (distance / 500) * 0.5
    if gameSpeed > 4.0 then gameSpeed = 4.0 end

    local crankChange = playdate.getCrankChange()
    soundManager:updateWhoosh(crankChange)

    local willJump = playdate.buttonJustPressed(playdate.kButtonA) and not player.isJumping
    local willShoot = playdate.buttonJustPressed(playdate.kButtonB) and player.ammo > 0 and player.shootCooldown <= 0

    player:update(crankChange, gameSpeed)

    if willJump then soundManager:playJump() end
    if willShoot then soundManager:playBlaster() end

    -- Apply slow-motion
    slowMoActive = player.slowMotionActive
    if slowMoActive then
        effectiveSpeed = gameSpeed * 0.3
    else
        effectiveSpeed = gameSpeed
    end

    world:update(effectiveSpeed, distance)
    obstacleManager:update(effectiveSpeed, distance)

    -- Wizard emote timer
    if wizardEmoteTimer > 0 then wizardEmoteTimer = wizardEmoteTimer - 1 end

    -- Projectile hits
    local hits = obstacleManager:checkProjectileCollisions(player.projectiles)
    if hits > 0 then
        score = score + hits * 25
        obstaclesDestroyed = obstaclesDestroyed + hits
        triggerShake(2, 5)
        hudDisplay:showHitCombo(hits, score)
        player:addAmmo(hits)
        soundManager:playHit()
        wizardEmoteTimer = 30
    end

    -- Player collisions
    local collision, cType = obstacleManager:checkCollision(player)
    if collision then
        if cType == "bubble" then
            player:activateShield()
            soundManager:playStar()
            score = score + 10
        elseif cType == "ammo_crate" then
            player:addAmmo(5)
            soundManager:playStar()
            score = score + 5
        else
            if player:useShield() then
                triggerShake(3, 8); soundManager:playHit()
            else
                triggerShake(6, 15); soundManager:playGameOver(); soundManager:stopMusic()
                startScoreTally()
                return
            end
        end
    end

    -- Platform check
    if not player.isJumping and not obstacleManager:isOnPlatform(player) then
        player.fallTimer = player.fallTimer + 1
        if player.fallTimer > 3 then
            if player:useShield() then
                triggerShake(3, 8); soundManager:playHit(); player.fallTimer = 0
            else
                triggerShake(6, 15); soundManager:playGameOver(); soundManager:stopMusic()
                startScoreTally()
                return
            end
        end
    else
        player.fallTimer = 0
    end

    distance = distance + effectiveSpeed
    score = math.max(score, math.floor(distance / 3))
    soundManager:updateMusic(effectiveSpeed)

    -- ---- DRAW ----
    gfx.clear(gfx.kColorWhite)
    updateShake()

    world:draw(CENTER_X, CENTER_Y, effectiveSpeed)

    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, player.orbitRadius)

    obstacleManager:draw(CENTER_X, CENTER_Y, player.orbitRadius)

    -- Time Wizard at center (replaces plain hub)
    local wizAnger = obstacleManager.wizardAngerTimer
    if wizardEmoteTimer > 0 then wizAnger = math.max(wizAnger, wizardEmoteTimer) end
    drawTimeWizard(CENTER_X, CENTER_Y, frameCount, obstacleManager.difficultyLevel, wizAnger)

    player:draw()

    hudDisplay:draw(score, highScore, gameSpeed, distance, player.ammo, player.maxAmmo, slowMoActive)

    -- Slow-motion visual effect: dither border
    if slowMoActive then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
        -- Top and bottom bars
        gfx.fillRect(0, 0, SCREEN_W, 8)
        gfx.fillRect(0, SCREEN_H - 8, SCREEN_W, 8)
        -- Side bars
        gfx.fillRect(0, 0, 8, SCREEN_H)
        gfx.fillRect(SCREEN_W - 8, 0, 8, SCREEN_H)

        -- "SLOW" text
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.setFont(gfx.getSystemFont(gfx.font.kVariantBold))
        if frameCount % 10 < 7 then
            gfx.drawTextAligned("SLOW", CENTER_X, 10, kTextAlignment.center)
        end
    end

    if shakeDuration <= 0 then gfx.setDrawOffset(0, 0) end
end

-- ============================================================
-- SCORE TALLY (animated score breakdown)
-- ============================================================

startScoreTally = function()
    gameState = STATE_SCORE_TALLY
    tallyPhase = 0
    tallyTimer = 0
    tallyFinalDistance = distance
    tallyFinalDestroyed = obstaclesDestroyed
    tallyFinalSpeed = gameSpeed

    -- Calculate score components
    tallyDistanceScore = math.floor(tallyFinalDistance / 10)
    tallyDestroyScore = tallyFinalDestroyed * 25
    tallySpeedMultiplier = math.floor(tallyFinalSpeed * 10) / 10  -- round to 0.1
    tallyTotal = math.floor((tallyDistanceScore + tallyDestroyScore) * tallySpeedMultiplier)

    -- Display counters (count up to target)
    tallyDisplayDist = 0
    tallyDisplayDestroy = 0
    tallyDisplayTotal = 0
    tallyFinalScore = tallyTotal

    if tallyFinalScore > highScore then highScore = tallyFinalScore end
end

local function updateScoreTally()
    frameCount = frameCount + 1
    tallyTimer = tallyTimer + 1

    gfx.clear(gfx.kColorWhite)

    -- Background game world (frozen)
    world:draw(CENTER_X, CENTER_Y, 0)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_W, SCREEN_H)

    -- Panel
    gfx.setColor(gfx.kColorWhite); gfx.fillRoundRect(50, 20, 300, 200, 10)
    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(3); gfx.drawRoundRect(50, 20, 300, 200, 10)

    local bf = gfx.getSystemFont(gfx.font.kVariantBold)
    local nf = gfx.getSystemFont()
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    -- Title
    gfx.setFont(bf)
    gfx.drawTextAligned("SCORE BREAKDOWN", CENTER_X, 28, kTextAlignment.center)
    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(2); gfx.drawLine(70, 48, 330, 48)

    -- Phase progression (each phase starts after a delay)
    local phaseDelay = 30  -- frames before first phase
    local countSpeed = 8   -- how fast numbers count up

    -- Phase 1: Distance bonus
    if tallyTimer > phaseDelay then
        if tallyPhase < 1 then tallyPhase = 1 end
        local elapsed = tallyTimer - phaseDelay
        tallyDisplayDist = math.min(tallyDistanceScore, math.floor(elapsed * countSpeed))

        gfx.setFont(nf)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawText("Distance Bonus:", 75, 58)
        gfx.setFont(bf)
        gfx.drawTextAligned(tostring(tallyDisplayDist), 320, 58, kTextAlignment.right)

        -- Show distance value
        gfx.setFont(nf)
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.4, gfx.image.kDitherTypeBayer4x4)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawText(string.format("(%.0fm)", tallyFinalDistance / 10), 75, 74)
    end

    -- Phase 2: Destroy bonus
    local phase2Start = phaseDelay + math.ceil(tallyDistanceScore / countSpeed) + 15
    if tallyTimer > phase2Start then
        if tallyPhase < 2 then tallyPhase = 2 end
        local elapsed = tallyTimer - phase2Start
        tallyDisplayDestroy = math.min(tallyDestroyScore, math.floor(elapsed * countSpeed))

        gfx.setFont(nf)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawText("Enemies Destroyed:", 75, 96)
        gfx.setFont(bf)
        gfx.drawTextAligned(tostring(tallyDisplayDestroy), 320, 96, kTextAlignment.right)

        gfx.setFont(nf)
        gfx.drawText(string.format("(%d x 25)", tallyFinalDestroyed), 75, 112)
    end

    -- Phase 3: Speed multiplier
    local phase3Start = phase2Start + math.ceil(tallyDestroyScore / countSpeed) + 15
    if tallyTimer > phase3Start then
        if tallyPhase < 3 then tallyPhase = 3 end

        gfx.setFont(nf)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawText("Speed Multiplier:", 75, 134)
        gfx.setFont(bf)
        gfx.drawTextAligned(string.format("x%.1f", tallySpeedMultiplier), 320, 134, kTextAlignment.right)
    end

    -- Phase 4: Total
    local phase4Start = phase3Start + 20
    if tallyTimer > phase4Start then
        if tallyPhase < 4 then tallyPhase = 4 end
        local elapsed = tallyTimer - phase4Start
        tallyDisplayTotal = math.min(tallyTotal, math.floor(elapsed * countSpeed * 2))

        -- Separator line
        gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(2)
        gfx.drawLine(70, 155, 330, 155)

        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.setFont(bf)
        gfx.drawText("TOTAL:", 75, 162)
        gfx.drawTextAligned(tostring(tallyDisplayTotal), 320, 162, kTextAlignment.right)

        -- New best indicator
        if tallyFinalScore >= highScore and tallyFinalScore > 0 then
            if frameCount % 20 < 14 then
                gfx.drawTextAligned("NEW BEST!", CENTER_X, 182, kTextAlignment.center)
            end
        end
    end

    -- Phase 5: Done counting, show continue prompt
    local phase5Start = phase4Start + math.ceil(tallyTotal / (countSpeed * 2)) + 10
    if tallyTimer > phase5Start then
        if tallyPhase < 5 then tallyPhase = 5 end
    end

    -- Skip button: press A to finish counting instantly
    if tallyPhase < 5 and playdate.buttonJustPressed(playdate.kButtonA) then
        tallyTimer = phase5Start + 1
        tallyDisplayDist = tallyDistanceScore
        tallyDisplayDestroy = tallyDestroyScore
        tallyDisplayTotal = tallyTotal
        tallyPhase = 5
    end

    -- Once done, show continue
    if tallyPhase >= 5 then
        if frameCount % 30 < 22 then
            gfx.setFont(nf)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            gfx.drawTextAligned("Press A to continue", CENTER_X, 200, kTextAlignment.center)
        end
        if playdate.buttonJustPressed(playdate.kButtonA) then
            gameState = STATE_GAMEOVER
            gameOverSelection = 1
        end
    end
end

-- ============================================================
-- GAME OVER (Retry / Main Menu selection)
-- ============================================================

local gameOverTimer = 0

local function updateGameOver()
    frameCount = frameCount + 1
    gameOverTimer = gameOverTimer + 1

    gfx.clear(gfx.kColorWhite)
    updateShake()

    world:draw(CENTER_X, CENTER_Y, 0)

    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, player.orbitRadius)
    obstacleManager:draw(CENTER_X, CENTER_Y, player.orbitRadius)
    drawTimeWizard(CENTER_X, CENTER_Y, frameCount, obstacleManager.difficultyLevel, 0)
    player:draw()

    -- Overlay
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_W, SCREEN_H)

    -- Panel
    gfx.setColor(gfx.kColorWhite); gfx.fillRoundRect(80, 50, 240, 140, 10)
    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(3); gfx.drawRoundRect(80, 50, 240, 140, 10)

    local bf = gfx.getSystemFont(gfx.font.kVariantBold)
    local nf = gfx.getSystemFont()
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    gfx.setFont(bf)
    gfx.drawTextAligned("GAME OVER", CENTER_X, 58, kTextAlignment.center)

    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(2); gfx.drawLine(100, 78, 300, 78)

    -- Score summary (compact)
    gfx.setFont(nf)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.drawTextAligned("Score: " .. tallyFinalScore .. "  Best: " .. highScore, CENTER_X, 86, kTextAlignment.center)

    if tallyFinalScore >= highScore and tallyFinalScore > 0 and frameCount % 20 < 14 then
        gfx.setFont(bf)
        gfx.drawTextAligned("NEW BEST!", CENTER_X, 106, kTextAlignment.center)
    end

    -- Menu options
    if gameOverTimer > 20 then
        local options = {"Retry", "Main Menu"}
        local menuY = 130

        for i, label in ipairs(options) do
            local y = menuY + (i - 1) * 24
            local tw = bf:getTextWidth(label) + 30

            if i == gameOverSelection then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
                gfx.setFont(bf)
                gfx.drawTextAligned(label, CENTER_X, y, kTextAlignment.center)

                -- Arrow
                if frameCount % 20 < 14 then
                    gfx.setColor(gfx.kColorBlack)
                    local arrowX = CENTER_X - tw/2 - 2
                    gfx.fillPolygon(arrowX - 8, y + 4, arrowX - 8, y + 14, arrowX - 2, y + 9)
                end
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRoundRect(CENTER_X - tw/2, y - 2, tw, 20, 4)
                gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
                gfx.setFont(nf)
                gfx.drawTextAligned(label, CENTER_X, y, kTextAlignment.center)
            end
        end

        -- Input
        if playdate.buttonJustPressed(playdate.kButtonUp) or playdate.buttonJustPressed(playdate.kButtonDown) then
            gameOverSelection = gameOverSelection == 1 and 2 or 1
        end

        if playdate.buttonJustPressed(playdate.kButtonA) then
            if gameOverSelection == 1 then
                -- Retry
                gameState = STATE_READY; readyTimer = 60; gameOverTimer = 0; initGame()
            else
                -- Main Menu
                gameState = STATE_MENU; gameOverTimer = 0; menuSelection = 1
            end
        end
    end

    gfx.setDrawOffset(0, 0)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================

function playdate.update()
    if gameState == STATE_MENU then updateMenu()
    elseif gameState == STATE_HOWTOPLAY then updateHowToPlay()
    elseif gameState == STATE_READY then updateReady()
    elseif gameState == STATE_PLAYING then updatePlaying()
    elseif gameState == STATE_SCORE_TALLY then updateScoreTally()
    elseif gameState == STATE_GAMEOVER then updateGameOver()
    end
    playdate.timer.updateTimers()
end

function playdate.crankUndocked() end
function playdate.crankDocked() end
