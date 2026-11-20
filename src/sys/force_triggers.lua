local Triggers = {}

local function whole(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

function Triggers.validate(definition, catalogue)
    local rules = definition.triggers
    if rules == nil then return end
    local label = "Force " .. definition.id .. " trigger: "
    assert(type(rules) == "table", label .. "expected an array")
    local count, events = 0, {}
    for index, rule in pairs(rules) do
        count = count + 1
        assert(whole(index) and index >= 1 and index <= #rules, label .. "expected a dense array")
        assert(type(rule) == "table" and (rule.event == "before_engage"
            or rule.event == "after_maneuver" or rule.event == "after_engage"),
            label .. "unsupported event")
        assert(not events[rule.event], label .. "duplicate event")
        if rule.event ~= "before_engage" then
            assert(whole(rule.amount) and rule.amount > 0, label .. "invalid effect amount")
        end
        if rule.event == "after_maneuver" then
            assert(whole(rule.minimum_margin), label .. "invalid minimum margin")
            assert(rule.effect == "army_damage" and rule.target == "random_destination_enemy_force",
                label .. "unsupported effect or target")
        elseif rule.event == "after_engage" then
            assert(definition.faction == "allied" and rule.effect == "grant_bonus_fate",
                label .. "unsupported engagement effect or faction")
            assert(type(rule.tile_id) == "string" and rule.tile_id:match("%S"), label .. "missing bonus tile ID")
        else
            assert(definition.faction == "enemy" and rule.effect == "remove_and_reinforce"
                and rule.stacking == "once_per_army", label .. "unsupported pre-engagement effect")
            assert(rule.target_strength == "elite" or rule.target_strength == "regular", label .. "invalid target strength")
            assert(type(rule.add_force) == "string" and rule.add_force:match("%S"), label .. "missing reinforcement ID")
            local added = catalogue.byId[rule.add_force]
            assert(added and added.faction == "enemy", label .. "reinforcement must be a known enemy force")
        end
        events[rule.event] = true
    end
    assert(count == #rules, label .. "expected a dense array")
end

function Triggers.beforeEngage(catalogue, pair)
    for _, unit in ipairs(pair.enemy.forces) do
        local definition = catalogue.byId[unit.forceId]
        for _, rule in ipairs(definition.triggers or {}) do
            if rule.event == "before_engage" then
                for _, target in ipairs(pair.allied.forces) do
                    if catalogue.byId[target.forceId].strength == rule.target_strength then
                        return definition, target, catalogue.byId[rule.add_force]
                    end
                end
            end
        end
    end
end

function Triggers.afterManeuver(definition, margin, enemies, random)
    if margin == nil or #enemies == 0 then return end
    for _, rule in ipairs(definition.triggers or {}) do
        if rule.event == "after_maneuver" and margin >= rule.minimum_margin then
            local index = random and random:random(#enemies) or love.math.random(#enemies)
            assert(whole(index) and enemies[index], "Invalid maneuver target draw")
            return enemies[index], rule.amount
        end
    end
end

function Triggers.afterEngage(catalogue, before, after)
    local awards, seen = {}, {}
    if before.enemy.value <= 0 or after.enemy.value ~= 0 then return awards end
    for _, unit in ipairs(before.allied.forces) do
        if not seen[unit.forceId] then
            seen[unit.forceId] = true
            local definition = catalogue.byId[unit.forceId]
            for _, rule in ipairs(definition.triggers or {}) do
                if rule.event == "after_engage" then
                    awards[#awards + 1] = { tileId = rule.tile_id, count = rule.amount, source = definition.name or definition.id }
                end
            end
        end
    end
    return awards
end

return Triggers
