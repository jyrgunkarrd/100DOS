local Theme = require("data.preparation_theme")
local Settings = require("data.preparation_accents")
local Accents = {}
Accents.__index = Accents

function Accents.new(width, height)
    local self = setmetatable({ width = width, height = height, pulseTime = math.huge,
        diagnostics = {} }, Accents)
    for _, spec in ipairs({ { "heading", Theme.headingFont, Theme.headingSize },
        { "small", Theme.smallFont, Theme.smallSize } }) do
        local ok, font = pcall(love.graphics.newFont, spec[2], spec[3])
        if ok then
            font:setFilter("nearest", "nearest")
            self[spec[1]] = font
        else
            self.diagnostics[#self.diagnostics + 1] = "Cannot load accent font: " .. spec[2]
        end
    end
    return self
end

function Accents:pulse()
    self.pulseTime = 0
end

function Accents:update(dt)
    self.pulseTime = self.pulseTime + math.max(0, dt)
end

function Accents:pulseStrength()
    if not Settings.reroll.enabled or Settings.reroll.duration <= 0 then return 0 end
    return math.max(0, 1 - self.pulseTime / Settings.reroll.duration) ^ 2
end

function Accents:biomeLayout(biome)
    if not Settings.biome.enabled or not self.heading or not self.small then return nil end
    local label, name = "DEPLOYMENT ZONE", string.upper(biome.name or biome.id)
    local c = Settings.biome
    local width = math.max(self.heading:getWidth(name), self.small:getWidth(label)) + 2 * c.padding
    local height = self.heading:getHeight() + self.small:getHeight() + 5 + 2 * c.padding
    return { x = math.floor(self.width - c.margin - width), y = math.floor(self.height - c.margin - height),
        width = width, height = height, label = label, name = name }
end

function Accents:draw(biome)
    local g = love.graphics
    g.push("all")
    if Settings.seam.enabled then
        local strength = self:pulseStrength()
        local color = {}
        for i = 1, 3 do color[i] = Theme.seam[i] + (Theme.accent[i] - Theme.seam[i]) * strength end
        g.setColor(color[1], color[2], color[3], 1)
        local y = self.height / 2
        g.rectangle("fill", 0, y, self.width, 1)
        for x = Settings.seam.tickSpacing, self.width - 1, Settings.seam.tickSpacing do
            g.rectangle("fill", x, y - Settings.seam.tickHeight, 1, Settings.seam.tickHeight)
        end
    end
    local bounds = self:biomeLayout(biome)
    if bounds then
        local label, name = bounds.label, bounds.name
        local config = Settings.biome
        local width, height = bounds.width, bounds.height
        local x, y = bounds.x, bounds.y
        g.setColor(0, 0, 0, config.backingAlpha)
        g.rectangle("fill", x, y, width, height)
        g.setColor(Theme.accent)
        g.rectangle("fill", x, y + config.padding, 1, height - 2 * config.padding)
        g.setFont(self.small)
        g.setColor(Theme.deploymentLabel)
        g.print(label, x + config.padding, y + config.padding)
        g.setFont(self.heading)
        g.setColor(Theme.text)
        g.print(name, x + config.padding, y + config.padding + self.small:getHeight() + 5)
    end
    g.pop()
end

function Accents:release()
    for _, key in ipairs({ "heading", "small" }) do
        if self[key] then self[key]:release(); self[key] = nil end
    end
end

return Accents
