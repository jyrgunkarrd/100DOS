local RoutingUI = require("src.ui.army_routing_drag")
local BattlefieldInspection = require("src.ui.battlefield_inspection")
local FateInspection = require("src.ui.fate_pool_inspection")
local Comparison = require("src.ui.battlefield_comparison")
local Inspection = require("src.ui.agent_inspection")
local Animation = require("src.ui.animation")
local Backdrop = require("src.ui.mission_backdrop")
local Session = require("src.sys.mission_session")
local EquipmentRow = require("src.ui.agent_equipment_row")
local Turn = require("src.sys.agent_turn")
local HuntView = require("src.ui.hunt_distribution")
local Clashes = require("src.sys.battlefield_clashes")
local Hand = require("src.ui.agent_hand")
local Preview = require("src.ui.card_preview")
local AgentStatus = require("src.sys.agent_status")
local StatusView = require("src.ui.agent_status")
local Assets = require("src.sys.agent_assets")
local Play = require("src.sys.card_play")
local Drag = require("src.ui.card_drag")
local Footprint = require("src.ui.asset_footprint")
local Button = require("src.ui.image_button")
local TurnView = require("data.agent_turn_view")
local Exploration = require("src.sys.location_exploration")
local ExplorationPanel = require("src.ui.location_exploration_panel")
local PreviewController = require("src.ui.card_preview_controller")
local LocationDisplay = require("src.sys.location_card_display")
local Resolution = require("src.sys.agent_action_resolution")
local AttackFeedback = require("src.ui.attack_feedback")
local AttackCutin = require("src.ui.attack_cutin")
local ActionPanel = require("src.ui.agent_action_panel")
local AgentAction = {}
AgentAction.__index = AgentAction

function AgentAction.new(stateMachine, width, height)
    return setmetatable({ stateMachine = stateMachine, width = width, height = height }, AgentAction)
end

