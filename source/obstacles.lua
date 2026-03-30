-- Obstacles module for Torchy's World
-- All obstacles approach from the center (Smash Hit style)
-- Square obstacles remain still on the ring after landing
-- Triangle obstacles orbit around the ring after landing
-- Platforms blink/fade with warnings before appearing/disappearing

local gfx <const> = playdate.graphics

class('ObstacleManager').extends()

-- Constants
local PLATFORM_ARC = 45         -- Degrees of arc each platform covers
local OBSTACLE_TYPES = {"square", "triangle"}
local SPAWN_DISTANCE = 200      -- Distance between platform reconfigurations

-- Warning/fade timing
local WARNING_BLINK_FRAMES = 60  -- How long the blinking warning lasts
local BLINK_RATE = 6             -- Frames per blink toggle
local FADE_STEPS = 10            -- Frames for final fade-in/out

-- Incoming obstacle (Smash Hit style)
local INCOMING_SPEED_BASE = 0.8
local INCOMING_SPAWN_RATE = 100  -- Frames between incoming spawns

-- Triangle orbit speed on the ring
local TRIANGLE_ORBIT_SPEED = 1.5

function ObstacleManager:init()
    ObstacleManager.super.init(self)

    self.platforms = {}
    self.obstacles = {}       -- Track obstacles (landed from center)
    self.collectibles = {}
    self.lastSpawnDistance = 0
    self.difficultyLevel = 1

    -- Incoming obstacles (approach from center)
    self.incomingObstacles = {}
    self.incomingSpawnTimer = 0

    -- Destruction effects
    self.breakEffects = {}

    -- Star image
    self.starImg = gfx.image.new("images/star")

    -- Initialize starting platforms (full ring)
    self:initStartingPlatforms()
end

function ObstacleManager:initStartingPlatforms()
    self.platforms = {}
    self.obstacles = {}
    self.collectibles = {}
    self.incomingObstacles = {}
    self.breakEffects = {}

    for i = 0, 7 do
        table.insert(self.platforms, {
            startAngle = i * 45,
            endAngle = i * 45 + PLATFORM_ARC,
            active = true,
            state = "solid",
            blinkTimer = 0,
            opacity = 1.0
        })
    end
end

function ObstacleManager:update(gameSpeed, distance)
    self.difficultyLevel = 1 + math.floor(distance / 300)
    if self.difficultyLevel > 10 then
        self.difficultyLevel = 10
    end

    -- Reconfigure platforms at intervals
    if distance - self.lastSpawnDistance > SPAWN_DISTANCE / (1 + self.difficultyLevel * 0.1) then
        self:beginPlatformTransition()
        self.lastSpawnDistance = distance
    end

    -- Update platform transitions (blinking warnings)
    self:updatePlatformTransitions()

    -- Spawn incoming obstacles from center (all obstacles come this way)
    self.incomingSpawnTimer = self.incomingSpawnTimer + gameSpeed
    local spawnRate = math.max(40, INCOMING_SPAWN_RATE - self.difficultyLevel * 10)
    if self.incomingSpawnTimer >= spawnRate then
        self.incomingSpawnTimer = 0
        self:spawnIncomingObstacle()
    end

    -- Update incoming obstacles (moving from center toward orbit)
    self:updateIncomingObstacles(gameSpeed)

    -- Update landed track obstacles
    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active then
            -- Triangle obstacles orbit around the ring
            if obs.type == "triangle" and obs.orbiting then
                obs.angle = (obs.angle + obs.orbitSpeed * gameSpeed) % 360
            end
            -- Square obstacles stay still (no update needed)
        end
    end

    -- Update collectibles (bob effect)
    for _, col in ipairs(self.collectibles) do
        col.bobOffset = math.sin(col.bobPhase) * 5
        col.bobPhase = col.bobPhase + 0.1
    end

    -- Update break effects
    self:updateBreakEffects()

    -- Cleanup
    self:cleanupOld(distance)
end

-- ============================================================
-- PLATFORM TRANSITION WITH BLINKING WARNING
-- ============================================================

