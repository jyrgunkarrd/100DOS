local Pool = require("src.sys.force_pool")
local Generator = require("src.sys.army_generator")
local Armies = {}

function Armies.build(assignments, jaclCellId, biome, captain, forces, lists, rules, random)
    local cells = {}
    for cellId in pairs(assignments) do
        if cellId ~= jaclCellId then cells[#cells + 1] = cellId end
    end
    table.sort(cells)
    local result = { templates = lists, reinforcementSerial = 0, byCell = {}, pools = Pool.build(biome, captain, forces), catalogue = forces, rules = rules }
    for _, side in ipairs({ "allied", "enemy" }) do
        local armies = Generator.generate(side, #cells, lists[side], result.pools[side], forces, rules, random)
        for i, cellId in ipairs(cells) do
            result.byCell[cellId] = result.byCell[cellId] or {}
            result.byCell[cellId][side] = armies[i]
        end
    end
    return result
end

return Armies
