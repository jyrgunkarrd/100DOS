local Preview = require("src.ui.card_preview")
local Controller = require("src.ui.card_preview_controller")
local Display = require("src.sys.agent_display")
local Placement = require("src.ui.preview_placement")
local Panel = require("src.ui.agent_inspection_panel")
local Data = require("src.sys.agent_inspection_data")
local PanelView = require("data.agent_inspection_view")
local PortraitSize = require("data.agent_deployment_defaults").portraitSize
local Inspection = {}
local function inside(x, y, r)
    return x and y and x >= r.x and x < r.x + r.width and y >= r.y and y < r.y + r.height
end
function Inspection.clear(state)
    local i = state.inspection
    if i and i.controller.source == "character" then i.controller:clear() end
    if i then i.target = nil end
end
function Inspection.update(state, dt)
    local i = state.inspection
    if not i then return end
    if i.target then i.awayTime = 0; return end
    i.awayTime = (i.awayTime or 0) + math.max(0, dt)
    if i.awayTime >= i.view.settings.inspectionSoundResetDelay then i.soundPlayed = false end
end
local function closePanel(state)
    if not state.agentInspectionPanel then return end
    state.agentInspectionPanel:release()
    state.agentInspectionPanel = nil
end
function Inspection.release(state)
    closePanel(state)
    local i = state.inspection
    if not i then return end
    if i.shared then i.controller.views.character = nil; i.view:release()
    else i.controller:release() end
    state.inspection = nil
end
function Inspection.focus(state, focused)
    if focused then return end
    Inspection.clear(state)
    local panel = state.agentInspectionPanel
    if panel then
        if panel.focus then panel:focus()
        else panel.pressed = nil; panel:pointer(nil, nil) end
    end
end

local function agentDefinitions(state, session)
    return (session.agentCards and session.agentCards.agents) or state.agents
        or (state.comparison and state.comparison.agents) or require("data.agents.index").refresh()
end

local function hoverDisplay(definition, settings, session, id)
    local display = Display.normalize(definition, settings, session, id)
    display.hint = session and session.agentCards and PanelView.liveHint or PanelView.hint
    return display
end

