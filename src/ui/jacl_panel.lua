local C = require("data.jacl_action_view")
local Panel = {}; Panel.__index = Panel
function Panel.new()
    return setmetatable({ assets = require("src.sys.artwork_assets").new() }, Panel)
end
function Panel:markers(s)
    local result = {}
    if not s.locationDecks or not s.locationDecks.revealedTop then return result end
    for _, cell in ipairs(s.grid and s.grid.cells or {}) do
        local card = s.locationDecks:revealedTop(cell.id)
        if card then result[#result + 1] = { card = card, cell = cell.id,
            x = math.floor(cell.x - C.markerWidth / 2), y = math.floor(cell.y + C.markerOffsetY),
            width = C.markerWidth, height = C.markerHeight } end
    end
    return result
end
function Panel:draw(s)
    if not s.scene then return end
    local g = love.graphics
    g.push("all"); g.setFont(s.scene.accents.small)
    if s.agentStatus and s.scene.jaclPreview then
        local jacl, icon = s.scene.jaclPreview, self.assets:load(C.icon)
        local iw, ih = icon and icon:getWidth() or 24, icon and icon:getHeight() or 24
        local w, h = math.max(C.panelWidth, iw + 48 + C.padding * 2), ih + C.padding * 2
        local x, y = math.floor(jacl.targetX - jacl.width / 2 - w - C.panelGap), math.floor(jacl.y - jacl.height / 2 - h / 2)
        y = math.min(y, jacl.canvasHeight - h - C.panelGap)
        g.setColor(C.background); g.rectangle("fill", x, y, w, h)
        local value = s.jaclSecurity or 0
        if self.value ~= value then self.changedAt = love.timer.getTime(); self.value = value end
        local pulse = math.max(0, 1 - (love.timer.getTime() - self.changedAt) / 0.4)
        g.setColor(C.accent[1], C.accent[2], C.accent[3], 0.5 + pulse * 0.5)
        g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        g.setColor(C.text)
        if icon then g.draw(icon, x + C.padding, y + C.padding) else g.print("SEC", x + C.padding, y + C.padding) end
        g.print(value .. " / " .. require("data.jacl_actions").securityCap,
            x + C.padding + iw + 8, math.floor(y + (h - g.getFont():getHeight()) / 2))
    end
    if not s.huntPresentation then
        for _, b in ipairs(self:markers(s)) do
            g.setColor(C.background); g.rectangle("fill", b.x, b.y, b.width, b.height)
            g.setColor(C.accent); g.rectangle("line", b.x, b.y, b.width, b.height)
            g.printf("REVEALED TOP", b.x, b.y + 4, b.width, "center")
        end
    end
    g.pop()
end
function Panel:clearHover() self.hover = nil; if self.preview then self.preview:clear() end end
function Panel:pointer(s, x, y)
    if not x or not y or s.huntPresentation or s.talentFeedback or s.attackFeedback then self:clearHover(); return false end
    for _, b in ipairs(self:markers(s)) do
        if x >= b.x and x < b.x + b.width and y >= b.y and y < b.y + b.height then
            if not self.preview then
                local cards = {}
                for _, id in ipairs(s.locationDecks.pool.ids) do cards[#cards + 1] = { cardId = id } end
                local view = require("src.ui.card_preview").new(s.locationDecks.pool, cards,
                    require("data.location_card_preview_view"), s.scene.accents, s.grid, s.scene.accents.height,
                    require("src.sys.location_card_display").normalize, s.scene.biome.id)
                self.preview = require("src.ui.card_preview_controller").new(nil, view, s.audio)
            end
            self.hover = b; self.preview:show("location", b.card); return true
        end
    end
    self:clearHover(); return false
end
function Panel:drawPreview(s)
    local b = self.hover
    if not b or s.locationDecks:revealedTop(b.cell) ~= b.card then self:clearHover(); return end
    local view = self.preview.views.location
    local bounds = view.instanceLayout or view.layouts[b.card.cardId]
    local p = require("src.ui.preview_placement").choose(s.scene.accents.width, s.scene.accents.height,
        { width = view.settings.width, height = bounds.height, y = view.settings.top }, b,
        s.grid.bounds.x + s.grid.bounds.width / 2, {}, 16, 8)
    if p then view.x, view.y = p.x, p.y; self.preview:draw() end
end
function Panel.drawScan(s, record, age, font, reduced)
    local g = love.graphics
    local progress = math.min(1, math.max(0, age / C.scanDuration))
    g.push("all"); g.setFont(font)
    for _, entry in ipairs(record.scan or {}) do
        for _, cell in ipairs(s.grid and s.grid.cells or {}) do
            if cell.id == entry.cell then
                g.setColor(C.accent[1], C.accent[2], C.accent[3], 0.25 * (1 - progress))
                g.polygon("fill", cell.vertices)
                if not reduced then
                    g.setColor(C.accent); g.rectangle("fill", cell.x - 35, cell.y - 30 + 60 * progress, 70, 2)
                end
                local label = entry.card and "REVEALED" or entry.empty and "EMPTY" or "SHUFFLED"
                g.setColor(C.background); g.rectangle("fill", cell.x - 46, cell.y - 8, 92, 16)
                g.setColor(C.text); g.printf(label, cell.x - 46, cell.y - 5, 92, "center")
            end
        end
    end
    g.pop()
end
function Panel:release()
    if self.preview then self.preview:release() end
    self.assets:release()
end
return Panel
