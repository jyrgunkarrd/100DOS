local Artwork = require("src.ui.layered_artwork")
local ArtworkResolver = require("src.sys.artwork_resolver")
local ArtworkAssets = require("src.sys.artwork_assets")
local Animation = require("src.ui.animation")
local Portrait = {}
Portrait.__index = Portrait

function Portrait.new(agentIds, grid, width, settings, agents, biomeId)
    local c = settings
    assert(type(c) == "table" and type(c.directory) == "string" and c.size > 0,
        "Invalid action portrait settings")
    local left = math.ceil(grid.bounds.x + grid.bounds.width + c.boardGap)
    local available = width - c.rightMargin - left
    assert(available >= c.size and grid.height >= c.size, "Action portrait does not fit beside board")
    local self = setmetatable({ images = {}, known = {}, names = {}, diagnostics = {}, size = c.size,
        nameGap = c.nameGap, nameColor = c.nameColor,
        revealDuration = c.revealDuration, nameFadeDuration = c.nameFadeDuration,
        accents = c.accents,
        x = math.floor(left + (available - c.size) / 2 + 0.5),
        y = math.floor(grid.bounds.y + (grid.bounds.height - c.size) / 2 + 0.5) }, Portrait)
    self.artworkAssets = ArtworkAssets.new(self.diagnostics)
    self.artwork = {}
    local ok, failure = pcall(function()
        for _, id in ipairs(agentIds) do
            self.known[id] = true
            local definition = agents and agents.byId[id]
            self.names[id] = definition and type(definition.name) == "string" and definition.name or id
            self.artwork[id] = self.artworkAssets:prepare(ArtworkResolver.resolve(definition, biomeId))
            local path = c.directory .. "/" .. id .. ".png"
            local loaded, image = pcall(love.graphics.newImage, path)
            if loaded then
                self.images[id] = image
                image:setFilter("nearest", "nearest")
            else
                self.diagnostics[#self.diagnostics + 1] = "Cannot load selected agent portrait: " .. path
            end
        end
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Portrait:setPosition(x, y)
    self.x, self.y = math.floor(x + 0.5), math.floor(y + 0.5)
end

function Portrait:revealPose(elapsed)
    local time = elapsed or math.huge
    local progress = Animation.easeOutQuad(Animation.progress(time, 0, self.revealDuration))
    local height = math.floor(Animation.lerp(1, self.size, progress) + 0.5)
    return { y = math.floor(self.y + (self.size - height) / 2 + 0.5), height = height,
        nameAlpha = Animation.progress(time, math.max(0, self.revealDuration - self.nameFadeDuration), self.nameFadeDuration) }
end

function Portrait:draw(id, font, smallFont, elapsed, options)
    if not id or not self.known[id] then return end
    local g, image = love.graphics, self.images[id]
    g.push("all")
    local pose = self:revealPose(elapsed)
    g.push("all")
    g.intersectScissor(self.x, pose.y, self.size, pose.height)
    Artwork.draw(self.artwork[id], self.x, self.y, self.size, self.size, function()
        if image then
            local iw, ih = image:getDimensions()
            local scale = math.min(self.size / iw, self.size / ih)
            g.setColor(1, 1, 1, 1)
            g.draw(image, math.floor(self.x + (self.size - iw * scale) / 2 + 0.5),
                math.floor(self.y + (self.size - ih * scale) / 2 + 0.5), 0, scale, scale)
        else
            g.setColor(0.12, 0.12, 0.12, 1)
            g.rectangle("fill", self.x, self.y, self.size, self.size)
            g.setFont(font)
            g.setColor(0.82, 0.87, 0.85, 1)
            g.printf(id, self.x + 8, self.y + math.floor((self.size - font:getHeight()) / 2), self.size - 16, "center")
        end
    end)
    g.pop() -- Restore the caller's clipping before drawing name and stationary accents.
    g.setFont(font)
    g.setColor(self.nameColor[1], self.nameColor[2], self.nameColor[3], (self.nameColor[4] or 1) * pose.nameAlpha)
    g.printf(self.names[id], self.x, math.floor(self.y + self.size + self.nameGap + 0.5), self.size, "center")
    local c = self.accents
    if c then
        local left, top = self.x - c.gap - 1, self.y - c.gap - 1
        local right, bottom = self.x + self.size + c.gap, self.y + self.size + c.gap
        local length = c.bracketLength
        g.setColor(c.bracketColor[1], c.bracketColor[2], c.bracketColor[3], c.bracketAlpha)
        -- Filled one-pixel strips keep the corner brackets crisp on the canvas.
        for _, y in ipairs({ top, bottom }) do
            g.rectangle("fill", left, y, length, 1)
            g.rectangle("fill", right - length + 1, y, length, 1)
        end
        for _, x in ipairs({ left, right }) do
            g.rectangle("fill", x, top + 1, 1, length - 1)
            g.rectangle("fill", x, bottom - length + 1, 1, length - 1)
        end
        if not (options and options.hideLabel) then
        local labelFont = smallFont or font
        g.setFont(labelFont)
        g.setColor(c.labelColor)
        local labelX = math.floor(self.x + (self.size - labelFont:getWidth(c.label)) / 2 + 0.5)
        g.print(c.label, labelX, math.floor(top - c.labelGap - labelFont:getHeight()))
        end
    end
    g.pop()
end

function Portrait:release()
    if self.artworkAssets then self.artworkAssets:release() end
    self.artwork = {}
    for _, image in pairs(self.images) do image:release() end
    self.images = {}
end

return Portrait
