return function(write)
    local actions = require("data.jacl_actions").actions
    local function clickAt(state, x, y, button)
        state:pointermoved(x, y)
        state:mousepressed(x, y, button)
        state:mousereleased(x, y, button)
    end
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deploy = machine.current; deploy:update(2)
    assert(deploy.armies.byCell.center and #deploy.armies.byCell.center.allied.forces == 0)
    for _, label in ipairs(deploy.armyView.labels) do assert(label.cellId ~= "center") end
    local cell = "center"
    local north, center
    for _, hex in ipairs(deploy.grid.cells) do
        if hex.id == "north" then north = hex end
        if hex.id == "center" then center = hex end
    end
    clickAt(deploy, north.x, north.y, 2)
    assert(deploy.battlefieldInspectionCell == "north")
    clickAt(deploy, center.x, center.y, 2)
    assert(not deploy.battlefieldInspectionCell)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local mission = machine.current; mission:update(1)
    local selectedId = mission.session.package.agentIds[1]
    mission.selectedId = selectedId
    clickAt(mission, center.x, center.y, 2)
    assert(mission.battlefieldInspectionCell == "center" and mission.selectedId == selectedId)
    clickAt(mission, mission.panel.x + 1, mission.panel.y + 1, 1)
    assert(not mission.battlefieldInspectionCell and machine.current == mission)
    assert(mission:beginAgentAction())
    local state, s = machine.current, machine.current.session
    state:update(2)
    local id = state.activeAgentId
    s.agentStatus.byAgent[id].actionPoints = 10
    for i in ipairs(s.fatePool.entries) do s.fatePool.entries[i] = { tileId = "autosuccess" } end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); state:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); local encoded = pixels:encode("png")
        write(name, encoded:getString()); encoded:release(); pixels:release(); canvas:release()
    end
    local function click(x, y, button)
        clickAt(state, x, y, button or 1)
    end
    local function chooseTest(key)
        for _, b in ipairs(state.testPanel:buttons()) do if b.id == key then click(b.x + 5, b.y + 5); return end end
        error("Missing talent button")
    end
    local function checkTalents(kind)
        assert(state.testPanel.card)
        local tests, talents = state.testPanel.tests, actions[kind].talents
        assert(#tests == #talents)
        for index, talent in ipairs(talents) do
            assert(tests[index].talent == talent)
        end
    end
    local function openAction(kind)
        if not state.actions.open then click(state.actions.button.x + 4, state.actions.button.y + 4) end
        if not state.actions.battlefield then local tab = state.actions:tab(); click(tab.x + 4, tab.y + 4) end
        for _, row in ipairs(state.actions.rows) do if row.id == kind then click(row.x + 4, row.y + 4); return end end
        error("Missing battlefield action")
    end

    s.huntPresentation = nil
    s.agentStatus.byAgent[id].actionPoints = 20
    openAction("security")
    checkTalents("security")
    render("jacl_security_test.png")
    chooseTest(1); chooseTest("confirm")
    assert(state.actions.open, "Actions panel must stay open after Security")
    assert(s.jaclSecurity == 2 and s.agentStatus.byAgent[id].actionPoints == 19)
    state:update(5); state:update(5)
    openAction("bombard")
    assert(state.actions.targeting and not state.testPanel.card and not state:comparisonModel())
    render("jacl_bombard_targeting.png")
    local locationTab=state.actions:tab("location")
    click(locationTab.x+4,locationTab.y+4)
    assert(state.actions.selectedTab=="location" and not state.actions.targeting)
    local agentTab=state.actions:tab("agent")
    click(agentTab.x+4,agentTab.y+4)
    assert(state.actions.rows[1].id=="move" and not state.actions.battlefield)
    state:keypressed("escape"); assert(s.agentStatus.byAgent[id].actionPoints == 19)
    openAction("bombard")
    click(north.x, north.y)
    assert(state.actions.open and not state.actions.targeting, "Keep panel open but finish Bombard targeting")
    checkTalents("bombard")
    chooseTest(1); chooseTest("confirm")
    assert(s.agentStatus.byAgent[id].actionPoints == 16, tostring(state.testPanel.error))
    assert(state.testFeedback.result.battlefieldKind == "bombard" and state.testFeedback.millingStart)
    state:update(state.testFeedback.settings.hitTime + 0.15); render("jacl_bombard_result.png")
    state:update(10); state:update(10)
    -- Put a real hunt instance on top, preserving all its data and location.
    local huntCard, huntCell
    for cellId, deck in pairs(s.locationDecks.byCell) do
        if cellId ~= "center" then
            for i, card in ipairs(deck.drawPile) do
                if require("src.sys.location_card_traits").hunt(s.locationDecks.pool.byId[card.cardId]) then
                    huntCard, huntCell = card, cellId; table.remove(deck.drawPile, i); table.insert(deck.drawPile, card); break
                end
            end
        end
        if huntCard then break end
    end
    assert(huntCard)
    local jaclDeck, top = s.locationDecks.byCell.center, s.locationDecks.byCell.center.drawPile[#s.locationDecks.byCell.center.drawPile]
    openAction("triangulate")
    checkTalents("triangulate")
    chooseTest(1); chooseTest("confirm")
    assert(s.locationDecks:revealedTop(huntCell) == huntCard and jaclDeck.drawPile[#jaclDeck.drawPile] == top)
    state:update(state.testFeedback.scanStart + 0.2); render("jacl_triangulate_scan.png")
    state:update(10); state:update(10)
    local markers = s.missionFooter.jacl:markers(s)
    assert(#markers > 0)
    state:pointermoved(markers[1].x + 4, markers[1].y + 4)
    assert(s.missionFooter.jacl.hover)
    render("jacl_revealed_top.png")
    local escaped = require("src.sys.mission_hunt").prepareEscape(s)
    if escaped then assert(require("src.sys.mission_hunt").commitEscape(escaped)); assert(not s.locationDecks:revealedTop(huntCell)) end
    state:exit()
    write("jacl_ui_results.txt", "PASS: contextual menu, talent choices, free cancel, Bombard targeting/casualty/mill, scan, revealed-card hover and Security rendering\n")
end
