return function(write)
    local settings = require("data.agent_preview_view")
    local definition = { name = "TEST", health = 0, defiance = 4, talents = {}, methods = {},
        card_rules = { startingHandSize = 2, activationDrawCount = 3 } }
    local display = require("src.sys.agent_display").normalize(definition, settings)
    assert(#display.tests == 6 and display.tests[1].value == 0 and display.health == 0)
    assert(#display.paragraphs == 0 and display.summary.right:match("STARTING RESOURCES"))
    local Inspection = require("src.ui.agent_inspection")
    local Data = require("src.sys.agent_inspection_data")
    local cards = { a = { name = "Axe" }, b = { name = "Banner" }, c = { name = "axe" } }
    local agent = { name = "TEST", card_deck = { { card_id = "b", card_qty = 3 }, { card_id = "a", card_qty = 1 } },
        fate = { "neutral", "neutral" } }
    local fate = { neutral = { value = 0 }, brutality = { name = "BRUTALITY", value = 1, negative = true,
        img = true, clash = { amt = 1, en_dmg = 1, en_bonus = 1 } } }
    local planned = Data.build("one", agent, cards, nil, nil, fate)
    assert(not planned.live and planned.planned and planned.deck.total == 4 and planned.discard.total == 0)
    assert(planned.deck.rows[1].id == "a" and planned.fate.rows[1].name == "+0" and planned.fate.rows[1].quantity == 2)
    local live = { drawPile = { { cardId = "b", instanceId = 4 }, { cardId = "c", instanceId = 3 },
        { cardId = "a", instanceId = 1 }, { cardId = "b", instanceId = 5 } },
        discardPile = { { cardId = "b", instanceId = 2 } }, hand = { { cardId = "a", instanceId = 6 } } }
    local pool = { definitions = fate, entries = {
        { tileId = "brutality", sourceType = "agent", sourceId = "one" },
        { tileId = "brutality", sourceType = "agent", sourceId = "one" },
        { tileId = "brutality", sourceType = "agent", sourceId = "two" },
        { tileId = "brutality", sourceType = "captain", sourceId = "one" },
        { tileId = "neutral", sourceType = "jacl", sourceId = "one" },
    } }
    local model = Data.build("one", agent, cards, live, pool)
    local pile = live.drawPile
    assert(pile[1].instanceId == 4 and pile[4].instanceId == 5)
    pile[1], pile[3] = pile[3], pile[1]
    local shuffled = Data.build("one", agent, cards, live, pool)
    for i, id in ipairs({ "a", "c", "b" }) do
        local row, other = model.deck.rows[i], shuffled.deck.rows[i]
        assert(row.id == id and row.id == other.id and row.quantity == other.quantity and not row.instanceId)
    end
    assert(model.live and not model.planned and model.deck.total == 4 and model.discard.total == 1)
    assert(model.discard.rows[1].quantity == 1 and model.fate.total == 2)
    assert(model.fate.rows[1].modifier == -1 and model.fate.rows[1].clash.damage == 1)
    model.fate.rows[1].clash.damage = 99
    assert(fate.brutality.clash.en_dmg == 1)
    local Placement = require("src.ui.preview_placement")
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    local function clearOf(view, r)
        local l = view.instanceLayout or view.layouts[view.cardId]
        return view.x + view.settings.width <= r.x or view.x >= r.x + r.width
            or view.y + l.height <= r.y or view.y >= r.y + r.height
    end
    local function click(state, x, y, button)
        state:pointermoved(x, y)
        state:mousepressed(x, y, button)
        state:mousereleased(x, y, button)
    end
    local function tab(state, index)
        local panel = state.agentInspectionPanel
        local button = (panel.details or panel).tabs[index]
        click(state, button.x + 5, button.y + 5, 1)
    end
    local function details(state)
        local panel = assert(state.agentInspectionPanel, state.inspectionError)
        if panel.readOnly then
            local b = panel.detailsButton
            click(state, b.x + 4, b.y + 4, 1)
            return assert(panel.details, panel.detailsError)
        end
        return panel
    end
    machine:change("mission_preparation")
    local prep = machine.current
    prep:update(2)
    local previewSounds = 0
    local play = prep.audio.playOverlapping
    prep.audio.playOverlapping = function(audio, cue)
        if cue == "cardView" then previewSounds = previewSounds + 1 end
        return play(audio, cue)
    end
    for index, entry in ipairs(prep.agentRoster.entries) do
        prep:pointermoved(entry.x + 30, prep.agentRoster.y + 30)
        assert(prep.inspection and prep.inspection.view.cardId == entry.id, prep.inspectionError)
        local i = prep.inspection
        assert(clearOf(i.view, i.target))
        assert((i.view.x > 640) == (entry.x + 88 < 640))
        for _, b in ipairs(prep.buttons) do assert(clearOf(i.view, { x = b.x, y = b.y, width = b.width, height = b.height })) end
        if index == 1 then render("agent_preview_preparation_left.png") end
        if index == 6 then render("agent_preview_preparation_right.png") end
    end
    local first = prep.agentRoster.entries[1]
    assert(previewSounds == 1, "Switching Agents must share one preview sound")
    prep:pointermoved(0, 0)
    Inspection.update(prep, settings.inspectionSoundResetDelay / 2)
    prep:pointermoved(first.x + 20, prep.agentRoster.y + 20)
    assert(previewSounds == 1, "Brief gaps must not start another inspection session")
    prep:pointermoved(0, 0)
    Inspection.update(prep, settings.inspectionSoundResetDelay)
    prep:pointermoved(first.x + 20, prep.agentRoster.y + 20)
    assert(previewSounds == 2, "Returning after leaving must play the preview cue")
    Inspection.update(prep, 10)
    prep:pointermoved(prep.agentRoster.entries[2].x + 20, prep.agentRoster.y + 20)
    assert(previewSounds == 2, "Lingering on Agents must not reset the sound session")
    prep:pointermoved(first.x + 180, prep.agentRoster.y + 20)
    assert(prep.inspection.view.cardId == first.id) -- gap remains inspectable
    prep:focus(false); assert(not prep.inspection.view.cardId)
    click(prep, first.x + 20, prep.agentRoster.y + 20, 2)
    local panel = assert(prep.agentInspectionPanel, prep.inspectionError)
    assert(panel.model.name == prep.agents.byId[first.id].name and panel.model.deck.total == 20)
    tab(prep, 3)
    assert(panel.tab == "fate" and panel.model.planned and panel.model.fate.total == 3)
    local rowHeight = require("data.agent_inspection_view").rowHeight
    for index, row in ipairs(panel.model.fate.rows) do
        if row.id == "brutality" then click(prep, panel.list.x + 5, panel.list.y + (index - 1) * rowHeight + 5, 1) end
    end
    assert(panel.selected.id == "brutality")
    render("agent_inspection_planned_fate.png")
    assert(panel.assets.paths["assets/images/fate/brutality.png"])
    click(prep, panel.close.x + 2, panel.close.y + 2, 1)
    assert(not prep.agentInspectionPanel)
    assert(prep:rebuildPackage() and not prep.inspection)
    prep:update(2)
    assert(prep:deploy())
    local deployment = machine.current; deployment:update(2)
    local e = deployment.roster.entries[1]
    deployment:pointermoved(e.x + 4, e.y + 4)
    assert(deployment.inspection.view.cardId == e.id)
    deployment:mousepressed(e.x + 4, e.y + 4, 1)
    deployment:pointermoved(e.x + 80, e.y + 80)
    assert(not deployment.inspection.view.cardId)
    deployment:focus(false)
    click(deployment, e.x + 4, e.y + 4, 2)
    panel = assert(deployment.agentInspectionPanel, deployment.inspectionError)
    assert(not panel.model.live and not panel.model.planned and panel.model.fate.total == 3)
    click(deployment, 0, 0, 2)
    assert(not deployment.agentInspectionPanel and not deployment.drag.pending)
    local cell = next(deployment.assignments)
    for _, id in ipairs(deployment.package.agentIds) do deployment.agentDeployment:assign(id, cell) end
    deployment.agentView:refresh(); assert(deployment:beginAction()); machine.current:update(2)
    local mission = machine.current
    local session = mission.session
    local id = session.package.agentIds[1]
    local status = session.agentStatus.byAgent[id]
    status.health, status.defiance = 2, 3
    local entry = session.roster.entries[1]
    mission:pointermoved(entry.x + 4, entry.y + 4)
    assert(mission.inspection.view.cardId == id and not mission.selectedId)
    render("agent_preview_mission.png")
    local v = mission.inspection.view
    assert(v.instanceDisplay.health == 2)
    status.health = 1
    local oldScroll = v.scroll
    render("agent_preview_live.png")
    assert(v.instanceDisplay.health == 1 and v.scroll == oldScroll)
    status.exhausted = true
    mission:pointermoved(entry.x + 4, entry.y + 4)
    assert(v.cardId == id and not session.agentView.hovered)
    status.health, status.defeated = 0, true
    mission:pointermoved(entry.x + 4, entry.y + 4)
    render("agent_preview_defeated.png")
    assert(v.instanceDisplay.paragraphs[1].text:match("DEFEATED"))
    click(mission, entry.x + 4, entry.y + 4, 2)
    panel = details(mission)
    assert(panel.model.live and panel.model.deck.total == #session.agentCards.byAgent[id].drawPile)
    assert(panel.model.deck.total < 20 and panel.preview.cardId == "catburglar" and not mission.selectedId)
    tab(mission, 2)
    assert(panel.tab == "discard" and panel.model.discard.total == 0)
    render("agent_inspection_empty_discard.png")
    mission:keypressed("escape")
    assert(not mission.agentInspectionPanel and not mission.selectedId)
    local drawOrder = session.agentView:drawOrder()
    local top = drawOrder[#drawOrder]
    click(mission, top.x + 8, top.y + 8, 2)
    panel = details(mission)
    assert(panel.model.name == session.agentCards.agents.byId[top.id].name and not mission.battlefieldInspectionCell)
    mission:keypressed("escape")
    status.health, status.defiance, status.exhausted, status.defeated = 6, 6, false, false
    mission.selectedId = id; assert(mission:beginAgentAction()); machine.current:update(2)
    local active = machine.current
    local pileState = session.agentCards.byAgent[id]
    local drawCount = #pileState.drawPile
    local discarded = table.remove(pileState.hand)
    local handCount = #pileState.hand
    pileState.discardPile = { discarded }
    active.hand:layout()
    click(active, active.portrait.x + 20, active.portrait.y + 20, 2)
    panel = details(active)
    assert(panel.model.deck.total == drawCount and panel.model.discard.total == 1)
    tab(active, 2)
    assert(panel.preview.cardId == pileState.discardPile[1].cardId)
    render("agent_inspection_discard.png")
    active:pointermoved(panel.detail.x + 5, panel.detail.y + 5)
    active:wheelmoved(0, -2)
    assert(panel.preview.scroll > 0)
    local point = session.agentStatus.byAgent[id].actionPoints
    click(active, active.done.x + 2, active.done.y + 2, 1)
    assert(active.agentInspectionPanel and not active.agentInspectionPanel.details)
    click(active, 0, 0, 2)
    assert(not active.agentInspectionPanel and machine.current == active and session.activeAgentId == id)
    assert(session.agentStatus.byAgent[id].actionPoints == point and #pileState.hand == handCount and #pileState.drawPile == drawCount)
    pileState.hand[#pileState.hand + 1] = discarded
    pileState.discardPile = {}
    active.hand:layout()
    active:pointermoved(active.portrait.x + 20, active.portrait.y + 20)
    assert(active.previews.source == "character" and active.inspection.view.cardId == id)
    local assets = session.agentAssets
    local originalBoard = assets.byAgent[id]
    local asset = { start = 2, size = 3, health = 0, defiance = 0,
        card = { cardId = "catburglar", instanceId = "preview_multi" } }
    local single = { start = 7, size = 1, health = 0, defiance = 0,
        card = { cardId = "catburglar", instanceId = "preview_single" } }
    assets.byAgent[id] = { placements = { asset, single }, occupied = {} }
    for index = 2, 4 do assets.byAgent[id].occupied[assets.slots[index]] = asset end
    assets.byAgent[id].occupied[assets.slots[7]] = single
    render("agent_preview_assets.png")
    local av = active.inspection.view
    local slots = av.instanceDisplay.assetSlots
    assert(#slots == 7 and not slots[1].cardId and slots[2].cardId == "catburglar")
    assert(not slots[2].continuation and slots[3].continuation and slots[4].continuation)
    assert(slots[3].start == 2 and slots[7].start == 7 and not slots[7].continuation)
    local layout = av.instanceLayout.assetSlots
    assert(layout.entries[7].x == layout.entries[2].x and layout.entries[7].y > layout.entries[6].y)
    assert(av.images["assets/images/cards/catburglar_mini.png"])
    assets.byAgent[id] = originalBoard
    render("agent_preview_assets_cleared.png")
    assert(not av.instanceDisplay.assetSlots[2].cardId)
    -- Even-sized grids have no extra blank position.
    local six = {}
    for index = 1, 6 do six[index] = { index = index } end
    local even = require("src.ui.preview_asset_slots").layout(six, settings.assetSlots, session.scene.accents.small)
    assert(even.entries[5].x == 0 and even.entries[6].x > 0 and even.entries[5].y == even.entries[6].y)
    local hand = active.hand.entries[1]
    active:pointermoved(hand.x + 4, hand.y + 4)
    assert(active.previews.source == "player_card" and not active.inspection.view.cardId)
    active:pointermoved(active.portrait.x + 20, active.portrait.y + 20)
    active:focus(false); assert(not active.previews.source)
    -- Placement stays bounded for smaller available areas and never covers the target.
    local r = Placement.choose(640, 360, { width = 240, height = 320, y = 20 },
        { x = 20, y = 40, width = 100, height = 100 }, nil, {}, 12, 8)
    assert(r and r.x >= 120 and r.x + r.width <= 640)
    active:exit()
end
