-- Player module for Torchy's World
-- Matchstick on fire riding a skateboard, orbiting the center
-- Shoot fireballs (B), Jump (A), Slow-motion (D-pad)

local gfx <const> = playdate.graphics

class('Player').extends()

-- Constants
local ORBIT_RADIUS = 85
local JUMP_VELOCITY = -8
local GRAVITY = 0.5
local CRANK_SENSITIVITY = 1.0
local TRAIL_LENGTH = 8
local MAX_AMMO = 20
local START_AMMO = 10
local PROJECTILE_SPEED = 4
local SLOWMO_AMMO_COST_RATE = 10  -- Drain 1 ammo every N frames in slow-mo

function Player:init(centerX, centerY)
    Player.super.init(self)

    self.centerX = centerX
    self.centerY = centerY
    self.angle = 270
    self.prevAngle = 270
    self.orbitRadius = ORBIT_RADIUS

    self.x = 0
    self.y = 0

    -- Jump
    self.isJumping = false
    self.jumpVelocity = 0
    self.jumpOffset = 0

    -- Fall detection
    self.fallTimer = 0

    -- Visual
    self.size = 14
    self.trail = {}
    self.sparks = {}
    self.flameFrame = 0

    -- Shooting
    self.ammo = START_AMMO
    self.maxAmmo = MAX_AMMO
    self.projectiles = {}
    self.shootCooldown = 0

    -- Bubble shield
    self.hasShield = false
    self.shieldTimer = 0

    -- Slow-motion (D-pad)
    self.slowMotionActive = false
    self.slowMotionDrainTimer = 0

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
    self.prevAngle = self.angle
    self:updateAngle(crankChange)

    -- Jump
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

    if playdate.buttonJustPressed(playdate.kButtonA) and not self.isJumping then
        self.isJumping = true
        self.jumpVelocity = JUMP_VELOCITY
        self:createSparks(3)
    end

    -- Shoot (B button)
    if self.shootCooldown > 0 then
        self.shootCooldown = self.shootCooldown - 1
    end

    if playdate.buttonJustPressed(playdate.kButtonB) and self.ammo > 0 and self.shootCooldown <= 0 then
        self:shoot()
    end

    -- Slow-motion (any D-pad direction held)
    local dpadHeld = playdate.buttonIsPressed(playdate.kButtonUp)
        or playdate.buttonIsPressed(playdate.kButtonDown)
        or playdate.buttonIsPressed(playdate.kButtonLeft)
        or playdate.buttonIsPressed(playdate.kButtonRight)

    if dpadHeld and self.ammo > 0 then
        self.slowMotionActive = true
        self.slowMotionDrainTimer = self.slowMotionDrainTimer + 1
        if self.slowMotionDrainTimer >= SLOWMO_AMMO_COST_RATE then
            self.slowMotionDrainTimer = 0
            self.ammo = self.ammo - 1
        end
    else
        self.slowMotionActive = false
        self.slowMotionDrainTimer = 0
    end

    self:updatePosition()

    -- Trail
    table.insert(self.trail, 1, {x = self.x, y = self.y})
    if #self.trail > TRAIL_LENGTH then
        table.remove(self.trail)
    end

    self.flameFrame = self.flameFrame + 1

    if self.hasShield then
        self.shieldTimer = self.shieldTimer + 1
    end

    self:updateSparks()
    self:updateProjectiles()
end

