-- Presentation-only outward rings; the caller owns the clock and stable marker.
local Pulse = {}
function Pulse.validate(c)
    for _, key in ipairs({ "period", "duration", "lineWidth", "alpha" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid outline pulse " .. key)
    end
    assert(c.duration <= c.period and c.alpha <= 1, "Invalid outline pulse range")
end
function Pulse.pose(age, c, reduced)
    if reduced then return end
    local time = math.max(0, age) % c.period
    if time >= c.duration then return end
    local progress = time / c.duration
    return { progress = progress, alpha = c.alpha * (1 - progress) }
end
function Pulse.hexVertices(cell, expansion)
    local halfHeight = 0
    for i = 2, #cell.vertices, 2 do halfHeight = math.max(halfHeight, math.abs(cell.vertices[i] - cell.y)) end
    local scale, vertices = 1 + expansion / halfHeight, {}
    for i = 1, #cell.vertices, 2 do
        vertices[i] = math.floor(cell.x + (cell.vertices[i] - cell.x) * scale + 0.5)
        vertices[i + 1] = math.floor(cell.y + (cell.vertices[i + 1] - cell.y) * scale + 0.5)
    end
    return vertices
end
local function begin(c, tint, alpha)
    local g = love.graphics
    g.push("all"); g.setLineStyle("rough"); g.setLineWidth(c.lineWidth)
    g.setColor(tint[1], tint[2], tint[3], (tint[4] or 1) * alpha)
    return g
end
function Pulse.square(x, y, inner, outer, pose, c, tint)
    if not pose then return end
    -- Even sizes keep the expanding ring centered on the fixed square's pixel grid.
    local size = 2 * math.floor((inner + (outer - inner) * pose.progress) / 2 + 0.5)
    local g = begin(c, tint, pose.alpha)
    g.rectangle("line", math.floor(x - size / 2), math.floor(y - size / 2), size, size)
    g.pop()
end
function Pulse.hex(cell, spread, pose, c, tint)
    if not pose then return end
    local g = begin(c, tint, pose.alpha)
    g.polygon("line", Pulse.hexVertices(cell, spread * pose.progress)); g.pop()
end
return Pulse
