return function(write)
    local Basic = require("src.sys.agent_basic_actions")
    local Resolution = require("src.sys.agent_action_resolution")
    local Topology = require("src.sys.board_topology")
    local Cards = require("src.sys.agent_cards")
    local function fixture()
        local assignments = { center = "home", north = "neighbour", east = "distant" }
        local deployment = require("src.sys.agent_deployment").new({ "a", "b" }, assignments)
        deployment:assign("a", "center"); deployment:assign("b", "north")
        local cards = setmetatable({ byAgent = { a = { hand = {}, discardPile = {}, drawPile = {
            { instanceId = 1, cardId = "one" }, { instanceId = 2, cardId = "two" } } } } }, Cards)
        local status = { health = 10, defiance = 10, resources = 5, actionPoints = 3 }
        local s = { activeAgentId = "a", grid = { cells = require("data.deployment_board").cells }, assignments = assignments,
            agentDeployment = deployment, agentCards = cards, agentStatus = { byAgent = { a = status } },
            locationDecks = { pool = { byId = { enemy = { card_type = "ENEMY", damage = 2, trauma = 1 } } },
                byCell = { center = { revision = 0, inPlay = {}, inPlayOrder = {} } } } }
        return s, status
    end
    local function execute(s, kind, args) return Resolution.execute(s, "a", kind, args or {}) end
    local function engage(s)
        local deck = s.locationDecks.byCell.center
        deck.inPlay.e = { instanceId = "e", cardId = "enemy", engagedAgentId = "a" }
        deck.inPlayOrder = { "e" }; deck.revision = deck.revision + 1
        return deck.inPlay.e
    end
    local s, status = fixture()
    assert(#Topology.locations(s, "center") == 1)
    for _, id in ipairs({ "center", "east", "south", "missing" }) do
        assert(not execute(s, "move", { cellId = id }))
        assert(status.actionPoints == 3 and s.agentDeployment.placements.a == "center")
    end
    assert(not execute(s, "move"))
    assert(execute(s, "move", { cellId = "north" })) -- Occupied locations remain legal.
    assert(s.agentDeployment.placements.a == "north" and s.agentDeployment.placements.b == "north")
    assert(execute(s, "move", { cellId = "center" }))
    assert(execute(s, "move", { cellId = "north" }) and status.actionPoints == 0)
    assert(not execute(s, "move", { cellId = "center" }))
    s, status = fixture(); s.assignments.north = nil
    assert(Basic.evaluate(s, "a", "move").reason == "No adjacent locations")
    s, status = fixture(); local enemy = engage(s)
    assert(Basic.evaluate(s, "a", "move").reason == "Engaged with an enemy")
    assert(not execute(s, "move", { cellId = "north" }) and status.actionPoints == 3)
    enemy.engagedAgentId = nil
    local movement = assert(Resolution.prepare(s, "a", "move", { cellId = "north" }))
    enemy.engagedAgentId = "a" -- Even without a revision bump, commit rechecks movement eligibility.
    assert(not Resolution.commit(movement) and status.actionPoints == 3)
    enemy.engagedAgentId = nil
    assert(execute(s, "move", { cellId = "north" }))
    s, status = fixture()
    assert(execute(s, "draw_card") and execute(s, "draw_card"))
    assert(#s.agentCards.byAgent.a.hand == 2 and status.actionPoints == 1)
    assert(not execute(s, "draw_card") and status.actionPoints == 1)
    s, status = fixture()
    local draw = assert(Resolution.prepare(s, "a", "draw_card", {}))
    s.agentCards:commitHand("a", s.agentCards:prepareDraw("a", 1))
    assert(not Resolution.commit(draw) and status.actionPoints == 3)
    draw = assert(Resolution.prepare(s, "a", "draw_card", {}))
    table.remove(s.agentCards.byAgent.a.drawPile)
    assert(not Resolution.commit(draw) and status.actionPoints == 3)
    s, status = fixture()
    for _ = 1, 3 do assert(execute(s, "gain_resource")) end
    assert(status.resources == 8 and status.actionPoints == 0 and not execute(s, "gain_resource"))
    s, status = fixture()
    local gain = assert(Resolution.prepare(s, "a", "gain_resource", {}))
    assert(Resolution.commit(gain) and not Resolution.commit(gain) and status.resources == 6)
    for _, kind in ipairs({ "draw_card", "gain_resource" }) do
        s, status = fixture(); engage(s); status.actionPoints = 1
        assert(execute(s, kind) and status.actionPoints == 0 and status.health == 8)
        assert(#s.attackFeedback.events == 1 and not execute(s, kind))
        s, status = fixture(); engage(s); status.health = 1
        assert(execute(s, kind) and status.defeated and not s.activeAgentId)
        assert(kind == "draw_card" and #s.agentCards.byAgent.a.hand == 1 or kind == "gain_resource" and status.resources == 6)
        s, status = fixture(); engage(s); s.locationDecks.pool.byId.enemy.damage = -1
        assert(not pcall(execute, s, kind) and status.actionPoints == 3 and status.resources == 5 and #s.agentCards.byAgent.a.hand == 0)
    end
    s, status = fixture(); s.talentFeedback = {}
    assert(not execute(s, "gain_resource")); s.talentFeedback = nil
    s.activeAgentId = "b"; assert(not execute(s, "draw_card"))
    local definitions = require("data.agent_basic_actions")
    local cost = definitions[1].actionPointCost; definitions[1].actionPointCost = -1
    assert(not pcall(Basic.definitions)); definitions[1].actionPointCost = cost

    -- Exercise real state input, movement views, cancellation, and combat feedback.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deployment = machine.current; deployment:update(2)
    local from, target
    for _, cell in ipairs(deployment.grid.cells) do
        if deployment.assignments[cell.id] then
            local neighbours = Topology.locations(deployment, cell.id)
            if #neighbours > 0 then from, target = cell.id, neighbours[1]; break end
        end
    end
    assert(from and target)
    for _, id in ipairs(deployment.package.agentIds) do deployment.agentDeployment:assign(id, from) end
    deployment.agentView:refresh(); assert(deployment:beginAction())
    local mission = machine.current; mission:update(1)
    mission.selectedId = mission.session.package.agentIds[1]
    -- A card type absent from the opening hand must still have a prepared preview after a paid draw.
    local cards = mission.session.agentCards
    local pile = cards.byAgent[mission.selectedId].drawPile
    local definition = {}; for k, v in pairs(cards.definitions.byId[pile[1].cardId]) do definition[k] = v end
    cards.definitions.byId.basic_draw_test = definition
    pile[#pile - 1].cardId = "basic_draw_test"
    assert(mission:beginAgentAction())
    local active = machine.current; s = active.session
    local id = active.activeAgentId; status = s.agentStatus.byAgent[id]
    assert(not active:basicAction("gain_resource")); active:update(1)
    local p = active.actions
    local function click(x, y) active:mousepressed(x, y, 1); active:mousereleased(x, y, 1) end
    local function row(i) local r = p.rows[i]; click(r.x + 5, r.y + 5) end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); active:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    local ap = status.actionPoints
    active:mousepressed(p.button.x + 3, p.button.y + 3, 1); active:focus(false)
    active:mousereleased(p.button.x + 3, p.button.y + 3, 1); assert(not p.open)
    click(p.button.x + 3, p.button.y + 3); assert(p.open)
    render("agent_basic_actions.png")
    row(1); assert(p.targeting and status.actionPoints == ap)
    render("agent_move_targets.png")
    active:keypressed("escape"); assert(not p.open and status.actionPoints == ap)
    local entry = s.agentView.byId[id]; click(entry.x + 4, entry.y + 4); assert(p.open)
    row(1); click(640, 500); assert(p.targeting and status.actionPoints == ap)
    local destination
    for _, cell in ipairs(s.grid.cells) do if cell.id == target then destination = cell end end
    local departure = s.agentView.byId[id]
    click(destination.x, destination.y)
    assert(s.agentDeployment.placements[id] == target and active.exploration.cell == target)
    assert(s.agentView.byId[id].cellId == target and status.actionPoints == ap - 1 and p.open and not p.targeting)
    local view = s.agentView
    local startPose = view:movementPose(view.byId[id])
    assert(startPose.x == departure.x and startPose.y == departure.y)
    active:update(active.settings.movementDuration / 2)
    local midpoint = view:movementPose(view.byId[id])
    local arrival = view.byId[id]
    assert(midpoint.x ~= departure.x or midpoint.y ~= departure.y)
    assert(midpoint.x ~= arrival.x or midpoint.y ~= arrival.y)
    assert(view:hit(midpoint.x + 25, midpoint.y + 25).id == id)
    render("agent_move_midpoint.png")
    active:update(1)
    assert(not view.movement and view:movementPose(arrival) == arrival and status.actionPoints == ap - 1)
    active:mousereleased(destination.x, destination.y, 1); assert(status.actionPoints == ap - 1)
    local handCount = #s.agentCards.byAgent[id].hand
    row(2); assert(#s.agentCards.byAgent[id].hand == handCount + 1 and #active.hand.cards == handCount + 1)
    assert(active.preview.displays.basic_draw_test and active.hand.images.basic_draw_test ~= nil)
    local resources = status.resources
    row(3); assert(status.resources == resources + 1 and status.actionPoints == 0 and p.open)
    row(3); assert(status.resources == resources + 1)
    render("agent_basic_actions_spent.png")
    active:keypressed("escape"); status.actionPoints = 3
    -- Rapid consecutive moves start from the current visible pose without a snap.
    assert(active:basicAction("move", { cellId = from }))
    active:update(active.settings.movementDuration / 3)
    local interrupted = view:movementPose(view.byId[id])
    assert(active:basicAction("move", { cellId = target }))
    local continued = view:movementPose(view.byId[id])
    assert(interrupted.x == continued.x and interrupted.y == continued.y)
    active:focus(false); assert(view.movement and s.agentDeployment.placements[id] == target)
    active:update(1); assert(not view.movement and status.actionPoints == 1)
    local duration = active.settings.movementDuration
    active.settings.movementDuration = 0
    assert(active:basicAction("move", { cellId = from }) and not view.movement)
    status.actionPoints = 1
    assert(active:basicAction("move", { cellId = target }) and not view.movement)
    active.settings.movementDuration = duration; status.actionPoints = 3
    active:mousepressed(active.done.x + 2, active.done.y + 2, 1)
    active:keypressed("a"); active:mousereleased(active.done.x + 2, active.done.y + 2, 1)
    assert(machine.current == active and p.open); active:keypressed("escape")
    local card = active.hand.entries[1]
    active:mousepressed(card.x + 2, card.y + 2, 1)
    assert(not active:basicAction("gain_resource")); active:keypressed("a"); assert(not p.open)
    active:focus(false)
    active.testPanel.card = {}; assert(not active:basicAction("draw_card")); active.testPanel:close()
    -- Reveal an enemy to check the panel through a committed attack and defeat.
    local deck = s.locationDecks.byCell[target]
    local enemyId
    for _, cardId in ipairs(s.locationCardPool.ids) do
        if s.locationCardPool.byId[cardId].card_type == "ENEMY" then enemyId = cardId; break end
    end
    assert(enemyId)
    local attacker = { instanceId = "basic-action-attacker", cardId = enemyId, engagedAgentId = id, health = 3 }
    deck.inPlay[attacker.instanceId] = attacker; deck.inPlayOrder[#deck.inPlayOrder + 1] = attacker.instanceId
    deck.revision = deck.revision + 1
    active:keypressed("a"); assert(p.open)
    row(1); assert(not p.targeting and status.actionPoints == 3)
    render("agent_basic_actions_engaged.png")
    row(3); assert(active:resolving() and status.resources == resources + 2)
    assert(not active:basicAction("draw_card"))
    active:keypressed("escape"); assert(s.attackFeedback and status.resources == resources + 2)
    active:update(20); assert(not active:resolving())
    status.health = 1; status.defiance = 1
    assert(active:basicAction("gain_resource")); assert(status.defeated)
    active:update(20); assert(machine.current ~= active)
    machine.current:exit()
    cards.definitions.byId.basic_draw_test = nil
end
