return function(write)
    local Attack = require("src.sys.attack_resolution")
    local Resolution = require("src.sys.agent_action_resolution")
    local Explore = require("src.sys.location_exploration")
    local Play = require("src.sys.card_play")
    local Status = require("src.sys.agent_status")
    local Turn = require("src.sys.agent_turn")
    local Engagement = require("src.sys.location_engagement")
    local slots = require("data.agent_equipment_slots")
    local function fixture()
        local pool = { byId = { e1 = { name = "FIRST", card_type = "ENEMY", health = 2, damage = 1, trauma = 2 },
            e2 = { name = "SECOND", card_type = "ENEMY", health = 2, damage = 2, trauma = 1 },
            e3 = { name = "NEW", card_type = "ENEMY", health = 2, damage = 9, trauma = 9 }, b = { card_type = "BARRIER" } },
            byType = { ENEMY = { "e1" }, BARRIER = { "b" } } }
        local decks = require("src.sys.location_decks").new({ west = "loc" }, { byId = { loc = { deck_size = 4,
            deck_build = { { type = "ENEMY", qty = 3 }, { type = "BARRIER", qty = 1 } } } } }, pool)
        local deck = decks.byCell.west
        deck.drawPile = { { instanceId = "b", cardId = "b" }, { instanceId = "third", cardId = "e3" },
            { instanceId = "second", cardId = "e2" }, { instanceId = "first", cardId = "e1" } }
        decks:draw("west").engagedAgentId = "a"; decks:draw("west").engagedAgentId = "a"
        local session = { activeAgentId = "a", locationDecks = decks, locationCardPool = pool,
            agentDeployment = { placements = { a = "west", b = "west" } },
            agentStatus = { byAgent = { a = { health = 10, defiance = 10, resources = 5, actionPoints = 3, actionPointCapacity = 3 },
                b = { health = 10, defiance = 10, resources = 5, actionPoints = 3, actionPointCapacity = 3 } } },
            agentAssets = require("src.sys.agent_assets").new({ "a", "b" }, slots),
            agentCards = { definitions = { byId = { asset = { card_type = "ASSET", cost = 1, asset_slots = 1 } } },
                byAgent = { a = { hand = { { instanceId = 1, cardId = "asset" }, { instanceId = 2, cardId = "asset" } } } } }
        }
        return session, session.agentStatus.byAgent.a, deck
    end
    local s, status, deck = fixture()
    local plan = assert(Resolution.prepare(s, "a", "explore", { rules = { actionPointCost = 1 } }))
    assert(status.health == 10 and #deck.drawPile == 2 and status.actionPoints == 3)
    assert(#plan.events == 2 and plan.events[1].instanceId == "first" and plan.events[2].instanceId == "second")
    assert(plan.events[1].health == 9 and plan.events[2].health == 7)
    assert(Resolution.commit(plan) and status.health == 7 and status.defiance == 7 and status.actionPoints == 2)
    assert(deck.inPlay.third.engagedAgentId == "a" and #s.attackFeedback.events == 2)
    assert(not Resolution.commit(plan) and not Explore.commit(s, "a", { actionPointCost = 1 }))
    s.attackFeedback = nil
    local second = assert(Resolution.prepare(s, "a", "play_card", { instanceId = 1, start = 1 }))
    assert(#second.events == 3 and second.events[3].instanceId == "third" and second.status.defeated)
    assert(Resolution.commit(second) and status.health == 0 and status.defiance == 0)
    assert(status.resources == 4 and #s.agentCards.byAgent.a.hand == 1 and s.agentAssets:at("a", 1))
    assert(status.defeatCause == "health_and_defiance" and status.defeatedBy == "third" and not s.activeAgentId)
    assert(Engagement.count(s, "a") == 0 and deck.inPlay.third and #deck.inPlayOrder == 3)
    assert(not Play.commit(s, "a", 2, 2))
    assert(not pcall(Turn.prepareActivation, s, "a"))
    s.attackFeedback = nil; s.agentStatus.byAgent.b.exhausted = true
    assert(Status.allExhausted(s.agentStatus) and Turn.refreshAll(s))
    assert(status.defeated and status.actionPoints == 0 and status.resources == 4)
    Status.defeat(s.agentStatus.byAgent.b)
    assert(Status.allDefeated(s.agentStatus) and not Status.allExhausted(s.agentStatus) and not Turn.refreshAll(s))
    for _, field in ipairs({ "health", "defiance" }) do
        s, status, deck = fixture(); status[field] = 1
        assert(Play.commit(s, "a", 1, 1))
        assert(status[field] == 0 and status.defeated and #s.attackFeedback.events == 1)
        assert(status.defeatCause == field and status.resources == 4 and s.agentAssets:at("a", 1))
    end
    s, status, deck = fixture()
    local original = s.locationDecks.pool.byId.e2.damage
    for _, invalid in ipairs({ -1, 1.5, "2", false, math.huge }) do
        s.locationDecks.pool.byId.e2.damage = invalid
        assert(not pcall(Explore.commit, s, "a", { actionPointCost = 1 }))
        assert(status.health == 10 and status.actionPoints == 3 and #deck.drawPile == 2 and not deck.inPlay.third)
    end
    s.locationDecks.pool.byId.e2.damage = original
    local p1 = assert(Resolution.prepare(s, "a", "explore", { rules = { actionPointCost = 1 } }))
    local p2 = assert(Resolution.prepare(s, "a", "explore", { rules = { actionPointCost = 1 } }))
    assert(Resolution.commit(p1)); s.attackFeedback = nil; assert(not Resolution.commit(p2))
    s, status, deck = fixture()
    local stale = assert(Resolution.prepare(s, "a", "play_card", { instanceId = 1, start = 1 }))
    assert(s.locationDecks:discard("west", "first"))
    assert(not Resolution.commit(stale) and status.health == 10 and #s.agentCards.byAgent.a.hand == 2)
    s, status, deck = fixture(); status.actionPoints = 1
    assert(Play.commit(s, "a", 1, 1) and status.actionPoints == 0 and status.health == 7)
    s, status, deck = fixture()
    assert(Explore.commit(s, "a", { actionPointCost = 2 }) and status.actionPoints == 1 and #s.attackFeedback.events == 2)
    local unchanged, events = Attack.resolve({ health = 4, defiance = 5 }, { { instanceId = "zero" } })
    assert(unchanged.health == 4 and unchanged.defiance == 5 and #events == 1)
    s, status, deck = fixture()
    assert(not Play.commit(s, "a", 1, 99) and not s.attackFeedback and status.health == 10)
    local rules = require("data.attack_rules")
    rules.provokingActions.explore = false
    assert(Explore.commit(s, "a", { actionPointCost = 1 }) and status.health == 10 and not s.attackFeedback)
    rules.provokingActions.explore = true

    -- Ending a turn attacks once per ready engaged enemy, even with no AP.
    s, status, deck = fixture(); status.actionPoints = 0
    local ending = assert(Resolution.prepare(s, "a", "end_turn", {}))
    assert(status.health == 10 and not status.exhausted and s.activeAgentId == "a")
    assert(Resolution.commit(ending))
    assert(status.health == 7 and status.defiance == 7 and status.exhausted and status.actionPoints == 0)
    assert(not s.activeAgentId and s.attackFeedback.kind == "end_turn" and #s.attackFeedback.events == 2)
    assert(not Turn.finish(s, "a") and not Resolution.commit(ending) and not Turn.refreshAll(s))
    s, status, deck = fixture()
    deck.inPlay.first.exhausted = true; deck.inPlay.second.engagedAgentId = "b"
    assert(Turn.finish(s, "a") and status.health == 10 and not s.attackFeedback and status.exhausted)
    s, status, deck = fixture(); status.health = 1
    assert(Turn.finish(s, "a") and status.defeated and status.health == 0)
    assert(#s.attackFeedback.events == 1 and Engagement.count(s, "a") == 0)

    -- Real UI: committed damage is independent of timers, focus, and input.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deployment = machine.current; deployment:update(2)
    local cell = next(deployment.assignments)
    for _, id in ipairs(deployment.package.agentIds) do deployment.agentDeployment:assign(id, cell) end
    deployment.agentView:refresh(); assert(deployment:beginAction()); machine.current:update(1)
    local mission = machine.current; local session = mission.session
    local id = session.package.agentIds[1]
    mission.selectedId = id; assert(mission:beginAgentAction())
    local active = machine.current; active:update(1)
    local state = session.agentStatus.byAgent[id]
    state.health, state.defiance = 6, 6 -- Deterministic combat fixture regardless of the selected Agent.
    for n = 1, 3 do
        local pile = session.locationDecks.byCell[cell].drawPile
        for i, card in ipairs(pile) do
            if session.locationCardPool.byId[card.cardId].card_type == "ENEMY" then
                pile[i], pile[#pile] = pile[#pile], card; break
            end
        end
        session.locationDecks:draw(cell).engagedAgentId = id
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    assert(active:explore())
    assert(state.health == 3 and state.defiance == 3 and active.feedback:busy())
    assert(active.feedback:status(state).health == 6)
    assert(not active:explore() and not active:endTurn() and not Turn.finish(session, id))
    local button = active.actions.button
    active:mousepressed(button.x + 2, button.y + 2, 1); active:mousereleased(button.x + 2, button.y + 2, 1)
    active:keypressed("escape"); active:focus(false)
    active:update(0.3)
    assert(active.feedback:status(state).health == 5 and state.health == 3)
    render("opportunity_attack_first.png")
    -- Presentation-only changes must never alter committed combat results.
    local cutin = active.feedback.cutin
    assert(cutin:pose(active.feedback).impact == 1)
    assert(not cutin:defeatPose(active.feedback), "Nonlethal damage must not dissolve the Agent")
    local elapsed = active.feedback.elapsed
    active.feedback.elapsed = 0.45
    render("attack_cutin_readout.png")
    cutin.settings.reducedMotion = true
    local pose = cutin:pose(active.feedback)
    assert(pose.enemyOffset == 0 and pose.agentOffset == 0 and pose.shake == 0 and pose.impact == 0)
    render("attack_cutin_reduced_motion.png")
    local preview, portrait = cutin.preview, cutin.portrait
    cutin.preview, cutin.portrait = nil, nil
    local canvas = love.graphics.newCanvas(640, 360)
    love.graphics.setCanvas(canvas); love.graphics.clear()
    active.feedback:draw(640, 360, session.scene.accents.heading)
    love.graphics.setCanvas(); canvas:release()
    cutin.preview, cutin.portrait = preview, portrait
    cutin.settings.reducedMotion = false
    active.feedback.elapsed = 0.8
    local nextPose = cutin:pose(active.feedback)
    assert(nextPose.index == 2 and nextPose.agentOffset == 0 and nextPose.enemyOffset < 0)
    active.feedback.elapsed = elapsed
    assert(state.health == 3 and state.defiance == 3)
    active:update(0.8); assert(active.feedback:status(state).health == 4)
    render("opportunity_attack_second.png")
    active:update(20); assert(not active.feedback:busy() and state.health == 3 and not session.attackFeedback)
    -- Dragged card play uses the same transaction and sequence as Explore.
    state.health, state.defiance = 8, 8
    local attackers = Engagement.count(session, id)
    local handEntry = active.hand.entries[1]
    local handCount = #active.hand.cards
    local expectedResources = state.resources - session.agentCards.definitions.byId[handEntry.card.cardId].cost
    active:mousepressed(handEntry.x + 3, handEntry.y + 3, 1)
    active:pointermoved(active.equipment.x + 20, active.equipment.y + 20)
    active:mousereleased(active.equipment.x + 20, active.equipment.y + 20, 1)
    assert(active.feedback:busy() and #active.hand.cards == handCount - 1 and state.health == 8 - attackers)
    assert(state.resources == expectedResources and state.actionPoints == 1)
    active:mousereleased(active.equipment.x + 20, active.equipment.y + 20, 1)
    assert(#active.hand.cards == handCount - 1)
    active:update(20)
    -- A failed defeat return preparation must roll back the entire proposed action.
    state.health = 1
    local beforePile = #session.locationDecks.byCell[cell].drawPile
    local beforePoints = state.actionPoints
    local load = love.filesystem.load
    love.filesystem.load = function(path)
        if path == "data/mission_action.lua" then return function() return {} end end
        return load(path)
    end
    assert(not active:explore())
    love.filesystem.load = load
    assert(state.health == 1 and state.actionPoints == beforePoints and #session.locationDecks.byCell[cell].drawPile == beforePile)
    assert(active:explore() and state.defeated and state.health == 0)
    assert(#session.attackFeedback.events == 1 and Engagement.count(session, id) == 0)
    active:update(0.3); render("agent_defeated.png")
    assert(not active.feedback.cutin:defeatPose(active.feedback))
    active:update(active.feedback.cutin.settings.impactDuration + 0.09)
    local defeat = active.feedback.cutin:defeatPose(active.feedback)
    assert(defeat and defeat.sweep > 0 and defeat.sweep < 1 and defeat.contentAlpha == 1)
    render("agent_defeat_sweep.png")
    active.feedback.cutin.settings.reducedMotion = true
    render("agent_defeat_sweep_reduced.png")
    active.feedback.cutin.settings.reducedMotion = false
    active:update(0.27)
    defeat = active.feedback.cutin:defeatPose(active.feedback)
    assert(defeat.contentAlpha == 0 and defeat.frameAlpha == 0)
    render("agent_defeat_faded.png")
    active:update(20); assert(machine.currentName == "mission_action" and not session.attackFeedback)
    mission = machine.current; mission:update(1)
    assert(not session.agentView:hover(session.roster.entries[1].x + 2, session.roster.entries[1].y + 2))
    mission.selectedId = id; assert(not mission:beginAgentAction()); mission.selectedId = nil
    render("mission_agent_defeated.png")
    -- Lethal end-of-turn attacks also finish the cut-in before handing back the session.
    local nextId = session.package.agentIds[2]
    mission.selectedId = nextId; assert(mission:beginAgentAction())
    active = machine.current; active:update(1)
    local nextState = session.agentStatus.byAgent[nextId]
    nextState.health, nextState.actionPoints = 1, 0
    assert(Engagement.count(session, nextId) > 0)
    assert(active:endTurn() and nextState.defeated and machine.current == active)
    assert(active.turnReturn and session.attackFeedback.kind == "end_turn")
    assert(not active:endTurn() and not Turn.refreshAll(session))
    active:update(20)
    assert(machine.currentName == "mission_action" and not session.attackFeedback and not active.turnReturn)
    mission = machine.current; mission:update(1)
    for _, agentId in ipairs(session.package.agentIds) do
        local record = session.agentStatus.byAgent[agentId]
        if not record.defeated then record.exhausted = true; record.actionPoints = 0 end
    end
    assert(mission:nextPhaseRefresh() and state.defeated and state.actionPoints == 0)
    mission:update(5)
    for _, record in pairs(session.agentStatus.byAgent) do record.health = 0; Status.defeat(record) end
    assert(not mission:nextPhaseRefresh()); render("mission_all_defeated.png")
    machine:change("mission_preparation"); machine.current:exit()
end
