-- Obstacles module for Torchy's World
-- Manages platforms, obstacles, and collectibles on the circular track

local gfx <const> = playdate.graphics

class('ObstacleManager').extends()

-- Constants
local PLATFORM_ARC = 45         -- Degrees of arc each platform covers
local MIN_PLATFORMS = 3         -- Minimum active platforms
local MAX_PLATFORMS = 6         -- Maximum platforms on screen
local OBSTACLE_TYPES = {"spike", "cone", "fire"}
local SPAWN_DISTANCE = 200      -- Distance between spawns

function ObstacleManager:init()
    ObstacleManager.super.init(self)

    self.platforms = {}
    self.obstacles = {}
    self.collectibles = {}
    self.lastSpawnDistance = 0
    self.difficultyLevel = 1

    -- Load obstacle images
    self.spikeImg = gfx.image.new("images/obstacle-spike")
    self.coneImg = gfx.image.new("images/obstacle-cone")
    self.fireImg = gfx.image.new("images/obstacle-fire")
    self.starImg = gfx.image.new("images/star")
    self.platformImg = gfx.image.new("images/platform")

    -- Initialize starting platforms (full ring to start safe)
    self:initStartingPlatforms()
end

function ObstacleManager:initStartingPlatforms()
    self.platforms = {}
    self.obstacles = {}
    self.collectibles = {}

    -- Start with platforms covering most of the ring
    -- 8 platforms of 45 degrees each = full coverage
    for i = 0, 7 do
        table.insert(self.platforms, {
            startAngle = i * 45,
            endAngle = i * 45 + PLATFORM_ARC,
            active = true,
            opacity = 1.0
        })
    end
end

function ObstacleManager:update(gameSpeed, distance)
    -- Update difficulty based on distance
    self.difficultyLevel = 1 + math.floor(distance / 300)
    if self.difficultyLevel > 10 then
        self.difficultyLevel = 10
    end

    -- Spawn new platform configurations at intervals
    if distance - self.lastSpawnDistance > SPAWN_DISTANCE / (1 + self.difficultyLevel * 0.1) then
        self:spawnNewSection()
        self.lastSpawnDistance = distance
    end

    -- Update obstacles (rotate them for visual interest)
    for _, obs in ipairs(self.obstacles) do
        if obs.rotating then
            obs.angle = (obs.angle + obs.rotSpeed * gameSpeed) % 360
        end
        -- Fade in
        if obs.fadeIn then
            obs.opacity = math.min(1.0, obs.opacity + 0.05)
            if obs.opacity >= 1.0 then
                obs.fadeIn = false
            end
        end
    end

    -- Update collectibles (bob effect)
    for _, col in ipairs(self.collectibles) do
        col.bobOffset = math.sin(col.bobPhase) * 5
        col.bobPhase = col.bobPhase + 0.1
    end

    -- Remove old obstacles that have been passed
    self:cleanupOld(distance)
end

