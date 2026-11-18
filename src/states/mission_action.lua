local RoutingUI = require("src.ui.army_routing_drag")
local BattlefieldInspection = require("src.ui.battlefield_inspection")
local FateInspection = require("src.ui.fate_pool_inspection")
local Inspection = require("src.ui.agent_inspection")
local AgentAction = require("src.states.agent_action")
local Animation = require("src.ui.animation")
local AgentIndex = require("data.agents.index")
local Portrait = require("src.ui.selected_agent_portrait")
local DeploymentPrompt = require("data.deployment_prompt")
local Panel = require("src.ui.mission_action_panel")
local Session = require("src.sys.mission_session")
local Backdrop = require("src.ui.mission_backdrop")
local Button = require("src.ui.image_button")
local Status = require("src.sys.agent_status")
local TurnView = require("data.agent_turn_view")
local Lifecycle = require("src.sys.mission_lifecycle")
local Turn = require("src.sys.agent_turn")
local HuntView = require("src.ui.hunt_distribution")
local Action = {}
Action.__index = Action

function Action.new(stateMachine, width, height)
    return setmetatable({ stateMachine = stateMachine, width = width, height = height }, Action)
end

function Action.prepare(source)
    HuntView.validate()
    require("src.ui.doom_clock").validate()
    assert(source.agentDeployment:allAssigned(), "All agents must be assigned before action")
    local chunk, message = love.filesystem.load("data/mission_action.lua")
    assert(chunk, message)
    local settings = chunk()
    local timing = assert(settings.transition, "Missing action transition settings")
    for _, key in ipairs({ "duration", "outgoingDuration", "incomingDelay", "incomingDuration" }) do
        assert(type(timing[key]) == "number" and timing[key] >= 0 and timing[key] < math.huge,
            "Invalid action transition " .. key)
    end
    assert(timing.outgoingDuration <= timing.duration
        and timing.incomingDelay + timing.incomingDuration <= timing.duration, "Action fades exceed transition duration")
    local oldPrompt = source:promptLayout()
    local brightness = {}
    for _, entry in ipairs(source.roster.entries) do
        brightness[entry.id] = source.agentView.rosterBrightness[entry.id] or 1
    end
    local mission = Lifecycle.prepare(source)
    local agents = AgentIndex.refresh()
    local panel = Panel.new(source.roster, source.scene.accents.heading or love.graphics.getFont(), settings)
    local ok, portrait = pcall(Portrait.new, source.package.agentIds, source.grid, source.width, settings.portrait, agents, source.package.biomeId)
    if not ok then panel:release(); error(portrait, 0) end
    local buttonOK, nextPhase = pcall(Button.new, TurnView.nextPhase)
    if not buttonOK then panel:release(); portrait:release(); error(nextPhase, 0) end
    nextPhase.x = math.floor(source.roster.x + (source.roster.width - nextPhase.width) / 2)
    nextPhase.y = source.roster.y - TurnView.nextPhaseGap - nextPhase.height
    panel.promptY = panel.promptY - nextPhase.height - TurnView.nextPhaseGap
    local footer = source.missionFooter
    if not footer then
        local footerOK, result = pcall(require("src.ui.mission_footer").new, source.scene, mission or source)
        if not footerOK then
            nextPhase:release(); portrait:release(); panel:release(); error(result, 0)
        end
        footer = result
    end
    for _, diagnostic in ipairs(portrait.diagnostics) do print("[Mission action] " .. diagnostic) end
    for _, diagnostic in ipairs(panel.diagnostics) do print("[Mission action] " .. diagnostic) end
    return { mission = mission, panel = panel, settings = settings, portrait = portrait, oldPrompt = oldPrompt,
        brightness = brightness, nextPhase = nextPhase, footer = footer }
end

function Action.prepareReturn(source)
    local proxy = setmetatable({ width = source.width, height = source.height,
        promptLayout = function() return nil end }, { __index = source.session })
    local prepared = Action.prepare(proxy)
    prepared.returning = true
    prepared.settings.transition = { duration = TurnView.returnDuration, outgoingDuration = 0,
        incomingDelay = 0, incomingDuration = TurnView.returnDuration }
    for id in pairs(prepared.brightness) do prepared.brightness[id] = 1 end
    return prepared
end

function Action:enter(previousName, prepared)
    self.session, self.panel, self.settings = prepared.session, prepared.panel, prepared.settings
    Lifecycle.commit(self.session, prepared.mission)
    self.session.missionFooter = prepared.footer
    self.session.missionFooter:clearHover()
    require("src.sys.mission_hunt").resolvePending(self.session)
    self.nextPhase = prepared.nextPhase
    self.session.agentView.status = self.session.agentStatus
    self.selectedId, self.pending = nil, nil
    self.portraitAge = nil
    self.elapsed = 0
    self.portrait, self.oldPrompt, self.oldReady = prepared.portrait, prepared.oldPrompt, prepared.ready
    self.startBrightness = prepared.brightness
    self.session.agentView:clearHover()
    self.session.agentView.selected = nil
    self.session.agentView.rosterBrightness = prepared.brightness
    if self.session.audio and not prepared.returning then self.session.audio:playOverlapping("ready") end
