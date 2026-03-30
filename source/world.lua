-- World module for Torchy's World
-- Handles the scrolling background with radial particles coming AT the player
-- Creates a Smash Hit-style forward motion feel

local gfx <const> = playdate.graphics

class('World').extends()

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240

function World:init()
    World.super.init(self)

    -- Radial particles that fly outward from center (coming at the player)
    self.particles = {}
    for i = 1, 50 do
        self:spawnParticle(true) -- randomize initial positions
    end

    -- Ring pulse effect
    self.ringPulse = 0
    self.ringPulseDir = 1

    -- Track rotation visual
    self.trackRotation = 0

    -- Radial speed lines (appear at higher speeds)
    self.speedLines = {}

    -- Tunnel ring effects (depth rings expanding outward)
    self.tunnelRings = {}
    self.tunnelTimer = 0
end

function World:spawnParticle(randomizeRadius)
    local angle = math.random() * 360
    local startRadius
    if randomizeRadius then
        startRadius = math.random(5, 160)
    else
        startRadius = math.random(2, 10) -- spawn near center
    end

    table.insert(self.particles, {
        angle = angle,
        radius = startRadius,
        speed = 0.5 + math.random() * 1.5,
        size = math.random(1, 3),
        maxRadius = 180 + math.random(0, 40) -- despawn radius
    })
end

function World:update(gameSpeed)
    local centerX = SCREEN_W / 2
    local centerY = SCREEN_H / 2

    -- Update radial particles (move outward from center = "coming at" the player)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.radius = p.radius + p.speed * gameSpeed

        -- Remove if past screen edge and respawn near center
        if p.radius > p.maxRadius then
            table.remove(self.particles, i)
            self:spawnParticle(false)
        end
    end

    -- Ensure enough particles
    while #self.particles < 50 do
        self:spawnParticle(false)
    end

    -- Ring pulse animation
    self.ringPulse = self.ringPulse + self.ringPulseDir * 0.3
    if self.ringPulse > 5 or self.ringPulse < -2 then
        self.ringPulseDir = -self.ringPulseDir
    end

    -- Track visual rotation
    self.trackRotation = (self.trackRotation + gameSpeed * 1.5) % 360

    -- Generate radial speed lines at higher speeds
    if gameSpeed > 1.5 then
        local lineChance = math.min(0.5, (gameSpeed - 1.5) * 0.25)
        if math.random() < lineChance then
            local angle = math.random() * 360
            table.insert(self.speedLines, {
                angle = angle,
                radius = 20 + math.random() * 30,
                length = 15 + math.random() * 30,
                speed = gameSpeed * (4 + math.random() * 4)
            })
        end
    end

    -- Update speed lines (radial, moving outward)
    for i = #self.speedLines, 1, -1 do
        local line = self.speedLines[i]
        line.radius = line.radius + line.speed
        if line.radius > 200 then
            table.remove(self.speedLines, i)
        end
    end

    -- Tunnel ring effect (concentric rings expanding outward)
    self.tunnelTimer = self.tunnelTimer + gameSpeed
    if self.tunnelTimer > 15 then
        self.tunnelTimer = 0
        table.insert(self.tunnelRings, {
            radius = 5,
            speed = 1.5 + gameSpeed * 0.5,
            opacity = 0.8
        })
    end

    for i = #self.tunnelRings, 1, -1 do
        local ring = self.tunnelRings[i]
        ring.radius = ring.radius + ring.speed
        ring.opacity = ring.opacity - 0.008
        if ring.opacity <= 0 or ring.radius > 200 then
            table.remove(self.tunnelRings, i)
        end
    end
end

function World:draw(centerX, centerY, gameSpeed)
    -- Draw tunnel rings (depth effect, like flying through a tunnel)
    for _, ring in ipairs(self.tunnelRings) do
        if ring.opacity > 0.1 then
            gfx.setColor(gfx.kColorBlack)
            gfx.setDitherPattern(1.0 - ring.opacity * 0.3, gfx.image.kDitherTypeBayer8x8)
            gfx.setLineWidth(1)
            gfx.drawCircleAtPoint(centerX, centerY, ring.radius)
        end
    end

    -- Draw radial particles (dots flying outward from center)
    gfx.setColor(gfx.kColorBlack)
    for _, p in ipairs(self.particles) do
        local rad = math.rad(p.angle)
        local px = centerX + p.radius * math.cos(rad)
        local py = centerY + p.radius * math.sin(rad)

        -- Only draw if on screen
        if px > -5 and px < SCREEN_W + 5 and py > -5 and py < SCREEN_H + 5 then
            -- Particles grow slightly as they get further out (perspective)
            local drawSize = math.max(1, math.floor(p.size * (0.5 + p.radius / 200)))

            -- Farther particles are more opaque (closer to viewer)
            local ditherAmount = math.max(0.2, 1.0 - (p.radius / p.maxRadius))
            gfx.setDitherPattern(1.0 - ditherAmount, gfx.image.kDitherTypeBayer4x4)

            if drawSize <= 1 then
                gfx.drawPixel(px, py)
            else
                gfx.fillCircleAtPoint(px, py, drawSize)
            end
        end
    end

    -- Draw radial speed lines
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for _, line in ipairs(self.speedLines) do
        local rad = math.rad(line.angle)
        local r1 = line.radius
        local r2 = line.radius + line.length
        local x1 = centerX + r1 * math.cos(rad)
        local y1 = centerY + r1 * math.sin(rad)
        local x2 = centerX + r2 * math.cos(rad)
        local y2 = centerY + r2 * math.sin(rad)
        gfx.drawLine(x1, y1, x2, y2)
    end

    -- Orbit ring decorations (tick marks around the orbit)
    local orbitRadius = 85
    local numTicks = 24
    for i = 0, numTicks - 1 do
        local tickAngle = math.rad(i * (360 / numTicks) + self.trackRotation)
        local innerR = orbitRadius - 4
        local outerR = orbitRadius + 4

        if i % 3 == 0 then
            innerR = orbitRadius - 6
            outerR = orbitRadius + 6
        end

        local x1 = centerX + innerR * math.cos(tickAngle)
        local y1 = centerY + innerR * math.sin(tickAngle)
        local x2 = centerX + outerR * math.cos(tickAngle)
        local y2 = centerY + outerR * math.sin(tickAngle)

        gfx.setColor(gfx.kColorBlack)
        gfx.setLineWidth(1)
        gfx.drawLine(x1, y1, x2, y2)
    end

    -- Pulsing outer ring
    local pulseRadius = orbitRadius + 20 + self.ringPulse
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer4x4)
    gfx.setLineWidth(1)
    gfx.drawCircleAtPoint(centerX, centerY, pulseRadius)

    -- Inner decorative ring
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.drawCircleAtPoint(centerX, centerY, orbitRadius - 15)
end
