local Artwork = require("src.ui.layered_artwork")
local ArtworkResolver = require("src.sys.artwork_resolver")
local ArtworkAssets = require("src.sys.artwork_assets")
local Defaults = require("data.agent_roster_defaults")
local Entrance = require("data.preparation_entrance").agents
local Animation = require("src.ui.animation")
local Theme = require("data.preparation_theme")
local Accents = require("data.preparation_accents")
local Roster = {}
Roster.__index = Roster

function Roster.new(ids, catalog, partition, settings, biomeId)
    local config = {}
    for key, value in pairs(Defaults) do config[key] = value end
    for key, value in pairs(settings or {}) do config[key] = value end
    local paths = {}
    for _, id in ipairs(ids) do paths[id] = ArtworkResolver.resolve(assert(catalog.byId[id], "Unknown agent ID"), biomeId) end
    local self = setmetatable({ entries = {}, diagnostics = {}, partition = partition,
        config = config, dividers = {} }, Roster)
    self.artworkAssets = ArtworkAssets.new(self.diagnostics)
    local ok, font = pcall(love.graphics.newFont, config.fontPath, config.fontSize)
    if not ok then
        self.diagnostics[#self.diagnostics + 1] = "Cannot load roster font; using default font"
        font = love.graphics.newFont(config.fontSize)
    end
    self.font = font
    local smallOk, smallFont = pcall(love.graphics.newFont, Theme.smallFont, Theme.smallSize)
    if smallOk then
        self.smallFont = smallFont
        smallFont:setFilter("nearest", "nearest")
    else
        self.diagnostics[#self.diagnostics + 1] = "Cannot load agent slot font"
    end
    font:setFilter("nearest", "nearest")
    self.nameHeight = font:getHeight() * (1 + (config.nameLines - 1) * font:getLineHeight())
    self.width = #ids * config.portraitSize + math.max(0, #ids - 1) * config.gap
    self.height = config.portraitSize + config.nameGap + self.nameHeight
    self.x = partition.x + (partition.width - self.width) / 2
    self.y = math.floor(partition.y + (partition.height - self.height) / 2)
    if self.width > partition.width or self.height > partition.height then
        self.diagnostics[#self.diagnostics + 1] = "Agent roster exceeds available partition space"
    end
    for index, id in ipairs(ids) do
        assert(type(id) == "string" and id:match("^[%w_-]+$"), "Invalid agent image ID")
        local definition = assert(catalog.byId[id], "Unknown agent ID: " .. id)
        local entry = { id = id, name = definition.name or id,
            x = math.floor(self.x + (index - 1) * (config.portraitSize + config.gap) + 0.5) }
        entry.artwork = self.artworkAssets:prepare(paths[id])
        local path = "assets/images/agents/" .. id .. ".png"
        local loaded, image = pcall(love.graphics.newImage, path)
        if loaded then
            image:setFilter("nearest", "nearest")
            entry.image = image
            entry.scale = math.min(config.portraitSize / image:getWidth(),
                config.portraitSize / image:getHeight())
        else
            self.diagnostics[#self.diagnostics + 1] = "Cannot load " .. path .. ": " .. tostring(image)
        end
        local _, lines = font:getWrap(entry.name, config.portraitSize)
        if #lines > config.nameLines then
            self.diagnostics[#self.diagnostics + 1] = "Agent name exceeds reserved lines: " .. id
        end
        self.entries[#self.entries + 1] = entry
        if index < #ids then
            self.dividers[#self.dividers + 1] = math.floor(entry.x + config.portraitSize + config.gap / 2)
        end
    end
    return self
end

function Roster:entrancePose(index, time)
    local progress = Animation.progress(time or math.huge, (index - 1) * Entrance.stagger,
        Entrance.dropDuration)
    return {
        y = math.floor(Animation.lerp(self.partition.y - self.config.portraitSize, self.y,
            Animation.easeOutQuad(progress)) + 0.5),
        landed = progress >= 1,
    }
end

function Roster:draw(time, options)
    options = options or {}
    local alpha = options.alpha or 1
    local function color(value)
        love.graphics.setColor(value[1], value[2], value[3], (value[4] or 1) * alpha)
    end
    local g, c, p = love.graphics, self.config, self.partition
    g.push("all")
    g.intersectScissor(p.x, p.y, p.width, p.height)
    if not options.decorationsOnly then
        g.setColor(0, 0, 0, 1)
        g.rectangle("fill", p.x, p.y, p.width, p.height)
    end
    g.setFont(self.font)
    for index, entry in ipairs(self.entries) do
        local pose = self:entrancePose(index, time)
        if not options.decorationsOnly then
            Artwork.draw(entry.artwork, entry.x, pose.y, c.portraitSize, c.portraitSize, function()
                if entry.image then
                    g.setColor(1, 1, 1, 1)
                    local width, height = entry.image:getDimensions()
                    -- Snap after centering as well as animation: differently sized
                    -- artwork can introduce fractional offsets inside its portrait slot.
                    local drawX = math.floor(entry.x + (c.portraitSize - width * entry.scale) / 2 + 0.5)
                    local drawY = math.floor(pose.y + (c.portraitSize - height * entry.scale) / 2 + 0.5)
                    g.draw(entry.image, drawX, drawY, 0, entry.scale, entry.scale)
                else
                    g.setColor(0.12, 0.12, 0.12, 1)
                    g.rectangle("fill", entry.x, pose.y, c.portraitSize, c.portraitSize)
                end
            end)
        end
        if pose.landed then
            if Accents.landing.enabled then
                local age = (time or math.huge) - ((index - 1) * Entrance.stagger + Entrance.dropDuration)
                local glow = Accents.landing.duration > 0 and math.max(0, 1 - age / Accents.landing.duration) or 0
                local color = {}
                for i = 1, 3 do color[i] = Theme.muted[i] + (Theme.accent[i] - Theme.muted[i]) * glow end
                g.setColor(color[1], color[2], color[3], alpha)
                g.rectangle("fill", math.floor(entry.x + (c.portraitSize - Accents.landing.width) / 2),
                    self.y + c.portraitSize + Accents.landing.offset, Accents.landing.width, 1)
            end
            color(c.nameColor)
            g.printf(entry.name, entry.x, self.y + c.portraitSize + c.nameGap,
                c.portraitSize, "center")
        end
    end
    -- Markers stay above the slots, drawn after moving portraits for readability.
    if Accents.slots.enabled and self.smallFont then
        g.setFont(self.smallFont)
        color(Theme.muted)
        for index, entry in ipairs(self.entries) do
            g.print(string.format("%02d", index), entry.x, self.y - Accents.slots.abovePortrait)
        end
    end
    color(c.dividerColor)
    for _, x in ipairs(self.dividers) do
        g.rectangle("fill", x, self.y, 1, c.portraitSize)
    end
    g.pop()
end

function Roster:release()
    if self.artworkAssets then self.artworkAssets:release() end
    for _, entry in ipairs(self.entries) do
        if entry.image then entry.image:release(); entry.image = nil end
    end
    if self.font then self.font:release(); self.font = nil end
    if self.smallFont then self.smallFont:release(); self.smallFont = nil end
end

return Roster
