local Value = require("src.sys.army_value")
local Clashes = require("src.sys.battlefield_clashes")
local View = {}
View.__index = View

local function overlaps(a, b)
    return a.x < b.x + b.width and b.x < a.x + a.width
        and a.y < b.y + b.height and b.y < a.y + a.height
end

function View.new(armies, grid, settings)
    local font = love.graphics.newFont(settings.font, settings.size)
    font:setFilter("nearest", "nearest")
    local self = setmetatable({ armies = armies, settings = settings, font = font, labels = {} }, View)
    local ok, message = pcall(function()
        local bounds = {}
        for _, cell in ipairs(grid.cells) do
            local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
            for i = 1, #cell.vertices, 2 do
                x1, y1 = math.min(x1, cell.vertices[i]), math.min(y1, cell.vertices[i + 1])
                x2, y2 = math.max(x2, cell.vertices[i]), math.max(y2, cell.vertices[i + 1])
            end
            bounds[cell.id] = { x = x1, y = y1, width = x2 - x1, height = y2 - y1 }
        end
        for _, cell in ipairs(grid.cells) do
            local pair = armies.byCell[cell.id]
            if pair and cell.id ~= armies.jaclCellId then
                local a = settings.alliedPrefix .. Value.calculate(pair.allied, armies.catalogue, armies.rules)
                local e = (pair.routedBy and settings.routedLabel or settings.enemyPrefix .. Value.calculate(pair.enemy, armies.catalogue, armies.rules))
                local ew = font:getWidth(e)
                local width, height = ew + settings.sideGap + font:getWidth(a), font:getHeight()
                local b = bounds[cell.id]
                local label = { x = math.floor(cell.x - width / 2), width = width, height = height,
                    allied = a, enemy = e, alliedOffset = ew + settings.sideGap, cellId = cell.id, centerX = cell.x }
                local placed = false
                for position, y in ipairs({ math.ceil(b.y + b.height + settings.gap), math.floor(b.y - settings.gap - height) }) do
                    label.y = y
                    label.above = position == 2
                    -- Reserve both secondary labels even when hidden, keeping the rows stationary.
                    local clashPad = math.max(0, math.ceil((font:getWidth(settings.clashPrefix .. "9999") - ew) / 2))
                    local reserved = { x = label.x - clashPad, y = label.above and y - height - settings.protectionGap or y,
                        width = width + clashPad, height = height * 2 + settings.protectionGap }
                    local clear = reserved.x >= 0 and reserved.x + reserved.width <= grid.width
                        and reserved.y >= 0 and reserved.y + reserved.height <= grid.height
                    for _, obstacle in pairs(bounds) do if overlaps(reserved, obstacle) then clear = false end end
                    for _, previous in ipairs(self.labels) do if overlaps(reserved, previous.reserved) then clear = false end end
                    label.reserved = reserved
                    if clear then placed = true; break end
                end
                assert(placed, "No space above or below hex for army label: " .. cell.id)
                self.labels[#self.labels + 1] = label
            end
        end
    end)
    if not ok then font:release(); error(message, 0) end
    return self
end

local function secondaryLabel(self, label, text, center)
    local width, height = self.font:getWidth(text), self.font:getHeight()
    return { text = text, width = width, height = height, x = math.floor(center - width / 2),
        y = label.y + (label.above and -1 or 1) * (height + self.settings.protectionGap) }
end

function View:protectionLabel(label)
    local protection = self.armies.byCell[label.cellId].protection or 0
    if protection <= 0 then return nil end
    return secondaryLabel(self, label, self.settings.protectionPrefix .. protection,
        label.x + label.alliedOffset + self.font:getWidth(label.allied) / 2)
end

function View:clashLabel(label)
    local count = Clashes.count(self.armies.byCell[label.cellId])
    if count == 0 then return nil end
    local clash = secondaryLabel(self, label, self.settings.clashPrefix .. count,
        label.x + self.font:getWidth(label.enemy) / 2)
    local protection = self:protectionLabel(label)
    local right = (protection and protection.x or label.x + label.alliedOffset) - self.settings.protectionGap
    local width = math.min(clash.width, right - label.reserved.x)
    clash.scale = width / clash.width
    clash.width = width
    clash.x = math.max(label.reserved.x, math.min(clash.x, right - width))
    return clash
end

function View:draw(overrides)
    local g, settings = love.graphics, self.settings
    g.push("all")
    g.setFont(self.font)
    for _, label in ipairs(self.labels) do
        local pair = self.armies.byCell[label.cellId]
        local override = overrides and overrides[label.cellId]
        if label.revision ~= pair.revision or label.override ~= override then
            label.override = override
            label.enemy = (pair.routedBy and settings.routedLabel or settings.enemyPrefix .. Value.calculate(pair.enemy, self.armies.catalogue, self.armies.rules))
            label.allied = settings.alliedPrefix .. (override or Value.calculate(pair.allied, self.armies.catalogue, self.armies.rules))
            label.alliedOffset = self.font:getWidth(label.enemy) + settings.sideGap
            label.width = label.alliedOffset + self.font:getWidth(label.allied)
            label.x = math.floor(label.centerX - label.width / 2)
            label.revision = pair.revision
        end
        g.setColor(pair.routedBy and settings.routedColor or settings.enemyColor)
        g.print(label.enemy, label.x, label.y)
        local clash = self:clashLabel(label)
        if clash then g.print(clash.text, clash.x, clash.y, 0, clash.scale, 1) end
        g.setColor(settings.alliedColor)
        g.print(label.allied, label.x + label.alliedOffset, label.y)
        local protection = self:protectionLabel(label)
        if protection then g.print(protection.text, protection.x, protection.y) end
    end
    g.pop()
end

function View:release()
    if self.font then self.font:release(); self.font = nil end
end

return View
