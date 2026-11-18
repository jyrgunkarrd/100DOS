local Flight = {}
Flight.__index = Flight
function Flight.new(record, slot, target, portraits, settings, reduced, beforeValues)
    return setmetatable({ record = record, x = slot.x, y = slot.y, width = slot.width, height = slot.artHeight,
        target = target, portraits = portraits, settings = settings, reduced = reduced, elapsed = 0,
        beforeValues = beforeValues }, Flight)
end
function Flight:update(dt)
    self.elapsed = self.elapsed + math.max(0, dt)
    return self.elapsed >= self.settings.flightDuration + self.settings.arrivalHold
end
function Flight:values()
    if self.elapsed < self.settings.flightDuration then return self.beforeValues end
end
function Flight:draw()
    local c, g = self.settings, love.graphics
    local t = math.min(1, self.elapsed / c.flightDuration)
    local ease = 1 - (1 - t) ^ 3
    g.push("all")
    if t < 1 then
        local scale = self.reduced and 1 or 1 + (c.arrivalSize / math.max(self.width, self.height) - 1) * ease
        local x = self.reduced and self.x or self.x + (self.target.x - self.width * scale / 2 - self.x) * ease
        local y = self.reduced and self.y or self.y + (self.target.y - self.height * scale / 2 - self.y) * ease - math.sin(t * math.pi) * c.arcHeight
        g.translate(math.floor(x), math.floor(y)); g.scale(scale)
        self.portraits:draw(self.record.forceId, 0, 0, nil, { 1, 1, 1, 1 - t * t })
    end
    g.pop()
    if t >= 1 or self.reduced then
        g.push("all"); g.setLineWidth(3)
        local alpha = t < 1 and t or math.max(0, 1 - (self.elapsed - c.flightDuration) / c.arrivalHold)
        g.setColor(c.accent[1], c.accent[2], c.accent[3], alpha)
        g.polygon("line", self.target.vertices); g.pop()
    end
end
return Flight
