-- Player module for Torchy's World
-- Matchstick on fire riding a skateboard, orbiting the center
-- Smash Hit style: player can shoot fireballs to break obstacles

local gfx <const> = playdate.graphics

class('Player').extends()

-- Constants
local ORBIT_RADIUS = 85        -- Distance from center of screen
local JUMP_VELOCITY = -8       -- Initial jump velocity
local GRAVITY = 0.5            -- Gravity pulling player back
local CRANK_SENSITIVITY = 1.0  -- How responsive the crank is
local TRAIL_LENGTH = 8         -- Number of trail dots
local MAX_AMMO = 20            -- Maximum fireballs
local START_AMMO = 10          -- Starting fireballs
local PROJECTILE_SPEED = 4    -- How fast fireballs travel inward

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
    self.jumpOffset = 0

    -- Fall detection
    self.fallTimer = 0

    -- Visual
    self.size = 14
    self.trail = {}
    self.sparks = {}

    -- Flame animation
    self.flameFrame = 0

    -- Shooting (Smash Hit style)
    self.ammo = START_AMMO
    self.maxAmmo = MAX_AMMO
    self.projectiles = {}
    self.shootCooldown = 0

    self:updatePosition()
end

function Player:updateAngle(crankChange)
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
    self:updateAngle(crankChange)

    -- Handle jumping
    if self.isJumping then
        self.jumpVelocity = self.jumpVelocity + GRAVITY
        self.jumpOffset = self.jumpOffset + self.jumpVelocity

        if self.jumpOffset >= 0 then
            self.jumpOffset = 0
            self.jumpVelocity = 0
            self.isJumping = false
            self:createSparks(4)
        end
    end

    -- Jump input (A button)
    if playdate.buttonJustPressed(playdate.kButtonA) and not self.isJumping then
        self.isJumping = true
        self.jumpVelocity = JUMP_VELOCITY
        self:createSparks(3)
    end

    -- Shoot input (B button) - Smash Hit style
    if self.shootCooldown > 0 then
        self.shootCooldown = self.shootCooldown - 1
    end

    if playdate.buttonJustPressed(playdate.kButtonB) and self.ammo > 0 and self.shootCooldown <= 0 then
        self:shoot()
    end

    self:updatePosition()

    -- Trail effect
    table.insert(self.trail, 1, {x = self.x, y = self.y})
    if #self.trail > TRAIL_LENGTH then
        table.remove(self.trail)
    end

    -- Flame animation
    self.flameFrame = self.flameFrame + 1

    -- Update sparks
    self:updateSparks()

    -- Update projectiles
    self:updateProjectiles()
end

function Player:shoot()
    self.ammo = self.ammo - 1
    self.shootCooldown = 8

    -- Fire a projectile inward from player position toward center
    local rad = math.rad(self.angle)
    local startRadius = self.orbitRadius + self.jumpOffset
    table.insert(self.projectiles, {
        angle = self.angle,
        radius = startRadius,
        speed = PROJECTILE_SPEED,
        life = 60, -- frames before expiry
        size = 4,
        trail = {}
    })
    self:createSparks(2)
end

function Player:updateProjectiles()
    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]
        p.radius = p.radius - p.speed
        p.life = p.life - 1

        -- Store trail positions
        local rad = math.rad(p.angle)
        local px = self.centerX + p.radius * math.cos(rad)
        local py = self.centerY + p.radius * math.sin(rad)
        table.insert(p.trail, 1, {x = px, y = py})
        if #p.trail > 4 then
            table.remove(p.trail)
        end

        -- Remove if expired or reached center
        if p.life <= 0 or p.radius <= 15 then
            table.remove(self.projectiles, i)
        end
    end
end

function Player:addAmmo(amount)
    self.ammo = math.min(self.maxAmmo, self.ammo + amount)
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

    -- Draw projectiles (fireballs heading toward center)
    for _, p in ipairs(self.projectiles) do
        self:drawProjectile(p)
    end

    -- Draw the matchstick character
    self:drawMatchstick()

    -- Draw "falling" warning indicator
    if self.fallTimer > 0 and not self.isJumping then
        gfx.setColor(gfx.kColorBlack)
        local warningSize = 4 + self.fallTimer
        if math.floor(self.fallTimer) % 2 == 0 then
            gfx.drawCircleAtPoint(self.x, self.y, warningSize + 10)
        end
    end
