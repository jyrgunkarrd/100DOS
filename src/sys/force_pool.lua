local Pool = {}

function Pool.build(biome, captain, catalogue)
    local pools = {}
    for _, side in ipairs({ "allied", "enemy" }) do
        local pool, seen = { regular = {}, elite = {} }, {}
        for _, source in ipairs({ biome, captain }) do
            local entries = source[side .. "_forces"] or {}
            assert(type(entries) == "table", "Invalid force pool for " .. tostring(source.id))
            for key, id in pairs(entries) do
                assert(type(key) == "number" and key >= 1 and key <= #entries and key % 1 == 0,
                    "Force contributions must be an array: " .. tostring(source.id))
                local force = catalogue.byId[id]
                assert(force, "Unknown " .. side .. " force " .. tostring(id) .. " in " .. tostring(source.id))
                assert(force.faction == side, "Force faction mismatch: " .. id)
                assert(pool[force.strength], "Invalid force strength: " .. id)
                if not seen[id] then
                    seen[id] = true
                    table.insert(pool[force.strength], id)
                end
            end
        end
        table.sort(pool.regular)
        table.sort(pool.elite)
        pools[side] = pool
    end
    return pools
end

return Pool
