local Model = require("src.sys.battlefield_maneuver")
local Panel = {}
Panel.__index = Panel
local function inside(x, y, b) return x and y and x >= b.x and x < b.x + b.width and y >= b.y and y < b.y + b.height end
function Panel.new(session, agentId)
    local c = require("data.battlefield_maneuver_view")
    local Pulse = require("src.ui.outline_pulse")
    Pulse.validate(c.previewPulse); Pulse.validate(c.reservePulse)
    for _, value in ipairs({ c.previewSize, c.previewRingSize, c.reserveBadge.size, c.reserveBadge.bottomInset,
        c.reserveBadge.padding, c.reserveBadge.lineWidth, c.reservePulse.spread, c.reserveOutlineWidth, c.reserveTargetInset }) do
        assert(type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0, "Invalid maneuver marker size")
    end
    assert(c.previewRingSize >= c.previewSize, "Maneuver pulse must expand")
    assert(type(c.reserveBadge.textOffsetY) == "number" and math.abs(c.reserveBadge.textOffsetY) < math.huge,
        "Invalid reserve badge text offset")
    for _, key in ipairs({ "width", "height", "gap", "scrollStep", "flightDuration", "arrivalHold" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid maneuver " .. key)
    end
    return setmetatable({ session = session, agentId = agentId, settings = c,
        portraits = require("src.ui.force_portraits").new(session), scroll = 0 }, Panel)
end
function Panel:start()
    local pending = self.session.pendingManeuver
    if not Model.valid(self.session, pending) then Model.decline(self.session, pending); return false end
    self.pending, self.open, self.age = pending, true, 0
    self.mode, self.scroll, self.unitId, self.error, self.pressed = "local", 0, nil, nil, nil
    self.reducedMotion = require("data.attack_cutin_view").reducedMotion
    if #self.session.armies.byCell[pending.cell].allied.forces == 0 then self.mode = "reserve" end
    self:layout(); return true
end
function Panel:close() self.open, self.pressed, self.flight, self.hovered = false, nil, nil, nil end
function Panel:cancelSelection()
    if not self.flight then self.unitId, self.pressed = nil, nil end
end
function Panel:source() return self.mode == "reserve" and self.session.armies.jaclCellId or self.pending.cell end
function Panel:layout()
    local c, offset = self.settings, 0
    self.slots = {}
    local units = self.session.armies.byCell[self:source()].allied.forces
    for _, unit in ipairs(units) do
        local w, h = self.portraits:dimensions(unit.forceId)
        self.slots[#self.slots + 1] = { unit = unit, offset = offset, width = w, artHeight = h, height = h + c.captionHeight }
        offset = offset + w + c.gap
    end
    self.scrollMax = math.max(0, offset - c.gap - (c.width - 2 * c.padding))
    self.scroll = math.max(0, math.min(self.scroll, self.scrollMax))
    for _, slot in ipairs(self.slots) do slot.x, slot.y = c.x + c.padding + slot.offset - self.scroll, c.y + c.portraitsTop end
end
function Panel:selectedSlot()
    for _, slot in ipairs(self.slots) do if slot.unit.id == self.unitId then return slot end end
end
function Panel:buttons()
    local c = self.settings
    return {
        { id = "decline", text = c.labels.decline, x = c.x + c.width - 160, y = c.y + 10, width = 148, height = 22 },
        { id = "previous", text = "<", x = c.x + c.width - 64, y = c.y + c.height - 24, width = 22, height = 18 },
        { id = "next", text = ">", x = c.x + c.width - 34, y = c.y + c.height - 24, width = 22, height = 18 },
    }
end
function Panel:hit(x, y)
    if self.flight then return end
    local c = self.settings
    for _, b in ipairs(self:buttons()) do if inside(x, y, b) then return b.id end end
    if inside(x, y, c) then
        if x >= c.x + c.padding and x < c.x + c.width - c.padding then
            for _, slot in ipairs(self.slots) do if inside(x, y, slot) then return "unit:" .. slot.unit.id end end
        end
        return
    end
    if x and y then
        local cell = self.session.grid:hit(x, y)
        if cell and self.session.assignments[cell.id] then return "cell:" .. cell.id end
    end
end
function Panel:pointer(x, y) self.pointerX, self.pointerY, self.hovered = x, y, self.open and self:hit(x, y) or nil end
function Panel:press(x, y) self.pressed = self:hit(x, y) end
function Panel:transfer(destination)
    local slot = self:selectedSlot()
    if not slot then return end
    local target
    for _, cell in ipairs(self.session.grid.cells) do if cell.id == destination then target = cell end end
    if not target then return end
    local values = {}
    for _, cell in ipairs({ self:source(), destination }) do values[cell] = self.session.armies.byCell[cell].allied.value end
    local ok, result = Model.commit(self.session, self.pending, self:source(), destination, self.unitId)
    if not ok then self.error = result; return end
    self.flight = require("src.ui.force_transfer_feedback").new(result, slot, target, self.portraits, self.settings, self.reducedMotion, values)
    if self.session.audio then self.session.audio:playOverlapping("agentMove") end
    self.pressed, self.hovered = nil, nil
end
function Panel:releasePointer(x, y)
    local id, pressed = self:hit(x, y), self.pressed
    self.pressed = nil
    if not id or id ~= pressed then return end
    if id == "decline" then Model.decline(self.session, self.pending); self:close()
    elseif id == "previous" or id == "next" then self:scrollBy(id == "previous" and 1 or -1)
    elseif id:sub(1, 5) == "unit:" then
        self.unitId, self.error = id:sub(6), nil
        if self.session.audio then self.session.audio:play("selection") end
        if self.mode == "reserve" then self:transfer(self.pending.cell) end
    elseif id:sub(1, 5) == "cell:" then
        local cell = id:sub(6)
        if self.unitId then self:transfer(cell)
        elseif cell == self.pending.cell then self.mode, self.scroll, self.error = "local", 0, nil; self:layout()
        elseif cell == self.session.armies.jaclCellId and #self.session.armies.byCell[cell].allied.forces > 0 then
            self.mode, self.scroll, self.error = "reserve", 0, nil; self:layout()
        end
    end
end
function Panel:scrollBy(delta)
    if self.flight then return end
    self.scroll = self.scroll - delta * self.settings.scrollStep; self.pressed = nil; self:layout()
    self.hovered = self:hit(self.pointerX, self.pointerY)
end
function Panel:wheel(delta)
    if inside(self.pointerX, self.pointerY, self.settings) then self:scrollBy(delta) end
end
function Panel:update(dt)
    if not self.open then return end
    self.age = self.age + math.max(0, dt)
    if self.flight then if self.flight:update(dt) then self:close() end
    elseif not Model.valid(self.session, self.pending) then
        Model.decline(self.session, self.pending); self:close()
    end
end
function Panel:draw(font)
    if not self.open then return end
    local c, g, s = self.settings, love.graphics, self.session
    require("src.ui.battlefield_maneuver_overlay").draw(self, font)
    g.push("all"); g.setFont(font)
    g.setColor(c.background); g.rectangle("fill", c.x, c.y, c.width, c.height)
    g.setColor(c.accent); g.rectangle("line", c.x, c.y, c.width, c.height)
    local name = s.locations.byId[s.assignments[self.pending.cell]].name
    g.setColor(c.text); g.print(self.mode == "reserve" and c.labels.reserves or c.labels.localForces .. name, c.x + c.padding, c.y + 13)
    local hint = self.mode == "reserve" and c.labels.reinforce .. name .. "." or c.labels.choose
    if #self.slots == 0 then hint = c.labels.empty end
    local hover = self.hovered and self.hovered:match("^cell:(.+)$")
    if hover then
        if self.unitId then
            for _, target in ipairs(Model.targets(s, self.pending, self:source())) do
                if target == hover then hint = "Move selected Force to " .. s.locations.byId[s.assignments[hover]].name .. "." end
            end
        elseif hover == s.armies.jaclCellId then hint = "Click JACL to view reinforcements."
        elseif hover == self.pending.cell then hint = "Click to view local Forces." end
    end
    g.print(self.flight and c.labels.moving or self.error or hint, c.x + c.padding, c.y + 36)
    g.setColor(c.muted); g.print(c.labels.clear .. "  " .. c.labels.spent, c.x + c.padding, c.y + 49)
    g.push("all")
    local x1, y1 = g.transformPoint(c.x + c.padding, c.y + c.portraitsTop - 2)
    local x2, y2 = g.transformPoint(c.x + c.width - c.padding, c.y + c.height - 27)
    g.intersectScissor(x1, y1, x2 - x1, y2 - y1)
    for _, slot in ipairs(self.slots) do
        if not self.flight or slot.unit.id ~= self.flight.record.unitId then
            self.portraits:draw(slot.unit.forceId, slot.x, slot.y)
            local selected = self.unitId == slot.unit.id
            g.setColor(selected and c.accent or c.muted); g.setLineWidth(selected and 3 or 1)
            g.rectangle("line", slot.x, slot.y, slot.width, slot.artHeight)
            local definition = s.armies.catalogue.byId[slot.unit.forceId]
            g.setColor(c.text); g.printf(definition.name, slot.x, slot.y + slot.artHeight + 5, slot.width, "center")
            if definition.strength == "elite" then
                g.setColor(c.background); g.rectangle("fill", slot.x + 1, slot.y + 1, 42, 14)
                g.setColor(c.reserve); g.print("ELITE", slot.x + 4, slot.y + 3)
            end
        end
    end
    g.pop()
    if self.scrollMax > 0 then
        local track = c.width - 110
        local thumb = math.max(24, track * (c.width - 2 * c.padding) / (c.width - 2 * c.padding + self.scrollMax))
        g.setColor(c.muted); g.rectangle("fill", c.x + c.padding, c.y + c.height - 15, track, 2)
        g.setColor(c.accent); g.rectangle("fill", c.x + c.padding + (track - thumb) * self.scroll / self.scrollMax, c.y + c.height - 18, thumb, 6)
    end
    if not self.flight then
        for _, b in ipairs(self:buttons()) do
            g.setColor(c.accent); g.rectangle("line", b.x, b.y, b.width, b.height)
            g.setColor(c.text); g.printf(b.text, b.x, b.y + 5, b.width, "center")
        end
    end
    g.pop()
    if self.flight then self.flight:draw() end
end
function Panel:release() self:close(); self.portraits:release() end
return Panel
