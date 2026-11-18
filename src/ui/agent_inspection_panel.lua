local Config = require("data.agent_inspection_view")
local Preview = require("src.ui.card_preview")
local FateTile = require("src.ui.fate_tile")
local Assets = require("src.sys.artwork_assets")
local Panel = {}
Panel.__index = Panel

local function inside(box, x, y)
    return x and y and x >= box.x and x < box.x + box.width and y >= box.y and y < box.y + box.height
end

function Panel.new(model, definitions, fonts, width, height, biomeId)
    local c = Config
    local previewSettings = setmetatable({ scrollHint = c.rulesHint }, { __index = require("data.card_preview_view") })
    local x, y = math.floor((width - c.width) / 2), math.floor((height - c.height) / 2)
    local left, top = x + c.padding, y + c.padding
    local bodyY = top + 94
    local bodyHeight = y + c.height - c.padding - bodyY
    local detailX = left + c.listWidth + c.gap
    local cards, seen = {}, {}
    for _, tab in ipairs({ model.deck, model.discard }) do
        for _, row in ipairs(tab.rows) do
            if definitions.byId[row.id] and not seen[row.id] then
                cards[#cards + 1], seen[row.id] = { cardId = row.id }, true
            end
        end
    end
    local preview
    if #cards > 0 then
        preview = Preview.new(definitions, cards, previewSettings, fonts,
            { bounds = { x = detailX, width = previewSettings.width } },
            bodyHeight + previewSettings.top + previewSettings.bottomMargin, nil, biomeId)
        preview.y = bodyY
    end
    local panel = setmetatable({ x = x, y = y, width = c.width, height = c.height,
        fonts = fonts, model = model, preview = preview, assets = Assets.new(), tabs = {},
        capacity = math.floor(bodyHeight / c.rowHeight),
        list = { x = left, y = bodyY, width = c.listWidth, height = bodyHeight },
        detail = { x = detailX, y = bodyY, width = previewSettings.width, height = bodyHeight },
        close = { x = x + c.width - c.padding - 28, y = top, width = 28, height = 26 },
        screenWidth = width, screenHeight = height }, Panel)
    local tabWidth = math.floor((c.width - 2 * c.padding - (#c.tabs - 1) * 6) / #c.tabs)
    for index, tab in ipairs(c.tabs) do
        panel.tabs[index] = { id = tab.id, label = tab.label, x = left + (index - 1) * (tabWidth + 6),
            y = top + 36, width = tabWidth, height = 28 }
    end
    panel:showTab(c.tabs[1].id)
    return panel
end

function Panel:select(index)
    self.selected = self.model[self.tab].rows[index]
    if self.preview then
        local id = self.tab ~= "fate" and self.selected and self.selected.id
        self.preview:show(id and self.preview.displays[id] and id or nil)
    end
end

function Panel:showTab(id)
    self.tab, self.first = id, 1
    self:select(1)
end

function Panel:hit(x, y)
    if not inside(self, x, y) or inside(self.close, x, y) then return "close" end
    for _, tab in ipairs(self.tabs) do if inside(tab, x, y) then return tab.id end end
    if inside(self.list, x, y) then
        local offset = math.floor((y - self.list.y) / Config.rowHeight)
        local index = self.first + offset
        if offset < self.capacity and self.model[self.tab].rows[index] then return index end
    end
end

function Panel:pointer(x, y)
    self.pointerX, self.pointerY = x, y
    self.hovered = x and y and self:hit(x, y)
end

function Panel:press(x, y)
    self.pressed = self:hit(x, y)
end

function Panel:releasePointer(x, y)
    local hit, pressed = self:hit(x, y), self.pressed
    self.pressed = nil
    if not hit or hit ~= pressed then return end
    if hit == "close" then return true end
    if type(hit) == "number" then self:select(hit)
    elseif hit ~= self.tab then self:showTab(hit) end
end

function Panel:wheel(delta)
    if delta == 0 then return end
    if self.preview and self.preview.cardId and inside(self.detail, self.pointerX, self.pointerY) then
        self.preview:wheelmoved(delta)
    else
        local maximum = math.max(1, #self.model[self.tab].rows - self.capacity + 1)
        local step = math.max(1, math.floor(math.abs(delta)))
        self.first = math.max(1, math.min(maximum, self.first + (delta > 0 and -step or step)))
        self:pointer(self.pointerX, self.pointerY)
    end
end

local function centered(font, text, box)
    love.graphics.setFont(font)
    love.graphics.printf(text, box.x, math.floor(box.y + (box.height - font:getHeight()) / 2), box.width, "center")
end

function Panel:drawFate(row)
    local copies = row.quantity == 1 and " COPY" or " COPIES"
    FateTile.drawDetails(row, self.assets, self.fonts, self.detail, Config,
        row.quantity .. copies .. (self.model.planned and " PLANNED" or " CONTRIBUTED"))
end

function Panel:draw()
    local g, c, fonts = love.graphics, Config, self.fonts
    local tab, list, detail = self.model[self.tab], self.list, self.detail
    g.push("all")
    g.setColor(c.shade); g.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    g.setColor(c.background); g.rectangle("fill", self.x, self.y, self.width, self.height)
    g.setColor(c.accent); g.rectangle("line", self.x + 0.5, self.y + 0.5, self.width - 1, self.height - 1)
    g.setFont(fonts.small); g.setColor(c.muted)
    g.print("AGENT INSPECTION", list.x, self.y + c.padding)
    g.setFont(fonts.heading); g.setColor(c.text)
    local name = self.model.name:gsub("%s+", " ")
    local nameScale = math.min(1, (self.close.x - list.x - c.gap) / math.max(1, fonts.heading:getWidth(name)))
    g.print(name, list.x, self.y + c.padding + 13, 0, nameScale, nameScale)
    g.setColor(self.hovered == "close" and c.highlight or c.row)
    g.rectangle("fill", self.close.x, self.close.y, self.close.width, self.close.height)
    g.setColor(c.text); centered(fonts.heading, "X", self.close)
    for _, button in ipairs(self.tabs) do
        local active = button.id == self.tab
        g.setColor((active or self.hovered == button.id) and c.highlight or c.row)
        g.rectangle("fill", button.x, button.y, button.width, button.height)
        if active then
            g.setColor(c.accent); g.rectangle("fill", button.x, button.y + button.height - 2, button.width, 2)
        end
        g.setColor(c.text); centered(fonts.heading, button.label .. "  " .. self.model[button.id].total, button)
    end
    local subtitle = self.tab == "deck" and (self.model.live and "REMAINING DRAW PILE" or "STARTING DECK")
        or self.tab == "discard" and "DISCARD PILE"
        or (self.model.planned and "PLANNED CONTRIBUTION" or "CONTRIBUTED TO THE FATE POOL")
    g.setFont(fonts.small); g.setColor(c.muted); g.print(subtitle, list.x, list.y - 18)
    if tab.total == 0 then g.print(c.empty[self.tab], list.x, list.y + 10) end
    for i = self.first, math.min(#tab.rows, self.first + self.capacity - 1) do
        local row = tab.rows[i]
        local y = list.y + (i - self.first) * c.rowHeight
        g.setColor((row == self.selected or self.hovered == i) and c.highlight or c.row)
        g.rectangle("fill", list.x, y, list.width, c.rowHeight - 3)
        g.setFont(fonts.heading); g.setColor(c.text)
        local rowName = row.name:gsub("%s+", " ")
        local scale = math.min(1, (list.width - 68) / math.max(1, fonts.heading:getWidth(rowName)))
        g.print(rowName, list.x + 10, y + 8, 0, scale, scale)
        g.printf("x" .. row.quantity, list.x, y + 8, list.width - 10, "right")
    end
    if #tab.rows > self.capacity then
        g.setFont(fonts.small); g.setColor(c.muted)
        g.printf(self.first .. "–" .. math.min(#tab.rows, self.first + self.capacity - 1) .. " / " .. #tab.rows,
            list.x, list.y + self.capacity * c.rowHeight + 4, list.width, "right")
    end
    if self.selected then
        if self.tab == "fate" then self:drawFate(self.selected)
        elseif self.preview and self.preview.cardId then self.preview:draw()
        else g.setFont(fonts.small); g.setColor(c.muted); g.printf("CARD DETAILS UNAVAILABLE", detail.x, detail.y + 10, detail.width, "center") end
    end
    g.pop()
end

function Panel:release()
    if self.preview then self.preview:release() end
    self.assets:release()
end

return Panel
