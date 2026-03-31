-- World module for Cronobreak
-- Radial particles, tunnel effect, progressive background zones

local gfx <const> = playdate.graphics

class('World').extends()

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240

-- Zone thresholds (in distance units, /10 for meters)
local ZONE_2 = 5000   -- 500m
local ZONE_3 = 10000  -- 1000m
local ZONE_4 = 15000  -- 1500m
local ZONE_5 = 20000  -- 2000m

function World:init()
    World.super.init(self)

    self.particles = {}
    for i = 1, 50 do
        self:spawnParticle(true)
    end

    self.ringPulse = 0
    self.ringPulseDir = 1
    self.trackRotation = 0
    self.speedLines = {}
    self.tunnelRings = {}
    self.tunnelTimer = 0

    -- Zone tracking
    self.currentZone = 1
    self.zoneTransitionTimer = 0
    self.zoneNameTimer = 0
    self.zoneName = ""
end

function World:getZone(distance)
    if distance >= ZONE_5 then return 5
    elseif distance >= ZONE_4 then return 4
    elseif distance >= ZONE_3 then return 3
    elseif distance >= ZONE_2 then return 2
    else return 1 end
end

function World:spawnParticle(randomize)
    local angle = math.random() * 360
    local r = randomize and math.random(5, 160) or math.random(2, 10)
    table.insert(self.particles, {
        angle = angle, radius = r,
        speed = 0.5 + math.random() * 1.5,
        size = math.random(1, 3),
        maxRadius = 180 + math.random(0, 40)
    })
end

function World:update(gameSpeed, distance)
    distance = distance or 0

    -- Zone detection
    local newZone = self:getZone(distance)
    if newZone ~= self.currentZone then
        self.currentZone = newZone
        self.zoneTransitionTimer = 30  -- Flash effect
        self.zoneNameTimer = 90        -- Show zone name
        local zoneNames = {"THE OUTSKIRTS", "MINION TERRITORY", "CLOCKWORK DEPTHS", "TIME STORM", "THE VOID"}
        self.zoneName = zoneNames[newZone] or "UNKNOWN"
    end

    if self.zoneTransitionTimer > 0 then self.zoneTransitionTimer = self.zoneTransitionTimer - 1 end
    if self.zoneNameTimer > 0 then self.zoneNameTimer = self.zoneNameTimer - 1 end

    -- Particle count scales with zone
    local targetParticles = 40 + self.currentZone * 10

    -- Update particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.radius = p.radius + p.speed * gameSpeed
        if p.radius > p.maxRadius then
            table.remove(self.particles, i)
            self:spawnParticle(false)
        end
    end
    while #self.particles < targetParticles do self:spawnParticle(false) end

    -- Ring pulse (faster in higher zones)
    local pulseSpeed = 0.3 + self.currentZone * 0.1
    self.ringPulse = self.ringPulse + self.ringPulseDir * pulseSpeed
    if self.ringPulse > 5 or self.ringPulse < -2 then self.ringPulseDir = -self.ringPulseDir end

    self.trackRotation = (self.trackRotation + gameSpeed * 1.5) % 360

    -- Speed lines (more frequent in higher zones)
    if gameSpeed > 1.2 then
        local lineChance = math.min(0.6, (gameSpeed - 1.2) * 0.2 + self.currentZone * 0.05)
        if math.random() < lineChance then
            table.insert(self.speedLines, {
                angle = math.random() * 360,
                radius = 15 + math.random() * 25,
                length = 15 + math.random() * 30,
                speed = gameSpeed * (4 + math.random() * 4)
            })
        end
    end

    for i = #self.speedLines, 1, -1 do
        self.speedLines[i].radius = self.speedLines[i].radius + self.speedLines[i].speed
        if self.speedLines[i].radius > 200 then table.remove(self.speedLines, i) end
    end

    -- Tunnel rings (spawn rate varies by zone)
    local tunnelRate = math.max(5, 15 - self.currentZone * 2)
    self.tunnelTimer = self.tunnelTimer + gameSpeed
    if self.tunnelTimer > tunnelRate then
        self.tunnelTimer = 0
        table.insert(self.tunnelRings, {
            radius = 5,
            speed = 1.5 + gameSpeed * 0.5,
            opacity = 0.8
        })
        -- Zone 4+: double rings
        if self.currentZone >= 4 then
            table.insert(self.tunnelRings, {
                radius = 8, speed = 1.2 + gameSpeed * 0.4, opacity = 0.5
            })
        end
    end

    for i = #self.tunnelRings, 1, -1 do
        local ring = self.tunnelRings[i]
        ring.radius = ring.radius + ring.speed
        ring.opacity = ring.opacity - 0.008
        if ring.opacity <= 0 or ring.radius > 200 then table.remove(self.tunnelRings, i) end
    end
