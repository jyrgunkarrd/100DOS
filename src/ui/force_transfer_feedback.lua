local Pulse = require("src.ui.outline_pulse")
local Flight = {}
Flight.__index = Flight

function Flight.new(record, slot, target, portraits, settings, reduced, beforeValues)
    if record.hit then
        beforeValues[record.toCell] = { allied = beforeValues[record.toCell], enemy = record.hit.armiesBefore.enemy.value }
    end
    return setmetatable({
        record = record, x = slot.x, y = slot.y,
        endX = target.x - slot.width / 2, endY = target.y - slot.artHeight / 2,
        target = target, portraits = portraits, settings = settings, reduced = reduced,
        duration = reduced and 0 or settings.flightDuration, elapsed = 0, beforeValues = beforeValues,
    }, Flight)
end

function Flight:update(dt)
    self.elapsed = self.elapsed + math.max(0, dt)
    return self.elapsed >= self.duration + self.settings.arrivalHold
end

function Flight:values()
    if self.elapsed < self.duration then return self.beforeValues end
end

function Flight:label()
    local hit = self.record.hit
    if hit and self.elapsed >= self.duration then
        return self.settings.labels.hit:format(hit.sourceName:upper(), hit.targetName:upper())
    end
    return self.settings.labels.moving
end

function Flight:draw()
    local c, g = self.settings, love.graphics
    g.push("all")
    if self.elapsed < self.duration then
        local t = self.elapsed / self.duration
        local x = self.x + (self.endX - self.x) * t
        local y = self.y + (self.endY - self.y) * t
        local image = self.portraits:entry(self.record.forceId).image
        if image then
            g.setColor(1, 1, 1, 1)
            g.draw(image, math.floor(x), math.floor(y))
        end
    elseif self.elapsed < self.duration + c.arrivalHold then
        local progress = math.min(1, (self.elapsed - self.duration) / c.arrivalHold)
        local alpha = self.reduced and 1 or 1 - progress
        if not self.reduced then
            local image = self.portraits:entry(self.record.forceId).image
            if image and progress < 1 then
                local w, h = image:getDimensions()
                local scale = (1 - progress) ^ 2
                g.setColor(1, 1, 1, 1)
                g.draw(image, self.target.x, self.target.y, 0, scale, scale, w / 2, h / 2)
            end
            Pulse.hex(self.target, c.arrivalPulse.spread, { progress = progress, alpha = alpha }, c.arrivalPulse, c.accent)
        end
        g.setLineWidth(3)
        g.setColor(c.accent[1], c.accent[2], c.accent[3], alpha)
        g.polygon("line", self.target.vertices)
    end
    g.pop()
end

return Flight
