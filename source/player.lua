-- Player module for Torchy's World
-- Handles the skateboard character that orbits around the center

local gfx <const> = playdate.graphics

class('Player').extends()

-- Constants
local ORBIT_RADIUS = 85        -- Distance from center of screen
local JUMP_VELOCITY = -8       -- Initial jump velocity
local GRAVITY = 0.5            -- Gravity pulling player back
local MAX_JUMP_HEIGHT = 30     -- Maximum jump offset
local CRANK_SENSITIVITY = 1.0  -- How responsive the crank is
local TRAIL_LENGTH = 8         -- Number of trail dots

function Player:init(centerX, centerY)
    Player.super.init(self)

    self.centerX = centerX
    self.centerY = centerY
    self.angle = 270              -- Start at bottom (270 degrees)
    self.orbitRadius = ORBIT_RADIUS

    -- Position on the orbit
    self.x = 0
    self.y = 0

    -- Jump mechanics
    self.isJumping = false
    self.jumpVelocity = 0
    self.jumpOffset = 0           -- Offset from orbit radius (negative = outward)

    -- Fall detection
    self.fallTimer = 0

    -- Visual
    self.size = 14
    self.skateboardWidth = 20
    self.trail = {}               -- Trail positions for visual effect
    self.sparkTimer = 0
    self.sparks = {}

    -- Load images
    self.playerImg = gfx.image.new("images/player")
    self.jumpImg = gfx.image.new("images/player-jump")

    self:updatePosition()
end

function Player:updateAngle(crankChange)
    -- Update angle based on crank
    if crankChange ~= 0 then
        self.angle = (self.angle + crankChange * CRANK_SENSITIVITY) % 360
    end
    self:updatePosition()
end

function Player:updatePosition()
    local rad = math.rad(self.angle)
    local effectiveRadius = self.orbitRadius + self.jumpOffset
    self.x = self.centerX + effectiveRadius * math.cos(rad)
    self.y = self.centerY + effectiveRadius * math.sin(rad)
end

function Player:update(crankChange, gameSpeed)
    -- Update rotation from crank
    self:updateAngle(crankChange)

    -- Handle jumping
    if self.isJumping then
        self.jumpVelocity = self.jumpVelocity + GRAVITY
        self.jumpOffset = self.jumpOffset + self.jumpVelocity

        -- Land back on orbit
        if self.jumpOffset >= 0 then
            self.jumpOffset = 0
            self.jumpVelocity = 0
            self.isJumping = false

            -- Landing sparks
            self:createSparks(4)
        end
    end

    -- Jump input
    if playdate.buttonJustPressed(playdate.kButtonA) and not self.isJumping then
        self.isJumping = true
        self.jumpVelocity = JUMP_VELOCITY
        self:createSparks(3)
    end

    -- Update position
    self:updatePosition()

    -- Trail effect
    table.insert(self.trail, 1, {x = self.x, y = self.y})
    if #self.trail > TRAIL_LENGTH then
        table.remove(self.trail)
    end

    -- Update sparks
    self:updateSparks()
end

function Player:createSparks(count)
    for i = 1, count do
        local spark = {
            x = self.x,
            y = self.y,
            vx = (math.random() - 0.5) * 4,
            vy = (math.random() - 0.5) * 4,
            life = math.random(5, 12)
        }
        table.insert(self.sparks, spark)
    end
end

function Player:updateSparks()
    for i = #self.sparks, 1, -1 do
        local s = self.sparks[i]
        s.x = s.x + s.vx
        s.y = s.y + s.vy
        s.life = s.life - 1
        if s.life <= 0 then
            table.remove(self.sparks, i)
        end
    end
end

function Player:draw()
    -- Draw trail
    gfx.setColor(gfx.kColorBlack)
    for i, pos in ipairs(self.trail) do
        local alpha = 1.0 - (i / TRAIL_LENGTH)
        local trailSize = math.max(1, math.floor(self.size * alpha * 0.4))
        gfx.setDitherPattern(1.0 - alpha * 0.6, gfx.image.kDitherTypeBayer4x4)
        gfx.fillCircleAtPoint(pos.x, pos.y, trailSize)
    end

    -- Draw sparks
    gfx.setColor(gfx.kColorBlack)
    for _, s in ipairs(self.sparks) do
        local sparkSize = math.max(1, math.floor(s.life / 3))
        gfx.fillRect(s.x - sparkSize/2, s.y - sparkSize/2, sparkSize, sparkSize)
    end

    -- Draw player character
    local img = self.isJumping and self.jumpImg or self.playerImg
    if img then
        -- Rotate image based on angle on orbit
        local drawAngle = self.angle + 90 -- Adjust so feet face center
        local rotated = img:rotatedImage(drawAngle)
        rotated:draw(self.x - rotated.width/2, self.y - rotated.height/2)
    else
        -- Fallback: draw manually
        self:drawFallback()
    end

    -- Draw "falling" warning indicator
    if self.fallTimer > 0 and not self.isJumping then
        gfx.setColor(gfx.kColorBlack)
        local warningSize = 4 + self.fallTimer
        if math.floor(self.fallTimer) % 2 == 0 then
            gfx.drawCircleAtPoint(self.x, self.y, warningSize + 10)
        end
    end
end

function Player:drawFallback()
    local rad = math.rad(self.angle)

    -- Body circle
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(self.x, self.y, self.size / 2)

    -- White inner
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(self.x, self.y, self.size / 2 - 3)

    -- Skateboard line perpendicular to radius
    local perpAngle = rad + math.pi / 2
    local bx1 = self.x + (self.skateboardWidth/2) * math.cos(perpAngle)
    local by1 = self.y + (self.skateboardWidth/2) * math.sin(perpAngle)
    local bx2 = self.x - (self.skateboardWidth/2) * math.cos(perpAngle)
    local by2 = self.y - (self.skateboardWidth/2) * math.sin(perpAngle)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(bx1, by1, bx2, by2)

    -- Wheels
    gfx.fillCircleAtPoint(bx1, by1, 3)
    gfx.fillCircleAtPoint(bx2, by2, 3)
    gfx.setLineWidth(1)

    -- Eye dot to show facing direction
    local eyeX = self.x + 3 * math.cos(rad)
    local eyeY = self.y + 3 * math.sin(rad)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(eyeX, eyeY, 2)
end

function Player:getAngle()
    return self.angle
end

function Player:getPosition()
    return self.x, self.y
end

function Player:getOrbitAngle()
    return self.angle
end
