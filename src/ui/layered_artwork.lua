local Artwork = {}

-- Center layers at native size. The composition grows to contain them.
-- Preserve the full image canvas, including transparent margins.
-- The caller supplies the subject draw so existing fitting/placeholders stay intact.
function Artwork.draw(layers, x, y, width, height, drawSubject, tint)
    local g = love.graphics
    g.push("all")
    local left, top, right, bottom = x, y, x + width, y + height
    for _, key in ipairs({ "background", "foreground" }) do
        local image = layers and layers[key]
        if image then
            local iw, ih = image:getDimensions()
            local ix, iy = math.floor(x + (width - iw) / 2), math.floor(y + (height - ih) / 2)
            left, top = math.min(left, ix), math.min(top, iy)
            right, bottom = math.max(right, ix + iw), math.max(bottom, iy + ih)
        end
    end
    local x1, y1 = g.transformPoint(left, top)
    local x2, y2 = g.transformPoint(right, bottom)
    g.intersectScissor(math.min(x1, x2), math.min(y1, y2), math.abs(x2 - x1), math.abs(y2 - y1))
    local function draw(image)
        if not image then return end
        local iw, ih = image:getDimensions()
        g.setColor(tint or { 1, 1, 1, 1 })
        g.draw(image, math.floor(x + (width - iw) / 2),
            math.floor(y + (height - ih) / 2))
    end
    draw(layers and layers.background)
    drawSubject()
    draw(layers and layers.foreground)
    g.pop()
end

return Artwork