function Player:shoot()
    self.ammo = self.ammo - 1
    self.shootCooldown = 8

    table.insert(self.projectiles, {
        angle = self.angle,
        radius = self.orbitRadius + self.jumpOffset,
        speed = PROJECTILE_SPEED,
        life = 60,
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

        local rad = math.rad(p.angle)
        local px = self.centerX + p.radius * math.cos(rad)
        local py = self.centerY + p.radius * math.sin(rad)
        table.insert(p.trail, 1, {x = px, y = py})
        if #p.trail > 4 then
            table.remove(p.trail)
        end

        if p.life <= 0 or p.radius <= 20 then
            table.remove(self.projectiles, i)
        end
    end
end

function Player:addAmmo(amount)
    self.ammo = math.min(self.maxAmmo, self.ammo + amount)
end

function Player:activateShield()
    self.hasShield = true
    self.shieldTimer = 0
end

function Player:useShield()
    if self.hasShield then
        self.hasShield = false
        self.shieldTimer = 0
        return true
    end
    return false
end

function Player:getPrevAngle()
    return self.prevAngle
end

function Player:createSparks(count)
    for i = 1, count do
        table.insert(self.sparks, {
            x = self.x, y = self.y,
            vx = (math.random() - 0.5) * 4,
            vy = (math.random() - 0.5) * 4,
            life = math.random(5, 12)
        })
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
    -- Trail
    gfx.setColor(gfx.kColorBlack)
    for i, pos in ipairs(self.trail) do
        local alpha = 1.0 - (i / TRAIL_LENGTH)
        local trailSize = math.max(1, math.floor(self.size * alpha * 0.4))
        gfx.setDitherPattern(1.0 - alpha * 0.6, gfx.image.kDitherTypeBayer4x4)
        gfx.fillCircleAtPoint(pos.x, pos.y, trailSize)
    end

    -- Sparks
    gfx.setColor(gfx.kColorBlack)
    for _, s in ipairs(self.sparks) do
        local sz = math.max(1, math.floor(s.life / 3))
        gfx.fillRect(s.x - sz/2, s.y - sz/2, sz, sz)
    end

    -- Projectiles
    for _, p in ipairs(self.projectiles) do
        self:drawProjectile(p)
    end

    -- Matchstick character
    self:drawMatchstick()

    -- Shield
    if self.hasShield then
        local shimmer = math.sin(self.shieldTimer * 0.15) * 2
        local sr = 22 + shimmer
        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(2)
        gfx.drawCircleAtPoint(self.x, self.y, sr)
        gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
        gfx.drawCircleAtPoint(self.x, self.y, sr - 3)
        local hlA = self.shieldTimer * 0.1
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(self.x + (sr-4)*math.cos(hlA), self.y + (sr-4)*math.sin(hlA), 2)
        gfx.setLineWidth(1)
    end

    -- Fall warning
    if self.fallTimer > 0 and not self.isJumping then
        gfx.setColor(gfx.kColorBlack)
        if math.floor(self.fallTimer) % 2 == 0 then
            gfx.drawCircleAtPoint(self.x, self.y, 4 + self.fallTimer + 10)
        end
    end
end

function Player:drawProjectile(p)
    local rad = math.rad(p.angle)
    local px = self.centerX + p.radius * math.cos(rad)
    local py = self.centerY + p.radius * math.sin(rad)

    for i, t in ipairs(p.trail) do
        local alpha = 1.0 - (i / 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1.0 - alpha * 0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.fillCircleAtPoint(t.x, t.y, math.max(1, math.floor(p.size * alpha)))
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(px, py, p.size)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(px, py, p.size - 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(px, py, 1)
end

function Player:drawMatchstick()
    local rad = math.rad(self.angle)
    local outX = math.cos(rad)
    local outY = math.sin(rad)
    local perpX = -math.sin(rad)
    local perpY = math.cos(rad)

    -- Skateboard
    local bLen = 12
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(self.x + perpX*bLen, self.y + perpY*bLen, self.x - perpX*bLen, self.y - perpY*bLen)

    gfx.setLineWidth(2)
    local bx1, by1 = self.x + perpX*bLen, self.y + perpY*bLen
    local bx2, by2 = self.x - perpX*bLen, self.y - perpY*bLen
    gfx.drawLine(bx1, by1, bx1 + outX*3, by1 + outY*3)
    gfx.drawLine(bx2, by2, bx2 + outX*3, by2 + outY*3)

    -- Wheels
    for _, sign in ipairs({-1, 1}) do
        local wx = self.x + perpX*(bLen-3)*sign + outX*2
        local wy = self.y + perpY*(bLen-3)*sign + outY*2
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(wx, wy, 2.5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(wx, wy, 1)
    end

    -- Stick body
    local ssx, ssy = self.x + outX*2, self.y + outY*2
    local sex, sey = self.x + outX*16, self.y + outY*16
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)
    gfx.drawLine(ssx, ssy, sex, sey)

    -- Match head
    local hx, hy = sex + outX*2, sey + outY*2
    gfx.fillCircleAtPoint(hx, hy, 4)

    -- Flame
    local fx, fy = hx + outX*4, hy + outY*4
    local f1 = math.sin(self.flameFrame * 0.4) * 2
    local f2 = math.cos(self.flameFrame * 0.3) * 1.5
    local fSize = 7 + f1

    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(fx + perpX*f2, fy + perpY*f2, fSize)
    gfx.fillCircleAtPoint(fx + outX*(5+f1), fy + outY*(5+f1), 4)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(fx + perpX*(f2*0.5), fy + perpY*(f2*0.5), fSize - 3)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(fx, fy, 2)

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
