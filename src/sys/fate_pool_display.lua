local Fate = require("src.sys.fate_tile_definition")
local Display = {}
local sourceOrder = { agent = 1, captain = 2, jacl = 3, sabotage = 4, transport = 5 }

local function add(result, byId, definitions, id)
    local row = byId[id]
    if not row then
        local tile = definitions[id]
        row = { id = id, name = tile and tile.name or id, quantity = 0 }
        if tile then
            row.fate, row.modifier, row.special = Fate.display(tile), Fate.modifier(tile), tile.special
            if not tile.name and tile.value ~= nil then
                row.name = (row.modifier >= 0 and "+" or "") .. row.modifier
            end
            if tile.clash then
                row.clash = { amt = tile.clash.amt, damage = tile.clash.en_dmg or 0, difficulty = tile.clash.en_bonus or 0 }
            end
        end
        result.rows[#result.rows + 1], byId[id] = row, row
    end
    row.quantity = row.quantity + 1
    result.total = result.total + 1
    return row
end

local function sorted(result)
    table.sort(result.rows, function(a, b)
        local first, second = a.name:lower(), b.name:lower()
        if first == second then return a.id < b.id end
        return first < second
    end)
    return result
end

function Display.planned(ids, definitions)
    local result, byId = { rows = {}, total = 0 }, {}
    for _, id in ipairs(ids) do add(result, byId, definitions, id) end
    return sorted(result)
end

function Display.pool(pool, agentId)
    local result, byId, sources = { rows = {}, total = 0 }, {}, {}
    for _, entry in ipairs(pool.entries) do
        if not agentId or (entry.sourceType == "agent" and entry.sourceId == agentId) then
            local row = add(result, byId, pool.definitions, entry.tileId)
            if not agentId and sourceOrder[entry.sourceType] and entry.sourceId then
                local key = entry.sourceType .. ":" .. entry.sourceId
                sources[row.id] = sources[row.id] or {}
                row.contributors = row.contributors or {}
                local contributor = sources[row.id][key]
                if not contributor then
                    contributor = { kind = entry.sourceType, id = entry.sourceId,
                        name = entry.sourceName or entry.sourceId, quantity = 0 }
                    sources[row.id][key] = contributor
                    row.contributors[#row.contributors + 1] = contributor
                end
                contributor.quantity = contributor.quantity + 1
            end
        end
    end
    for _, row in ipairs(result.rows) do
        if row.contributors then
            table.sort(row.contributors, function(a, b)
                if a.kind ~= b.kind then return sourceOrder[a.kind] < sourceOrder[b.kind] end
                local first, second = a.name:lower(), b.name:lower()
                if first == second then return a.id < b.id end
                return first < second
            end)
        end
    end
    return sorted(result)
end

return Display
