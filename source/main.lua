-- Torchy's World
-- A Smash Hit-style game for Playdate
-- Use the crank to rotate around the screen, press A to jump, B to shoot!

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"

-- Local references for performance
local gfx <const> = playdate.graphics

-- Import game modules
import "player"
import "world"
import "obstacles"
import "hud"
import "sound"

-- ============================================================
-- GAME STATE MACHINE
-- ============================================================

local STATE_TITLE = 1
local STATE_PLAYING = 2
local STATE_GAMEOVER = 3
local STATE_READY = 4

local gameState = STATE_TITLE
local score = 0
local highScore = 0
local gameSpeed = 1.0
local distance = 0
local frameCount = 0
local obstaclesDestroyed = 0

-- Game objects
local player = nil
local world = nil
local obstacleManager = nil
local hudDisplay = nil
local soundManager = nil

-- Screen constants
local SCREEN_W <const> = 400
local SCREEN_H <const> = 240
local CENTER_X <const> = SCREEN_W / 2
local CENTER_Y <const> = SCREEN_H / 2

-- Title screen animation
local titleBounce = 0
local titleDir = 1
local titleSkaterAngle = 0
local titleFlameFrame = 0

-- Ready countdown
local readyTimer = 0

-- Screen shake
local shakeAmount = 0
local shakeDuration = 0

-- Initialize sound manager globally (persists across games)
soundManager = SoundManager()

-- ============================================================
-- HELPER: Screen shake
-- ============================================================

local function triggerShake(amount, duration)
    shakeAmount = amount
    shakeDuration = duration
end

local function updateShake()
    if shakeDuration > 0 then
        shakeDuration = shakeDuration - 1
        local offsetX = math.random(-shakeAmount, shakeAmount)
        local offsetY = math.random(-shakeAmount, shakeAmount)
        gfx.setDrawOffset(offsetX, offsetY)
    else
        shakeAmount = 0
        gfx.setDrawOffset(0, 0)
    end
end

-- ============================================================
-- GAME STATE: TITLE
-- ============================================================

