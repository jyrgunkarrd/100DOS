local Portraits = require("src.ui.force_portraits")
local ForcePreview = require("src.ui.force_preview")

local Preview = {}
Preview.__index = Preview

function Preview.new(session)
    return setmetatable({ session = session, portraits = Portraits.new(session), elapsed = 0 }, Preview)
end

function Preview:clear()
    self.elapsed, self.removedId, self.frozen = 0, nil, false
    if self.card then self.card:show(nil) end
end

function Preview:update(dt)
    if self.removedId and not self.frozen then self.elapsed = self.elapsed + math.max(0, dt) end
end

function Preview.waspOpacity(elapsed, hold, fade)
    local age = elapsed % (2 * (hold + fade))
    if age < hold + fade then return math.max(0, (age - hold) / fade) end
    return math.min(1, (2 * (hold + fade) - age) / fade)
end

local function hovered(panel, x, y, size)
    local px, py = panel.pointerX, panel.pointerY
    return px and py and px >= x and px < x + size and py >= y and py < y + size
end

function Preview:draw(panel, effect)
    if self.removedId ~= effect.removedId then
        self:clear()
        self.removedId = effect.removedId
    end
    local g, c = love.graphics, panel.settings
    local top = panel.y + c.engagementEffectTop
    local size, width = c.engagementEffectPortraitSize, panel.width / 2 - 14
    local split = panel.x + panel.width / 2
    local left, right = panel.x + 14, split
    local allied = math.floor(left + (width - size) / 2)
    local enemy = math.floor(right + (width - size) / 2)
    local portraitY = top + 13
    local statsY = portraitY + size + 2
    self.frozen = hovered(panel, allied, portraitY, size)
    local wasp = Preview.waspOpacity(self.elapsed, c.engagementEffectHold, c.engagementEffectFade)
    if self.frozen then wasp = wasp >= 0.5 and 1 or 0 end
    local elite = 1 - wasp

    local function label(text, x, y, color)
        g.setColor(color)
        g.printf(text, x, y, width, "center")
    end
    local function portrait(id, x, opacity, brightness)
        if opacity <= 0 then return end
        self.portraits:draw(id, x, portraitY, nil, { brightness, brightness, brightness, opacity })
    end

    label("ALLIED", left, top, c.muted)
    label("ENEMY / BEFORE FATE", right, top, c.muted)
    portrait(effect.removedForceId, allied, elite, 0.52)
    if elite > 0 then
        local inset = 38
        g.setColor(c.failure[1], c.failure[2], c.failure[3], elite)
        g.setLineWidth(3)
        g.line(allied + inset, portraitY + inset, allied + size - inset, portraitY + size - inset)
        g.line(allied + size - inset, portraitY + inset, allied + inset, portraitY + size - inset)
    end
    portrait(effect.addedForceId, allied, wasp, 1)
    portrait(effect.sourceForceId, enemy, 1, 1)
    label(string.format("STRENGTH %d > %d", effect.alliedBefore, effect.alliedAfter), left, statsY, c.text)
    label(string.format("STRENGTH %d > %d", effect.enemyBefore, effect.enemyAfter), right, statsY, c.text)
    label("+1 FORCE", right, statsY + 14, c.accent)

    local changes = {}
    if effect.protectionBefore ~= effect.protectionAfter then
        changes[#changes + 1] = string.format("PROTECTION %+d", effect.protectionAfter - effect.protectionBefore)
    end
    if effect.forceBonusBefore ~= effect.forceBonusAfter then
        changes[#changes + 1] = string.format("FORCE BONUS %+d", effect.forceBonusAfter - effect.forceBonusBefore)
    end
    if #changes > 0 then label(table.concat(changes, "   /   "), left, statsY + 14, c.failure) end

    local id
    if hovered(panel, enemy, portraitY, size) then
        id = effect.sourceForceId
    elseif self.frozen then
        id = wasp >= 0.5 and effect.addedForceId or effect.removedForceId
    end
    if id and not self.card then self.card = ForcePreview.new(self.session) end
    if self.card then self.card:show(id, panel) end
end

function Preview:release()
    self.portraits:release()
    if self.card then self.card:release() end
end

return Preview
