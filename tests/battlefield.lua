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
    -- REDLINE comes from the starting lineup and the final enemy strength.
    local Reserve = require("src.sys.fate_reserve")
    local redline = require("data.fate_tiles.redline")
    local function dustDevils(tile)
        local session = fixture(1, tile)
        local armies = session.armies
        local pair = armies.byCell.north
        armies.catalogue.byId.reg_dustdevil = require("data.forces.cut_allied.reg_dustdevil")
        armies.catalogue.byId.e.faction = "enemy"
        pair.allied.forces = {
            { id = "dust1", forceId = "reg_dustdevil" },
            { id = "dust2", forceId = "reg_dustdevil" },
        }
        pair.enemy.forces = { { id = "enemy1", forceId = "e" } }
        State.touch(armies, "north")
        return session, pair
    end
    s = dustDevils()
    Reserve.add(s.fatePool, redline, 1, "EXISTING")
    result = execute(s, "engage", { bonusCounts = { redline = 1 } })
    local reserve, status = Reserve.entries(s.fatePool), s.agentStatus.byAgent.a
    assert(result.success and result.total == 3 and result.sides.enemy.defeated)
    assert(result.sides.allied.removed[1].forceId == "reg_dustdevil")
    assert(#reserve == 1 and reserve[1].tileId == "redline" and reserve[1].sourceName == "Dust Devil")
    assert(status.health == 9 and status.defiance == 9 and result.summary:find("+1 REDLINE", 1, true))
    local pair
    s, pair = dustDevils({ special = "auto_success" })
    local Clashes = require("src.sys.battlefield_clashes")
    local clash = Clashes.prepareBatch("retaliation", { amt = 1, en_dmg = 1 })
    Clashes.enqueue(pair, clash)
    s.pendingEndTurn = { agentId = "a", cell = "north" }
    result = execute(s, "engage", { clash = clash })
    assert(result.clash and result.sides.allied.defeated and result.sides.enemy.defeated)
    assert(#Reserve.entries(s.fatePool) == 1)
    s = dustDevils({ special = "auto_success" })
    s.armies.catalogue.byId.e.on_defeat = { replace_with = "replacement" }
    s.armies.catalogue.byId.replacement = { strength = "regular", faction = "enemy" }
    result = execute(s, "engage")
    assert(result.armiesAfter.enemy.value == 1 and #Reserve.entries(s.fatePool) == 0)
    s = dustDevils()
    result = execute(s, "engage")
    assert(not result.success and #Reserve.entries(s.fatePool) == 0)

    local function pazervores(tile)
        local session = fixture(2, tile)
        local armies = session.armies
        local definitions = armies.catalogue.byId
        definitions.elite_synthvor = require("data.forces.cut_hostile.elite_synthvor")
        definitions.reg_synthwasp = require("data.forces.cut_hostile.reg_synthwasp")
        definitions.e.on_defeat = { replace_with = "r" }
        definitions.e.passives = {
            { id = "shield", effect = "location_protection_bonus", stacking = "per_force", bonus = 1, maximum = 2 },
            { id = "test", effect = "battlefield_test_bonus", stacking = "per_force", action = "engage", bonus = 2 },
        }
        local pair = armies.byCell.north
        pair.enemy.forces = {
            { id = "pazervore1", forceId = "elite_synthvor" },
            { id = "pazervore2", forceId = "elite_synthvor" },
        }
        State.touch(armies, "north")
        return session, pair
    end
    s, pair = pazervores({ value = 1 })
    local projected = assert(Action.previewEngagement(s, "a")).effect
    assert(projected.removedId == "alliede" and projected.addedName == "Synthetic Devilwasp")
    assert(projected.alliedBefore == 4 and projected.alliedAfter == 2)
    assert(projected.enemyBefore == 4 and projected.enemyAfter == 5)
    assert(projected.forceBonusBefore == 2 and projected.forceBonusAfter == 0)
    assert(projected.protectionBefore == 1 and projected.protectionAfter == 0)
    assert(pair.allied.value == 4 and pair.enemy.value == 4)
    result = execute(s, "engage")
    assert(result.success and result.forceBonus == 0 and result.total == 3 and result.beforeEngage.addedId == projected.addedId)
    assert(result.armiesBefore.allied.value == 2 and result.armiesBefore.enemy.value == 5)
    assert(result.sides.enemy.removed[1].id == projected.addedId and result.milling.actual == 1)
    assert(#result.sides.allied.removed == 2 and not result.sides.allied.removed[1].replacementId)

    s, pair = pazervores()
    local staleArgs = request("engage")
    local stale = assert(Resolution.prepare(s, "a", "battlefield", staleArgs))
    State.touch(s.armies, "north")
    assert(not Resolution.commit(stale) and staleArgs.random.count == 0)
    assert(pair.allied.value == 4 and pair.enemy.value == 4)
    result = execute(s, "engage")
    assert(not result.success and result.beforeEngage and result.milling.actual == 0 and pair.enemy.value == 5)
    assert(not Action.previewEngagement(s, "a"))

    s, pair = pazervores()
    table.remove(pair.allied.forces, 1)
    State.touch(s.armies, "north")
    assert(not Action.previewEngagement(s, "a"))
    result = execute(s, "engage")
    assert(not result.beforeEngage and pair.enemy.value == 4)

    s, pair = pazervores()
    pair.allied.forces = { pair.allied.forces[1] }
    State.touch(s.armies, "north")
    result = execute(s, "engage")
    assert(result.beforeEngage and result.armiesBefore.allied.value == 0 and #pair.allied.forces == 0)
    assert(#result.sides.allied.removed == 0 and result.sides.enemy.damage == 0)

    s, pair = pazervores()
    pair.allied.forces[#pair.allied.forces + 1] = { id = "second_ally_elite", forceId = "e" }
    pair.protection = 4
    State.touch(s.armies, "north")
    Clashes.enqueue(pair, Clashes.prepareBatch("retaliation", { amt = 2, en_bonus = 2 }))
    s.pendingEndTurn = { agentId = "a", cell = "north" }
    for i, target in ipairs({ "alliede", "second_ally_elite" }) do
        local pending = Clashes.ready(s, "a")
        assert(Action.previewEngagement(s, "a", pending).effect.removedId == target)
        result = execute(s, "engage", { clash = pending })
        assert(result.clash and not result.success and result.beforeEngage.removedId == target)
        assert(#pair.enemy.forces == 2 + i and pair.enemy.forces[2 + i].forceId == "reg_synthwasp")
        s.talentFeedback = nil
    end
    assert(pair.enemy.forces[3].id ~= pair.enemy.forces[4].id and Clashes.count(pair) == 0)
    -- Applying fixed incoming amounts in either order produces the same outcome.
    for _, success in ipairs({ true, false }) do
        local a, b = fixture(), fixture()
        a.armies.byCell.north.protection, b.armies.byCell.north.protection = 1, 1
        local committed = Engagement.resolve(a.armies, "north", success)
        local amounts = Engagement.calculate(require("src.sys.battlefield_engagement_record").capture(
            b.armies, "north"), success)
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
    do
        local abrams = require("data.forces.cap_saw.elite_abrams")
        local game = fixture()
        local armies = game.armies
        local field = armies.byCell.north
        armies.catalogue.byId[abrams.id] = abrams
        field.protection = 3
        assert(State.protection(armies, "north").total == 3)
        for i = 1, 3 do
            field.allied.forces[i] = { id = "tank" .. i, forceId = abrams.id }
            for j = i + 1, 3 do field.allied.forces[j] = nil end
            local protection = State.protection(armies, "north")
            assert(protection.bonus == math.min(i, 2) and protection.sources[1].label == "ABRAMS")
        end
        State.touch(armies, "north")
        assert(Action.available(game, "a", "entrench").valid)
        local entrenched = execute(game, "entrench")
        assert(field.protection == 4 and entrenched.summary == "ALLIED PROTECTION SET TO 6")
        game.talentFeedback = nil
        assert(not Action.available(game, "a", "entrench").valid)

        local staged = Engagement.prepare(armies, "north", false, 1)
        assert(field.protection == 4 and State.protection(armies, "north").total == 6)
        local exchange = assert(Engagement.commit(staged))
        assert(exchange.sides.allied.absorbed == 3 and exchange.sides.allied.bonusAbsorbed == 2
            and exchange.sides.allied.storedAbsorbed == 1)
        assert(exchange.armiesBefore.protectionBreakdown.stored == 4)
        assert(exchange.armiesAfter.protection == 5 and field.protection == 3)
        exchange = Engagement.resolve(armies, "north", false)
        assert(exchange.sides.allied.bonusAbsorbed == 2 and field.protection == 3)

        Maneuver.begin(game, "a", "north")
        assert(Maneuver.commit(game, game.pendingManeuver, "north", "center", "tank3"))
        assert(State.protection(armies, "center").bonus == 0 and State.protection(armies, "north").bonus == 2)
        game.agentDeployment.placements.a = "south"
        Maneuver.begin(game, "a", "south")
        assert(Maneuver.commit(game, game.pendingManeuver, "center", "south", "tank3"))
        assert(State.protection(armies, "south").total == 1 and field.protection == 3)
        staged = Engagement.prepare(armies, "north", false, 4)
        assert(#field.allied.forces == 2 and staged.result.armiesAfter.protectionBreakdown.bonus == 1)
        exchange = assert(Engagement.commit(staged))
        assert(exchange.sides.allied.removed[1].id == "tank1")
        assert(State.protection(armies, "north").total == 1 and exchange.armiesAfter.protection == 1)
    end
    do
        local game = fixture(2)
        local armies = game.armies
        local hummer = require("data.forces.cap_saw.reg_hummer")
        local blackpelt = require("data.forces.cap_saber.elite_blackpelt")
        armies.catalogue.byId[hummer.id] = hummer
        armies.catalogue.byId[blackpelt.id] = blackpelt
        local function add(cell, definition, id)
            table.insert(armies.byCell[cell].allied.forces, { id = id, forceId = definition.id })
            State.touch(armies, cell)
        end
        local function evaluate(kind)
            return assert(Action.evaluate(game, "a", request(kind)))
        end

        add("center", hummer, "reserve")
        add("south", hummer, "elsewhere")
        assert(evaluate("maneuver").forceBonus == 0)
        assert(not execute(game, "maneuver").success)
        game.talentFeedback, game.attackFeedback = nil, nil

        State.transfer(armies, "center", "north", "reserve")
        local maneuvered = execute(game, "maneuver")
        assert(maneuvered.success and maneuvered.forceBonus == 1 and maneuvered.total == 3)
        assert(require("src.ui.test_difficulty").result(maneuvered) == "2 + 0 + 1 HMMWV + 0 = 3 vs 3")
        game.talentFeedback, game.attackFeedback = nil, nil
        assert(Maneuver.commit(game, game.pendingManeuver, "north", "center", "alliede"))

        for i = 2, 4 do add("north", hummer, "hummer" .. i) end
        local maneuver = evaluate("maneuver")
        assert(maneuver.forceBonus == 4 and #maneuver.forceSources == 1
            and maneuver.forceSources[1].count == 4 and maneuver.forceSources[1].value == 4)
        assert(evaluate("engage").forceBonus == 0 and evaluate("entrench").forceBonus == 0)

        add("north", blackpelt, "wardroid1")
        add("north", blackpelt, "wardroid2")
        maneuver = evaluate("maneuver")
        assert(maneuver.forceBonus == 5 and #maneuver.forceSources == 2)
        assert(evaluate("engage").forceBonus == 1 and evaluate("entrench").forceBonus == 1)
        State.transfer(armies, "north", "center", "hummer4")
        assert(evaluate("maneuver").forceBonus == 4)
        local forceBonus = require("src.sys.force_passives").battlefieldBonus
        assert(forceBonus(armies, "center", "maneuver") == 0)
        State.transfer(armies, "center", "south", "hummer4")
        assert(forceBonus(armies, "south", "maneuver") == 2)
        State.damage(armies, "south", "allied", 1)
        assert(forceBonus(armies, "south", "maneuver") == 1)
    end
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
    do
        local bigMack = require("data.forces.cut_allied.elite_bigmack")
        local hummer = require("data.forces.cap_saw.reg_hummer")
        local function attempt(base, options)
            local game = fixture(base, options.tile)
            local armies = game.armies
            local definitions = armies.catalogue.byId
            definitions[bigMack.id], definitions[hummer.id] = bigMack, hummer
            definitions.e.on_defeat = { replace_with = "enemy_replacement" }
            definitions.enemy_replacement = { strength = "regular", faction = "enemy", name = "Replacement" }
            game.grid.cells[3].q, game.grid.cells[3].r = 1, -1
            local source, destination = "north", "south"
            if options.reserve then source, destination = "center", "north" end
            local unitId = options.otherForce and "other" or "mack"
            table.insert(armies.byCell[source].allied.forces, { id = unitId, forceId = options.otherForce and "r" or bigMack.id })
            if options.otherForce then
                table.insert(armies.byCell[source].allied.forces, { id = "mack", forceId = bigMack.id })
            end
            if options.support then
                table.insert(armies.byCell.north.allied.forces, { id = "support", forceId = hummer.id })
            end
            armies.byCell[destination].enemy.forces = options.empty and {} or {
                { id = "regular", forceId = "r" }, { id = "elite", forceId = "e" },
            }
            if not options.reserve then
                local deck = game.locationDecks.byCell.north
                game.locationDecks.byCell.south = { locationId = "loc", locationName = "South Field", revision = 0,
                    drawPile = { deck.drawPile[1] }, discardPile = {}, inPlay = {}, inPlayOrder = {}, types = deck.types }
            end
            State.touch(armies, source)
            State.touch(armies, destination)
            local rng = { count = 0, random = function(self, size)
                self.count = self.count + 1
                assert(size == self.count and self.count <= 2)
                return size
            end }
            local outcome = execute(game, "maneuver", { random = rng })
            local pendingMove = game.pendingManeuver
            if not outcome.success then
                assert(not pendingMove and rng.count == 1)
                return
            end
            assert(rng.count == 1 and pendingMove.margin == options.margin)
            game.talentFeedback, game.attackFeedback = nil, nil
            assert(not Maneuver.commit(game, pendingMove, source, destination, "missing"))
            assert(rng.count == 1)
            if options.decline then
                Maneuver.decline(game, pendingMove)
                assert(not Maneuver.commit(game, pendingMove, source, destination, unitId) and rng.count == 1)
                return
            end
            local ok, move = Maneuver.commit(game, pendingMove, source, destination, unitId)
            assert(ok, move)
            assert(not Maneuver.commit(game, pendingMove, source, destination, unitId))
            local enemy = armies.byCell[destination].enemy
            if options.hit then
                local hit = move.hit
                local casualty = hit.sides.enemy.removed[1]
                assert(rng.count == 2 and casualty.id == "elite" and hit.sides.enemy.damage == 1)
                assert(hit.sides.allied.damage == 0 and #hit.sides.allied.removed == 0)
                assert(enemy.forces[1].id == "regular" and enemy.forces[2].forceId == "enemy_replacement"
                    and enemy.forces[2].id == casualty.replacementId and enemy.value == 2)
                assert(hit.armiesBefore.enemy.forces[2].id == "elite"
                    and hit.armiesAfter.enemy.forces[2].id == casualty.replacementId)
                assert(move.milling.cell == destination and move.milling.actual == 1
                    and game.locationDecks.byCell[destination].lastMilling == move.milling)
            else
                assert(rng.count == 1 and not move.hit and not move.milling)
                assert(#enemy.forces == (options.empty and 0 or 2))
            end
        end
        attempt(4, { margin = 1 })
        attempt(4, { margin = 2, support = true, hit = true })
        attempt(5, { margin = 2, hit = true, reserve = true })
        attempt(5, { margin = 2, decline = true })
        attempt(5, { margin = 2, otherForce = true })
        attempt(5, { margin = 2, empty = true })
        attempt(2, { margin = -1, tile = { special = "auto_success" } })
        attempt(4, { margin = 2, hit = true, tile = { special = "auto_success", value = 1 } })
        attempt(6, { tile = { special = "auto_failure" } })
    end
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
    s.armies.catalogue.byId.elite_abrams = require("data.forces.cap_saw.elite_abrams")
    pair.allied.forces[1].forceId = "elite_abrams"
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
    assert(result.sides.allied.bonusAbsorbed == 1 and result.sides.allied.storedAbsorbed == 1
        and pair.protection == 1)
    assert(#pair.allied.forces > 0 and #pair.enemy.forces > 0 and Clashes.count(pair) == 0)
    assert(status.actionPoints == 0 and #s.agentCards.byAgent.a.discardPile == 1 and not status.exhausted)
    s.talentFeedback = nil
    assert(Turn.finish(s, "a") and status.exhausted and not s.pendingEndTurn)

    s = fixture()
    s.agentDeployment.placements.a = "center"
    pair = s.armies.byCell.center
    Clashes.enqueue(pair, Clashes.prepareBatch("test", { amt = 1 }))
    assert(Turn.finish(s, "a") and Clashes.count(pair) == 1 and not s.pendingEndTurn)

    -- Exercise the printed Blackpelt passive with actual force definitions.
    s = fixture(2)
    local definitions = s.armies.catalogue.byId
    definitions.enemyRegular = definitions.r
    for _, unit in ipairs(s.armies.byCell.north.enemy.forces) do
        if unit.forceId == "r" then unit.forceId = "enemyRegular" end
    end
    definitions.e = require("data.forces.cap_saber.elite_blackpelt")
    definitions.r = require("data.forces.cap_saber.reg_vicky")
    definitions.reg_cold_hand = require("data.forces.cap_saber.reg_cold_hand")
    local forces = s.armies.byCell.north.allied.forces
    local bonus = require("src.sys.force_passives").battlefieldBonus
    for count = 3, 8 do
        assert(bonus(s.armies, "north") == math.min(3, math.floor(count / 2)))
        forces[#forces + 1] = { id = "copy" .. count, forceId = "e" }
    end
    while #forces > 3 do table.remove(forces) end
    s.agentStatus.byAgent.a.turnTalentBonuses = { reason = 3, steel = -1 }
    local preview = require("src.ui.battlefield_comparison").build({ agents = s.agentCards.agents },
        s, "a", { north = true, south = true })
    assert(preview.noPreference and preview.byCell.north.best and preview.byCell.south.best)
    for _, test in ipairs(preview.byCell.north.tests) do
        assert(test.score == (test.talent == "steel" and 2 or 0) and test.margin == -1)
    end
    s.agentStatus.byAgent.a.turnTalentBonuses = nil
    for _, kind in ipairs({ "engage", "entrench", "maneuver" }) do
        local evaluation = assert(Action.evaluate(s, "a", request(kind, { testId = "reason" })))
        assert(evaluation.forceBonus == 1 and evaluation.forceSources[1].count == 3)
    end
    local charm = assert(require("src.sys.location_actions").evaluate(s, "a", { locationKind = "charm", testId = "charm" }))
    assert(charm.bonus == 0)
    s.agentDeployment.placements.a = "center"
    local bombard = assert(Action.evaluate(s, "a", request("bombard", { testId = "fire", targetCell = "north" })))
    assert(bombard.bonus == 0)
    s.agentDeployment.placements.a = "north"
    result = execute(s, "maneuver")
    assert(result.success and result.total == 3 and result.forceBonus == 1)
    s.talentFeedback, s.attackFeedback = nil, nil
    assert(Maneuver.commit(s, s.pendingManeuver, "north", "center", "alliede"))
    assert(bonus(s.armies, "north") == 0 and bonus(s.armies, "center") == 0)
    State.transfer(s.armies, "center", "north", "alliede")
    pair = s.armies.byCell.north
    batch = Clashes.prepareBatch("test", { amt = 1, en_bonus = 1 })
    Clashes.enqueue(pair, batch)
    assert(Turn.finish(s, "a"))
    result = execute(s, "engage", { clash = batch, committedIds = { "card1" } })
    assert(result.success and result.total == 4 and result.difficulty == 4)
    assert(require("src.ui.test_difficulty").result(result) == "2 + 1 + 1 BLACKPELT + 0 = 4 vs 4")
    assert(bonus(s.armies, "north") == 1 and result.forceSources[1].count == 3)
    for i, casualty in ipairs(result.sides.allied.removed) do
        local replacement = pair.allied.forces[i]
        assert(replacement.id == casualty.replacementId and replacement.id ~= casualty.id)
        assert(replacement.forceId == "reg_cold_hand")
    end
    local nextHit = assert(Engagement.resolve(s.armies, "north", false))
    -- Apply excess damage after the clash to check that the replacement has one life.
    local remaining = State.damage(s.armies, "north", "allied", 99)
    assert(#remaining + #nextHit.sides.allied.removed == 3 and #pair.allied.forces == 0)

    pair.allied.forces = { { id = "solo", forceId = "r" } }
    pair.protection = 1
    local blocked = State.damage(s.armies, "north", "allied", 1)
    assert(#blocked == 0 and pair.allied.forces[1].id == "solo")
    local staged = Engagement.prepare(s.armies, "north", false, 99)
    assert(pair.allied.forces[1].id == "solo" and not staged.result.sides.allied.defeated)
    assert(Engagement.commit(staged) and not Engagement.commit(staged))
    assert(#pair.allied.forces == 1 and pair.allied.forces[1].forceId == "reg_cold_hand")

    -- Real data: every ordinary location's printed tests validate.
    local locations = require("data.locations.index").refresh()
    for _, id in ipairs(locations.ids) do assert(#require("src.sys.battlefield_tests").resolve(locations.byId[id]) > 0) end
end
