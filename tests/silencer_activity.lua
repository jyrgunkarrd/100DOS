return function(write)
    local Activity = require("src.sys.silencer_activity")
    local Catalogue = require("src.sys.silencer_catalogue")
    local Decks = require("src.sys.location_decks")
    local Phase = require("src.sys.mission_phase")
    local Clock = require("src.sys.doom_clock")
    local Status = require("src.sys.agent_status")
    local View = require("src.ui.silencer_activity")
    local Effects = require("src.sys.mission_deck_effects")
    local catalogue = Catalogue.load(require("data.biomes.the_cut"))
    local function fixture(size)
        local pool = { ids = { "door" }, byId = { door = { id = "door", card_type = "BARRIER", name = "Door" } },
            byType = { BARRIER = { "door" } } }
        local decks = Decks.new({ center = "jacl" }, { byId = { jacl = { deck_size = size,
            deck_build = { { type = "BARRIER", qty = size } } } } }, pool)
        local session = { locationDecks = decks, locationCardPool = pool,
            doomClock = Clock.new(require("data.doom_clock_rules")), jaclSecurity = 0,
            fatePool = { entries = { { tileId = "autofail" } }, definitions = { autofail = require("data.fate_tiles.autofail") } },
            agentStatus = Status.new({ "a" }, { byId = { a = { health = 10, defiance = 10 } } }, require("data.agent_status_defaults")) }
        session.silencers = Activity.new(catalogue, pool)
        Effects.bind(session)
        return session
    end
    local function gloryCount(session)
        local n = 0
        for _, entry in ipairs(session.fatePool.entries) do
            if entry.tileId == "autofail" and not entry.transportEffect then n = n + 1 end
        end
        return n
    end
    local last = { random = function(_, n) return n end }
    local function setGlory(s, count)
        for i = 1, #s.doomClock.slots do s.doomClock.slots[i] = i <= count and "locked" or "cleared" end
    end
    local function boundary(s)
        Status.exhaust(s.agentStatus, "a")
        assert(Phase.begin(s))
        assert(not Phase.begin(s))
        for _ = 1, 5 do Phase.update(s, 10) end
        assert(not s.phaseTransition)
    end
    local s = fixture(80)
    setGlory(s, 2)
    -- Arrivals count actual Glory, not net milling after autosuccess relief.
    s.doomClock.successes[3] = true
    boundary(s)
    assert(#s.silencers.transports == 3 and #s.locationDecks.byCell.center.inPlayOrder == 0)
    assert(#s.locationDecks.byCell.center.drawPile == 79)
    s.doomClock.successes = {}; setGlory(s, 2)
    boundary(s)
    local deck = s.locationDecks.byCell.center
    assert(#s.silencers.transports == 0 and #deck.inPlayOrder == 3)
    assert(s.silencers.receipt.converted == 0 and s.silencers.receipt.milled == 0)
    for _, id in ipairs(deck.inPlayOrder) do assert(deck.inPlay[id].deployedPhase == 2 and deck.inPlay[id].health == 1) end
    -- Deterministic volley: three conversions at top, two kills, one unblocked mill.
    s.jaclSecurity = 2; setGlory(s, 2)
    Activity.resolve(s, last)
    local receipt = s.silencers.receipt
    assert(receipt.converted == 3 and receipt.blocked == 2 and receipt.damage == 2 and receipt.milled == 1)
    assert(s.jaclSecurity == 0 and #s.silencers.transports == 3)
    assert(gloryCount(s) == 2)
    local mill = s.locationDecks:prepareMill("center", 2)
    assert(#mill.entered == 2 and s.locationDecks:commitMill("center", mill))
    assert(gloryCount(s) == 4)
    local removed
    for _, id in ipairs(deck.inPlayOrder) do
        if deck.inPlay[id].cardId == "infected_intelligence" then removed = id; break end
    end
    assert(s.locationDecks:discard("center", removed) and gloryCount(s) == 3)
    require("src.sys.location_card_effects").sync(s)
    assert(gloryCount(s) == 3, "Glory contributions must not accumulate on repeated sync")
    -- Glory milling also reveals sabotage through the shared mill policy.
    local glory = fixture(20)
    glory.locationDecks.byCell.center.drawPile[20].cardId = "infected_intelligence"
    setGlory(glory, 1); boundary(glory)
    assert(#glory.locationDecks.byCell.center.inPlayOrder == 1 and gloryCount(glory) == 2)
    -- Last card still enters play and contributes its effect before mission failure.
    local empty = fixture(1)
    empty.locationDecks.byCell.center.drawPile[1].cardId = "infected_intelligence"
    setGlory(empty, 1); boundary(empty)
    assert(empty.missionOutcome.reason == "jacl_deck_exhausted" and gloryCount(empty) == 2)
    -- Conversions never grow the deck or replace existing sabotage.
    local allSab = fixture(8)
    for _, card in ipairs(allSab.locationDecks.byCell.center.drawPile) do card.cardId = "infected_intelligence" end
    local troop = { instanceId = "test_squad", cardId = "fools_meat", deployedPhase = 0, health = 1 }
    local d = allSab.locationDecks.byCell.center
    d.inPlay[troop.instanceId] = troop; d.inPlayOrder[1] = troop.instanceId
    Activity.resolve(allSab, last)
    assert(allSab.silencers.receipt.converted == 0 and #d.drawPile == 7)
    -- Lower vis_order draws later; equal values retain spawn order.
    local ordered = View.ordered({ { vis_order = 1, order = 3 }, { vis_order = 2, order = 2 }, { vis_order = 1, order = 1 } })
    assert(ordered[1].order == 2 and ordered[2].order == 1 and ordered[3].order == 3)
    local traits = require("src.sys.location_card_traits")
    assert(traits.enemy(catalogue.troops.fools_meat) and not traits.hunt(catalogue.troops.fools_meat))
    assert(require("src.sys.artwork_resolver").cardPath(catalogue.troops.fools_meat, "fools_meat", "assets/images/loc_cards") == "assets/images/silencers/fools_meat.png")
    -- Render actual assets at game resolution for visual inspection.
    local preview = require("src.ui.jacl_preview").new(require("data.jacls.mjolnir"), 1280, 720)
    preview:update(10)
    local view = View.new(s.silencers, preview)
    assert(#view.assets.diagnostics == 0)
    s.silencers.transports = {
        { id = "ripper", order = 1, vis_order = 2 }, { id = "whisper", order = 2, vis_order = 1 },
        { id = "ripper", order = 3, vis_order = 2 }, { id = "whisper", order = 4, vis_order = 1 },
        { id = "ripper", order = 5, vis_order = 2 }, { id = "whisper", order = 6, vis_order = 1 } }
    s.silencers.presentation = nil
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(0.08, 0.1, 0.14, 1)
    preview:draw(); view:draw()
    love.graphics.pop()
    local pixels = canvas:newImageData(); local png = pixels:encode("png")
    write("silencer_hover.png", png:getString())
    png:release(); pixels:release()
    for _, frame in ipairs({ { "arrival", "arrive", 0.25 }, { "drop", "deploy", 0.25 }, { "departure", "deploy", 0.6 } }) do
        s.silencers.presentation = { kind = frame[2], elapsed = frame[3], transports = s.silencers.transports }
        love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(0.08, 0.1, 0.14, 1)
        preview:draw(); view:draw(); love.graphics.pop()
        pixels = canvas:newImageData(); png = pixels:encode("png")
        write("silencer_" .. frame[1] .. ".png", png:getString()); png:release(); pixels:release()
    end
    canvas:release(); view:release(); preview:release()
    require("tests.transport_fate")(write, fixture, boundary, setGlory)
    local fresh = fixture(20)
    assert(#fresh.silencers.transports == 0 and fresh.silencers.serial == 0 and #fresh.fatePool.entries == 1)
    -- Real mission handoff, encounter artwork, Strike, sabotage interaction, and restart.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deploy = machine.current; deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, "center") end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local mission = machine.current; mission:update(2)
    local live = mission.session
    for _ = 1, 2 do
        setGlory(live, 0)
        for id in pairs(live.agentStatus.byAgent) do Status.exhaust(live.agentStatus, id) end
        assert(Phase.begin(live)); Phase.update(live, 3)
    end
    local onboard = live.locationDecks.byCell.center
    assert(#onboard.inPlayOrder == 1 and not live.phaseTransition)
    local squadId = onboard.inPlayOrder[1]
    local agentId = live.package.agentIds[1]
    mission.selectedId = agentId; assert(mission:beginAgentAction())
    local active = machine.current; active:update(2)
    assert(live.silencers and onboard.inPlay[squadId].engagedAgentId == agentId)
    assert(active.exploration.images[onboard.inPlay[squadId].cardId])
    live.fatePool = { entries = { { tileId = "autosuccess" } },
        definitions = { autosuccess = require("data.fate_tiles.autosuccess") } }
    local Resolution = require("src.sys.agent_action_resolution")
    local ok, result = Resolution.execute(live, agentId, "talent_test", { instanceId = squadId,
        testId = "strike", committedIds = {}, random = last })
    assert(ok and result.success and not onboard.inPlay[squadId])
    live.talentFeedback, live.attackFeedback = nil, nil
    live.agentStatus.byAgent[agentId].actionPoints = 3
    onboard.drawPile[#onboard.drawPile].cardId = "infected_intelligence"
    local reveal = live.locationDecks:prepareMill("center", 1)
    assert(live.locationDecks:commitMill("center", reveal))
    local sabotage = reveal.entered[1]
    assert(sabotage and #live.fatePool.entries == 2)
    ok, result = Resolution.execute(live, agentId, "talent_test", { instanceId = sabotage.instanceId,
        testId = "unlock", committedIds = {}, random = { random = function() return 1 end } })
    assert(ok and result.success and #live.fatePool.entries == 1 and not onboard.inPlay[sabotage.instanceId])
    machine:change("mission_preparation")
    assert(not active.session and not machine.current.silencers)
    machine.current:exit()
    write("silencer_results.txt", "PASS: wave timing, Glory count, Security volley, sabotage conversion/reveal/removal, exhaustion, artwork and layering\n")
end
