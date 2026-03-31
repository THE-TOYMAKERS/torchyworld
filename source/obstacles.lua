-- Obstacles module for Cronobreak
-- Enemy minions approach from the Time Wizard at center
-- Standing minions (still), flying minions (orbit), platform gaps
-- Ammo crates and bubbles spawn as power-ups

local gfx <const> = playdate.graphics

class('ObstacleManager').extends()

-- Constants
local PLATFORM_ARC = 45
local OBSTACLE_TYPES = {"minion_stand", "minion_fly"}
local SPAWN_DISTANCE = 200

-- Warning/fade timing
local WARNING_BLINK_FRAMES = 60
local BLINK_RATE = 6
local FADE_STEPS = 10

-- Incoming
local INCOMING_SPEED_BASE = 0.8
local INCOMING_SPAWN_RATE = 100

-- Flying minion orbit speed
local FLY_ORBIT_SPEED = 1.5

-- Obstacle lifetime on ring
local OBSTACLE_LIFETIME = 120
local OBSTACLE_FADE_FRAMES = 15

-- Power-up spawn chances (per spawn cycle)
local BUBBLE_SPAWN_CHANCE = 0.06
local AMMO_CRATE_SPAWN_CHANCE = 0.12

function ObstacleManager:init()
    ObstacleManager.super.init(self)

    self.platforms = {}
    self.obstacles = {}
    self.lastSpawnDistance = 0
    self.difficultyLevel = 1

    self.incomingObstacles = {}
    self.incomingSpawnTimer = 0
    self.breakEffects = {}

    -- Track wizard anger for main.lua to read
    self.wizardAngerTimer = 0

    self:initStartingPlatforms()
end

function ObstacleManager:initStartingPlatforms()
    self.platforms = {}
    self.obstacles = {}
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

    if distance - self.lastSpawnDistance > SPAWN_DISTANCE / (1 + self.difficultyLevel * 0.1) then
        self:beginPlatformTransition()
        self.lastSpawnDistance = distance
    end

    self:updatePlatformTransitions()

    self.incomingSpawnTimer = self.incomingSpawnTimer + gameSpeed
    local spawnRate = math.max(40, INCOMING_SPAWN_RATE - self.difficultyLevel * 10)
    if self.incomingSpawnTimer >= spawnRate then
        self.incomingSpawnTimer = 0
        self:spawnIncoming()
    end

    self:updateIncomingObstacles(gameSpeed)

    -- Update landed obstacles
    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active then
            if obs.type == "minion_fly" and obs.orbiting then
                obs.angle = (obs.angle + obs.orbitSpeed * gameSpeed) % 360
            end
            -- Lifetime decay for enemies only
            if obs.lifetime then
                obs.lifetime = obs.lifetime - gameSpeed
                if obs.lifetime <= 0 then
                    obs.active = false
                    table.remove(self.obstacles, i)
                end
            end
            -- Ammo crate bob
            if obs.type == "ammo_crate" and obs.bobPhase then
                obs.bobPhase = obs.bobPhase + 0.1
            end
        end
    end

    -- Wizard anger decay
    if self.wizardAngerTimer > 0 then
        self.wizardAngerTimer = self.wizardAngerTimer - 1
    end

    self:updateBreakEffects()
    self:cleanupOld(distance)
end

-- ============================================================
-- PLATFORM TRANSITION
-- ============================================================

