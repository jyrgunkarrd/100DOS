local Drag = {}
Drag.__index = Drag
function Drag.new(settings)
    for _, key in ipairs({ "threshold", "portraitSize", "resourceGap", "messageGap" }) do
        local n = settings[key]
        assert(type(n) == "number" and n >= 0 and n < math.huge, "Invalid card drag " .. key)
    end
    assert(settings.portraitSize > 0, "Invalid card drag portrait size")
    for _, key in ipairs({ "ghostAlpha", "draggedAlpha" }) do
        assert(type(settings[key]) == "number" and settings[key] >= 0 and settings[key] <= 1, "Invalid drag alpha")
    end
    for _, key in ipairs({ "validColor", "invalidColor", "backgroundColor" }) do
        assert(type(settings[key]) == "table", "Missing drag color")
        for i = 1, 4 do assert(type(settings[key][i]) == "number" and settings[key][i] >= 0 and settings[key][i] <= 1, "Invalid drag color") end
    end
    return setmetatable({ settings = settings }, Drag)
end
function Drag:press(card, x, y)
    if not self.card and card and x and y then self.card, self.startX, self.startY = card, x, y end
end
function Drag:move(x, y)
    if not x or not y then self:cancel(); return end
    self.x, self.y = x, y
    if self.card and (x - self.startX)^2 + (y - self.startY)^2 >= self.settings.threshold^2 then self.active = true end
end
function Drag:cancel()
    self.card, self.active, self.x, self.y = nil, false, nil, nil
end
return Drag
