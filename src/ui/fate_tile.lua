local View = require("data.talent_test_view")
local Tile = {}

-- Draw the centered contents inside the feedback controller's frame and reveal mask.
function Tile.draw(record, image, settings, font, color, alpha)
    local g = love.graphics
    local rows = {}
    local width = settings.tileWidth - 2 * settings.fateInset
    local function text(value)
        local scale = math.min(1, width / math.max(1, font:getWidth(value)))
        rows[#rows + 1] = { text = value, scale = scale, height = font:getHeight() * scale }
    end
    local fate = record and record.fate
    if fate and fate.name then text(fate.name) end
    if image then
        local scale = settings.fateIconSize / math.max(image:getDimensions())
        rows[#rows + 1] = { image = image, scale = scale, height = image:getHeight() * scale }
    elseif record and record.special then
        text(record.special == "auto_success" and "AUTO SUCCESS" or "AUTO FAILURE")
    end
    if record and ((fate and fate.value ~= nil) or (not fate and not record.special)) then
        text((record.modifier >= 0 and "+" or "") .. record.modifier)
    end
    if #rows == 0 then text("FATE") end

    local height = (#rows - 1) * settings.fateRowGap
    for _, row in ipairs(rows) do height = height + row.height end
    local y = -height / 2
    for _, row in ipairs(rows) do
        if row.image then
            g.setColor(1, 1, 1, alpha)
            g.draw(row.image, -row.image:getWidth() * row.scale / 2, y, 0, row.scale, row.scale)
        else
            g.setColor(color[1], color[2], color[3], alpha)
            g.print(row.text, -font:getWidth(row.text) * row.scale / 2, y, 0, row.scale, row.scale)
        end
        y = y + row.height + settings.fateRowGap
    end
end

function Tile.drawDetails(row, assets, fonts, detail, colors, quantityText)
    local g = love.graphics
    local x, y = math.floor(detail.x + detail.width / 2), detail.y + 62
    local image = row.fate and row.fate.img and assets:load(View.fateDirectory .. "/" .. row.id .. ".png")
    g.setColor(colors.row)
    g.rectangle("fill", x - View.tileWidth / 2, y - View.tileHeight / 2, View.tileWidth, View.tileHeight)
    g.setColor(colors.accent)
    g.rectangle("line", x - View.tileWidth / 2, y - View.tileHeight / 2, View.tileWidth, View.tileHeight)
    g.push()
    g.translate(x, y)
    g.setFont(fonts.heading)
    Tile.draw(row.fate and row or nil, image, View, fonts.heading, colors.text, 1)
    g.pop()
    local lines = { quantityText }
    if row.special then lines[#lines + 1] = row.special == "auto_success" and "AUTO SUCCESS" or "AUTO FAILURE" end
    if row.clash then
        lines[#lines + 1] = "CLASH POINTS PER REVEAL  " .. row.clash.amt
        lines[#lines + 1] = "ENEMY DAMAGE PER CLASH  +" .. row.clash.damage
        lines[#lines + 1] = "DIFFICULTY PER CLASH  +" .. row.clash.difficulty
    elseif not row.fate then
        lines[#lines + 1] = "TILE DETAILS UNAVAILABLE"
    end
    g.setFont(fonts.small)
    g.setColor(colors.text)
    for index, text in ipairs(lines) do
        g.printf(text, detail.x + 10, y + 52 + (index - 1) * 18, detail.width - 20, "center")
    end
    return y + 52 + #lines * 18
end

return Tile
