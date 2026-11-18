return function(write)
    local Status = require("src.sys.agent_status")
    local Turn = require("src.sys.agent_turn")
    local Cards = require("src.sys.agent_cards")
    local defs = { byId = { a = { health = 6, defiance = 6, card_deck = { { card_id = "x", card_qty = 2 } } },
        b = { health = 4, defiance = 3, card_deck = { { card_id = "x", card_qty = 10 } } } } }
    local session = { agentStatus = Status.new({ "a", "b" }, defs, require("data.agent_status_defaults")),
        agentCards = Cards.new({ "a", "b" }, defs, { byId = { x = { name = "X", cost = 0 } } },
            require("data.card_system_defaults"), love.math.newRandomGenerator(1)) }
    assert(not Turn.refreshAll(session))
    assert(Status.exhaust(session.agentStatus, "a"))
    assert(not Turn.refreshAll(session) and not Status.exhaust(session.agentStatus, "a"))
    Status.exhaust(session.agentStatus, "b")
    local b = session.agentCards.byAgent.b
    for _ = 1, 6 do b.hand[#b.hand + 1] = table.remove(b.drawPile) end
    local first = b.hand[1]
    -- A failure halfway through preparation must not refresh any live values.
    session.agentStatus.byAgent.b.actionPointCapacity = -1
    assert(not pcall(Turn.refreshAll, session))
    assert(Status.allExhausted(session.agentStatus) and session.agentStatus.byAgent.a.resources == 5
        and session.agentStatus.byAgent.b.resources == 5 and #session.agentCards.byAgent.a.hand == 0)
    session.agentStatus.byAgent.b.actionPointCapacity = 3
    assert(Turn.refreshAll(session))
    assert(#session.agentCards.byAgent.a.hand == 0 and #session.agentCards.byAgent.a.drawPile == 2)
    assert(#session.agentCards.byAgent.b.hand == 6 and session.agentCards.byAgent.b.hand[1] == first)
    for _, state in pairs(session.agentStatus.byAgent) do
        assert(not state.exhausted and state.resources == 6 and state.actionPoints == state.actionPointCapacity)
    end
    assert(not Turn.refreshAll(session) and session.agentStatus.byAgent.a.resources == 6)

    -- Preparation is read-only; committing twice and rebuilding an active turn never redraw.
    local staged = Turn.prepareActivation(session, "a")
    assert(#staged.hand == 1 and #session.agentCards.byAgent.a.hand == 0)
    Turn.commitActivation(session, "a", staged)
    Turn.commitActivation(session, "a", staged)
    assert(#session.agentCards.byAgent.a.hand == 1)
    assert(#Turn.prepareActivation(session, "a").hand == 1)
    assert(not pcall(Turn.prepareActivation, session, "b"))
    assert(not Turn.finish(session, "b") and Turn.finish(session, "a"))
    assert(not Turn.finish(session, "a") and not pcall(Turn.prepareActivation, session, "a"))

    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy = machine.current
    local fatePool = deploy.fatePool
    deploy:update(2)
    local cell
    for id in pairs(deploy.assignments) do if id ~= "center" then cell = id; break end end
    local locationDecks, locationPool = deploy.locationDecks, deploy.locationCardPool
    local locationCard = locationDecks:draw(cell)
    local remainingLocationCards = #locationDecks.byCell[cell].drawPile
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh()
    assert(deploy:beginAction())
    local action = machine.current
    action:update(1)
    local s, roster = action.session, action.session.roster
    -- Ready publishes detached decks containing the initial hunt distribution.
    locationDecks, locationPool = s.locationDecks, s.locationCardPool
    remainingLocationCards = #locationDecks.byCell[cell].drawPile
    local scene, audio = s.scene, s.audio
    local readyPlays = 0
    local play = audio.playOverlapping
    audio.playOverlapping = function(self, id)
        if id == "ready" then readyPlays = readyPlays + 1 end
        return play(self, id)
    end
    local function click(x, y)
        machine:dispatch("mousepressed", x, y, 1)
        machine:dispatch("mousereleased", x, y, 1)
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    click(action.nextPhase.x + 2, action.nextPhase.y + 2)
    assert(s.agentStatus and not action:nextPhaseRefresh())
    local firstAgent, keptCard, keptAssets
    for index, entry in ipairs(roster.entries) do
        action = machine.current
        click(entry.x + 2, entry.y + 2)
        assert(action.selectedId == entry.id)
        click(action.panel.x + 2, action.panel.y + 2)
        local active = machine.current
        assert(machine.currentName == "agent_action")
        active:update(1)
        local status = s.agentStatus.byAgent[entry.id]
        local dx, dy = active.done.x + 2, active.done.y + 2
        if index == 1 then
            firstAgent = entry.id
            local cardEntry = active.hand.entries[1]
            keptCard = active.hand.cards[2]
            -- Dragging a card onto Done must only cancel the card play.
            machine:dispatch("mousepressed", cardEntry.x + 3, cardEntry.y + 3, 1)
            machine:dispatch("pointermoved", dx, dy)
            machine:dispatch("mousereleased", dx, dy, 1)
            assert(machine.current == active and not status.exhausted)
            local expectedResources = status.resources - s.agentCards.definitions.byId[cardEntry.card.cardId].cost
            -- A normal play leaves resources, hand and asset to preserve through Done.
            machine:dispatch("mousepressed", cardEntry.x + 3, cardEntry.y + 3, 1)
            machine:dispatch("pointermoved", active.equipment.x + 20, active.equipment.y + 20)
            machine:dispatch("mousereleased", active.equipment.x + 20, active.equipment.y + 20, 1)
            assert(status.resources == expectedResources and status.actionPoints == 2)
            -- An already revealed enemy now engages on activation; finish any
            -- opportunity-attack presentation before exercising Done controls.
            if active.feedback:busy() then active:update(2) end
            keptAssets = s.agentAssets.byAgent[entry.id]
            -- Canceled clicks and a failed return preparation leave the turn intact.
            machine:dispatch("mousepressed", dx, dy, 1)
            machine:dispatch("focus", false)
            machine:dispatch("mousereleased", dx, dy, 1)
            assert(machine.current == active)
            machine:dispatch("mousepressed", dx, dy, 1)
            machine:dispatch("mousereleased", 0, 0, 1)
            assert(machine.current == active)
            local originalLoad = love.filesystem.load
            love.filesystem.load = function(path)
                if path == "data/mission_action.lua" then return function() return {} end end
                return originalLoad(path)
            end
            assert(not active:endTurn())
            love.filesystem.load = originalLoad
            assert(not status.exhausted and status.actionPoints == 2 and active.session == s)
        elseif index == 2 then status.actionPoints = 0 end
        click(dx, dy)
        if machine.current == active and active.feedback:busy() then
            assert(s.attackFeedback.kind == "end_turn" and not active:endTurn())
            assert(not Turn.refreshAll(s))
            active:update(20)
        end
        assert(machine.currentName == "mission_action" and status.exhausted and status.actionPoints == 0)
        action = machine.current
        assert(action.session == s and s.scene == scene and s.audio == audio and not action.selectedId)
        assert(s.fatePool == fatePool and #fatePool.entries == 20)
        action:update(0.12)
        click(entry.x + 2, entry.y + 2)
        assert(not action.selectedId and not action:beginAgentAction())
        assert(not s.agentView:hover(entry.x + 2, entry.y + 2))
        assert(s.agentDeployment.placements[entry.id] == cell)
        if index == 1 then
            assert(s.agentCards.byAgent[entry.id].hand[1] == keptCard and s.agentAssets.byAgent[entry.id] == keptAssets)
            render("agent_exhausted.png")
        end
    end
    assert(readyPlays == 0 and Status.allExhausted(s.agentStatus))
    render("next_phase_ready.png")
    assert(action.nextPhase.hovered)
    local before = {}
    for id, state in pairs(s.agentStatus.byAgent) do before[id] = state.resources end
    machine:dispatch("mousepressed", action.nextPhase.x + 2, action.nextPhase.y + 2, 1)
    machine:dispatch("focus", false)
    machine:dispatch("mousereleased", action.nextPhase.x + 2, action.nextPhase.y + 2, 1)
    assert(Status.allExhausted(s.agentStatus))
    machine:dispatch("mousepressed", action.nextPhase.x + 2, action.nextPhase.y + 2, 1)
    machine:dispatch("mousereleased", 0, 0, 1)
    assert(Status.allExhausted(s.agentStatus))
    click(action.nextPhase.x + 2, action.nextPhase.y + 2)
    assert(s.phaseTransition and Status.allExhausted(s.agentStatus) and not action.selectedId)
    action:update(5) -- Includes transport and milling feedback.
    assert(not s.phaseTransition and not Status.allExhausted(s.agentStatus))
    assert(s.locationDecks == locationDecks and s.locationCardPool == locationPool)
    assert(s.fatePool == fatePool)
    assert(#locationDecks.byCell[cell].drawPile == remainingLocationCards
        and locationDecks.byCell[cell].inPlay[locationCard.instanceId] == locationCard)
    for id, state in pairs(s.agentStatus.byAgent) do
        assert(not state.exhausted and state.actionPoints == state.actionPointCapacity and state.resources == before[id] + 1)
        assert(#s.agentCards.byAgent[id].hand == (id == firstAgent and 5 or 6))
        assert(#s.agentCards.byAgent[id].drawPile == 14)
    end
    assert(s.agentCards.byAgent[firstAgent].hand[1] == keptCard and s.agentAssets.byAgent[firstAgent] == keptAssets)
    click(action.nextPhase.x + 2, action.nextPhase.y + 2)
    assert(s.agentStatus.byAgent[firstAgent].resources == before[firstAgent] + 1)
    render("next_phase_refreshed.png")
    assert(not action.nextPhase.hovered)
    click(roster.entries[1].x + 2, roster.entries[1].y + 2)
    assert(action.selectedId == firstAgent)
    local nextButton = action.nextPhase
    click(action.panel.x + 2, action.panel.y + 2)
    assert(machine.currentName == "agent_action" and #s.agentCards.byAgent[firstAgent].hand == 6)
    assert(#s.agentCards.byAgent[firstAgent].drawPile == 13)
    machine:dispatch("mousereleased", 0, 0, 1)
    assert(#s.agentCards.byAgent[firstAgent].hand == 6)

    machine:change("mission_preparation")
    assert(not nextButton.base and not s.agentCards and not s.agentStatus and not s.agentAssets)
    assert(not s.locationDecks and not s.locationCardPool)
    assert(not s.fatePool)
    machine.current:exit()
end
