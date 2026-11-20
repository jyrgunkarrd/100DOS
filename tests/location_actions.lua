return function(write)
    local Resolution = require("src.sys.agent_action_resolution")
    local Reserve = require("src.sys.fate_reserve")
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

    local function setup()
        local s,enemies,door = fixture()
        s.assignments = { west = "loc" }
        s.agentCards.agents.byId.a.talents = {{ type="reason",qty=3 },{ type="passion",qty=3 },{type="steel",qty=2}}
        s.agentStatus.byAgent.a.actionPoints = 40
        s.fatePool.entries = {{tileId="neutral"}}
        return s,enemies,door
    end
    local function clear(s) s.talentFeedback,s.attackFeedback = nil,nil end
    local function request(kind,counts)
        return {locationKind=kind,testId=kind,bonusCounts=counts,random={random=function() return 1 end}}
    end
    local s,enemies = setup()
    local deck = s.locationDecks.byCell.west
    deck.inPlay,deck.inPlayOrder = {},{}
    deck.drawPile = {enemies[1],enemies[2]}
    local ok,r = Resolution.execute(s,"a","location_action",request("charm"))
    assert(ok and r.success and #deck.drawPile==2 and #deck.inPlayOrder==0)
    assert(#s.locationDecks:faceUpCards("west")==2)
    clear(s)
    ok,r = Resolution.execute(s,"a","location_action",request("charm"))
    assert(ok and r.success and #deck.drawPile==0 and #deck.inPlayOrder==2)
    for _,card in pairs(deck.inPlay) do assert(card.exhausted and not card.engagedAgentId) end
    clear(s)
    assert(not Resolution.prepare(s,"a","location_action",request("charm")))
    local before = s.agentStatus.byAgent.a.actionPoints
    ok,r = Resolution.execute(s,"a","location_action",request("ingenuity"))
    assert(ok and r.success and #Reserve.entries(s.fatePool)==1 and #s.fatePool.entries==1)
    assert(s.agentStatus.byAgent.a.actionPoints==before-2)
    clear(s)
    ok,r = Resolution.execute(s,"a","location_action",request("ingenuity",{genius=1}))
    assert(ok and r.success and #Reserve.entries(s.fatePool)==1)
    clear(s)
    Reserve.add(s.fatePool,require("data.fate_tiles.genius"),20,"TEST")
    s.fatePool.entries={{tileId="autofail"}}
    ok,r=Resolution.execute(s,"a","location_action",request("ingenuity",{genius=21}))
    assert(ok and not r.success and #Reserve.entries(s.fatePool)==0 and #s.fatePool.entries==1)
    clear(s)
    Reserve.add(s.fatePool,require("data.fate_tiles.genius"),3)
    local plan=assert(Resolution.prepare(s,"a","location_action",request("ingenuity",{genius=2})))
    assert(#Reserve.entries(s.fatePool)==3) -- preparing/cancelling is read-only
    Reserve.add(s.fatePool,require("data.fate_tiles.genius"),1)
    assert(not Resolution.commit(plan) and #Reserve.entries(s.fatePool)==4)
    assert(not Resolution.prepare(s,"a","location_action",request("ingenuity",{genius=5})))
    -- Mixed CHARM: only the original top two, including one known card.
    s,enemies=setup();deck=s.locationDecks.byCell.west
    deck.inPlay,deck.inPlayOrder={},{}
    deck.drawPile={enemies[1],enemies[2]};deck.revealedTopId=enemies[2].instanceId
    ok,r=Resolution.execute(s,"a","location_action",request("charm"))
    assert(ok and #deck.inPlayOrder==1 and #deck.drawPile==1 and deck.drawPile[1].faceUp)
    local drawn=s.locationDecks:draw("west");assert(drawn and not drawn.faceUp)
    -- Two different bonus types stack alongside cards on an encounter test.
    local door
    s,enemies,door=setup()
    Reserve.add(s.fatePool,require("data.fate_tiles.genius"),2)
    Reserve.add(s.fatePool,{id="insight",name="INSIGHT",value=2,bonus=true},1)
    local card=s.agentCards.byAgent.a.hand[1]
    ok,r=Resolution.execute(s,"a","talent_test",{instanceId=door.instanceId,testId="unlock",
        committedIds={card.instanceId},bonusCounts={genius=2,insight=1},random={random=function() return 1 end}})
    assert(ok and r.success and r.total==8 and #Reserve.entries(s.fatePool)==0)
    -- Paid commitments work on failure, and unaffordable or stale tests spend nothing.
    s,enemies,door = setup()
    local redline = require("data.fate_tiles.redline")
    Reserve.add(s.fatePool, redline, 2)
    s.fatePool.entries = {{tileId="autofail"}}
    local status = s.agentStatus.byAgent.a
    local paid = request("ingenuity", {redline=2})
    status.defiance = 2
    local evaluation, reason = require("src.sys.location_actions").evaluate(s, "a", paid)
    assert(not evaluation and reason == "NOT ENOUGH DEFIANCE FOR BONUS TILES")
    assert(not Resolution.prepare(s, "a", "location_action", paid))
    status.defiance = 3
    plan = assert(Resolution.prepare(s, "a", "location_action", paid))
    assert(status.health == 10 and status.defiance == 3 and #Reserve.entries(s.fatePool) == 2)
    status.health = 9
    assert(not Resolution.commit(plan) and status.defiance == 3 and #Reserve.entries(s.fatePool) == 2)
    -- Retaliation should start at the post-payment stats.
    enemies[1].engagedAgentId = "a"
    ok,r = Resolution.execute(s, "a", "location_action", paid)
    assert(ok and not r.success and r.reserveBonus == 4 and #Reserve.entries(s.fatePool) == 0)
    local hit = s.attackFeedback.events[1]
    assert(hit.beforeHealth == 7 and hit.beforeDefiance == 1)
    assert(status.health == 6 and status.defiance == 0 and status.defeated)
    write("location_actions_results.txt","PASS: CHARM, INGENUITY, unlimited bonus commitments, Glory, stale actions, encounter cards\n")
end
