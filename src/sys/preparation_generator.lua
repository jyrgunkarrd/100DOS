local PoolResolver = require("src.sys.pool_resolver")
local Generator = {}

-- A supplied RandomGenerator makes selections reproducible without changing
-- the global random stream. Packages contain IDs, not mutable definitions.
function Generator.generate(pools, catalogs, random)
    assert(type(pools) == "table", "Preparation data must return a table")
    assert(type(pools.biome_pool) == "table"
        and pools.biome_pool.source == "biomes", "biome_pool must use source 'biomes'")
    assert(type(pools.jacl_pool) == "table"
        and pools.jacl_pool.source == "jacl", "jacl_pool must use source 'jacl'")
    -- Validate the complete package before consuming any random values.
    local biomeIds = PoolResolver.resolve(pools.biome_pool, catalogs)
    local jaclIds = PoolResolver.resolve(pools.jacl_pool, catalogs)
    assert(type(pools.captain_pool) == "table"
        and pools.captain_pool.source == "captains", "captain_pool must use source 'captains'")
    local captainIds = PoolResolver.resolve(pools.captain_pool, catalogs)
    assert(type(pools.agent_pool) == "table" and pools.agent_pool.source == "agents",
        "agent_pool must use source 'agents'")
    local candidates = PoolResolver.resolve(pools.agent_pool, catalogs)
    local count = pools.agent_pool.count
    assert(type(count) == "number" and count >= 1 and count < math.huge and count % 1 == 0,
        "agent_pool count must be a positive integer")
    assert(#candidates >= count, "agent_pool needs at least " .. count .. " unique IDs")
    random = random or love.math
    local function draw(maximum)
        if random == love.math then return random.random(maximum) end
        return random:random(maximum)
    end
    local function choose(ids)
        return ids[draw(#ids)]
    end
    local biomeId = choose(biomeIds)
    local jaclId = choose(jaclIds)
    local captainId = choose(captainIds)
    -- Partial Fisher-Yates shuffle of the resolver's copy, never the catalog.
    local agentIds = {}
    for i = 1, count do
        local j = i - 1 + draw(#candidates - i + 1)
        candidates[i], candidates[j] = candidates[j], candidates[i]
        agentIds[i] = candidates[i]
    end
    return { biomeId = biomeId, jaclId = jaclId, captainId = captainId, agentIds = agentIds }
end

return Generator
