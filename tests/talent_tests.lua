return function(write)
    local Tests = require("src.sys.talent_tests")
    local Action = require("src.sys.talent_test_action")
    local Resolution = require("src.sys.agent_action_resolution")
    local Turn = require("src.sys.agent_turn")
    local Fate = require("src.sys.fate_draw")
    local function fixture()
        local agents = { byId = { a = { health = 10, defiance = 10,
            talents = { { type = "steel", qty = 2 }, { type = "fire", qty = 2 }, { type = "reason", qty = 2 } },
            card_deck = { { card_id = "boost", card_qty = 6 } } } } }
        local cards = require("src.sys.agent_cards").new({ "a" }, agents, { byId = {
            boost = { name = "Boost", cost = 9, talents = { { type = "fire", qty = 1 }, { type = "steel", qty = 1 }, { type = "reason", qty = 1 } } },
        } }, require("data.card_system_defaults"), love.math.newRandomGenerator(1))
        cards:commitHand("a", cards:prepareDrawTo("a", 3))
        local enemy = { name = "Enemy", card_type = "ENEMY", health = 2, damage = 1, trauma = 1,
            talent_tests = { { id = "strike", kind = "strike", val = 3 }, { id = "evade", kind = "evade", val = 3 } } }
        local barrier = { name = "Door", card_type = "BARRIER", talent_tests = { { id = "unlock", talent = "reason", val = 3 } } }
        local pool = { byId = { enemy = enemy, door = barrier }, byType = { ENEMY = { "enemy" }, BARRIER = { "door" } } }
        local decks = require("src.sys.location_decks").new({ west = "loc" }, { byId = { loc = { deck_size = 3,
            deck_build = { { type = "ENEMY", qty = 2 }, { type = "BARRIER", qty = 1 } } } } }, pool, love.math.newRandomGenerator(1))
        local deck = decks.byCell.west
        while decks:draw("west") do end
        local enemies, door = {}, nil
        for _, id in ipairs(deck.inPlayOrder) do
            local card = deck.inPlay[id]
            if card.cardId == "enemy" then enemies[#enemies + 1] = card else door = card end
        end
        local definitions = require("data.fate_tiles.index").refresh().byId
        local fate = { definitions = definitions, entries = { { tileId = "neutral" }, { tileId = "neg_one" },
            { tileId = "autofail" }, { tileId = "autosuccess" }, { tileId = "neutral" } } }
        local session = { activeAgentId = "a", agentCards = cards, locationDecks = decks, locationCardPool = pool,
            agentStatus = require("src.sys.agent_status").new({ "a" }, agents, require("data.agent_status_defaults")),
            agentDeployment = { placements = { a = "west" } }, fatePool = fate }
        session.doomClock = require("src.sys.doom_clock").new(require("data.doom_clock_rules"))
        return session, enemies, door
    end
    local function random(index)
        return { count = 0, random = function(self, maximum) self.count = self.count + 1; assert(index <= maximum); return index end }
    end
    local function args(card, id, rng, committed)
        return { instanceId = card.instanceId, testId = id, random = rng, committedIds = committed or {} }
    end
    local function clear(s) s.talentFeedback, s.attackFeedback = nil, nil end
    -- Systems grant their data-defined reward only on a successful interaction.
    for _, initial in ipairs({ 0, 2, 4 }) do
        local s, _, system = fixture()
        s.locationCardPool.byId.door = require("data.loc_cards.jacl_systems.blast_door")
        s.jaclSecurity = initial
        local ok, result = Resolution.execute(s, "a", "talent_test", args(system, "unlock", random(3)))
        assert(ok and not result.success and s.jaclSecurity == initial)
        assert(s.locationDecks.byCell.west.inPlay[system.instanceId] == system)
        clear(s)
        local plan = assert(Resolution.prepare(s, "a", "talent_test", args(system, "unlock", random(4))))
        ok, result = Resolution.commit(plan)
        assert(ok and result.success and s.jaclSecurity == 4 and result.security.gained == 4 - initial)
        assert(not s.locationDecks.byCell.west.inPlay[system.instanceId])
        assert(not Resolution.commit(plan) and s.jaclSecurity == 4)
    end
    do
        local s, _, system = fixture()
        s.locationCardPool.byId.door = require("data.loc_cards.jacl_systems.blast_door")
        s.jaclSecurity = 0
        local rng = random(4)
        local plan = assert(Resolution.prepare(s, "a", "talent_test", args(system, "force", rng)))
        s.jaclSecurity = 1
        assert(not Resolution.commit(plan) and rng.count == 0 and s.jaclSecurity == 1)
        s.locationCardPool.byId.door = { id = "bad_system", on_resolve = { security = -1 } }
        assert(not pcall(require("src.sys.location_card_effects").validate, s.locationCardPool.byId.door))
    end
    assert(Tests.calculate(2, 1, 3, { value = 0 }).success)
    assert(not Tests.calculate(2, 1, 3, { value = 1, negative = true }).success)
    assert(Tests.calculate(2, 1, 4, { value = 1 }).success)
    assert(not Tests.calculate(99, 99, 1, { value = 0, special = "auto_failure" }).success)
    assert(Tests.calculate(0, 0, 99, { value = 0, special = "auto_success" }).success)
    assert(Tests.resolve({ card_type = "ENEMY", talent_tests = { { id = "x", kind = "strike", talent = "reason", val = 2 } } })[1].talent == "reason")
    for _, entry in ipairs({ { id = "x", kind = "unknown", val = 2 }, { id = "x", talent = "unknown", val = 2 },
        { id = "x", talent = "fire", val = -1 } }) do
        assert(not pcall(Tests.resolve, { talent_tests = { entry } }))
    end
    assert(not pcall(Tests.resolve, { talent_tests = { { id = "x", talent = "fire", val = 1 }, { id = "x", talent = "fire", val = 1 } } }))

    local s, enemies, door = fixture()
    local status = s.agentStatus.byAgent.a
    enemies[1].engagedAgentId = "a"
    local hand = s.agentCards.byAgent.a.hand
    local rng = random(1)
    local request = args(enemies[1], "strike", rng, { hand[1].instanceId })
    local beforeAP, beforeResources = status.actionPoints, status.resources
    local plan = assert(Resolution.prepare(s, "a", "talent_test", request))
    assert(rng.count == 0 and #s.agentCards.byAgent.a.hand == 3 and enemies[1].health == 2)
    local ok, result = Resolution.commit(plan)
    assert(ok and result.success and result.total == 3 and rng.count == 1)
    assert(s.doomClock.slots[5] == "cleared" and s.doomClock.slots[4] == "pending")
    assert(enemies[1].health == 1 and enemies[2].health == 2 and s.locationCardPool.byId.enemy.health == 2)
    assert(status.actionPoints == beforeAP - 1 and status.resources == beforeResources and status.health == 10)
    assert(#s.agentCards.byAgent.a.hand == 2 and #s.agentCards.byAgent.a.discardPile == 1)
    local doomRevision = s.doomClock.revision
    assert(not Resolution.commit(plan) and rng.count == 1 and #s.fatePool.entries == 5)
    assert(s.doomClock.revision == doomRevision)
    assert(not Turn.finish(s, "a") and not Resolution.prepare(s, "a", "talent_test", request))
    clear(s)
    assert(Resolution.execute(s, "a", "talent_test", args(enemies[1], "strike", random(4))))
    assert(not s.locationDecks.byCell.west.inPlay[enemies[1].instanceId] and not enemies[1].engagedAgentId)
    clear(s)
    local before = #s.agentCards.byAgent.a.discardPile
    local staged = s.agentCards:prepareDraw("a", 1)
    s.agentCards:commitHand("a", staged)
    assert(#s.agentCards.byAgent.a.discardPile == before)

    s, enemies, door = fixture()
    status = s.agentStatus.byAgent.a
    enemies[1].engagedAgentId = "a"
    request = args(enemies[1], "evade", random(4))
    assert(Resolution.execute(s, "a", "talent_test", request))
    assert(enemies[1].exhausted and not enemies[1].engagedAgentId and status.health == 10 and not s.attackFeedback)
    clear(s)
    enemies[1].engagedAgentId = "a" -- Defensive check: exhausted attackers are ignored even with stale engagement.
    assert(#require("src.sys.opportunity_attacks").collect(s, "a", "explore") == 0)
    enemies[1].engagedAgentId = nil
    assert(Turn.finish(s, "a")); assert(Turn.refreshAll(s)); assert(not enemies[1].exhausted)
    assert(not enemies[1].engagedAgentId)
    Turn.commitActivation(s, "a", Turn.prepareActivation(s, "a"))
    assert(enemies[1].engagedAgentId == "a" and enemies[2].engagedAgentId == "a")

    s, enemies, door = fixture()
    local committed = s.agentCards.byAgent.a.hand[1].instanceId
    enemies[1].engagedAgentId = "a"
    ok, result = Resolution.execute(s, "a", "talent_test", args(door, "unlock", random(3), { committed }))
    assert(ok and not result.success and s.locationDecks.byCell.west.inPlay[door.instanceId])
    assert(s.doomClock.warningUsed and s.doomWarning and s.doomClock.slots[1] == "pending")
    assert(#s.agentCards.byAgent.a.discardPile == 1 and s.agentStatus.byAgent.a.health == 9 and s.attackFeedback)
    clear(s)
    ok, result = Resolution.execute(s, "a", "talent_test", args(door, "unlock", random(4)))
    assert(ok and result.success and not s.locationDecks.byCell.west.inPlay[door.instanceId])

    s, enemies, door = fixture()
    rng = random(1)
    request = args(door, "unlock", rng)
    plan = assert(Resolution.prepare(s, "a", "talent_test", request))
    s.locationDecks:discard("west", door.instanceId)
    assert(not Resolution.commit(plan) and rng.count == 0 and s.agentStatus.byAgent.a.actionPoints == 3)
    s, enemies, door = fixture()
    committed = s.agentCards.byAgent.a.hand[1].instanceId
    assert(not Action.evaluate(s, "a", args(door, "unlock", rng, { committed, committed })))
    assert(not Action.evaluate(s, "a", args(door, "unlock", rng, { 9999 })))
    s.agentCards.definitions.byId.boost.talents = { { type = "passion", qty = 1 } }
    assert(not Action.evaluate(s, "a", args(door, "unlock", rng, { committed })))
    s.agentStatus.byAgent.a.actionPoints = 0
    assert(not Action.evaluate(s, "a", args(door, "unlock", rng)))
    s.agentStatus.byAgent.a.actionPoints = 3
    plan = assert(Resolution.prepare(s, "a", "talent_test", args(door, "unlock", rng)))
    table.remove(s.agentCards.byAgent.a.hand)
    assert(not Resolution.commit(plan) and rng.count == 0)
    -- Every entry, including duplicate tile IDs, is a possible draw; pool never shrinks.
    local ids = {}
    for i = 1, #s.fatePool.entries do local id = Fate.pick(s.fatePool, random(i)); ids[id] = (ids[id] or 0) + 1 end
    assert(ids.neutral == 2 and #s.fatePool.entries == 5)

    s, enemies, door = fixture()
    s.armies = { byCell = { west = {}, east = {} } }
    s.fatePool.entries[1].tileId = "brutality"
    request = args(door, "unlock", random(1))
    plan = assert(Resolution.prepare(s, "a", "talent_test", request))
    s.agentDeployment.placements.a = "east"
    assert(not Resolution.commit(plan) and request.random.count == 0)
    s.agentDeployment.placements.a = "west"
    ok, result = Resolution.commit(plan)
    local Clashes = require("src.sys.battlefield_clashes")
    assert(ok and result.fate.name == "BRUTALITY" and result.fate.img and result.modifier == -1)
    assert(not Resolution.commit(plan) and Clashes.count(s.armies.byCell.west) == 1)
    assert(Clashes.count(s.armies.byCell.east) == 0)
    s.fatePool.definitions.brutality.clash.en_dmg = 99
    assert(s.armies.byCell.west.clashes[1].damage == 1)

    require("tests.talent_test_ui")(write)
end
