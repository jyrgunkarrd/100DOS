local Passives = {}

function Passives.battlefieldBonus(armies, cell, action)
    local pair = armies and armies.byCell[cell]
    if not pair or cell == armies.jaclCellId then return 0, {} end

    local tagCounts, passiveCounts, sources = {}, {}, {}
    for _, unit in ipairs(pair.allied.forces) do
        local definition = armies.catalogue.byId[unit.forceId]
        for _, tag in ipairs(definition.tags or {}) do
            tagCounts[tag] = (tagCounts[tag] or 0) + 1
        end
        for _, passive in ipairs(definition.passives or {}) do
            if passive.effect == "battlefield_test_bonus" and (not passive.action or passive.action == action) then
                if not passiveCounts[passive.id] then
                    assert(passive.stacking == "once_per_army" or passive.stacking == "per_force",
                        "Unsupported battlefield bonus stacking")
                    passiveCounts[passive.id] = 0
                    sources[#sources + 1] = passive
                end
                passiveCounts[passive.id] = passiveCounts[passive.id] + 1
            end
        end
    end

    local total, contributions = 0, {}
    for _, passive in ipairs(sources) do
        local count = passiveCounts[passive.id]
        local value = count * passive.bonus
        if passive.stacking == "once_per_army" then
            count = tagCounts[passive.count_tag] or 0
            value = math.floor(count / passive.per) * passive.bonus
        end
        if passive.maximum then value = math.min(passive.maximum, value) end
        if value > 0 then
            total = total + value
            contributions[#contributions + 1] = {
                id = passive.id, label = passive.label, count = count, value = value,
            }
        end
    end
    return total, contributions
end

function Passives.locationProtection(armies, cell)
    local pair = armies.byCell[cell]
    if not pair or cell == armies.jaclCellId then return 0, {} end

    local total, byId, contributions = 0, {}, {}
    for _, unit in ipairs(pair.allied.forces) do
        local definition = armies.catalogue.byId[unit.forceId]
        for _, passive in ipairs(definition.passives or {}) do
            if passive.effect == "location_protection_bonus" then
                local source = byId[passive.id]
                if not source then
                    assert(passive.stacking == "per_force", "Unsupported location protection stacking")
                    source = { id = passive.id, label = passive.label, value = 0 }
                    byId[passive.id] = source
                    contributions[#contributions + 1] = source
                end
                local added = math.min(passive.bonus, passive.maximum - source.value)
                source.value = source.value + added
                total = total + added
            end
        end
    end
    return total, contributions
end

return Passives
