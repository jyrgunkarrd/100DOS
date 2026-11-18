local Tabs = require("data.agent_action_tabs")
local Basic = require("src.sys.agent_basic_actions")
local Panel = {}
Panel.__index = Panel
local function inside(x, y, r)
    return x and y and x >= r.x and y >= r.y and x < r.x + r.width and y < r.y + r.height
end
function Panel.new(settings, equipment, fonts, audio)
    for _, key in ipairs({ "width", "padding", "rowHeight", "gap", "buttonWidth", "buttonHeight", "topGap", "headerHeight", "footerHeight", "tabWidth", "tabHeight", "tabGap", "tabTop" }) do
        local n = settings[key]
        assert(type(n) == "number" and n > 0 and n < math.huge and n % 1 == 0, "Invalid action panel " .. key)
    end
    for _, key in ipairs({ "backgroundColor", "frameColor", "textColor", "mutedColor", "hoverColor", "targetColor" }) do
        for i = 1, 4 do
            local n = settings[key] and settings[key][i]
            assert(type(n) == "number" and n >= 0 and n <= 1, "Invalid action panel color")
        end
    end
    for _, key in ipairs({ "open", "close", "ap", "move", "cancel", "ready" }) do
        assert(type(settings.labels[key]) == "string", "Missing action panel label")
    end
    local definitions = Basic.definitions()
    local right = equipment.x + equipment.width
    local button = { x = right - settings.buttonWidth, y = equipment.y + equipment.height + settings.topGap,
        width = settings.buttonWidth, height = settings.buttonHeight }
    local self = setmetatable({ settings = settings, fonts = fonts, definitions = definitions, button = button,
        x = right - settings.width, y = button.y + button.height + settings.gap, width = settings.width,
        height = settings.padding * 2 + settings.headerHeight + #definitions * (settings.rowHeight + settings.gap) + settings.footerHeight,
        rows = {}, audio = audio }, Panel)
    self.y = math.min(self.y,(fonts.height or 720)-settings.padding-self.height)
    self:setTab(Tabs.default)
    return self
end
function Panel:setOpen(open)
    local changed = (self.open == true) ~= open
    self.open = open
    if changed and self.audio then self.audio:play("selection") end