local function ensure(state)
    if state.inspection then return state.inspection end
    local session = state.session or state
    local scene = session.scene or state
    local settings = require("data.agent_preview_view")
    assert(type(settings.inspectionSoundResetDelay) == "number" and settings.inspectionSoundResetDelay >= 0
        and settings.inspectionSoundResetDelay < math.huge, "Invalid inspection sound reset delay")
    local definitions = agentDefinitions(state, session)
    local cards = {}
    for _, id in ipairs(session.package.agentIds) do cards[#cards + 1] = { cardId = id } end
    local view = Preview.new(definitions, cards, settings, scene.accents,
        session.grid or { bounds = { x = 0, width = state.width } }, state.height,
        function(d) return hoverDisplay(d, settings) end, session.package.biomeId)
    local controller = state.previews or Controller.new(nil, nil, session.audio)
    controller.views.character = view
    local i = { view = view, controller = controller, definitions = definitions, shared = state.previews ~= nil }
    state.inspection = i
    local draw = view.draw
    function view:draw()
        if self.cardId then
            local current = state.session or state
            local d = hoverDisplay(definitions.byId[self.cardId], settings, current, self.cardId)
            for _, slot in ipairs(d.assetSlots) do
                if slot.cardId and not slot.continuation then
                    self:load(require("src.ui.preview_asset_slots").path(settings.assetSlots, slot.cardId))
                end
            end
            self.instanceDisplay, self.instanceLayout = d, self:layout(d)
            self.scroll = math.min(self.scroll, self.instanceLayout.overflow or 0)
        end
        draw(self)
    end
    return i
end
local function targetAt(state, x, y)
    local session = state.session or state
    if not x or not y or x < 0 or y < 0 or x >= state.width or y >= state.height then return end
    local target
    local function rect(entry, size, ry)
        return { id = entry.id, x = entry.x, y = entry.y or ry, width = size, height = size }
    end
    if state.agentRoster then
        local roster = state.agentRoster
        for index, entry in ipairs(roster.entries) do
            local pose = roster:entrancePose(index, state.entranceTime)
            if not pose.landed then return end
            local r = rect(entry, roster.config.portraitSize, roster.y)
            -- Split only the small gaps between adjacent portraits, retaining their real bounds for placement.
            local hit = { x = r.x - (index > 1 and roster.config.gap / 2 or 0), y = r.y,
                width = r.width + (index > 1 and roster.config.gap / 2 or 0) + (index < #roster.entries and roster.config.gap / 2 or 0), height = r.height }
            if inside(x, y, hit) then target = r end
        end
    else
        local portrait = state.portrait
        local id = state.activeAgentId or state.selectedId
        if portrait and id then
            local r = { id = id, x = portrait.x, y = portrait.y, width = portrait.size, height = portrait.size }
            if inside(x, y, r) then target = r end
        end
        local view = session.agentView
        if not target and view then
            if x < session.grid.width and y < session.grid.height then
                for _, entry in ipairs(view:drawOrder()) do
                    entry = view:movementPose(entry)
                    local r = rect(entry, PortraitSize)
                    if inside(x, y, r) then target = r end
                end
            end
            -- Roster is not drawn during Agent Action.
            if not state.activeAgentId then
                for _, entry in ipairs(session.roster.entries) do
                    local r = rect(entry, session.roster.size)
                    local gap = session.roster.gap or 0
                    local hit = { x = r.x - gap / 2, y = r.y - gap / 2, width = r.width + gap, height = r.height + gap }
                    if session.roster:contains(x, y) and inside(x, y, hit) then target = r end
                end
            end
        end
    end
    return target
end

function Inspection.pointer(state, x, y)
    local session = state.session or state
    local target = not session.attackFeedback and not (state.drag and state.drag.active) and targetAt(state, x, y)
    if not target then Inspection.clear(state); return false end
    local ok, i = pcall(ensure, state)
    if not ok then state.inspectionError = tostring(i); return false end
    local v, c = i.view, i.view.settings
    local d = hoverDisplay(i.definitions.byId[target.id], c, session, target.id)
    local layout = v:layout(d)
    local reserved = {}
    local preparation = state.agentRoster ~= nil
    if preparation then
        for _, button in ipairs(state.buttons or {}) do reserved[#reserved + 1] = { x = button.x, y = button.y, width = button.width, height = button.height } end
    end
    local placement = Placement.choose(state.width, state.height, { width = c.width, height = layout.height, y = c.top },
        target, not preparation and session.grid.bounds.x + session.grid.bounds.width / 2 or nil, reserved, c.edgeMargin, c.portraitGap)
    if not placement then Inspection.clear(state); return false end
    v.x, v.y = placement.x, placement.y
    i.controller:show("character", { cardId = target.id, instanceId = target.id }, i.soundPlayed)
    i.soundPlayed, i.awayTime = true, 0
    i.target = target
    return true
end
local function openDetails(state, id)
    local session = state.session or state
    local scene = session.scene or state
    local agent = assert(agentDefinitions(state, session).byId[id], "Unknown inspected Agent")
    local cards = session.agentCards
    local definitions = cards and cards.definitions or require("data.cards.index").refresh()
    local planned = not session.fatePool and require("data.fate_tiles.index").refresh().byId
    local model = Data.build(id, agent, definitions.byId, cards and cards.byAgent[id], session.fatePool, planned)
    return Panel.new(model, definitions, scene.accents, state.width, state.height, session.package.biomeId)
end

local function openPanel(state, id)
    local session = state.session or state
    if session.agentCards then
        return require("src.ui.agent_observation").new(session, id, state.width, state.height,
            function() return openDetails(state, id) end)
    end
    return openDetails(state, id)
end

function Inspection.mousepressed(state, x, y, button)
    local panel = state.agentInspectionPanel
    if panel then
        if button == 2 then closePanel(state)
        elseif button == 1 then panel:press(x, y) end
        return true
    end
    local session = state.session or state
    local drag = state.drag
    if button ~= 2 or session.pendingEndTurn or (drag and (drag.pending or drag.card or drag.active))
        or (state.actions and state.actions.open) or (state.testPanel and state.testPanel.card)
        or (state.maneuver and state.maneuver.open) or (state.resolving and state:resolving()) then return false end
    local target = targetAt(state, x, y)
    if not target then return false end
    local ok, result = pcall(openPanel, state, target.id)
    if not ok then
        state.inspectionError = tostring(result)
        print("[Agent inspection] " .. state.inspectionError)
        return true
    end
    state:focus(false)
    state.agentInspectionPanel, state.inspectionError = result, nil
    return true
end

function Inspection.mousereleased(state, x, y, button)
    local panel = state.agentInspectionPanel
    if not panel then return false end
    if button == 1 and panel:releasePointer(x, y) then closePanel(state) end
    return true
end

function Inspection.panelPointer(state, x, y)
    local panel = state.agentInspectionPanel
    if not panel then return false end
    panel:pointer(x, y)
    return true
end

function Inspection.keypressed(state, key)
    if not state.agentInspectionPanel then return false end
    if key == "escape" then closePanel(state) end
    return true
end

function Inspection.draw(state)
    local i = state.inspection
    if state.agentInspectionPanel then state.agentInspectionPanel:draw()
    elseif i and not i.shared then i.controller:draw() end
end
function Inspection.wheel(state, y)
    if state.agentInspectionPanel then state.agentInspectionPanel:wheel(y); return true end
    local i = state.inspection
    if i and i.controller.source == "character" and love.keyboard.isDown("lshift", "rshift") then return i.controller:wheelmoved(y) end
    return false
end
return Inspection
