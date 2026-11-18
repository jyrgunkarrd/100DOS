-- Build pixels directly so graphics filtering, blending, and display scaling
-- cannot introduce colors into the exported palette.
local Export = {}

function Export.save(palette, layout, path, sourcePath)
    if path:lower() == sourcePath:lower() then
        return nil, "Choose an output path different from the source text file."
    end
    if not path:lower():match("%.png$") then return nil, "Output filename must end in .png." end
    local image = love.image.newImageData(layout.width, layout.height, "rgba8")
    local allowed, found = {}, {}
    for _, entry in ipairs(palette.entries) do
        allowed[entry.r * 65536 + entry.g * 256 + entry.b] = true
    end
    image:mapPixel(function(x, y)
        local column = math.floor(x / layout.swatchSize)
        local row = math.floor(y / layout.swatchSize)
        local index = math.min(row * layout.columns + column + 1, #palette.entries)
        local entry = palette.entries[index]
        return entry.r / 255, entry.g / 255, entry.b / 255, 1
    end)
    image:mapPixel(function(_, _, r, g, b, a)
        local key = math.floor(r * 255 + 0.5) * 65536
            + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
        assert(allowed[key] and a == 1, "Export contains an unexpected pixel.")
        found[key] = true
        return r, g, b, a
    end)
    for key in pairs(allowed) do assert(found[key], "Export is missing a palette color.") end
    local encoded = image:encode("png")
    image:release()
    local bytes = encoded:getString()
    encoded:release()
    -- Encode and validate before opening the destination, preserving existing
    -- files when palette generation fails.
    local file, message = io.open(path, "wb")
    if not file then return nil, "Cannot open output: " .. tostring(message) end
    local written, writeError = file:write(bytes)
    local closed, closeError = file:close()
    if not written or not closed then
        return nil, "Cannot save output: " .. tostring(writeError or closeError)
    end
    return true
end

return Export
