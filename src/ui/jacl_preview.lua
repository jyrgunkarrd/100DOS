local Defaults = require("data.jacl_preview_defaults")
local Preview = {}
Preview.__index = Preview

local function number(settings, key, positive)
    local value = settings[key]
    if value == nil then value = Defaults[key] end
    assert(type(value) == "number" and value >= 0 and value < math.huge
        and (not positive or value > 0), "Invalid JACL preview " .. key)
    return value
end

function Preview.new(definition, canvasWidth, canvasHeight)
    local settings = definition.preparation or {}
    local id = definition.id
    assert(type(id) == "string" and id:match("^[%w_-]+$"), "Invalid JACL image ID")
    local easing = settings.entranceEasing or Defaults.entranceEasing
    assert(easing == "linear" or easing == "easeOutQuad", "Invalid JACL entranceEasing")
    local self = setmetatable({
        name = definition.name or id,
        scale = number(settings, "scale", true),
        duration = number(settings, "entranceDuration"),
        easing = easing, elapsed = 0, diagnostics = {},
        canvasWidth = canvasWidth, canvasHeight = canvasHeight,
        y = canvasHeight - number(settings, "bottomOffset"),
        targetX = canvasWidth / 2,
    }, Preview)
    local path = "assets/images/jacls/" .. id .. ".png"
    local ok, image = pcall(love.graphics.newImage, path)
    local width, height = 384, 88
    if ok then
        self.image = image
        image:setFilter("nearest", "nearest")
        width, height = image:getDimensions()
    else
        self.diagnostics[1] = "Cannot load " .. path .. ": " .. tostring(image)
    end
    self.width, self.height = width * self.scale, height * self.scale
    self.startX = -self.width / 2
    self.x = self.startX
    self:update(0)
    return self
end

function Preview:update(dt)
    self.elapsed = math.min(self.duration, self.elapsed + math.max(0, dt))
    local t = self.duration == 0 and 1 or self.elapsed / self.duration
    if self.easing == "easeOutQuad" then t = 1 - (1 - t) ^ 2 end
    self.x = self.startX + (self.targetX - self.startX) * t
end

function Preview:transportAnchor()
    return self.x, self.y - self.height, self.canvasWidth, self.canvasHeight
end

function Preview:draw()
    local g = love.graphics
    g.push("all")
    g.intersectScissor(0, 0, self.canvasWidth, self.canvasHeight)
    local left, top = self.x - self.width / 2, self.y - self.height
    if self.image then
        g.setColor(1, 1, 1, 1)
        g.draw(self.image, left, top, 0, self.scale, self.scale)
    else
        g.setColor(0.15, 0.18, 0.24, 1)
        g.rectangle("fill", left, top, self.width, self.height)
        g.setColor(1, 1, 1, 1)
        g.printf(self.name, left, top + self.height / 2 - g.getFont():getHeight() / 2,
            self.width, "center")
    end
    g.pop()
end

function Preview:release()
    if self.image then self.image:release() end
    self.image = nil
end

return Preview