end
function Panel:setTab(id)
    assert(Tabs.labels[id], "Unknown action tab")
    self.selectedTab, self.battlefield, self.targeting, self.error, self.pressed = id, id == "battlefield", false, nil, nil
    self.definitions = {}
    if id == "agent" then self.definitions = Basic.definitions()
    elseif id == "location" then
        local rules = require("data.location_actions")
        for _,kind in ipairs(rules.order) do
            local d = rules.actions[kind]
            self.definitions[#self.definitions+1] = { id = kind, label = d and d.label or "EXPLORE",
                actionPointCost = d and d.actionPointCost or require("data.location_exploration_rules").actionPointCost }
        end
    elseif self.jacl then
        local rules = require("data.jacl_actions")
        for _,kind in ipairs(rules.order) do
            local d = rules.actions[kind]
            self.definitions[#self.definitions+1] = {id=kind,label=d.label,actionPointCost=d.actionPointCost}
        end
    else
        for _,kind in ipairs(Tabs.battlefieldOrder) do
            self.definitions[#self.definitions+1] = {id=kind,label=kind:upper(),actionPointCost=require("data.battlefield_rules").actionPointCost}
        end
    end
    self.rows = {}
    local c = self.settings
    for i,d in ipairs(self.definitions) do
        self.rows[i] = { id=d.id,x=self.x+c.padding,y=self.y+c.padding+c.headerHeight+(i-1)*(c.rowHeight+c.gap),
            width=self.width-2*c.padding,height=c.rowHeight }
    end
end
function Panel:setBattlefield(enabled) self:setTab(enabled and "battlefield" or "agent") end
function Panel:context(session, id)
    local jacl = session.armies and session.agentDeployment.placements[id] == session.armies.jaclCellId or false
    if self.jacl ~= jacl then self.jacl = jacl; self:setTab(self.selectedTab) end
end
function Panel:evaluate(session, id, kind)
    if self.selectedTab == "location" then
        if kind == "explore" then return require("src.sys.location_exploration").evaluate(session,id,require("data.location_exploration_rules")) end
        return require("src.sys.location_actions").available(session,id,kind)
    end
    if self.battlefield then return require("src.sys.battlefield_action").available(session, id, kind) end
    return Basic.evaluate(session, id, kind)
end
function Panel:tab(id)
    id = id or "battlefield"
    local c = self.settings
    for i,kind in ipairs(Tabs.order) do
        if kind == id then return { id=kind,x=self.x+self.width-c.padding-c.tabWidth,
            y=self.y+c.padding+c.tabTop+(i-1)*(c.tabHeight+c.tabGap),width=c.tabWidth,height=c.tabHeight } end
    end
end
function Panel:close()
    self:setOpen(false)
    self.targeting, self.pressed, self.error = false, nil, nil
end
function Panel:toggle() if self.open then self:close() else self:setOpen(true) end end
function Panel:pointer(x, y) self.pointerX, self.pointerY = x, y end
function Panel:hit(x, y, session, id)
    self:context(session, id)
    if inside(x, y, self.button) then return "toggle" end
    if self.open then
        for _,kind in ipairs(Tabs.order) do if inside(x,y,self:tab(kind)) then return "tab:" .. kind end end
        for _, r in ipairs(self.rows) do if inside(x, y, r) then return r.id end end
        if inside(x, y, self) then return "panel" end
        if self.targeting then
            local cell = session.grid:hit(x, y)
            return cell and "cell:" .. cell.id or "invalid"
        end
        return "outside"
    end
    local entry = session.agentView:hit(x, y)
    if entry and entry.id == id then return "toggle" end
end
function Panel:press(x, y, session, id)
    self.pressed = self:hit(x, y, session, id)
    return self.pressed ~= nil
end
function Panel:releasePointer(x, y, session, id)
    local pressed = self.pressed; self.pressed = nil
    if not pressed then return false end
    if pressed ~= self:hit(x, y, session, id) then return true end
    self.error = nil
    if pressed == "toggle" then self:toggle()
    elseif pressed:sub(1,4) == "tab:" then
        local id = pressed:sub(5)
        if id ~= self.selectedTab then
            self:setTab(id)
            if self.audio then self.audio:play("cardView") end
        end
    elseif self.selectedTab == "location" and (pressed == "explore" or pressed == "charm" or pressed == "ingenuity") then
        local result = self:evaluate(session,id,pressed)
        if result.valid then return true, "location", { locationKind = pressed } end
        self.error = result.reason
    elseif self.battlefield and pressed == "bombard" then
        local result = self:evaluate(session, id, pressed)
        if result.valid then self.targeting = not self.targeting else self.error = result.reason end
    elseif self.battlefield and (pressed == "engage" or pressed == "entrench" or pressed == "maneuver" or pressed == "security" or pressed == "triangulate") then
        local result = self:evaluate(session, id, pressed)
        if result.valid then return true, "battlefield", { battlefieldKind = pressed } end
        self.error = result.reason
    elseif pressed == "outside" then self:close()
    elseif pressed:sub(1, 5) == "cell:" then
        if self.battlefield and self.jacl then
            local cell = pressed:sub(6)
            for _, target in ipairs(require("src.sys.jacl_actions").targets(session)) do
                if target == cell then return true, "battlefield", { battlefieldKind = "bombard", targetCell = cell } end
            end
            self.error = "Choose a highlighted enemy army"
        else return true, "move", { cellId = pressed:sub(6) } end
    elseif pressed == "move" then
        local result = Basic.evaluate(session, id, "move")
        if result.valid then self.targeting = not self.targeting else self.error = result.reason end
    elseif pressed == "draw_card" or pressed == "gain_resource" then
        return true, pressed, {}
    end
    return true
end
function Panel:drawTargets(session, id, outlineOnly)
    if not self.targeting then return end
    local result = self.battlefield and self.jacl and require("src.sys.jacl_actions").available(session, id, "bombard") or Basic.evaluate(session, id, "move")
    if not result.valid then return end
    local targets = {}; for _, cell in ipairs(result.targets) do targets[cell] = true end
    local g, c = love.graphics, self.settings
    g.push("all"); g.setLineWidth(3); g.setLineStyle("rough")
    for _, cell in ipairs(session.grid.cells) do
        if targets[cell.id] then
            if not outlineOnly then g.setColor(c.targetColor); g.polygon("fill", cell.vertices) end
            g.setColor(c.hoverColor); g.polygon("line", cell.vertices)
        end
    end
    g.pop()
end
function Panel:draw(session, id, name, enabled)
    self:context(session, id)
    local g, c, b = love.graphics, self.settings, self.button
    g.push("all"); g.setFont(self.fonts.small); g.setLineWidth(1); g.setLineStyle("rough")
    local function box(r, color)
        g.setColor(c.backgroundColor); g.rectangle("fill", r.x, r.y, r.width, r.height)
        g.setColor(color); g.rectangle("line", r.x + 0.5, r.y + 0.5, r.width - 1, r.height - 1)
    end
    box(b, enabled and inside(self.pointerX, self.pointerY, b) and c.hoverColor or c.frameColor)
    g.setColor(enabled and c.textColor or c.mutedColor)
    g.printf((self.open and c.labels.close or c.labels.open):upper(), b.x, b.y + 9, b.width, "center")
    if self.open then
        box(self, c.frameColor)
        g.setFont(self.fonts.heading)
        g.setColor(c.textColor); g.printf(name:gsub("%s+", " "):upper(), self.x + c.padding, self.y + c.padding, self.width - 2 * c.padding)
        g.setFont(self.fonts.small)
        g.setColor(c.hoverColor)
        g.print(session.agentStatus.byAgent[id].actionPoints .. c.labels.ap:upper(), self.x + c.padding, self.y + c.padding + 18)
        for _,kind in ipairs(Tabs.order) do
            local tab = self:tab(kind)
            box(tab,self.selectedTab == kind and c.hoverColor or c.frameColor)
            if self.selectedTab == kind then
                g.setColor(c.hoverColor[1],c.hoverColor[2],c.hoverColor[3],0.15)
                g.rectangle("fill",tab.x+1,tab.y+1,tab.width-2,tab.height-2)
            end
            g.setColor(c.textColor)
            g.printf(Tabs.labels[kind == "battlefield" and self.jacl and "jacl" or kind],tab.x,tab.y+5,tab.width,"center")
        end
        for i, row in ipairs(self.rows) do
            local d = self.definitions[i]
            local result = self:evaluate(session, id, d.id)
            local available = enabled and result.valid
            box(row, available and inside(self.pointerX, self.pointerY, row) and c.hoverColor or c.frameColor)
            g.setColor(available and c.textColor or c.mutedColor)
            g.setFont(self.fonts.heading)
            g.print(d.label:upper(), row.x + 8, row.y + 8)
            g.setFont(self.fonts.small)
            g.printf(d.actionPointCost .. " >", row.x + 8, row.y + 8, row.width - 16, "right")
            g.setColor(c.mutedColor)
            g.print((not result.valid and result.reason or (d.id == "move" and self.targeting and "Select a highlighted location" or "")):upper(), row.x + 8, row.y + 28)
        end
        g.setColor(c.textColor)
        g.printf((self.error or (self.targeting and (self.jacl and self.battlefield and "SELECT AN ENEMY ARMY" or c.labels.move) or c.labels.ready)):upper(), self.x + c.padding,
            self.y + self.height - c.footerHeight - c.padding, self.width - c.padding * 2)
        g.setColor(c.mutedColor)
        g.print(c.labels.cancel:upper(), self.x + c.padding, self.y + self.height - c.padding - 8)
    end
    g.pop()
end
return Panel
