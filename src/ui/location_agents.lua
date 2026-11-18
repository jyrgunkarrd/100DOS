local Settings = require("data.agent_deployment_defaults")
local Status = require("src.sys.agent_status")
local TurnView = require("data.agent_turn_view")
local Animation = require("src.ui.animation")
local View = {}
View.__index = View

local function contains(rect, x, y, size)
    return x ~= nil and y ~= nil and x >= rect.x and x < rect.x + size
        and y >= rect.y and y < rect.y + size
end

function View.new(model, grid, roster)
    return setmetatable({ model = model, grid = grid, roster = roster, entries = {}, byId = {},
        rosterBrightness = {} }, View)
end

function View:update(dt, drag)
    local draggedId = drag.active and drag.pending and drag.pending.id
    local step = Settings.brightnessFadeDuration > 0
        and (1 - Settings.assignedBrightness) * math.max(0, dt) / Settings.brightnessFadeDuration or 1
    for _, entry in ipairs(self.roster.entries) do
        local assigned = self.model.placements[entry.id] ~= nil
        local target = assigned and entry.id ~= self.hovered and entry.id ~= draggedId
            and Settings.assignedBrightness or 1
        local current = self.rosterBrightness[entry.id] or 1
        if not assigned then current = 1
        elseif current < target then current = math.min(target, current + step)
        else current = math.max(target, current - step) end
        self.rosterBrightness[entry.id] = current
    end
end

