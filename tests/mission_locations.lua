return function()
    local Locations = require("src.sys.mission_locations")
    local Recipe = require("src.sys.location_deck_recipe")
    local settings = require("data.jacl_location_rules")
    local board = require("data.deployment_board")
    local locations = require("data.locations.index").refresh()
    local catalogues = { jacls = require("data.jacls.index").refresh(),
        captains = require("data.captains.index").refresh() }
    local biomes = require("data.biomes.index").refresh()
    local cards = require("data.loc_cards.index").refresh()
    local Pool = require("src.sys.location_card_pool")
    local Decks = require("src.sys.location_decks")
    local function rejects(fn, expected)
        local ok, message = pcall(fn)
        assert(not ok and tostring(message):find(expected, 1, true), tostring(message))
    end
    for _, jaclId in ipairs(catalogues.jacls.ids) do
        for _, captainId in ipairs(catalogues.captains.ids) do
            for _, biomeId in ipairs(biomes.ids) do
                local selection = { jaclId = jaclId, captainId = captainId }
                local biome = biomes.byId[biomeId]
                local a, resolved = Locations.build(selection, catalogues, biome, locations,
                    board.cells, settings, love.math.newRandomGenerator(42))
                local b = Locations.build(selection, catalogues, biome, locations,
                    board.cells, settings, love.math.newRandomGenerator(42))
                assert(a.center == "loc_" .. jaclId and not locations.byId[a.center])
                local definition = resolved.byId[a.center]
                assert(definition.name == catalogues.jacls.byId[jaclId].name)
                assert(definition.captainId == captainId and definition.deck_size == 20)
                assert(#definition.card_pool == 1 and definition.card_pool[1] == "blast_door")
                local eligible, seen, count = {}, {}, 0
                for _, id in ipairs(biome.loc_pool) do eligible[id] = true end
                local surrounding = {}
                for cell, id in pairs(a) do
                    assert(b[cell] == id and not seen[id])
                    seen[id], count = true, count + 1
                    if cell ~= "center" then
                        assert(eligible[id]); surrounding[cell] = id
                    end
                end
                assert(count == 9)
                local pool = Pool.build(a, resolved, cards)
                local outerPool = Pool.build(surrounding, locations, cards)
                assert(#pool.ids == #outerPool.ids + 1 and pool.byId.blast_door and not outerPool.byId.blast_door)
                local decks = Decks.new(a, resolved, pool, love.math.newRandomGenerator(3))
                local summary = decks:summary("center")
                assert(summary.total == 20 and summary.byType.SYSTEM == 20 and not summary.byType.ENEMY and not summary.byType.BARRIER)
                local instances = {}
                for _, card in ipairs(decks.byCell.center.drawPile) do
                    assert(card.cardId == "blast_door" and not instances[card.instanceId])
                    instances[card.instanceId] = true
                end
                local milled = decks:prepareMill("center", 1)
                assert(#milled.entered == 0 and milled.cards[1].destination == "discardPile")
                assert(decks:commitMill("center", milled))
                assert(love.filesystem.getInfo(board.artwork.directory .. "/" .. a.center .. ".png"))
                definition.deck_build[1].qty = 999
                assert(catalogues.jacls.byId[jaclId].deck_build[1].qty == 10)
                assert(catalogues.captains.byId[captainId].deck_build[1].qty == 10)
            end
        end
    end
    local recipe, size = Recipe.combine({
        { label = "a", recipe = { { type = "E", qty = 2 }, { type = "E", qty = 3 } } },
        { label = "b", recipe = { { type = "E", qty = 1 }, { type = "ZERO", qty = 0 } } },
    })
    assert(size == 6 and #recipe == 2 and recipe[1].qty == 6 and recipe[2].qty == 0)
    for _, invalid in ipairs({ { { type = "E", qty = -1 } },
        { { type = "E", qty = 0.5 } }, { { type = "E", qty = math.huge } },
        { { type = "", qty = 1 } }, { [2] = { type = "E", qty = 1 } } }) do
        rejects(function() Recipe.validate(invalid, "bad") end, "bad:")
    end
    local selection = { jaclId = "val", captainId = "saber" }
    local noDraw = { random = function() error("Unexpected randomness") end }
    local function build(cells, defs, cats)
        return Locations.build(selection, cats or catalogues, { loc_pool = {} }, defs or locations,
            cells, settings, noDraw)
    end
    rejects(function() build({}) end, "target cell")
    rejects(function() build({ { id = "center" }, { id = "center" } }) end, "duplicate")
    rejects(function() build(board.cells, { byId = { loc_val = {} } }) end, "collides")
    rejects(function() build(board.cells, nil, { jacls = { byId = {} } }) end, "unknown JACL")
    local a, resolved = build({ { id = "center" } })
    assert(a.center == "loc_val" and next(a, "center") == nil)
    local ownPool = Pool.build(a, resolved, cards)
    assert(#Decks.new(a, resolved, ownPool).byCell.center.drawPile == 20)
    local emptyPool = { byId = {}, byType = {} }
    rejects(function() Decks.new(a, resolved, emptyPool, noDraw) end, "no eligible cards")
    local source = { id = "test", name = "Test", deck_size = 1,
        deck_build = { { type = "SYSTEM", qty = 1 } }, card_pool = { "blast_door", "blast_door" } }
    local cats = { jacls = { byId = { test = source } }, captains = { byId = { test = source } } }
    local function combined()
        return require("src.sys.jacl_location").build({ jaclId = "test", captainId = "test" }, cats, settings)
    end
    assert(#combined().card_pool == 1 and combined().deck_size == 2)
    source.deck_size = 2
    rejects(combined, "deck_size")
    source.deck_size = 1; source.card_pool = { [1] = "blast_door", [3] = "blast_door" }
    rejects(combined, "card_pool")
    source.card_pool = { "missing_system" }
    local loc = combined()
    rejects(function() Pool.build({ center = loc.id }, { byId = { [loc.id] = loc } }, cards) end, "unknown location card ID")
end
