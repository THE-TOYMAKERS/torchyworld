-- HUD module for Torchy's World
-- Displays score, speed, distance, and other game info

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
    self.crankHintTimer = 150 -- Show for first 5 seconds
end

function HUD:draw(score, highScore, gameSpeed, distance)
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

    -- Speed bar visualization
    local barWidth = 60
    local barX = SCREEN_W - barWidth - 8
    local barY = 26

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(barX - 2, barY, barWidth + 4, 8, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(barX - 2, barY, barWidth + 4, 8, 2)

    -- Fill based on speed (1.0 to 4.0 range)
    local fillWidth = math.min(barWidth, math.floor(barWidth * (gameSpeed - 1.0) / 3.0))
    if fillWidth > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(barX, barY + 2, fillWidth, 4)
    end

    -- Speed warning flash at high speeds
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

    -- ---- CRANK HINT (early game) ----
    if self.showCrankHint and self.crankHintTimer > 0 then
        self.crankHintTimer = self.crankHintTimer - 1
        if self.crankHintTimer <= 0 then
            self.showCrankHint = false
        end

        -- Draw crank icon at bottom right
        local crankX = SCREEN_W - 30
        local crankY = SCREEN_H - 30
        local alpha = math.min(1.0, self.crankHintTimer / 30) -- Fade out

        if alpha > 0.3 then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRoundRect(crankX - 18, crankY - 14, 36, 28, 4)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRoundRect(crankX - 18, crankY - 14, 36, 28, 4)

            -- Crank icon (simplified)
            gfx.setLineWidth(2)
            gfx.drawLine(crankX - 5, crankY - 5, crankX - 5, crankY + 5)
            gfx.drawLine(crankX - 5, crankY - 5, crankX + 8, crankY - 5)
            gfx.fillCircleAtPoint(crankX + 8, crankY - 5, 3)

            -- Rotation arrow
            gfx.setLineWidth(1)
            gfx.drawArc(crankX, crankY, 10, 200, 340)
            -- Arrow head
            local arrowAngle = math.rad(340)
            local ax = crankX + 10 * math.cos(arrowAngle)
            local ay = crankY + 10 * math.sin(arrowAngle)
            gfx.drawLine(ax, ay, ax - 3, ay - 4)
            gfx.drawLine(ax, ay, ax + 4, ay - 2)
        end
    end

    gfx.setLineWidth(1)
end
