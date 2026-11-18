local Panel = {}
Panel.__index = Panel

function Panel.new(roster, font, settings)
    local c = settings
    assert(type(c.prompt) == "string" and c.scale == 1, "Action panel requires text and native scale")
    local _, lines = font:getWrap(c.prompt, roster.width)
    local textHeight = font:getHeight() * (1 + (#lines - 1) * font:getLineHeight())
    local self = setmetatable({ images = {}, diagnostics = {}, config = c, font = font,
        promptX = roster.x, promptY = math.floor(roster.y - c.promptGap - textHeight + 0.5),
        promptWidth = roster.width, width = c.width, height = c.height,
        x = math.floor(roster.x + (roster.width - c.width) / 2 + 0.5),
        y = math.floor(roster.y + roster.height + c.buttonGap + 0.5) }, Panel)
    for _, name in ipairs({ "false", "true" }) do
        local path = c[name .. "Path"]
        local ok, image = pcall(love.graphics.newImage, path)
        if ok then
            if image:getWidth() == c.width and image:getHeight() == c.height then
                image:setFilter("nearest", "nearest")
                self.images[name] = image
            else
                image:release()
                self.diagnostics[#self.diagnostics + 1] = "Unexpected Act image dimensions: " .. path
            end
        else
            self.diagnostics[#self.diagnostics + 1] = "Cannot load Act image: " .. tostring(path)
        end
    end
    return self
end

function Panel:contains(x, y)
    return x ~= nil and y ~= nil and x >= self.x and y >= self.y
        and x < self.x + self.width and y < self.y + self.height
end

function Panel:draw(selectedId, alpha, prompt)
    alpha = alpha or 1
    if alpha <= 0 then return end
    local g, c = love.graphics, self.config
    g.push("all")
    g.setFont(self.font)
    g.setColor(c.textColor[1], c.textColor[2], c.textColor[3], alpha)
    g.printf(prompt or c.prompt, self.promptX, self.promptY, self.promptWidth, "center")
    local image = self.images[selectedId and "true" or "false"]
    if image then
        g.setColor(1, 1, 1, alpha)
        g.draw(image, self.x, self.y) -- Native size; the owning state handles clicks.
    else
        g.setColor(0.12, 0.12, 0.12, alpha)
        g.rectangle("fill", self.x, self.y, self.width, self.height)
        local color = selectedId and c.selectionColor or c.textColor
        g.setColor(color[1], color[2], color[3], alpha)
        g.printf("ACT", self.x, math.floor(self.y + (self.height - self.font:getHeight()) / 2), self.width, "center")
    end
    g.pop()
end

function Panel:release()
    for _, image in pairs(self.images) do image:release() end
    self.images = {}
end

return Panel
