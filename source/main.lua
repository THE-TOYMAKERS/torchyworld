-- Torchy's World
-- A high-speed infinite runner for Playdate
-- Use the crank to rotate 360° around the screen, press A to jump!

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/animation"

-- Local references for performance
local gfx <const> = playdate.graphics
local geo <const> = playdate.geometry

-- Import game modules
import "player"
import "world"
import "obstacles"
import "hud"

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

-- Game objects
local player = nil
local world = nil
local obstacleManager = nil
local hudDisplay = nil

-- Screen constants
local SCREEN_W <const> = 400
local SCREEN_H <const> = 240
local CENTER_X <const> = SCREEN_W / 2
local CENTER_Y <const> = SCREEN_H / 2

-- Title screen animation
local titleBounce = 0
local titleDir = 1
local titleSkaterAngle = 0

-- Ready countdown
local readyTimer = 0
local readyText = ""

-- Screen shake
local shakeAmount = 0
local shakeDuration = 0

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

    -- Animated background pattern
    for i = 0, 10 do
        local x = (frameCount * 2 + i * 40) % (SCREEN_W + 40) - 20
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(x, 0, 20, SCREEN_H)
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
    gfx.drawTextAligned("Crank It Up!", CENTER_X, 58 + titleBounce, kTextAlignment.center)

    -- Rotating skater preview
    local previewRadius = 40
    local skaterX = CENTER_X + previewRadius * math.cos(math.rad(titleSkaterAngle))
    local skaterY = 155 + previewRadius * math.sin(math.rad(titleSkaterAngle))

    -- Draw orbit circle
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.drawCircleAtPoint(CENTER_X, 155, previewRadius)

    -- Draw center hub
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, 155, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, 155, 4)

    -- Draw skater dot
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(skaterX, skaterY, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(skaterX, skaterY, 6)

    -- Instructions
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.setFont(subFont)

    -- Blinking "Press A"
    if frameCount % 40 < 28 then
        gfx.drawTextAligned("Press A to Start!", CENTER_X, 210, kTextAlignment.center)
    end

    -- High score
    if highScore > 0 then
        gfx.drawTextAligned("Best: " .. highScore, CENTER_X, 225, kTextAlignment.center)
    end

    -- Animate
    titleBounce = titleBounce + titleDir * 0.3
    if titleBounce > 4 or titleBounce < -4 then
        titleDir = -titleDir
    end
    titleSkaterAngle = (titleSkaterAngle + 3) % 360
end

local function updateTitle()
    drawTitle()

    if playdate.buttonJustPressed(playdate.kButtonA) then
        gameState = STATE_READY
        readyTimer = 90 -- 3 seconds at 30fps
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

    player = Player(CENTER_X, CENTER_Y)
    world = World()
    obstacleManager = ObstacleManager()
    hudDisplay = HUD()
end

-- ============================================================
-- GAME STATE: READY (countdown)
-- ============================================================

local function updateReady()
    gfx.clear(gfx.kColorWhite)

    -- Draw the game world in background
    world:draw(CENTER_X, CENTER_Y, gameSpeed)
    player:draw()

    -- Draw center hub
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 12)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 8)

    -- Countdown overlay
    local seconds = math.ceil(readyTimer / 30)
    local countText = tostring(seconds)
    if seconds <= 0 then
        countText = "GO!"
    end

    -- Big countdown number
    local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(boldFont)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    -- Background for readability
    local textW = boldFont:getTextWidth(countText)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(CENTER_X - textW/2 - 20, CENTER_Y - 20, textW + 40, 40, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(CENTER_X - textW/2 - 20, CENTER_Y - 20, textW + 40, 40, 6)
    gfx.drawTextAligned(countText, CENTER_X, CENTER_Y - 10, kTextAlignment.center)

    -- "Use the crank!" hint
    local subFont = gfx.getSystemFont()
    gfx.setFont(subFont)
    gfx.drawTextAligned("Use the crank to rotate!", CENTER_X, CENTER_Y + 30, kTextAlignment.center)

    -- Let player rotate during countdown
    local crankChange = playdate.getCrankChange()
    player:updateAngle(crankChange)

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

    -- Progressive difficulty: speed increases over time
    gameSpeed = 1.0 + (distance / 500) * 0.5
    if gameSpeed > 4.0 then
        gameSpeed = 4.0
    end

    -- Get crank input
    local crankChange = playdate.getCrankChange()

    -- Update player
    player:update(crankChange, gameSpeed)

    -- Update world (scrolling background/track)
    world:update(gameSpeed)

    -- Update obstacles
    obstacleManager:update(gameSpeed, distance)

    -- Check collisions
    local collision, collisionType = obstacleManager:checkCollision(player)
    if collision then
        if collisionType == "star" then
            -- Collect star for bonus points
            score = score + 50
        else
            -- Hit obstacle - game over!
            triggerShake(6, 15)
            gameState = STATE_GAMEOVER
            if score > highScore then
                highScore = score
            end
            return
        end
    end

    -- Check if player is on a platform (must be on a valid platform position)
    if not player.isJumping and not obstacleManager:isOnPlatform(player) then
        -- Falling! Grace period based on speed
        player.fallTimer = player.fallTimer + 1
        if player.fallTimer > 10 then
            triggerShake(6, 15)
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
    score = math.floor(distance / 3)

    -- ---- DRAW EVERYTHING ----
    gfx.clear(gfx.kColorWhite)
    updateShake()

    -- Draw world background
    world:draw(CENTER_X, CENTER_Y, gameSpeed)

    -- Draw orbital track
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, player.orbitRadius)

    -- Draw platforms and obstacles
    obstacleManager:draw(CENTER_X, CENTER_Y, player.orbitRadius)

    -- Draw center hub
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, 4)

    -- Draw spokes from center
    for i = 0, 7 do
        local angle = math.rad(i * 45 + frameCount * 2)
        local x1 = CENTER_X + 10 * math.cos(angle)
        local y1 = CENTER_Y + 10 * math.sin(angle)
        local x2 = CENTER_X + 14 * math.cos(angle)
        local y2 = CENTER_Y + 14 * math.sin(angle)
        gfx.setLineWidth(1)
        gfx.drawLine(x1, y1, x2, y2)
    end

    -- Draw player
    player:draw()

    -- Draw HUD
    hudDisplay:draw(score, highScore, gameSpeed, distance)

    -- Reset draw offset after shake
    if shakeDuration <= 0 then
        gfx.setDrawOffset(0, 0)
    end