function ObstacleManager:beginPlatformTransition()
    local numGaps = math.min(4, 1 + math.floor(self.difficultyLevel / 2))
    local numSegments = 8
    local minConsecutiveSolid = 2  -- at least 90 degrees (2 segments) of solid platform

    local newSegments = {}
    for i = 1, numSegments do newSegments[i] = true end

    local gapsCreated = 0
    local attempts = 0
    while gapsCreated < numGaps and attempts < 30 do
        local idx = math.random(1, numSegments)
        if newSegments[idx] then
            -- Temporarily remove this segment
            newSegments[idx] = false

            -- Check: does every gap neighbor at least one solid segment,
            -- AND is there a run of at least minConsecutiveSolid solid segments?
            local valid = true

            -- Check neighbor rule
            local prevIdx = ((idx - 2) % numSegments) + 1
            local nextIdx = (idx % numSegments) + 1
            if not newSegments[prevIdx] and not newSegments[nextIdx] then
                valid = false
            end

            -- Check minimum consecutive solid run exists
            if valid then
                local maxRun = 0
                for start = 1, numSegments do
                    local run = 0
                    for offset = 0, numSegments - 1 do
                        local si = ((start - 1 + offset) % numSegments) + 1
                        if newSegments[si] then
                            run = run + 1
                            if run > maxRun then maxRun = run end
                        else
                            break
                        end
                    end
                end
                if maxRun < minConsecutiveSolid then valid = false end
            end

            if valid then
                gapsCreated = gapsCreated + 1
            else
                newSegments[idx] = true  -- revert
            end
        end
        attempts = attempts + 1
    end

    local oldSegments = {}
    for i = 1, numSegments do oldSegments[i] = false end
    for _, plat in ipairs(self.platforms) do
        if plat.active and (plat.state == "solid" or plat.state == "fading_in" or plat.state == "warning_in") then
            local segIdx = math.floor(plat.startAngle / 45) + 1
            if segIdx >= 1 and segIdx <= numSegments then
                oldSegments[segIdx] = true
            end
        end
    end

    local newPlatforms = {}
    for i = 1, numSegments do
        local sa = (i - 1) * 45
        local ea = sa + PLATFORM_ARC
        if newSegments[i] and oldSegments[i] then
            table.insert(newPlatforms, {startAngle=sa, endAngle=ea, active=true, state="solid", blinkTimer=0, opacity=1.0})
        elseif newSegments[i] and not oldSegments[i] then
            table.insert(newPlatforms, {startAngle=sa, endAngle=ea, active=true, state="warning_in", blinkTimer=0, opacity=0.0})
        elseif not newSegments[i] and oldSegments[i] then
            table.insert(newPlatforms, {startAngle=sa, endAngle=ea, active=true, state="warning_out", blinkTimer=0, opacity=1.0})
        end
    end
    self.platforms = newPlatforms
end

function ObstacleManager:updatePlatformTransitions()
    for i = #self.platforms, 1, -1 do
        local p = self.platforms[i]
        if p.state == "warning_in" then
            p.blinkTimer = p.blinkTimer + 1
            if p.blinkTimer >= WARNING_BLINK_FRAMES then p.state = "fading_in"; p.opacity = 0.0 end
        elseif p.state == "fading_in" then
            p.opacity = math.min(1.0, p.opacity + 1.0/FADE_STEPS)
            if p.opacity >= 1.0 then p.state = "solid" end
        elseif p.state == "warning_out" then
            p.blinkTimer = p.blinkTimer + 1
            if p.blinkTimer >= WARNING_BLINK_FRAMES then p.state = "fading_out" end
        elseif p.state == "fading_out" then
            p.opacity = math.max(0.0, p.opacity - 1.0/FADE_STEPS)
            if p.opacity <= 0 then p.active = false; table.remove(self.platforms, i) end
        end
    end
end

-- ============================================================
-- SPAWNING FROM CENTER
-- ============================================================

