return function(write)
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
    local cell = "north"
    local north, center
    for _, hex in ipairs(deploy.grid.cells) do
        if hex.id == cell then north = hex end
        if hex.id == "center" then center = hex end
    end
    clickAt(deploy, north.x, north.y, 2)
    assert(deploy.battlefieldInspectionCell == cell)
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
    local function openAction(kind)
        if not state.actions.open then click(state.actions.button.x + 4, state.actions.button.y + 4) end
        if not state.actions.battlefield then local tab = state.actions:tab(); click(tab.x + 4, tab.y + 4) end
        for _, row in ipairs(state.actions.rows) do if row.id == kind then click(row.x + 4, row.y + 4); return end end
        error("Missing battlefield action")
    end
    local function maneuverButton(key)
        local panel = state.maneuver
        if key:sub(1, 5) == "unit:" then
            for _, slot in ipairs(panel.slots) do
                if slot.unit.id == key:sub(6) then click(slot.x + 10, slot.y + 10); return end
            end
        elseif key:sub(1, 5) == "cell:" then
            for _, cell in ipairs(s.grid.cells) do
                if cell.id == key:sub(6) then click(cell.x, cell.y); return end
            end
        end
        for _, b in ipairs(panel:buttons()) do if b.id == key then click(b.x + 5, b.y + 5); return end end
        error("Missing maneuver button " .. key)
    end
    local function beginManeuver()
        openAction("maneuver"); assert(state.testPanel.card and not state.maneuver.open)
        chooseTest(1); chooseTest("confirm")
        state:update(state.testFeedback.settings.hitTime + 0.175)
        assert(state.testFeedback.outcomeImage and not state.maneuver.open and s.pendingManeuver)
        state:update(4); state:update(4)
        assert(state.maneuver.open and s.pendingManeuver)
    end
    local label
    for _, entry in ipairs(s.armyView.labels) do if entry.cellId == cell then label = entry end end
    state:pointermoved(label.x + 2, label.y + 2); state:update(0.3)
    assert(not state.battlefieldInspectionCell)
    click(label.x + 2, label.y + 2, 2)
    assert(state.battlefieldInspectionCell == cell)
    render("battlefield_inspection.png")
    local army = s.armies.byCell[cell].allied
    local originalForces = army.forces
    army.forces = {}
    for _, forceId in ipairs(s.armies.catalogue.ids) do
        if s.armies.catalogue.byId[forceId].faction == "allied" and #army.forces < 4 then
            army.forces[#army.forces + 1] = { id = "scroll_test:" .. forceId, forceId = forceId }
        end
    end
    render("battlefield_inspection_long.png")
    assert(state.battlefieldScrollMax > 0)
    state:pointermoved(1200, 680); state:update(0.3)
    assert(state.battlefieldInspectionCell == cell)
    local handFirst = state.hand.first
    state:wheelmoved(0, -100)
    assert(state.battlefieldScroll == state.battlefieldScrollMax and state.hand.first == handFirst)
    render("battlefield_inspection_scrolled.png")
    state:wheelmoved(0, 100)
    assert(state.battlefieldScroll == 0)
    army.forces = originalForces
    click(state.done.x + 1, state.done.y + 1)
    assert(not state.battlefieldInspectionCell and state.battlefieldScroll == 0)
    assert(machine.current == state and s.activeAgentId == id)
    openAction("engage"); assert(state.testPanel.battlefieldArgs.battlefieldKind == "engage")
    chooseTest(1); render("battlefield_engage_test.png")
    state:keypressed("escape"); assert(s.agentStatus.byAgent[id].actionPoints == 10 and not state.testPanel.card)
    openAction("entrench"); chooseTest(1); chooseTest("confirm")
    assert(s.armies.byCell[cell].protection == 2 and s.agentStatus.byAgent[id].actionPoints == 9 and not s.attackFeedback)
    require("tests.card_outcome_vfx")(state, render)
    state:update(0.8); render("battlefield_entrench_result.png"); state:update(4)
    local protection = s.armyView:protectionLabel(label)
    assert(protection.text == "P 2" and protection.y < label.y and protection.y >= 0)
    assert(state.actions.open, "Actions remain open after Entrench")
    state:keypressed("escape")
    click(protection.x + 1, protection.y + 1, 2)
    assert(state.battlefieldInspectionCell == cell)
    click(protection.x + 1, protection.y + 1, 2)
    assert(not state.battlefieldInspectionCell)
    local southLabel
    for _, entry in ipairs(s.armyView.labels) do if entry.cellId == "south" then southLabel = entry end end
    local battlefield = require("src.sys.battlefield_state")
    battlefield.entrench(s.armies, "south")
    local southProtection = s.armyView:protectionLabel(southLabel)
    assert(southProtection.text == "P 2" and southProtection.y > southLabel.y
        and southProtection.y + southProtection.height <= s.grid.height)
    render("battlefield_map_protection.png")
    battlefield.damage(s.armies, "south", "allied", 1)
    assert(s.armyView:protectionLabel(southLabel).text == "P 1")
    battlefield.damage(s.armies, "south", "allied", 1)
    assert(not s.armyView:protectionLabel(southLabel))
    beginManeuver()
    local unit = s.armies.byCell[cell].allied.forces[1]
    maneuverButton("unit:" .. unit.id)
    render("battlefield_maneuver_selected.png")
    state:keypressed("escape"); assert(state.maneuver.open and not state.maneuver.unitId)
    maneuverButton("unit:" .. unit.id); maneuverButton("cell:center")
    render("battlefield_maneuver.png")
    assert(state.maneuver.flight and not s.pendingManeuver)
    state:update(0.2); render("battlefield_maneuver_flight.png")
    state:update(1); assert(not state.maneuver.open)
    assert(s.armies.byCell.center.allied.forces[1] == unit and s.armies.byCell[cell].protection == 2)
    -- JACL remains label-free and its forces remain inspectable.
    for _, entry in ipairs(s.armyView.labels) do assert(entry.cellId ~= "center") end
    assert(state.actions.open, "Actions remain open after Maneuver")
    state:keypressed("escape")
    click(center.x, center.y, 2)
    assert(state.battlefieldInspectionCell == "center"); render("battlefield_jacl_inspection.png")
    click(center.x, center.y)
    s.agentDeployment:assign(id, "south"); s.agentView:refresh(); state.exploration:setCell("south")
    beginManeuver(); render("battlefield_maneuver_jacl_indicator.png")
    require("tests.maneuver_markers")(state, render)
    maneuverButton("cell:center"); assert(state.maneuver.mode == "reserve")
    render("battlefield_maneuver_reserves.png")
    maneuverButton("unit:" .. unit.id)
    assert(state.maneuver.flight); state:update(0.2); render("battlefield_reinforcement_flight.png"); state:update(1)
    assert(#s.armies.byCell.center.allied.forces == 0)
    local found = false
    for _, u in ipairs(s.armies.byCell.south.allied.forces) do if u == unit then found = true end end
    assert(found)
    local before = #s.armies.byCell.south.enemy.forces
    -- Keep allies available for the subsequent maneuver UI checks.
    battlefield.entrench(s.armies, "south"); battlefield.entrench(s.armies, "south")
    local south = s.armies.byCell.south
    local incoming = math.floor(south.enemy.value / 2)
    while #south.allied.forces <= incoming - south.protection do
        south.allied.forces[#south.allied.forces + 1] = {
            id = "survivor_test:" .. #south.allied.forces, forceId = s.armies.pools.allied.regular[1],
        }
    end
    battlefield.touch(s.armies, "south")
    local outgoing = math.floor(s.armies.byCell.south.allied.value / 2)
    openAction("engage"); chooseTest(1); chooseTest("confirm")
    assert(#s.armies.byCell.south.enemy.forces == math.max(0, before - outgoing))
    state:update(0.8); render("battlefield_engage_result.png"); state:update(4)
    s.armyView:draw()
    for _, entry in ipairs(s.armyView.labels) do
        if entry.cellId == "south" then assert(entry.enemy == "E " .. s.armies.byCell.south.enemy.value) end
    end
    -- A paid success remains usable at zero AP; scrolling and focus never spend it.
    s.agentStatus.byAgent[id].actionPoints = 1
    beginManeuver()
    assert(s.agentStatus.byAgent[id].actionPoints == 0 and not state:endTurn())
    local panel = state.maneuver
    local savedForces = s.armies.byCell.south.allied.forces
    local extended = {}
    for i = 1, 10 do extended[i] = { id = "tray_test:" .. i, forceId = savedForces[1].forceId } end
    s.armies.byCell.south.allied.forces = extended
    panel:layout()
    local first = panel.slots[1]
    assert(first.width == 176 and first.artHeight == 176)
    state:pointermoved(first.x + 10, first.y + 10)
    local handFirst = state.hand.first
    state:wheelmoved(0, -100)
    assert(panel.scroll == panel.scrollMax and state.hand.first == handFirst)
    render("battlefield_maneuver_scrolled.png")
    state:pointermoved(center.x, center.y); state:wheelmoved(0, 100)
    assert(panel.scroll == panel.scrollMax)
    s.armies.byCell.south.allied.forces = savedForces
    panel.scroll = 0; panel:layout()
    first = panel.slots[1]
    state:mousepressed(first.x + 10, first.y + 10, 1); state:focus(false)
    state:mousereleased(first.x + 10, first.y + 10, 1)
    assert(not panel.unitId and s.pendingManeuver)
    click(first.x + 10, first.y + 10)
    maneuverButton("cell:north") -- Not adjacent to south.
    assert(not panel.flight and s.pendingManeuver)
    state:mousepressed(first.x, first.y, 2)
    assert(not panel.unitId and panel.open)
    maneuverButton("decline")
    assert(not s.pendingManeuver and not panel.open and s.agentStatus.byAgent[id].actionPoints == 0)
    -- Last-AP reinforcement commits once and keeps its tray through arrival.
    s.agentStatus.byAgent[id].actionPoints = 1
    local reinforcing = s.armies.byCell.south.allied.forces[1]
    battlefield.transfer(s.armies, "south", "center", reinforcing.id)
    beginManeuver(); maneuverButton("cell:center")
    panel.reducedMotion = true
    maneuverButton("unit:" .. reinforcing.id)
    assert(panel.flight and panel.flight.reduced and not s.pendingManeuver)
    local revision = s.armies.revision
    state:mousereleased(first.x + 10, first.y + 10, 1); state:keypressed("escape")
    state:focus(false); assert(panel.flight and s.armies.revision == revision)
    state:update(0.2); render("battlefield_maneuver_reduced_motion.png")
    state:update(1); assert(not panel.open and s.armies.revision == revision)
    -- Failure never opens the tray or moves a Force.
    s.agentStatus.byAgent[id].actionPoints = 1
    for i in ipairs(s.fatePool.entries) do s.fatePool.entries[i] = { tileId = "autofail" } end
    openAction("maneuver"); chooseTest(1); chooseTest("confirm")
    state:update(4); state:update(4)
    assert(not s.pendingManeuver and not panel.open and s.armies.revision == revision)
    require("tests.battlefield_engagement")(state, render)
    require("tests.location_milling")(state, render)
    state:exit()
end
