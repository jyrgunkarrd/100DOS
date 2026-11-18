local Theme = require("data.preparation_theme")
local Pair = {}
function Pair.width(font, health, defiance)
    return font:getWidth(tostring(health) .. " / " .. tostring(defiance))
end
function Pair.draw(font, health, defiance, x, y, colors)
    colors = colors or Theme
    local g = love.graphics
    g.push("all")
    g.setFont(font)
    g.setColor(colors.healthColor); g.print(tostring(health), x, y)
    x = x + font:getWidth(tostring(health))
    g.setColor(colors.statSlashColor or Theme.statSlashColor); g.print(" / ", x, y)
    x = x + font:getWidth(" / ")
    g.setColor(colors.defianceColor); g.print(tostring(defiance), x, y)
    g.pop()
end
return Pair