end

-- ============================================================
-- GAME STATE: GAME OVER
-- ============================================================

local gameOverTimer = 0
local gameOverFlash = 0

local function updateGameOver()
    frameCount = frameCount + 1
    gameOverTimer = gameOverTimer + 1

    -- Keep drawing the frozen game world
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
    gfx.fillRoundRect(60, 40, 280, 160, 10)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawRoundRect(60, 40, 280, 160, 10)

    -- Title
    local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
    gfx.setFont(boldFont)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.drawTextAligned("GAME OVER", CENTER_X, 55, kTextAlignment.center)

    -- Divider line
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)
    gfx.drawLine(80, 78, 320, 78)

    -- Score display
    local font = gfx.getSystemFont()
    gfx.setFont(font)
    gfx.drawTextAligned("Score: " .. score, CENTER_X, 90, kTextAlignment.center)
    gfx.drawTextAligned("Best:  " .. highScore, CENTER_X, 110, kTextAlignment.center)

    -- Distance
    local distStr = string.format("Distance: %.0fm", distance / 10)
    gfx.drawTextAligned(distStr, CENTER_X, 130, kTextAlignment.center)

    -- New high score indicator
    if score >= highScore and score > 0 then
        if frameCount % 20 < 14 then
            gfx.setFont(boldFont)
            gfx.drawTextAligned("NEW BEST!", CENTER_X, 150, kTextAlignment.center)
        end
    end

    -- Restart prompt
    if gameOverTimer > 45 then
        if frameCount % 30 < 22 then
            gfx.setFont(font)
            gfx.drawTextAligned("Press A to Retry", CENTER_X, 175, kTextAlignment.center)
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

    -- Always update timers
    playdate.timer.updateTimers()
end

-- ============================================================
-- CRANK INDICATOR
-- ============================================================

function playdate.crankUndocked()
    -- Crank is out, good to go
end

function playdate.crankDocked()
    -- Show message if crank is stowed during gameplay
    if gameState == STATE_PLAYING then
        -- Pause or warn
    end
end
