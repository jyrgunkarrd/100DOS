local Value = {}

function Value.calculate(army, catalogue, rules)
    local total, counts = 0, { regular = 0, elite = 0 }
    for _, unit in ipairs(army.forces) do
        local force = assert(catalogue.byId[unit.forceId], "Unknown army force: " .. tostring(unit.forceId))
        local strength = force.strength
        local value = rules.strength[strength]
        assert(type(value) == "number" and value >= 0 and value < math.huge, "Invalid force value")
        counts[strength] = counts[strength] + 1
        total = total + value
    end
    return total, counts
end

return Value
