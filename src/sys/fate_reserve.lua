local R = {}
local Definition = require("src.sys.fate_tile_definition")
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k,v in pairs(value) do result[k] = copy(v) end; return result
end
function R.entries(pool) return pool and pool.reserve or {} end
function R.add(pool, tile, count, source)
    Definition.validate(tile, tile.id)
    assert(tile.bonus == true, "Reserve requires bonus tiles")
    assert(type(count) == "number" and count >= 0 and count % 1 == 0 and count < math.huge)
    pool.definitions[tile.id] = pool.definitions[tile.id] or copy(tile)
    pool.reserve = pool.reserve or {}
    for _ = 1, count do pool.reserve[#pool.reserve + 1] = { tileId = tile.id, sourceName = source or "BONUS" } end
end
function R.evaluate(pool, counts)
    if counts == nil then counts = {} end
    if type(counts) ~= "table" then return nil, "INVALID BONUS COMMITMENTS" end
    local available, selected, total = {}, {}, 0
    local cost = { dmg = 0, trm = 0 }
    for _, entry in ipairs(R.entries(pool)) do available[entry.tileId] = (available[entry.tileId] or 0) + 1 end
    for id, count in pairs(counts) do
        if type(count) ~= "number" or count < 0 or count % 1 ~= 0 or count > (available[id] or 0) then
            return nil, "BONUS TILES NO LONGER AVAILABLE"
        end
        if count > 0 then
            local tile = pool.definitions[id]
            if not tile or not tile.bonus then return nil, "INVALID BONUS TILE" end
            total = total + count * Definition.modifier(tile)
            local extra = tile.extra_cost
            if extra then
                cost.dmg = cost.dmg + count * (extra.dmg or 0)
                cost.trm = cost.trm + count * (extra.trm or 0)
            end
            selected[id] = count
        end
    end
    assert(math.abs(total) < math.huge, "Bonus total overflow")
    return { counts = selected, value = total, cost = cost }
end
function R.consume(pool, selection)
    local remaining, counts = {}, {}
    for id, n in pairs(selection.counts) do counts[id] = n end
    for _, entry in ipairs(R.entries(pool)) do
        if (counts[entry.tileId] or 0) > 0 then counts[entry.tileId] = counts[entry.tileId] - 1
        else remaining[#remaining + 1] = entry end
    end
    pool.reserve = remaining
end
function R.rows(pool)
    local rows, byId = {}, {}
    for _, entry in ipairs(R.entries(pool)) do
        local row = byId[entry.tileId]
        if not row then
            local tile = pool.definitions[entry.tileId]
            row = { id = entry.tileId, name = tile.name or entry.tileId, quantity = 0,
                modifier = Definition.modifier(tile), fate = Definition.display(tile), bonus = true,
                extraCost = tile.extra_cost }
            rows[#rows + 1], byId[entry.tileId] = row, row
        end
        row.quantity = row.quantity + 1
    end
    table.sort(rows, function(a,b) return a.id < b.id end)
    return rows
end
return R
