local Pair = require("src.ui.health_defiance")
local Footprint = {}
function Footprint.portrait(image, x, y, size, alpha, font)
    local g = love.graphics
    g.setColor(1, 1, 1, alpha or 1)
    if image then
        local scale = math.min(size / image:getWidth(), size / image:getHeight())
        g.draw(image, math.floor(x + (size - image:getWidth() * scale) / 2),
            math.floor(y + (size - image:getHeight() * scale) / 2), 0, scale, scale)
    else g.setFont(font); g.printf("?", x, y + math.floor((size - font:getHeight()) / 2), size, "center") end
end
function Footprint.draw(row, asset, image, fonts, settings, ghost)
    local font = fonts.heading
    local g, x, y, width, height = love.graphics, row:bounds(asset.start, asset.size)
    local color = ghost and settings.validColor or row.settings.frameColor
    local alpha = ghost and settings.ghostAlpha or 1
    g.push("all")
    g.setColor(color[1], color[2], color[3], alpha); g.rectangle("fill", x, y, width, height)
    g.setColor(settings.backgroundColor[1], settings.backgroundColor[2], settings.backgroundColor[3], alpha)
    g.rectangle("fill", x + 1, y + 1, width - 2, height - 2)
    Footprint.portrait(image, x + math.floor((width - settings.portraitSize) / 2), y + 2, settings.portraitSize, alpha, font)
    if asset.exhausted then
        g.setColor(0, 0, 0, 0.65)
        g.rectangle("fill", x + 1, y + 1, width - 2, settings.portraitSize)
        g.setFont(fonts.small)
        g.setColor(1, 1, 1)
        g.printf("EXH", x, y + 2, width, "center")
    end
    if asset.health > 0 or asset.defiance > 0 then
        local Theme = require("data.preparation_theme")
        local function tint(c) return { c[1], c[2], c[3], alpha } end
        Pair.draw(font, asset.health, asset.defiance,
            math.floor(x + (width - Pair.width(font, asset.health, asset.defiance)) / 2), y + height - font:getHeight() - 2,
            { healthColor = tint(Theme.healthColor), defianceColor = tint(Theme.defianceColor), statSlashColor = tint(Theme.statSlashColor) })
    end
    g.pop()
end
return Footprint
