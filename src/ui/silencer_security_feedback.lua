local C = require("data.phase_end_view")
local Resolver = require("src.sys.artwork_resolver")
local Artwork = require("src.ui.layered_artwork")
local View = {}; View.__index = View
function View.new(session)
    return setmetatable({ session = session, assets = require("src.sys.artwork_assets").new() }, View)
end
function View:bind(event)
    self.event = event
    self.icon = self.assets:load(C.securityIcon)
    self.image, self.layers = nil, nil
    if event.cardId then
        local definition = self.session.locationCardPool.byId[event.cardId]
        self.image = self.assets:load(Resolver.cardPath(definition, event.cardId, "assets/images/loc_cards"))
        self.layers = self.assets:prepare(Resolver.resolve(definition, self.session.package and self.session.package.biomeId))
    end
end
function View:draw(age, width, height, font, reduced)
    local e, g = self.event, love.graphics
    local hit = age >= C.hitTime
    local x, y = math.floor((width - C.width) / 2), math.floor((height - C.height) / 2)
    g.push("all"); g.setFont(font)
    g.setColor(0, 0, 0, 0.75); g.rectangle("fill", 0, 0, width, height)
    g.setColor(C.background); g.rectangle("fill", x, y, C.width, C.height)
    g.setColor(C.securityColor); g.rectangle("line", x + 0.5, y + 0.5, C.width - 1, C.height - 1)
    local function label(text, top, color)
        g.setColor(color or C.text); g.printf(text, x + 16, y + top, C.width - 32, "center")
    end
    label(C.labels.security .. " / " .. C.labels.blocked, 16, C.securityColor)
    label("SECURITY " .. e.beforeSecurity .. " > " .. (hit and e.security or e.beforeSecurity), 39)
    if self.icon then
        local pulse = reduced and 1 or (0.65 + 0.35 * math.max(0, 1 - math.abs(age - C.hitTime) / C.hitTime))
        g.setColor(1, 1, 1, pulse)
        g.draw(self.icon, x + 48, y + 105)
    end
    if e.cardId then
        local w, h = C.artSize, C.artSize
        if self.image then w, h = self.image:getDimensions() end
        local ax, ay = math.floor(width / 2 - w / 2), y + 70
        local fade = e.destroyed and hit and math.max(0, math.min(1, (age - C.hitDuration) / C.fadeDuration)) or 0
        local brightness = e.destroyed and hit and 0.35 or 1
        local tint = { brightness, brightness, brightness, 1 - fade }
        Artwork.draw(self.layers, ax, ay, w, h, function()
            if self.image then g.setColor(tint); g.draw(self.image, ax, ay) end
        end, tint)
        if hit and not reduced then
            g.setColor(1, 0.36, 0.24, math.max(0, 1 - (age - C.hitTime) / 0.16) * 0.55)
            g.rectangle("fill", ax, ay, w, h)
        end
        if hit then
            label("-" .. e.damage .. " HP" .. (e.destroyed and " / " .. C.labels.destroyed or ""), 278, C.damageColor)
        end
        label(e.name .. " / " .. C.labels.health .. " " .. e.beforeHealth .. " > " .. (hit and e.health or e.beforeHealth), 311)
    else label(C.labels.noTarget, 170) end
    g.pop()
end
function View:release() self.assets:release() end
return View
