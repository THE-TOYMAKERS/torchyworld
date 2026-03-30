-- World module for Torchy's World
-- Handles the scrolling background and visual environment

local gfx <const> = playdate.graphics

class('World').extends()

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240

function World:init()
    World.super.init(self)

    -- Background stars/dots that scroll
    self.bgDots = {}
    for i = 1, 40 do
        table.insert(self.bgDots, {
            x = math.random(0, SCREEN_W),
            y = math.random(0, SCREEN_H),
            speed = math.random(1, 3) * 0.5,
            size = math.random(1, 3)
        })
    end

    -- Ring pulse effect
    self.ringPulse = 0
    self.ringPulseDir = 1

    -- Track rotation visual
    self.trackRotation = 0

    -- Background scroll offset
    self.scrollOffset = 0

    -- Speed lines
    self.speedLines = {}

    -- Ground pattern offset
    self.patternOffset = 0
end

function World:update(gameSpeed)
    -- Scroll background dots
    for _, dot in ipairs(self.bgDots) do
        dot.x = dot.x - dot.speed * gameSpeed
        if dot.x < -5 then
            dot.x = SCREEN_W + 5
            dot.y = math.random(0, SCREEN_H)
        end
    end

    -- Ring pulse animation
    self.ringPulse = self.ringPulse + self.ringPulseDir * 0.3
    if self.ringPulse > 5 or self.ringPulse < -2 then
        self.ringPulseDir = -self.ringPulseDir
    end

    -- Track visual rotation
    self.trackRotation = (self.trackRotation + gameSpeed * 1.5) % 360

    -- Scroll offset
    self.scrollOffset = (self.scrollOffset + gameSpeed * 2) % 40

    -- Pattern offset
    self.patternOffset = (self.patternOffset + gameSpeed) % 20

    -- Generate speed lines at higher speeds
    if gameSpeed > 1.5 then
        local lineChance = math.min(0.4, (gameSpeed - 1.5) * 0.2)
        if math.random() < lineChance then
            table.insert(self.speedLines, {
                x = SCREEN_W + 10,
                y = math.random(10, SCREEN_H - 10),
                length = math.random(20, 60),
                speed = gameSpeed * (3 + math.random() * 3)
            })
        end
    end

    -- Update speed lines
    for i = #self.speedLines, 1, -1 do
        local line = self.speedLines[i]
        line.x = line.x - line.speed
        if line.x + line.length < 0 then
            table.remove(self.speedLines, i)
        end
    end
end

function World:draw(centerX, centerY, gameSpeed)
    -- Background dots
    gfx.setColor(gfx.kColorBlack)
    for _, dot in ipairs(self.bgDots) do
        if dot.size <= 1 then
            gfx.drawPixel(dot.x, dot.y)
        else
            gfx.fillCircleAtPoint(dot.x, dot.y, dot.size)
        end
    end

    -- Corner decorations with scrolling pattern
    self:drawCornerPattern(0, 0, gameSpeed)
    self:drawCornerPattern(SCREEN_W - 60, 0, gameSpeed)
    self:drawCornerPattern(0, SCREEN_H - 40, gameSpeed)
    self:drawCornerPattern(SCREEN_W - 60, SCREEN_H - 40, gameSpeed)

    -- Speed lines
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for _, line in ipairs(self.speedLines) do
        gfx.drawLine(line.x, line.y, line.x + line.length, line.y)
    end

    -- Orbit ring decorations (tick marks around the orbit)
    local orbitRadius = 85
    local numTicks = 24
    for i = 0, numTicks - 1 do
        local tickAngle = math.rad(i * (360 / numTicks) + self.trackRotation)
        local innerR = orbitRadius - 4
        local outerR = orbitRadius + 4

        -- Alternating tick sizes
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

function World:drawCornerPattern(x, y, gameSpeed)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.8, gfx.image.kDitherTypeBayer8x8)

    local offset = math.floor(self.patternOffset)
    for i = 0, 3 do
        local lineY = y + i * 10 + (offset % 10)
        if lineY >= y and lineY <= y + 40 then
            gfx.drawLine(x, lineY, x + 60, lineY)
        end
    end
end
