local CardBack = require("src.ui.hunt_card_back")
local Track = {}
Track.__index = Track

function Track.new(settings)
    for _, key in ipairs({ "fontSize", "panelWidth", "panelHeight", "portraitSize", "padding",
        "portraitTop", "healthGap", "gap", "labelGap", "leftMargin", "crossInset", "crossWidth",
        "championTabWidth", "championTabHeight" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid target track " .. key)
    end
    assert(settings.fontSize > 0 and settings.portraitSize > 0 and settings.crossWidth > 0,
        "Invalid target track dimensions")
    assert(type(settings.eliminatedBrightness) == "number" and settings.eliminatedBrightness >= 0
        and settings.eliminatedBrightness <= 1, "Invalid target dimming")
    for _, key in ipairs({ "background", "healthColor", "slashColor", "championColor", "crossColor", "missingColor" }) do
        for i = 1, 4 do
            local value = settings[key] and settings[key][i]
            assert(type(value) == "number" and value >= 0 and value <= 1, "Invalid target track " .. key)
        end
    end
    local font = love.graphics.newFont(settings.font, settings.fontSize)
    font:setFilter("nearest", "nearest")
    return setmetatable({ settings = settings, font = font, images = {}, diagnostics = {}, reported = {} }, Track)
end

function Track:report(message)
    if self.reported[message] then return end
    self.reported[message] = true
    self.diagnostics[#self.diagnostics + 1] = message
    print("[Target track] " .. message)
end

function Track:load(entries)
    for _, entry in ipairs(entries) do
        if self.images[entry.cardId] == nil then
            local path = self.settings.directory .. "/" .. entry.cardId .. self.settings.suffix
            local ok, image = pcall(love.graphics.newImage, path)
            self.images[entry.cardId] = ok and image or false
            if ok then image:setFilter("nearest", "nearest")
            else self:report("Cannot load target portrait: " .. path) end
        end
    end
end

function Track:layout(entries, label)
    local c, panels, width, height = self.settings, {}, 0, 0
    for i, entry in ipairs(entries) do
        local image = self.images[entry.cardId]
        local iw, ih = c.portraitSize, c.portraitSize
        if image then iw, ih = image:getDimensions() end
        local text = (entry.health and tostring(math.max(0, entry.health)) or "--") .. "/" .. entry.maxHealth
        local w = math.max(c.panelWidth, iw + c.padding * 2, self.font:getWidth(text) + c.padding * 2)
        local h = math.max(c.panelHeight, c.portraitTop + ih + c.healthGap + self.font:getHeight() + c.padding)
        panels[i] = { width = w, height = h, portraitWidth = iw, portraitHeight = ih }
        width = width + w + (i > 1 and c.gap or 0)
        height = math.max(height, h)
    end
    local x = math.floor(label.x - c.labelGap - width)
    local y = math.floor(label.y + label.height - height)
    assert(#entries == 0 or (x >= c.leftMargin and y >= 0),
        "Target track does not fit beside deployment label at native portrait resolution")
    local nextX = x
    for _, panel in ipairs(panels) do
        panel.x, panel.y, panel.height = nextX, y, height
        panel.portraitX = nextX + math.floor((panel.width - panel.portraitWidth) / 2)
        panel.portraitY = y + c.portraitTop
        panel.healthY = panel.portraitY + panel.portraitHeight + c.healthGap
        nextX = nextX + panel.width + c.gap
    end
    return { x = x, y = y, width = width, height = height, panels = panels }
end

function Track:draw(entries, layout, treatment)
    local g, c = love.graphics, self.settings
    g.push("all")
    g.setFont(self.font); g.setLineStyle("rough"); g.setLineWidth(c.crossWidth)
    for i, entry in ipairs(entries) do
        local p, image = layout.panels[i], self.images[entry.cardId]
        local effect = treatment and treatment[i]
        local reveal = effect and effect.reveal or 1
        local function tint(color)
            g.setColor(color[1], color[2], color[3], color[4] * reveal)
        end
        g.setColor(c.background); g.rectangle("fill", p.x, p.y, p.width, p.height)
        if entry.champion then
            g.setColor(c.championColor)
            g.rectangle("fill", p.x, p.y, p.width, 1)
            g.rectangle("fill", p.x, p.y + p.height - 1, p.width, 1)
            g.rectangle("fill", p.x, p.y, 1, p.height)
            g.rectangle("fill", p.x + p.width - 1, p.y, 1, p.height)
            g.rectangle("fill", p.x + math.floor((p.width - c.championTabWidth) / 2),
                p.y + 3, c.championTabWidth, c.championTabHeight)
        end
        if effect and effect.backAlpha > 0 then
            CardBack.draw(p.portraitX, p.portraitY, p.portraitWidth, p.portraitHeight,
                effect.backAlpha, require("data.hunt_distribution_view"))
        end
        local brightness = entry.eliminated and c.eliminatedBrightness or 1
        if image then
            g.setColor(brightness, brightness, brightness, reveal)
            g.draw(image, p.portraitX, p.portraitY) -- Native pixels; never scale to fit.
        else
            tint(c.missingColor)
            g.printf("?", p.portraitX, p.portraitY + math.floor((p.portraitHeight - self.font:getHeight()) / 2),
                p.portraitWidth, "center")
        end
        if entry.eliminated then
            local inset = c.crossInset
            local x1, y1 = p.portraitX + inset, p.portraitY + inset
            local x2, y2 = p.portraitX + p.portraitWidth - inset - 1, p.portraitY + p.portraitHeight - inset - 1
            tint(c.crossColor); g.line(x1, y1, x2, y2); g.line(x1, y2, x2, y1)
        end
        local current, maximum = entry.health and tostring(math.max(0, entry.health)) or "--", tostring(entry.maxHealth)
        local text = current .. "/" .. maximum
        local tx = p.x + math.floor((p.width - self.font:getWidth(text)) / 2) + 1
        local ty = p.healthY + 1 -- Undead Pixel 8 visible-digit bearing compensation.
        tint(c.healthColor); g.print(current, tx, ty)
        tx = tx + self.font:getWidth(current)
        tint(c.slashColor); g.print("/", tx, ty)
        tint(c.healthColor); g.print(maximum, tx + self.font:getWidth("/"), ty)
        if effect and effect.highlight > 0 then
            local accent = require("data.hunt_distribution_view").accent
            g.push("all"); g.setLineWidth(1)
            g.setColor(accent[1], accent[2], accent[3], effect.highlight)
            g.rectangle("line", p.x - 1.5, p.y - 1.5, p.width + 3, p.height + 3)
            g.pop()
        end
    end
    g.pop()
end

function Track:release()
    if self.font then self.font:release(); self.font = nil end
    for _, image in pairs(self.images) do if image then image:release() end end
    self.images = {}
end

return Track
