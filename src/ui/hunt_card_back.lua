local Back = {}

-- Shared anonymous design; accepts portrait-sized bounds without scaling artwork.
function Back.draw(x, y, width, height, alpha, style)
    if alpha <= 0 then return end
    local g = love.graphics
    local sx, sy = width / 30, height / 42
    local insetX, insetY = math.floor(5 * sx), math.floor(5 * sy)
    local pointX, pointY = math.floor(8 * sx), math.floor(10 * sy)
    g.push("all"); g.setLineWidth(1); g.setLineStyle("rough")
    g.setColor(style.background[1], style.background[2], style.background[3], alpha)
    g.rectangle("fill", x, y, width, height)
    g.setColor(style.accent[1], style.accent[2], style.accent[3], alpha)
    g.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1)
    g.rectangle("line", x + insetX + 0.5, y + insetY + 0.5,
        width - insetX * 2 - 1, height - insetY * 2 - 1)
    g.line(x + pointX, y + height / 2, x + width / 2, y + pointY,
        x + width - pointX, y + height / 2, x + width / 2, y + height - pointY,
        x + pointX, y + height / 2)
    g.pop()
end

return Back