local function drawTitle()
    gfx.clear(gfx.kColorWhite)
    titleFlameFrame = titleFlameFrame + 1

    -- Radial background particles (preview of gameplay feel)
    for i = 0, 15 do
        local angle = (frameCount * 3 + i * 24) % 360
        local radius = (frameCount * 2 + i * 15) % 160
        local rad = math.rad(angle)
        local px = CENTER_X + radius * math.cos(rad)
        local py = CENTER_Y + radius * math.sin(rad)
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
        local dotSize = math.max(1, math.floor(radius / 80))
        gfx.fillCircleAtPoint(px, py, dotSize)
    end

    -- Title background box
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(40, 20 + titleBounce, 320, 70, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRoundRect(40, 20 + titleBounce, 320, 70, 8)

    -- Title text
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    local titleFont = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(titleFont)
    gfx.drawTextAligned("TORCHY'S WORLD", CENTER_X, 32 + titleBounce, kTextAlignment.center)

    local subFont = gfx.getSystemFont()
    gfx.setFont(subFont)
    gfx.drawTextAligned("Crank & Smash!", CENTER_X, 58 + titleBounce, kTextAlignment.center)

    -- Matchstick preview character orbiting
    local previewRadius = 40
    local skaterRad = math.rad(titleSkaterAngle)
    local skaterX = CENTER_X + previewRadius * math.cos(skaterRad)
    local skaterY = 155 + previewRadius * math.sin(skaterRad)

    -- Orbit circle
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.drawCircleAtPoint(CENTER_X, 155, previewRadius)

    -- Center hub
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, 155, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, 155, 4)

    -- Draw mini matchstick character
    local outX = math.cos(skaterRad)
    local outY = math.sin(skaterRad)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(skaterX, skaterY, skaterX + outX * 10, skaterY + outY * 10)

    gfx.fillCircleAtPoint(skaterX + outX * 12, skaterY + outY * 12, 3)

    local flicker = math.sin(titleFlameFrame * 0.4) * 1.5
    gfx.fillCircleAtPoint(skaterX + outX * (16 + flicker), skaterY + outY * (16 + flicker), 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(skaterX + outX * (16 + flicker), skaterY + outY * (16 + flicker), 3)

    -- Instructions
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.setFont(subFont)

    gfx.drawTextAligned("A=Jump  B=Shoot", CENTER_X, 198, kTextAlignment.center)

    if frameCount % 40 < 28 then
        gfx.drawTextAligned("Press A to Start!", CENTER_X, 213, kTextAlignment.center)
    end

    if highScore > 0 then
        gfx.drawTextAligned("Best: " .. highScore, CENTER_X, 228, kTextAlignment.center)
    end

    -- Animate
    titleBounce = titleBounce + titleDir * 0.3
    if titleBounce > 4 or titleBounce < -4 then
        titleDir = -titleDir
    end
    titleSkaterAngle = (titleSkaterAngle + 3) % 360
end

local function updateTitle()
    frameCount = frameCount + 1
    drawTitle()

    if playdate.buttonJustPressed(playdate.kButtonA) then
        gameState = STATE_READY
        readyTimer = 90
        initGame()
    end
end

-- ============================================================
-- GAME INITIALIZATION
-- ============================================================

function initGame()
    score = 0
    distance = 0
    gameSpeed = 1.0
    frameCount = 0
    shakeAmount = 0
    shakeDuration = 0
    obstaclesDestroyed = 0

    player = Player(CENTER_X, CENTER_Y)
    world = World()
    obstacleManager = ObstacleManager()
    hudDisplay = HUD()

    -- Start background music
    soundManager:startMusic()
end

-- ============================================================
-- GAME STATE: READY (countdown)
-- ============================================================

local function updateReady()
    gfx.clear(gfx.kColorWhite)

    world:draw(CENTER_X, CENTER_Y, gameSpeed)
    player:draw()

    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 12)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 8)

    local seconds = math.ceil(readyTimer / 30)
    local countText = tostring(seconds)
    if seconds <= 0 then
        countText = "GO!"
    end

    local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(boldFont)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    local textW = boldFont:getTextWidth(countText)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(CENTER_X - textW/2 - 20, CENTER_Y - 20, textW + 40, 40, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(CENTER_X - textW/2 - 20, CENTER_Y - 20, textW + 40, 40, 6)
    gfx.drawTextAligned(countText, CENTER_X, CENTER_Y - 10, kTextAlignment.center)

    local subFont = gfx.getSystemFont()
    gfx.setFont(subFont)
    gfx.drawTextAligned("Crank=Rotate  A=Jump  B=Shoot", CENTER_X, CENTER_Y + 30, kTextAlignment.center)

    -- Let player rotate during countdown + whoosh sound
    local crankChange = playdate.getCrankChange()
    player:updateAngle(crankChange)
    soundManager:updateWhoosh(crankChange)
    soundManager:updateMusic(gameSpeed)

    readyTimer = readyTimer - 1
    if readyTimer <= -30 then
        gameState = STATE_PLAYING
    end
end

-- ============================================================
-- GAME STATE: PLAYING
-- ============================================================

local function updatePlaying()
    frameCount = frameCount + 1

    -- Progressive difficulty
    gameSpeed = 1.0 + (distance / 500) * 0.5
    if gameSpeed > 4.0 then
        gameSpeed = 4.0
    end

    -- Get crank input
    local crankChange = playdate.getCrankChange()

    -- Crank whoosh sound
    soundManager:updateWhoosh(crankChange)

    -- Detect jump for sound (check before player:update consumes the input)
    local willJump = playdate.buttonJustPressed(playdate.kButtonA) and not player.isJumping
    local willShoot = playdate.buttonJustPressed(playdate.kButtonB) and player.ammo > 0 and player.shootCooldown <= 0

    -- Update player
    player:update(crankChange, gameSpeed)

    -- Play sounds for actions that just happened
    if willJump then
        soundManager:playJump()
    end
    if willShoot then
        soundManager:playBlaster()
    end

    -- Update world
    world:update(gameSpeed)

    -- Update obstacles
    obstacleManager:update(gameSpeed, distance)

    -- Check projectile-obstacle collisions
    local hits = obstacleManager:checkProjectileCollisions(player.projectiles)
    if hits > 0 then
        score = score + hits * 25
        obstaclesDestroyed = obstaclesDestroyed + hits
        triggerShake(2, 5)
        hudDisplay:showHitCombo(hits, score)
        player:addAmmo(hits)
        soundManager:playHit()
    end

    -- Check player-obstacle collisions
    local collision, collisionType = obstacleManager:checkCollision(player)
    if collision then
        if collisionType == "star" then
            score = score + 50
            player:addAmmo(3)
            soundManager:playStar()
        else
            -- Hit obstacle - game over!
            triggerShake(6, 15)
            soundManager:playGameOver()
            soundManager:stopMusic()
            gameState = STATE_GAMEOVER
            if score > highScore then
                highScore = score
            end
            return
        end
    end

    -- Platform fall check
    if not player.isJumping and not obstacleManager:isOnPlatform(player) then
        player.fallTimer = player.fallTimer + 1
        if player.fallTimer > 10 then
            triggerShake(6, 15)
            soundManager:playGameOver()
            soundManager:stopMusic()
            gameState = STATE_GAMEOVER
            if score > highScore then
                highScore = score
            end
            return
        end
    else
        player.fallTimer = 0
    end

    -- Score based on distance
    distance = distance + gameSpeed
    score = math.max(score, math.floor(distance / 3))

    -- Update music (tempo scales with speed)
    soundManager:updateMusic(gameSpeed)

    -- ---- DRAW EVERYTHING ----
    gfx.clear(gfx.kColorWhite)
    updateShake()

    world:draw(CENTER_X, CENTER_Y, gameSpeed)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, player.orbitRadius)

    obstacleManager:draw(CENTER_X, CENTER_Y, player.orbitRadius)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 4)

    for i = 0, 7 do
        local angle = math.rad(i * 45 + frameCount * 2)
        local x1 = CENTER_X + 10 * math.cos(angle)
        local y1 = CENTER_Y + 10 * math.sin(angle)
        local x2 = CENTER_X + 14 * math.cos(angle)
        local y2 = CENTER_Y + 14 * math.sin(angle)
        gfx.setLineWidth(1)
        gfx.drawLine(x1, y1, x2, y2)
    end

    player:draw()

    hudDisplay:draw(score, highScore, gameSpeed, distance, player.ammo, player.maxAmmo)

    if shakeDuration <= 0 then
        gfx.setDrawOffset(0, 0)
    end
