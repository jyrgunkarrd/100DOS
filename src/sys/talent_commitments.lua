local Values = require("src.sys.talent_values")
local Commitments = {}
function Commitments.evaluate(session, agentId, talent, ids, bonusCounts)
    ids = ids or {}
    if type(ids) ~= "table" then return nil, "INVALID COMMITMENTS" end
    local cards, selected, bonus, count = session.agentCards, {}, 0, 0
    local handState = cards.byAgent[agentId]
    local base = Values.sum(assert(cards.agents.byId[agentId], "Missing Agent talents").talents or {}, talent)
    for key in pairs(ids) do
        count = count + 1
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #ids then return nil, "INVALID COMMITMENTS" end
    end
    if count ~= #ids then return nil, "INVALID COMMITMENTS" end
    for _, id in ipairs(ids) do
        if selected[id] then return nil, "CARD COMMITTED TWICE" end
        local found
        for _, entry in ipairs(handState.hand) do if entry.instanceId == id then found = entry; break end end
        if not found then return nil, "CARD NOT IN HAND" end
        local value = Values.sum(cards.definitions.byId[found.cardId].talents or {}, talent)
        if value <= 0 then return nil, "CARD HAS NO MATCHING TALENT" end
        selected[id], bonus = true, bonus + value
    end
    local reserve, reason = require("src.sys.fate_reserve").evaluate(session.fatePool, bonusCounts)
    if not reserve then return nil, reason end
    local cardBonus = bonus
    bonus = bonus + reserve.value
    assert(base + bonus < math.huge, "Talent total overflow")
    return { handState = handState, selected = selected, base = base, bonus = bonus, cardBonus = cardBonus, reserveBonus = reserve.value }
end
return Commitments
