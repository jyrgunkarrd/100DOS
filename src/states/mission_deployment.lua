local BattlefieldInspection = require("src.ui.battlefield_inspection")
local FateInspection = require("src.ui.fate_pool_inspection")
local Comparison = require("src.ui.battlefield_comparison")
local Inspection = require("src.ui.agent_inspection")
local MissionAction = require("src.states.mission_action")
local Session = require("src.sys.mission_session")
local Transition = require("src.ui.deployment_transition")
local ReadyButton = require("src.ui.deployment_ready")
local AgentDeployment = require("src.sys.agent_deployment")
local AgentDrag = require("src.ui.agent_drag")
local LocationAgents = require("src.ui.location_agents")
local AgentSettings = require("data.agent_deployment_defaults")
local Animation = require("src.ui.animation")
local Prompt = require("data.deployment_prompt")
local LocationIndex = require("data.locations.index")
local MissionLocations = require("src.sys.mission_locations")
local LocationArt = require("src.ui.location_art")
local DeploymentRoster = require("src.ui.deployment_roster")
local Grid = require("src.ui.hex_grid")
local Backdrop = require("src.ui.mission_backdrop")
local Deployment = {}
Deployment.__index = Deployment

function Deployment.new(stateMachine, width, height)
    return setmetatable({ stateMachine = stateMachine, width = width, height = height }, Deployment)
end

-- Complete all fallible board construction before releasing preparation.
function Deployment.prepare(package, width, height, biome, source)
    local loadFateSettings, fateError = love.filesystem.load("data/fate_pool_defaults.lua")
    assert(loadFateSettings, fateError)
    local fatePool = require("src.sys.fate_pool").build(package, source,
        require("data.fate_tiles.index").refresh(), loadFateSettings())
    local chunk, message = love.filesystem.load("data/deployment_board.lua")
    assert(chunk, message)
    local settings = chunk()
    if biome.loc_col ~= nil then
        local hex = type(biome.loc_col) == "string" and biome.loc_col:gsub("^#", "")
        if hex and #hex == 6 and hex:match("^%x+$") then
            settings.frameColor = {
                tonumber(hex:sub(1, 2), 16) / 255,
                tonumber(hex:sub(3, 4), 16) / 255,
                tonumber(hex:sub(5, 6), 16) / 255, 1,
            }
        else
            print("[Deployment] Invalid loc_col for biome " .. tostring(biome.id)
                .. "; using the default frame color")
        end
    end
    local grid = Grid.new(settings, width, height / 2)
    local loadLocationRules, rulesError = love.filesystem.load("data/jacl_location_rules.lua")
    assert(loadLocationRules, rulesError)
    local locationRules = loadLocationRules()
    local assignments, locations = MissionLocations.build(package, source, biome,
        LocationIndex.refresh(), grid.cells, locationRules)
    local armies = require("src.sys.mission_armies").build(assignments, locationRules.cellId,
        biome, assert(source.captains.byId[package.captainId]), require("data.forces.index").refresh(),
        require("data.army_lists.index").refresh(), require("data.army_deployment_rules"))
    require("src.sys.battlefield_state").initialize(armies, assignments, locationRules.cellId)
    for _, locationId in pairs(assignments) do require("src.sys.battlefield_tests").resolve(locations.byId[locationId]) end
    local locationCardPool = require("src.sys.location_card_pool").build(
        assignments, locations, require("data.loc_cards.index").refresh())
    local locationDecks = require("src.sys.location_decks").new(assignments, locations, locationCardPool)
    local selection = { biomeId = package.biomeId, jaclId = package.jaclId,
        captainId = package.captainId, agentIds = {} }
    for i, id in ipairs(package.agentIds) do selection.agentIds[i] = id end
    local art = LocationArt.new(assignments, grid.cells, settings.artwork)
    local ok, roster = pcall(DeploymentRoster.new, selection.agentIds, grid.bounds, width, height / 2)
    if not ok then art:release(); error(roster, 0) end
    local transitionOk, transition = pcall(function()
        local loadTransition, loadError = love.filesystem.load("data/deployment_transition.lua")
        assert(loadTransition, loadError)
        return Transition.new(source, roster, grid, loadTransition())
    end)
    if not transitionOk then roster:release(); art:release(); error(transition, 0) end
    local readyOk, ready = pcall(ReadyButton.new)
    if not readyOk then roster:release(); art:release(); error(ready, 0) end
    local armyViewOk, armyView = pcall(require("src.ui.location_armies").new, armies, grid,
        require("data.army_deployment_view"))
    if not armyViewOk then
        ready:release(); transition:release(); roster:release(); art:release(); error(armyView, 0)
    end
    for _, diagnostic in ipairs(art.diagnostics) do print("[Location art] " .. diagnostic) end
    for _, diagnostic in ipairs(roster.diagnostics) do print("[Deployment roster] " .. diagnostic) end
    for _, diagnostic in ipairs(ready.diagnostics) do print("[Ready button] " .. diagnostic) end
    return { grid = grid, package = selection, assignments = assignments, art = art,
        roster = roster, transition = transition, ready = ready, fatePool = fatePool,
        locationCardPool = locationCardPool, locationDecks = locationDecks, armies = armies, armyView = armyView, locations = locations,
        comparisonAgents = source.agents }