end

-- ============================================================
-- GAME STATE: GAME OVER
-- ============================================================

local gameOverTimer = 0

local function updateGameOver()
    frameCount = frameCount + 1
    gameOverTimer = gameOverTimer + 1

    gfx.clear(gfx.kColorWhite)
    updateShake()

    world:draw(CENTER_X, CENTER_Y, 0)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, player.orbitRadius)

    obstacleManager:draw(CENTER_X, CENTER_Y, player.orbitRadius)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 10)

    player:draw()

    -- Dark overlay
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_W, SCREEN_H)

    -- Game Over panel
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(60, 30, 280, 180, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRoundRect(60, 30, 280, 180, 10)

    local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(boldFont)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.drawTextAligned("GAME OVER", CENTER_X, 42, kTextAlignment.center)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(80, 64, 320, 64)

    local font = gfx.getSystemFont()
    gfx.setFont(font)
    gfx.drawTextAligned("Score: " .. score, CENTER_X, 74, kTextAlignment.center)
    gfx.drawTextAligned("Best:  " .. highScore, CENTER_X, 94, kTextAlignment.center)

    local distStr = string.format("Distance: %.0fm", distance / 10)
    gfx.drawTextAligned(distStr, CENTER_X, 114, kTextAlignment.center)

    gfx.drawTextAligned("Destroyed: " .. obstaclesDestroyed, CENTER_X, 134, kTextAlignment.center)

    if score >= highScore and score > 0 then
        if frameCount % 20 < 14 then
            gfx.setFont(boldFont)
            gfx.drawTextAligned("NEW BEST!", CENTER_X, 156, kTextAlignment.center)
        end
    end

    if gameOverTimer > 45 then
        if frameCount % 30 < 22 then
            gfx.setFont(font)
            gfx.drawTextAligned("Press A to Retry", CENTER_X, 190, kTextAlignment.center)
        end

        if playdate.buttonJustPressed(playdate.kButtonA) then
            gameState = STATE_READY
            readyTimer = 60
            gameOverTimer = 0
            initGame()
        end
    end

    gfx.setDrawOffset(0, 0)
end

-- ============================================================
-- MAIN UPDATE LOOP
-- ============================================================

function playdate.update()
    if gameState == STATE_TITLE then
        updateTitle()
    elseif gameState == STATE_READY then
        updateReady()
    elseif gameState == STATE_PLAYING then
        updatePlaying()
    elseif gameState == STATE_GAMEOVER then
        updateGameOver()
    end

    playdate.timer.updateTimers()
end

-- ============================================================
-- CRANK INDICATOR
-- ============================================================

function playdate.crankUndocked()
end

function playdate.crankDocked()
    if gameState == STATE_PLAYING then
        -- Crank stowed warning could go here
    end
end