end

function Action:update(dt)
    self.session.missionFooter.routing:update(dt)
    require("src.ui.doom_clock").update(self.session, dt)
    require("src.sys.mission_phase").update(self.session, dt)
    HuntView.update(self.session, dt)
    BattlefieldInspection.update(self)
    Inspection.update(self, dt)
    self.session.agentView:updateMovement(dt)
    self.elapsed = self.elapsed + math.max(0, dt)
    if self.portraitAge then self.portraitAge = self.portraitAge + math.max(0, dt) end
    if self.elapsed >= self.settings.transition.outgoingDuration and self.oldReady then
        self.oldReady:release()
        self.oldReady, self.oldPrompt = nil, nil
    end
    Backdrop.update(self.session.scene, dt)
    if self.session.audio then self.session.audio:update() end
end

function Action:pointermoved(x, y)
    if RoutingUI.pointer(self, x, y) then return end
    if self.session.phaseFeedback or self.session.phaseTransition then return end
    local footer = self.session.missionFooter
    if FateInspection.pointermoved(self, x, y) then footer:clearHover(); return end
    if self.battlefieldInspectionCell then footer:clearHover(); return end
    if Inspection.panelPointer(self, x, y) then return end
    if footer:pointer(self.session, x, y) then
        self.session.agentView:clearHover(); Inspection.clear(self); return
    end
    if HuntView.busy(self.session) then return end
    if not self:inputReady() then return end
    if x == nil or y == nil then self:focus(false); return end
    if self.pending and self.pending.kind ~= "act" and self.pending.kind ~= "phase"
        and (x - self.pending.x)^2 + (y - self.pending.y)^2 > self.settings.clickThreshold^2 then
        self.pending = nil
    end
    self.session.agentView:hover(x, y)
    Inspection.pointer(self, x, y)
end

function Action:mousepressed(x, y, button)
    if RoutingUI.press(self, x, y, button) then return end
    if self.session.phaseFeedback or self.session.phaseTransition then return end
    if HuntView.busy(self.session) then return end
    if FateInspection.mousepressed(self, x, y, button) then return end
    if not self:inputReady() then return end
    if not self.battlefieldInspectionCell and Inspection.mousepressed(self, x, y, button) then return end
    if BattlefieldInspection.mousepressed(self, x, y, button) then return end
    if button == 2 then
        self.selectedId, self.pending, self.session.agentView.selected = nil, nil, nil
        self.portraitAge = nil
    elseif button == 1 then
        if self.nextPhase:contains(x, y) then
            self.pending = nil
            if Status.allExhausted(self.session.agentStatus) then self.pending = { kind = "phase" } end
            return
        end
        if self.selectedId and self.panel:contains(x, y) then
            self.pending = { kind = "act", id = self.selectedId }
            return
        end
        local hit = self.session.agentView:hover(x, y)
        self.pending = hit and { id = hit.id, x = x, y = y } or nil
    end
end

function Action:mousereleased(x, y, button)
    if RoutingUI.releasePointer(self, x, y, button) then return end
    if self.session.phaseFeedback or self.session.phaseTransition then return end
    if HuntView.busy(self.session) then return end
    if FateInspection.mousereleased(self, x, y, button) or Inspection.mousereleased(self, x, y, button)
        or BattlefieldInspection.mousereleased(self, button)
        or button ~= 1 or not self:inputReady() then return end
    if self.pending and self.pending.kind == "phase" then
        self.pending = nil
        if self.nextPhase:contains(x, y) then self:nextPhaseRefresh() end
        return
    end
    if self.pending and self.pending.kind == "act" then
        local id = self.pending.id
        self.pending = nil
        if self.selectedId == id and self.panel:contains(x, y) then self:beginAgentAction() end
        return
    end
    self:pointermoved(x, y)
    local hit = self.session.agentView:hover(x, y)
    if self.pending and hit and hit.id == self.pending.id then
        if self.selectedId ~= hit.id then self.portraitAge = 0 end
        if self.selectedId ~= hit.id and self.session.audio then
            self.session.audio:playOverlapping("selection")
        end
        self.selectedId = hit.id
        self.session.agentView.selected = hit.id
    end
    self.pending = nil
end

function Action:beginAgentAction()
    if self.agentInspectionPanel then return false end
    if not self:inputReady() or not self.selectedId or Status.isExhausted(self.session.agentStatus, self.selectedId) then return false end
    local ok, prepared = pcall(AgentAction.prepare, self)
    if not ok then
        self.agentActionError = tostring(prepared)
        print("[Agent Action] " .. self.agentActionError)
        return false
    end
    prepared.session, self.session = self.session, nil
    prepared.portrait, self.portrait = self.portrait, nil
    self.stateMachine:change("agent_action", prepared)
    return true
end

