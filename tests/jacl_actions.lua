return function(write)
    local State = require("src.sys.battlefield_state")
    local Resolution = require("src.sys.agent_action_resolution")
    local Action = require("src.sys.jacl_actions")
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

    local function setup(tile)
        local s = fixture(3, tile)
        s.agentDeployment.placements.a = "center"
        s.locationDecks.byCell.north.inPlay.attacker1.engagedAgentId = nil
        s.agentCards.agents.byId.a.talents = {}
        for talent in pairs(require("data.talent_test_rules").talents) do
            table.insert(s.agentCards.agents.byId.a.talents, { type = talent, qty = 3 })
        end
        for _, cell in ipairs({ "center", "south" }) do
            s.locationDecks.byCell[cell] = { locationId = cell, locationName = cell,
                drawPile = { { instanceId = cell .. "1", cardId = "attacker" } },
                discardPile = {}, inPlay = {}, inPlayOrder = {}, types = { ENEMY = true }, revision = 0 }
        end
        return s
    end
    local function args(kind)
        return { battlefieldKind = kind, testId = require("data.jacl_actions").actions[kind].talents[1],
            targetCell = kind == "bombard" and "north" or nil, committedIds = {},
            random = { count = 0, random = function(self) self.count = self.count + 1; return 1 end } }
    end
    do
        local Reserve = require("src.sys.fate_reserve")
        for _,success in ipairs({true,false}) do
            local s = setup({value=0,special=success and "auto_success" or "auto_failure"})
            Reserve.add(s.fatePool,require("data.fate_tiles.genius"),3)
            Reserve.add(s.fatePool,require("data.fate_tiles.redline"),1)
            local status = s.agentStatus.byAgent.a
            local health, defiance = status.health, status.defiance
            local a = args("security"); a.bonusCounts={genius=3,redline=1}
            local ok,r=Resolution.execute(s,"a","battlefield",a)
            assert(ok and r.success==success and r.reserveBonus==5 and #Reserve.entries(s.fatePool)==0)
            assert(status.health == health - 1 and status.defiance == defiance - 1)
        end
    end
    for _, kind in ipairs(require("data.jacl_actions").order) do
        for _, success in ipairs({ true, false }) do
            local s = setup({ value = 0, special = success and "auto_success" or "auto_failure" })
            local a = args(kind)
            local ok, r = Resolution.execute(s, "a", "battlefield", a)
            assert(ok, r); assert(r.success == success)
            assert(s.agentStatus.byAgent.a.actionPoints == 9 - require("data.jacl_actions").actions[kind].actionPointCost)
            assert(#s.locationDecks.byCell.center.drawPile == 1 and s.locationDecks.byCell.center.revision == 0)
            if kind == "bombard" then
                assert(#s.armies.byCell.north.enemy.forces == (success and 2 or 3))
                if success then assert(r.sides.enemy.removed[1].id == "enemye" and r.milling.actual == 1) end
                assert(#s.locationDecks.byCell.north.discardPile == (success and 1 or 0))
            elseif kind == "security" then assert((s.jaclSecurity or 0) == (success and 2 or 0))
            else assert(s.locationDecks.byCell.north.revision == (success and 1 or 0)) end
        end
    end
    local s = setup(); s.jaclSecurity = 3
    assert(Resolution.execute(s, "a", "battlefield", args("security")))
    assert(s.jaclSecurity == 4); s.talentFeedback = nil
    assert(not Action.available(s, "a", "security").valid)
    s = setup(); s.agentStatus.byAgent.a.actionPoints = 2
    assert(not Action.available(s, "a", "bombard").valid)
    s = setup(); s.agentDeployment.placements.a = "north"
    assert(not Action.available(s, "a", "security").valid)
    -- Stale and repeated commits do not spend AP or consume RNG.
    s = setup(); local a = args("bombard"); local plan = assert(Resolution.prepare(s, "a", "battlefield", a))
    State.touch(s.armies, "north")
    assert(not Resolution.commit(plan)); assert(a.random.count == 0 and s.agentStatus.byAgent.a.actionPoints == 9)
    s = setup(); a = args("security"); plan = assert(Resolution.prepare(s, "a", "battlefield", a))
    assert(Resolution.commit(plan)); assert(not Resolution.commit(plan)); assert(a.random.count == 1)
    -- All hunt roles remain on top, outside play, with identity and health intact.
    for _, role in ipairs({ "CHAMPION", "BODYGUARD", "COMPANY" }) do
        s = setup(); s.locationDecks.pool.byId.target = { card_type = role }
        local deck = s.locationDecks.byCell.north
        local top = { cardId = "target", instanceId = "target1", health = 7 }
        deck.drawPile[#deck.drawPile] = top
        assert(Resolution.execute(s, "a", "battlefield", args("triangulate")))
        assert(s.locationDecks:revealedTop("north") == top and top.health == 7)
        assert(not deck.inPlay.target1 and not s.pendingHuntEscape)
        s.locationDecks:draw("north"); assert(not s.locationDecks:revealedTop("north"))
    end
    -- Bombard mills hunt cards into play using the existing remote-entry behavior.
    s = setup(); s.locationDecks.pool.byId.target = { card_type = "BODYGUARD", health = 2 }
    local deck = s.locationDecks.byCell.north
    local huntTop = { cardId = "target", instanceId = "bodyguard1", health = 2 }
    deck.drawPile[#deck.drawPile] = huntTop
    deck.revealedTopId = huntTop.instanceId
    assert(Resolution.execute(s, "a", "battlefield", args("bombard")))
    assert(deck.inPlay.bodyguard1 and not deck.inPlay.bodyguard1.engagedAgentId and not s.locationDecks:revealedTop("north"))
    -- Commitments are consumed on failure, but JACL tests never queue Clashes.
    s = setup({ value = 0, special = "auto_failure", clash = { amt = 1, en_dmg = 0, en_bonus = 0 } })
    local committed = args("security"); committed.committedIds = { "card1" }
    s.agentCards.definitions.byId.boost.talents = { { type = committed.testId, qty = 1 } }
    assert(Resolution.execute(s, "a", "battlefield", committed))
    assert(#s.agentCards.byAgent.a.hand == 0 and #s.agentCards.byAgent.a.discardPile == 1)
    assert(require("src.sys.battlefield_clashes").count(s.armies.byCell.center) == 0)
    -- An empty deck is skipped; ordinary tops are not exposed in the scan receipt.
    s = setup(); s.locationDecks.byCell.south.drawPile = {}
    local ok, result = Resolution.execute(s, "a", "battlefield", args("triangulate"))
    assert(ok and #result.scan == 2 and result.scan[1].shuffled and not result.scan[1].card and result.scan[2].empty)
    -- The standard opportunity policy still applies at JACL.
    s = setup(); local d = s.locationDecks.byCell.center
    d.inPlayOrder = { "threat" }; d.inPlay.threat = { instanceId = "threat", cardId = "attacker", engagedAgentId = "a" }
    assert(Resolution.execute(s, "a", "battlefield", args("triangulate")))
    assert(s.agentStatus.byAgent.a.health == 9)
    s = setup(); d = s.locationDecks.byCell.center
    d.inPlayOrder = { "threat" }; d.inPlay.threat = { instanceId = "threat", cardId = "attacker", engagedAgentId = "a" }
    assert(Resolution.execute(s, "a", "battlefield", args("security")))
    assert(s.agentStatus.byAgent.a.health == 10)
    write("jacl_rules_results.txt", "PASS: costs, success/failure, random elite removal, milling, scan roles, JACL exclusion, caps, access, stale/repeated commits and opportunity attacks\n")
end