function ObstacleManager:spawnNewSection()
    -- Create a new platform layout
    -- As difficulty increases, fewer platforms and more obstacles

    -- Calculate gap count based on difficulty
    local numGaps = math.min(5, 1 + math.floor(self.difficultyLevel / 2))
    local numSegments = 8 -- 8 segments of 45 degrees

    -- Decide which segments have platforms
    local segments = {}
    for i = 1, numSegments do
        segments[i] = true
    end

    -- Remove random segments to create gaps
    local gapsCreated = 0
    local attempts = 0
    while gapsCreated < numGaps and attempts < 20 do
        local idx = math.random(1, numSegments)
        if segments[idx] then
            -- Make sure we don't create too many consecutive gaps
            local prevIdx = ((idx - 2) % numSegments) + 1
            local nextIdx = (idx % numSegments) + 1
            if segments[prevIdx] or segments[nextIdx] then
                segments[idx] = false
                gapsCreated = gapsCreated + 1
            end
        end
        attempts = attempts + 1
    end

    -- Update platforms with transition
    self.platforms = {}
    for i = 1, numSegments do
        if segments[i] then
            table.insert(self.platforms, {
                startAngle = (i - 1) * 45,
                endAngle = (i - 1) * 45 + PLATFORM_ARC,
                active = true,
                opacity = 1.0
            })
        end
    end

    -- Spawn obstacles on platforms
    self.obstacles = {}
    local numObstacles = math.min(4, math.floor(self.difficultyLevel / 2))
    for i = 1, numObstacles do
        local platformIdx = math.random(1, #self.platforms)
        if platformIdx <= #self.platforms then
            local plat = self.platforms[platformIdx]
            local obsAngle = plat.startAngle + PLATFORM_ARC / 2

            local obsType = OBSTACLE_TYPES[math.random(1, #OBSTACLE_TYPES)]
            table.insert(self.obstacles, {
                angle = obsAngle,
                type = obsType,
                radius = 0, -- on the orbit
                active = true,
                rotating = (obsType == "fire"),
                rotSpeed = 2,
                opacity = 0,
                fadeIn = true,
                size = self:getObstacleSize(obsType)
            })
        end
    end

    -- Spawn collectible stars in gaps or on platforms
    self.collectibles = {}
    if math.random() < 0.6 then
        local starAngle = math.random(0, 359)
        table.insert(self.collectibles, {
            angle = starAngle,
            radius = -15, -- slightly outside orbit
            active = true,
            bobOffset = 0,
            bobPhase = math.random() * math.pi * 2,
            size = 8
        })
    end
end

function ObstacleManager:getObstacleSize(obsType)
    if obsType == "spike" then
        return 12
    elseif obsType == "cone" then
        return 10
    elseif obsType == "fire" then
        return 14
    end
    return 10
end

function ObstacleManager:cleanupOld(distance)
    -- Keep obstacles and collectibles lists manageable
    while #self.obstacles > 8 do
        table.remove(self.obstacles, 1)
    end
    while #self.collectibles > 4 do
        table.remove(self.collectibles, 1)
    end
end

function ObstacleManager:checkCollision(player)
    local playerAngle = player:getAngle()
    local collisionThreshold = 15 -- degrees

    -- Check obstacle collisions
    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active then
            local angleDiff = math.abs(self:angleDifference(playerAngle, obs.angle))

            if angleDiff < collisionThreshold and not player.isJumping then
                obs.active = false
                table.remove(self.obstacles, i)
                return true, "obstacle"
            end

            -- Can jump over obstacles
            if angleDiff < collisionThreshold and player.isJumping and player.jumpOffset < -15 then
                -- Player jumped over! Bonus points could be added
            end
        end
    end

    -- Check collectible collisions
    for i = #self.collectibles, 1, -1 do
        local col = self.collectibles[i]
        if col.active then
            local angleDiff = math.abs(self:angleDifference(playerAngle, col.angle))

            if angleDiff < 20 then
                col.active = false
                table.remove(self.collectibles, i)
                return true, "star"
            end
        end
    end

    return false, nil
end

function ObstacleManager:isOnPlatform(player)
    local playerAngle = player:getAngle() % 360

    for _, plat in ipairs(self.platforms) do
        if plat.active then
            local startA = plat.startAngle % 360
            local endA = plat.endAngle % 360

            if startA <= endA then
                if playerAngle >= startA and playerAngle <= endA then
                    return true
                end
            else
                -- Wraps around 360
                if playerAngle >= startA or playerAngle <= endA then
                    return true
                end
            end
        end
    end

    return false
end

function ObstacleManager:angleDifference(a1, a2)
    local diff = (a1 - a2) % 360
    if diff > 180 then
        diff = diff - 360
    end
    return diff
end

function ObstacleManager:draw(centerX, centerY, orbitRadius)
    -- Draw platforms as arcs on the orbit
    for _, plat in ipairs(self.platforms) do
        if plat.active then
            self:drawPlatformArc(centerX, centerY, orbitRadius, plat)
        end
    end

    -- Draw obstacles
    for _, obs in ipairs(self.obstacles) do
        if obs.active then
            self:drawObstacle(centerX, centerY, orbitRadius, obs)
        end
    end

    -- Draw collectibles
    for _, col in ipairs(self.collectibles) do
        if col.active then
            self:drawCollectible(centerX, centerY, orbitRadius, col)
        end
    end
end

function ObstacleManager:drawPlatformArc(centerX, centerY, orbitRadius, plat)
    -- Draw platform as a thick arc segment
    local innerR = orbitRadius - 8
    local outerR = orbitRadius + 8

    -- Draw arc using line segments
    local startRad = math.rad(plat.startAngle)
    local endRad = math.rad(plat.endAngle)
    local steps = 12

    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(2)

    -- Outer arc
    local prevX, prevY
    for i = 0, steps do
        local t = startRad + (endRad - startRad) * (i / steps)
        local x = centerX + outerR * math.cos(t)
        local y = centerY + outerR * math.sin(t)
        if prevX then
            gfx.drawLine(prevX, prevY, x, y)
        end
        prevX, prevY = x, y
    end

    -- Inner arc
    prevX, prevY = nil, nil
    for i = 0, steps do
        local t = startRad + (endRad - startRad) * (i / steps)
        local x = centerX + innerR * math.cos(t)
        local y = centerY + innerR * math.sin(t)
        if prevX then
            gfx.drawLine(prevX, prevY, x, y)
        end
        prevX, prevY = x, y
    end

    -- Connect ends
    local sx1 = centerX + innerR * math.cos(startRad)
    local sy1 = centerY + innerR * math.sin(startRad)
    local sx2 = centerX + outerR * math.cos(startRad)
    local sy2 = centerY + outerR * math.sin(startRad)
    gfx.drawLine(sx1, sy1, sx2, sy2)

    local ex1 = centerX + innerR * math.cos(endRad)
    local ey1 = centerY + innerR * math.sin(endRad)
    local ex2 = centerX + outerR * math.cos(endRad)
    local ey2 = centerY + outerR * math.sin(endRad)
    gfx.drawLine(ex1, ey1, ex2, ey2)

    -- Fill with dither pattern for texture
    -- Draw cross-hatches inside the platform
    for i = 1, steps - 1, 2 do
        local t = startRad + (endRad - startRad) * (i / steps)
        local ix = centerX + innerR * math.cos(t)
        local iy = centerY + innerR * math.sin(t)
        local ox = centerX + outerR * math.cos(t)
        local oy = centerY + outerR * math.sin(t)
        gfx.setLineWidth(1)
        gfx.drawLine(ix, iy, ox, oy)
    end

    gfx.setLineWidth(1)
end

function ObstacleManager:drawObstacle(centerX, centerY, orbitRadius, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + orbitRadius * math.cos(rad)
    local y = centerY + orbitRadius * math.sin(rad)

    -- Choose image based on type
    local img = nil
    if obs.type == "spike" then
        img = self.spikeImg
    elseif obs.type == "cone" then
        img = self.coneImg
    elseif obs.type == "fire" then
        img = self.fireImg
    end

    if img then
        -- Rotate obstacle to face outward from center
        local drawAngle = obs.angle + 90
        local rotated = img:rotatedImage(drawAngle)
        rotated:draw(x - rotated.width/2, y - rotated.height/2)
    else
        -- Fallback drawing
        self:drawObstacleFallback(x, y, obs)
    end

    -- Danger indicator ring
    if obs.type == "fire" then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.drawCircleAtPoint(x, y, obs.size + 4)
    end
end

function ObstacleManager:drawObstacleFallback(x, y, obs)
    gfx.setColor(gfx.kColorBlack)

    if obs.type == "spike" then
        -- Triangle
        gfx.fillPolygon(
            x, y - obs.size,
            x - obs.size, y + obs.size,
            x + obs.size, y + obs.size
        )
    elseif obs.type == "cone" then
        -- Cone shape
        gfx.fillPolygon(
            x, y - obs.size,
            x - obs.size * 0.7, y + obs.size,
            x + obs.size * 0.7, y + obs.size
        )
        -- Stripes
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(x - 3, y, x + 3, y)
    elseif obs.type == "fire" then
        -- Flame
        gfx.fillCircleAtPoint(x, y, obs.size)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y - 2, obs.size - 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x, y - 4, obs.size - 7)
    end
end

function ObstacleManager:drawCollectible(centerX, centerY, orbitRadius, col)
    local rad = math.rad(col.angle)
    local effectiveRadius = orbitRadius + col.radius + col.bobOffset
    local x = centerX + effectiveRadius * math.cos(rad)
    local y = centerY + effectiveRadius * math.sin(rad)

    if self.starImg then
        self.starImg:draw(x - 8, y - 8)
    else
        -- Fallback: draw a star shape
        gfx.setColor(gfx.kColorBlack)
        local points = {}
        for i = 0, 9 do
            local angle = math.pi / 2 + i * math.pi / 5
            local r = (i % 2 == 0) and col.size or (col.size * 0.4)
            table.insert(points, x + r * math.cos(angle))
            table.insert(points, y - r * math.sin(angle))
        end
        gfx.fillPolygon(table.unpack(points))
    end
end