function Action:nextPhaseRefresh()
    if self.agentInspectionPanel then return false end
    if not self:inputReady() then return false end
    local ok, refreshed = pcall(require("src.sys.mission_phase").begin, self.session)
    if not ok then self.refreshError = tostring(refreshed); return false end
    if not refreshed then return false end
    if self.session.audio then self.session.audio:playOverlapping("endPhase") end
    self.refreshError = nil
    self.selectedId, self.pending, self.portraitAge = nil, nil, nil
    self.session.agentView.selected = nil
    self.session.agentView:clearHover()
    self.nextPhase.hovered = false
    return true
end

function Action:focus(focused)
    if not focused then self.session.missionFooter:clearHover(); self.session.missionFooter.routing:cancel() end
    FateInspection.focus(self, focused)
    Inspection.focus(self, focused)
    if not focused then
        self.pending = nil
        self.session.agentView:clearHover()
    end
end

function Action:inputReady()
    return self.elapsed >= self.settings.transition.duration and not HuntView.busy(self.session)
end

function Action:wheelmoved(x, y)
    if self.session.missionFooter.routing.receipt or self.session.missionFooter.routing.drag.pending then return end
    if self.session.phaseFeedback or self.session.phaseTransition then return end
    if self.session.missionFooter:wheel(y) then return end
    if HuntView.busy(self.session) then return end
    if not FateInspection.wheel(self, y) and not BattlefieldInspection.wheel(self, y) then Inspection.wheel(self, y) end
end
function Action:keypressed(key, _, isrepeat)
    if RoutingUI.key(self, key) then return end
    if self.session.phaseFeedback or self.session.phaseTransition then return end
    if HuntView.keypressed(self, key) then return end
    if not FateInspection.keypressed(self, key, isrepeat) then Inspection.keypressed(self, key) end
end

function Action:draw()
    local s, timing = self.session, self.settings.transition
    local outgoing = 1 - Animation.progress(self.elapsed, 0, timing.outgoingDuration)
    local incoming = Animation.progress(self.elapsed, timing.incomingDelay, timing.incomingDuration)
    local brighten = Animation.progress(self.elapsed, 0, timing.duration)
    local brightness = {}
    for id, level in pairs(self.startBrightness) do
        brightness[id] = Status.isExhausted(s.agentStatus, id) and TurnView.exhaustedBrightness or Animation.lerp(level, 1, brighten)
    end
    Backdrop.draw(s.scene)
    s.grid:draw(s.art, nil, s.agentDeployment.placements)
    if s.armyView then s.armyView:draw() end
    HuntView.outlines(s)
    require("src.ui.silencer_activity").markers(s)
    love.graphics.push("all")
    if self.elapsed < timing.duration and not self.oldReady then
        -- The roster appears with the returning selection UI.
        for id, level in pairs(brightness) do brightness[id] = level * incoming end
    end
    s.roster:draw(brightness)
    love.graphics.pop()
    s.agentView:draw(nil, { deploymentIndicators = outgoing > 0, indicatorAlpha = outgoing,
        selectionColor = self.settings.selectionColor })
    if self.oldPrompt and outgoing > 0 then
        local g, p = love.graphics, self.oldPrompt
        g.push("all")
        g.setFont(p.font)
        g.setColor(DeploymentPrompt.color[1], DeploymentPrompt.color[2], DeploymentPrompt.color[3], outgoing)
        g.printf(DeploymentPrompt.text, p.x, p.y, p.width, "left")
        self.oldReady:draw(p, true, 0, 0, outgoing)
        g.pop()
    end
    self.panel:draw(self.selectedId, incoming, Status.allDefeated(s.agentStatus) and TurnView.allDefeatedPrompt or (Status.allExhausted(s.agentStatus) and TurnView.allExhaustedPrompt or nil))
    self.nextPhase.hovered = Status.allExhausted(s.agentStatus)
    self.nextPhase:draw(incoming)
    self.portrait:draw(self.selectedId, self.panel.font, s.scene.accents.small, self.portraitAge)
    require("src.ui.doom_clock").draw(s)
    HuntView.markers(s, s.scene.accents.small)
    s.missionFooter:draw(s)
    BattlefieldInspection.draw(self)
    Inspection.draw(self)
    FateInspection.draw(self)
    HuntView.draw(s, self.width, self.height, s.scene.accents.small, s.scene.accents.heading)
    s.missionFooter:drawPreview(s)
    require("src.ui.transport_hover").drawFor(self)
    s.missionFooter.routing:draw(s)
    if s.scene.phaseFeedbackView then s.scene.phaseFeedbackView:draw(self.width, self.height, s.scene.accents.small) end
    require("src.ui.doom_clock").drawWarning(s, self.width, self.height)
end

function Action:exit()
    FateInspection.release(self)
    BattlefieldInspection.release(self)
    Inspection.release(self)
    if self.nextPhase then self.nextPhase:release(); self.nextPhase = nil end
    if self.oldReady then self.oldReady:release() end
    if self.portrait then self.portrait:release() end
    self.oldReady, self.oldPrompt, self.portrait, self.startBrightness = nil, nil, nil, nil
    if self.panel then self.panel:release() end
    if self.session then Session.release(self.session) end
    self.panel, self.session, self.settings, self.selectedId, self.pending = nil, nil, nil, nil, nil
end

return Action
