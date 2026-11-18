local PoolResolver = {}

-- Resolve against catalogs supplied by their index modules, never asset folders.
function PoolResolver.resolve(pool, catalogs)
    assert(type(pool) == "table", "Preparation pool must be a table")
    local catalog = catalogs[pool.source]
    assert(catalog, "Unknown preparation pool source: " .. tostring(pool.source))
    local requested = pool.ids == "all" and catalog.ids or pool.ids
    assert(type(requested) == "table", "Pool ids must be 'all' or an array of IDs")
    local ids, seen = {}, {}
    for key in pairs(requested) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0
            and key <= #requested, "Pool ids must be a dense array")
    end
    for index = 1, #requested do
        local id = requested[index]
        assert(type(id) == "string" and catalog.byId[id],
            "Unknown " .. tostring(pool.source) .. " ID: " .. tostring(id))
        assert(not seen[id], "Duplicate pool ID: " .. id)
        seen[id] = true
        ids[#ids + 1] = id
    end
    assert(#ids > 0, "Preparation pool is empty: " .. tostring(pool.source))
    return ids
end

return PoolResolver
