local Generator = require("src.sys.deployment_generator")
local JaclLocation = require("src.sys.jacl_location")
local Locations = {}

-- Reserve the JACL cell before random placement; never mutate source catalogues.
function Locations.build(selection, catalogues, biome, locations, cells, settings, random)
    assert(type(settings.cellId) == "string", "JACL location requires a target cell")
    local available, seen = {}, {}
    for _, cell in ipairs(cells) do
        assert(type(cell.id) == "string" and not seen[cell.id], "Invalid or duplicate board cell ID")
        seen[cell.id] = true
        if cell.id ~= settings.cellId then available[#available + 1] = cell end
    end
    assert(seen[settings.cellId], "JACL location target cell does not exist: " .. settings.cellId)
    local jacl = JaclLocation.build(selection, catalogues, settings)
    assert(not locations.byId[jacl.id], "JACL location ID collides with location: " .. jacl.id)
    local assignments = Generator.generate(biome.loc_pool, locations, available, random)
    local resolved = { ids = {}, byId = {}, paths = {} }
    for id, definition in pairs(locations.byId) do
        resolved.byId[id] = definition
        resolved.ids[#resolved.ids + 1] = id
    end
    for id, path in pairs(locations.paths or {}) do resolved.paths[id] = path end
    resolved.byId[jacl.id] = jacl
    resolved.ids[#resolved.ids + 1] = jacl.id
    table.sort(resolved.ids)
    assignments[settings.cellId] = jacl.id
    return assignments, resolved
end

return Locations
