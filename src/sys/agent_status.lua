local Status = {}
function Status.new(ids, agents, defaults)
    local result = { byAgent = {} }
    for _, id in ipairs(ids) do
        local definition = assert(agents.byId[id], "Unknown status agent: " .. id)
        local values = { health = definition.health, defiance = definition.defiance,
            resources = defaults.resources, actionPoints = defaults.actionPoints,
            actionPointCapacity = defaults.actionPoints, exhausted = false }
        for _, key in ipairs({ "health", "defiance", "resources", "actionPoints", "actionPointCapacity" }) do
            local value = values[key]
            assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
                "Invalid agent " .. id .. " " .. key)
        end
        if Status.isDefeatedState(values) then Status.defeat(values) end
        result.byAgent[id] = values
    end
    return result
end
function Status.isDefeatedState(state)
    return state and (state.defeated == true or state.health == 0 or state.defiance == 0) or false
end
function Status.isDefeated(model, id) return Status.isDefeatedState(model and model.byAgent[id]) end
function Status.defeat(state, attacker)
    state.defeated, state.exhausted, state.actionPoints = true, true, 0
    state.defeatCause = state.health == 0 and (state.defiance == 0 and "health_and_defiance" or "health") or "defiance"
    state.defeatedBy = attacker
end
function Status.allDefeated(model)
    if not model or not next(model.byAgent) then return false end
    for _, state in pairs(model.byAgent) do if not Status.isDefeatedState(state) then return false end end
    return true
end
function Status.isExhausted(model, id)
    return model and model.byAgent[id] and (model.byAgent[id].exhausted == true or Status.isDefeatedState(model.byAgent[id])) or false
end
function Status.exhaust(model, id)
    local state = model and model.byAgent[id]
    if not state or state.exhausted then return false end
    state.exhausted, state.actionPoints = true, 0
    return true
end
function Status.allExhausted(model)
    if not model or not next(model.byAgent) then return false end
    local survivors = 0
    for _, state in pairs(model.byAgent) do
        if not Status.isDefeatedState(state) then
            survivors = survivors + 1
            if not state.exhausted then return false end
        end
    end
    return survivors > 0
end
return Status