function AgentAction.prepare(source)
    local id, session = source.selectedId, source.session
    assert(id and session.agentDeployment.known[id] and session.agentDeployment.placements[id],
        "Agent Action requires a deployed selected agent")
    assert(not AgentStatus.isExhausted(session.agentStatus, id), "Agent is exhausted")
    local chunk, message = love.filesystem.load("data/agent_action.lua")
    assert(chunk, message)
    local settings = chunk()
    for _, key in ipairs({ "rightMargin", "slideDuration", "movementDuration" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge,
            "Invalid Agent Action " .. key)
    end
    assert(type(settings.activeAgentColor) == "table", "Missing active agent color")
    for i = 1, 4 do
        local value = settings.activeAgentColor[i]
        assert(type(value) == "number" and value >= 0 and value <= 1, "Invalid active agent color")
    end
    local notice = TurnView.actionsSpent
    assert(type(notice) == "table" and type(notice.text) == "string", "Missing actions-spent notice")
    assert(type(notice.gap) == "number" and notice.gap >= 0 and notice.gap < math.huge,
        "Invalid actions-spent notice gap")
    for i = 1, 4 do
        local value = notice.color and notice.color[i]
        assert(type(value) == "number" and value >= 0 and value <= 1, "Invalid actions-spent notice color")
    end
    local portrait = source.portrait
    local bracketExtent = portrait.accents and portrait.accents.gap + 1 or 0
    local targetX = math.floor(source.width - settings.rightMargin - portrait.size - bracketExtent)
    assert(targetX >= session.grid.bounds.x + session.grid.bounds.width,
        "Agent Action portrait overlaps the map")
    local function loadData(path)
        local loader, failure = love.filesystem.load(path)
        assert(loader, failure)
        return loader()
    end
    local feedback = AttackFeedback.new(loadData("data/attack_feedback_view.lua"))
    local cutin = AttackCutin.new(loadData("data/attack_cutin_view.lua"), feedback.settings)
    local equipment = EquipmentRow.new(loadData("data/agent_equipment_slots.lua"),
        loadData("data/agent_equipment_view.lua"), source.width, session.scene.parallax.rectangle.y)
    local actions = ActionPanel.new(loadData("data/agent_action_panel_view.lua"), equipment, session.scene.accents, session.audio)
    assert(actions.y + actions.height <= (source.height or 720), "Action panel exceeds canvas")
    assert(equipment.x >= session.grid.bounds.x + session.grid.bounds.width,
        "Agent Action equipment overlaps the map")
    local status, cards = session.agentStatus, session.agentCards
    local staged = Turn.prepareActivation(session, id)
    local assets = session.agentAssets or Assets.new(session.package.agentIds, equipment.slots)
    local drag = Drag.new(loadData("data/card_play_view.lua"))
    local equipped = assets.byAgent[id].placements
    local previewCards = {}
    for _, card in ipairs(staged.hand) do previewCards[#previewCards + 1] = card end
    for _, asset in ipairs(equipped) do previewCards[#previewCards + 1] = asset.card end
    -- Paid draws can introduce card types not present in the opening hand.
    for _, card in ipairs(staged.drawPile) do previewCards[#previewCards + 1] = card end
    local hand = Hand.new(staged.hand, cards.definitions, loadData("data/agent_hand_view.lua"),
        session.scene.accents.small, equipment, targetX - bracketExtent, previewCards)
    local ok, preview = pcall(function()
        return Preview.new(cards.definitions, previewCards, loadData("data/card_preview_view.lua"),
            { heading = session.scene.accents.heading, small = session.scene.accents.small }, session.grid, source.height or 720, nil, session.package.biomeId)
    end)
    if not ok then hand:release(); error(preview, 0) end
    local statusOK, statusView = pcall(function()
        return StatusView.new(loadData("data/agent_status_view.lua"),
            { heading = session.scene.accents.heading, small = session.scene.accents.small })
    end)
    if not statusOK then hand:release(); preview:release(); error(statusView, 0) end
    local doneOK, done = pcall(Button.new, TurnView.done)
    if not doneOK then hand:release(); preview:release(); statusView:release(); error(done, 0) end
    local explorationOK, exploration = pcall(function()
        return ExplorationPanel.new(session, id, loadData("data/location_exploration_view.lua"),
            loadData("data/location_exploration_rules.lua"),
            { heading = session.scene.accents.heading, small = session.scene.accents.small })
    end)
    if not explorationOK then
        hand:release(); preview:release(); statusView:release(); done:release(); error(exploration, 0)
    end
    local locationOK, locationPreview = pcall(function()
        local locationCards = {}
        for _, cardId in ipairs(session.locationCardPool.ids) do locationCards[#locationCards + 1] = { cardId = cardId } end
        return Preview.new(session.locationCardPool, locationCards, loadData("data/location_card_preview_view.lua"),
            { heading = session.scene.accents.heading, small = session.scene.accents.small },
            session.grid, source.height or 720, LocationDisplay.normalize, session.package.biomeId)
    end)
    if not locationOK then
        exploration:release(); hand:release(); preview:release(); statusView:release(); done:release()
        error(locationPreview, 0)
    end
    cutin:bind(locationPreview, portrait, id)
    feedback.cutin = cutin
    local testFeedback = require("src.ui.talent_test_feedback").new(cutin, locationPreview, portrait, id, session)
    local testPanel = require("src.ui.talent_test_panel").new(session, id, source.width, locationPreview, portrait)
    feedback:bindAudio(session, id)
    local previews = PreviewController.new(preview, locationPreview, session.audio, function(agentId) return exploration:agentName(agentId) end)
    for _, diagnostic in ipairs(locationPreview.diagnostics) do print("[Location preview] " .. diagnostic) end
    for _, diagnostic in ipairs(exploration.diagnostics) do print("[Exploration] " .. diagnostic) end
    for _, diagnostic in ipairs(hand.diagnostics) do print("[Agent hand] " .. diagnostic) end
    for _, diagnostic in ipairs(preview.diagnostics) do print("[Card preview] " .. diagnostic) end
    return { activeAgentId = id, settings = settings, startX = portrait.x, targetX = targetX,
        y = portrait.y, portraitAge = source.portraitAge or 0, font = source.panel.font, equipment = equipment,
        cards = cards, stagedCards = staged, hand = hand, preview = preview, actions = actions,
        status = status, statusView = statusView, assets = assets, drag = drag, done = done, exploration = exploration, previews = previews, feedback = feedback, testPanel = testPanel, testFeedback = testFeedback }
end

function AgentAction:enter(previousName, prepared)
    self.session, self.portrait = prepared.session, prepared.portrait
    self.session.missionFooter:clearHover()
    self.equipment = prepared.equipment
    self.actions = prepared.actions
    self.hand = prepared.hand
    self.preview = prepared.preview
    self.previews = prepared.previews
    self.feedback = prepared.feedback
    self.testPanel, self.testFeedback = prepared.testPanel, prepared.testFeedback
    if self.session.attackFeedback then self.feedback:start(self.session.attackFeedback) end
    self.done = prepared.done
    self.exploration = prepared.exploration
    self.drag, self.session.agentAssets = prepared.drag, prepared.assets
    self.handReadyAt = prepared.settings.slideDuration + self.hand:revealDuration()
    self.statusView, self.session.agentStatus = prepared.statusView, prepared.status
    self.session.agentView.status = prepared.status
    self.session.agentCards = prepared.cards
    Turn.commitActivation(self.session, prepared.activeAgentId, prepared.stagedCards)
    self.activeAgentId, self.settings = prepared.activeAgentId, prepared.settings
    self.comparison = Comparison.new(self.session.agentCards.agents)
    self.maneuver = require("src.ui.battlefield_action_panel").new(self.session, self.activeAgentId)
    self.startX, self.targetX, self.y = prepared.startX, prepared.targetX, prepared.y
    self.portraitAge, self.font, self.elapsed = prepared.portraitAge, prepared.font, 0
    self.session.agentView:clearHover()
    self.session.agentView.selected = self.activeAgentId
    if self.session.audio then self.session.audio:playOverlapping("agentAct") end
    self:update(0)
end

function AgentAction:resolving()
    return self.session.reinforcementFeedback ~= nil or HuntView.busy(self.session) or self.feedback:busy() or (self.testFeedback and self.testFeedback:busy())
end

function AgentAction:combatFeedbackBusy()
    return self.feedback:busy() or (self.testFeedback and self.testFeedback:busy())
end

function AgentAction:update(dt)
    self.session.missionFooter.routing:update(dt)
    if require("src.ui.clash_reinforcement_feedback").update(self.session, dt) then
        local clash = Clashes.ready(self.session, self.activeAgentId)
        if clash then self:openClash(clash)
        else self:endTurn(); if not self.session then return end end
    end
    require("src.ui.phase_end_feedback").update(self.session, dt)
    require("src.ui.doom_clock").update(self.session, dt)
    if require("src.sys.mission_outcome").finished(self.session) then
        -- Gameplay is finished, but the winning hit still owns its full presentation.
        local testing = self.testFeedback and self.testFeedback:busy()
        if testing then
            if self.testFeedback:update(dt) then
                self.testFeedback:clear(); self.session.talentFeedback = nil
            end
        elseif self.feedback:update(dt) then
            self.feedback:clear(); self.session.attackFeedback = nil; self.exploration.attackingId = nil
        end
        Backdrop.update(self.session.scene, dt)
        return
    end
    BattlefieldInspection.update(self)
    Inspection.update(self, dt)
    self.session.agentView:updateMovement(dt)
    local testing = self.testFeedback and self.testFeedback:busy()
    if testing then
        if self.testFeedback:update(dt) then
            self.testFeedback:clear(); self.session.talentFeedback = nil
            if self.session.pendingEndTurn then
                local clash = Clashes.ready(self.session, self.activeAgentId)
                if clash then self:openClash(clash)
                else self:endTurn(); return end
            end
        end
    end
    if not testing and self.feedback:update(dt) then
        self.feedback:clear(); self.session.attackFeedback = nil; self.exploration.attackingId = nil
        if self.turnReturn then self:completeTurn(); return end
        if self:returnAfterDefeat() then return end
    end
    if not self:resolving() and self.session.pendingManeuver and not self.maneuver.open then
        self:focus(false, true)
        self.maneuver:start()
    end
    self.maneuver:update(dt)
    local attack = self.feedback:current()
    if attack then
        self.exploration.attackingId = attack.instanceId
        self.exploration:showInstance(attack.instanceId)
    end
    self.exploration:update(dt)
    local delta = math.max(0, dt)
    self.elapsed, self.portraitAge = self.elapsed + delta, self.portraitAge + delta
    local progress = Animation.easeOutQuad(Animation.progress(self.elapsed, 0, self.settings.slideDuration))
    self.portrait:setPosition(Animation.lerp(self.startX, self.targetX, progress), self.y)
    self.done.x = math.floor(self.portrait.x + (self.portrait.size - self.done.width) / 2)
    self.done.y = self.statusView:layout(self.portrait, self.session.agentStatus.byAgent[self.activeAgentId]).y
        - TurnView.doneGap - self.done.height
    if self.elapsed >= self.handReadyAt then self:syncPreview() end
    Backdrop.update(self.session.scene, dt)
    if self.session.audio then self.session.audio:update() end
end

function AgentAction:syncPreview()
    local footer = self.session.missionFooter
    if (self.session.scene.silencerView and self.session.scene.silencerView.hover.target)
        or footer.routing.drag.pending or footer.routing.receipt or footer.hoveredId or (footer.jacl and footer.jacl.hover) then
        Inspection.clear(self); self.previews:clear(); return
    end
    if self.fatePoolInspection or self.agentInspectionPanel or self.battlefieldInspectionCell
        or self.actions.open or self.maneuver.open or self.drag.active
        or self:resolving() or self.testPanel.card then
        Inspection.clear(self); self.previews:clear(); return
    end
    if Inspection.pointer(self, self.inspectionX, self.inspectionY) then return end
    local location = self.exploration:hoveredMilledCard() or self.exploration:hoveredCard()
    if location then self.previews:show("location", location); return end
    local card
    for _, entry in ipairs(self.hand.entries) do
        if entry.card.instanceId == self.hand.hovered then card = entry.card; break end
    end
    if not card then
        local index = self.equipment:hit(self.hand.pointerX, self.hand.pointerY)
        local asset = index and self.session.agentAssets:at(self.activeAgentId, index)
        card = asset and asset.card
    end
    self.previews:show("player_card", card)
end

function AgentAction:pointermoved(x, y)
    if RoutingUI.pointer(self, x, y) then return end
    local footer = self.session.missionFooter
    if FateInspection.pointermoved(self, x, y) then footer:clearHover(); return end
    if self.battlefieldInspectionCell then footer:clearHover(); return end
    if Inspection.panelPointer(self, x, y) then return end
    footer:pointer(self.session, not self.drag.active and x or nil, y)
    if HuntView.busy(self.session) then return end
    self.inspectionX, self.inspectionY = x, y
    self.actions:pointer(x, y)
    if self:resolving() or AgentStatus.isDefeated(self.session.agentStatus, self.activeAgentId) then return end
    if self.maneuver.open then self.maneuver:pointer(x, y); self.previews:clear(); return end
    if self.elapsed >= self.handReadyAt then
        if not x or not y or x < 0 or y < 0 or x >= self.width or y >= self.height then
            self:focus(false); return
        end
        if self.actions.open and not self.testPanel.card then
            self.hand:clearHover(); self.exploration:cancel(); self.done:cancelPress()
            self:syncPreview(); return
        end
        self.exploration:pointermoved(not self.drag.card and x or nil, y)
        if self.testPanel.card then
            self.testPanel:pointermoved(x, y)
            self.hand:hover(x, y); self.previews:clear(); return
        end
        self.drag:move(x, y)
        if self.done:updatePointer(not self.drag.card and x or nil, y) and self.session.audio then
            self.session.audio:play("hover")
        end
        if self.drag.active then self.hand:clearHover(); self.previews:clear(); return end
        self.hand:hover(x, y)
        self:syncPreview()
    end
end

function AgentAction:focus(focused, preserveActionPanel)
    if not focused then self.session.missionFooter:clearHover(); self.session.missionFooter.routing:cancel() end
    FateInspection.focus(self, focused)
    if not focused and self.maneuver then self.maneuver.pressed = nil; self.maneuver:pointer(nil, nil) end
    Inspection.focus(self, focused)
    if not focused then self.inspectionX, self.inspectionY = nil, nil end
    if not focused then
        if self.actions then
            if not preserveActionPanel then self.actions:close() end
            self.actions.pressed = nil; self.actions:pointer(nil, nil)
        end
        self.exploration:cancel()
        self.locationPressed = nil
        if self.testPanel then self.testPanel.pressed = nil; self.testPanel:pointermoved(nil, nil) end
        self.done:cancelPress(); self.done:updatePointer(nil, nil)
        self.drag:cancel(); self.hand:clearHover(); self.previews:clear()
    end
end

function AgentAction:wheelmoved(x, y)
    if self.session.missionFooter.routing.receipt or self.session.missionFooter.routing.drag.pending then return end
    if self.session.missionFooter:wheel(y) then return end
    if HuntView.busy(self.session) then return end
    if FateInspection.wheel(self, y) then return end
    if BattlefieldInspection.wheel(self, y) then return end
    if self.agentInspectionPanel and Inspection.wheel(self, y) then return end
    if self.maneuver.open then self.maneuver:wheel(y); return end
    if self.actions.open and not self.testPanel.card then return end
    if self.testPanel.card and not self:resolving() then
        if not self.testPanel:wheel(self.inspectionX, self.inspectionY, y) then self.hand:wheelmoved(x, y) end
        return
    end
    if self.elapsed >= self.handReadyAt and not self.drag.card and not self:resolving() then
        if love.keyboard.isDown("lshift", "rshift") and self.previews:wheelmoved(y) then return end
        if self.exploration:wheelmoved(y) then self:syncPreview(); return end
        self.hand:wheelmoved(x, y); self:syncPreview()
    end
end

function AgentAction:mousepressed(x, y, button)
    if RoutingUI.press(self, x, y, button) then return end
    if HuntView.busy(self.session) then return end
    if FateInspection.mousepressed(self, x, y, button) then return end
    if self:resolving() or AgentStatus.isDefeated(self.session.agentStatus, self.activeAgentId) then return end
    if not self.battlefieldInspectionCell and Inspection.mousepressed(self, x, y, button) then return end
    if BattlefieldInspection.mousepressed(self, x, y, button) then return end
    if button == 2 then
        if self.maneuver.open then self.maneuver:cancelSelection(); return end
        if not self.session.pendingEndTurn then self.testPanel:close() end
        self:focus(false); return
    end
    if button ~= 1 or self.elapsed < self.handReadyAt then return end
    self:pointermoved(x, y)
    if not x or not y then return end
    if self.maneuver.open then self.maneuver:press(x, y); return end
    if self.testPanel.card then self.testPanel:press(x, y, self.hand); return end
    if self:basicActionsEnabled() and self.actions:press(x, y, self.session, self.activeAgentId) then
        self.previews:clear(); Inspection.clear(self); return
    end
    if not self.drag.card and not self.exploration:busy() then
        if self.exploration:pressReceipt(x, y) then return end
        local card = self.exploration:hoveredCard()
        if card then self.locationPressed = card.instanceId; return end
    end
    if not self.drag.card and self.done:contains(x, y) then self.done:press(x, y, button); return end
    local hit = self.hand:hover(x, y)
    -- Gap hover keeps previews continuous; only visible card pixels start a drag.
    if hit and y < hit.y + self.hand.settings.height then self.drag:press(hit.card, x, y) end
end

function AgentAction:dragResult()
    local card = self.drag.card
    if not card then return end
    local general = Play.evaluate(self.session, self.activeAgentId, card.instanceId)
    local start = self.equipment:dropStart(self.drag.x, self.drag.y, general.size)
    local target = start and Play.evaluate(self.session, self.activeAgentId, card.instanceId, start) or general
    return general, target, start
end

function AgentAction:mousereleased(x, y, button)
    if RoutingUI.releasePointer(self, x, y, button) then return end
    if HuntView.busy(self.session) then return end
    if FateInspection.mousereleased(self, x, y, button) or Inspection.mousereleased(self, x, y, button)
        or BattlefieldInspection.mousereleased(self, button) then return end
    if self:resolving() or AgentStatus.isDefeated(self.session.agentStatus, self.activeAgentId) then return end
    if button ~= 1 then return end
    if self.maneuver.open then
        self.maneuver:releasePointer(x, y)
        return
    end
    if self.actions.pressed then
        if not self:basicActionsEnabled() then self.actions.pressed = nil; return end
        local consumed, kind, args = self.actions:releasePointer(x, y, self.session, self.activeAgentId)
        if kind then self:basicAction(kind, args) end
        if consumed then self:syncPreview(); return end
    end
    if self.testPanel.card then
        local args = self.testPanel:releasePointer(x, y, self.hand)
        if args then
            local success, result = self:performAction(args.locationKind and "location_action" or args.battlefieldKind and "battlefield" or "talent_test", args)
            if not success then self.testPanel.error = result end
        end
        return
    end
    if self.exploration:releaseReceipt(x, y) then self:syncPreview(); return end
    if self.locationPressed then
        self.exploration:pointermoved(x, y)
        local card, pressed = self.exploration:hoveredCard(), self.locationPressed
        self.locationPressed = nil
        if card and card.instanceId == pressed then
            if self.session.locationDecks.byCell[self.exploration.cell].inPlay[card.instanceId] then
                self.testPanel:open(card); self.previews:clear(); Inspection.clear(self)
            end
        end
        return
    end
    if not self.drag.card then
        if self.done:releasePointer(x, y, button) then self:endTurn() end
        return
    end
    self.exploration:cancel()
    self.done:cancelPress()
    self:pointermoved(x, y)
    if self.drag.active then
        local _, _, start = self:dragResult()
        if start then
            local success = self:performAction("play_card", { instanceId = self.drag.card.instanceId, start = start })
            if success then
                if self.session.audio then self.session.audio:playOverlapping("hexDeploy") end
                self.hand.cards = self.session.agentCards.byAgent[self.activeAgentId].hand
                self.hand:layout()
            end
        end
    end
    self.drag:cancel()
    self:pointermoved(x, y)
end

local function releaseReturn(prepared)
    if not prepared then return end
    for _, key in ipairs({ "panel", "portrait", "nextPhase" }) do if prepared[key] then prepared[key]:release() end end
end

function AgentAction:performAction(kind, args)
    if self.agentInspectionPanel then return false, "CLOSE INSPECTION FIRST" end
    if self:resolving() then return false, "ATTACKS RESOLVING" end
    local ok, plan, reason = pcall(Resolution.prepare, self.session, self.activeAgentId, kind, args)
    if not ok then self.actionError = tostring(plan); return false, self.actionError end
    if not plan then return false, reason end
    local preparedReturn
    if plan.status.defeated then
        local ready, result = pcall(require("src.states.mission_action").prepareReturn, self)
        if not ready then self.actionError = tostring(result); return false, self.actionError end
        preparedReturn = result
    end
    local success, result, feedback = Resolution.commit(plan)
    if not success then releaseReturn(preparedReturn); return false, result end
    self.defeatReturn = preparedReturn
    if feedback then
        self:focus(false, not plan.status.defeated)
        self.feedback:start(feedback)
        local event = self.feedback:current()
        self.exploration.attackingId = event.instanceId
        self.exploration:showInstance(event.instanceId)
    end
    if kind == "talent_test" or kind == "battlefield" or kind == "location_action" then
        self.testPanel:close(); self.testFeedback:start(result)
        self.hand.cards = self.session.agentCards.byAgent[self.activeAgentId].hand
        self.hand:layout(); self.previews:clear()
    end
    return true, result
end

function AgentAction:returnAfterDefeat()
    if not AgentStatus.isDefeated(self.session.agentStatus, self.activeAgentId) then return false end
    local prepared = self.defeatReturn
    if not prepared then
        local ok, value = pcall(require("src.states.mission_action").prepareReturn, self)
        if not ok then self.actionError = tostring(value); return false end
        prepared = value
    end
    self.defeatReturn = nil
    self:focus(false)
    self.session.agentView.selected = nil
    prepared.session, self.session = self.session, nil
    self.stateMachine:change("mission_action", prepared)
    return true
end

function AgentAction:explore()
    if self.fatePoolInspection or self.agentInspectionPanel or self.testPanel.card
        or self.maneuver.open or self.session.pendingEndTurn then return false end
    if self.elapsed < self.handReadyAt or self.drag.card or self.exploration:busy() or self:resolving() then return false end
    local success, card = self:performAction("explore", { rules = self.exploration.rules })
    if not success then self.explorationError = card; return false end
    self.explorationError = nil
    self.exploration:revealed(card)
    self:syncPreview()
    if self.session.audio then self.session.audio:playOverlapping("selection") end
    return true
end

function AgentAction:basicActionsEnabled()
    return self.elapsed >= self.handReadyAt and not self.maneuver.open and not self.drag.card and not self.testPanel.card
        and not self.exploration:busy() and not self:resolving()
        and not self.fatePoolInspection and not self.agentInspectionPanel and not self.session.pendingEndTurn
        and not AgentStatus.isExhausted(self.session.agentStatus, self.activeAgentId)
end

function AgentAction:basicAction(kind, args)
    if not self:basicActionsEnabled() then return false end
    if kind == "location" then
        if args.locationKind == "explore" then
            return self:explore()
        end
        local available = require("src.sys.location_actions").available(self.session,self.activeAgentId,args.locationKind)
        if not available.valid then self.actions.error = available.reason; return false end
        self.actions.targeting, self.actions.error = false, nil
        self.previews:clear(); Inspection.clear(self)
        self.testPanel:openLocation(args.locationKind)
        return true
    end
    if kind == "battlefield" then
        local result = require("src.sys.battlefield_action").available(self.session, self.activeAgentId, args.battlefieldKind)
        if not result.valid then self.actions.error = result.reason; return false end
        self.actions.targeting, self.actions.error = false, nil
        self.previews:clear(); Inspection.clear(self)
        self.testPanel:openBattlefield(args)
        return true
    end
    local wasOpen = self.actions.open
    local success, result = self:performAction(kind, args or {})
    if not success then self.actions.error = result; return false, result end
    self.actions.error, self.actions.targeting = nil, false
    if not AgentStatus.isDefeated(self.session.agentStatus, self.activeAgentId) then self.actions.open = wasOpen end
    if kind == "draw_card" then
        self.hand.cards = self.session.agentCards.byAgent[self.activeAgentId].hand
        self.hand.first = math.max(1, #self.hand.cards - self.hand.capacity + 1)
        self.hand:layout()
    elseif kind == "move" then
        self.session.agentView:animateMovement(self.settings.movementDuration)
        self.exploration:setCell(result.cellId)
    end
    self.previews:clear(); Inspection.clear(self)
    if self.session.audio then self.session.audio:playOverlapping(kind == "move" and "agentMove" or "selection") end
    return true, result
end

function AgentAction:openClash(clash)
    self:focus(false)
    self.testPanel:openBattlefield({ battlefieldKind = "engage", clash = clash })
end

function AgentAction:endTurn()
    if self.fatePoolInspection or self.agentInspectionPanel or self.testPanel.card or self.maneuver.open then return false end
    if self.elapsed < self.handReadyAt or self.drag.card or self:resolving()
        or AgentStatus.isExhausted(self.session.agentStatus, self.activeAgentId) then return false end
    local planned, plan, reason = pcall(Resolution.prepare, self.session, self.activeAgentId, "end_turn", {})
    if not planned or not plan then self.endTurnError = tostring(planned and reason or plan); return false end
    local prepared = self.turnReturn
    if not prepared then
        local ok, result = pcall(require("src.states.mission_action").prepareReturn, self)
        if not ok then self.endTurnError = tostring(result); return false end
        prepared = result
    end
    local success, message, feedback = Resolution.commit(plan)
    if not success then
        if not self.turnReturn then releaseReturn(prepared) end
        self.endTurnError = message
        return false
    end
    if not self.turnReturn and self.session.audio then self.session.audio:playOverlapping("selection") end
    self.turnReturn, self.endTurnError = prepared, nil
    if type(message) == "table" and message.reinforcement then
        self:focus(false)
        if not self.session.scene.reinforcementView then
            self.session.scene.reinforcementView = require("src.ui.clash_reinforcement_feedback").new(self.session)
        end
        return true
    end
    if type(message) == "table" and message.clash then
        self:openClash(message.clash)
        return true
    end
    self:focus(false)
    if feedback then
        self.feedback:start(feedback)
        local event = self.feedback:current()
        self.exploration.attackingId = event.instanceId
        self.exploration:showInstance(event.instanceId)
    else self:completeTurn() end
    return true
end

function AgentAction:completeTurn()
    local prepared = assert(self.turnReturn, "Missing prepared turn return")
    self.turnReturn = nil
    self.session.agentView.selected = nil
    prepared.session, self.session = self.session, nil
    self.stateMachine:change("mission_action", prepared)
    return true
end

function AgentAction:keypressed(key, _, isrepeat)
    if require("src.sys.mission_outcome").finished(self.session) and self:combatFeedbackBusy() then return end
    if RoutingUI.key(self, key) then return end
    if self.session.reinforcementFeedback then return end
    if HuntView.keypressed(self, key) then return end
    if FateInspection.keypressed(self, key, isrepeat) then return end
    if self.battlefieldInspectionCell or Inspection.keypressed(self, key) then return end
    if key == "escape" then
        if self.maneuver.open then self.maneuver:cancelSelection(); return end
        if not self.session.pendingEndTurn then self.testPanel:close() end
        self:focus(false)
    end
    if key == "a" and self:basicActionsEnabled() then
        self:focus(false, true)
        self.actions:toggle()
    end
end

function AgentAction:drawAssets()
    local assets, row, c = self.session.agentAssets, self.equipment, self.drag.settings
    local board = assets.byAgent[self.activeAgentId]
    local font = self.session.scene.accents.heading
    for _, asset in ipairs(board.placements) do
        Footprint.draw(row, asset, self.hand.images[asset.cardId], font, c)
    end
    if not self.drag.active then return end
    local general, target, start = self:dragResult()
    local g = love.graphics
    g.push("all")
    g.setLineWidth(1); g.setLineStyle("rough")
    g.setColor(general.valid and c.validColor or c.invalidColor)
    for i = 1, #row.slots do
        if not assets:at(self.activeAgentId, i) then
            local x, y, w, h = row:bounds(i, 1)
            g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        end
    end
    if start then
        if target.valid then
            local d = self.session.agentCards.definitions.byId[self.drag.card.cardId]
            Footprint.draw(row, { start = start, size = target.size, health = d.health or 0, defiance = d.defiance or 0 },
                self.hand.images[self.drag.card.cardId], font, c, true)
        else
            local x, y, w, h = row:bounds(start, target.size)
            g.setColor(c.invalidColor); g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        end
    end
    if not target.valid then
        g.setFont(self.session.scene.accents.small); g.setColor(c.invalidColor)
        g.printf(target.reason, row.x, row.y + row.height + c.messageGap, row.width, "right")
    end
    g.pop()
end

function AgentAction:drawDrag()
    if not self.drag.active then return end
    local result = self:dragResult()
    if result.cost then self.statusView:drawProjection(self.portrait,
        self.session.agentStatus.byAgent[self.activeAgentId], result.cost, self.drag.settings) end
    local size = self.drag.settings.portraitSize
    love.graphics.push("all")
    Footprint.portrait(self.hand.images[self.drag.card.cardId], math.floor(self.drag.x - size / 2),
        math.floor(self.drag.y - size / 2), size, 1, self.session.scene.accents.small)
    love.graphics.pop()
end

function AgentAction:allActionsSpent()
    return self.session.agentStatus.byAgent[self.activeAgentId].actionPoints == 0
end

function AgentAction:drawDone()
    local spent = self:allActionsSpent()
    self.done:draw(nil, spent)
    local defeated = AgentStatus.isDefeatedState(self.feedback:status(self.session.agentStatus.byAgent[self.activeAgentId]))
    if not spent and not defeated then return end
    local g, notice = love.graphics, TurnView.actionsSpent
    local font = self.session.scene.accents.small
    local label = defeated and TurnView.defeatedLabel or notice.text
    local width = font:getWidth(label)
    local x = math.floor(self.done.x + (self.done.width - width) / 2)
    local y = math.floor(self.done.y - notice.gap - font:getHeight())
    g.push("all")
    g.setFont(font); g.setColor(notice.color)
    g.print(label, x, y)
    g.pop()
end

function AgentAction:comparisonModel()
    if not self.actions.open or not self.actions.targeting or self.actions.battlefield or not self:basicActionsEnabled() then return nil end
    local move = require("src.sys.agent_basic_actions").evaluate(self.session, self.activeAgentId, "move")
    if not move.valid then return nil end
    local eligible = {}
    for _, id in ipairs(move.targets) do eligible[id] = true end
    return self.comparison:build(self.session, self.activeAgentId, eligible, self.actions.pointerX, self.actions.pointerY)
end

function AgentAction:draw()
    local s = self.session
    local comparison = self:comparisonModel()
    local positions = comparison and Comparison.positionsHeld()
    local comparing = comparison and not positions
    Backdrop.draw(s.scene)
    s.grid:draw(s.art, nil, comparison and {} or s.agentDeployment.placements)
    if comparing then self.comparison:draw(s.grid, comparison, s.scene.accents.small) end
    if s.armyView then s.armyView:draw(self.maneuver.flight and self.maneuver.flight:values()) end
    HuntView.outlines(s)
    self.actions:drawTargets(s, self.activeAgentId, comparison ~= nil)
    local liveStatus = s.agentView.status
    if self:resolving() then
        local byAgent = {}
        for id, status in pairs(s.agentStatus.byAgent) do byAgent[id] = status end
        byAgent[self.activeAgentId] = self.feedback:status(byAgent[self.activeAgentId])
        s.agentView.status = { byAgent = byAgent }
    end
    s.agentView:draw(nil, { deploymentIndicators = false, rosterIndicators = false,
        hideMapPortraits = comparing == true,
        selectionColor = self.settings.activeAgentColor })
    s.agentView.status = liveStatus
    self.portrait:draw(self.activeAgentId, self.font, s.scene.accents.small, self.portraitAge, { hideLabel = true })
    self.statusView:draw(self.portrait, self.feedback:status(s.agentStatus.byAgent[self.activeAgentId]))
    self.exploration:draw(self.elapsed >= self.handReadyAt and not self.drag.card and not self:resolving())
    self:drawDone()
    self.equipment:draw(s.scene.accents.small, self.elapsed)
    self:drawAssets()
    self.hand:draw(self.elapsed - self.settings.slideDuration,
        self.drag.active and self.drag.card.instanceId, self.drag.settings.draggedAlpha)
    require("src.ui.doom_clock").draw(s)
    HuntView.markers(s, s.scene.accents.small)
    s.missionFooter:draw(s)
    self.actions:draw(s, self.activeAgentId, self.exploration:agentName(self.activeAgentId), self:basicActionsEnabled())
    self.previews:draw()
    BattlefieldInspection.draw(self)
    self:drawDrag()
    self.testPanel:draw(self.hand, s.scene.accents.small, s.scene.accents.heading)
    self.maneuver:draw(s.scene.accents.small)
    Inspection.draw(self)
    FateInspection.draw(self)
    if require("src.sys.mission_outcome").finished(s) and not self:combatFeedbackBusy() then
        HuntView.draw(s, self.width, self.height, s.scene.accents.small, s.scene.accents.heading)
    elseif self.testFeedback:busy() then self.testFeedback:draw(self.width, self.height, s.scene.accents.heading)
    else self.feedback:draw(self.width, self.height, s.scene.accents.heading) end
    s.missionFooter:drawPreview(s)
    require("src.ui.transport_hover").drawFor(self)
    s.missionFooter.routing:draw(s)
    if s.scene.phaseFeedbackView then s.scene.phaseFeedbackView:draw(self.width, self.height, s.scene.accents.small) end
    if s.scene.reinforcementView then s.scene.reinforcementView:draw(self.width, self.height, s.scene.accents.small) end
    require("src.ui.doom_clock").drawWarning(s, self.width, self.height)
end

-- No portrait input callbacks: the committed active agent cannot be changed here.
function AgentAction:exit()
    FateInspection.release(self)
    if self.comparison then self.comparison:release(); self.comparison = nil end
    if self.maneuver then self.maneuver:release(); self.maneuver = nil end
    BattlefieldInspection.release(self)
    Inspection.release(self)
    releaseReturn(self.defeatReturn); self.defeatReturn = nil
    releaseReturn(self.turnReturn); self.turnReturn = nil
    if self.feedback then self.feedback:release(); self.feedback = nil end
    if self.testFeedback then self.testFeedback:release(); self.testFeedback = nil end
    if self.testPanel then self.testPanel:release(); self.testPanel = nil end
    self.actions = nil
    if self.exploration then self.exploration:release(); self.exploration = nil end
    if self.done then self.done:release(); self.done = nil end
    if self.drag then self.drag:cancel(); self.drag = nil end
    if self.statusView then self.statusView:release(); self.statusView = nil end
    if self.previews then self.previews:release(); self.previews = nil end
    self.preview = nil
    if self.hand then self.hand:release(); self.hand = nil end
    if self.portrait then self.portrait:release() end
    if self.session then Session.release(self.session) end
    self.equipment = nil
    self.portrait, self.session, self.font, self.settings, self.activeAgentId = nil, nil, nil, nil, nil
end

return AgentAction

