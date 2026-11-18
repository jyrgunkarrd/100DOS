local Layout = {}
-- Back-to-front order, stable within each rank; casualty order is independent.
function Layout.build(forces, dimensions, width, height, direction, settings)
    local ordered, maxW, maxH = {}, 0, 0
    for _, elite in ipairs({ false, true }) do
        for _, unit in ipairs(forces) do
            if unit.elite == elite then
                local w, h = dimensions(unit.forceId)
                ordered[#ordered + 1] = { unit = unit, width = w, height = h }
                maxW, maxH = math.max(maxW, w), math.max(maxH, h)
            end
        end
    end
    local gaps = math.max(1, #ordered - 1)
    local dx = math.min(settings.offsetX, math.max(0, width - maxW) / gaps)
    local dy = math.min(settings.offsetY, math.max(0, height - maxH) / gaps)
    local spreadX, spreadY = dx * math.max(0, #ordered - 1), dy * math.max(0, #ordered - 1)
    local byId = {}
    for i, slot in ipairs(ordered) do
        slot.x = (width - maxW - spreadX) / 2 + (direction == 1 and i - 1 or #ordered - i) * dx
        slot.y = (height - maxH - spreadY) / 2 + (i - 1) * dy
        byId[slot.unit.id] = slot
    end
    return ordered, byId
end
return Layout
