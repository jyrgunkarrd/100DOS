local Status = require("src.sys.agent_status")
local Attack = {}
function Attack.rating(value, label)
    if value == nil then return 0 end
    assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
        "Invalid attack " .. label)
    return value
end
function Attack.resolve(status, requests)
    local nextStatus, events = {}, {}
    for key, value in pairs(status) do nextStatus[key] = value end
    for _, request in ipairs(requests) do
        if Status.isDefeatedState(nextStatus) then break end
        local damage, trauma = Attack.rating(request.damage, "damage"), Attack.rating(request.trauma, "trauma")
        local beforeHealth, beforeDefiance = nextStatus.health, nextStatus.defiance
        assert(beforeHealth ~= nil and beforeDefiance ~= nil, "Missing attack target stats")
        Attack.rating(beforeHealth, "target Health"); Attack.rating(beforeDefiance, "target Defiance")
        nextStatus.health, nextStatus.defiance = math.max(0, beforeHealth - damage), math.max(0, beforeDefiance - trauma)
        if Status.isDefeatedState(nextStatus) then Status.defeat(nextStatus, request.instanceId) end
        events[#events + 1] = { instanceId = request.instanceId, cardId = request.cardId, cell = request.cell, name = request.name,
            damage = damage, trauma = trauma, beforeHealth = beforeHealth, beforeDefiance = beforeDefiance,
            health = nextStatus.health, defiance = nextStatus.defiance, defeated = nextStatus.defeated == true }
    end
    return nextStatus, events
end
return Attack
