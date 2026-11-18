local C = require("data.silencer_view").tooltip
local Hover = {}; Hover.__index = Hover
function Hover.new(view)
    local self = setmetatable({ view = view, masks = {}, tiles = {},
        definitions = require("data.fate_tiles.index").refresh().byId }, Hover)
    for id, definition in pairs(view.state.catalogue.transports) do
        if view.images[id] then
            local ok, pixels = pcall(love.image.newImageData, "assets/images/silencers/" .. id .. ".png")
            if ok then self.masks[id] = pixels end
        end
        for _, tileId in ipairs(definition.ongoing_fate or {}) do
            if self.definitions[tileId].img then
                self.tiles[tileId] = view.assets:load("assets/images/fate/" .. tileId .. ".png")
            end
        end
    end
    return self
end
function Hover:clear() self.x, self.y, self.target = nil, nil, nil end
function Hover:hit(x, y)
    local poses, width, height = self.view:poses()
    if not x or not y or x < 0 or y < 0 or x >= width or y >= height then return end
    for i = #poses, 1, -1 do
        local p = poses[i]
        local px, py = math.floor(x - p.x), math.floor(y - p.y)
        if p.visible and px >= 0 and py >= 0 and px < p.width and py < p.height then
            local mask = self.masks[p.transport.id]
            if mask then
                local _, _, _, alpha = mask:getPixel(px, py)
                if alpha > C.alphaThreshold then return p.transport end
            else return p.transport end
        end
    end
end
function Hover:pointer(x, y)
    self.x, self.y = x, y
    self.target = self:hit(x, y)
    return self.target ~= nil
end
function Hover:rows(transport)
    local rows, byId = {}, {}
    for _, id in ipairs(self.view.state.catalogue.transports[transport.id].ongoing_fate or {}) do
        if not byId[id] then
            local tile = self.definitions[id]
            byId[id] = { id = id, name = tile.name or tostring(require("src.sys.fate_tile_definition").modifier(tile)), count = 0 }
            rows[#rows + 1] = byId[id]
        end
        byId[id].count = byId[id].count + 1
    end
    return rows
end
function Hover:draw(width, height)
    self.target = self:hit(self.x, self.y)
    if not self.target then return end
    local g, font = love.graphics, self.view.feedbackFont
    local name = self.view.state.catalogue.transports[self.target.id].name:upper()
    local rows, rowHeight = self:rows(self.target), math.max(C.tileSize, font:getHeight())
    local w = font:getWidth(name)
    for _, row in ipairs(rows) do
        row.text = row.name .. (row.count > 1 and " x" .. row.count or "")
        w = math.max(w, C.tileSize + C.gap + font:getWidth(row.text))
    end
    w = math.min(width - C.margin * 2, w + C.padding * 2)
    local h = C.padding * 2 + font:getHeight() + #rows * (rowHeight + C.gap)
    local x = math.max(C.margin, math.min(width - w - C.margin, self.x + C.pointerGap))
    local y = self.y - h - C.pointerGap
    if y < C.margin then y = self.y + C.pointerGap end
    y = math.max(C.margin, math.min(height - h - C.margin, y))
    x, y = math.floor(x), math.floor(y)
    g.push("all"); g.setFont(font); g.setLineWidth(1)
    g.setColor(C.background); g.rectangle("fill", x, y, w, h)
    g.setColor(C.border); g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    g.setColor(C.text); g.print(name, x + C.padding, y + C.padding)
    for i, row in ipairs(rows) do
        local top = y + C.padding + font:getHeight() + C.gap + (i - 1) * (rowHeight + C.gap)
        local image = self.tiles[row.id]
        if image then
            local scale = math.min(1, C.tileSize / image:getWidth(), C.tileSize / image:getHeight())
            g.draw(image, x + C.padding, top, 0, scale, scale)
        else
            g.printf(tostring(require("src.sys.fate_tile_definition").modifier(self.definitions[row.id])),
                x + C.padding, top + math.floor((rowHeight - font:getHeight()) / 2), C.tileSize, "center")
        end
        g.print(row.text, x + C.padding + C.tileSize + C.gap, top + math.floor((rowHeight - font:getHeight()) / 2))
    end
    g.pop()
end
local function inside(x, y, rect)
    return x and y and rect and rect.x and rect.width and x >= rect.x and x < rect.x + rect.width
        and y >= rect.y and y < rect.y + rect.height
end
function Hover.drawFor(host)
    local s = host.session
    local view = s.scene.silencerView
    if not view or not view.hover then return end
    local hover = view.hover
    if host.fatePoolInspection or host.agentInspectionPanel or host.battlefieldInspectionCell
        or (host.testPanel and host.testPanel.card) or (host.maneuver and host.maneuver.open)
        or (host.drag and (host.drag.card or host.drag.pending)) or (host.resolving and host:resolving())
        or s.phaseFeedback or s.missionOutcome or s.attackFeedback or s.talentFeedback
        or (s.missionFooter.routing and (s.missionFooter.routing.drag.pending or s.missionFooter.routing.receipt))
        or (host.actions and host.actions.open and inside(hover.x, hover.y, host.actions)) then
        hover:clear(); return
    end
    hover:draw(host.width, host.height)
end
function Hover:release()
    self:clear()
    for _, pixels in pairs(self.masks) do pixels:release() end
    self.masks, self.tiles = {}, {}
end
return Hover
