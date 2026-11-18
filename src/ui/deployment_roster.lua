local Defaults = require("data.deployment_roster_defaults")
local Roster = {}
Roster.__index = Roster

function Roster.new(agentIds, boardBounds, panelWidth, panelHeight, settings)
    local c = settings or Defaults
    assert(type(agentIds) == "table" and #agentIds == 6, "Deployment roster requires six agents")
    for _, key in ipairs({ "columns", "portraitSize", "gap", "boardGap" }) do
        local value = c[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid deployment roster " .. key)
    end
    assert(c.columns >= 1 and c.columns <= 6 and c.portraitSize > 0, "Invalid roster dimensions")
    assert(type(c.directory) == "string" and type(c.suffix) == "string", "Invalid mini portrait path")
    local rows = math.ceil(#agentIds / c.columns)
    local width = c.columns * c.portraitSize + (c.columns - 1) * c.gap
    local height = rows * c.portraitSize + (rows - 1) * c.gap
    local x = math.floor(boardBounds.x - c.boardGap - width)
    local y = math.floor(boardBounds.y + (boardBounds.height - height) / 2 + 0.5)
    assert(x >= 0 and y >= 0 and x + width <= panelWidth and y + height <= panelHeight,
        "Deployment roster does not fit beside the board")
    local self = setmetatable({ entries = {}, diagnostics = {}, x = x, y = y,
        width = width, height = height, size = c.portraitSize, gap = c.gap }, Roster)
    local ok, failure = pcall(function()
        for i, id in ipairs(agentIds) do
            assert(type(id) == "string" and id ~= "", "Invalid deployment agent ID")
            local entry = { id = id,
                x = x + ((i - 1) % c.columns) * (c.portraitSize + c.gap),
                y = y + math.floor((i - 1) / c.columns) * (c.portraitSize + c.gap) }
            self.entries[i] = entry
            local path = c.directory .. "/" .. id .. c.suffix
            local loaded, image = pcall(love.graphics.newImage, path)
            if loaded then
                entry.image = image
                image:setFilter("nearest", "nearest")
                local iw, ih = image:getDimensions()
                entry.scale = math.min(c.portraitSize / iw, c.portraitSize / ih)
                entry.drawX = entry.x + (c.portraitSize - iw * entry.scale) / 2
                entry.drawY = entry.y + (c.portraitSize - ih * entry.scale) / 2
            else
                self.diagnostics[#self.diagnostics + 1] = "Cannot load mini portrait for " .. id .. ": " .. path
            end
        end
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Roster:contains(x, y)
    return x ~= nil and y ~= nil and x >= self.x and y >= self.y
        and x < self.x + self.width and y < self.y + self.height
end

function Roster:hit(x, y)
    if not self:contains(x, y) then return nil end
    for _, entry in ipairs(self.entries) do
        if x >= entry.x and x < entry.x + self.size and y >= entry.y and y < entry.y + self.size then
            return entry
        end
    end
end

function Roster:drawPortrait(id, x, y, alpha, brightness)
    local g = love.graphics
    alpha = alpha or 1
    brightness = brightness or 1
    for _, entry in ipairs(self.entries) do
        if entry.id == id then
            if entry.image then
                g.setColor(brightness, brightness, brightness, alpha)
                g.draw(entry.image, math.floor(x + entry.drawX - entry.x + 0.5),
                    math.floor(y + entry.drawY - entry.y + 0.5), 0, entry.scale, entry.scale)
            else
                g.setColor(0.12 * brightness, 0.12 * brightness, 0.12 * brightness, alpha)
                g.rectangle("fill", x, y, self.size, self.size)
                g.setColor(0.34 * brightness, 0.39 * brightness, 0.39 * brightness, alpha)
                g.setLineWidth(1)
                local cx, cy = x + self.size / 2, y + self.size / 2
                g.line(cx - 6, cy - 6, cx + 6, cy + 6)
                g.line(cx - 6, cy + 6, cx + 6, cy - 6)
            end
            return
        end
    end
end

function Roster:draw(brightness)
    local g = love.graphics
    g.push("all")
    g.intersectScissor(self.x, self.y, self.width, self.height)
    for _, entry in ipairs(self.entries) do
        local level = brightness and brightness[entry.id] or 1
        if entry.image then
            g.setColor(level, level, level, 1)
            g.draw(entry.image, entry.drawX, entry.drawY, 0, entry.scale, entry.scale)
        else
            g.setColor(0.12 * level, 0.12 * level, 0.12 * level, 1)
            g.rectangle("fill", entry.x, entry.y, self.size, self.size)
            g.setColor(0.34 * level, 0.39 * level, 0.39 * level, 1)
            g.setLineWidth(1)
            local cx, cy = entry.x + self.size / 2, entry.y + self.size / 2
            local d = math.min(6, self.size / 4)
            g.line(cx - d, cy - d, cx + d, cy + d)
            g.line(cx - d, cy + d, cx + d, cy - d)
        end
    end
    g.pop()
end

function Roster:release()
    for _, entry in ipairs(self.entries) do
        if entry.image then entry.image:release(); entry.image = nil end
    end
end

return Roster
