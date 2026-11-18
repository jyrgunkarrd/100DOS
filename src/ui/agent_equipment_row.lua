local Animation = require("src.ui.animation")
local Row = {}
Row.__index = Row

local function color(value, label)
    assert(type(value) == "table", "Missing equipment " .. label)
    for i = 1, 4 do
        local channel = value[i]
        assert(type(channel) == "number" and channel >= 0 and channel <= 1,
            "Invalid equipment " .. label)
    end
end

-- No images or input state: this view only owns its prepared layout and data.
function Row.new(slots, settings, width, parallaxTop)
    assert(type(slots) == "table" and #slots > 0, "Missing equipment slots")
    assert(type(settings) == "table", "Missing equipment view settings")
    for _, key in ipairs({ "size", "borderWidth", "padding", "gap", "rightMargin", "parallaxGap", "labelGap" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid equipment " .. key)
    end
    assert(settings.borderWidth > 0 and settings.size > 2 * (settings.borderWidth + settings.padding),
        "Equipment frame and padding leave no room for a color block")
    for _, key in ipairs({ "revealDuration", "revealStagger" }) do
        local value = settings[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge, "Invalid equipment " .. key)
    end
    color(settings.frameColor, "frame color")
    assert(type(settings.label) == "string", "Missing equipment label")
    color(settings.backgroundColor, "background color")
    local known = {}
    for _, slot in ipairs(slots) do
        assert(type(slot.id) == "string" and slot.id:match("%S") and not known[slot.id],
            "Equipment slots require unique nonempty IDs")
        known[slot.id] = true
        color(slot.color, "slot color")
    end
    local rowWidth = #slots * settings.size + (#slots - 1) * settings.gap
    local x = math.floor(width - settings.rightMargin - rowWidth)
    local y = math.floor(parallaxTop - settings.parallaxGap - settings.size)
    assert(x >= 0 and y >= 0, "Equipment row does not fit on the canvas")
    return setmetatable({ slots = slots, settings = settings,
        x = x, y = y, width = rowWidth, height = settings.size }, Row)
end

function Row:revealAlpha(index, elapsed)
    local c = self.settings
    return Animation.easeOutQuad(Animation.progress(elapsed or math.huge, (index - 1) * c.revealStagger, c.revealDuration))
end

function Row:bounds(start, size)
    local c = self.settings
    return self.x + (start - 1) * (c.size + c.gap), self.y,
        size * c.size + (size - 1) * c.gap, c.size
end

function Row:hit(x, y)
    if not x or not y or x < self.x or x >= self.x + self.width or y < self.y or y >= self.y + self.height then return end
    return math.min(#self.slots, math.floor((x - self.x) / (self.settings.size + self.settings.gap)) + 1)
end

function Row:dropStart(x, y, size)
    local index = self:hit(x, y)
    if index and size and size <= #self.slots then return math.min(index, #self.slots - size + 1) end
end

function Row:draw(smallFont, elapsed)
    local g, c = love.graphics, self.settings
    local inset = c.borderWidth + c.padding
    g.push("all")
    g.setFont(smallFont)
    local function tint(value, alpha)
        g.setColor(value[1], value[2], value[3], value[4] * alpha)
    end
    tint(c.frameColor, self:revealAlpha(1, elapsed))
    g.print(c.label, self.x, math.floor(self.y - c.labelGap - smallFont:getHeight()))
    for index, slot in ipairs(self.slots) do
        local x = self.x + (index - 1) * (c.size + c.gap)
        local alpha = self:revealAlpha(index, elapsed)
        -- Non-overlapping strips keep the fading border from tinting the padding.
        tint(c.frameColor, alpha)
        g.rectangle("fill", x, self.y, c.size, c.borderWidth)
        g.rectangle("fill", x, self.y + c.size - c.borderWidth, c.size, c.borderWidth)
        g.rectangle("fill", x, self.y + c.borderWidth, c.borderWidth, c.size - 2 * c.borderWidth)
        g.rectangle("fill", x + c.size - c.borderWidth, self.y + c.borderWidth,
            c.borderWidth, c.size - 2 * c.borderWidth)
        tint(c.backgroundColor, alpha)
        g.rectangle("fill", x + c.borderWidth, self.y + c.borderWidth,
            c.size - 2 * c.borderWidth, c.size - 2 * c.borderWidth)
        tint(slot.color, alpha)
        g.rectangle("fill", x + inset, self.y + inset, c.size - 2 * inset, c.size - 2 * inset)
    end
    g.pop()
end

return Row
