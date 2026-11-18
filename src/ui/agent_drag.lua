local Drag = {}
Drag.__index = Drag

function Drag.new(threshold)
    return setmetatable({ threshold = threshold }, Drag)
end

function Drag:press(hit, x, y)
    if self.pending or not hit then return end
    self.pending = { id = hit.id, startX = x, startY = y, offsetX = x - hit.x, offsetY = y - hit.y }
    self.x, self.y = x, y
end

function Drag:move(x, y)
    if x == nil or y == nil then self:cancel(); return end
    self.x, self.y = x, y
    local p = self.pending
    if p and (x - p.startX)^2 + (y - p.startY)^2 >= self.threshold^2 then self.active = true end
end

function Drag:release(x, y)
    self:move(x, y)
    local id = self.active and self.pending and self.pending.id
    self:cancel()
    return id
end

function Drag:cancel()
    self.pending, self.active, self.x, self.y = nil, false, nil, nil
end

function Drag:pose()
    if not self.active then return nil end
    return { id = self.pending.id,
        x = math.floor(self.x - self.pending.offsetX + 0.5),
        y = math.floor(self.y - self.pending.offsetY + 0.5) }
end

return Drag
