-- HUD module for Torchy's World
-- Displays score, speed, distance, ammo count, and other game info

local gfx <const> = playdate.graphics

class('HUD').extends()

local SCREEN_W <const> = 400
local SCREEN_H <const> = 240

function HUD:init()
    HUD.super.init(self)

    self.comboCount = 0
    self.comboTimer = 0
    self.speedWarning = false
    self.speedWarningTimer = 0

    -- Crank indicator
    self.showCrankHint = true
    self.crankHintTimer = 150

    -- Hit combo display
    self.hitComboText = ""
    self.hitComboTimer = 0
end

function HUD:showHitCombo(hits, totalScore)
    if hits > 0 then
        self.hitComboText = "+" .. (hits * 25)
        self.hitComboTimer = 45
    end
end

function HUD:draw(score, highScore, gameSpeed, distance, ammo, maxAmmo)
    local boldFont = gfx.getSystemFont(gfx.font.kVariantBold)
    local normalFont = gfx.getSystemFont()

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    -- ---- TOP LEFT: Score ----
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(2, 2, 90, 22, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    gfx.drawRoundRect(2, 2, 90, 22, 4)

    gfx.setFont(boldFont)
    gfx.drawText(tostring(score), 8, 5)

    -- ---- TOP RIGHT: Speed indicator ----
    local speedText = string.format("x%.1f", gameSpeed)
    local speedWidth = boldFont:getTextWidth(speedText) + 16

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(SCREEN_W - speedWidth - 4, 2, speedWidth, 22, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(SCREEN_W - speedWidth - 4, 2, speedWidth, 22, 4)

    gfx.setFont(boldFont)
    gfx.drawTextAligned(speedText, SCREEN_W - 12, 5, kTextAlignment.right)

    -- Speed bar
    local barWidth = 60
    local barX = SCREEN_W - barWidth - 8
    local barY = 26

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(barX - 2, barY, barWidth + 4, 8, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(barX - 2, barY, barWidth + 4, 8, 2)

    local fillWidth = math.min(barWidth, math.floor(barWidth * (gameSpeed - 1.0) / 3.0))
    if fillWidth > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(barX, barY + 2, fillWidth, 4)
    end

    -- Speed warning
    if gameSpeed > 3.0 then
        self.speedWarningTimer = self.speedWarningTimer + 1
        if self.speedWarningTimer % 20 < 10 then
            gfx.setFont(normalFont)
            gfx.drawTextAligned("MAX SPEED!", SCREEN_W - 40, 36, kTextAlignment.center)
        end
    end

    -- ---- BOTTOM LEFT: Distance ----
    local distStr = string.format("%.0fm", distance / 10)
    gfx.setFont(normalFont)

    gfx.setColor(gfx.kColorWhite)
    local distWidth = normalFont:getTextWidth(distStr) + 12
    gfx.fillRoundRect(2, SCREEN_H - 20, distWidth, 18, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(2, SCREEN_H - 20, distWidth, 18, 4)

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.drawText(distStr, 8, SCREEN_H - 18)

    -- ---- BOTTOM RIGHT: Ammo (fireball count) ----
    if ammo ~= nil then
        local ammoBarWidth = 50
        local ammoX = SCREEN_W - ammoBarWidth - 12
        local ammoY = SCREEN_H - 22

        -- Background
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(ammoX - 4, ammoY - 2, ammoBarWidth + 24, 20, 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(ammoX - 4, ammoY - 2, ammoBarWidth + 24, 20, 4)

        -- Flame icon
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(ammoX + 2, ammoY + 8, 4)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(ammoX + 2, ammoY + 6, 2)

        -- Ammo count text
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.setFont(boldFont)
        gfx.drawText(tostring(ammo), ammoX + 10, ammoY + 1)

        -- Ammo bar
        local ammoBarStartX = ammoX + 28
        local ammoBarW = 30
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(ammoBarStartX, ammoY + 3, ammoBarW, 10)

        local ammoFill = math.floor(ammoBarW * ammo / (maxAmmo or 20))
        if ammoFill > 0 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(ammoBarStartX + 1, ammoY + 4, ammoFill - 1, 8)
        end

        -- Low ammo warning
        if ammo <= 3 and ammo > 0 then
            self.speedWarningTimer = self.speedWarningTimer + 1
            if self.speedWarningTimer % 30 < 15 then
                gfx.setFont(normalFont)
                gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
                gfx.drawTextAligned("LOW AMMO!", SCREEN_W / 2, SCREEN_H - 36, kTextAlignment.center)
            end
        elseif ammo <= 0 then
            gfx.setFont(normalFont)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            gfx.drawTextAligned("NO AMMO! Collect stars!", SCREEN_W / 2, SCREEN_H - 36, kTextAlignment.center)
        end
    end

    -- ---- HIT COMBO DISPLAY ----
    if self.hitComboTimer > 0 then
        self.hitComboTimer = self.hitComboTimer - 1
        local comboAlpha = self.hitComboTimer / 45
        if comboAlpha > 0.3 then
            gfx.setFont(boldFont)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            local comboY = SCREEN_H / 2 - 40 - (45 - self.hitComboTimer)
            gfx.drawTextAligned(self.hitComboText, SCREEN_W / 2, comboY, kTextAlignment.center)
        end
    end

    -- ---- CRANK HINT (early game) ----
    if self.showCrankHint and self.crankHintTimer > 0 then
        self.crankHintTimer = self.crankHintTimer - 1
        if self.crankHintTimer <= 0 then
            self.showCrankHint = false
        end

        local crankX = SCREEN_W - 30
        local crankY = SCREEN_H - 50
        local alpha = math.min(1.0, self.crankHintTimer / 30)

        if alpha > 0.3 then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(crankX - 18, crankY - 14, 36, 28, 4)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(crankX - 18, crankY - 14, 36, 28, 4)

            gfx.setLineWidth(2)
            gfx.drawLine(crankX - 5, crankY - 5, crankX - 5, crankY + 5)
            gfx.drawLine(crankX - 5, crankY - 5, crankX + 8, crankY - 5)
            gfx.fillCircleAtPoint(crankX + 8, crankY - 5, 3)

            gfx.setLineWidth(1)
            gfx.drawArc(crankX, crankY, 10, 200, 340)
            local arrowAngle = math.rad(340)
            local ax = crankX + 10 * math.cos(arrowAngle)
            local ay = crankY + 10 * math.sin(arrowAngle)
            gfx.drawLine(ax, ay, ax - 3, ay - 4)
            gfx.drawLine(ax, ay, ax + 4, ay - 2)
        end
    end

    gfx.setLineWidth(1)
end
