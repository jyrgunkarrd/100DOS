local Cost = {}

function Cost.stage(status, cost)
    local patch = {}
    if cost.dmg > 0 then
        if status.health <= cost.dmg then return nil, "NOT ENOUGH HEALTH FOR BONUS TILES" end
        patch.health = status.health - cost.dmg
    end
    if cost.trm > 0 then
        if status.defiance <= cost.trm then return nil, "NOT ENOUGH DEFIANCE FOR BONUS TILES" end
        patch.defiance = status.defiance - cost.trm
    end
    return patch
end

return Cost