end

function Player:drawProjectile(p)
    local rad = math.rad(p.angle)
    local px = self.centerX + p.radius * math.cos(rad)
    local py = self.centerY + p.radius * math.sin(rad)

    -- Fireball trail
    for i, t in ipairs(p.trail) do
        local alpha = 1.0 - (i / 4)
        local s = math.max(1, math.floor(p.size * alpha))
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1.0 - alpha * 0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.fillCircleAtPoint(t.x, t.y, s)
    end

    -- Fireball core
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(px, py, p.size)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(px, py, p.size - 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(px, py, 1)
end

function Player:drawMatchstick()
    local rad = math.rad(self.angle)

    -- Direction vectors
    -- "outward" = away from center (where flame is)
    local outX = math.cos(rad)
    local outY = math.sin(rad)
    -- "perpendicular" = along the orbit (skateboard direction)
    local perpX = -math.sin(rad)
    local perpY = math.cos(rad)

    -- The player position is on the orbit. Skateboard is at the orbit,
    -- matchstick body extends outward, flame on top (outer end)

    -- === SKATEBOARD ===
    local boardLen = 12
    local bx1 = self.x + perpX * boardLen
    local by1 = self.y + perpY * boardLen
    local bx2 = self.x - perpX * boardLen
    local by2 = self.y - perpY * boardLen

    -- Board deck
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(bx1, by1, bx2, by2)

    -- Curved kicktails
    local tailLen = 3
    gfx.setLineWidth(2)
    gfx.drawLine(bx1, by1, bx1 + outX * tailLen, by1 + outY * tailLen)
    gfx.drawLine(bx2, by2, bx2 + outX * tailLen, by2 + outY * tailLen)

    -- Wheels (4 small circles, 2 on each side)
    local wheelInset = 3
    local wheelOffset = -2 -- slightly toward center from board
    for _, sign in ipairs({-1, 1}) do
        local wxBase = self.x + perpX * (boardLen - wheelInset) * sign
        local wyBase = self.y + perpY * (boardLen - wheelInset) * sign
        -- Offset toward center
        local wx = wxBase - outX * wheelOffset
        local wy = wyBase - outY * wheelOffset
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(wx, wy, 2.5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(wx, wy, 1)
    end

    -- === MATCHSTICK BODY (thin stick extending outward from skateboard) ===
    local stickBase = 2    -- start slightly above board
    local stickLen = 14    -- length of the stick
    local stickStartX = self.x + outX * stickBase
    local stickStartY = self.y + outY * stickBase
    local stickEndX = self.x + outX * (stickBase + stickLen)
    local stickEndY = self.y + outY * (stickBase + stickLen)

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(stickStartX, stickStartY, stickEndX, stickEndY)

    -- Match head (rounded bulb at the top of the stick)
    local headX = stickEndX + outX * 2
    local headY = stickEndY + outY * 2
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(headX, headY, 4)

    -- === FLAME (animated, on top of the match head) ===
    local flameBaseX = headX + outX * 4
    local flameBaseY = headY + outY * 4

    -- Flame flickers using sin wave
    local flicker1 = math.sin(self.flameFrame * 0.4) * 2
    local flicker2 = math.cos(self.flameFrame * 0.3) * 1.5

    -- Outer flame (larger, black)
    local flameOuterSize = 7 + flicker1
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(
        flameBaseX + perpX * flicker2,
        flameBaseY + perpY * flicker2,
        flameOuterSize
    )

    -- Tip of flame (extends further outward)
    local flameTipX = flameBaseX + outX * (5 + flicker1)
    local flameTipY = flameBaseY + outY * (5 + flicker1)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(flameTipX, flameTipY, 4)

    -- Inner flame (white, gives the flame definition on 1-bit display)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(
        flameBaseX + perpX * (flicker2 * 0.5),
        flameBaseY + perpY * (flicker2 * 0.5),
        flameOuterSize - 3
    )

    -- Flame core (small black dot in center of white for depth)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(flameBaseX, flameBaseY, 2)

    -- Small spark particles flying off the flame
    if self.flameFrame % 4 == 0 then
        self:createSparks(1)
    end

    gfx.setLineWidth(1)
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
