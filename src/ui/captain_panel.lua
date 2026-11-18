local Defaults = require("data.captain_panel_defaults")
local Entrance = require("data.preparation_entrance").captain
local Animation = require("src.ui.animation")
local Panel = {}
Panel.__index = Panel

function Panel.new(definition, partition, settings)
    settings = settings or Defaults
    local self = setmetatable({ diagnostics = {} }, Panel)
    local function warn(message) self.diagnostics[#self.diagnostics + 1] = message end
    local function image(path)
        local ok, value = pcall(love.graphics.newImage, path)
        if not ok then warn("Cannot load " .. path .. ": " .. tostring(value)); return nil end
        value:setFilter("nearest", "nearest")
        return value
    end
    local function font(path, size)
        local ok, value = pcall(love.graphics.newFont, path, size)
        if not ok then
            warn("Cannot load font " .. path .. "; using default font")
            value = love.graphics.newFont(size)
        end
        value:setFilter("nearest", "nearest")
        return value
    end
    local function color(hex, label)
        if type(hex) == "string" then
            hex = hex:gsub("^#", "")
            if #hex == 6 and hex:match("^%x+$") then
                return { tonumber(hex:sub(1, 2), 16) / 255,
                    tonumber(hex:sub(3, 4), 16) / 255,
                    tonumber(hex:sub(5, 6), 16) / 255, 1 }
            end
        end
        warn("Invalid captain " .. label .. " color; using white")
        return { 1, 1, 1, 1 }
    end
    assert(type(definition.id) == "string" and definition.id:match("^[%w_-]+$"),
        "Invalid captain image ID")
    self.name = definition.name and definition.name.text or definition.id
    self.title = definition.title and definition.title.text or ""
    self.nameColor = color(definition.name and definition.name.color, "name")
    self.titleColor = color(definition.title and definition.title.color, "title")
    self.panel = image(settings.panelPath)
    self.portrait = image("assets/images/captains/" .. definition.id .. ".png")
    self.nameFont = font(settings.nameFontPath, settings.nameFontSize)
    self.titleFont = font(settings.titleFontPath, settings.titleFontSize)
    self.width, self.height = 128, 169
    if self.panel then self.width, self.height = self.panel:getDimensions() end
    self.portraitWidth, self.portraitHeight = 128, 128
    if self.portrait then self.portraitWidth, self.portraitHeight = self.portrait:getDimensions() end
    self.x, self.y = partition.x + settings.insetX, partition.y + settings.insetY
    self.portraitX = self.x + (self.width - self.portraitWidth) / 2
    self.portraitY = self.y + (self.height - self.portraitHeight) / 2
    local function measure(text, textFont)
        local _, lines = textFont:getWrap(text, self.width)
        return textFont:getHeight() + math.max(0, #lines - 1)
            * textFont:getHeight() * textFont:getLineHeight()
    end
    self.nameHeight, self.titleHeight = measure(self.name, self.nameFont), measure(self.title, self.titleFont)
    self.nameY = math.floor(self.portraitY - settings.textGap - self.nameHeight)
    self.titleY = math.ceil(self.portraitY + self.portraitHeight + settings.textGap)
    if self.nameY < self.y or self.titleY + self.titleHeight > self.y + self.height then
        warn("Captain text exceeds panel space: " .. definition.id)
    end
    return self
end

function Panel:entrancePose(time)
    time = time or math.huge
    local slide = Animation.progress(time, 0, Entrance.slideDuration)
    local portrait = Animation.progress(time, Entrance.slideDuration, Entrance.portraitDuration)
    return {
        x = math.floor(Animation.lerp(-self.width, self.x, Animation.easeOutQuad(slide)) + 0.5),
        portraitVisible = time >= Entrance.slideDuration,
        revealHeight = Animation.lerp(Entrance.lineHeight, self.portraitHeight,
            Animation.easeOutQuad(portrait)),
        lineAlpha = 1 - Animation.progress(time, Entrance.slideDuration, Entrance.lineFadeDuration),
        text = Animation.progress(time, Entrance.slideDuration + Entrance.portraitDuration,
            Entrance.textDuration),
    }
end

function Panel:draw(time)
    local g = love.graphics
    local pose = self:entrancePose(time)
    g.push("all")
    g.setColor(1, 1, 1, 1)
    if self.panel then g.draw(self.panel, pose.x, self.y) else
        g.setColor(0.06, 0.07, 0.1, 0.95)
        g.rectangle("fill", pose.x, self.y, self.width, self.height)
    end
    if pose.portraitVisible then
        g.push("all")
        g.intersectScissor(self.portraitX, self.portraitY + (self.portraitHeight - pose.revealHeight) / 2,
            self.portraitWidth, pose.revealHeight)
        g.setColor(1, 1, 1, 1)
        if self.portrait then g.draw(self.portrait, self.portraitX, self.portraitY) else
            g.setColor(0.2, 0.23, 0.3, 1)
            g.rectangle("fill", self.portraitX, self.portraitY, self.portraitWidth, self.portraitHeight)
        end
        g.pop()
        if pose.lineAlpha > 0 then
            g.setColor(1, 1, 1, pose.lineAlpha)
            g.rectangle("fill", self.portraitX,
                math.floor(self.portraitY + (self.portraitHeight - Entrance.lineHeight) / 2),
                self.portraitWidth, Entrance.lineHeight)
        end
    end
    if pose.text > 0 then
        g.push("all")
        g.intersectScissor(self.x, self.nameY, self.width * pose.text,
            self.titleY + self.titleHeight - self.nameY)
        g.setFont(self.nameFont)
        g.setColor(self.nameColor)
        g.printf(self.name, self.x, self.nameY, self.width, "center")
        g.setFont(self.titleFont)
        g.setColor(self.titleColor)
        g.printf(self.title, self.x, self.titleY, self.width, "center")
        g.pop()
    end
    g.pop()
end

function Panel:release()
    for _, key in ipairs({ "panel", "portrait", "nameFont", "titleFont" }) do
        if self[key] then self[key]:release(); self[key] = nil end
    end
end

return Panel
