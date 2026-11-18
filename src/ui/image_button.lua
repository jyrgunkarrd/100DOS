local Button = {}
Button.__index = Button

-- Reports completed clicks; the owning state decides their action.
function Button.new(definition)
    local self = setmetatable({ id = definition.id, label = definition.label,
        x = 0, y = 0, width = definition.width, height = definition.height,
        hovered = false, diagnostics = {} }, Button)
    local function load(path)
        local ok, image = pcall(love.graphics.newImage, path)
        if not ok then
            self.diagnostics[#self.diagnostics + 1] = "Cannot load button image: " .. path
            return nil
        end
        image:setFilter("nearest", "nearest")
        return image
    end
    self.base = load(definition.basePath)
    self.hover = load(definition.hoverPath)
    if self.base then self.width, self.height = self.base:getDimensions() end
    local scale = definition.scale or 1
    self.width, self.height = self.width * scale, self.height * scale
    if not self.base then self.font = love.graphics.newFont(12) end
    return self
end

function Button:updatePointer(x, y)
    local wasHovered = self.hovered
    self.hovered = x ~= nil and y ~= nil and x >= self.x and y >= self.y
        and x < self.x + self.width and y < self.y + self.height
    return self.hovered and not wasHovered
end

function Button:contains(x, y)
    return x ~= nil and y ~= nil and x >= self.x and y >= self.y
        and x < self.x + self.width and y < self.y + self.height
end

function Button:press(x, y, mouseButton)
    if mouseButton == 1 then self.pressed = self:contains(x, y) end
end

function Button:cancelPress()
    self.pressed = false
end

function Button:releasePointer(x, y, mouseButton)
    if mouseButton ~= 1 then return false end
    local clicked = self.pressed and self:contains(x, y)
    self:cancelPress()
    return clicked or false
end

function Button:draw(alpha, forceTrue)
    alpha = alpha or 1
    local g = love.graphics
    g.push("all")
    local active = forceTrue == true or self.hovered
    local image = self.base and (active and self.hover or self.base)
    if image then
        g.setColor(1, 1, 1, alpha)
        g.draw(image, self.x, self.y, 0, self.width / image:getWidth(), self.height / image:getHeight())
    else
        local shade = active and 0.3 or 0.18
        g.setColor(shade, shade, shade, alpha)
        g.rectangle("fill", self.x, self.y, self.width, self.height)
        g.setFont(self.font)
        g.setColor(1, 1, 1, alpha)
        g.printf(self.label, self.x, self.y + math.floor((self.height - self.font:getHeight()) / 2),
            self.width, "center")
    end
    g.pop()
end

function Button:release()
    for _, key in ipairs({ "base", "hover", "font" }) do
        if self[key] then self[key]:release(); self[key] = nil end
    end
    self.hovered = false
    self:cancelPress()
end

return Button
