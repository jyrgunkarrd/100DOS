local Defaults = require("data.deployment_ready")
local Animation = require("src.ui.animation")
local Ready = {}
Ready.__index = Ready

-- Appearance and bounds; the owning state handles readiness and completed clicks.
function Ready.new(settings)
    local c = settings or Defaults
    local self = setmetatable({ images = {}, diagnostics = {},
        width = c.width * c.scale, height = c.height * c.scale,
        scale = c.scale, gap = c.promptGap, fadeDuration = c.fadeDuration }, Ready)
    for _, name in ipairs({ "false", "true" }) do
        local path = c[name .. "Path"]
        local ok, image = pcall(love.graphics.newImage, path)
        if ok then
            if image:getWidth() == c.width and image:getHeight() == c.height then
                image:setFilter("nearest", "nearest")
                self.images[name] = image
            else
                image:release()
                self.diagnostics[#self.diagnostics + 1] = "Unexpected Ready image dimensions: " .. path
            end
        else
            self.diagnostics[#self.diagnostics + 1] = "Cannot load Ready image: " .. tostring(path)
        end
    end
    return self
end

function Ready:alpha(elapsed, start)
    return Animation.progress(elapsed, start, self.fadeDuration)
end

function Ready:layout(prompt)
    return math.floor(prompt.x + (prompt.textWidth - self.width) / 2 + 0.5),
        math.floor(prompt.y + prompt.height + self.gap + 0.5)
end

function Ready:contains(prompt, px, py)
    if not prompt or px == nil or py == nil then return false end
    local x, y = self:layout(prompt)
    return px >= x and py >= y and px < x + self.width and py < y + self.height
end

function Ready:draw(prompt, allAssigned, elapsed, start, opacity)
    local alpha = opacity or self:alpha(elapsed, start)
    if alpha <= 0 then return end
    local x, y = self:layout(prompt)
    local image = self.images[allAssigned and "true" or "false"]
    local g = love.graphics
    g.push("all")
    if image then
        g.setColor(1, 1, 1, alpha)
        g.draw(image, x, y, 0, self.scale, self.scale)
    else
        g.setColor(0.12, 0.12, 0.12, alpha)
        g.rectangle("fill", x, y, self.width, self.height)
        g.setColor(allAssigned and 0.4 or 0.6, allAssigned and 0.9 or 0.6, 0.6, alpha)
        g.setLineWidth(1)
        g.rectangle("line", x + 0.5, y + 0.5, self.width - 1, self.height - 1)
        g.setFont(prompt.font)
        g.printf(allAssigned and "READY" or "NOT READY", x,
            math.floor(y + (self.height - prompt.font:getHeight()) / 2), self.width, "center")
    end
    g.pop()
end

function Ready:release()
    for _, image in pairs(self.images) do image:release() end
    self.images = {}
end

return Ready
