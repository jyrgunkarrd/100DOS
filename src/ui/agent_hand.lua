local Tile = require("src.ui.card_tile")
local Animation = require("src.ui.animation")
local Hand = {}
Hand.__index = Hand

function Hand.new(cards, definitions, settings, font, equipment, portraitLeft, extraCards)
    for _, key in ipairs({ "revealDuration", "revealStagger", "revealMaximum", "revealOffset" }) do
        local n = settings[key]
        assert(type(n) == "number" and n >= 0 and n < math.huge, "Invalid hand " .. key)
    end
    assert(settings.revealMaximum >= settings.revealDuration, "Hand reveal exceeds maximum duration")
    for _, key in ipairs({ "width", "height", "gap", "minimumStep", "top", "bottomGap", "portraitGap" }) do
        local n = settings[key]
        assert(type(n) == "number" and n >= 0 and n < math.huge and n % 1 == 0, "Invalid hand " .. key)
    end
    assert(settings.height > 2 and settings.minimumStep >= 1 and settings.minimumStep <= settings.height,
        "Invalid hand tile/overlap size")
    assert(type(settings.directory) == "string" and type(settings.suffix) == "string", "Missing card image path")
    for _, key in ipairs({ "frameColor", "textColor", "hoverColor", "backgroundColor" }) do
        assert(type(settings[key]) == "table", "Missing hand " .. key)
        for i = 1, 4 do
            local v = settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid hand " .. key)
        end
    end
    local bottom = equipment.y - equipment.settings.labelGap - font:getHeight() - settings.bottomGap
    local width = math.min(settings.width, math.floor(portraitLeft - settings.portraitGap - equipment.x))
    assert(width >= settings.height * 2 + 24 and bottom - settings.top >= settings.height,
        "Agent hand does not fit beside the portrait")
    local self = setmetatable({ cards = cards, definitions = definitions, settings = settings, font = font,
        x = equipment.x, top = settings.top, bottom = bottom, width = width, first = 1,
        images = {}, diagnostics = {} }, Hand)
    local ok, failure = pcall(function()
        local cacheCards = {}
        for _, card in ipairs(cards) do cacheCards[#cacheCards + 1] = card end
        for _, card in ipairs(extraCards or {}) do cacheCards[#cacheCards + 1] = card end
        for _, card in ipairs(cacheCards) do
            assert(definitions.byId[card.cardId], "Unknown hand card")
            if self.images[card.cardId] == nil then
                local path = settings.directory .. "/" .. card.cardId .. settings.suffix
                local loaded, image = pcall(love.graphics.newImage, path)
                self.images[card.cardId] = loaded and image or false
                if loaded then image:setFilter("nearest", "nearest")
                else self.diagnostics[#self.diagnostics + 1] = "Cannot load card portrait: " .. path end
            end
        end
        self:layout()
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Hand:layout()
    local c, available = self.settings, self.bottom - self.top
    self.capacity = math.floor((available - c.height) / c.minimumStep) + 1
    local count = math.min(#self.cards, self.capacity)
    self.first = math.max(1, math.min(self.first, #self.cards - count + 1))
    self.step = count <= 1 and 0 or math.min(c.height + c.gap, math.floor((available - c.height) / (count - 1)))
    local top = self.bottom - (count > 0 and (c.height + (count - 1) * self.step) or 0)
    self.entries = {}
    for i = 1, count do
        local card = self.cards[self.first + i - 1]
        self.entries[i] = { card = card, x = self.x, y = top + (i - 1) * self.step }
    end
    self.hovered = nil
end

function Hand:hover(x, y)
    self.pointerX, self.pointerY = x, y
    self.hovered = nil
    if not x or not y or x < self.x or x >= self.x + self.width then return end
    -- Hit the original exposed strips, not the temporarily raised card.
    for i = #self.entries, 1, -1 do
        local entry = self.entries[i]
        -- Include each internal gap in the preceding card's hit region so the
        -- preview stays open while traversing the column. Outer bounds stay exact.
        local hitHeight = i < #self.entries and math.max(self.settings.height, self.step) or self.settings.height
        if y >= entry.y and y < entry.y + hitHeight then
            self.hovered = entry.card.instanceId
            return entry
        end
    end
end

function Hand:clearHover()
    self.hovered, self.pointerX, self.pointerY = nil, nil, nil
end

function Hand:wheelmoved(_, y)
    if not self.pointerX or self.pointerX < self.x or self.pointerX >= self.x + self.width
        or self.pointerY < self.top or self.pointerY >= self.bottom or y == 0 then return end
    self.first = self.first + (y < 0 and 1 or -1)
    self:layout()
    self:hover(self.pointerX, self.pointerY)
end

function Hand:revealStagger()
    local c = self.settings
    return #self.entries <= 1 and 0 or math.min(c.revealStagger,
        (c.revealMaximum - c.revealDuration) / (#self.entries - 1))
end

function Hand:revealDuration()
    if #self.entries == 0 then return 0 end
    return self.settings.revealDuration + (#self.entries - 1) * self:revealStagger()
end

function Hand:revealPose(index, elapsed)
    local progress = Animation.easeOutQuad(Animation.progress(elapsed or math.huge,
        (#self.entries - index) * self:revealStagger(), self.settings.revealDuration))
    return { alpha = progress, offsetY = math.floor(self.settings.revealOffset * (1 - progress) + 0.5) }
end

function Hand:draw(elapsed, draggedId, draggedAlpha)
    local g, raised = love.graphics, nil
    g.push("all")
    g.setFont(self.font)
    -- Allow the entrance offset into the reserved gap, but never over the asset label.
    local extra = elapsed and elapsed < self:revealDuration()
        and math.min(self.settings.revealOffset, self.settings.bottomGap) or 0
    g.intersectScissor(self.x, self.top, self.width, self.bottom - self.top + extra)
    local function draw(entry, hovered, index)
        local pose = self:revealPose(index, elapsed)
        if entry.card.instanceId == draggedId then pose.alpha = pose.alpha * (draggedAlpha or 0.35) end
        if pose.alpha == 0 then return end
        Tile.draw(entry.card, self.definitions.byId[entry.card.cardId], self.images[entry.card.cardId],
            self.font, self.settings, entry.x, entry.y + pose.offsetY, self.width, hovered, pose.alpha)
    end
    for index, entry in ipairs(self.entries) do
        if entry.card.instanceId == self.hovered then raised = index else draw(entry, false, index) end
    end
    if raised then draw(self.entries[raised], true, raised) end
    g.pop()
end

function Hand:release()
    for _, image in pairs(self.images) do if image then image:release() end end
    self.images = {}
end
return Hand