end

function Deployment:enter(previousName, prepared)
    self.armies, self.armyView = prepared.armies, prepared.armyView
    self.locations = prepared.locations
    self.comparison = Comparison.new(prepared.comparisonAgents or require("data.agents.index").refresh())
    self.fatePool = prepared.fatePool
    self.grid, self.package, self.scene = prepared.grid, prepared.package, prepared.scene
    self.assignments, self.art = prepared.assignments, prepared.art
    self.locationCardPool, self.locationDecks = prepared.locationCardPool, prepared.locationDecks
    self.roster = prepared.roster
    self.readyButton = prepared.ready
    self.readyPressed, self.actionError = false, nil
    self.agentDeployment = AgentDeployment.new(self.package.agentIds, self.assignments)
    self.agentView = LocationAgents.new(self.agentDeployment, self.grid, self.roster)
    self.agentView:refresh()
    self.drag = AgentDrag.new(AgentSettings.dragThreshold)
    self.transition = prepared.transition
    self.elapsed = 0
    self.promptStart = self.transition.duration
    self.audio = prepared.audio
    self.landedCells = {}
    if self.audio then
        self.audio:play("deploy")
        self.audio:playOverlapping("agentDeploy")
    end
end

function Deployment:update(dt)
    BattlefieldInspection.update(self)
    Inspection.update(self, dt)
    self.elapsed = self.elapsed + math.max(0, dt)
    self.agentView:update(dt, self.drag)
    Backdrop.update(self.scene, dt)
    if self.audio then self.audio:update() end
    if self.transition then
        self.transition:update(dt)
        for _, cell in ipairs(self.transition.order) do
            local landingTime = self.transition.drops[cell.id].start + self.transition.config.dropDuration
            if self.transition.time >= landingTime and not self.landedCells[cell.id] then
                self.landedCells[cell.id] = true
                if self.audio then self.audio:playOverlapping("hexDeploy") end
            end
        end
        if self.transition.time >= self.transition.duration then
            self.transition:release()
            self.transition = nil
        end
    end
end

function Deployment:promptAlpha()
    return Animation.progress(self.elapsed, self.promptStart, Prompt.fadeDuration)
end

function Deployment:inputReady()
    return self.transition == nil and self:promptAlpha() >= 1
end

function Deployment:pointermoved(x, y)
    if FateInspection.pointermoved(self, x, y) then return end
    if self.battlefieldInspectionCell or Inspection.panelPointer(self, x, y) then return end
    if not self:inputReady() then return end
    if x == nil or y == nil then self.readyPressed = false end
    self.drag:move(x, y)
    if self.drag.active then Inspection.clear(self); return end
    if not self.drag.active then self.agentView:hover(x, y) end
    Inspection.pointer(self, x, y)
end

function Deployment:mousepressed(x, y, button)
    if FateInspection.mousepressed(self, x, y, button) then return end
    if not self:inputReady() then return end
    if not self.battlefieldInspectionCell and Inspection.mousepressed(self, x, y, button) then return end
    if BattlefieldInspection.mousepressed(self, x, y, button) then return end
    Inspection.clear(self)
    if button ~= 1 then return end
    if self:canReady() and self.readyButton:contains(self:promptLayout(), x, y) then
        self.readyPressed = true
        return
    end
    local hit = self.agentView:hover(x, y)
    self.drag:press(hit, x, y)
end

function Deployment:mousereleased(x, y, button)
    if FateInspection.mousereleased(self, x, y, button) or Inspection.mousereleased(self, x, y, button)
        or BattlefieldInspection.mousereleased(self, button)
        or button ~= 1 or not self:inputReady() then return end
    if self.readyPressed then
        self.readyPressed = false
        if self:canReady() and self.readyButton:contains(self:promptLayout(), x, y) then self:beginAction() end
        return
    end
    local id = self.drag:release(x, y)
    if id then
        if self.roster:contains(x, y) then
            self.agentDeployment:assign(id, nil)
        else
            local cell = self.grid:hit(x, y)
            if cell then
                local previous = self.agentDeployment.placements[id]
                if self.agentDeployment:assign(id, cell.id) and previous ~= cell.id and self.audio then
                    self.audio:playOverlapping("agentMove")
                end
            end
        end
        self.agentView:refresh()
    end
    self.agentView:hover(x, y)
end

function Deployment:focus(focused)
    FateInspection.focus(self, focused)
    Inspection.focus(self, focused)
    if not focused then
        self.readyPressed = false
        self.drag:cancel()
        self.agentView:clearHover()
    end
end

