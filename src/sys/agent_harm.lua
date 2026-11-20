-- Resolve a single source of harm against the board present at impact.
-- The returned placements are detached snapshots used by the next hit and its animation.
local Harm = {}

local function distribute(amount, stat, agent, assets, random)
    local eligible = {}
    if agent[stat] > 0 then eligible[1] = agent end
    for _, asset in ipairs(assets) do
        if asset[stat] > 0 then eligible[#eligible + 1] = asset end
    end
    while amount > 0 and #eligible > 0 do
        if #eligible == 1 then
            local target = eligible[1]
            target[stat] = math.max(0, target[stat] - amount)
            break
        end
        local index = random and random:random(#eligible) or love.math.random(#eligible)
        local target = eligible[index]
        target[stat] = target[stat] - 1
        if target[stat] == 0 then table.remove(eligible, index) end
        amount = amount - 1
    end
end

function Harm.resolve(status, placements, damage, trauma, random)
    local agent = { health = status.health, defiance = status.defiance }
    local assets, survivors, hits = {}, {}, {}
    for i, placement in ipairs(placements or {}) do
        local copy = {}
        for key, value in pairs(placement) do copy[key] = value end
        assets[i] = copy
    end
    distribute(damage, "health", agent, assets, random)
    distribute(trauma, "defiance", agent, assets, random)
    for i, asset in ipairs(assets) do
        local before = placements[i]
        local lostHealth = before.health - asset.health
        local lostDefiance = before.defiance - asset.defiance
        local destroyed = (lostHealth > 0 and asset.health == 0) or (lostDefiance > 0 and asset.defiance == 0)
        if lostHealth > 0 or lostDefiance > 0 then
            hits[#hits + 1] = { asset = asset, damage = lostHealth, trauma = lostDefiance, destroyed = destroyed }
        end
        if not destroyed then survivors[#survivors + 1] = asset end
    end
    return agent, survivors, hits
end
return Harm
