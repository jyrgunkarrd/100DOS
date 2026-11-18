local Pool = {}

local function arrayLength(entries, label)
    assert(type(entries) == "table", label .. " must be an array")
    local count = 0
    for key in pairs(entries) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0,
            label .. " must be a dense array")
        count = count + 1
    end
    for i = 1, count do
        assert(entries[i] ~= nil, label .. " must be a dense array")
    end
    return count
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

-- Pure construction: no draws, shuffles, filesystem access, or input mutation.
-- tiles is a validated data.fate_tiles.index snapshot.
function Pool.build(selection, catalogues, tiles, settings)
    for _, key in ipairs({ "agents", "captain", "jacl", "total" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Fate pool: invalid " .. key .. " count")
    end
    assert(settings.agents + settings.captain + settings.jacl == settings.total,
        "Fate pool: contribution counts must sum to total")
    local result = { entries = {}, definitions = {} }
    local function contribute(kind, id, catalogue)
        local asset = type(id) == "string" and catalogue.byId[id]
        assert(asset, "Fate pool: unknown " .. kind .. " " .. tostring(id))
        local label = "Fate pool " .. kind .. " " .. id .. ": fate"
        local name = type(asset.name) == "table" and asset.name.text or asset.name
        if type(name) ~= "string" or not name:match("%S") then name = id end
        local count = arrayLength(asset.fate, label)
        for i = 1, count do
            local tileId = asset.fate[i]
            local definition = type(tileId) == "string" and tiles.byId[tileId]
            assert(definition, label .. "[" .. i .. "]: unknown tile " .. tostring(tileId))
            result.entries[#result.entries + 1] = {
                tileId = tileId, sourceType = kind, sourceId = id, sourceIndex = i, sourceName = name,
            }
            if not result.definitions[tileId] then result.definitions[tileId] = copy(definition) end
        end
        return count
    end
    local function check(kind, actual, expected)
        assert(actual == expected, "Fate pool: " .. kind .. " contributed " .. actual
            .. " tiles; expected " .. expected)
    end
    local seen, agentCount = {}, 0
    for i = 1, arrayLength(selection.agentIds, "Fate pool: agentIds") do
        local id = selection.agentIds[i]
        assert(type(id) == "string", "Fate pool: Agent ID must be a string")
        assert(not seen[id], "Fate pool: duplicate Agent " .. id)
        seen[id] = true
        agentCount = agentCount + contribute("agent", id, catalogues.agents)
    end
    check("Agents", agentCount, settings.agents)
    check("Captain", contribute("captain", selection.captainId, catalogues.captains), settings.captain)
    check("JACL", contribute("jacl", selection.jaclId, catalogues.jacls), settings.jacl)
    check("total", #result.entries, settings.total)
    result.reserve = {}
    local ordinary = {}
    for _, entry in ipairs(result.entries) do
        local target = result.definitions[entry.tileId].bonus and result.reserve or ordinary
        target[#target + 1] = entry
    end
    result.entries = ordinary
    return result
end

return Pool
