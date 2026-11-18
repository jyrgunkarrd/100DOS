local Definition = require("src.sys.fate_tile_definition")
local Draw = {}
function Draw.validate(pool)
    assert(pool and type(pool.entries) == "table" and #pool.entries > 0, "Empty fate pool")
    for _, entry in ipairs(pool.entries) do
        local tile = assert(pool.definitions[entry.tileId], "Unknown fate tile")
        Definition.validate(tile, entry.tileId)
        assert(not tile.bonus, "Bonus tile belongs in the bonus reserve")
    end
end
-- Sampling with replacement: each physical entry has equal probability.
function Draw.pick(pool, random)
    local index = random and random:random(#pool.entries) or love.math.random(#pool.entries)
    assert(type(index) == "number" and index % 1 == 0 and pool.entries[index], "Invalid fate draw")
    local entry = pool.entries[index]
    return entry.tileId, pool.definitions[entry.tileId], index
end
return Draw