function ObstacleManager:beginPlatformTransition()
    local numGaps = math.min(5, 1 + math.floor(self.difficultyLevel / 2))
    local numSegments = 8
    local newSegments = {}

    for i = 1, numSegments do
        newSegments[i] = true
    end

    -- Remove random segments to create gaps
    local gapsCreated = 0
    local attempts = 0
    while gapsCreated < numGaps and attempts < 20 do
        local idx = math.random(1, numSegments)
        if newSegments[idx] then
            local prevIdx = ((idx - 2) % numSegments) + 1
            local nextIdx = (idx % numSegments) + 1
            if newSegments[prevIdx] or newSegments[nextIdx] then
                newSegments[idx] = false
                gapsCreated = gapsCreated + 1
            end
        end
        attempts = attempts + 1
    end

    -- Determine which segments currently exist
    local oldSegments = {}
    for i = 1, numSegments do
        oldSegments[i] = false
    end
    for _, plat in ipairs(self.platforms) do
        if plat.active and (plat.state == "solid" or plat.state == "fading_in" or plat.state == "warning_in") then
            local segIdx = math.floor(plat.startAngle / 45) + 1
            if segIdx >= 1 and segIdx <= numSegments then
                oldSegments[segIdx] = true
            end
        end
    end

    -- Build new platform list with transitions
    local newPlatforms = {}
    for i = 1, numSegments do
        local startAngle = (i - 1) * 45
        local endAngle = (i - 1) * 45 + PLATFORM_ARC

        if newSegments[i] and oldSegments[i] then
            -- Stays solid
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "solid",
                blinkTimer = 0,
                opacity = 1.0
            })
        elseif newSegments[i] and not oldSegments[i] then
            -- New platform appearing - blink warning
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "warning_in",
                blinkTimer = 0,
                opacity = 0.0
            })
        elseif not newSegments[i] and oldSegments[i] then
            -- Platform being removed - blink warning then fade
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "warning_out",
                blinkTimer = 0,
                opacity = 1.0
            })
        end
    end

    self.platforms = newPlatforms

    -- No obstacles spawned directly on platforms anymore.
    -- All obstacles come from center via spawnIncomingObstacle().

    -- Spawn collectible stars
    self.collectibles = {}
    if math.random() < 0.6 then
        local starAngle = math.random(0, 359)
        table.insert(self.collectibles, {
            angle = starAngle,
            radius = -15,
            active = true,
            bobOffset = 0,
            bobPhase = math.random() * math.pi * 2,
            size = 8
        })
    end
end

function ObstacleManager:updatePlatformTransitions()
    for i = #self.platforms, 1, -1 do
        local plat = self.platforms[i]

        if plat.state == "warning_in" then
            plat.blinkTimer = plat.blinkTimer + 1
            if plat.blinkTimer >= WARNING_BLINK_FRAMES then
                plat.state = "fading_in"
                plat.opacity = 0.0
            end
        elseif plat.state == "fading_in" then
            plat.opacity = math.min(1.0, plat.opacity + 1.0 / FADE_STEPS)
            if plat.opacity >= 1.0 then
                plat.state = "solid"
            end
        elseif plat.state == "warning_out" then
            plat.blinkTimer = plat.blinkTimer + 1
            if plat.blinkTimer >= WARNING_BLINK_FRAMES then
                plat.state = "fading_out"
            end
        elseif plat.state == "fading_out" then
            plat.opacity = math.max(0.0, plat.opacity - 1.0 / FADE_STEPS)
            if plat.opacity <= 0 then
                plat.active = false
                table.remove(self.platforms, i)
            end
        end
    end
end

-- ============================================================
-- INCOMING OBSTACLES (ALL FROM CENTER)
-- ============================================================

