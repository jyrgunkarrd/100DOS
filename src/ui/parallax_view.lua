local Defaults = require("data.parallax_defaults")
local View = {}
View.__index = View

local function nonnegative(value, label)
    assert(type(value) == "number" and value >= 0 and value < math.huge,
        label .. " must be a finite nonnegative number")
    return value
end

function View.new(visuals, settings, rectangle)
    settings = settings or {}
    local direction = settings.direction or Defaults.direction
    assert(direction == "left" or direction == "right", "Parallax direction must be left or right")
    local base = nonnegative(settings.baseSpeed or Defaults.baseSpeed, "baseSpeed")
    local step = nonnegative(settings.speedStep or Defaults.speedStep, "speedStep")
    local self = setmetatable({
        rectangle = rectangle, layers = {}, diagnostics = {},
        backgroundColor = settings.backgroundColor or Defaults.backgroundColor,
    }, View)
    for _, message in ipairs(visuals.diagnostics) do
        self.diagnostics[#self.diagnostics + 1] = message
    end
    local function load(layer, speed, detached)
        local ok, image = pcall(love.graphics.newImage, layer.path)
        if not ok then
            self.diagnostics[#self.diagnostics + 1] = "Cannot load " .. layer.path .. ": " .. tostring(image)
            return
        end
        image:setFilter("linear", "linear")
        -- Repeat sampling avoids seams at tile boundaries, including wide images.
        image:setWrap("repeat", "clamp")
        local scale = rectangle.height / image:getHeight()
        local prepared = {
            image = image, key = layer.key, offset = 0,
            speed = speed * (direction == "left" and 1 or -1),
            scale = scale, width = image:getWidth() * scale,
            quad = love.graphics.newQuad(0, 0, rectangle.width / scale,
                image:getHeight(), image:getWidth(), image:getHeight()),
        }
        if not detached then self.layers[#self.layers + 1] = prepared end
        return prepared
    end
    if visuals.doomBackground then self.doomBackground = load(visuals.doomBackground, 0, true) end
    if visuals.background then load(visuals.background, 0) end
    for rank, layer in ipairs(visuals.layers) do
        local speed = settings.speeds and settings.speeds[layer.key]
        if speed == nil then speed = base + (rank - 1) * step end
        load(layer, nonnegative(speed, "Layer " .. layer.key .. " speed"))
    end
    return self
end

-- The alternate is preloaded so committing the warning never allocates assets
-- or resets the offsets/speeds of the numbered foreground layers.
function View:activateDoom()
    if self.doomActive then return true end
    if not self.doomBackground then
        print("[Parallax] Doom background unavailable; retaining current background")
        return false
    end
    for i, layer in ipairs(self.layers) do
        if layer.key == "bg" then
            layer.quad:release(); layer.image:release()
            self.layers[i] = self.doomBackground
            self.doomBackground, self.doomActive = nil, true
            return true
        end
    end
    table.insert(self.layers, 1, self.doomBackground)
    self.doomBackground, self.doomActive = nil, true
    return true
end

function View:update(dt)
    for _, layer in ipairs(self.layers) do
        layer.offset = (layer.offset + layer.speed * dt) % layer.width
    end
end

function View:draw()
    local g, r = love.graphics, self.rectangle
    g.push("all")
    g.intersectScissor(r.x, r.y, r.width, r.height)
    g.setColor(self.backgroundColor)
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    g.setColor(1, 1, 1, 1)
    for _, layer in ipairs(self.layers) do
        layer.quad:setViewport(layer.offset / layer.scale, 0,
            r.width / layer.scale, layer.image:getHeight())
        g.draw(layer.image, layer.quad, r.x, r.y, 0, layer.scale, layer.scale)
    end
    g.pop()
end

function View:release()
    if self.doomBackground then
        self.doomBackground.quad:release(); self.doomBackground.image:release()
        self.doomBackground = nil
    end
    for _, layer in ipairs(self.layers) do
        layer.quad:release()
        layer.image:release()
    end
    self.layers = {}
end

return View
