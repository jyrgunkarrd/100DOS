-- An inspection-only composition of Agent Action views. No activation, actions or session ownership.
local Preview = require("src.ui.card_preview")
local Controller = require("src.ui.card_preview_controller")
local Exploration = require("src.ui.location_exploration_panel")
local Portrait = require("src.ui.selected_agent_portrait")
local Equipment = require("src.ui.agent_equipment_row")
local Hand = require("src.ui.agent_hand")
local StatusView = require("src.ui.agent_status")
local Status = require("src.sys.agent_status")
local Footprint = require("src.ui.asset_footprint")
local Config = require("data.agent_observation_view")
local Observation = {}
Observation.__index = Observation
local function inside(box, x, y)
    return x and y and x >= box.x and x < box.x + box.width and y >= box.y and y < box.y + box.height
end

function Observation.new(session, id, width, height, openDetails)
    assert(session.agentStatus.byAgent[id] and session.agentCards.byAgent[id], "Missing inspected Agent")
    local self = setmetatable({ readOnly = true, session = session, agentId = id, width = width, height = height,
        openDetails = openDetails, fonts = session.scene.accents }, Observation)
    local ok, failure = xpcall(function()
        local agents, definitions = session.agentCards.agents, session.agentCards.definitions
        self.name = agents.byId[id].name:gsub("%s+", " ")
        self.portrait = Portrait.new({ id }, session.grid, width, require("data.mission_action").portrait, agents, session.package.biomeId)
        local settings = require("data.agent_action")
        local bracket = self.portrait.accents and self.portrait.accents.gap + 1 or 0
        self.portrait:setPosition(width - settings.rightMargin - self.portrait.size - bracket, self.portrait.y)
        self.equipment = Equipment.new(require("data.agent_equipment_slots"), require("data.agent_equipment_view"),
            width, session.scene.parallax.rectangle.y)
        local board = session.agentAssets and session.agentAssets.byAgent[id]
        self.assets = board and board.placements or {}
        local cards = {}
        for _, card in ipairs(session.agentCards.byAgent[id].hand) do cards[#cards + 1] = card end
        for _, asset in ipairs(self.assets) do cards[#cards + 1] = asset.card end
        self.hand = Hand.new(session.agentCards.byAgent[id].hand, definitions, require("data.agent_hand_view"),
            self.fonts.small, self.equipment, self.portrait.x - bracket, cards)
        self.status = StatusView.new(require("data.agent_status_view"), self.fonts)
        self.exploration = Exploration.new(session, id, require("data.location_exploration_view"),
            require("data.location_exploration_rules"), self.fonts, { readOnly = true })
        self.cardPreview = Preview.new(definitions, cards, require("data.card_preview_view"), self.fonts,
            session.grid, height, nil, session.package.biomeId)
        local locationCards, seen = {}, {}
        local function include(card)
            if not seen[card.cardId] then locationCards[#locationCards + 1] = card; seen[card.cardId] = true end
        end
        local deck = session.locationDecks.byCell[self.exploration.cell]
        for _, instanceId in ipairs(deck.inPlayOrder) do include(deck.inPlay[instanceId]) end
        for _, card in ipairs(deck.lastMilling and deck.lastMilling.cards or {}) do include(card) end
        self.locationPreview = Preview.new(session.locationCardPool, locationCards, require("data.location_card_preview_view"),
            self.fonts, session.grid, height, require("src.sys.location_card_display").normalize, session.package.biomeId)
        self.previews = Controller.new(self.cardPreview, self.locationPreview, session.audio,
            function(agentId) return self.exploration:agentName(agentId) end)
        self.detailsButton = { x = math.floor((width - Config.buttonWidth) / 2),
            y = Config.titleY + Config.hintGap + Config.buttonGap, width = Config.buttonWidth, height = Config.buttonHeight }
    end, debug.traceback)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Observation:pointer(x, y)
    self.pointerX, self.pointerY = x, y
    if self.details then self.session.missionFooter:clearHover(); self.details:pointer(x, y); return end
    local targetHovered = self.session.missionFooter:pointer(self.session, x, y)
    self.hand:hover(x, y); self.exploration:pointermoved(x, y)
    if targetHovered then self.previews:clear(); return end
    local location = self.exploration:hoveredMilledCard() or self.exploration:hoveredCard()
    if location then self.previews:show("location", location); return end
    local card
    for _, entry in ipairs(self.hand.entries) do if entry.card.instanceId == self.hand.hovered then card = entry.card; break end end
    if not card then
        local index = self.equipment:hit(x, y)
        local asset = index and self.session.agentAssets and self.session.agentAssets:at(self.agentId, index)
        card = asset and asset.card
    end
    self.previews:show("player_card", card)
end
function Observation:press(x, y)
    if self.details then self.details:press(x, y); return end
    self.pressed = inside(self.detailsButton, x, y) and "details" or nil
    self.exploration:pressReceipt(x, y)
end
function Observation:focus()
    self.pressed = nil
    self.exploration:cancel()
    if self.details then self.details.pressed = nil end
    self:pointer(nil, nil)
end
function Observation:releasePointer(x, y)
    if self.details then
        if self.details:releasePointer(x, y) then self.details:release(); self.details = nil; self:pointer(x, y) end
        return false
    end
    local pressed = self.pressed; self.pressed = nil
    if pressed == "details" and inside(self.detailsButton, x, y) then
        local ok, result = pcall(self.openDetails)
        if ok then self.details = result; self.detailsError = nil; self.previews:clear()
        else self.detailsError = tostring(result) end
    elseif self.exploration:releaseReceipt(x, y) then self:pointer(x, y) end
    return false
end
function Observation:wheel(delta)
    if self.details then self.details:wheel(delta); return end
    if self.session.missionFooter:wheel(delta) then return end
    if love.keyboard.isDown("lshift", "rshift") and self.previews:wheelmoved(delta) then return end
    if not self.exploration:wheelmoved(delta) then self.hand:wheelmoved(0, delta) end
    self:pointer(self.pointerX, self.pointerY)
end
function Observation:draw()
    local s, g, id = self.session, love.graphics, self.agentId
    require("src.ui.mission_backdrop").draw(s.scene)
    s.grid:draw(s.art, nil, s.agentDeployment.placements)
    if s.armyView then s.armyView:draw() end
    require("src.ui.hunt_distribution").outlines(s)
    s.agentView:draw(nil, { deploymentIndicators = false, rosterIndicators = false })
    self.portrait:draw(id, self.fonts.heading, self.fonts.small, nil, { hideLabel = true })
    self.status:draw(self.portrait, s.agentStatus.byAgent[id])
    self.exploration:draw(false)
    self.equipment:draw(self.fonts.small)
    for _, asset in ipairs(self.assets) do
        Footprint.draw(self.equipment, asset, self.hand.images[asset.cardId or asset.card.cardId], self.fonts,
            require("data.card_play_view"))
    end
    self.hand:draw()
    require("src.ui.hunt_distribution").markers(s, self.fonts.small)
    s.missionFooter:draw(s)
    g.push("all")
    if #self.hand.cards == 0 then
        g.setFont(self.fonts.small); g.setColor(Config.muted)
        g.printf(Config.emptyHand, self.hand.x, self.hand.bottom - 20, self.hand.width, "center")
    end
    local status = s.agentStatus.byAgent[id]
    local label = Status.isDefeatedState(status) and Config.defeated or status.exhausted and Config.exhausted
        or s.activeAgentId == id and Config.active or Config.ready
    local x, width = s.grid.bounds.x - 12, s.grid.bounds.width + 24
    g.setColor(Config.background); g.rectangle("fill", x, Config.titleY - 12, width, 104)
    g.setFont(self.fonts.heading); g.setColor(Config.text)
    g.printf(Config.heading .. " / " .. self.name, x + 6, Config.titleY, width - 12, "center")
    g.setFont(self.fonts.small); g.setColor(Config.muted)
    g.printf(label .. " / " .. Config.hint, x, Config.titleY + Config.hintGap, width, "center")
    local b = self.detailsButton
    g.setColor(inside(b, self.pointerX, self.pointerY) and Config.text or Config.accent)
    g.rectangle("line", b.x + 0.5, b.y + 0.5, b.width - 1, b.height - 1)
    g.printf(Config.details, b.x, b.y + math.floor((b.height - self.fonts.small:getHeight()) / 2) + 1, b.width, "center")
    if self.detailsError then g.printf("DETAILS UNAVAILABLE", x, b.y + b.height + 8, width, "center") end
    g.pop()
    self.previews:draw()
    self.session.missionFooter:drawPreview(self.session)
    if self.details then self.details:draw() end
end
function Observation:release()
    self.session.missionFooter:clearHover()
    if self.details then self.details:release(); self.details = nil end
    if self.previews then self.previews:release(); self.previews = nil
    else
        if self.cardPreview then self.cardPreview:release() end
        if self.locationPreview then self.locationPreview:release() end
    end
    for _, key in ipairs({ "hand", "portrait", "status", "exploration" }) do
        if self[key] then self[key]:release(); self[key] = nil end
    end
    self.cardPreview, self.locationPreview, self.session = nil, nil, nil
end
return Observation
