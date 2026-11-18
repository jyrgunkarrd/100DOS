local Pair = require("src.ui.health_defiance")
local View = {}
View.__index = View
function View.new(settings, fonts)
    for _, key in ipairs({ "height", "gap", "resourceSize", "actionFontSize", "actionSpacing" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid agent status " .. key)
    end
    assert(settings.resourceSize >= 3 and settings.height >= settings.resourceSize and settings.actionFontSize > 0,
        "Invalid agent status dimensions")
    assert(type(settings.actionGlyph) == "string" and settings.actionGlyph ~= "", "Missing action glyph")
    assert(type(settings.spentActionGlyph) == "string" and settings.spentActionGlyph ~= "", "Missing spent action glyph")
    assert(settings.actionSpacing > 0, "Invalid action spacing")
    for _, key in ipairs({ "actionColor", "spentActionColor", "frameColor", "backgroundColor", "textColor" }) do
        assert(type(settings[key]) == "table", "Missing status " .. key)
        for i = 1, 4 do
            local v = settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid status " .. key)
        end
    end
    local actionFont = love.graphics.newFont(settings.actionFont, settings.actionFontSize)
    actionFont:setFilter("nearest", "nearest")
    return setmetatable({ settings = settings, fonts = fonts, actionFont = actionFont }, View)
end
function View:layout(portrait, status)
    local c = self.settings
    local bracket = portrait.accents and portrait.accents.gap + 1 or 0
    local y = portrait.y - bracket - c.gap - c.height
    local width = Pair.width(self.fonts.heading, status.health, status.defiance)
    local resourceWidth = math.max(c.resourceSize, self.fonts.small:getWidth(tostring(status.resources)) + 6)
    return { x = portrait.x, y = y,
        statsX = math.floor(portrait.x + (portrait.size - width) / 2),
        resourceX = portrait.x + portrait.size - resourceWidth, resourceWidth = resourceWidth }
end
function View:draw(portrait, status)
    local g, c, f = love.graphics, self.settings, self.fonts
    local p = self:layout(portrait, status)
    g.push("all")
    g.setFont(self.actionFont)
    for i = 1, status.actionPointCapacity do
        local available = i <= status.actionPoints
        local glyph = available and c.actionGlyph or c.spentActionGlyph
        g.setColor(available and c.actionColor or c.spentActionColor)
        g.print(glyph, p.x + (i - 1) * c.actionSpacing,
            p.y + math.floor((c.height - self.actionFont:getHeight()) / 2))
    end
    Pair.draw(f.heading, status.health, status.defiance, p.statsX,
        p.y + math.floor((c.height - f.heading:getHeight()) / 2))
    local boxY = p.y + math.floor((c.height - c.resourceSize) / 2)
    g.setColor(c.frameColor); g.rectangle("fill", p.resourceX, boxY, p.resourceWidth, c.resourceSize)
    g.setColor(c.backgroundColor); g.rectangle("fill", p.resourceX + 1, boxY + 1, p.resourceWidth - 2, c.resourceSize - 2)
    g.setFont(f.small); g.setColor(c.textColor)
    -- Undead Pixel 8's visible digits sit one pixel above and left of its
    -- centered advance box. Compensate while keeping the text pixel-aligned.
    g.printf(tostring(status.resources), p.resourceX + 1,
        boxY + math.floor((c.resourceSize - f.small:getHeight()) / 2) + 1, p.resourceWidth, "center")
    g.pop()
end
function View:release()
    if self.actionFont then self.actionFont:release(); self.actionFont = nil end
end
function View:drawProjection(portrait, status, cost, settings)
    local p, c, g = self:layout(portrait, status), self.settings, love.graphics
    local projected = status.resources - cost
    local font = self.fonts.small
    local width = math.max(p.resourceWidth, font:getWidth(tostring(projected)) + 6)
    local x = p.resourceX + p.resourceWidth - width
    local y = p.y + math.floor((c.height - c.resourceSize) / 2) - c.resourceSize - settings.resourceGap
    local color = projected < 0 and settings.invalidColor or settings.validColor
    g.push("all")
    g.setColor(color); g.rectangle("fill", x, y, width, c.resourceSize)
    g.setColor(c.backgroundColor); g.rectangle("fill", x + 1, y + 1, width - 2, c.resourceSize - 2)
    g.setFont(font); g.setColor(color)
    g.printf(tostring(projected), x + 1, y + math.floor((c.resourceSize - font:getHeight()) / 2) + 1, width, "center")
    local label = "-" .. tostring(cost)
    g.print(label, x - settings.resourceGap - font:getWidth(label), y + math.floor((c.resourceSize - font:getHeight()) / 2) + 1)
    g.pop()
end
return View
