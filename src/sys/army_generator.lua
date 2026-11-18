local Value = require("src.sys.army_value")
local Generator = {}

function Generator.generate(side, count, list, pool, catalogue, rules, random)
    local function draw(maximum)
        if random then return random:random(maximum) end
        return love.math.random(maximum)
    end
    local candidates = {}
    assert(#list.ids >= count, "Not enough distinct " .. side .. " army templates")
    for _, id in ipairs(list.ids) do
        local weights = rules.weights[side]
        local weight = id:match("^sup_") and weights.supreme or weights.normal
        assert(type(weight) == "number" and weight > 0 and weight < math.huge, "Invalid army selection weight")
        for _, slot in ipairs(list.byId[id]) do
            assert(#pool[slot.str] > 0, "No " .. side .. " " .. slot.str .. " forces for army " .. id)
        end
        candidates[#candidates + 1] = { id = id, weight = weight }
    end
    local selected = {}
    for i = 1, count do
        local total = 0
        for _, candidate in ipairs(candidates) do total = total + candidate.weight end
        local roll = (random and random:random() or love.math.random()) * total
        local chosen = #candidates
        for j, candidate in ipairs(candidates) do
            roll = roll - candidate.weight
            if roll < 0 then chosen = j; break end
        end
        selected[i] = table.remove(candidates, chosen).id
    end
    -- Placement order is independent of weighted selection order.
    for i = #selected, 2, -1 do local j = draw(i); selected[i], selected[j] = selected[j], selected[i] end
    local armies = {}
    for i, id in ipairs(selected) do
        local army = { id = side .. ":" .. i, templateId = id, side = side, forces = {} }
        for _, slot in ipairs(list.byId[id]) do
            for _ = 1, slot.qty do
                local units = pool[slot.str]
                army.forces[#army.forces + 1] = { id = army.id .. ":" .. (#army.forces + 1), forceId = units[draw(#units)] }
            end
        end
        army.value, army.counts = Value.calculate(army, catalogue, rules)
        armies[i] = army
    end
    return armies
end

-- A fresh one-army draw always considers the complete template list.
function Generator.one(side, list, pool, catalogue, rules, instanceId, random)
    local army = Generator.generate(side, 1, list, pool, catalogue, rules, random)[1]
    army.id = instanceId
    for i, unit in ipairs(army.forces) do unit.id = instanceId .. ":" .. i end
    return army
end
return Generator
