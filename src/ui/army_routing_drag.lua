local Routing = require("src.sys.army_routing")
local Drag = require("src.ui.agent_drag")
local Milling = require("src.ui.location_milling_feedback")
local UI = {}
UI.__index = UI

function UI.new()
    return setmetatable({ drag = Drag.new(require("data.target_track_view").routingDragThreshold) }, UI)
end
local function controller(host) return host.session.missionFooter.routing end
function UI.allowed(host)
    local s = host.session
    if s.missionOutcome or s.phaseTransition or s.phaseFeedback or s.pendingEndTurn or s.pendingManeuver
        or s.attackFeedback or s.talentFeedback or s.reinforcementFeedback or s.pendingHuntEscape
        or require("src.ui.hunt_distribution").busy(s) then return false end
    if host.fatePoolInspection or host.agentInspectionPanel or host.battlefieldInspectionCell then return false end
    if host.inputReady and not host:inputReady() then return false end
    if host.resolving and host:resolving() then return false end
    if host.handReadyAt and host.elapsed < host.handReadyAt then return false end
    if (host.actions and host.actions.open) or (host.maneuver and host.maneuver.open)
        or (host.testPanel and host.testPanel.card) or (host.drag and host.drag.card)
        or (host.exploration and host.exploration:busy()) then return false end
    return true
end
function UI.press(host, x, y, button)
    local self = controller(host)
    if self.receipt then return true end
    if self.drag.pending then
        if button == 2 then self:cancel() end
        return true
    end
    if button ~= 1 or not x or not y or not UI.allowed(host) then return false end
    local entries, layout = host.session.missionFooter:prepare(host.session)
    for i, panel in ipairs(layout and layout.panels or {}) do
        local entry = entries[i]
        if x >= panel.x and x < panel.x + panel.width and y >= panel.y and y < panel.y + panel.height
            and Routing.available(host.session, entry.instanceId) then
            host:focus(false)
            self.entry, self.panel = entry, panel
            self.drag:press({ id = entry.instanceId, x = panel.x, y = panel.y }, x, y)
            return true
        end
    end
    return false
end
function UI.pointer(host, x, y)
    local self = controller(host)
    if self.receipt then return true end
    if not self.drag.pending then return false end
    if not UI.allowed(host) then self:cancel(); return true end
    self.drag:move(x, y)
    if self.drag.active then host.session.missionFooter:clearHover() end
    return true
end
function UI.releasePointer(host, x, y, button)
    local self = controller(host)
    if self.receipt then return true end
    if not self.drag.pending then return false end
    if button ~= 1 then return true end
    local id = self.drag:release(x, y)
    self.entry, self.panel = nil, nil
    if not id or not UI.allowed(host) then return true end
    local s = host.session
    local cell = s.grid:hit(x, y)
    local plan = cell and Routing.prepare(s, id, cell.id)
    if not plan then return true end
    -- Load feedback before committing gameplay so missing art cannot leave a half-finished drop.
    self.milling = self.milling or Milling.new(s)
    local duration = self.milling:bind(plan.receipt)
    if not plan:commit() then self.milling:clear(); return true end
    s.missionFooter:clearHover()
    if duration > 0 then
        self.receipt, self.elapsed, self.duration = plan.receipt, 0, duration
        self.audio = self.audio or require("src.sys.audio_controller").new({ mill = require("data.location_milling_view").sound })
        self.audio:playOverlapping("mill")
    end
    return true
end
function UI.key(host, key)
    local self = controller(host)
    if self.receipt then return true end
    if not self.drag.pending then return false end
    if key == "escape" then self:cancel() end
    return true
end
function UI:cancel() self.drag:cancel(); self.entry, self.panel = nil, nil end
function UI:update(dt)
    if self.audio then self.audio:update() end
    if not self.receipt then return end
    self.elapsed = self.elapsed + math.max(0, dt)
    if self.elapsed >= self.duration then self.receipt = nil; self.milling:clear() end
end
function UI:draw(s)
    local g, footer = love.graphics, s.missionFooter
    if self.receipt then
        self.milling:draw(self.elapsed, s.scene.accents.width, s.scene.accents.height, s.scene.accents.small,
            require("src.ui.phase_end_feedback").reducedMotion(), 1)
        return
    end
    local pose = self.drag:pose()
    if not pose then return end
    local c = footer.track.settings
    local hovered = s.grid:hit(self.drag.x, self.drag.y)
    g.push("all"); g.setLineWidth(2)
    for _, cell in ipairs(s.grid.cells) do
        if Routing.available(s, pose.id, cell.id) then
            g.setColor(hovered == cell and c.routingHoverColor or c.routingColor)
            g.polygon("line", cell.vertices)
        end
    end
    g.translate(pose.x - self.panel.x, pose.y - self.panel.y)
    footer.track:draw({ self.entry }, { panels = { self.panel } })
    g.pop()
end
function UI:release()
    self:cancel()
    if self.milling then self.milling:release() end
    if self.audio then self.audio:release() end
end
return UI
