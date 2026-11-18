local View = {}
View.__index = View
local C = require("data.silencer_view")
local function reducedMotion() return C.reducedMotion or require("data.doom_clock_view").reducedMotion end
function View.validate()
    for _, key in ipairs({ "arrivalDuration", "dropDuration", "departureDuration", "feedbackDuration" }) do
        assert(type(C[key]) == "number" and C[key] > 0 and C[key] < math.huge, "Invalid Silencer view " .. key)
    end
    for _, key in ipairs({ "stagger", "hoverGap", "hoverSpacing", "hoverHorizontalSpacing", "hoverAmplitude" }) do
        assert(type(C[key]) == "number" and C[key] >= 0 and C[key] < math.huge, "Invalid Silencer view " .. key)
    end
    assert(type(C.reducedMotion) == "boolean", "Invalid Silencer reducedMotion")
end
function View.duration(presentation)
    if not presentation or reducedMotion() then return 0 end
    local base = presentation.kind == "arrive" and C.arrivalDuration or C.dropDuration + C.departureDuration
    return base + math.max(0, #presentation.transports - 1) * C.stagger
end
function View.ordered(transports)
    local result = {}; for i, transport in ipairs(transports) do result[i] = transport end
    table.sort(result, function(a, b)
        if a.vis_order == b.vis_order then return a.order < b.order end
        return a.vis_order > b.vis_order
    end)
    return result
end
function View.new(state, jacl)
    View.validate()
    local font = love.graphics.newFont(C.feedbackFont, C.feedbackFontSize)
    font:setFilter("nearest", "nearest")
    local self = setmetatable({ state = state, jacl = jacl, elapsed = 0,
        assets = require("src.sys.artwork_assets").new(), images = {}, feedbackFont = font }, View)
    for id in pairs(state.catalogue.transports) do
        for _, suffix in ipairs({ "", "_jump" }) do
            self.images[id .. suffix] = self.assets:load("assets/images/silencers/" .. id .. suffix .. ".png")
        end
    end
    self.hover = require("src.ui.transport_hover").new(self)
    return self
end
function View:update(dt)
    self.elapsed = self.elapsed + math.max(0, dt)
    if self.state.receipt then self.state.receipt.elapsed = self.state.receipt.elapsed + math.max(0, dt) end
end
local function clamp(n) return math.max(0, math.min(1, n)) end
-- One pose list drives both rendering and pixel-accurate hover selection.
function View:poses()
    local state = self.state
    local cx, landing, width, height = self.jacl:transportAnchor()
    local presentation = state.presentation
    local transports = state.feedbackTransports or (presentation and presentation.transports or state.transports)
    local poses = {}
    for _, transport in ipairs(View.ordered(transports)) do
        local image = self.images[transport.id]
        if image then
            local iw, ih = image:getDimensions()
            local hoverX = cx + (transport.order - (#transports + 1) / 2) * C.hoverHorizontalSpacing
            local x, y = hoverX, landing - C.hoverGap - (transport.order - 1) * C.hoverSpacing
            y = y + (reducedMotion() and 0 or math.sin(self.elapsed * 2 + transport.order) * C.hoverAmplitude)
            local age = presentation and presentation.elapsed - (transport.order - 1) * C.stagger
            local visible, jumpX, jumpY = true
            if presentation and presentation.kind == "arrive" then
                local t = reducedMotion() and 1 or clamp(age / C.arrivalDuration)
                x = -iw / 2 + (hoverX + iw / 2) * (1 - (1 - t) ^ 2)
            elseif presentation then
                local t = reducedMotion() and 1 or clamp((age - C.dropDuration) / C.departureDuration)
                x = hoverX + (width + iw / 2 - hoverX) * t * t
                visible = t < 1
                local jump = self.images[transport.id .. "_jump"]
                if jump and age >= 0 and age < C.dropDuration and not reducedMotion() then
                    local fall = clamp(age / C.dropDuration)
                    jumpX, jumpY = math.floor(hoverX - jump:getWidth() / 2),
                        math.floor(y + (landing - y) * fall * fall - jump:getHeight())
                end
            end
            poses[#poses + 1] = { transport = transport, image = image, visible = visible,
                x = math.floor(x - iw / 2), y = math.floor(y - ih), width = iw, height = ih,
                jumpX = jumpX, jumpY = jumpY }
        end
    end
    return poses, width, height
end
function View:draw()
    local g, state = love.graphics, self.state
    local cx, landing, width, height = self.jacl:transportAnchor()
    g.push("all")
    g.intersectScissor(0, 0, width, height)
    for _, pose in ipairs(self:poses()) do
        g.setColor(1, 1, 1, 1)
        if pose.jumpX then g.draw(self.images[pose.transport.id .. "_jump"], pose.jumpX, pose.jumpY) end
        if pose.visible then g.draw(pose.image, pose.x, pose.y) end
    end
    local receipt = state.receipt
    if receipt and not state.phaseFeedbackActive and receipt.elapsed < C.feedbackDuration then
        local text = receipt.deployed > 0 and ("SILENCERS DEPLOYED: " .. receipt.deployed) or nil
        if not receipt.events and receipt.converted + receipt.blocked + receipt.milled > 0 then
            text = string.format("SABOTAGE +%d   BLOCKED %d   DAMAGE %d   MILLED %d",
                receipt.converted, receipt.blocked, receipt.damage, receipt.milled)
        end
        if text then
            local font = self.feedbackFont
            g.setFont(font)
            local textWidth = math.min(480, font:getWidth(text))
            local _, lines = font:getWrap(text, textWidth)
            local width = textWidth + 16
            local height = font:getHeight() * (1 + (#lines - 1) * font:getLineHeight()) + 8
            local x, y = math.floor(cx - width / 2), math.floor(landing - 22)
            g.setColor(0, 0, 0, 0.96)
            g.rectangle("fill", x, y, width, height)
            g.setLineWidth(1)
            g.setColor(1, 0.36, 0.24, 1)
            g.rectangle("line", x, y, width, height)
            g.printf(text, x + 8, y + 4, textWidth, "center")
        end
    end
    g.pop()
end
function View.markers(session)
    local state = session.silencers
    local receipt = state and state.receipt
    if not receipt or state.phaseFeedbackActive or receipt.deployed == 0 or receipt.elapsed >= C.feedbackDuration then return end
    local id = require("src.sys.mission_deck_effects").jaclCell(session)
    for _, cell in ipairs(session.grid.cells) do
        if cell.id == id then
            local g = love.graphics
            g.push("all")
            g.setColor(1, 0.36, 0.24, 1 - receipt.elapsed / C.feedbackDuration)
            g.setLineWidth(3)
            g.polygon("line", cell.vertices)
            g.pop()
            break
        end
    end
end
function View:release()
    if self.hover then self.hover:release() end
    self.assets:release()
    if self.feedbackFont then self.feedbackFont:release(); self.feedbackFont = nil end
end
return View
