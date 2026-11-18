local Layout = {}

function Layout.create(count, columns, swatchSize, maxPixels)
    local rows = math.ceil(count / columns)
    local width, height = columns * swatchSize, rows * swatchSize
    if width * height > maxPixels then
        return nil, "Image exceeds the 16-megapixel limit. Reduce columns or swatch size."
    end
    return { columns = columns, rows = rows, swatchSize = swatchSize,
        width = width, height = height, count = count }
end

-- Repeating the final entry fills a rectangular image using only palette colors.
function Layout.entryAt(layout, column, row)
    return math.min(row * layout.columns + column + 1, layout.count)
end

return Layout