function Deployment:keypressed(key, _, isrepeat)
    if FateInspection.keypressed(self, key, isrepeat) or Inspection.keypressed(self, key) then return end
    if key == "escape" then Inspection.clear(self) end
    if key == "escape" then
        self.readyPressed = false
        self.drag:cancel()
        self.agentView:clearHover()
    end
end

function Deployment:canReady()
    return self:inputReady() and not self.drag.pending and self.agentDeployment:allAssigned()
        and self.readyButton:alpha(self.elapsed, self.promptStart + Prompt.fadeDuration) >= 1
end

function Deployment:beginAction()
    if not self:canReady() then return false end
    local ok, prepared = pcall(MissionAction.prepare, self)
    if not ok then
        self.actionError = tostring(prepared)
        print("[Mission action] " .. self.actionError)
        return false
    end
    prepared.ready, self.readyButton = self.readyButton, nil
    prepared.session = Session.take(self)
    self.stateMachine:change("mission_action", prepared)
    return true
end

function Deployment:promptLayout()
    local bounds = self.grid.bounds
    local x = math.ceil(bounds.x + bounds.width + Prompt.boardGap)
    local width = math.min(Prompt.width, self.width - Prompt.rightMargin - x)
    if width <= 0 then return nil end
    local font = self.scene.accents.heading or love.graphics.getFont()
    local textWidth, lines = font:getWrap(Prompt.text, width)
    local textHeight = font:getHeight() * (1 + (#lines - 1) * font:getLineHeight())
    local y = math.floor(bounds.y + (bounds.height - textHeight) / 2 + 0.5)
    return { x = x, y = y, width = width, textWidth = textWidth, height = textHeight, font = font }
end

function Deployment:drawPrompt()
    local alpha = self:promptAlpha()
    if alpha <= 0 then return end
    local layout = self:promptLayout()
    if not layout then return end
    local g = love.graphics
    g.push("all")
    g.intersectScissor(0, 0, self.width, self.height / 2)
    g.setFont(layout.font)
    g.setColor(Prompt.color[1], Prompt.color[2], Prompt.color[3], alpha)
    g.printf(Prompt.text, layout.x, layout.y, layout.width, "left")
    self.readyButton:draw(layout, self.agentDeployment:allAssigned(), self.elapsed,
        self.promptStart + Prompt.fadeDuration)
    g.pop()
end

function Deployment:wheelmoved(x, y)
    if FateInspection.wheel(self, y) then return end
    if self.drag.active then return end
    if not BattlefieldInspection.wheel(self, y) then Inspection.wheel(self, y) end
end

function Deployment:comparisonModel()
    if not self:inputReady() or not self.drag.active or not self.drag.pending then return nil end
    return self.comparison:build(self, self.drag.pending.id, self.agentDeployment.eligible, self.drag.x, self.drag.y)
end

function Deployment:draw()
    local comparison = self:comparisonModel()
    local positions = comparison and Comparison.positionsHeld()
    local comparing = comparison and not positions
    Backdrop.draw(self.scene)
    self.grid:draw(self.art, self.transition, comparison and {} or self.agentDeployment.placements)
    if comparing then self.comparison:draw(self.grid, comparison, self.scene.accents.small) end
    if not self.transition and self.armyView then self.armyView:draw() end
    if self.transition then self.transition:drawAgents()
    else self.roster:draw(self.agentView.rosterBrightness) end
    self:drawPrompt()
    self.scene.accents:draw(self.scene.biome)
    if self:inputReady() then
        self.agentView:draw(self.drag, { hideMapPortraits = comparing == true })
        local ghost = self.drag:pose()
        if ghost then
            love.graphics.push("all")
            self.roster:drawPortrait(ghost.id, ghost.x, ghost.y)
            love.graphics.pop()
        end
    end
    if not comparison then BattlefieldInspection.draw(self); Inspection.draw(self) end
    FateInspection.draw(self)
end

function Deployment:exit()
    FateInspection.release(self)
    if self.comparison then self.comparison:release(); self.comparison = nil end
    BattlefieldInspection.release(self)
    if self.armyView then self.armyView:release() end
    self.armyView, self.armies = nil, nil
    self.locations = nil
    Inspection.release(self)
    if self.readyButton then self.readyButton:release() end
    self.readyButton = nil
    if self.drag then self.drag:cancel() end
    self.drag, self.agentView, self.agentDeployment = nil, nil, nil
    if self.transition then self.transition:release() end
    self.transition = nil
    if self.audio then self.audio:release() end
    self.audio = nil
    self.landedCells = nil
    if self.scene then Backdrop.release(self.scene) end
    if self.art then self.art:release() end
    if self.roster then self.roster:release() end
    self.roster = nil
    self.art, self.assignments = nil, nil
    self.locationCardPool, self.locationDecks, self.fatePool = nil, nil, nil
    self.scene, self.grid, self.package = nil, nil, nil
end

return Deployment

