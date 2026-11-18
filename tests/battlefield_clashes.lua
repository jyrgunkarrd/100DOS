return function(write)
    local Clashes = require("src.sys.battlefield_clashes")
    local Resolution = require("src.sys.agent_action_resolution")
    local State = require("src.sys.battlefield_state")
    local Turn = require("src.sys.agent_turn")
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy, cell = machine.current, "north"
    deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh()
    assert(deploy:beginAction())
    local mission = machine.current
    mission:update(1)
    mission.selectedId = mission.session.package.agentIds[1]
    assert(mission:beginAgentAction())
    local state, s = machine.current, machine.current.session
    state:update(2)
    local id, pair = state.activeAgentId, s.armies.byCell[cell]
    local status = s.agentStatus.byAgent[id]
    for _, side in ipairs({ "allied", "enemy" }) do
        local forceId = assert(s.armies.pools[side].regular[1])
        pair[side].forces = { { id = "clash-" .. side, forceId = forceId } }
    end
    State.touch(s.armies, cell)
    local function fate(tileId)
        s.fatePool.entries = { { tileId = tileId } }
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); state:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        local encoded = pixels:encode("png")
        write(name, encoded:getString()); encoded:release(); pixels:release(); canvas:release()
    end
    local function clickButton(buttonId)
        for _, button in ipairs(state.testPanel:buttons()) do
            if button.id == buttonId then
                local x, y = button.x + 5, button.y + 5
                state:mousepressed(x, y, 1); state:mousereleased(x, y, 1)
                return
            end
        end
        error("Missing button " .. tostring(buttonId))
    end
    local function playClash(tileId)
        fate(tileId)
        clickButton(1)
        clickButton("confirm")
        assert(state.testFeedback:busy() and not state.testPanel.card and not state:endTurn())
        return assert(s.talentFeedback)
    end
    local function finishFeedback()
        state:update(state.testFeedback.settings.stepDuration + 0.1)
    end

    fate("brutality")
    local testId = require("src.sys.battlefield_tests").resolve(s.locations.byId[s.assignments[cell]])[1].id
    assert(state:performAction("battlefield", { battlefieldKind = "entrench", testId = testId }))
    assert(Clashes.count(pair) == 1 and state.testFeedback.fateImage)
    state:update(state.testFeedback.settings.hitTime + 0.1)
    render("clash_fate.png")
    finishFeedback()

    pair.protection = 1
    Clashes.enqueue(pair, Clashes.prepareBatch("other", { amt = 2, en_bonus = 3 }))
    local label
    for _, entry in ipairs(s.armyView.labels) do if entry.cellId == cell then label = entry end end
    local clashLabel = s.armyView:clashLabel(label)
    local protectionLabel = s.armyView:protectionLabel(label)
    assert(clashLabel.text == "C 3" and clashLabel.y == protectionLabel.y and clashLabel.x < protectionLabel.x)
    Clashes.enqueue(s.armies.byCell.south, Clashes.prepareBatch("large", { amt = 1234 }))
    Clashes.enqueue(s.armies.byCell.center, Clashes.prepareBatch("reserve", { amt = 2 }))
    -- Even an old/injected JACL Clash must not produce a map marker.
    assert(not s.armyView.jaclClash)
    for _, entry in ipairs(s.armyView.labels) do assert(entry.cellId ~= s.armies.jaclCellId) end
    render("clash_map.png")
    state:mousepressed(clashLabel.x + 1, clashLabel.y + 1, 2)
    assert(state.battlefieldInspectionCell == cell)
    state:mousereleased(clashLabel.x + 1, clashLabel.y + 1, 2)
    state:mousepressed(clashLabel.x + 1, clashLabel.y + 1, 2)
    state:mousereleased(clashLabel.x + 1, clashLabel.y + 1, 2)
    assert(not state.battlefieldInspectionCell)

    local deck = s.locationDecks.byCell[cell]
    local attacker
    repeat
        attacker = assert(s.locationDecks:draw(cell))
    until s.locationDecks.pool.byId[attacker.cardId].card_type == "ENEMY"
    attacker.engagedAgentId = id
    status.actionPoints = 0
    local health = status.health
    assert(state:endTurn() and not status.exhausted and not s.attackFeedback)
    assert(not state:endTurn() and not Turn.finish(s, id))
    assert(not Resolution.prepare(s, id, "gain_resource", {}))
    local oldHead = pair.clashes[1]
    assert(state.testPanel.battlefieldArgs.clash == oldHead)
    for _, button in ipairs(state.testPanel:buttons()) do assert(button.id ~= "cancel") end
    state:keypressed("escape"); state:mousepressed(0, 0, 2)
    assert(state.testPanel.card and Clashes.count(pair) == 3)
    render("clash_required_test.png")
    clickButton(1)
    local chosenTest = state.testPanel.test
    state:keypressed("f")
    assert(state.fatePoolInspection and state.testPanel.test == chosenTest)
    state:keypressed("escape")
    assert(not state.fatePoolInspection and state.testPanel.test == chosenTest and Clashes.count(pair) == 3)

    local first = playClash("brutality")
    assert(first.clash and first.difficulty == first.test.printed + 1 and first.sides.allied.damage == 1)
    assert(first.sides.allied.absorbed == 1 and Clashes.count(pair) == 3)
    assert(pair.clashes[1].tileId == "other" and pair.clashes[2].tileId == "brutality")
    assert(status.actionPoints == 0 and status.health == health and not status.exhausted)
    state:update(state.testFeedback.settings.hitTime + 0.1)
    render("clash_exchange.png")
    finishFeedback()
    assert(not Resolution.prepare(s, id, "battlefield", { battlefieldKind = "engage", testId = testId, clash = oldHead }))

    for remaining = 2, 1, -1 do
        local nextResult = playClash("autosuccess")
        assert(nextResult.success and nextResult.difficulty == nextResult.test.printed + 3)
        assert(nextResult.sides.allied.damage == 0 and Clashes.count(pair) == remaining)
        assert(state.testFeedback.fateImage and nextResult.fate.name == "CONVICTION" and nextResult.fate.value == nil)
        finishFeedback()
    end

    s.fatePool.definitions.unillustrated = { name = "UNILLUSTRATED", img = true, value = 1,
        negative = true, clash = { amt = 1 } }
    local last = playClash("unillustrated")
    assert(last.difficulty == last.test.printed + 1 and last.sides.allied.defeated)
    assert(not state.testFeedback.fateImage and last.modifier == -1)
    state:update(state.testFeedback.settings.hitTime + 0.1)
    render("clash_missing_fate_art.png")
    assert(Clashes.count(pair) == 1 and not s.attackFeedback)
    finishFeedback()
    assert(status.exhausted and not s.pendingEndTurn and s.attackFeedback.kind == "end_turn")
    assert(#s.attackFeedback.events == 1 and Clashes.count(pair) == 1)
    state:update(4)
    assert(machine.current == mission and mission.session.armies.byCell[cell] == pair)
    assert(Clashes.count(mission.session.armies.byCell.south) == 1234 and Clashes.count(pair) == 1)
    mission:exit()
end
