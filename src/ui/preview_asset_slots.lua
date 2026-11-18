-- Read-only compact view of the existing Asset slot order.
local Slots = {}
function Slots.layout(entries, settings, font)
    local c = settings
    for _, key in ipairs({ "size", "gap", "portraitGap", "labelGap" }) do
        assert(type(c[key]) == "number" and c[key] >= 0 and c[key] % 1 == 0, "Invalid preview Asset slot " .. key)
    end
    assert(c.size >= 3 and type(c.label) == "string", "Invalid preview Asset slots")
    local rows = math.ceil(#entries / 2)
    local layout = { width = c.size * 2 + c.gap, entries = {} }
    local top = font:getHeight() + c.labelGap
    layout.height = top + rows * c.size + math.max(0, rows - 1) * c.gap
    for index, entry in ipairs(entries) do
        local row = math.floor((index - 1) / 2)
        local column = (index - 1) % 2
        -- Snake through rows so every consecutive footprint stays connected.
        -- Anchor an odd final slot beside the portrait, leaving the outer side blank.
        local startsRight = #entries % 2 == 1 and rows % 2 == 1
        if (row % 2 == 1) ~= startsRight then column = 1 - column end
        layout.entries[index] = { x = column * (c.size + c.gap),
            y = top + math.floor((index - 1) / 2) * (c.size + c.gap) }
    end
    return layout
end
function Slots.path(settings, cardId) return settings.directory .. "/" .. cardId .. settings.suffix end
function Slots.draw(view, entries, layout, x, y)
    local c, g, font = view.settings.assetSlots, love.graphics, view.fonts.small
    g.push("all"); g.setFont(font); g.setColor(c.textColor)
    g.print(c.label, x, y)
    for index, entry in ipairs(entries) do
        local position = layout.entries[index]
        local sx, sy = x + position.x, y + position.y
        g.setColor(c.frameColor); g.rectangle("fill", sx, sy, c.size, c.size)
        if not entry.cardId or entry.size == 1 then
            g.setColor(c.backgroundColor); g.rectangle("fill", sx + 1, sy + 1, c.size - 2, c.size - 2)
        end
    end
    -- Join touching cells belonging to the same Asset, without filling empty slots.
    g.setColor(c.frameColor)
    for i, entry in ipairs(entries) do
        if entry.cardId and entry.size > 1 then
            local a = layout.entries[i]
            for j = i + 1, #entries do
                local other, b = entries[j], layout.entries[j]
                if other.cardId == entry.cardId and other.start == entry.start then
                    if a.y == b.y and math.abs(a.x - b.x) == c.size + c.gap then
                        g.rectangle("fill", x + math.min(a.x, b.x) + c.size, y + a.y, c.gap, c.size)
                    elseif a.x == b.x and math.abs(a.y - b.y) == c.size + c.gap then
                        g.rectangle("fill", x + a.x, y + math.min(a.y, b.y) + c.size, c.size, c.gap)
                    end
                end
            end
        end
    end
    for index, entry in ipairs(entries) do
        if entry.cardId and not entry.continuation then
            local position = layout.entries[index]
            view:drawImage(Slots.path(c, entry.cardId), x + position.x + 1, y + position.y + 1, c.size - 2)
        end
    end
    g.pop()
end
return Slots
