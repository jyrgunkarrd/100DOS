local Difficulty = require("src.ui.test_difficulty")
local CardVfx = require("src.ui.card_outcome_vfx")
local Artwork = require("src.ui.layered_artwork")
-- Presentation only. Images are borrowed from the existing preview/portrait caches.
local Cutin = {}
Cutin.__index = Cutin
local function clamp(v) return math.max(0, math.min(1, v)) end
local function ease(v) return 1 - (1 - clamp(v)) ^ 3 end
function Cutin.new(settings, timing)
    for _, key in ipairs({ "width", "height", "margin", "panelWidth", "artSize", "enterDuration",
        "exitDuration", "impactDuration", "defeatSweepDuration", "slideDistance", "shakeDistance", "dimAlpha", "nameScale", "statScale" }) do
        local v = settings[key]
        assert(type(v) == "number" and v >= 0 and v < math.huge, "Invalid cut-in " .. key)
    end
    assert(settings.width > settings.panelWidth * 2 and settings.panelWidth >= settings.artSize
        and settings.height >= settings.artSize + 100 and settings.artSize > 0, "Invalid cut-in bounds")
    assert(settings.enterDuration > 0 and settings.enterDuration <= timing.hitTime
        and settings.exitDuration > 0 and settings.exitDuration < timing.stepDuration - timing.hitTime
        and settings.impactDuration > 0 and settings.defeatSweepDuration > 0 and settings.dimAlpha <= 1
        and settings.nameScale > 0 and settings.statScale > 0, "Invalid cut-in timing/style")
    assert(type(settings.reducedMotion) == "boolean", "Invalid reduced-motion setting")
    for _, key in ipairs({ "background", "enemyColor", "agentColor" }) do
        for i = 1, 4 do
            local v = settings[key] and settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid cut-in color")
        end
    end
    for _, key in ipairs({ "versus", "unavailable" }) do assert(type(settings[key]) == "string", "Invalid cut-in label") end
    return setmetatable({ settings = settings }, Cutin)
end
function Cutin:bind(preview, portrait, agentId)
    self.preview, self.portrait, self.agentId = preview, portrait, agentId
end
function Cutin:sweepPose(age, duration)
    return CardVfx.pose(age, duration)
end
function Cutin:defeatPose(feedback, pose)
    local p = pose or self:pose(feedback)
    if not p or not p.hit or not p.event.defeated or p.event.health ~= 0
        or not p.event.beforeHealth or p.event.beforeHealth <= 0 then return end
    if feedback.talent and (not p.event.success or p.event.test.kind ~= "strike") then return end
    local age = p.age - feedback.settings.hitTime - self.settings.impactDuration
    if age < 0 then return end
    return self:sweepPose(age, self.settings.defeatSweepDuration)
end
function Cutin:pose(feedback)
    local event, index, hit = feedback:current()
    if not event then return end
    local c, t = self.settings, feedback.settings
    local age = feedback.elapsed - (index - 1) * t.stepDuration
    local ending = index == #feedback.record.events
    local duration = t.stepDuration + (event.defeated and t.defeatHold or 0)
    local exit = ending and clamp((age - duration + c.exitDuration) / c.exitDuration) or 0
    local entrance = ease(age / c.enterDuration)
    local wholeEntrance = ease(feedback.elapsed / c.enterDuration)
    local impact = hit and (not feedback.talent or (event.success and event.test.kind == "strike")) and clamp(1 - (age - t.hitTime) / c.impactDuration) or 0
    return { event = event, index = index, hit = hit, age = age, alpha = wholeEntrance * (1 - exit),
        enemyOffset = c.reducedMotion and 0 or -c.slideDistance * (1 - entrance + exit),
        agentOffset = c.reducedMotion and 0 or c.slideDistance * (1 - wholeEntrance + exit),
        shake = c.reducedMotion and 0 or math.sin((age - t.hitTime) * 90) * c.shakeDistance * impact,
        impact = c.reducedMotion and 0 or impact, enemyAlpha = entrance * (1 - exit) }
