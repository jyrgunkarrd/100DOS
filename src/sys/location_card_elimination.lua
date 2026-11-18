local Elimination = {}
function Elimination.commit(session, cell, instanceId, random)
    local deck = session.locationDecks.byCell[cell]
    local card = deck and deck.inPlay[instanceId]
    if not card or card.health ~= 0 then return false end
    if not session.locationDecks:discard(cell, instanceId) then return false end
    require("src.sys.mission_hunt").eliminated(session, cell, card, random)
    return true
end
return Elimination
