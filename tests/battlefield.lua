return function()
    local State = require("src.sys.battlefield_state")
    local Action = require("src.sys.battlefield_action")
    local Resolution = require("src.sys.agent_action_resolution")
    local function fixture(base, tile)
        local definitions = { r = { strength = "regular", faction = "allied", name = "Regular" },
            e = { strength = "elite", faction = "allied", name = "Elite" } }
        local function army(side)
            return { side = side, forces = { { id = side .. "e", forceId = "e" },
                { id = side .. "r1", forceId = "r" }, { id = side .. "r2", forceId = "r" } } }
        end
        local s = { activeAgentId = "a", actionRevision = 0,
            agentStatus = { byAgent = { a = { actionPoints = 9, health = 10, defiance = 10 } } },
            agentDeployment = { placements = { a = "north" } },
            assignments = { north = "loc", center = "jacl", south = "loc" },
            grid = { cells = { { id = "north", q = 0, r = -1 }, { id = "center", q = 0, r = 0 }, { id = "south", q = 0, r = 1 } } },
            locations = { byId = { loc = { name = "Field", battlefield_talent = { { type = "steel", qty = 3 }, { type = "reason", qty = 1 } } }, jacl = { name = "JACL" } } },
            armies = { byCell = { north = { allied = army("allied"), enemy = army("enemy") } },
                catalogue = { byId = definitions }, rules = require("data.army_deployment_rules") },
            agentCards = { agents = { byId = { a = { talents = { { type = "steel", qty = base or 3 } } } } },
                definitions = { byId = { boost = { talents = { { type = "steel", qty = 1 } } } } },
                byAgent = { a = { hand = { { instanceId = "card1", cardId = "boost" } }, discardPile = {} } } },
            fatePool = { entries = { { tileId = "tile" } }, definitions = { tile = tile or { value = 0 } } },
            locationDecks = { pool = { byId = { attacker = { card_type = "ENEMY", damage = 1, trauma = 1 } } },
                byCell = { north = { revision = 0, inPlayOrder = { "attacker1" }, inPlay = {
                    attacker1 = { instanceId = "attacker1", cardId = "attacker", engagedAgentId = "a" } } } } },
        }
        setmetatable(s.locationDecks, require("src.sys.location_decks"))
        local deck = s.locationDecks.byCell.north
        deck.locationId, deck.locationName = "loc", "Field"
        deck.drawPile, deck.discardPile, deck.types = {}, {}, { ENEMY = true }
        for i = 1, 5 do deck.drawPile[i] = { instanceId = "deck" .. i, cardId = "attacker" } end
        State.initialize(s.armies, s.assignments, "center")
        State.touch(s.armies, "north")
        return s
    end
    local function request(kind, extra)
        local a = { battlefieldKind = kind, testId = "steel", committedIds = {},
            random = { count = 0, random = function(self) self.count = self.count + 1; return 1 end } }
        for k, v in pairs(extra or {}) do a[k] = v end
        return a
    end
    local function execute(s, kind, extra)
        local args = request(kind, extra)
        local ok, result = Resolution.execute(s, "a", "battlefield", args)
        assert(ok, result)
        assert(args.random.count == 1)
        return result
    end
    local s = fixture()
    local result = execute(s, "engage")
    assert(result.success and result.sides.enemy.damage == 2 and result.sides.enemy.removed[1].id == "enemyr1")
    assert(result.sides.allied.damage == 2 and #result.sides.allied.removed == 2)
    assert(result.milling.actual == 2 and result.milling.cards[1].instanceId == "deck5"
        and result.milling.cards[2].instanceId == "deck4" and result.milling.after == 3)
    assert(#s.locationDecks.byCell.north.discardPile == 2 and s.locationDecks.byCell.north.inPlay.attacker1)
    assert(s.locationDecks.byCell.north.lastMilling == result.milling)
    assert(#result.armiesBefore.enemy.forces == 3 and #result.armiesAfter.enemy.forces == 1)
    assert(result.armiesBefore.enemy.value == 4 and result.armiesAfter.enemy.value == 2 and not result.sides.enemy.defeated)
    s.armies.byCell.north.enemy.forces[1].id = "changed_after_resolution"
    assert(result.armiesBefore.enemy.forces[1].id == "enemye" and result.armiesAfter.enemy.forces[1].id == "enemye")
    assert(s.armies.byCell.north.enemy.value == 2 and s.agentStatus.byAgent.a.actionPoints == 8)
    assert(not s.attackFeedback and s.agentStatus.byAgent.a.health == 10)
    s = fixture(2); result = execute(s, "engage")
    assert(not result.success and result.sides.allied.damage == 2 and #result.sides.allied.removed == 2)
    assert(result.sides.enemy.damage == 0 and #result.sides.enemy.removed == 0)
    assert(result.milling.actual == 0 and #s.locationDecks.byCell.north.drawPile == 5)
    assert(s.armies.byCell.north.allied.forces[1].id == "alliede")
    s = fixture(99); result = execute(s, "engage")
    assert(result.sides.enemy.damage == 2 and result.sides.allied.damage == 2)
    for _, special in ipairs({ "auto_success", "auto_failure" }) do
        s = fixture(special == "auto_success" and 0 or 99, { value = 0, special = special })
        result = execute(s, "engage")
        assert(result.sides.allied.damage == 2 and #result.sides.allied.removed == 2)
        assert(result.sides.enemy.damage == (special == "auto_success" and 2 or 0))
    end
    local Engagement = require("src.sys.battlefield_engagement")
    assert(not pcall(Engagement.validate, { strengthPerDamage = 0, rounding = "down", alliedRequiresSuccess = true }))
    -- Odd strength and protection are independent of test margin.
    for _, protection in ipairs({ 0, 1, 4 }) do
        s = fixture(20)
        table.remove(s.armies.byCell.north.allied.forces)
        State.touch(s.armies, "north")
        s.armies.byCell.north.protection = protection
        result = execute(s, "engage")
        assert(result.sides.enemy.damage == 1 and result.sides.allied.damage == 2)
        assert(result.sides.allied.absorbed == math.min(2, protection))
        assert(#result.sides.allied.removed == math.max(0, 2 - protection))
        assert(s.armies.byCell.north.protection == math.max(0, protection - 2))
    end
    -- Strength-one armies inflict nothing, even on automatic success.
    s = fixture(0, { value = 0, special = "auto_success" })
    for _, side in ipairs({ "enemy", "allied" }) do
        s.armies.byCell.north[side].forces = { s.armies.byCell.north[side].forces[2] }
    end
    State.touch(s.armies, "north")
    result = execute(s, "engage")
    assert(result.sides.enemy.damage == 0 and result.sides.allied.damage == 0)
    assert(#result.armiesAfter.enemy.forces == 1 and #result.armiesAfter.allied.forces == 1)
    -- One elite on each side can destroy the other simultaneously.
    s = fixture(3)
    for _, side in ipairs({ "enemy", "allied" }) do
        s.armies.byCell.north[side].forces = { s.armies.byCell.north[side].forces[1] }
    end
    State.touch(s.armies, "north")
    result = execute(s, "engage")
    assert(result.sides.enemy.defeated and result.sides.allied.defeated)
    assert(result.milling.actual == 1)
    assert(result.sides.enemy.damage == 1 and result.sides.allied.damage == 1)
    -- Applying fixed incoming amounts in either order produces the same outcome.
    for _, success in ipairs({ true, false }) do
        local a, b = fixture(), fixture()
        a.armies.byCell.north.protection, b.armies.byCell.north.protection = 1, 1
        local committed = Engagement.resolve(a.armies, "north", success)
        local amounts = Engagement.calculate(require("src.sys.battlefield_engagement_record").capture(
            b.armies.byCell.north, b.armies.catalogue), success)
        for _, side in ipairs({ "allied", "enemy" }) do
            if amounts[side] > 0 then State.damage(b.armies, "north", side, amounts[side]) end
        end
        for _, side in ipairs({ "allied", "enemy" }) do
            assert(a.armies.byCell.north[side].value == b.armies.byCell.north[side].value)
            assert(#committed.armiesAfter[side].forces == #b.armies.byCell.north[side].forces)
        end
        assert(a.armies.byCell.north.protection == b.armies.byCell.north.protection)
    end
    s = fixture(1); result = execute(s, "entrench")
    assert(result.success and result.difficulty == 1 and s.armies.byCell.north.protection == 2 and not s.attackFeedback)
    assert(result.summary == "ALLIED PROTECTION SET TO 2")
    s.talentFeedback = nil
    assert(Action.available(s, "a", "entrench").valid)
    result = execute(s, "entrench")
    assert(s.armies.byCell.north.protection == 4 and result.summary == "ALLIED PROTECTION SET TO 4")
    s.talentFeedback = nil
    assert(not Action.available(s, "a", "entrench").valid)
    local removed, absorbed = State.damage(s.armies, "north", "allied", 1)
    assert(#removed == 0 and absorbed == 1 and s.armies.byCell.north.protection == 3)
    result = execute(s, "entrench"); assert(s.armies.byCell.north.protection == 4)
    removed, absorbed = State.damage(s.armies, "north", "allied", 5)
    assert(absorbed == 4 and #removed == 1 and removed[1].id == "alliedr1")
    s = fixture(1); s.armies.byCell.north.protection = 1
    result = execute(s, "entrench")
    assert(s.armies.byCell.north.protection == 3 and result.summary == "ALLIED PROTECTION SET TO 3")
    s = fixture(0, { value = 0, special = "auto_success" })
    result = execute(s, "entrench"); assert(s.armies.byCell.north.protection == 2)
    s = fixture(0); s.armies.byCell.north.protection = 1
    result = execute(s, "entrench")
    assert(not result.success and s.armies.byCell.north.protection == 1 and #s.armies.byCell.north.allied.forces == 3)
    assert(require("src.sys.battlefield_tests").resolve(s.locations.byId.loc, "entrench")[2].value == 0)
    local Maneuver = require("src.sys.battlefield_maneuver")
    s = fixture(); State.entrench(s.armies, "north")
    local unit = s.armies.byCell.north.allied.forces[1]
    s.agentStatus.byAgent.a.actionPoints = 1
    result = execute(s, "maneuver")
    assert(result.success and #s.armies.byCell.center.allied.forces == 0 and s.pendingManeuver)
    assert(s.agentStatus.byAgent.a.actionPoints == 0 and s.agentStatus.byAgent.a.health == 9)
    local pending = s.pendingManeuver
    assert(not Maneuver.commit(s, pending, "north", "center", unit.id))
    s.talentFeedback, s.attackFeedback = nil, nil
    assert(not Resolution.prepare(s, "a", "end_turn", {}))
    assert(not Maneuver.commit(s, pending, "north", "south", unit.id))
    assert(not Maneuver.commit(s, pending, "north", "center", "enemye"))
    assert(Maneuver.commit(s, pending, "north", "center", unit.id))
    assert(s.armies.byCell.center.allied.forces[1] == unit and s.armies.byCell.north.protection == 2)
    assert(s.armies.byCell.center.protection == 0 and not s.pendingManeuver)
    assert(not Maneuver.commit(s, pending, "center", "north", unit.id))
    s.agentStatus.byAgent.a.actionPoints = 1
    s.agentDeployment.placements.a = "south"
    result = execute(s, "maneuver")
    s.talentFeedback, s.attackFeedback = nil, nil
    assert(Maneuver.commit(s, s.pendingManeuver, "center", "south", unit.id))
    assert(s.armies.byCell.south.allied.forces[1] == unit and #s.armies.byCell.center.allied.forces == 0)
    s = fixture(0); result = execute(s, "maneuver")
    assert(not result.success and not s.pendingManeuver and #s.armies.byCell.north.allied.forces == 3)
    s = fixture(); s.agentStatus.byAgent.a.health = 1
    result = execute(s, "maneuver")
    assert(result.success and not s.pendingManeuver and #s.armies.byCell.center.allied.forces == 0)
    s = fixture(); result = execute(s, "maneuver")
    pending = s.pendingManeuver
    s.talentFeedback, s.attackFeedback = nil, nil
    State.entrench(s.armies, "north")
    assert(not Maneuver.commit(s, pending, "north", "center", "alliede"))
    Maneuver.decline(s, pending)
    assert(not s.pendingManeuver and s.agentStatus.byAgent.a.actionPoints == 8)
    s = fixture()
    s.agentDeployment.placements.a = "center"
    for _, kind in ipairs({ "engage", "entrench", "maneuver" }) do assert(not Action.available(s, "a", kind).valid) end
    s = fixture(); s.armies.byCell.north.allied.forces = {}
    assert(not Action.available(s, "a", "engage").valid and not Action.available(s, "a", "entrench").valid)
    s = fixture(); s.armies.byCell.north.enemy.forces = {}; assert(not Action.available(s, "a", "engage").valid)
    s = fixture(2)
    local args = request("engage", { committedIds = { "card1" } })
    local plan = assert(Resolution.prepare(s, "a", "battlefield", args))
    assert(args.random.count == 0 and #s.agentCards.byAgent.a.hand == 1)
    local ok; ok, result = Resolution.commit(plan)
    assert(ok and result.success and result.sides.enemy.damage == 2 and #s.agentCards.byAgent.a.hand == 0 and #s.agentCards.byAgent.a.discardPile == 1)
    assert(not Resolution.commit(plan) and args.random.count == 1)
    for _, mutation in ipairs({
        function(v) State.entrench(v.armies, "north") end,
        function(v) v.locationDecks:draw("north") end,
        function(v) v.agentDeployment.placements.a = "south" end,
        function(v) table.remove(v.agentCards.byAgent.a.hand) end,
        function(v) v.agentStatus.byAgent.a.actionPoints = 0 end,
    }) do
        s = fixture(); args = request("engage")
        plan = assert(Resolution.prepare(s, "a", "battlefield", args)); mutation(s)
        assert(not Resolution.commit(plan) and args.random.count == 0)
    end
    s = fixture(); assert(not Action.evaluate(s, "a", request("engage", { committedIds = { "card1", "card1" } })))
    assert(not Action.prepare(s, "a", request("engage", { committedIds = { [2] = "card1" } })))
    s.agentStatus.byAgent.a.actionPoints = 0; assert(not Action.available(s, "a", "engage").valid)
    for _, count in ipairs({ 0, 1 }) do
        s = fixture(99)
        local deck = s.locationDecks.byCell.north
        while #deck.drawPile > count do table.remove(deck.drawPile, 1) end
        result = execute(s, "engage")
        assert(result.milling.requested == 2 and result.milling.actual == count and result.milling.after == 0)
        assert(#deck.discardPile == count and #deck.inPlayOrder == 1)
    end
    s = fixture()
    args = request("engage")
    plan = assert(Resolution.prepare(s, "a", "battlefield", args))
    local armyRevision, ap = s.armies.revision, s.agentStatus.byAgent.a.actionPoints
    s.locationDecks:draw("north")
    assert(not Resolution.commit(plan) and args.random.count == 0)
    assert(s.armies.revision == armyRevision and s.agentStatus.byAgent.a.actionPoints == ap)
    s = fixture()
    args = request("engage")
    s.locationDecks.pool.byId.attacker = nil
    assert(not pcall(Resolution.prepare, s, "a", "battlefield", args) and args.random.count == 0)

    local Clashes = require("src.sys.battlefield_clashes")
    local Turn = require("src.sys.agent_turn")
    s = fixture(3, { img = true, special = "auto_success" })
    local pair = s.armies.byCell.north
    local batch = Clashes.prepareBatch("test", { amt = 1, en_bonus = 2 })
    Clashes.enqueue(pair, batch)
    pair.protection = 2
    local status = s.agentStatus.byAgent.a
    status.actionPoints = 0
    local started, nextTest = Turn.finish(s, "a")
    assert(started and nextTest.clash == batch and not status.exhausted and not s.attackFeedback)
    args = request("engage", { clash = batch, committedIds = { "card1" } })
    plan = assert(Resolution.prepare(s, "a", "battlefield", args))
    State.touch(s.armies, "north")
    assert(not Resolution.commit(plan) and Clashes.count(pair) == 1 and args.random.count == 0)
    result = execute(s, "engage", args)
    assert(result.clash and result.committed == 1 and result.difficulty == 5 and result.milling.actual == 2)
    assert(#pair.allied.forces > 0 and #pair.enemy.forces > 0 and Clashes.count(pair) == 0)
    assert(status.actionPoints == 0 and #s.agentCards.byAgent.a.discardPile == 1 and not status.exhausted)
    s.talentFeedback = nil
    assert(Turn.finish(s, "a") and status.exhausted and not s.pendingEndTurn)

    s = fixture()
    s.agentDeployment.placements.a = "center"
    pair = s.armies.byCell.center
    Clashes.enqueue(pair, Clashes.prepareBatch("test", { amt = 1 }))
    assert(Turn.finish(s, "a") and Clashes.count(pair) == 1 and not s.pendingEndTurn)

    -- Real data: every ordinary location's printed tests validate.
    local locations = require("data.locations.index").refresh()
    for _, id in ipairs(locations.ids) do assert(#require("src.sys.battlefield_tests").resolve(locations.byId[id]) > 0) end
end