end
function Cutin:draw(feedback, width, height, font)
    local p = self:pose(feedback)
    if not p then return end
    local c, t, g = self.settings, feedback.settings, love.graphics
    local scale = math.min(1, (width - 2 * c.margin) / c.width, (height - 2 * c.margin) / c.height)
    if scale <= 0 then return end
    g.push("all")
    g.setColor(0, 0, 0, c.dimAlpha * p.alpha); g.rectangle("fill", 0, 0, width, height)
    g.translate((width - c.width * scale) / 2, (height - c.height * scale) / 2); g.scale(scale)
    g.setFont(font)
    local function color(value, alpha)
        g.setColor(value[1], value[2], value[3], value[4] * (alpha or p.alpha))
    end
    local function label(text, x, y, w, size, tint, alpha)
        color(tint, alpha)
        local factor = math.min(size, w / math.max(1, font:getWidth(text)))
        g.print(text, x + (w - font:getWidth(text) * factor) / 2, y, 0, factor, factor)
    end
    if not feedback.talent then
        local title = feedback.record.kind == "end_turn" and t.turnEndTitle or t.title
        label(title .. "  " .. p.index .. " OF " .. #feedback.record.events, 0, -26, c.width, 1, t.textColor)
    end
    local outcome = feedback.talent and feedback:outcomePose()
    local defeat = self:defeatPose(feedback, p)
    local function panel(x, image, name, accent, alpha, defeated, treatment, layers)
        local contentAlpha = alpha * (treatment and treatment.contentAlpha or 1)
        local frameAlpha = alpha * (treatment and treatment.frameAlpha or 1)
        color(c.background, contentAlpha); g.rectangle("fill", x, 0, c.panelWidth, c.height)
        color(accent, frameAlpha); g.rectangle("fill", x, 0, c.panelWidth, 2)
        g.rectangle("fill", x, c.height - 2, c.panelWidth, 2)
        local artX, artY = x + (c.panelWidth - c.artSize) / 2, 12
        local brightness = defeated and 0.35 or treatment and treatment.brightness or 1
        local function composed(offset, tint)
            Artwork.draw(layers, artX + offset, artY, c.artSize, c.artSize, function()
                if image then
                    local iw, ih = image:getDimensions()
                    g.setColor(tint)
                    -- Match the native-size foreground and background layers.
                    g.draw(image, math.floor(artX + offset + (c.artSize - iw) / 2),
                        math.floor(artY + (c.artSize - ih) / 2))
                else
                    label(c.unavailable, artX + offset, artY + c.artSize / 2, c.artSize, 1, t.textColor, contentAlpha)
                end
            end, tint)
        end
        if treatment and treatment.trailAlpha and treatment.trailAlpha > 0 then
            composed(-4, { c.agentColor[1], c.agentColor[2], c.agentColor[3], contentAlpha * treatment.trailAlpha })
        end
        CardVfx.drawCrossfade(function(tint)
            composed(treatment and treatment.artOffset or 0, tint)
        end, treatment and treatment.replacement, treatment and treatment.artMix or 0,
            artX, artY, c.artSize, { brightness, brightness, brightness, contentAlpha })
        label(name:gsub("%s+", " "), x + 10, c.artSize + 22, c.panelWidth - 20, c.nameScale, t.textColor, contentAlpha)
    end
    local event = p.event
    local preview, portrait = self.preview, self.portrait
    local enemy = preview and event.cardId and preview.images[preview.artPaths[event.cardId]]
    if event.battlefield then enemy = feedback.locationImage end
    local agent = portrait and portrait.images[self.agentId]
    local absorbed = not feedback.talent and event.assetHits and #event.assetHits > 0
        and event.beforeHealth == event.health and event.beforeDefiance == event.defiance
    local ax = c.width - c.panelWidth + p.agentOffset + ((feedback.talent or absorbed) and 0 or p.shake)
    local ex = p.enemyOffset + (feedback.talent and p.shake or 0)
    local locationColor = outcome and outcome.sweep and c.agentColor or c.enemyColor
    local enemyTreatment = feedback.talent and defeat or outcome and { brightness = outcome.brightness, contentAlpha = outcome.contentAlpha, frameAlpha = outcome.frameAlpha, artMix = outcome.artMix, replacement = feedback.outcomeImage }
    local agentTreatment = not feedback.talent and defeat or outcome and { artOffset = outcome.artOffset, trailAlpha = outcome.trailAlpha }
    panel(ex, enemy, event.name or event.cardId or "LOCATION", locationColor, p.enemyAlpha, feedback.talent and p.hit and event.defeated and event.health ~= 0, enemyTreatment, preview and preview.artwork and preview.artwork[event.cardId])
    panel(ax, agent, portrait and portrait.names[self.agentId] or feedback.record.agentId or "AGENT",
        not feedback.talent and defeat and c.enemyColor or c.agentColor, p.alpha,
        not feedback.talent and p.hit and event.defeated and event.health ~= 0, agentTreatment, portrait and portrait.artwork and portrait.artwork[self.agentId])
    if outcome and outcome.failureFlash > 0 then
        color(c.enemyColor, p.enemyAlpha * outcome.failureFlash)
        g.setLineWidth(2); g.rectangle("line", ex + 1, 1, c.panelWidth - 2, c.height - 2); g.setLineWidth(1)
    end
    if outcome and outcome.evadeSweep then
        local progress, view = outcome.evadeSweep, feedback.view
        local function horizontalSweep(x, tint, direction, alpha)
            local left, right = x + 2, x + c.panelWidth - 2
            if c.reducedMotion then
                color(tint, alpha * view.evadeSweepAlpha * (1 - progress))
                g.rectangle("fill", left, 2, right - left, c.height - 4)
                return
            end
            local edge = left + (right - left) * (direction == 1 and progress or 1 - progress)
            -- A broad coloured trail with a bright leading edge, clipped to this card.
            for band = 1, 8 do
                local a = edge - direction * view.evadeSweepWidth * band / 8
                local b = edge - direction * view.evadeSweepWidth * (band - 1) / 8
                local start, finish = math.max(left, math.min(a, b)), math.min(right, math.max(a, b))
                if finish > start then
                    color(tint, alpha * view.evadeSweepAlpha * (1 - (band - 1) / 8))
                    g.rectangle("fill", start, 2, finish - start, c.height - 4)
                end
            end
            color(tint, alpha)
            local start = math.max(left, edge - 1.5)
            g.rectangle("fill", start, 2, math.min(right, edge + 1.5) - start, c.height - 4)
        end
        horizontalSweep(ax, c.agentColor, 1, p.alpha)
        horizontalSweep(ex, c.enemyColor, -1, p.enemyAlpha)
    end
    local function verticalSweep(x, tint, alpha, treatment)
        CardVfx.drawScan(x, c.panelWidth, c.height, tint, alpha, treatment, c.reducedMotion)
    end
    if outcome and outcome.sweep then verticalSweep(ex, c.agentColor, p.enemyAlpha, outcome) end
    if defeat then verticalSweep(feedback.talent and ex or ax, c.enemyColor, feedback.talent and p.enemyAlpha or p.alpha, defeat) end
    label(c.versus, c.panelWidth, c.height / 2 - 12, c.width - 2 * c.panelWidth, 2, t.textColor)
    if p.impact > 0 and not absorbed then
        g.setColor(1, 1, 1, p.impact * 0.22)
        g.rectangle("fill", feedback.talent and ex or ax, 2, c.panelWidth, c.artSize + 14)
        g.setColor(1, 0.8, 0.65, p.impact)
        if feedback.talent then
            g.polygon("fill", ax + 30, c.height * 0.6, ex + c.panelWidth * 0.35, c.height * 0.24,
                ex + c.panelWidth * 0.55, c.height * 0.34)
        else
            g.polygon("fill", c.panelWidth - 30, c.height * 0.6, ax + c.panelWidth * 0.65, c.height * 0.24,
                ax + c.panelWidth * 0.45, c.height * 0.34)
        end
    end
    if feedback.talent then
        g.setColor(1, 1, 1, p.alpha)
        g.printf(Difficulty.line(event.test.label .. " ", event.test, event.difficulty, t.textColor), 0, c.artSize + 46, c.width, "center")
        if p.hit then
            local result = Difficulty.result(event)
            label(result, 0, c.artSize + 68, c.width, 1, t.textColor)
            local text = event.success and "SUCCESS" or "FAILURE"
            if event.success and event.test.kind == "strike" then text = event.defeated and "SUCCESS - ENEMY ELIMINATED" or "SUCCESS - ENEMY HEALTH " .. event.beforeHealth .. " > " .. event.health
            elseif event.success and event.test.kind == "evade" then text = "SUCCESS - EXHAUSTED - ENGAGEMENT BROKEN"
            elseif event.success then text = "SUCCESS - CARD DISCARDED" end
            if event.battlefield then text = (event.success and "SUCCESS - " or "FAILURE - ") .. event.summary end
            label(text, 0, c.height + 14, c.width, 1.2, event.success and c.agentColor or c.enemyColor)
            if outcome.linkAlpha > 0 then
                color(c.agentColor, p.alpha * outcome.linkAlpha)
                local mid = c.width / 2
                g.line(c.panelWidth, c.height / 2 + 30, mid - outcome.linkGap, c.height / 2 + 30)
                g.line(mid + outcome.linkGap, c.height / 2 + 30, c.width - c.panelWidth, c.height / 2 + 30)
            end
        end
    elseif p.hit then
        local function stat(title, before, after, x, tint)
            local reduction = before - after
            local pulse = reduction > 0 and p.impact * 0.15 or 0
            local alpha = p.alpha * (defeat and defeat.contentAlpha or 1)
            label(title .. " -" .. reduction, x + 8, c.artSize + 48, c.panelWidth / 2 - 16, c.statScale + pulse, tint, alpha)
            label(before .. " > " .. after, x, c.artSize + 74, c.panelWidth / 2, 1, t.textColor, alpha)
        end
        stat(t.health, event.beforeHealth, event.health, ax, t.healthColor)
        stat(t.defiance, event.beforeDefiance, event.defiance, ax + c.panelWidth / 2, t.defianceColor)
        local hits = event.assetHits or {}
        local rowHeight = math.min(34, (c.height / 2 - 26) / math.max(1, #hits))
        for i, hit in ipairs(hits) do
            local y = c.height / 2 + 20 + (i - 1) * rowHeight
            if p.impact > 0 then
                g.setColor(1, 0.8, 0.65, 0.25 * p.impact)
                g.rectangle("fill", c.panelWidth + 2, y - 2, c.width - c.panelWidth * 2 - 4, rowHeight)
            end
            local name = hit.name .. (hit.destroyed and "  DESTROYED" or "")
            local loss = {}
            if hit.damage > 0 then loss[#loss + 1] = "-" .. hit.damage .. " HEALTH" end
            if hit.trauma > 0 then loss[#loss + 1] = "-" .. hit.trauma .. " DEFIANCE" end
            label(name, c.panelWidth + 3, y, c.width - 2 * c.panelWidth - 6, 1, hit.destroyed and c.enemyColor or t.textColor)
            label(table.concat(loss, "  "), c.panelWidth + 3, y + rowHeight / 2, c.width - 2 * c.panelWidth - 6, 1, t.textColor)
        end
        if event.defeated then label(t.defeated, ax, event.health == 0 and c.height + 14 or c.artSize / 2, c.panelWidth, 2, c.enemyColor) end
    end
    g.pop()
end
return Cutin
