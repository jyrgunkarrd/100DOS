return function(write)
    require("tests.agent_cards")(write)
    require("tests.card_preview")(write)
    require("tests.card_play")()
    local Status = require("src.sys.agent_status")
    local definitions = { byId = { a = { health = 12, defiance = 0 }, b = { health = 4, defiance = 9 } } }
    local model = Status.new({ "a", "b" }, definitions, require("data.agent_status_defaults"))
    assert(model.byAgent.a.health == 12 and model.byAgent.b.defiance == 9)
    model.byAgent.a.resources = 2
    assert(model.byAgent.b.resources == 5 and not definitions.byId.a.resources)
    local holder = { agentStatus = model }
    local transferred = require("src.sys.mission_session").take(holder)
    assert(transferred.agentStatus == model and not holder.agentStatus)
    require("src.sys.mission_session").release(transferred)
    assert(not transferred.agentStatus)
    assert(not pcall(Status.new, { "a" }, { byId = { a = { health = -1, defiance = 1 } } },
        require("data.agent_status_defaults")))
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy = machine.current
    local fatePool = deploy.fatePool
    assert(#fatePool.entries == 20)
    deploy:update(2)
    local cell = next(deploy.assignments)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh()
    assert(deploy:beginAction())
    local action = machine.current
    assert(action.session.fatePool == fatePool and not deploy.fatePool)
    local actPlays = 0
    local audio = action.session.audio
    assert(audio.sources.agentAct)
    local play = audio.playOverlapping
    audio.playOverlapping = function(self, id)
        if id == "agentAct" then actPlays = actPlays + 1 end
        return play(self, id)
    end
    assert(not action:beginAgentAction())
    action:keypressed("space") -- Skip the independent hunt distribution.
    action:update(0.2)
    local function click(x, y)
        machine:dispatch("mousepressed", x, y, 1)
        machine:dispatch("mousereleased", x, y, 1)
    end
    local panel = action.panel
    click(panel.x + 2, panel.y + 2)
    assert(machine.current == action and not action:beginAgentAction())
    local s, portrait = action.session, action.portrait
    local first = s.roster.entries[1]
    click(first.x + 2, first.y + 2)
    local selected = action.selectedId
    assert(selected == first.id)
    action:mousepressed(panel.x + 2, panel.y + 2, 1)
    action:focus(false)
    action:mousereleased(panel.x + 2, panel.y + 2, 1)
    assert(machine.current == action)
    local originalLoad = love.filesystem.load
    love.filesystem.load = function(path)
        if path == "data/agent_action.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not action:beginAgentAction())
    love.filesystem.load = originalLoad
    assert(action.session == s and action.portrait == portrait)
    love.filesystem.load = function(path)
        if path == "data/agent_equipment_view.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not action:beginAgentAction())
    love.filesystem.load = originalLoad
    assert(action.session == s and action.portrait == portrait and actPlays == 0)
    love.filesystem.load = function(path)
        if path == "data/agent_hand_view.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not action:beginAgentAction())
    love.filesystem.load = originalLoad
    assert(#s.agentCards.byAgent[selected].hand == 5 and action.session == s and actPlays == 0)
    love.filesystem.load = function(path)
        if path == "data/card_preview_view.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not action:beginAgentAction())
    love.filesystem.load = originalLoad
    assert(#s.agentCards.byAgent[selected].hand == 5 and action.session == s and actPlays == 0)
    love.filesystem.load = function(path)
        if path == "data/agent_status_view.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not action:beginAgentAction())
    love.filesystem.load = originalLoad
    assert(s.agentStatus and #s.agentCards.byAgent[selected].hand == 5 and action.session == s and actPlays == 0)
    action:update(0.03)
    assert(actPlays == 0)
    local oldX, oldY = portrait.x, portrait.y
    click(panel.x + 2, panel.y + 2)
    local active = machine.current
    assert(active.session.fatePool == fatePool)
    assert(machine.currentName == "agent_action" and active.activeAgentId == selected)
    assert(actPlays == 1)
    assert(active.session == s and active.portrait == portrait and active.portraitAge == 0.03)
    assert(not action.session and not action.portrait and next(panel.images) == nil)
    assert(first.image and portrait.images[selected] and portrait.x == oldX)
    assert(#s.agentCards.byAgent[selected].hand == 6 and #s.agentCards.byAgent[selected].drawPile == 14)
    for id, state in pairs(s.agentCards.byAgent) do
        if id ~= selected then assert(#state.hand == 5 and #state.drawPile == 15) end
    end
    local hand = active.hand
    local status = s.agentStatus.byAgent[selected]
    assert(status.health == 6 and status.defiance == 6 and status.resources == 5 and status.actionPoints == 3)
    local statusView = active.statusView
    local startStatus = statusView:layout(portrait, status)
    assert(startStatus.x == portrait.x and startStatus.y + 20 + 6 == portrait.y - 4)
    assert(hand.x == active.equipment.x and #hand.entries == 6)
    machine:dispatch("pointermoved", hand.x + 2, hand.entries[1].y + 2)
    assert(not hand.hovered)
    local equipment = active.equipment
    assert(#equipment.slots == 7 and equipment.width == 374 and equipment.height == 50)
    assert(equipment.x == 882 and equipment.y == 304)
    assert(equipment.y + equipment.height + 6 == s.scene.parallax.rectangle.y)
    local canvas = love.graphics.newCanvas(1280, 720)
    local function render(name)
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        active:draw()
        love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        local function matches(x, y, expected)
            local channels = { pixels:getPixel(x, y) }
            for i = 1, 4 do assert(math.abs(channels[i] - expected[i]) <= 1 / 255) end
        end
        for index, slot in ipairs(equipment.slots) do
            if equipment:revealAlpha(index, active.elapsed) == 1 and not active.drag.active
                and not s.agentAssets:at(selected, index) then
            local x, y = equipment.x + (index - 1) * 54, equipment.y
            matches(x, y, equipment.settings.frameColor)
            matches(x + 4, y + 25, equipment.settings.backgroundColor)
            matches(x + 5, y + 5, slot.color)
            matches(x + 44, y + 44, slot.color)
            matches(x + 45, y + 25, equipment.settings.backgroundColor)
            matches(x + 49, y + 49, equipment.settings.frameColor)
            end
        end
        write(name, pixels:encode("png"):getString())
        pixels:release()
    end
    assert(equipment:revealAlpha(1, 0) == 0 and equipment:revealAlpha(7, 0.1) == 0)
    assert(equipment:revealAlpha(1, 0.04) > equipment:revealAlpha(2, 0.04))
    assert(hand:revealPose(6, 0).offsetY == 6 and hand:revealPose(6, 0).alpha == 0)
    render("agent_action_entrance_start.png")
    active:update(0.075)
    assert(portrait.x > oldX and portrait.x < active.targetX and portrait.x % 1 == 0)
    assert(portrait.y == oldY and active.portraitAge > 0.03)
    render("agent_action_transition.png")
    active:update(0.075)
    assert(portrait.x == active.targetX)
    local finalStatus = statusView:layout(portrait, status)
    assert(finalStatus.x == portrait.x and finalStatus.y == startStatus.y)
    assert(finalStatus.resourceX + finalStatus.resourceWidth == portrait.x + portrait.size)
    machine:dispatch("pointermoved", hand.x + 2, hand.entries[1].y + 2)
    assert(not hand.hovered)
    active:update(0.05)
    assert(hand:revealPose(6, 0.05).alpha > 0 and hand:revealPose(1, 0.05).alpha == 0)
    render("agent_action_hand_reveal.png")
    machine:dispatch("pointermoved", hand.x + 2, hand.entries[5].y + 2)
    machine:dispatch("wheelmoved", 0, -1)
    assert(not hand.hovered and hand.first == 1)
    active:update(0.15)
    assert(hand:revealPose(1, 0.2).alpha == 1 and hand:revealPose(1, 0.2).offsetY == 0)
    machine:dispatch("pointermoved", hand.x + 2, hand.entries[1].y + 2)
    assert(hand.hovered == hand.entries[1].card.instanceId)
    assert(active.preview.cardId == hand.entries[1].card.cardId)
    render("card_preview.png")
    for gapY = hand.entries[1].y + hand.settings.height, hand.entries[2].y - 1 do
        machine:dispatch("pointermoved", hand.x + 2, gapY)
        assert(hand.hovered == hand.entries[1].card.instanceId and active.preview.cardId)
    end
    machine:dispatch("pointermoved", hand.x - 1, hand.entries[1].y + 2)
    assert(not hand.hovered and not active.preview.cardId)
    machine:dispatch("pointermoved", hand.x + 2, hand.entries[2].y + 2)
    assert(active.preview.cardId == hand.entries[2].card.cardId)
    machine:dispatch("focus", false)
    assert(not hand.hovered and not active.preview.cardId)
    -- Preparing another visit stages the same hand without drawing again.
    status.resources = 12
    local reentry = require("src.states.agent_action").prepare({ selectedId = selected,
        session = s, portrait = portrait, width = 1280, panel = { font = active.font } })
    assert(reentry.cards == s.agentCards and #reentry.stagedCards.drawPile == 14)
    assert(reentry.status == s.agentStatus and reentry.status.byAgent[selected].resources == 12)
    reentry.statusView:release()
    reentry.done:release()
    reentry.exploration:release()
    status.resources = 5
    reentry.hand:release()
    reentry.previews:release()
    assert(equipment.x == 882 and equipment.y == 304)
    assert(portrait.x + portrait.size + portrait.accents.gap + 1 == 1280 - active.settings.rightMargin)
    for _, entry in ipairs(s.agentView.entries) do
        machine:dispatch("pointermoved", entry.x + 2, entry.y + 2)
        click(entry.x + 2, entry.y + 2)
        machine:dispatch("mousepressed", entry.x + 2, entry.y + 2, 2)
        machine:dispatch("mousereleased", entry.x + 2, entry.y + 2, 2)
        if active.agentInspectionPanel then machine:dispatch("keypressed", "escape") end
        if active.battlefieldInspectionCell then
            assert(active.battlefieldInspectionCell == cell)
            click(entry.x + 2, entry.y + 2)
        end
    end
    assert(active.activeAgentId == selected and s.agentView.selected == selected)
    for _, id in ipairs(s.package.agentIds) do assert(s.agentDeployment.placements[id] == cell) end
    render("agent_action.png")
    local function beginDrag()
        local entry = hand.entries[1]
        machine:dispatch("mousepressed", entry.x + 8, entry.y + 8, 1)
        machine:dispatch("pointermoved", equipment.x + 20, equipment.y + 25)
        assert(active.drag.active and not active.preview.cardId)
    end
    beginDrag()
    assert(s.agentStatus.byAgent[selected].resources == 5 and #hand.cards == 6)
    render("card_drag_valid.png")
    machine:dispatch("keypressed", "escape")
    machine:dispatch("mousereleased", equipment.x + 20, equipment.y + 25, 1)
    assert(#hand.cards == 6 and s.agentStatus.byAgent[selected].resources == 5)
    beginDrag()
    machine:dispatch("focus", false)
    assert(not active.drag.card and #hand.cards == 6)
    beginDrag()
    machine:dispatch("mousepressed", equipment.x, equipment.y, 2)
    assert(not active.drag.card)
    beginDrag()
    machine:dispatch("pointermoved", nil, nil)
    assert(not active.drag.card)
    beginDrag()
    machine:dispatch("mousereleased", 800, 400, 1)
    assert(#hand.cards == 6 and s.agentStatus.byAgent[selected].resources == 5)
    local expectedResources = 5 - s.agentCards.definitions.byId[hand.cards[1].cardId].cost
    local playedId = hand.cards[1].instanceId
    beginDrag()
    machine:dispatch("mousereleased", equipment.x + 20, equipment.y + 25, 1)
    assert(#hand.cards == 5 and s.agentStatus.byAgent[selected].resources == expectedResources)
    assert(s.agentAssets:at(selected, 1).instanceId == playedId and status.actionPoints == 2
        and status.actionPointCapacity == 3)
    assert(active.preview.cardId == "catburglar", "Equipped assets must keep their preview")
    machine:dispatch("mousereleased", equipment.x + 20, equipment.y + 25, 1)
    assert(s.agentStatus.byAgent[selected].resources == expectedResources and #hand.cards == 5)
    machine:dispatch("pointermoved", 800, 400)
    render("card_asset_played.png")
    status.resources, expectedResources = 0, 0
    beginDrag()
    assert(not active:dragResult().valid)
    render("card_drag_unaffordable.png")
    machine:dispatch("mousereleased", equipment.x + 74, equipment.y + 25, 1)
    assert(#hand.cards == 5 and s.agentStatus.byAgent[selected].resources == expectedResources)
    local nextVisit = require("src.states.agent_action").prepare({ selectedId = selected, session = s,
        portrait = portrait, width = 1280, panel = { font = active.font } })
    assert(nextVisit.assets == s.agentAssets and nextVisit.hand.images.catburglar and nextVisit.preview.displays.catburglar)
    assert(nextVisit.status.byAgent[selected].actionPoints == 2)
    nextVisit.hand:release(); nextVisit.previews:release(); nextVisit.statusView:release()
    nextVisit.done:release()
    nextVisit.exploration:release()
    -- Exercise a wider footprint and right-edge clamping without changing on-disk definitions.
    local definition = s.agentCards.definitions.byId.catburglar
    local oldSize = definition.asset_slots
    definition.asset_slots = 2
    status.resources = 8
    beginDrag()
    assert(not select(2, active:dragResult()).valid, "Occupied first slot must reject the attempted span")
    machine:dispatch("pointermoved", equipment.x + equipment.width - 10, equipment.y + 25)
    local _, target, start = active:dragResult()
    assert(target.valid and start == 6)
    render("card_drag_two_slots.png")
    machine:dispatch("mousereleased", equipment.x + equipment.width - 10, equipment.y + 25, 1)
    assert(s.agentAssets:at(selected, 6) == s.agentAssets:at(selected, 7)
        and s.agentAssets:at(selected, 6).size == 2 and status.resources == 8 - definition.cost)
    machine:dispatch("pointermoved", 800, 400)
    render("card_assets_two_slots.png")
    definition.asset_slots = oldSize
    assert(status.actionPoints == 1)
    status.resources = 10
    definition.asset_slots = 1
    local freeSlot = assert(s.agentAssets:findSpace(selected, 1))
    beginDrag()
    machine:dispatch("mousereleased", equipment.x + (freeSlot - 1) * (equipment.settings.size + equipment.settings.gap) + 20, equipment.y + 25, 1)
    definition.asset_slots = oldSize
    assert(status.actionPoints == 0 and status.resources == 10 - definition.cost)
    machine:dispatch("pointermoved", 800, 400)
    assert(active:allActionsSpent() and not active.done.hovered and machine.current == active)
    -- Forced appearance is independent of pointer state and does not complete a click.
    local drawImage, forced = love.graphics.draw, false
    love.graphics.draw = function(image, ...)
        if image == active.done.hover then forced = true end
        return drawImage(image, ...)
    end
    active:drawDone()
    love.graphics.draw = drawImage
    assert(forced and not active.done.hovered and not active.done.pressed)
    active:focus(false); assert(active:allActionsSpent())
    status.actionPoints = 1; assert(not active:allActionsSpent())
    status.actionPoints = 0
    local notice = require("data.agent_turn_view").actionsSpent
    assert(active.done.y - notice.gap - s.scene.accents.small:getHeight() >= 0)
    assert(notice.color[1] == 1 and notice.color[2] == 68 / 255 and notice.color[3] == 68 / 255)
    render("agent_actions_spent.png")
    beginDrag()
    assert(active:dragResult().reason == "NO ACTION POINTS")
    render("card_drag_no_actions.png")
    local countBefore = #hand.cards
    machine:dispatch("mousereleased", equipment.x + 128, equipment.y + 25, 1)
    assert(status.actionPoints == 0 and status.resources == 10 - definition.cost and #hand.cards == countBefore)
    assert(actPlays == 1)
    local audio = s.audio
    local preview = active.preview
    machine:change("mission_preparation")
    assert(not active.equipment)
    assert(not active.drag and not s.agentAssets)
    assert(not active.statusView and not statusView.actionFont and not s.agentStatus)
    assert(not active.preview and next(preview.images) == nil)
    assert(not active.hand and next(hand.images) == nil and not s.agentCards)
    assert(not first.image and next(portrait.images) == nil and next(audio.sources) == nil)
    machine.current:exit()
    canvas:release()
    require("tests.agent_turn")(write)

end
