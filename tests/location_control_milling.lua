return function(write)
    local Turn = require("src.sys.agent_turn")
    local Decks = require("src.sys.location_decks")
    local Feedback = require("src.ui.phase_end_feedback")
    local function fixture(allied, enemy, cell, role, size)
        cell, role, size = cell or "field", role or "BARRIER", size or 3
        local deck = { locationId = "test", locationName = "Test", drawPile = {}, discardPile = {},
            inPlay = {}, inPlayOrder = {}, revision = 0, types = { [role] = true } }
        for i = 1, size do deck.drawPile[i] = { instanceId = "card_" .. i, cardId = "test", health = 3 } end
        local pool = { byId = { test = { name = "Test", card_type = role, health = 3 } } }
        local function army(n)
            local forces = {}; for i = 1, n do forces[i] = { forceId = "regular" } end
            return { forces = forces, value = 999 } -- Must calculate strength, not trust a stale cached value.
        end
        local s = { agentDeployment = { placements = { a = cell, b = cell } },
            agentStatus = { byAgent = { a = { health = 5 }, b = { health = 5 } } },
            agentCards = { commitHand = function() end }, locationCardPool = pool,
            armies = { jaclCellId = "jacl", byCell = { [cell] = { allied = army(allied), enemy = army(enemy) } },
                catalogue = { byId = { regular = { strength = "regular" } } }, rules = { strength = { regular = 1 } } },
            locationDecks = setmetatable({ byCell = { [cell] = deck }, pool = pool }, Decks),
            missionHunt = { located = {}, revision = 0 } }
        return s, deck
    end
    local s, deck = fixture(1, 0)
    Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 2 and #deck.discardPile == 1 and deck.lastMilling.source == "control")
    assert(s.phaseFeedback and deck.lastMilling.actual == 1)
    Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 2, "Reentering an active turn must not mill again")
    Feedback.update(s, 5)
    s.activeAgentId = nil
    Turn.commitActivation(s, "b", {})
    assert(#deck.drawPile == 1, "Each Agent's new turn can trigger the mill")
    for _, values in ipairs({ { 0, 0 }, { 1, 1 }, { 3, 1 } }) do
        s, deck = fixture(values[1], values[2]); Turn.commitActivation(s, "a", {})
        assert(#deck.drawPile == 3 and not s.phaseFeedback and not deck.lastMilling)
    end
    s, deck = fixture(5, 0, "jacl"); Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 3 and not s.phaseFeedback, "JACL never receives control milling")
    s, deck = fixture(5, 0); Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 2, "High allied strength still mills only one card")
    s, deck = fixture(1, 0, "field", "CHAMPION")
    s.locationDecks.huntCells = { field = true }
    Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 2 and #deck.discardPile == 0 and deck.inPlay.card_3.engagedAgentId == "a")
    assert(s.missionHunt.located.card_3 == "field" and deck.lastMilling.cards[1].destination == "inPlay")
    assert(deck.lastMilling.concealed and deck.lastMilling.before == 0 and deck.lastMilling.after == 0)
    s, deck = fixture(1, 0, "field", "BARRIER", 0); Turn.commitActivation(s, "a", {})
    assert(#deck.drawPile == 0 and deck.lastMilling.actual == 0 and not s.missionOutcome)
    Feedback.update(s, 5); assert(not s.phaseFeedback)
    write("control_milling_results.txt", "PASS: turn-start control milling, strength conditions, JACL exclusion, once per activation, hunt entry and empty decks\n")
end
