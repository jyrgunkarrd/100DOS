local Placement = {}
local function overlaps(a, b)
    return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
end
function Placement.choose(width, height, panel, target, center, reserved, margin, gap)
    local left, right = margin, width - margin - panel.width
    local opposite = target.x + target.width / 2 < width / 2 and right or left
    local candidates = {}
    if center then candidates[#candidates + 1] = center - panel.width / 2 end
    candidates[#candidates + 1] = opposite
    candidates[#candidates + 1] = opposite == left and right or left
    candidates[#candidates + 1] = target.x + target.width + gap
    candidates[#candidates + 1] = target.x - panel.width - gap
    for _, x in ipairs(candidates) do
        local r = { x = math.floor(x), y = panel.y, width = panel.width, height = panel.height }
        local valid = r.x >= 0 and r.x + r.width <= width and r.y >= 0 and r.y + r.height <= height and not overlaps(r, target)
        for _, avoid in ipairs(reserved or {}) do if overlaps(r, avoid) then valid = false end end
        if valid then return r end
    end
    -- Suppress rather than cover the inspected portrait on unsupported tiny layouts.
end
return Placement
