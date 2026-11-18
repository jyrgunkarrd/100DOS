local Grid = {}
Grid.__index = Grid

local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end

-- The view owns a coordinate snapshot, never mutable configuration tables.
function Grid.new(settings, width, height)
    assert(type(settings.cells) == "table" and #settings.cells == 9,
        "Deployment board must define nine cells")
    for _, key in ipairs({ "radius", "gap", "padding", "lineWidth" }) do
        assert(finite(settings[key]) and settings[key] >= 0, "Invalid board " .. key)
    end
    assert(settings.radius > 0 and settings.lineWidth > 0, "Board radius and line width must be positive")
    local occupiedDimAlpha = settings.occupiedDimAlpha or 0
    assert(finite(occupiedDimAlpha) and occupiedDimAlpha >= 0 and occupiedDimAlpha <= 1,
        "Invalid board occupiedDimAlpha")
    local self = setmetatable({ cells = {}, width = width, height = height,
        occupiedDimAlpha = occupiedDimAlpha,
        lineWidth = settings.lineWidth, frameColor = {}, fillColor = {} }, Grid)
    for _, key in ipairs({ "frameColor", "fillColor" }) do
        assert(type(settings[key]) == "table", "Missing board " .. key)
        for i = 1, 4 do
            local value = settings[key][i] or (i == 4 and 1)
            assert(finite(value) and value >= 0 and value <= 1, "Invalid board " .. key)
            self[key][i] = value
        end
    end
    local ids, coordinates = {}, {}
    local spacing = settings.radius + settings.gap / math.sqrt(3)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, location in ipairs(settings.cells) do
        assert(type(location.id) == "string" and location.id ~= "" and not ids[location.id],
            "Board location IDs must be unique nonempty strings")
        assert(finite(location.q) and finite(location.r)
            and location.q % 1 == 0 and location.r % 1 == 0, "Board coordinates must be integers")
        local key = location.q .. ":" .. location.r
        assert(not coordinates[key], "Board locations cannot share coordinates")
        ids[location.id], coordinates[key] = true, true
        local x, y = 1.5 * spacing * location.q, math.sqrt(3) * spacing * (location.r + location.q / 2)
        self.cells[#self.cells + 1] = { id = location.id, q = location.q, r = location.r, x = x, y = y }
        minX, maxX = math.min(minX, x - settings.radius), math.max(maxX, x + settings.radius)
        minY, maxY = math.min(minY, y - settings.radius * math.sqrt(3) / 2),
            math.max(maxY, y + settings.radius * math.sqrt(3) / 2)
    end
    local padding = settings.padding + settings.lineWidth / 2
    assert(maxX - minX <= width - padding * 2 and maxY - minY <= height - padding * 2,
        "Deployment board does not fit its panel")
    self.bounds = {
        x = (width - (maxX - minX)) / 2 - settings.lineWidth / 2,
        y = (height - (maxY - minY)) / 2 - settings.lineWidth / 2,
        width = maxX - minX + settings.lineWidth,
        height = maxY - minY + settings.lineWidth,
    }
    for _, cell in ipairs(self.cells) do
        cell.x, cell.y = cell.x + (width - minX - maxX) / 2, cell.y + (height - minY - maxY) / 2
        cell.vertices = {}
        for corner = 0, 5 do
            local angle = corner * math.pi / 3
            cell.vertices[#cell.vertices + 1] = cell.x + settings.radius * math.cos(angle)
            cell.vertices[#cell.vertices + 1] = cell.y + settings.radius * math.sin(angle)
        end
    end
    return self
end

function Grid:hit(x, y)
    if x == nil or y == nil or x < 0 or y < 0 or x >= self.width or y >= self.height then return nil end
    for _, cell in ipairs(self.cells) do
        local inside = true
        local v = cell.vertices
        for i = 1, #v, 2 do
            local j = (i + 1) % #v + 1
            if (v[j] - v[i]) * (y - v[i + 1]) - (v[j + 1] - v[i + 1]) * (x - v[i]) < -0.000001 then
                inside = false
                break
            end
        end
        if inside then return cell end
    end
end

function Grid:draw(art, transition, placements)
    local g = love.graphics
    local occupied = {}
    for _, cellId in pairs(placements or {}) do occupied[cellId] = true end
    g.push("all")
    g.intersectScissor(0, 0, self.width, self.height)
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 0, 0, self.width, self.height)
    g.setLineWidth(self.lineWidth)
    g.setLineJoin("bevel")
    g.setLineStyle("rough")
    for _, cell in ipairs(transition and transition.order or self.cells) do
        local pose = transition and transition:cellPose(cell) or { visible = true, offsetY = 0 }
        if pose.visible then
            g.push()
            g.translate(0, pose.offsetY)
            g.setColor(self.fillColor)
            g.polygon("fill", cell.vertices)
            if art then art:draw(cell) end
            if occupied[cell.id] then
                g.setColor(0, 0, 0, self.occupiedDimAlpha)
                g.polygon("fill", cell.vertices)
            end
            g.setColor(self.frameColor)
            g.polygon("line", cell.vertices)
            g.pop()
        end
    end
    g.pop()
end

return Grid
