-- Obstacles module for Torchy's World
-- Manages platforms, obstacles, and collectibles on the circular track
-- Smash Hit style: obstacles approach from center, can be shot and destroyed
-- All obstacles and platform changes blink/fade in as warnings

local gfx <const> = playdate.graphics

class('ObstacleManager').extends()

-- Constants
local PLATFORM_ARC = 45         -- Degrees of arc each platform covers
local OBSTACLE_TYPES = {"spike", "cone", "fire"}
local SPAWN_DISTANCE = 200      -- Distance between spawns

-- Warning/fade timing
local WARNING_BLINK_FRAMES = 60  -- How long the blinking warning lasts
local BLINK_RATE = 6             -- Frames per blink toggle
local FADE_STEPS = 10            -- Frames for final fade-in

-- Incoming obstacle (Smash Hit style)
local INCOMING_SPEED_BASE = 0.8
local INCOMING_SPAWN_RATE = 120  -- Frames between incoming spawns (decreases with difficulty)

function ObstacleManager:init()
    ObstacleManager.super.init(self)

    self.platforms = {}
    self.obstacles = {}
    self.collectibles = {}
    self.lastSpawnDistance = 0
    self.difficultyLevel = 1

    -- Incoming obstacles (Smash Hit style - approach from center)
    self.incomingObstacles = {}
    self.incomingSpawnTimer = 0

    -- Pending platform changes (for blinking transition)
    self.pendingPlatforms = nil
    self.transitionTimer = 0
    self.isTransitioning = false

    -- Destruction effects
    self.breakEffects = {}

    -- Load obstacle images
    self.spikeImg = gfx.image.new("images/obstacle-spike")
    self.coneImg = gfx.image.new("images/obstacle-cone")
    self.fireImg = gfx.image.new("images/obstacle-fire")
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
            state = "solid",    -- "solid", "warning_in", "warning_out", "fading_in", "fading_out"
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

    -- Spawn new platform configurations at intervals
    if distance - self.lastSpawnDistance > SPAWN_DISTANCE / (1 + self.difficultyLevel * 0.1) then
        self:beginPlatformTransition()
        self.lastSpawnDistance = distance
    end

    -- Update platform transitions (blinking warnings)
    self:updatePlatformTransitions()

    -- Spawn incoming obstacles (Smash Hit style)
    self.incomingSpawnTimer = self.incomingSpawnTimer + gameSpeed
    local spawnRate = math.max(40, INCOMING_SPAWN_RATE - self.difficultyLevel * 10)
    if self.incomingSpawnTimer >= spawnRate then
        self.incomingSpawnTimer = 0
        self:spawnIncomingObstacle()
    end

    -- Update incoming obstacles
    self:updateIncomingObstacles(gameSpeed)

    -- Update track obstacles
    for _, obs in ipairs(self.obstacles) do
        if obs.rotating then
            obs.angle = (obs.angle + obs.rotSpeed * gameSpeed) % 360
        end
        -- Update warning/blink state
        if obs.state == "warning_in" then
            obs.blinkTimer = obs.blinkTimer + 1
            if obs.blinkTimer >= WARNING_BLINK_FRAMES then
                obs.state = "fading_in"
                obs.opacity = 0.0
            end
        elseif obs.state == "fading_in" then
            obs.opacity = math.min(1.0, obs.opacity + 1.0 / FADE_STEPS)
            if obs.opacity >= 1.0 then
                obs.state = "solid"
                obs.dangerous = true
            end
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
    -- Calculate new platform layout
    local numGaps = math.min(5, 1 + math.floor(self.difficultyLevel / 2))
    local numSegments = 8
    local newSegments = {}

    for i = 1, numSegments do
        newSegments[i] = true
    end

    -- Remove random segments
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

    -- Determine which platforms are being added/removed
    local oldSegments = {}
    for i = 1, numSegments do
        oldSegments[i] = false
    end
    for _, plat in ipairs(self.platforms) do
        if plat.active and (plat.state == "solid" or plat.state == "fading_in") then
            local segIdx = math.floor(plat.startAngle / 45) + 1
            if segIdx >= 1 and segIdx <= numSegments then
                oldSegments[segIdx] = true
            end
        end
    end

    -- Start transition: mark platforms being removed as "warning_out"
    -- and prepare new platforms as "warning_in"
    local newPlatforms = {}
    for i = 1, numSegments do
        local startAngle = (i - 1) * 45
        local endAngle = (i - 1) * 45 + PLATFORM_ARC

        if newSegments[i] and oldSegments[i] then
            -- Platform stays - keep solid
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "solid",
                blinkTimer = 0,
                opacity = 1.0
            })
        elseif newSegments[i] and not oldSegments[i] then
            -- New platform appearing - blink warning first
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "warning_in",
                blinkTimer = 0,
                opacity = 0.0
            })
        elseif not newSegments[i] and oldSegments[i] then
            -- Platform being removed - blink warning then fade out
            table.insert(newPlatforms, {
                startAngle = startAngle,
                endAngle = endAngle,
                active = true,
                state = "warning_out",
                blinkTimer = 0,
                opacity = 1.0
            })
        end
        -- If not new and not old, no platform (gap stays)
    end

    self.platforms = newPlatforms

    -- Spawn obstacles on solid/incoming platforms with warnings
    self.obstacles = {}
    local numObstacles = math.min(4, math.floor(self.difficultyLevel / 2))
    local solidPlatforms = {}
    for _, p in ipairs(self.platforms) do
        if p.state == "solid" or p.state == "warning_in" then
            table.insert(solidPlatforms, p)
        end
    end

    for i = 1, numObstacles do
        if #solidPlatforms > 0 then
            local platIdx = math.random(1, #solidPlatforms)
            local plat = solidPlatforms[platIdx]
            local obsAngle = plat.startAngle + PLATFORM_ARC / 2

            local obsType = OBSTACLE_TYPES[math.random(1, #OBSTACLE_TYPES)]
            table.insert(self.obstacles, {
                angle = obsAngle,
                type = obsType,
                active = true,
                rotating = (obsType == "fire"),
                rotSpeed = 2,
                state = "warning_in",
                blinkTimer = 0,
                opacity = 0.0,
                dangerous = false,
                size = self:getObstacleSize(obsType)
            })
        end
    end

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
-- INCOMING OBSTACLES (SMASH HIT STYLE)
-- ============================================================

function ObstacleManager:spawnIncomingObstacle()
    local angle = math.random(0, 359)
    local obsType = OBSTACLE_TYPES[math.random(1, #OBSTACLE_TYPES)]

    table.insert(self.incomingObstacles, {
        angle = angle,
        radius = 10, -- starts near center
        targetRadius = 85, -- orbit radius
        speed = INCOMING_SPEED_BASE + self.difficultyLevel * 0.1,
        type = obsType,
        active = true,
        size = self:getObstacleSize(obsType),
        warningShown = false,
        hitPoints = 1, -- one shot to destroy
        blinkTimer = 0
    })
end

function ObstacleManager:updateIncomingObstacles(gameSpeed)
    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        obs.radius = obs.radius + obs.speed * gameSpeed
        obs.blinkTimer = obs.blinkTimer + 1

        -- When reaching the orbit, it becomes dangerous
        if obs.radius >= obs.targetRadius then
            obs.active = false
            table.remove(self.incomingObstacles, i)
            -- It becomes a regular track obstacle (already dangerous)
            table.insert(self.obstacles, {
                angle = obs.angle,
                type = obs.type,
                active = true,
                rotating = false,
                rotSpeed = 0,
                state = "solid",
                blinkTimer = 0,
                opacity = 1.0,
                dangerous = true,
                size = obs.size
            })
        end
    end
end

-- ============================================================
-- PROJECTILE COLLISION (player shoots to break obstacles)
-- ============================================================

function ObstacleManager:checkProjectileCollisions(projectiles)
    local hits = 0

    for pi = #projectiles, 1, -1 do
        local proj = projectiles[pi]
        local projRad = math.rad(proj.angle)
        local projX = proj.radius * math.cos(projRad)
        local projY = proj.radius * math.sin(projRad)

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
                -- Hit! Destroy both
                self:createBreakEffect(obs)
                table.remove(self.incomingObstacles, oi)
                table.remove(projectiles, pi)
                hits = hits + 1
                break
            end
        end

        -- Check against track obstacles too
        if projectiles[pi] then -- projectile still exists
            for oi = #self.obstacles, 1, -1 do
                local obs = self.obstacles[oi]
                if obs.active and obs.state == "solid" and obs.dangerous then
                    local angleDiff = math.abs(self:angleDifference(proj.angle, obs.angle))
                    local radiusDiff = math.abs(proj.radius - 85) -- orbit radius

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
    local cx = obs.radius and obs.radius or 85
    -- Create shatter particles (like Smash Hit glass breaking)
    for i = 1, 12 do
        local spd = 1 + math.random() * 3
        local angle = math.random() * math.pi * 2
        table.insert(self.breakEffects, {
            x = 200 + cx * math.cos(rad), -- approximate screen position
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
        e.vy = e.vy + 0.15 -- gravity
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
    while #self.obstacles > 10 do
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

    -- Check track obstacle collisions (only if dangerous/solid)
    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active and obs.dangerous then
            local angleDiff = math.abs(self:angleDifference(playerAngle, obs.angle))

            if angleDiff < collisionThreshold and not player.isJumping then
                obs.active = false
                table.remove(self.obstacles, i)
                return true, "obstacle"
            end

            -- Jump over check
            if angleDiff < collisionThreshold and player.isJumping and player.jumpOffset < -15 then
                -- Jumped over!
            end
        end
    end

    -- Check incoming obstacle collision (if it reached orbit and player is there)
    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        if obs.active and obs.radius >= 75 then -- close to orbit
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
        -- Only count solid and fading-out (grace period) platforms
        if plat.active and (plat.state == "solid" or plat.state == "warning_out" or plat.state == "fading_out") then
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

    -- Draw track obstacles
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

    -- Draw break effects (shatter particles)
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
        -- Blink: show/hide every BLINK_RATE frames
        local blinkPhase = math.floor(plat.blinkTimer / BLINK_RATE) % 2
        if blinkPhase == 1 then
            return -- hidden during blink-off phase
        end
        -- During blink-on, draw with dither to show it's transitional
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
    elseif plat.state == "fading_in" or plat.state == "fading_out" then
        -- Gradual fade
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

    -- Scale size based on distance (perspective: grows as it approaches)
    local scale = 0.3 + 0.7 * (obs.radius / obs.targetRadius)
    local drawSize = math.max(3, math.floor(obs.size * scale))

    -- Warning line from center to target position on orbit
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
    gfx.setLineWidth(1)
    local targetX = centerX + obs.targetRadius * math.cos(rad)
    local targetY = centerY + obs.targetRadius * math.sin(rad)
    gfx.drawLine(x, y, targetX, targetY)

    -- Draw the approaching obstacle
    gfx.setColor(gfx.kColorBlack)
    self:drawObstacleFallback(x, y, {type = obs.type, size = drawSize})

    -- Blinking danger ring as it gets close
    if obs.radius > obs.targetRadius * 0.6 then
        if obs.blinkTimer % 8 < 4 then
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(x, y, drawSize + 5)
        end
    end
end

function ObstacleManager:drawObstacle(centerX, centerY, orbitRadius, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + orbitRadius * math.cos(rad)
    local y = centerY + orbitRadius * math.sin(rad)

    -- Handle blinking/fading states
    if obs.state == "warning_in" then
        local blinkPhase = math.floor(obs.blinkTimer / BLINK_RATE) % 2
        if blinkPhase == 1 then
            return -- hidden during blink
        end
    end

    -- Apply opacity via dithering
    if obs.opacity < 1.0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1.0 - obs.opacity, gfx.image.kDitherTypeBayer8x8)
    end

    -- Try image first, fallback to manual drawing
    local img = nil
    if obs.type == "spike" then
        img = self.spikeImg
    elseif obs.type == "cone" then
        img = self.coneImg
    elseif obs.type == "fire" then
        img = self.fireImg
    end

    if img then
        local drawAngle = obs.angle + 90
        local rotated = img:rotatedImage(drawAngle)
        rotated:draw(x - rotated.width/2, y - rotated.height/2)
    else
        self:drawObstacleFallback(x, y, obs)
    end

    -- Fire danger ring
    if obs.type == "fire" and obs.state == "solid" then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
        gfx.drawCircleAtPoint(x, y, obs.size + 4)
    end
end

function ObstacleManager:drawObstacleFallback(x, y, obs)
    gfx.setColor(gfx.kColorBlack)

    if obs.type == "spike" then
        -- Triangle/spike
        gfx.fillPolygon(
            x, y - obs.size,
            x - obs.size, y + obs.size,
            x + obs.size, y + obs.size
        )
    elseif obs.type == "cone" then
        -- Cone with stripe
        gfx.fillPolygon(
            x, y - obs.size,
            x - obs.size * 0.7, y + obs.size,
            x + obs.size * 0.7, y + obs.size
        )
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(x - 3, y, x + 3, y)
    elseif obs.type == "fire" then
        -- Flame shape
        gfx.fillCircleAtPoint(x, y, obs.size)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y - 2, obs.size - 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x, y - 4, math.max(1, obs.size - 7))
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
        -- Fallback star drawing
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
            gfx.fillRect(e.x - s/2, e.y - s/2, s, s)
        else
            gfx.fillRect(e.x, e.y, 1, 1)
        end
    end
end
