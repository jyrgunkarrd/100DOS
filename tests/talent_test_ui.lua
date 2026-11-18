return function(write)
    local FateInspection = require("src.ui.fate_pool_inspection")
    local function clickAt(state, x, y)
        state:pointermoved(x, y)
        state:mousepressed(x, y, 1)
        state:mousereleased(x, y, 1)
    end
    local function renderState(state, name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); state:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        local encoded = pixels:encode("png")
        write(name, encoded:getString())
        encoded:release(); pixels:release(); canvas:release()
    end
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy = machine.current
    deploy:keypressed("f")
    assert(not deploy.fatePoolInspection)
    deploy:update(2)
    local box = FateInspection.buttonBounds(deploy)
    local captain = deploy.scene.captainPanel
    assert(box.x == captain.x and box.width == captain.width and box.y == captain.y + captain.height + 4)
    local builtPool = deploy.fatePool
    clickAt(deploy, box.x + 4, box.y + 4)
    local poolPanel = assert(deploy.fatePoolInspection)
    assert(poolPanel.model.total == #builtPool.entries and poolPanel.model.total == 20)
    local rowHeight = require("data.fate_pool_inspection_view").rowHeight
    for i, row in ipairs(poolPanel.model.rows) do
        if row.id == "brutality" then
            clickAt(deploy, poolPanel.list.x + 5, poolPanel.list.y + (i - 1) * rowHeight + 5)
        end
    end
    assert(poolPanel.model.rows[poolPanel.selected].clash.difficulty == 1)
    renderState(deploy, "fate_pool_inspection.png")
    assert(poolPanel.assets.paths["assets/images/fate/brutality.png"])
    clickAt(deploy, poolPanel.close.x + 2, poolPanel.close.y + 2)
    assert(not deploy.fatePoolInspection and deploy.fatePool == builtPool)
    local cell = next(deploy.assignments)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local mission = machine.current
    mission:update(1)
    mission.selectedId = mission.session.package.agentIds[1]
    local missionBox = FateInspection.buttonBounds(mission)
    assert(missionBox.x == box.x and missionBox.y == box.y and mission.session.fatePool == builtPool)
    mission:keypressed("f")
    assert(mission.fatePoolInspection.model.total == 20)
    mission:keypressed("f", nil, true)
    assert(mission.fatePoolInspection)
    clickAt(mission, mission.panel.x + 2, mission.panel.y + 2)
    assert(not mission.fatePoolInspection and machine.current == mission and mission.selectedId)
    assert(mission:beginAgentAction())
    local state, session = machine.current, machine.current.session
    state:update(2)
    local id = state.activeAgentId
    local clicks = 0
    local play = session.audio.playOverlapping
    session.audio.playOverlapping = function(self, cue)
        if cue == "selection" then clicks = clicks + 1 end
        return play(self, cue)
    end
    local deck = session.locationDecks.byCell[cell]
    local enemy = { instanceId = "test_enemy", cardId = "forgiven", health = 2, exhausted = false, engagedAgentId = id }
    local door = { instanceId = "test_door", cardId = "security_door" }
    deck.inPlay, deck.inPlayOrder = { test_enemy = enemy, test_door = door }, { "test_enemy", "test_door" }
    deck.revision = deck.revision + 1
    for i = 1, #session.fatePool.entries do session.fatePool.entries[i] = { tileId = "autosuccess" } end
    local function click(x, y)
        clickAt(state, x, y)
    end
    local function button(key)
        for _, b in ipairs(state.testPanel:buttons()) do if b.id == key then click(b.x + 5, b.y + 5); return end end
        error("Missing test button")
    end
    local function selectCard(instanceId)
        state.exploration:showInstance(instanceId)
        for _, entry in ipairs(state.exploration:visibleCards()) do
            if entry.card.instanceId == instanceId then click(entry.x + 5, entry.y + 5); return end
        end
        error("Missing location tile")
    end
    local function render(name)
        renderState(state, name)
    end
    local function bonusTile(index)
        local tile = assert(state.testPanel:reserveTiles()[index])
        click(tile.x+tile.width/2,tile.y+tile.height/2)
    end
    -- The location column opens the shared test UI and bonus selections remain read-only until commit.
    local Reserve = require("src.sys.fate_reserve")
    Reserve.add(session.fatePool,require("data.fate_tiles.genius"),3,"INGENUITY")
    for _,kind in ipairs({"charm","ingenuity"}) do
        state.actions:setOpen(true)
        local tab=state.actions:tab("location"); click(tab.x+4,tab.y+4)
        assert(state.actions.selectedTab=="location")
        render("location_action_tab.png")
        for _,b in ipairs(state.actions.rows) do if b.id==kind then click(b.x+4,b.y+4) end end
        assert(state.testPanel.locationArgs and state.testPanel.locationArgs.locationKind==kind)
        button(1); bonusTile(1); bonusTile(2)
        assert(state.testPanel:args().bonusCounts.genius==2 and #Reserve.entries(session.fatePool)==3)
        bonusTile(1)
        assert(state.testPanel:args().bonusCounts.genius==1)
        assert(not state.testPanel.bonusSelected[session.fatePool.reserve[1]] and state.testPanel.bonusSelected[session.fatePool.reserve[2]])
        bonusTile(1)
        render("location_" .. kind .. "_bonus.png")
        button("cancel")
        assert(#Reserve.entries(session.fatePool)==3)
    end
    Reserve.add(session.fatePool,require("data.fate_tiles.genius"),12,"SCROLL TEST")
    state.testPanel:openLocation("ingenuity"); button(1); bonusTile(2)
    local strip=state.testPanel:reserveBounds()
    state.testPanel:wheel(strip.x+5,strip.y+5,-20)
    local visible=state.testPanel:reserveTiles()
    bonusTile(#visible)
    assert(state.testPanel:args().bonusCounts.genius==2)
    render("bonus_reserve_row_overflow.png")
    state.testPanel:wheel(strip.x+5,strip.y+5,20)
    bonusTile(2)
    assert(state.testPanel:args().bonusCounts.genius==1)
    button("cancel")
    while #session.fatePool.reserve>3 do table.remove(session.fatePool.reserve) end
    local savedStatus = {}; for k,v in pairs(session.agentStatus.byAgent[id]) do savedStatus[k]=v end
    state.testPanel:openLocation("ingenuity")
    button(1); bonusTile(1); bonusTile(2); button("confirm")
    assert(session.talentFeedback and session.talentFeedback.success and #Reserve.entries(session.fatePool)==2)
    state:update(0.7)
    render("ingenuity_result.png")
    state:update(10); state:update(10) -- talent playback, then queued opportunity attacks
    for k,v in pairs(savedStatus) do session.agentStatus.byAgent[id][k]=v end
    Reserve.add(session.fatePool,require("data.fate_tiles.genius"),1)
    state:keypressed("f")
    local reservePanel = assert(state.fatePoolInspection)
    click(reservePanel.x+20,reservePanel.y+45)
    assert(reservePanel.bonusTab and reservePanel.model.total==3)
    render("bonus_reserve_inspection.png")
    state:keypressed("f")
    local originalPile = deck.drawPile
    deck.drawPile = {{instanceId="faceup1",cardId="forgiven",health=2,faceUp=true},
        {instanceId="faceup2",cardId="security_door",faceUp=true}}
    render("charm_faceup_cards.png")
    local row
    for _,entry in ipairs(state.exploration:visibleCards()) do if entry.column == "faceUp" then row=entry; break end end
    assert(row and row.x > state.exploration.x)
    click(row.x+4,row.y+4)
    assert(not state.testPanel.card)
    local inPlayFirst = state.exploration.first
    state.exploration:pointermoved(row.x+4,row.y+4)
    assert(state.exploration:wheelmoved(-1))
    assert(state.exploration.faceUpFirst==state.exploration:lastPageStart("faceUp") and state.exploration.first==inPlayFirst)
    state.exploration:pointermoved(state.exploration.x+4,row.y+4)
    assert(state.exploration:wheelmoved(-1))
    assert(state.exploration.faceUpFirst==state.exploration:lastPageStart("faceUp"))
    state.exploration.first,state.exploration.faceUpFirst=1,1
    deck.drawPile=originalPile
    session.fatePool.reserve={}
    clicks=0
    selectCard(enemy.instanceId)
    assert(state.testPanel.card == enemy and not state.testPanel.test)
    for _, image in ipairs({ state.testPanel.agentImage, state.testPanel.locationImage }) do
        local min, mag = image:getFilter()
        assert(min == "nearest" and mag == "nearest")
        assert(image:getMipmapCount() == 1)
    end
    local miniAgent = require("data.deployment_roster_defaults")
    local miniLocation = require("data.location_exploration_view")
    assert(state.testPanel.agentImage == state.testPanel.images[miniAgent.directory .. "/" .. id .. miniAgent.suffix])
    assert(state.testPanel.locationImage == state.testPanel.images[miniLocation.directory .. "/" .. enemy.cardId .. miniLocation.suffix])
    assert(state.portrait.images[id]:getFilter() == "nearest")
    -- The icon/name gutter is part of the test's click target, outside its border.
    local evadeRow = state.testPanel:buttons()[2]
    click(state.testPanel.x + 16, evadeRow.y + 5)
    assert(state.testPanel.test.id == "evade")
    assert(clicks == 1)
    local hand = session.agentCards.byAgent[id]
    local count = #hand.hand
    local first = state.hand.entries[1]
    click(first.x + 5, first.y + 5)
    assert(state.testPanel.selected[first.card.instanceId])
    assert(clicks == 2)
    click(first.x + 5, first.y + 5)
    assert(not state.testPanel.selected[first.card.instanceId] and clicks == 3)
    click(first.x + 5, first.y + 5)
    assert(state.testPanel.selected[first.card.instanceId] and clicks == 4)
    state:mousepressed(first.x + 5, first.y + 5, 1)
    state:mousereleased(0, 0, 1)
    assert(clicks == 4, "Cancelled clicks must be silent")
    render("talent_test_commitment.png")
    state:keypressed("f")
    assert(state.fatePoolInspection.model.total == 20)
    button("confirm") -- The inspection captures clicks over the test controls.
    assert(not session.talentFeedback and state.testPanel.test.id == "evade")
    state:mousepressed(0, 0, 2); state:mousereleased(0, 0, 2)
    assert(not state.fatePoolInspection and state.testPanel.selected[first.card.instanceId])
    click(box.x + 4, box.y + 4)
    assert(state.fatePoolInspection and state.testPanel.test.id == "evade")
    state:keypressed("escape")
    assert(not state.fatePoolInspection and state.testPanel.selected[first.card.instanceId] and clicks == 4)
    -- Cancelling never spends, draws, discards, or mutates the enemy.
    state:keypressed("escape")
    assert(clicks == 4)
    assert(not state.testPanel.card and #hand.hand == count and #hand.discardPile == 0 and enemy.engagedAgentId == id)
    selectCard(enemy.instanceId); button(2)
    first = state.hand.entries[1]; click(first.x + 5, first.y + 5)
    button("confirm")
    assert(clicks == 7, "Selection, commitment, and confirmation each play one click")
    assert(state.testFeedback:busy() and session.talentFeedback.success and session.talentFeedback.committed == 1)
    state:keypressed("f")
    assert(not state.fatePoolInspection)
    assert(enemy.exhausted and not enemy.engagedAgentId and #hand.discardPile == 1 and #hand.hand == count - 1)
    assert(session.agentStatus.byAgent[id].actionPoints == 2 and not state:endTurn() and not state:explore())
    local same = session.talentFeedback
    assert(not state:performAction("talent_test", { instanceId = enemy.instanceId, testId = "evade" }))
    state:update(state.testFeedback.view.enterDuration + state.testFeedback.view.drawDuration * 0.25)
    render("talent_test_wipe_start.png")
    state:update(state.testFeedback.view.drawDuration * 0.5)
    render("talent_test_wipe_end.png")
    state:update(state.testFeedback.view.drawDuration * 0.25 + 0.04)
    render("talent_test_evade.png")
    assert(session.talentFeedback == same)
    -- Render presentation-only probes without changing the committed game result.
    local feedback = state.testFeedback
    local saved = { result = feedback.result, record = feedback.record, elapsed = feedback.elapsed }
    local function probe(kind, success, age, name, reduced)
        local record = {}
        for key, value in pairs(saved.result) do record[key] = value end
        record.success, record.special = success, success and "auto_success" or "auto_failure"
        record.test = { kind = kind, label = kind:upper() }
        if kind == "interact" then record.cardId, record.name = "security_door", "Security Door" end
        feedback.result, feedback.record = record, { events = { record }, agentId = id }
        feedback.elapsed = feedback.settings.hitTime + age
        feedback.cutin.settings.reducedMotion = reduced or false
        render(name)
        return feedback:outcomePose()
    end
    local evade = probe("evade", true, 0.15, "talent_outcome_evade.png")
    assert(evade.evadeSweep > 0 and evade.evadeSweep < 1 and evade.artOffset == 0
        and evade.trailAlpha == 0 and evade.brightness == 1 and evade.contentAlpha == 1 and evade.frameAlpha == 1)
    local swept = probe("interact", true, 0.09, "talent_outcome_sweep.png")
    assert(swept.sweep > 0 and swept.sweep < 1 and swept.contentAlpha == 1)
    local frame = probe("interact", true, 0.3, "talent_outcome_discard.png")
    assert(frame.contentAlpha == 0 and frame.frameAlpha > 0 and frame.frameAlpha < 1)
    local failed = probe("strike", false, 0.025, "talent_outcome_failure.png")
    assert(failed.fateOffset ~= 0 and failed.failureFlash > 0 and failed.contentAlpha == 1 and failed.brightness == 1)
    local calm = probe("evade", true, 0.15, "talent_outcome_evade_reduced.png", true)
    assert(calm.artOffset == 0 and calm.trailAlpha == 0 and calm.brightness == 1 and calm.evadeSweep)
    calm = probe("interact", false, 0.025, "talent_outcome_failure_reduced.png", true)
    assert(calm.fateOffset == 0 and calm.failureFlash > 0)
    feedback.result, feedback.record, feedback.elapsed = saved.result, saved.record, saved.elapsed
    feedback.cutin.settings.reducedMotion = false
    assert(session.talentFeedback == same)
    state:update(3)
    assert(not state:resolving() and not session.talentFeedback)
    selectCard(enemy.instanceId); button(1); button("confirm")
    assert(enemy.health == 1 and not state.testFeedback.result.defeated)
    state.previews:show("location", enemy)
    assert(state.previews.views.location.instanceDisplay.stats[1].value == 1)
    assert(state.previews.views.location.instanceDisplay.engagementText == "EXHAUSTED")
    state.previews:clear()
    state:update(state.testFeedback.settings.hitTime + 0.03)
    render("talent_test_strike.png")
    state.testFeedback.cutin.settings.reducedMotion = true
    render("talent_test_reduced_motion.png")
    state.testFeedback.cutin.settings.reducedMotion = false
    state:update(3)
    selectCard(enemy.instanceId); button(1); button("confirm")
    assert(enemy.health == 0 and not deck.inPlay[enemy.instanceId] and state.testFeedback.result.defeated)
    state:update(state.testFeedback.settings.hitTime)
    assert(not state.testFeedback.cutin:defeatPose(state.testFeedback), "Damage impact precedes the defeat sweep")
    state:update(state.testFeedback.cutin.settings.impactDuration + 0.09)
    local defeat = state.testFeedback.cutin:defeatPose(state.testFeedback)
    assert(defeat and defeat.sweep > 0 and defeat.sweep < 1 and defeat.contentAlpha == 1)
    render("talent_enemy_defeat_sweep.png")
    state:update(0.27)
    defeat = state.testFeedback.cutin:defeatPose(state.testFeedback)
    assert(defeat.contentAlpha == 0 and defeat.frameAlpha == 0)
    render("talent_enemy_defeat_faded.png")
    state:update(3)
    selectCard(door.instanceId); button(1)
    local beforeDisabled = clicks
    button("confirm")
    assert(clicks == beforeDisabled, "Disabled confirmation must be silent")
    assert(state.testPanel.error == "NO ACTION POINTS" and not session.talentFeedback)
    render("talent_test_comparison_barrier.png")
    button("cancel")
    assert(clicks == beforeDisabled + 1, "Cancel button plays one click")

    -- Non-combat tests present fate before queued opportunity attacks, including defeat.
    session.agentStatus.byAgent[id].actionPoints = 1
    session.agentStatus.byAgent[id].health = 1
    local attacker = { instanceId = "attacker", cardId = "forgiven", health = 1, engagedAgentId = id }
    deck.inPlay.attacker = attacker; deck.inPlayOrder[#deck.inPlayOrder + 1] = "attacker"; deck.revision = deck.revision + 1
    selectCard(door.instanceId); button(2); button("confirm")
    assert(session.attackFeedback and state.testFeedback:busy() and state.feedback.elapsed == 0)
    assert(not deck.inPlay[door.instanceId])
    state:update(state.testFeedback.settings.hitTime + 0.02)
    assert(state.feedback.elapsed == 0 and machine.current == state)
    state:update(3)
    assert(not state.testFeedback:busy() and state.feedback.elapsed == 0)
    state:update(3)
    assert(machine.currentName == "mission_action" and not session.talentFeedback and not session.attackFeedback)
    machine.current:exit()
end
