local Outcome = require("src.sys.mission_outcome")
local Effects = {}
function Effects.jaclCell(session)
    return session.armies and session.armies.jaclCellId or require("data.jacl_location_rules").cellId
end
function Effects.check(session)
    if Outcome.finished(session) then return false end
    local deck = session.locationDecks and session.locationDecks.byCell[Effects.jaclCell(session)]
    if deck and #deck.drawPile == 0 then return Outcome.failure(session, "jacl_deck_exhausted") end
    return false
end
-- Deck commits notify their mission owner, including draws/mills by future effects.
-- Hunt deck clones retain this observer; it always queries the current session decks.
function Effects.bind(session)
    if not session.locationDecks then return end
    session.locationDecks.onChanged = function(cell)
        require("src.sys.location_card_effects").sync(session)
        if cell == Effects.jaclCell(session) then Effects.check(session) end
    end
    Effects.check(session)
end
return Effects
