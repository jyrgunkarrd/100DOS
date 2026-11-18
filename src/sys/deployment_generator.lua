local Generator = {}

-- Validate before drawing; shuffle copies so definitions keep their ordering.
function Generator.generate(pool, catalogue, cells, random)
    assert(type(pool) == "table", "Biome loc_pool must be an array of location IDs")
    local ids, seen = {}, {}
    for key in pairs(pool) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #pool,
            "Biome loc_pool must be a dense array")
    end
    for i = 1, #pool do
        local id = pool[i]
        assert(type(id) == "string" and catalogue.byId[id], "Unknown location ID: " .. tostring(id))
        assert(not seen[id], "Duplicate location ID in loc_pool: " .. id)
        seen[id], ids[i] = true, id
    end
    local slots, slotIds = {}, {}
    for i, cell in ipairs(cells) do
        assert(type(cell.id) == "string" and not slotIds[cell.id], "Invalid or duplicate board cell ID")
        slotIds[cell.id], slots[i] = true, cell.id
    end
    local function shuffle(values)
        for i = #values, 2, -1 do
            local j = random and random:random(i) or love.math.random(i)
            values[i], values[j] = values[j], values[i]
        end
    end
    shuffle(ids)
    shuffle(slots)
    local assignments = {}
    for i = 1, math.min(#ids, #slots) do assignments[slots[i]] = ids[i] end
    return assignments
end

return Generator
