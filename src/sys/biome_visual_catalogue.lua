local Catalogue = {}

function Catalogue.refresh(biomeId, filesystem)
    local fs = filesystem or love.filesystem
    assert(type(biomeId) == "string" and biomeId:match("^[%w_-]+$"),
        "Biome visual ID must contain only letters, numbers, underscores or hyphens")
    local root = "assets/images/biomes/" .. biomeId
    local result = { layers = {}, diagnostics = {} }
    local info = fs.getInfo(root)
    if not info or info.type ~= "directory" then
        result.diagnostics[1] = "Missing biome image directory: " .. root
        return result
    end
    local entries, numbers = fs.getDirectoryItems(root), {}
    table.sort(entries)
    for _, file in ipairs(entries) do
        local path = root .. "/" .. file
        local fileInfo = fs.getInfo(path)
        if fileInfo and fileInfo.type == "file" then
            if file == "bg.png" then
                result.background = { path = path, key = "bg" }
            elseif file == "bg_doom.png" then
                result.doomBackground = { path = path, key = "bg" }
            else
                local digits = file:match("^(%d+)%.png$")
                if digits then
                    local number = tonumber(digits)
                    assert(not numbers[number], "Duplicate parallax layer number in " .. root)
                    numbers[number] = true
                    result.layers[#result.layers + 1] = {
                        path = path, number = number, key = tostring(number),
                    }
                end
            end
        end
    end
    table.sort(result.layers, function(a, b) return a.number > b.number end)
    if not result.background then
        result.diagnostics[#result.diagnostics + 1] = "No bg.png in " .. root .. "; using solid background"
    end
    if #result.layers == 0 then
        result.diagnostics[#result.diagnostics + 1] = "No numbered parallax layers in " .. root
    end
    return result
end

return Catalogue