function View:refresh()
    self.movement = nil
    self.entries, self.byId = {}, {}
    local size = Settings.portraitSize
    for _, cell in ipairs(self.grid.cells) do
        local ids = self.model:occupants(cell.id)
        local rows = Settings.rows[#ids]
        if rows then
            local height = #rows * size + (#rows - 1) * Settings.rowGap
            local top = math.floor(cell.y - height / 2 + 0.5)
            -- Fit the row horizontally at its center; vertical/corner overhang is intentional.
            local radius = (cell.vertices[1] - cell.x)
            local rowOffset = #rows == 1 and size / 2 or (size + Settings.rowGap) / 2
            local width = math.floor(2 * radius - 2 * rowOffset / math.sqrt(3) - 2 * Settings.horizontalInset)
            local index = 1
            for row, count in ipairs(rows) do
                local step = count == 1 and 0 or math.min(size, math.floor((width - size) / (count - 1)))
                assert(step >= 0, "Hex is too small for native-size agent portraits")
                local left = math.floor(cell.x - (size + (count - 1) * step) / 2 + 0.5)
                for column = 1, count do
                    local entry = { id = ids[index], cellId = cell.id,
                        x = left + (column - 1) * step, y = top + (row - 1) * (size + Settings.rowGap) }
                    self.entries[#self.entries + 1], self.byId[entry.id] = entry, entry
                    index = index + 1
                end
            end
        end
    end
end

-- Keep committed layout separate from presentation; rapid moves start at the
-- current visible position, including other portraits rearranging in a cluster.
function View:movementPose(entry)
    local movement = self.movement
    local start = movement and movement.starts[entry.id]
    if not start then return entry end
    local progress = Animation.easeOutQuad(Animation.progress(movement.elapsed, 0, movement.duration))
    return { id = entry.id, cellId = entry.cellId,
        x = math.floor(Animation.lerp(start.x, entry.x, progress) + 0.5),
        y = math.floor(Animation.lerp(start.y, entry.y, progress) + 0.5) }
end

function View:animateMovement(duration)
    local starts = {}
    for _, entry in ipairs(self.entries) do starts[entry.id] = self:movementPose(entry) end
    self:refresh()
    if duration > 0 then self.movement = { starts = starts, elapsed = 0, duration = duration } end
end

function View:updateMovement(dt)
    if not self.movement then return end
    self.movement.elapsed = self.movement.elapsed + math.max(0, dt)
    if self.movement.elapsed >= self.movement.duration then self.movement = nil end
end

function View:hit(x, y)
    local raised = self.hovered and self.byId[self.hovered]
    if raised and not self:isExhausted(raised.id) and contains(self:movementPose(raised), x, y, Settings.portraitSize) then return self:movementPose(raised) end
    local selected = self.selected and self.byId[self.selected]
    if selected and not self:isExhausted(selected.id) and contains(self:movementPose(selected), x, y, Settings.portraitSize) then return self:movementPose(selected) end
    for i = #self.entries, 1, -1 do
        local pose = self:movementPose(self.entries[i])
        if not self:isExhausted(pose.id) and contains(pose, x, y, Settings.portraitSize) then return pose end
    end
end

function View:isExhausted(id)
    return Status.isExhausted(self.status, id)
end

function View:hover(x, y)
    local rosterEntry = self.roster:hit(x, y)
    if rosterEntry and self:isExhausted(rosterEntry.id) then rosterEntry = nil end
    local hit = rosterEntry or self:hit(x, y)
    self.hovered = hit and hit.id or nil
    return hit
end

function View:clearHover()
    self.hovered = nil
end

function View:drawOrder()
    local entries = {}
    for _, entry in ipairs(self.entries) do
        if self:isExhausted(entry.id) then entries[#entries + 1] = entry end
    end
    for _, entry in ipairs(self.entries) do
        if not self:isExhausted(entry.id) and entry.id ~= self.hovered and entry.id ~= self.selected then
            entries[#entries + 1] = entry
        end
    end
    local selected = self.selected ~= self.hovered and self.byId[self.selected]
    if selected and not self:isExhausted(selected.id) then entries[#entries + 1] = selected end
    local raised = self.byId[self.hovered]
    if raised and not self:isExhausted(raised.id) then entries[#entries + 1] = raised end
    return entries
end

function View:draw(drag, options)
    options = options or {}
    local g = love.graphics
    local ghost = drag and drag:pose()
    g.push("all")
    g.intersectScissor(0, 0, self.grid.width, self.grid.height)
    local target = ghost and self.grid:hit(drag.x, drag.y)
    local targetId = target and self.model.eligible[target.id] and target.id
    local highlighted = targetId or (not ghost and self.hovered and self.model.placements[self.hovered])
    if highlighted then
        for _, cell in ipairs(self.grid.cells) do
            if cell.id == highlighted then
                g.setColor(Settings.highlight)
                g.setLineWidth(3)
                g.polygon("line", cell.vertices)
            end
        end
    end
    local function defeatedMarker(entry, size, showLabel)
        if not Status.isDefeated(self.status, entry.id) then return end
        local font = self.roster.font or love.graphics.getFont()
        if showLabel then g.setColor(0.08, 0, 0, 0.95); g.rectangle("fill", entry.x, entry.y + size - 12, size, 12) end
        g.setColor(TurnView.actionsSpent.color)
        g.line(entry.x + 3, entry.y + 3, entry.x + size - 3, entry.y + size - (showLabel and 15 or 3))
        g.line(entry.x + size - 3, entry.y + 3, entry.x + 3, entry.y + size - (showLabel and 15 or 3))
        if not showLabel then return end
        g.setFont(font)
        local scale = math.min(1, (size - 2) / font:getWidth(TurnView.defeatedLabel), 10 / font:getHeight())
        g.print(TurnView.defeatedLabel, entry.x + (size - font:getWidth(TurnView.defeatedLabel) * scale) / 2,
            entry.y + size - 11, 0, scale, scale)
    end
    local function drawEntry(entry)
        if options.hideMapPortraits then return end
        entry = self:movementPose(entry)
        local alpha = ghost and ghost.id == entry.id and 0.3 or 1
        local shadow = Settings.mapShadow
        g.setColor(0, 0, 0, shadow.opacity * alpha)
        g.rectangle("fill", entry.x + shadow.offsetX, entry.y + shadow.offsetY,
            Settings.portraitSize, Settings.portraitSize)
        local exhausted = self:isExhausted(entry.id)
        self.roster:drawPortrait(entry.id, entry.x, entry.y, alpha, exhausted and TurnView.exhaustedBrightness or 1)
        if exhausted then
            g.setColor(TurnView.badgeColor); g.rectangle("fill", entry.x + 2, entry.y + 2, 5, 5)
        end
        if not exhausted and options.selectionColor and (entry.id == self.selected or entry.id == self.hovered) then
            g.setColor(entry.id == self.selected and options.selectionColor or Settings.highlight)
            g.setLineWidth(1)
            g.rectangle("line", entry.x + 0.5, entry.y + 0.5, Settings.portraitSize - 1, Settings.portraitSize - 1)
        end
        defeatedMarker(entry, Settings.portraitSize)
    end
    for _, entry in ipairs(self:drawOrder()) do drawEntry(entry) end
    -- Stable roster slots remain the accessible source for every agent.
    for _, entry in ipairs(options.rosterIndicators == false and {} or self.roster.entries) do
        if self:isExhausted(entry.id) then
            g.setColor(TurnView.badgeColor); g.rectangle("fill", entry.x + 2, entry.y + 2, 5, 5)
        elseif options.deploymentIndicators ~= false and self.model.placements[entry.id] then
            g.setColor(Settings.assignedColor[1], Settings.assignedColor[2], Settings.assignedColor[3],
                options.indicatorAlpha or 1)
            g.rectangle("fill", entry.x + 2, entry.y + 2, 5, 5)
        end
        if not self:isExhausted(entry.id) and (entry.id == self.hovered or entry.id == self.selected) then
            g.setColor(entry.id == self.selected and options.selectionColor or Settings.highlight)
            g.setLineWidth(1)
            g.rectangle("line", entry.x + 0.5, entry.y + 0.5, self.roster.size - 1, self.roster.size - 1)
        end
    end
    for _, entry in ipairs(self.roster.entries) do
        if options.rosterIndicators ~= false then defeatedMarker(entry, self.roster.size, true) end
    end
    if ghost and self.roster:contains(drag.x, drag.y) then
        g.setColor(Settings.highlight)
        g.setLineWidth(1)
        g.rectangle("line", self.roster.x - 2.5, self.roster.y - 2.5,
            self.roster.width + 5, self.roster.height + 5)
    end
    g.pop()
end

return View
