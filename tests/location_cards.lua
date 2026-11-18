return function()
    local Pool = require("src.sys.location_card_pool")
    local Decks = require("src.sys.location_decks")
    local cards = { byId = { enemy = { card_type = "ENEMY", health = 2 }, event = { card_type = "EVENT" },
        unused = { card_type = "ENEMY", health = 2 } } }
    local locations = { byId = {
        a = { card_pool = { "enemy", "enemy" }, deck_size = 3,
            deck_build = { { type = "ENEMY", qty = 2 }, { type = "EVENT", qty = 1 } } },
        b = { card_pool = { "event", "enemy" }, deck_size = 2,
            deck_build = { { type = "ENEMY", qty = 1 }, { type = "EVENT", qty = 1 } } },
        unused = { card_pool = { "unused" } },
    } }
    local assignments = { west = "a", east = "b", north = "a" }
    local pool = Pool.build(assignments, locations, cards)
    assert(#pool.ids == 2 and #pool.byType.ENEMY == 1 and not pool.byId.unused)
    local decks = Decks.new(assignments, locations, pool, love.math.newRandomGenerator(42))
    local same = Decks.new(assignments, locations, pool, love.math.newRandomGenerator(42))
    local seen = {}
    for cell, state in pairs(decks.byCell) do
        local counts = { enemy = 0, event = 0 }
        assert(#state.drawPile == locations.byId[state.locationId].deck_size)
        for i, card in ipairs(state.drawPile) do
            assert(not seen[card.instanceId]); seen[card.instanceId] = true
            counts[card.cardId] = counts[card.cardId] + 1
            assert(card.cardId == same.byCell[cell].drawPile[i].cardId)
            assert(card.instanceId == same.byCell[cell].drawPile[i].instanceId)
        end
        assert(counts.event == 1 and counts.enemy == (state.locationId == "a" and 2 or 1))
    end
    local drawn = decks:draw("west")
    drawn.health = 99
    assert(cards.byId.enemy.health == 2 and decks.byCell.north.drawPile[1].health ~= 99)
    assert(not decks:discard("east", drawn.instanceId))
    assert(decks:discard("west", drawn.instanceId) and not decks:discard("west", drawn.instanceId))
    assert(decks.byCell.west.discardPile[1] == drawn)
    decks:draw("west"); decks:draw("west")
    assert(not decks:draw("west") and #decks.byCell.west.discardPile == 1)
    local source = { locationCardPool = pool, locationDecks = decks }
    local Session = require("src.sys.mission_session")
    local session = Session.take(source)
    assert(session.locationDecks == decks and session.locationCardPool == pool and not source.locationDecks)
    Session.release(session)
    assert(not session.locationDecks and not session.locationCardPool)
    local function rejects(fn, text)
        local ok, message = pcall(fn)
        assert(not ok and tostring(message):find(text, 1, true), tostring(message))
    end
    locations.byId.a.card_pool = { "missing" }
    rejects(function() Pool.build(assignments, locations, cards) end, "a: unknown")
    locations.byId.a.card_pool = { "enemy" }
    local draws = 0
    local random = { random = function() draws = draws + 1; return 1 end }
    for _, recipe in ipairs({
        { { type = "ENEMY", qty = -1 } },
        { { type = "ENEMY", qty = 0.5 } },
        { { type = "MISSING", qty = 3 } },
        { { type = "ENEMY", qty = 2 } },
    }) do
        locations.byId.a.deck_build = recipe
        rejects(function() Decks.new(assignments, locations, pool, random) end, "a:")
    end
    assert(draws == 0, "Invalid recipes must fail before consuming randomness")
    locations.byId.a.deck_size = 0
    locations.byId.a.deck_build = {}
    assert(#Decks.new({ west = "a" }, locations, pool).byCell.west.drawPile == 0)
    local realLocations = require("data.locations.index").refresh()
    local realAssignments = {}
    for _, id in ipairs(realLocations.ids) do realAssignments[id] = id end
    local realPool = Pool.build(realAssignments, realLocations, require("data.loc_cards.index").refresh())
    local realDecks = Decks.new(realAssignments, realLocations, realPool)
    for cell, state in pairs(realDecks.byCell) do
        assert(#state.drawPile == realLocations.byId[cell].deck_size)
    end
end
