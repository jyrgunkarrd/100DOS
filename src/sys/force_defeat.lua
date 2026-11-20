local Defeat = {}

-- Select all casualties from the original lineup before filling their positions.
function Defeat.resolve(forces, catalogue, side, damage, targetId)
    local removed, defeated, replacements, survivors = {}, {}, {}, {}
    for _, strength in ipairs({ "regular", "elite" }) do
        for _, unit in ipairs(forces) do
            if damage > 0 and (not targetId or unit.id == targetId)
                and catalogue.byId[unit.forceId].strength == strength then
                removed[#removed + 1] = unit
                defeated[unit.id] = true
                damage = damage - 1
            end
        end
    end
    for _, unit in ipairs(forces) do
        if not defeated[unit.id] then
            survivors[#survivors + 1] = unit
        else
            local rule = catalogue.byId[unit.forceId].on_defeat
            if rule then
                local target = assert(catalogue.byId[rule.replace_with], "Unknown on-defeat replacement for " .. unit.forceId)
                assert(target.faction == side, "Replacement force belongs to the wrong army")
                local replacement = { id = unit.id .. ":replacement", forceId = rule.replace_with }
                survivors[#survivors + 1] = replacement
                replacements[unit.id] = replacement.id
            end
        end
    end
    return survivors, removed, replacements
end

return Defeat