function ObstacleManager:spawnIncomingObstacle()
    local angle = math.random(0, 359)
    local obsType = OBSTACLE_TYPES[math.random(1, #OBSTACLE_TYPES)]

    table.insert(self.incomingObstacles, {
        angle = angle,
        radius = 10,
        targetRadius = 85,
        speed = INCOMING_SPEED_BASE + self.difficultyLevel * 0.1,
        type = obsType,
        active = true,
        size = self:getObstacleSize(obsType),
        hitPoints = 1,
        blinkTimer = 0
    })
end

function ObstacleManager:updateIncomingObstacles(gameSpeed)
    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        obs.radius = obs.radius + obs.speed * gameSpeed
        obs.blinkTimer = obs.blinkTimer + 1

        -- When reaching the orbit, it lands and becomes a track obstacle
        if obs.radius >= obs.targetRadius then
            table.remove(self.incomingObstacles, i)

            if obs.type == "square" then
                -- Square: stays still at its landing angle
                table.insert(self.obstacles, {
                    angle = obs.angle,
                    type = "square",
                    active = true,
                    orbiting = false,
                    orbitSpeed = 0,
                    dangerous = true,
                    size = obs.size
                })
            elseif obs.type == "triangle" then
                -- Triangle: starts orbiting around the ring
                local dir = (math.random() < 0.5) and 1 or -1
                table.insert(self.obstacles, {
                    angle = obs.angle,
                    type = "triangle",
                    active = true,
                    orbiting = true,
                    orbitSpeed = TRIANGLE_ORBIT_SPEED * dir,
                    dangerous = true,
                    size = obs.size
                })
            end
        end
    end
end

-- ============================================================
-- PROJECTILE COLLISION
-- ============================================================

function ObstacleManager:checkProjectileCollisions(projectiles)
    local hits = 0

    for pi = #projectiles, 1, -1 do
        local proj = projectiles[pi]
        local projRad = math.rad(proj.angle)
        local projX = proj.radius * math.cos(projRad)
        local projY = proj.radius * math.sin(projRad)

        local hitSomething = false

        -- Check against incoming obstacles
        for oi = #self.incomingObstacles, 1, -1 do
            local obs = self.incomingObstacles[oi]
            local obsRad = math.rad(obs.angle)
            local obsX = obs.radius * math.cos(obsRad)
            local obsY = obs.radius * math.sin(obsRad)

            local dx = projX - obsX
            local dy = projY - obsY
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < (obs.size + proj.size + 5) then
                self:createBreakEffect(obs)
                table.remove(self.incomingObstacles, oi)
                table.remove(projectiles, pi)
                hits = hits + 1
                hitSomething = true
                break
            end
        end

        -- Check against track obstacles (landed ones)
        if not hitSomething and projectiles[pi] then
            for oi = #self.obstacles, 1, -1 do
                local obs = self.obstacles[oi]
                if obs.active and obs.dangerous then
                    local angleDiff = math.abs(self:angleDifference(proj.angle, obs.angle))
                    local radiusDiff = math.abs(proj.radius - 85)

                    if angleDiff < 15 and radiusDiff < 15 then
                        self:createBreakEffect(obs)
                        table.remove(self.obstacles, oi)
                        table.remove(projectiles, pi)
                        hits = hits + 1
                        break
                    end
                end
            end
        end
    end

    return hits
end

function ObstacleManager:createBreakEffect(obs)
    local rad = math.rad(obs.angle)
    local cx = obs.radius or 85
    for i = 1, 12 do
        local spd = 1 + math.random() * 3
        local angle = math.random() * math.pi * 2
        table.insert(self.breakEffects, {
            x = 200 + cx * math.cos(rad),
            y = 120 + cx * math.sin(rad),
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = 15 + math.random(0, 10),
            size = math.random(2, 5),
            type = obs.type
        })
    end
end

function ObstacleManager:updateBreakEffects()
    for i = #self.breakEffects, 1, -1 do
        local e = self.breakEffects[i]
        e.x = e.x + e.vx
        e.y = e.y + e.vy
        e.vy = e.vy + 0.15
        e.life = e.life - 1
        e.size = math.max(1, e.size - 0.1)
        if e.life <= 0 then
            table.remove(self.breakEffects, i)
        end
    end
end

-- ============================================================
-- COLLISION DETECTION
-- ============================================================

function ObstacleManager:getObstacleSize(obsType)
    if obsType == "square" then
        return 11
    elseif obsType == "triangle" then
        return 12
    end
    return 10
end

function ObstacleManager:cleanupOld(distance)
    while #self.obstacles > 12 do
        table.remove(self.obstacles, 1)
    end
    while #self.collectibles > 4 do
        table.remove(self.collectibles, 1)
    end
    while #self.breakEffects > 50 do
        table.remove(self.breakEffects, 1)
    end
end

function ObstacleManager:checkCollision(player)
    local playerAngle = player:getAngle()
    local collisionThreshold = 15

    -- Check track obstacle collisions
    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active and obs.dangerous then
            local angleDiff = math.abs(self:angleDifference(playerAngle, obs.angle))

            if angleDiff < collisionThreshold and not player.isJumping then
                obs.active = false
                table.remove(self.obstacles, i)
                return true, "obstacle"
            end
        end
    end

    -- Check incoming obstacles near the orbit
    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        if obs.active and obs.radius >= 75 then
            local angleDiff = math.abs(self:angleDifference(playerAngle, obs.angle))
            if angleDiff < collisionThreshold and not player.isJumping then
                obs.active = false
                table.remove(self.incomingObstacles, i)
                return true, "obstacle"
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
        -- BUG FIX: Only "solid" platforms count as ground.
        -- "warning_out" gives a brief grace period (first half of blink only).
        -- "fading_out" does NOT count - the platform is gone, player falls.
        local isValid = false
        if plat.active then
            if plat.state == "solid" then
                isValid = true
            elseif plat.state == "warning_out" and plat.blinkTimer < (WARNING_BLINK_FRAMES / 2) then
                -- First half of warning: still counts (grace period to move)
                isValid = true
            end
            -- "fading_out", "warning_in", "fading_in" do NOT count
        end

        if isValid then
            local startA = plat.startAngle % 360
            local endA = plat.endAngle % 360

            if startA <= endA then
                if playerAngle >= startA and playerAngle <= endA then
                    return true
                end
            else
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

-- ============================================================
-- DRAWING
-- ============================================================

function ObstacleManager:draw(centerX, centerY, orbitRadius)
    -- Draw platforms
    for _, plat in ipairs(self.platforms) do
        if plat.active then
            self:drawPlatformArc(centerX, centerY, orbitRadius, plat)
        end
    end

    -- Draw incoming obstacles (approaching from center)
    for _, obs in ipairs(self.incomingObstacles) do
        if obs.active then
            self:drawIncomingObstacle(centerX, centerY, obs)
        end
    end

    -- Draw track obstacles (landed)
    for _, obs in ipairs(self.obstacles) do
        if obs.active then
            self:drawTrackObstacle(centerX, centerY, orbitRadius, obs)
        end
    end

    -- Draw collectibles
    for _, col in ipairs(self.collectibles) do
        if col.active then
            self:drawCollectible(centerX, centerY, orbitRadius, col)
        end
    end

    -- Draw break effects
    self:drawBreakEffects()
end

function ObstacleManager:drawPlatformArc(centerX, centerY, orbitRadius, plat)
    local innerR = orbitRadius - 8
    local outerR = orbitRadius + 8
    local startRad = math.rad(plat.startAngle)
    local endRad = math.rad(plat.endAngle)
    local steps = 12

    -- Handle blinking states
    if plat.state == "warning_in" or plat.state == "warning_out" then
        local blinkPhase = math.floor(plat.blinkTimer / BLINK_RATE) % 2
        if blinkPhase == 1 then
            return
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    elseif plat.state == "fading_in" or plat.state == "fading_out" then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1.0 - plat.opacity, gfx.image.kDitherTypeBayer8x8)
    else
        gfx.setColor(gfx.kColorBlack)
    end

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

    -- Cross-hatches (only for solid platforms)
    if plat.state == "solid" then
        gfx.setColor(gfx.kColorBlack)
        for i = 1, steps - 1, 2 do
            local t = startRad + (endRad - startRad) * (i / steps)
            local ix = centerX + innerR * math.cos(t)
            local iy = centerY + innerR * math.sin(t)
            local ox = centerX + outerR * math.cos(t)
            local oy = centerY + outerR * math.sin(t)
            gfx.setLineWidth(1)
            gfx.drawLine(ix, iy, ox, oy)
        end
    end

    gfx.setLineWidth(1)
end

function ObstacleManager:drawIncomingObstacle(centerX, centerY, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + obs.radius * math.cos(rad)
    local y = centerY + obs.radius * math.sin(rad)

    -- Scale size based on distance (perspective effect)
    local scale = 0.3 + 0.7 * (obs.radius / obs.targetRadius)
    local drawSize = math.max(3, math.floor(obs.size * scale))

    -- Warning line from obstacle to target position on orbit
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
    gfx.setLineWidth(1)
    local targetX = centerX + obs.targetRadius * math.cos(rad)
    local targetY = centerY + obs.targetRadius * math.sin(rad)
    gfx.drawLine(x, y, targetX, targetY)

    -- Draw the approaching obstacle shape
    gfx.setColor(gfx.kColorBlack)
    self:drawObstacleShape(x, y, obs.type, drawSize)

    -- Blinking danger ring when close to orbit
    if obs.radius > obs.targetRadius * 0.6 then
        if obs.blinkTimer % 8 < 4 then
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(x, y, drawSize + 5)
        end
    end
end

function ObstacleManager:drawTrackObstacle(centerX, centerY, orbitRadius, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + orbitRadius * math.cos(rad)
    local y = centerY + orbitRadius * math.sin(rad)

    gfx.setColor(gfx.kColorBlack)
    self:drawObstacleShape(x, y, obs.type, obs.size)

    -- Orbiting triangle indicator (small motion trail)
    if obs.type == "triangle" and obs.orbiting then
        local trailDir = obs.orbitSpeed > 0 and -1 or 1
        local trailAngle = obs.angle + trailDir * 8
        local trailRad = math.rad(trailAngle)
        local tx = centerX + orbitRadius * math.cos(trailRad)
        local ty = centerY + orbitRadius * math.sin(trailRad)
        gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer4x4)
        self:drawObstacleShape(tx, ty, "triangle", math.floor(obs.size * 0.6))
    end
end

function ObstacleManager:drawObstacleShape(x, y, obsType, size)
    gfx.setColor(gfx.kColorBlack)

    if obsType == "square" then
        -- Filled square with white center detail
        gfx.fillRect(x - size, y - size, size * 2, size * 2)
        gfx.setColor(gfx.kColorWhite)
        local inner = math.max(1, size - 3)
        gfx.fillRect(x - inner, y - inner, inner * 2, inner * 2)
        -- Small cross in center
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x - 2, y, x + 2, y)
        gfx.drawLine(x, y - 2, x, y + 2)
    elseif obsType == "triangle" then
        -- Filled triangle pointing outward
        gfx.fillPolygon(
            x, y - size,
            x - size, y + size,
            x + size, y + size
        )
        -- White inner triangle for detail
        gfx.setColor(gfx.kColorWhite)
        local inner = math.max(1, size - 4)
        gfx.fillPolygon(
            x, y - inner,
            x - inner * 0.6, y + inner * 0.6,
            x + inner * 0.6, y + inner * 0.6
        )
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

function ObstacleManager:drawBreakEffects()
    gfx.setColor(gfx.kColorBlack)
    for _, e in ipairs(self.breakEffects) do
        local alpha = e.life / 25
        if alpha > 0.3 then
            gfx.setDitherPattern(1.0 - alpha, gfx.image.kDitherTypeBayer4x4)
            local s = math.max(1, math.floor(e.size))
            if e.type == "square" then
                gfx.fillRect(e.x - s/2, e.y - s/2, s, s)
            else
                -- Triangle shards
                gfx.fillPolygon(e.x, e.y - s, e.x - s, e.y + s, e.x + s, e.y + s)
            end
        else
            gfx.fillRect(e.x, e.y, 1, 1)
        end
    end
end
