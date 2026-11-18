local Tile = {}
local utf8 = require("utf8")

function Tile.draw(entry, definition, image, font, c, x, y, width, hovered, alpha)
    local g, h = love.graphics, c.height
    alpha = alpha or 1
    local function tint(value)
        g.setColor(value[1], value[2], value[3], value[4] * alpha)
    end
    tint(hovered and c.hoverColor or c.frameColor)
    g.rectangle("fill", x, y, width, 1)
    g.rectangle("fill", x, y + h - 1, width, 1)
    g.rectangle("fill", x, y + 1, 1, h - 2)
    g.rectangle("fill", x + width - 1, y + 1, 1, h - 2)
    tint(c.backgroundColor)
    g.rectangle("fill", x + 1, y + 1, width - 2, h - 2)
    if image then
        local scale = math.min((h - 2) / image:getWidth(), (h - 2) / image:getHeight())
        g.setColor(1, 1, 1, alpha)
        g.draw(image, math.floor(x + (h - image:getWidth() * scale) / 2),
            math.floor(y + (h - image:getHeight() * scale) / 2), 0, scale, scale)
    else
        tint(c.textColor)
        g.printf("?", x + 1, y + math.floor((h - font:getHeight()) / 2), h - 2, "center")
    end
    tint(hovered and c.hoverColor or c.frameColor)
    g.rectangle("fill", x + h - 1, y + 1, 1, h - 2)
    if c.showCost ~= false then g.rectangle("fill", x + width - h, y + 1, 1, h - 2) end
    local name = definition.name:gsub("%s+", " ")
    local available = width - h - (c.showCost ~= false and h or 0) - 8
    if font:getWidth(name) > available then
        while #name > 0 and font:getWidth(name .. "...") > available do
            name = name:sub(1, utf8.offset(name, -1) - 1)
        end
        name = name .. "..."
    end
    tint(c.textColor)
    local textY = y + math.floor((h - font:getHeight()) / 2)
    g.print(name, x + h + 4, textY)
    if c.showCost == false then return end
    -- Clip unusually large costs to their box instead of drawing over the name.
    g.push("all")
    g.intersectScissor(x + width - h + 1, y + 1, h - 2, h - 2)
    g.printf(tostring(definition.cost), x + width - h + 1, textY, h - 2, "center")
    g.pop()
end
return Tile
