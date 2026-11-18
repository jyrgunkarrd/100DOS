local State = {}
function State.initialize(card, definition)
    if not require("src.sys.location_card_traits").enemy(definition) then return end
    assert(type(definition.health) == "number" and definition.health > 0
        and definition.health < math.huge and definition.health % 1 == 0, "Invalid enemy health")
    card.health, card.exhausted = definition.health, false
end
function State.engageAt(session, agentId)
    local cell = session.agentDeployment and session.agentDeployment.placements[agentId]
    local deck = session.locationDecks and session.locationDecks.byCell[cell]
    if not deck then return end
    local changed = false
    for _, card in pairs(deck.inPlay) do
        local definition = session.locationDecks.pool.byId[card.cardId]
        if require("src.sys.location_card_traits").enemy(definition) and not card.exhausted and not card.engagedAgentId then
            card.engagedAgentId, changed = agentId, true
        end
    end
    if changed then deck.revision = deck.revision + 1 end
end
function State.readyAll(session)
    if not session.locationDecks then return end
    for _, deck in pairs(session.locationDecks.byCell) do
        local changed = false
        for _, card in pairs(deck.inPlay) do
            if card.exhausted then card.exhausted, changed = false, true end
        end
        if changed then deck.revision = deck.revision + 1 end
    end
end
return State