end

function World:draw(centerX, centerY, gameSpeed)
    local zone = self.currentZone

    -- Zone transition flash
    if self.zoneTransitionTimer > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(self.zoneTransitionTimer / 30 * 0.4, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, SCREEN_W, SCREEN_H)
    end

    -- Tunnel rings
    for _, ring in ipairs(self.tunnelRings) do
        if ring.opacity > 0.1 then
            gfx.setColor(gfx.kColorBlack)
            local ditherBase = zone >= 3 and 0.4 or 0.3
            gfx.setDitherPattern(1.0 - ring.opacity * ditherBase, gfx.image.kDitherTypeBayer8x8)
            gfx.setLineWidth(1)
            gfx.drawCircleAtPoint(centerX, centerY, ring.radius)
        end
    end

    -- Radial particles
    gfx.setColor(gfx.kColorBlack)
    for _, p in ipairs(self.particles) do
        local rad = math.rad(p.angle)
        local px = centerX + p.radius * math.cos(rad)
        local py = centerY + p.radius * math.sin(rad)

        if px > -5 and px < SCREEN_W + 5 and py > -5 and py < SCREEN_H + 5 then
            local drawSize = math.max(1, math.floor(p.size * (0.5 + p.radius / 200)))
            -- Zone 5: particles are larger
            if zone >= 5 then drawSize = drawSize + 1 end

            local dither = math.max(0.2, 1.0 - (p.radius / p.maxRadius))
            gfx.setDitherPattern(1.0 - dither, gfx.image.kDitherTypeBayer4x4)

            if drawSize <= 1 then
                gfx.drawPixel(px, py)
            else
                gfx.fillCircleAtPoint(px, py, drawSize)
            end
        end
    end

    -- Speed lines
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for _, line in ipairs(self.speedLines) do
        local rad = math.rad(line.angle)
        local r1, r2 = line.radius, line.radius + line.length
        gfx.drawLine(centerX + r1*math.cos(rad), centerY + r1*math.sin(rad),
                      centerX + r2*math.cos(rad), centerY + r2*math.sin(rad))
    end

    -- Orbit ring decorations
    local orbitR = 85
    local numTicks = 24
    for i = 0, numTicks - 1 do
        local ta = math.rad(i * (360/numTicks) + self.trackRotation)
        local iR = (i % 3 == 0) and (orbitR - 6) or (orbitR - 4)
        local oR = (i % 3 == 0) and (orbitR + 6) or (orbitR + 4)
        gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(1)
        gfx.drawLine(centerX + iR*math.cos(ta), centerY + iR*math.sin(ta),
                      centerX + oR*math.cos(ta), centerY + oR*math.sin(ta))
    end

    -- Pulsing outer ring
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer4x4)
    gfx.drawCircleAtPoint(centerX, centerY, orbitR + 20 + self.ringPulse)

    -- Inner ring (zone 3+: double inner ring)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    gfx.drawCircleAtPoint(centerX, centerY, orbitR - 15)
    if zone >= 3 then
        gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer4x4)
        gfx.drawCircleAtPoint(centerX, centerY, orbitR - 25)
    end

    -- Zone name display
    if self.zoneNameTimer > 0 then
        local alpha = math.min(1.0, self.zoneNameTimer / 30)
        if alpha > 0.2 then
            local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
            gfx.setFont(boldFont)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

            local tw = boldFont:getTextWidth(self.zoneName)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(centerX - tw/2 - 12, 42, tw + 24, 22, 4)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(centerX - tw/2 - 12, 42, tw + 24, 22, 4)
            gfx.drawTextAligned(self.zoneName, centerX, 45, kTextAlignment.center)
        end
    end
end