function ObstacleManager:spawnIncoming()
    local angle = math.random(0, 359)
    local roll = math.random()

    if roll < AMMO_CRATE_SPAWN_CHANCE then
        -- Ammo crate power-up
        table.insert(self.incomingObstacles, {
            angle = angle, radius = 10, targetRadius = 85,
            speed = INCOMING_SPEED_BASE + self.difficultyLevel * 0.05,
            type = "ammo_crate", active = true, size = 7,
            hitPoints = 1, blinkTimer = 0
        })
    elseif roll < AMMO_CRATE_SPAWN_CHANCE + BUBBLE_SPAWN_CHANCE then
        -- Bubble shield
        table.insert(self.incomingObstacles, {
            angle = angle, radius = 10, targetRadius = 85,
            speed = INCOMING_SPEED_BASE + self.difficultyLevel * 0.05,
            type = "bubble", active = true, size = 10,
            hitPoints = 1, blinkTimer = 0
        })
    else
        -- Enemy minion
        local obsType = OBSTACLE_TYPES[math.random(1, #OBSTACLE_TYPES)]
        table.insert(self.incomingObstacles, {
            angle = angle, radius = 10, targetRadius = 85,
            speed = INCOMING_SPEED_BASE + self.difficultyLevel * 0.1,
            type = obsType, active = true,
            size = self:getObstacleSize(obsType),
            hitPoints = 1, blinkTimer = 0
        })
    end
end

function ObstacleManager:updateIncomingObstacles(gameSpeed)
    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        obs.radius = obs.radius + obs.speed * gameSpeed
        obs.blinkTimer = obs.blinkTimer + 1

        if obs.radius >= obs.targetRadius then
            table.remove(self.incomingObstacles, i)

            if obs.type == "bubble" then
                table.insert(self.obstacles, {
                    angle=obs.angle, type="bubble", active=true, orbiting=false,
                    orbitSpeed=0, dangerous=false, size=obs.size, bobPhase=0
                })
            elseif obs.type == "ammo_crate" then
                table.insert(self.obstacles, {
                    angle=obs.angle, type="ammo_crate", active=true, orbiting=false,
                    orbitSpeed=0, dangerous=false, size=obs.size, bobPhase=0
                })
            elseif obs.type == "minion_stand" then
                table.insert(self.obstacles, {
                    angle=obs.angle, type="minion_stand", active=true, orbiting=false,
                    orbitSpeed=0, dangerous=true, size=obs.size, lifetime=OBSTACLE_LIFETIME
                })
            elseif obs.type == "minion_fly" then
                local dir = (math.random() < 0.5) and 1 or -1
                table.insert(self.obstacles, {
                    angle=obs.angle, type="minion_fly", active=true, orbiting=true,
                    orbitSpeed=FLY_ORBIT_SPEED * dir, dangerous=true,
                    size=obs.size, lifetime=OBSTACLE_LIFETIME
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

        -- Incoming enemies (not power-ups)
        for oi = #self.incomingObstacles, 1, -1 do
            local obs = self.incomingObstacles[oi]
            if obs.type ~= "bubble" and obs.type ~= "ammo_crate" then
                local obsRad = math.rad(obs.angle)
                local dx = projX - obs.radius * math.cos(obsRad)
                local dy = projY - obs.radius * math.sin(obsRad)
                if math.sqrt(dx*dx + dy*dy) < (obs.size + proj.size + 5) then
                    self:createBreakEffect(obs)
                    table.remove(self.incomingObstacles, oi)
                    table.remove(projectiles, pi)
                    hits = hits + 1
                    hitSomething = true
                    self.wizardAngerTimer = 45  -- Wizard gets angry when minions die
                    break
                end
            end
        end

        -- Track enemies
        if not hitSomething and projectiles[pi] then
            for oi = #self.obstacles, 1, -1 do
                local obs = self.obstacles[oi]
                if obs.active and obs.dangerous then
                    local angleDiff = math.abs(self:angleDifference(proj.angle, obs.angle))
                    if angleDiff < 15 and math.abs(proj.radius - 85) < 15 then
                        self:createBreakEffect(obs)
                        table.remove(self.obstacles, oi)
                        table.remove(projectiles, pi)
                        hits = hits + 1
                        self.wizardAngerTimer = 45
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
        local a = math.random() * math.pi * 2
        table.insert(self.breakEffects, {
            x = 200 + cx * math.cos(rad), y = 120 + cx * math.sin(rad),
            vx = math.cos(a) * spd, vy = math.sin(a) * spd,
            life = 15 + math.random(0, 10), size = math.random(2, 5), type = obs.type
        })
    end
end

function ObstacleManager:updateBreakEffects()
    for i = #self.breakEffects, 1, -1 do
        local e = self.breakEffects[i]
        e.x = e.x + e.vx; e.y = e.y + e.vy
        e.vy = e.vy + 0.15; e.life = e.life - 1
        e.size = math.max(1, e.size - 0.1)
        if e.life <= 0 then table.remove(self.breakEffects, i) end
    end
end

-- ============================================================
-- COLLISION / PLATFORM
-- ============================================================

function ObstacleManager:getObstacleSize(obsType)
    if obsType == "minion_stand" then return 11
    elseif obsType == "minion_fly" then return 12
    elseif obsType == "bubble" then return 10
    elseif obsType == "ammo_crate" then return 7
    end
    return 10
end

function ObstacleManager:cleanupOld(distance)
    while #self.obstacles > 14 do table.remove(self.obstacles, 1) end
    while #self.breakEffects > 50 do table.remove(self.breakEffects, 1) end
end

function ObstacleManager:checkCollision(player)
    local playerAngle = player:getAngle()
    local threshold = 15

    for i = #self.obstacles, 1, -1 do
        local obs = self.obstacles[i]
        if obs.active then
            local diff = math.abs(self:angleDifference(playerAngle, obs.angle))

            if obs.type == "bubble" then
                if diff < 20 then
                    obs.active = false; table.remove(self.obstacles, i)
                    return true, "bubble"
                end
            elseif obs.type == "ammo_crate" then
                if diff < 20 then
                    obs.active = false; table.remove(self.obstacles, i)
                    return true, "ammo_crate"
                end
            elseif obs.dangerous then
                if diff < threshold and not player.isJumping then
                    obs.active = false; table.remove(self.obstacles, i)
                    return true, "obstacle"
                end
            end
        end
    end

    for i = #self.incomingObstacles, 1, -1 do
        local obs = self.incomingObstacles[i]
        if obs.active and obs.radius >= 75 then
            local diff = math.abs(self:angleDifference(playerAngle, obs.angle))
            if obs.type == "bubble" or obs.type == "ammo_crate" then
                if diff < 20 then
                    local t = obs.type
                    obs.active = false; table.remove(self.incomingObstacles, i)
                    return true, t
                end
            else
                if diff < threshold and not player.isJumping then
                    obs.active = false; table.remove(self.incomingObstacles, i)
                    return true, "obstacle"
                end
            end
        end
    end

    return false, nil
end

function ObstacleManager:isOnPlatform(player)
    local cur = player:getAngle() % 360
    local prev = player:getPrevAngle() % 360
    local diff = cur - prev
    if diff > 180 then diff = diff - 360 end
    if diff < -180 then diff = diff + 360 end

    local n = math.max(1, math.ceil(math.abs(diff) / 10))
    for step = 0, n do
        local t = (n > 0) and (step / n) or 0
        local ca = (prev + diff * t) % 360
        if ca < 0 then ca = ca + 360 end

        local onPlat = false
        for _, plat in ipairs(self.platforms) do
            local valid = plat.active and (plat.state == "solid"
                or (plat.state == "warning_out" and plat.blinkTimer < WARNING_BLINK_FRAMES/2))
            if valid then
                local sa, ea = plat.startAngle % 360, plat.endAngle % 360
                if sa <= ea then
                    if ca >= sa and ca <= ea then onPlat = true; break end
                else
                    if ca >= sa or ca <= ea then onPlat = true; break end
                end
            end
        end
        if not onPlat then return false end
    end
    return true
end

function ObstacleManager:angleDifference(a1, a2)
    local d = (a1 - a2) % 360
    if d > 180 then d = d - 360 end
    return d
end

-- ============================================================
-- DRAWING
-- ============================================================

function ObstacleManager:draw(centerX, centerY, orbitRadius)
    for _, plat in ipairs(self.platforms) do
        if plat.active then self:drawPlatformArc(centerX, centerY, orbitRadius, plat) end
    end
    for _, obs in ipairs(self.incomingObstacles) do
        if obs.active then self:drawIncoming(centerX, centerY, obs) end
    end
    for _, obs in ipairs(self.obstacles) do
        if obs.active then self:drawTrackObs(centerX, centerY, orbitRadius, obs) end
    end
    self:drawBreakEffects()
end

function ObstacleManager:drawPlatformArc(centerX, centerY, orbitRadius, plat)
    local innerR = orbitRadius - 8
    local outerR = orbitRadius + 8
    local sRad = math.rad(plat.startAngle)
    local eRad = math.rad(plat.endAngle)
    local steps = 12

    -- Offset for "dropping" animation when disappearing
    local dropOffset = 0

    if plat.state == "warning_out" then
        -- DISAPPEARING: rapid blink, getting faster
        local rate = math.max(2, BLINK_RATE - math.floor(plat.blinkTimer / 15))
        if math.floor(plat.blinkTimer / rate) % 2 == 1 then return end
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.4, gfx.image.kDitherTypeBayer4x4)
    elseif plat.state == "fading_out" then
        -- DISAPPEARING: drops away from orbit (outward) and fades
        dropOffset = (1.0 - plat.opacity) * 12
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1.0 - plat.opacity, gfx.image.kDitherTypeBayer8x8)
    elseif plat.state == "warning_in" then
        -- APPEARING: gentle pulse, grows from center of arc
        local pulse = math.sin(plat.blinkTimer * 0.3) * 0.5 + 0.5
        if pulse < 0.3 then return end
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer4x4)
        -- Shrink the arc during warning (grows to full size)
        local progress = plat.blinkTimer / WARNING_BLINK_FRAMES
        local midAngle = (sRad + eRad) / 2
        local halfArc = (eRad - sRad) / 2 * progress
        sRad = midAngle - halfArc
        eRad = midAngle + halfArc
    elseif plat.state == "fading_in" then
        -- APPEARING: healing sweep - fills in with shimmer
        gfx.setColor(gfx.kColorBlack)
        -- Shimmer dither that gets more solid
        local shimmer = math.sin(plat.opacity * 20) * 0.15
        gfx.setDitherPattern(math.max(0, 1.0 - plat.opacity - shimmer), gfx.image.kDitherTypeBayer4x4)
    else
        gfx.setColor(gfx.kColorBlack)
    end

    -- Apply drop offset to radii
    local dInner = innerR + dropOffset
    local dOuter = outerR + dropOffset

    gfx.setLineWidth(2)
    local px, py
    for i = 0, steps do
        local t = sRad + (eRad - sRad) * (i/steps)
        local x, y = centerX + dOuter*math.cos(t), centerY + dOuter*math.sin(t)
        if px then gfx.drawLine(px, py, x, y) end
        px, py = x, y
    end
    px, py = nil, nil
    for i = 0, steps do
        local t = sRad + (eRad - sRad) * (i/steps)
        local x, y = centerX + dInner*math.cos(t), centerY + dInner*math.sin(t)
        if px then gfx.drawLine(px, py, x, y) end
        px, py = x, y
    end
    gfx.drawLine(centerX+dInner*math.cos(sRad), centerY+dInner*math.sin(sRad),
                  centerX+dOuter*math.cos(sRad), centerY+dOuter*math.sin(sRad))
    gfx.drawLine(centerX+dInner*math.cos(eRad), centerY+dInner*math.sin(eRad),
                  centerX+dOuter*math.cos(eRad), centerY+dOuter*math.sin(eRad))

    if plat.state == "solid" then
        gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(1)
        for i = 1, steps-1, 2 do
            local t = sRad + (eRad - sRad) * (i/steps)
            gfx.drawLine(centerX+dInner*math.cos(t), centerY+dInner*math.sin(t),
                          centerX+dOuter*math.cos(t), centerY+dOuter*math.sin(t))
        end
    elseif plat.state == "fading_in" then
        -- Healing sparkle marks
        gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(1)
        local numSparkles = math.floor(plat.opacity * 4)
        for i = 1, numSparkles do
            local t = sRad + (eRad - sRad) * (i / (numSparkles + 1))
            local mr = (dInner + dOuter) / 2
            local mx, my = centerX + mr*math.cos(t), centerY + mr*math.sin(t)
            gfx.drawLine(mx - 2, my, mx + 2, my)
            gfx.drawLine(mx, my - 2, mx, my + 2)
        end
    end
    gfx.setLineWidth(1)
end

function ObstacleManager:drawIncoming(centerX, centerY, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + obs.radius * math.cos(rad)
    local y = centerY + obs.radius * math.sin(rad)
    local scale = 0.3 + 0.7 * (obs.radius / obs.targetRadius)
    local ds = math.max(3, math.floor(obs.size * scale))

    -- Warning line
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
    gfx.setLineWidth(1)
    gfx.drawLine(x, y, centerX + obs.targetRadius*math.cos(rad), centerY + obs.targetRadius*math.sin(rad))

    gfx.setColor(gfx.kColorBlack)
    self:drawShape(x, y, obs.type, ds)

    -- Danger ring when close (enemies only)
    if obs.radius > obs.targetRadius * 0.6 and obs.type ~= "bubble" and obs.type ~= "ammo_crate" then
        if obs.blinkTimer % 8 < 4 then
            gfx.setColor(gfx.kColorBlack); gfx.drawCircleAtPoint(x, y, ds + 5)
        end
    end
end

function ObstacleManager:drawTrackObs(centerX, centerY, orbitRadius, obs)
    local rad = math.rad(obs.angle)
    local x = centerX + orbitRadius * math.cos(rad)
    local y = centerY + orbitRadius * math.sin(rad)

    -- Lifetime fade for enemies
    if obs.lifetime and obs.lifetime < OBSTACLE_FADE_FRAMES then
        local fa = obs.lifetime / OBSTACLE_FADE_FRAMES
        if obs.lifetime < OBSTACLE_FADE_FRAMES/2 and math.floor(obs.lifetime) % 4 < 2 then return end
        gfx.setColor(gfx.kColorBlack); gfx.setDitherPattern(1.0 - fa, gfx.image.kDitherTypeBayer4x4)
    else
        gfx.setColor(gfx.kColorBlack)
    end

    self:drawShape(x, y, obs.type, obs.size)

    -- Flying minion trail
    if obs.type == "minion_fly" and obs.orbiting then
        local td = obs.orbitSpeed > 0 and -1 or 1
        local tr = math.rad(obs.angle + td * 8)
        gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer4x4)
        self:drawShape(centerX + orbitRadius*math.cos(tr), centerY + orbitRadius*math.sin(tr),
                        "minion_fly", math.floor(obs.size * 0.6))
    end
end

function ObstacleManager:drawShape(x, y, obsType, size)
    gfx.setColor(gfx.kColorBlack)

    if obsType == "minion_stand" then
        -- Standing minion: round body, angry eyes, little legs
        gfx.fillCircleAtPoint(x, y, size)
        -- Eyes (angry slant)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x - 3, y - 2, 3)
        gfx.fillCircleAtPoint(x + 3, y - 2, 3)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x - 3, y - 1, 1.5)
        gfx.fillCircleAtPoint(x + 3, y - 1, 1.5)
        -- Angry eyebrows
        gfx.setLineWidth(1)
        gfx.drawLine(x - 5, y - 5, x - 1, y - 4)
        gfx.drawLine(x + 5, y - 5, x + 1, y - 4)
        -- Frown
        gfx.drawLine(x - 3, y + 3, x, y + 5)
        gfx.drawLine(x + 3, y + 3, x, y + 5)
        -- Little legs
        gfx.drawLine(x - 3, y + size, x - 4, y + size + 4)
        gfx.drawLine(x + 3, y + size, x + 4, y + size + 4)

    elseif obsType == "minion_fly" then
        -- Flying minion: triangular body, wings, angry face
        gfx.fillPolygon(x, y - size, x - size, y + size, x + size, y + size)
        -- Wings
        gfx.setLineWidth(2)
        gfx.drawLine(x - size, y, x - size - 5, y - 3)
        gfx.drawLine(x + size, y, x + size + 5, y - 3)
        gfx.setLineWidth(1)
        -- Face
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x - 2, y + 1, 2)
        gfx.fillCircleAtPoint(x + 2, y + 1, 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x - 2, y + 2, 1)
        gfx.fillCircleAtPoint(x + 2, y + 2, 1)

    elseif obsType == "bubble" then
        -- Bubble shield power-up
        gfx.setLineWidth(2)
        gfx.drawCircleAtPoint(x, y, size)
        gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer4x4)
        gfx.fillCircleAtPoint(x, y, size - 2)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x - size*0.3, y - size*0.3, math.max(1, math.floor(size*0.25)))
        gfx.setLineWidth(1)

    elseif obsType == "ammo_crate" then
        -- Ammo crate: small box, white center, clearly a pickup
        local s = size
        gfx.fillRect(x - s, y - s, s*2, s*2)
        -- White center with flame icon
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x - s + 2, y - s + 2, s*2 - 4, s*2 - 4)
        -- Small flame symbol
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x, y - 1, 2)
        gfx.fillCircleAtPoint(x, y + 1, 1)
    end
end

function ObstacleManager:drawBreakEffects()
    gfx.setColor(gfx.kColorBlack)
    for _, e in ipairs(self.breakEffects) do
        local alpha = e.life / 25
        if alpha > 0.3 then
            gfx.setDitherPattern(1.0 - alpha, gfx.image.kDitherTypeBayer4x4)
            local s = math.max(1, math.floor(e.size))
            gfx.fillCircleAtPoint(e.x, e.y, s)
        else
            gfx.fillRect(e.x, e.y, 1, 1)
        end
    end
end
