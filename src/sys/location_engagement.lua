local Engagement = {}
function Engagement.validate(rules)
    assert(type(rules) == "table" and type(rules.engageRevealerTypes) == "table", "Missing engagement type rules")
    for kind, enabled in pairs(rules.engageRevealerTypes) do
        assert(type(kind) == "string" and kind:match("%S") and type(enabled) == "boolean", "Invalid engagement type rule")
    end
end
function Engagement.prepare(session, cell, staged, agentId, rules)
    Engagement.validate(rules)
    assert(staged and staged.card, "Missing prepared reveal")
    local definition = assert(session.locationDecks.pool.byId[staged.card.cardId], "Unknown revealed card")
    if not rules.engageRevealerTypes[definition.card_type] or staged.card.exhausted then return end
    assert(session.agentStatus.byAgent[agentId] and session.agentDeployment.placements[agentId] == cell,
        "Engagement requires an agent at the revealed location")
    -- The staged pile shares instances with the live deck; copy before assigning runtime state.
    local card = {}
    for key, value in pairs(staged.card) do card[key] = value end
    card.engagedAgentId = agentId
    staged.card, staged.inPlay[card.instanceId] = card, card
end
function Engagement.target(card) return card and card.engagedAgentId end
function Engagement.clear(card) card.engagedAgentId = nil end
function Engagement.count(session, agentId)
    local count = 0
    for _, deck in pairs(session.locationDecks.byCell) do
        for _, card in pairs(deck.inPlay) do
            if card.engagedAgentId == agentId then count = count + 1 end
        end
    end
    return count
end
function Engagement.ordered(session, agentId)
    local result, cells = {}, {}
    if not session.locationDecks then return result end
    for cell in pairs(session.locationDecks.byCell) do cells[#cells + 1] = cell end
    table.sort(cells)
    for _, cell in ipairs(cells) do
        local deck = session.locationDecks.byCell[cell]
        for _, id in ipairs(deck.inPlayOrder) do
            local card = deck.inPlay[id]
            if card.engagedAgentId == agentId then result[#result + 1] = { card = card, cell = cell } end
        end
    end
    return result
end
function Engagement.clearTarget(session, agentId)
    if not session.locationDecks then return end
    for _, deck in pairs(session.locationDecks.byCell) do
        local changed = false
        for _, card in pairs(deck.inPlay) do
            if card.engagedAgentId == agentId then Engagement.clear(card); changed = true end
        end
        if changed then deck.revision = deck.revision + 1 end
    end
end
return Engagement
