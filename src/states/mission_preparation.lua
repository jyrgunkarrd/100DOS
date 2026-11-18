local Inspection = require("src.ui.agent_inspection")
local Deployment = require("src.states.mission_deployment")
local Backdrop = require("src.ui.mission_backdrop")
local BiomeIndex = require("data.biomes.index")
local PreparationAccents = require("src.ui.preparation_accents")
local ImageButton = require("src.ui.image_button")
local AudioController = require("src.sys.audio_controller")
local ButtonSettings = require("data.preparation_buttons")
local AgentIndex = require("data.agents.index")
local AgentRoster = require("src.ui.agent_roster")
local CaptainIndex = require("data.captains.index")
local CaptainPanel = require("src.ui.captain_panel")
local JaclIndex = require("data.jacls.index")
local JaclPreview = require("src.ui.jacl_preview")
local Generator = require("src.sys.preparation_generator")
local VisualCatalogue = require("src.sys.biome_visual_catalogue")
local ParallaxView = require("src.ui.parallax_view")
local MissionPreparation = {}
MissionPreparation.__index = MissionPreparation

function MissionPreparation.new(stateMachine, width, height)
    return setmetatable({
        stateMachine = stateMachine,
        width = width,
        height = height,
    }, MissionPreparation)
end

function MissionPreparation:enter(previousName)
    if self.accents then self.accents:release() end
    self.accents = PreparationAccents.new(self.width, self.height)
    self.entranceTime = 0
    self.deployError = nil
    if self.audio then self.audio:release() end
    self.audio = AudioController.new({ hover = ButtonSettings.hoverSound,
        roll = ButtonSettings.rollSound, deploy = ButtonSettings.deploySound,
        agentDeploy = ButtonSettings.agentDeploySound, hexDeploy = ButtonSettings.hexDeploySound,
        agentMove = ButtonSettings.agentMoveSound, ready = ButtonSettings.readySound,
        selection = ButtonSettings.selectionSound, agentAct = ButtonSettings.agentActSound,
        cardView = ButtonSettings.cardViewSound, endPhase = ButtonSettings.endPhaseSound })
    for _, button in ipairs(self.buttons or {}) do button:release() end
    local ready, message = self:rebuildPackage()
    assert(ready, message)
    self.buttons, self.buttonDiagnostics = {}, {}
    local rowWidth = math.max(0, #ButtonSettings.buttons - 1) * ButtonSettings.gap
    local rowHeight = 0
    for _, definition in ipairs(ButtonSettings.buttons) do
        local button = ImageButton.new(definition)
        self.buttons[#self.buttons + 1] = button
        rowWidth = rowWidth + button.width
        rowHeight = math.max(rowHeight, button.height)
        for _, message in ipairs(button.diagnostics) do
            self.buttonDiagnostics[#self.buttonDiagnostics + 1] = message
            print("[Preparation buttons] " .. message)
        end
    end
    -- Snap horizontal placement to canvas pixels so thin sprite edges survive
    -- nearest-neighbor sampling when the total row width is odd.
    local x = math.floor((self.width - rowWidth) / 2)
    local centerY = self.agentRoster.y + self.agentRoster.height + ButtonSettings.rosterGap + rowHeight / 2
    for _, button in ipairs(self.buttons) do
        button.x = x
        -- Odd/even sprite heights cannot share an exact center on integer pixels.
        -- Snap to the nearest pixel, preserving borders within a half-pixel of center.
        button.y = math.floor(centerY - button.height / 2 + 0.5)
        x = x + button.width + ButtonSettings.gap
    end
end

function MissionPreparation:rebuildPackage()
    Inspection.release(self)
    local candidate = {}
    local previews = { "agentRoster", "captainPanel", "jaclPreview", "parallax" }
    local ok, message = pcall(function()
        candidate.biomes = BiomeIndex.refresh()
        candidate.jacls = JaclIndex.refresh()
        candidate.captains = CaptainIndex.refresh()
        candidate.agents = AgentIndex.refresh()
        local chunk, loadError = love.filesystem.load("data/prep_pool.lua")
        assert(chunk, loadError)
        candidate.package = Generator.generate(chunk(), {
            biomes = candidate.biomes, jacl = candidate.jacls,
            captains = candidate.captains, agents = candidate.agents,
        })
        candidate.biome = candidate.biomes.byId[candidate.package.biomeId]
        candidate.jacl = candidate.jacls.byId[candidate.package.jaclId]
        candidate.captain = candidate.captains.byId[candidate.package.captainId]
        candidate.agentRoster = AgentRoster.new(candidate.package.agentIds, candidate.agents, {
            x = 0, y = 0, width = self.width, height = self.height / 2,
        }, nil, candidate.package.biomeId)
        candidate.captainPanel = CaptainPanel.new(candidate.captain, { x = 0, y = self.height / 2 })
        candidate.jaclPreview = JaclPreview.new(candidate.jacl, self.width, self.height)
        candidate.parallax = ParallaxView.new(VisualCatalogue.refresh(candidate.package.biomeId),
            candidate.biome.parallax, {
                x = 0, y = self.height / 2, width = self.width, height = self.height / 2,
            })
    end)
    if not ok then
        for _, key in ipairs(previews) do if candidate[key] then candidate[key]:release() end end
        self.rerollError = tostring(message)
        print("[Reroll] " .. self.rerollError)
        return false, self.rerollError
    end
    for _, key in ipairs(previews) do if self[key] then self[key]:release() end end
    for key, value in pairs(candidate) do self[key] = value end
    self.entranceTime, self.rerollError, self.deployError = 0, nil, nil
    for _, key in ipairs(previews) do
        for _, diagnostic in ipairs(self[key].diagnostics) do print("[" .. key .. "] " .. diagnostic) end
    end
    return true
end

function MissionPreparation:mousepressed(x, y, mouseButton)
    if Inspection.mousepressed(self, x, y, mouseButton) then return end
    for _, button in ipairs(self.buttons or {}) do button:press(x, y, mouseButton) end
end

function MissionPreparation:mousereleased(x, y, mouseButton)
    if Inspection.mousereleased(self, x, y, mouseButton) then return end
    for _, button in ipairs(self.buttons or {}) do
        if button:releasePointer(x, y, mouseButton) then
            if button.id == "deploy" then
                self:deploy()
                return
            end
            if button.id == "reroll" then
                if self:rebuildPackage() then
                    self.audio:play("roll")
                    self.accents:pulse()
                end
            end
        end
    end
end

function MissionPreparation:focus(focused)
    Inspection.focus(self, focused)
    if not focused then
        for _, button in ipairs(self.buttons or {}) do
            button:cancelPress()
            button:updatePointer(nil, nil)
        end
    end
end

function MissionPreparation:deploy()
    local ok, prepared = pcall(Deployment.prepare, self.package, self.width, self.height, self.biome, self)
    if not ok then
        self.deployError = tostring(prepared)
        print("[Deployment] " .. self.deployError)
        return false
    end
    prepared.transition:take(self)
    prepared.scene = Backdrop.take(self)
    -- Transfer ownership so preparation exit cannot cut off the deployment cue.
    self.audio:stop()
    prepared.audio, self.audio = self.audio, nil
    self.stateMachine:change("mission_deployment", prepared)
    return true
end

function MissionPreparation:update(dt)
    Inspection.update(self, dt)
    Backdrop.update(self, dt)
end

function MissionPreparation:pointermoved(x, y)
    if Inspection.panelPointer(self, x, y) then return end
    Inspection.pointer(self, x, y)
    for _, button in ipairs(self.buttons or {}) do
        if button:updatePointer(x, y) and self.audio then self.audio:play("hover") end
    end
end

function MissionPreparation:exit(nextName)
    Inspection.release(self)
    if self.accents then self.accents:release() end
    self.accents = nil
    if self.audio then self.audio:release() end
    self.audio = nil
    if self.parallax then self.parallax:release() end
    self.parallax = nil
    if self.jaclPreview then self.jaclPreview:release() end
    self.jaclPreview = nil
    if self.captainPanel then self.captainPanel:release() end
    self.captainPanel = nil
    if self.agentRoster then self.agentRoster:release() end
    self.agentRoster = nil
    for _, button in ipairs(self.buttons or {}) do button:release() end
    self.buttons = nil
end

function MissionPreparation:wheelmoved(x, y) Inspection.wheel(self, y) end
function MissionPreparation:keypressed(key) Inspection.keypressed(self, key) end

function MissionPreparation:draw()
    Backdrop.draw(self)
    self.agentRoster:draw(self.entranceTime)
    for _, button in ipairs(self.buttons) do button:draw() end
    self.accents:draw(self.biome)
    love.graphics.setColor(0.65, 0.72, 0.82, 1)
    if #self.parallax.diagnostics > 0 or #self.jaclPreview.diagnostics > 0
        or #self.captainPanel.diagnostics > 0 or #self.agentRoster.diagnostics > 0
        or #self.buttonDiagnostics > 0 or self.rerollError or self.deployError then
        love.graphics.printf(self.deployError and "Deployment failed; keeping preparation. See diagnostics."
            or self.rerollError and "Reroll failed; keeping the current package. See diagnostics."
            or "Some preview content needs attention; see diagnostics.",
            0, self.height / 2 - 16, self.width, "center")
    end
    Inspection.draw(self)
end

return MissionPreparation
