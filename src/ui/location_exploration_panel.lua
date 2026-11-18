local MillingView = require("data.location_milling_view")
local Tile = require("src.ui.card_tile")
local Layout = require("src.ui.card_column_layout")
local Engagement = require("src.sys.location_engagement")
local utf8 = require("utf8")
local Panel = {}
Panel.__index = Panel
local function inside(x, y, box)
    return x and y and x >= box.x and y >= box.y and x < box.x + box.width and y < box.y + box.height
end

function Panel.new(session, agentId, settings, rules, fonts, options)
    for _, key in ipairs({ "left", "top", "width", "mapGap", "bottomGap", "height", "gap", "minimumNameHeight", "listHeaderGap", "revealDuration", "engagementHeight", "columnGap" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge, "Invalid exploration view " .. key)
    end
    assert(settings.height >= 16 and settings.minimumNameHeight >= 1 and settings.width >= 120, "Exploration panel too small")
    for _, key in ipairs({ "frameColor", "textColor", "mutedColor", "hoverColor", "backgroundColor", "engagementColor" }) do
        for i = 1, 4 do
            local v = settings[key] and settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid exploration color " .. key)
        end
    end
    assert(settings.showCost == false and type(settings.directory) == "string" and type(settings.suffix) == "string",
        "Invalid location tile settings")
    assert(type(settings.typeOrder) == "table" and type(settings.typeLabels) == "table" and type(settings.typeColors) == "table",
        "Invalid location type presentation")
    for kind, label in pairs(settings.typeLabels) do
        assert(type(kind) == "string" and type(label) == "string", "Invalid exploration type label")
    end
    for kind, color in pairs(settings.typeColors) do
        assert(type(kind) == "string" and type(color) == "table", "Invalid exploration type color")
        for i = 1, 4 do
            assert(type(color[i]) == "number" and color[i] >= 0 and color[i] <= 1, "Invalid exploration type color")
        end
    end
    for _, key in ipairs({ "location", "remaining", "revealed", "explore", "action", "actions", "empty", "scroll", "revealing" }) do
        assert(type(settings.labels and settings.labels[key]) == "string", "Missing exploration label " .. key)
    end
    assert(type(settings.engagementLabel) == "string" and type(settings.engagementCountLabel) == "string",
        "Missing engagement labels")
    local agentNames = {}
    for id, definition in pairs(require("data.agents.index").refresh().byId) do
        agentNames[id] = definition.name:gsub("%s+", " ")
    end
    local cell = assert(session.agentDeployment.placements[agentId], "Agent has no location")
    local state = assert(session.locationDecks.byCell[cell], "Missing location deck")
    local summary = session.locationDecks:publicSummary(cell)
    local types, seen = {}, {}
    for _, kind in ipairs(settings.typeOrder) do
        if summary.byType[kind] ~= nil and not seen[kind] then types[#types + 1] = kind; seen[kind] = true end
    end
    for _, kind in ipairs(summary.types) do if not seen[kind] then types[#types + 1] = kind end end
    local self = setmetatable({ session = session, agentId = agentId, cell = cell, settings = settings,
        rules = rules, fonts = fonts, types = types, agentNames = agentNames, images = {}, definitions = {}, diagnostics = {},
        x = settings.left, y = settings.top, width = settings.width, first = 1, revealTime = 0,
        readOnly = options and options.readOnly == true }, Panel)
    assert(self.x + self.width + settings.mapGap <= session.grid.bounds.x, "Exploration panel overlaps map")
    self.listY = self.y + 70 + math.ceil(#types / 2) * 18 + settings.listHeaderGap
    self.bottom = session.scene.parallax.rectangle.y - settings.bottomGap
    assert(self.bottom - 16 - self.listY >= settings.height + settings.engagementHeight, "Exploration summary leaves no room for cards")
    -- Preload the pool while preparing the interface; revealing never allocates artwork.
    local ok, failure = pcall(function()
        for _, id in ipairs(session.locationCardPool.ids) do
            local def = session.locationCardPool.byId[id]
            self.definitions[id] = { name = type(def.name) == "string" and def.name or id }
            local path = require("src.sys.artwork_resolver").cardPath(def, id, settings.directory, settings.suffix)
            if require("src.sys.location_card_traits").hunt(def) and not love.filesystem.getInfo(path) then
                path = settings.directory .. "/" .. id .. ".png"
            end
            local loaded, art = pcall(love.graphics.newImage, path)
            if loaded then self.images[id] = art; art:setFilter("nearest", "nearest")
            else self.images[id] = false; self.diagnostics[#self.diagnostics + 1] = "Missing location artwork: " .. path end
        end
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Panel:setCell(cell)
    assert(self.session.locationDecks.byCell[cell], "Missing destination location deck")
    local summary = self.session.locationDecks:publicSummary(cell)
    local types, seen = {}, {}
    for _, kind in ipairs(self.settings.typeOrder) do
        if summary.byType[kind] ~= nil and not seen[kind] then types[#types + 1] = kind; seen[kind] = true end
    end
    for _, kind in ipairs(summary.types) do if not seen[kind] then types[#types + 1] = kind end end
    self.cell, self.types, self.first, self.faceUpFirst = cell, types, 1, 1
    self.latest, self.attackingId, self.revealTime = nil, nil, 0
    self.receiptOpen, self.receiptFirst = false, 1
    self.listY = self.y + 70 + math.ceil(#types / 2) * 18 + self.settings.listHeaderGap
    self:cancel()
end
function Panel:busy() return self.revealTime > 0 end
function Panel:update(dt) self.revealTime = math.max(0, self.revealTime - math.max(0, dt)) end
function Panel:cancel() self.receiptPressed = nil; self.pressed = false; self.pointerX, self.pointerY = nil, nil end
function Panel:pointermoved(x, y) self.pointerX, self.pointerY = x, y end
function Panel:revealed(card)
    self.receiptOpen = false
    self.latest = card.instanceId
    self.revealTime = self.settings.revealDuration
    self.first = self:lastPageStart()
end
function Panel:receipt()
    return self.session.locationDecks.byCell[self.cell].lastMilling
end
function Panel:receiptBox()
    return { x = self.x + self.width / 2, y = self.listY - 34, width = self.width / 2, height = 16 }
end
function Panel:pressReceipt(x, y)
    self.receiptPressed = self:receipt() and inside(x, y, self:receiptBox()) or false
    return self.receiptPressed
end
function Panel:releaseReceipt(x, y)
    if not self.receiptPressed then return false end
    self.receiptPressed = false
    if inside(x, y, self:receiptBox()) then self.receiptOpen = not self.receiptOpen; self.receiptFirst = 1 end
    return true
end
function Panel:receiptEntries()
    local receipt = self:receipt()
    local groups, byId = {}, {}
    if not receipt then return groups end
    for _, card in ipairs(receipt.cards) do
        local key = card.cardId .. ":" .. (card.source or "") .. ":" .. (card.destination or "discardPile")
        if not byId[key] then
            local group = { card = card, count = 0 }
            groups[#groups + 1], byId[key] = group, group
        end
        byId[key].count = byId[key].count + 1
    end
    return groups
end
function Panel:receiptCapacity()
    return math.max(1, math.floor((self.bottom - self.listY - 58) / MillingView.receiptRow))
end
function Panel:hoveredMilledCard()
    if not self.receiptOpen then return end
    local groups = self:receiptEntries()
    local first = math.min(self.receiptFirst or 1, math.max(1, #groups - self:receiptCapacity() + 1))
    for i = first, math.min(#groups, first + self:receiptCapacity() - 1) do
        if inside(self.pointerX, self.pointerY, { x = self.x, y = self.listY + 40 + (i - first) * MillingView.receiptRow,
            width = self.width, height = MillingView.receiptRow }) then return groups[i].card end
    end
end
function Panel:drawReceipt()
    local receipt = self:receipt()
    if not receipt then return end
    local g, c = love.graphics, self.settings
    g.setFont(self.fonts.small); g.setColor(c.textColor)
    g.printf((receipt.locationName or receipt.locationId) .. " / " .. receipt.actual .. " MILLED / DECK "
        .. receipt.before .. (receipt.concealed and " + ?" or "") .. " > " .. receipt.after
        .. (receipt.concealed and " + ?" or ""), self.x, self.listY + 3, self.width, "left")
    if receipt.actual == 0 then
        g.printf(receipt.requested > 0 and "DECK EMPTY" or "NO CARDS MILLED", self.x, self.listY + 40, self.width, "left")
        return
    end
    local groups, capacity = self:receiptEntries(), self:receiptCapacity()
    local first = math.min(self.receiptFirst or 1, math.max(1, #groups - capacity + 1))
    for i = first, math.min(#groups, first + capacity - 1) do
        local entry, y = groups[i], self.listY + 40 + (i - first) * MillingView.receiptRow
        g.setColor(self:hoveredMilledCard() == entry.card and c.hoverColor or c.textColor)
        g.push("all"); g.intersectScissor(self.x, y, self.width, MillingView.receiptRow)
        g.printf(entry.count .. "x " .. entry.card.name
            .. ((entry.card.source == "glory" or entry.card.source == "silencer" or entry.card.source == "control") and " / " .. entry.card.source:upper() or "") .. (entry.card.destination == "inPlay" and " / IN PLAY" or ""),
            self.x, y + 3, self.width, "left"); g.pop()
    end
    g.setColor(c.mutedColor)
    g.printf("NAMES " .. first .. "-" .. math.min(#groups, first + capacity - 1) .. " / " .. #groups
        .. "  /  HOVER TO INSPECT", self.x, self.bottom - 12, self.width, "left")
end

function Panel:wheelmoved(delta)
    local box = { x = self.x, y = self.listY, width = self.width, height = self.bottom - self.listY }
    if not inside(self.pointerX, self.pointerY, box) then return false end
    if self.receiptOpen then
        self.receiptFirst = math.floor(math.max(1, math.min(math.max(1, #self:receiptEntries() - self:receiptCapacity() + 1),
            (self.receiptFirst or 1) - delta)))
        return true
    end
    for _,column in ipairs(self:columns()) do
        if inside(self.pointerX,self.pointerY,column) then
            self[column.scrollKey] = math.floor(math.max(1,math.min(self:lastPageStart(column.kind),
                (self[column.scrollKey] or 1)-delta)))
            return true
        end
    end
    return false
end

function Panel:agentName(id) return self.agentNames[id] or id end
function Panel:cardHeight(card)
    return self.settings.height + ((Engagement.target(card) or card.health or not self.session.locationDecks.byCell[self.cell].inPlay[card.instanceId]) and self.settings.engagementHeight or 0)
end
function Panel:columns()
    local gap = self.settings.columnGap
    local width = math.floor((self.width-gap)/2)
    return {
        { kind = "inPlay", scrollKey = "first", label = "IN PLAY", x = self.x, y = self.listY,
            width = width, height = self.bottom-self.listY },
        { kind = "faceUp", scrollKey = "faceUpFirst", label = "REVEALED", x = self.x+width+gap, y = self.listY,
            width = self.width-width-gap, height = self.bottom-self.listY },
    }
end
function Panel:listedCards(kind)
    if kind == "faceUp" then return self.session.locationDecks:faceUpCards(self.cell) end
    local cards, state = {}, self.session.locationDecks.byCell[self.cell]
    for _,id in ipairs(state.inPlayOrder) do cards[#cards+1] = state.inPlay[id] end
    return cards
end
function Panel:columnLayout(kind, first)
    local cards,items = self:listedCards(kind),{}
    for i,card in ipairs(cards) do
        local height = self:cardHeight(card)
        items[i] = {height=height,minimum=math.min(height,height-self.settings.height+self.settings.minimumNameHeight)}
    end
    return Layout.build(items,self.bottom-16-self.listY,self.settings.gap,first),cards
end
function Panel:lastPageStart(kind)
    return self:columnLayout(kind,1).lastStart
end
function Panel:visibleCards()
    local entries = {}
    for _,column in ipairs(self:columns()) do
        local layout,cards = self:columnLayout(column.kind,self[column.scrollKey])
        self[column.scrollKey] = layout.first
        for _,item in ipairs(layout.entries) do
            entries[#entries+1]={card=cards[item.index],x=column.x,y=self.listY+item.y,width=column.width,
                height=item.height,hitHeight=item.hitHeight,column=column.kind}
        end
    end
    return entries
end
function Panel:showInstance(instanceId)
    for _,column in ipairs(self:columns()) do
        for i,card in ipairs(self:listedCards(column.kind)) do
            if card.instanceId == instanceId then
                self[column.scrollKey] = math.min(i,self:lastPageStart(column.kind)); return
            end
        end
    end
end

function Panel:hoveredCard()
    if self.receiptOpen then return end
    local entries = self:visibleCards()
    for i, entry in ipairs(entries) do
        local hitHeight = entry.hitHeight
        if inside(self.pointerX, self.pointerY,
            { x = entry.x, y = entry.y, width = entry.width, height = hitHeight }) then return entry.card end
    end
end

function Panel:draw(enabled)
    local g, c, f = love.graphics, self.settings, self.fonts
    local state = self.session.locationDecks.byCell[self.cell]
    local summary = self.session.locationDecks:publicSummary(self.cell)
    self.first = math.min(self.first, self:lastPageStart())
    g.push("all")
    g.intersectScissor(self.x, self.y, self.width, self.bottom - self.y)
    g.setFont(f.small); g.setColor(c.mutedColor); g.print(c.labels.location, self.x, self.y)
    g.setFont(f.heading); g.setColor(c.textColor)
    g.push("all"); g.intersectScissor(self.x, self.y + 14, self.width, 28)
    g.printf(state.locationName, self.x, self.y + 14, self.width, "left"); g.pop()
    g.setFont(f.small); g.setColor(c.textColor)
    g.print(c.labels.remaining .. (summary.concealed and (c.labels.concealed or " / ? HIDDEN") or ""), self.x, self.y + 50)
    g.printf(tostring(summary.total) .. (summary.concealed and " + ?" or ""), self.x, self.y + 50, self.width, "right")
    for i, kind in ipairs(self.types) do
        local x = self.x + ((i - 1) % 2) * math.floor(self.width / 2)
        local y = self.y + 70 + math.floor((i - 1) / 2) * 18
        g.setColor(c.typeColors[kind] or c.textColor)
        local label = (c.typeLabels[kind] or kind:gsub("_", " ")):upper()
        g.push("all"); g.intersectScissor(x, y, math.floor(self.width / 2) - 8, 16)
        g.print(label .. " " .. summary.byType[kind], x, y); g.pop()
    end
    local engagedCount = Engagement.count(self.session, self.agentId)
    if engagedCount > 0 then
        g.setColor(c.engagementColor)
        g.print(c.engagementCountLabel .. engagedCount, self.x, self.listY - 28)
    end
    if self:receipt() then
        local box = self:receiptBox()
        g.setColor(self.receiptOpen and c.hoverColor or c.frameColor)
        g.rectangle("line",box.x,box.y,box.width,box.height)
        g.printf(self.receiptOpen and "< LOCATION CARDS" or "LAST MILL " .. self:receipt().actual .. " >",
            box.x,box.y+4,box.width,"center")
    end
    if self.receiptOpen and self:receipt() then self:drawReceipt(); g.pop(); return end
    for _,column in ipairs(self:columns()) do
        local count = #self:listedCards(column.kind)
        g.setColor(c.textColor); g.print(column.label,column.x,self.listY-14)
        g.printf(tostring(count),column.x,self.listY-14,column.width,"right")
        if count == 0 then
            g.setColor(c.mutedColor); g.printf("NONE",column.x,self.listY+8,column.width,"center")
        end
    end
    local hoveredCard = self:hoveredCard()
    local visible = self:visibleCards()
    local function drawEntry(entry)
        local card = entry.card
        local hovered = hoveredCard == card
        local statusHeight = entry.height-c.height
        g.push("all")
        g.intersectScissor(entry.x,self.listY,entry.width,self.bottom-16-self.listY)
        if statusHeight>0 then
            g.setColor(c.backgroundColor); g.rectangle("fill",entry.x,entry.y,entry.width,statusHeight)
            g.setColor(hovered and c.hoverColor or c.frameColor)
            g.rectangle("line",entry.x+0.5,entry.y+0.5,entry.width-1,statusHeight)
            local text
            if not state.inPlay[card.instanceId] then text="FACE-UP IN DECK"; g.setColor(c.hoverColor)
            else
                text=(card.health and "HP " .. card.health .. "  " or "")
                    .. (card.exhausted and "EXHAUSTED" or card.engagedAgentId and c.engagementLabel .. self:agentName(card.engagedAgentId) or "READY")
                g.setColor(c.engagementColor)
            end
            local maxWidth=entry.width-8
            while #text>0 and f.small:getWidth(text)>maxWidth do
                text=text:sub(1,utf8.offset(text,-1)-1)
                if f.small:getWidth(text .. "...")<=maxWidth then text=text .. "..."; break end
            end
            g.setFont(f.small); g.print(text,entry.x+4,entry.y+3)
        end
        Tile.draw(card,self.definitions[card.cardId],self.images[card.cardId],f.small,c,
            entry.x,entry.y+statusHeight,entry.width,hovered or self.attackingId==card.instanceId or (self:busy() and self.latest==card.instanceId))
        g.pop()
    end
    local raised
    for _,entry in ipairs(visible) do
        if entry.card==hoveredCard then raised=entry else drawEntry(entry) end
    end
    if raised then drawEntry(raised) end
    for _,column in ipairs(self:columns()) do
        local count,shown = #self:listedCards(column.kind),0
        for _,entry in ipairs(visible) do if entry.column == column.kind then shown = shown+1 end end
        local first = self[column.scrollKey] or 1
        if count > 0 and (first > 1 or shown < count) then
            g.setColor(c.mutedColor)
            g.printf("SCROLL " .. first .. "-" .. (first+shown-1) .. " / " .. count,
                column.x,self.bottom-10,column.width,"right")
        end
    end
    g.pop()
end
function Panel:release()
    for id, art in pairs(self.images) do if art then art:release() end; self.images[id] = nil end
    self:cancel()
end
return Panel
