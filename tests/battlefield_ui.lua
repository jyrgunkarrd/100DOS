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
    local north, center, southHex
    for _, hex in ipairs(deploy.grid.cells) do
        if hex.id == cell then north = hex end
        if hex.id == "center" then center = hex end
        if hex.id == "south" then southHex = hex end
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
        if not name then canvas:release(); return end
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
    local army = s.armies.byCell[cell].allied
    local originalForces = army.forces
    army.forces = { { id = "inspection-tank", forceId = "elite_abrams" } }
    assert(s.armyView:protectionLabel(label).text == "P 1")
    render("battlefield_inspection.png")
    local enemy = s.armies.byCell[cell].enemy
    local originalEnemies = enemy.forces
    enemy.forces = {
        { id = "inspection-enemy-1", forceId = "reg_synthwasp" },
        { id = "inspection-enemy-2", forceId = "reg_synthwasp" },
    }
    army.forces = { { id = "inspection-hmmwv", forceId = "reg_hmmvv" } }
    render()
    local layout = state.battlefieldInspectionLayout
    assert(#layout.rows == 2, "Duplicate enemy Forces should share a row")
    local wasp, hmmwv = layout.rows[1], layout.rows[2]
    state:pointermoved(wasp.x + 1, wasp.y + 1)
    local preview = state.battlefieldForcePreview.view
    assert(preview.cardId == "reg_synthwasp" and preview.displays[preview.cardId].type == "REGULAR")
    state:pointermoved(hmmwv.x + 1, hmmwv.y + hmmwv.height - 12)
    assert(preview.cardId == "reg_hmmvv" and preview.x >= layout.panel.x + layout.panel.width)
    assert(preview.artPaths[preview.cardId] == "assets/images/forces/reg_hummer.png")
    assert(preview.images[preview.artPaths[preview.cardId]])
    local display = preview.displays[preview.cardId]
    assert(display.stats[1].value == s.armies.rules.strength.regular and display.paragraphs[1].text:find("This effect stacks", 1, true))
    render()
    state:focus(false)
    assert(not preview.cardId and state.battlefieldInspectionCell == cell)
    enemy.forces = originalEnemies
    army.forces = {}
    for _, forceId in ipairs(s.armies.catalogue.ids) do
        if s.armies.catalogue.byId[forceId].faction == "allied" and #army.forces < 4 then
            army.forces[#army.forces + 1] = { id = "scroll_test:" .. forceId, forceId = forceId }
        end
    end
    render("battlefield_inspection_long.png")
    assert(state.battlefieldScrollMax > 0)
    local viewport = state.battlefieldInspectionLayout.viewport
    local firstRow = state.battlefieldInspectionLayout.rows[#state.battlefieldInspectionLayout.rows - #army.forces + 1]
    state:pointermoved(firstRow.x + 1, viewport.y + 1)
    assert(preview.cardId == firstRow.id)
    state:wheelmoved(0, -100)
    assert(preview.cardId and preview.cardId ~= firstRow.id, "Scrolling should refresh the hovered Force")
    state:pointermoved(firstRow.x + 1, viewport.y - 1)
    assert(not preview.cardId, "Clipped portions should not receive hover")
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
    local battlefield = require("src.sys.battlefield_state")
    army.forces = { { id = "preview-tank", forceId = "elite_abrams" } }
    enemy.forces = { { id = "preview-pazervore", forceId = "elite_synthvor" } }
    battlefield.touch(s.armies, cell)
    openAction("engage"); assert(state.testPanel.battlefieldArgs.battlefieldKind == "engage")
    local panel = state.testPanel
    local projection = assert(panel:engagementProjection()).effect
    assert(projection.removedId == "preview-tank" and projection.protectionBefore == projection.protectionAfter + 1)
    assert(projection.sourceForceId == "elite_synthvor" and projection.addedForceId == "reg_synthwasp"
        and projection.removedForceId == "elite_abrams")
    assert(panel:reserveBounds().y == panel.y + panel.settings.reserveTop + panel.settings.engagementEffectHeight)
    assert(panel.y + panel.height <= state.height)
    render()
    local effectView = assert(panel.engagementPreview)
    for _, forceId in ipairs({ projection.removedForceId, projection.addedForceId, projection.sourceForceId }) do
        local width, height = effectView.portraits:dimensions(forceId)
        assert(width == panel.settings.engagementEffectPortraitSize and height == width)
    end
    local hold, fade = panel.settings.engagementEffectHold, panel.settings.engagementEffectFade
    assert(effectView.waspOpacity(0, hold, fade) == 0 and effectView.waspOpacity(hold + fade, hold, fade) == 1)
    local midpoint = hold + fade / 2
    assert(math.abs(effectView.waspOpacity(midpoint, hold, fade) - 0.5) < 0.001)
    assert(math.abs(effectView.waspOpacity(2 * (hold + fade) - fade / 2, hold, fade) - 0.5) < 0.001)
    panel:update(hold + fade)
    panel:pointermoved(panel.x + panel.width / 4 + 7, panel.y + panel.settings.engagementEffectTop + 24)
    render()
    assert(effectView.card.view.cardId == "reg_synthwasp")
    local hoveredAge = effectView.elapsed
    panel:update(0.5)
    assert(effectView.elapsed == hoveredAge, "Hover should hold the visible portrait")
    panel:pointermoved(panel.x + panel.width * 3 / 4 - 7, panel.y + panel.settings.engagementEffectTop + 24)
    render()
    assert(effectView.card.view.cardId == "elite_synthvor")
    panel:pointermoved(nil, nil)
    panel:update(hold + fade)
    chooseTest(1); render("battlefield_engage_test.png")
    assert(panel:evaluate().engagementProjection.effect.removedId == projection.removedId)
    state:keypressed("escape"); assert(s.agentStatus.byAgent[id].actionPoints == 10 and not state.testPanel.card)
    assert(effectView.elapsed == 0 and not effectView.card.view.cardId)
    assert(army.forces[1].id == "preview-tank" and #enemy.forces == 1)
    army.forces, enemy.forces = originalForces, originalEnemies
    battlefield.touch(s.armies, cell)
    openAction("entrench"); chooseTest(1); chooseTest("confirm")
    assert(s.armies.byCell[cell].protection == 2 and s.agentStatus.byAgent[id].actionPoints == 9 and not s.attackFeedback)
    require("tests.card_outcome_vfx")(state, render)
    state:update(0.8); render("battlefield_entrench_result.png"); state:update(4)
    local protection = s.armyView:protectionLabel(label)
    local function ordinaryMover(cellId)
        local army = s.armies.byCell[cellId].allied
        for _, unit in ipairs(army.forces) do
            local definition = s.armies.catalogue.byId[unit.forceId]
            local hitsOnArrival = false
            for _, trigger in ipairs(definition.triggers or {}) do
                if trigger.event == "after_maneuver" then hitsOnArrival = true; break end
            end
            if not hitsOnArrival then return unit end
        end
        local unit = { id = "ordinary_mover:" .. cellId, forceId = s.armies.pools.allied.regular[1] }
        army.forces[#army.forces + 1] = unit
        battlefield.touch(s.armies, cellId)
        return unit
    end
    local northBonus = battlefield.protection(s.armies, cell).bonus
    assert(protection.text == "P " .. (2 + northBonus) and protection.y < label.y and protection.y >= 0)
    assert(state.actions.open, "Actions remain open after Entrench")
    state:keypressed("escape")
    click(protection.x + 1, protection.y + 1, 2)
    assert(state.battlefieldInspectionCell == cell)
    click(protection.x + 1, protection.y + 1, 2)
    assert(not state.battlefieldInspectionCell)
    local southLabel
    for _, entry in ipairs(s.armyView.labels) do if entry.cellId == "south" then southLabel = entry end end
    battlefield.entrench(s.armies, "south")
    local southBonus = battlefield.protection(s.armies, "south").bonus
    local southProtection = s.armyView:protectionLabel(southLabel)
    assert(southProtection.text == "P " .. (2 + southBonus) and southProtection.y > southLabel.y
        and southProtection.y + southProtection.height <= s.grid.height)
    render("battlefield_map_protection.png")
    battlefield.damage(s.armies, "south", "allied", southBonus + 1)
    assert(s.armyView:protectionLabel(southLabel).text == "P " .. (1 + southBonus))
    battlefield.damage(s.armies, "south", "allied", southBonus + 1)
    southProtection = s.armyView:protectionLabel(southLabel)
    assert((southBonus == 0 and not southProtection) or (southProtection and southProtection.text == "P " .. southBonus))
    local unit = ordinaryMover(cell)
    beginManeuver()
    local selectedSlot
    for _, slot in ipairs(state.maneuver.slots) do
        if slot.unit.id == unit.id then selectedSlot = slot; break end
    end
    state:pointermoved(selectedSlot.x + 1, selectedSlot.y + 1)
    local maneuverPreview = state.maneuver.forcePreview.view
    assert(maneuverPreview.cardId == unit.forceId and not state.maneuver.unitId)
    assert(maneuverPreview.y + maneuverPreview.layouts[unit.forceId].height <= state.maneuver.settings.y)
    render()
    maneuverButton("unit:" .. unit.id)
    render("battlefield_maneuver_selected.png")
    state:keypressed("escape"); assert(state.maneuver.open and not state.maneuver.unitId)
    maneuverButton("unit:" .. unit.id); maneuverButton("cell:center")
    render("battlefield_maneuver.png")
    assert(state.maneuver.flight and not s.pendingManeuver and not maneuverPreview.cardId)
    local cue = s.armies.catalogue.byId[unit.forceId].move_audio
    local soundId = cue and "forceMove:" .. (cue:match("%.[%w]+$") and cue or cue .. ".wav")
    local moveSound = s.audio.sources[soundId]
    assert(not cue or moveSound, "Expected the selected Force's movement sound")
    assert(state.maneuver.flight:values())
    state:update(0.2); render("battlefield_maneuver_flight.png")
    state:update(0.2); assert(not state.maneuver.flight:values())
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
    local reserveSlot = state.maneuver.slots[1]
    state:pointermoved(reserveSlot.x + 1, reserveSlot.y + 1)
    assert(maneuverPreview.cardId == unit.forceId and not state.maneuver.unitId)
    render("battlefield_maneuver_reserves.png")
    maneuverButton("unit:" .. unit.id)
    assert(not cue or s.audio.sources[soundId] == moveSound)
    assert(state.maneuver.flight); state:update(0.2); render("battlefield_reinforcement_flight.png"); state:update(1)
    assert(#s.armies.byCell.center.allied.forces == 0)
    local found = false
    for _, u in ipairs(s.armies.byCell.south.allied.forces) do if u == unit then found = true end end
    assert(found)
    -- Keep allies available for the subsequent maneuver UI checks.
    battlefield.entrench(s.armies, "south"); battlefield.entrench(s.armies, "south")
    local south = s.armies.byCell.south
    local engagement = require("src.sys.battlefield_engagement").project(s.armies, "south")
    local lineups = engagement and engagement.armies.byCell.south or south
    local incoming = math.floor(lineups.enemy.value / 2)
    local added = 0
    while #lineups.allied.forces + added <= incoming - south.protection do
        south.allied.forces[#south.allied.forces + 1] = {
            id = "survivor_test:" .. #south.allied.forces, forceId = s.armies.pools.allied.regular[1],
        }
        if engagement then added = added + 1 end
    end
    battlefield.touch(s.armies, "south")
    openAction("engage")
    assert(state.testPanel.card, state.actions.error or "Engage did not open its test panel")
    local forecast = state.testPanel:engagementProjection()
    lineups = forecast and forecast.armies.byCell.south or south
    local before = #lineups.enemy.forces
    local outgoing = math.floor(lineups.allied.value / 2)
    chooseTest(1); chooseTest("confirm")
    local exchange = assert(s.talentFeedback, state.testPanel.error or "Engage did not resolve")
    assert(exchange.success, "Expected a successful Engage")
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
    assert(maneuverPreview.cardId == first.unit.forceId)
    local reserveForces = s.armies.byCell.center.allied.forces
    local reserveId = first.unit.forceId == "reg_hmmvv" and "elite_abrams" or "reg_hmmvv"
    s.armies.byCell.center.allied.forces = { { id = "preview-switch-reserve", forceId = reserveId } }
    panel:press(center.x, center.y); panel:releasePointer(center.x, center.y)
    assert(panel.mode == "reserve" and maneuverPreview.cardId == reserveId)
    panel:press(southHex.x, southHex.y); panel:releasePointer(southHex.x, southHex.y)
    assert(panel.mode == "local" and maneuverPreview.cardId == first.unit.forceId)
    s.armies.byCell.center.allied.forces = reserveForces
    local handFirst = state.hand.first
    local isDown = love.keyboard.isDown
    love.keyboard.isDown = function(key) return key == "lshift" end
    state:wheelmoved(0, -1)
    love.keyboard.isDown = isDown
    assert(panel.scroll == 0, "Shift + wheel should be directed to the Force preview")
    state:wheelmoved(0, -1)
    assert(panel.scroll > 0 and maneuverPreview.cardId == first.unit.forceId)
    state:pointermoved(first.x - 1, first.y + 10)
    assert(not maneuverPreview.cardId, "The tray margin should not hover the clipped portrait")
    state:pointermoved(first.x + 10, first.y + 10)
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
    local reinforcing = ordinaryMover("south")
    battlefield.transfer(s.armies, "south", "center", reinforcing.id)
    beginManeuver(); maneuverButton("cell:center")
    panel.reducedMotion = true
    maneuverButton("unit:" .. reinforcing.id)
    assert(panel.flight and panel.flight.reduced and not s.pendingManeuver)
    assert(not panel.flight:values())
    local revision = s.armies.revision
    state:mousereleased(first.x + 10, first.y + 10, 1); state:keypressed("escape")
    state:focus(false); assert(panel.flight and s.armies.revision == revision)
    state:update(panel.settings.arrivalHold / 2); render("battlefield_maneuver_reduced_motion.png")
    state:update(1); assert(not panel.open and s.armies.revision == revision)
    -- Arrival reveals the hit and releases the pre-move enemy total.
    s.agentStatus.byAgent[id].actionPoints = 1
    s.fatePool.definitions.maneuver_hit = { name = "Maneuver hit", value = 20 }
    for i in ipairs(s.fatePool.entries) do s.fatePool.entries[i] = { tileId = "maneuver_hit" } end
    s.armies.byCell.center.allied.forces = { { id = "mack_ui", forceId = "elite_bigmack" } }
    s.armies.byCell.south.enemy.forces = { { id = "enemy_ui", forceId = "reg_synthwasp" } }
    battlefield.touch(s.armies, "center")
    battlefield.touch(s.armies, "south")
    beginManeuver(); maneuverButton("cell:center"); maneuverButton("unit:mack_ui")
    assert(panel.flight:label() == panel.settings.labels.moving and panel.flight:values().south.enemy == 1)
    render()
    assert(southLabel.enemy == s.armyView.settings.enemyPrefix .. "1")
    state:update(panel.settings.flightDuration + panel.settings.arrivalHold / 2)
    local enemyName = s.armies.catalogue.byId.reg_synthwasp.name:upper()
    assert(panel.flight:label() == "BIG MACK HIT · " .. enemyName and not panel.flight:values())
    render()
    assert(southLabel.enemy == s.armyView.settings.enemyPrefix .. "0")
    assert(not state.testFeedback:busy())
    local impact = panel.flight.record.hit
    state:update(panel.settings.arrivalHold)
    local feedback = state.testFeedback
    assert(not panel.open and feedback:current() == impact and feedback.cutin == feedback.armyCutin)
    assert(not feedback.fateImage and not impact.test and state:resolving())
    local cutin = feedback.armyCutin
    assert(cutin.layouts.allied.byId.mack_ui and cutin.layouts.enemy.byId.enemy_ui
        and not cutin.layouts.enemy.after.enemy_ui)
    state:update(feedback.casualtySoundTime + 0.01)
    local casualty = cutin:casualtyPose("enemy_ui", feedback.elapsed - feedback.settings.hitTime)
    assert(casualty and casualty.destruction > 0 and feedback.casualtySounded
        and not feedback.revealSounded and not feedback.resultSounded)
    render()
    state:update(feedback.millingStart - feedback.elapsed + 0.01)
    assert(feedback.millingSounded and feedback.millingView.record == impact.milling)
    render()
    state:update(10)
    assert(not feedback:busy() and not s.talentFeedback)
    revision = s.armies.revision
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
