local Assets = require("src.sys.artwork_assets")
local Artwork = require("src.ui.layered_artwork")
local Resolver = require("src.sys.artwork_resolver")
local View = {}
View.__index = View
local function clamp(x) return math.max(0, math.min(1, x)) end
function View.new(session)
    local c = require("data.location_milling_view")
    for _, key in ipairs({ "artSize", "width", "height", "travel", "cardDuration", "stagger", "maxCascade", "hold", "emptyDuration" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid milling view " .. key)
    end
    assert(c.enterFraction > 0 and c.enterFraction < c.exitFraction and c.exitFraction < 1, "Invalid milling phases")
    return setmetatable({ settings = c, session = session, assets = Assets.new() }, View)
end
function View.duration(record)
    if not record or record.requested == 0 then return 0 end
    local c = require("data.location_milling_view")
    local stagger = math.min(c.stagger, c.maxCascade / math.max(1, record.actual - 1))
    return record.actual == 0 and c.emptyDuration or (record.actual - 1) * stagger + c.cardDuration + c.hold
end
function View:bind(record)
    self.record, self.images, self.layers = record, {}, {}
    if not record or record.requested == 0 then return 0 end
    local c = self.settings
    self.stagger = math.min(c.stagger, c.maxCascade / math.max(1, record.actual - 1))
    for _, card in ipairs(record.cards) do
        local definition = self.session.locationCardPool.byId[card.cardId]
        self.images[card.cardId] = self.assets:load(Resolver.cardPath(definition, card.cardId, c.directory))
        if definition then
            self.layers[card.cardId] = self.assets:prepare(Resolver.resolve(definition, self.session.package and self.session.package.biomeId))
        end
    end
    return View.duration(record)
end
function View:cardPose(index, age, reduced)
    local c = self.settings
    local progress = (age - (index - 1) * self.stagger) / c.cardDuration
    if progress < 0 or progress >= 1 then return end
    local enter = clamp(progress / c.enterFraction)
    local leave = clamp((progress - c.exitFraction) / (1 - c.exitFraction))
    return { x = reduced and 0 or math.floor(c.travel * (leave - (1 - enter))), alpha = enter * (1 - leave), scale = 1 }
end
function View:draw(age, width, height, font, reduced, alpha)
    local r, c, g = self.record, self.settings, love.graphics
    if not r or r.requested == 0 then return end
    g.push("all"); g.setFont(font)
    g.setColor(0, 0, 0, 0.75 * alpha); g.rectangle("fill", 0, 0, width, height)
    local x, y = math.floor((width - c.width) / 2), math.floor((height - c.height) / 2)
    local function color(tint, a) g.setColor(tint[1], tint[2], tint[3], alpha * (a or 1)) end
    local function label(text, top, tint)
        color(tint or c.text); g.printf(text, x + 12, y + top, c.width - 24, "center")
    end
    color(c.background); g.rectangle("fill", x, y, c.width, c.height)
    color(c.accent); g.rectangle("line", x + 0.5, y + 0.5, c.width - 1, c.height - 1)
    local profile = require("data.phase_end_view").sources[r.source]
    label((profile and profile.title or c.labels.title) .. " / " .. (r.locationName or r.locationId), 16)
    local cause = profile and (r.requested .. " " .. profile.cause) or ((r.eliminated or 0) .. " " .. c.labels.eliminated)
    label(cause .. " > " .. r.actual .. " CARDS " .. c.labels.milled, 38, c.accent)
    local cx, cy = math.floor(width / 2), y + 78
    local arrived, ordinaryArrived = 0, 0
    for i, card in ipairs(r.cards) do
        if age >= (i - 1) * self.stagger + c.cardDuration then
            arrived = arrived + 1
            if card.destination ~= "inPlay" then ordinaryArrived = ordinaryArrived + 1 end
        end
    end
    local entersPlay = false
    for _, card in ipairs(r.cards) do if card.destination == "inPlay" then entersPlay = true end end
    for _, marker in ipairs({ { -c.travel, c.labels.deck }, { c.travel, entersPlay and "IN PLAY / DISCARD" or c.labels.discard } }) do
        color(c.accent, 0.45)
        g.rectangle("line", cx + marker[1] - c.artSize / 2, cy, c.artSize, c.artSize)
        color(c.text); g.printf(marker[2], cx + marker[1] - c.artSize / 2, cy + c.artSize + 8, c.artSize, "center")
    end
    local current, currentScore = nil, -1
    for i, card in ipairs(r.cards) do
        local pose = self:cardPose(i, age, reduced)
        if pose then
            -- Caption the most visible card in the reveal area, not a faint incoming card.
            local score = pose.alpha * (1 - math.abs(pose.x) / c.travel)
            if score >= currentScore then current, currentScore = card, score end
            local image = self.images[card.cardId]
            local w, h = c.artSize, c.artSize
            if image then w, h = image:getDimensions() end
            local ax, ay = math.floor(cx + pose.x - w / 2), math.floor(cy + (c.artSize - h) / 2)
            color(c.background, pose.alpha); g.rectangle("fill", ax, ay, w, h)
            local tint = { 1, 1, 1, alpha * pose.alpha }
            Artwork.draw(self.layers[card.cardId], ax, ay, w, h, function()
                if image then
                    g.setColor(tint); g.draw(image, ax, ay) -- Native pixels, integer position, no scaling.
                else
                    color(c.text, pose.alpha); g.printf(c.labels.unavailable, ax, ay + h / 2, w, "center")
                end
            end, tint)
            color(c.accent, pose.alpha); g.rectangle("line", ax - 1, ay - 1, w + 2, h + 2)
        end
    end
    local pulse = 0
    for i in ipairs(r.cards) do
        local since = age - ((i - 1) * self.stagger + c.cardDuration)
        if since >= 0 and since < c.hold then pulse = math.max(pulse, 1 - since / c.hold) end
    end
    color(c.accent, pulse * 0.3); g.rectangle("fill", cx + c.travel - c.artSize / 2, cy, c.artSize, c.artSize)
    label(current and (current.name .. (current.destination == "inPlay" and " / ENTERS PLAY" or ""))
        or (r.actual == 0 and c.labels.empty or "Review card names in LAST MILL"), 302)
    label(c.labels.milled .. " " .. arrived .. (r.actual > 0 and " / " .. r.actual or "") .. "   |   " .. c.labels.deck .. " "
        .. r.before .. (r.concealed and " + ?" or "") .. " > " .. (r.before - (r.concealed and ordinaryArrived or arrived))
        .. (r.concealed and " + ?" or "")
        .. (not r.concealed and arrived == r.actual and r.after == 0 and " / " .. c.labels.empty or ""), 334, c.accent)
    g.pop()
end
function View:clear() self.record, self.images, self.layers = nil, nil, nil end
function View:release() self:clear(); self.assets:release() end
return View
