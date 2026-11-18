local Clock = require("src.sys.doom_clock")
local DeckEffects = require("src.sys.mission_deck_effects")
local View = {}
local function config() return require("data.doom_clock_view") end
function View.validate()
    local c = config()
    for _, key in ipairs({ "slotSize", "slotGap", "pendingGap", "buttonGap", "padding", "captionGap", "dropDuration", "clearDuration", "populateDuration", "gloryPulseDuration", "populateOffset", "openingPanelDuration", "openingStagger", "openingSlotDuration", "warningFlashDuration", "warningFlashHold" }) do
        assert(type(c[key]) == "number" and c[key] >= 0 and c[key] < math.huge, "Invalid doom view " .. key)
    end
    assert(c.slotSize > 0 and type(c.reducedMotion) == "boolean" and type(c.imagePath) == "string" and type(c.successImagePath) == "string", "Invalid doom display")
    for _, key in ipairs({ "background", "border", "locked", "success", "text", "gloryColor", "warningFlashColor" }) do
        for i = 1, 4 do
            local v = c[key] and c[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid doom color " .. key)
        end
    end
    assert(c.warningFlashDuration > c.warningFlashHold, "Invalid doom warning flash duration")
    assert(c.gloryPulseDuration > 0 and type(c.gloryLabel) == "string", "Invalid doom glory display")
end
local function progress(age, start, length)
    if age < start then return 0 end
    if length == 0 then return 1 end
    return math.max(0, math.min(1, (age - start) / length))
end
local function full(clock)
    if not clock then return false end
    for _, state in ipairs(clock.slots) do
        if state ~= "locked" then return false end
    end
    return true
end
local function duration(event, c)
    if event.kind == "success_drop" or event.kind == "convert" then return c.dropDuration end
    return c[event.kind .. "Duration"]
end
function View.update(session, dt)
    local c = config()
    if session.doomWarning then
        session.doomWarning.elapsed = session.doomWarning.elapsed + math.max(0, dt)
        if session.doomWarning.elapsed >= c.warningFlashDuration then session.doomWarning = nil end
    end
    if session.doomEntranceTime ~= nil then
        local endTime = c.openingPanelDuration + math.max(0, #(session.doomClock and session.doomClock.slots or {}) - 1) * c.openingStagger + c.openingSlotDuration
        session.doomEntranceTime = c.reducedMotion and endTime or math.min(endTime, session.doomEntranceTime + math.max(0, dt))
    end
    session.doomGloryTime = full(session.doomClock) and ((session.doomGloryTime or 0) + math.max(0, dt)) or 0
    local events = session.doomPresentation or {}
    for i = #events, 1, -1 do
        local event = events[i]
        event.elapsed = event.elapsed + math.max(0, dt)
        if c.reducedMotion or event.elapsed >= duration(event, c) then table.remove(events, i) end
    end
    if session.lastDoomMill then session.lastDoomMill.elapsed = session.lastDoomMill.elapsed + math.max(0, dt) end
end
function View.layout(clock, session, imageHeight)
    local c = config()
    local button = require("src.ui.fate_pool_inspection").buttonBounds(session)
    local width = #clock.slots * c.slotSize + (#clock.slots - 1) * c.slotGap
    local panelX, panelY = math.floor(button.x), math.floor(button.y + button.height + c.buttonGap)
    local pendingY = panelY + c.padding
    return { x = panelX + c.padding, y = pendingY + imageHeight + c.pendingGap,
        pendingY = pendingY, width = width, panelX = panelX, panelY = panelY }
end

function View.draw(session)
    local clock = session.doomClock
    if not clock then return end
    local c, g = config(), love.graphics
    -- Share the mission artwork cache so the image survives screen transitions and
    -- is released with the mission, including failed/abandoned missions.
    local function artwork(key, path)
        if session.art.images[key] == nil then
            local ok, image = pcall(g.newImage, path)
            session.art.images[key] = ok and image or false
            if ok then image:setFilter("nearest", "nearest") else print("[Doom] Cannot load " .. path) end
        end
        return session.art.images[key]
    end
    local image = artwork("__doom_autofail", c.imagePath)
    local successImage = artwork("__doom_autosuccess", c.successImagePath)
    local ih = image and image:getHeight() or c.slotSize
    local sh = successImage and successImage:getHeight() or c.slotSize
    local layout = View.layout(clock, session, math.max(ih, sh))
    local pendingY = layout.pendingY
    local age = c.reducedMotion and math.huge or (session.doomEntranceTime or math.huge)
    local function opening(index)
        return progress(age, c.openingPanelDuration + (index - 1) * c.openingStagger, c.openingSlotDuration)
    end
    local function tile(x, y, alpha, success)
        local art = success and successImage or image
        g.setColor(1, 1, 1, alpha)
        if art then g.draw(art, math.floor(x + (c.slotSize - art:getWidth()) / 2), math.floor(y))
        else
            local color = success and c.success or c.locked
            g.setColor(color[1], color[2], color[3], alpha)
            g.print(success and "+" or "X", x + 10, y + 6)
        end
    end
    local animations, successAnimations = {}, {}
    local showGlory = full(clock)
    for _, event in ipairs(session.doomPresentation or {}) do
        -- Let falling/converting icons settle before replacing their row.
        if event.kind == "drop" or event.kind == "success_drop" or event.kind == "clear" then showGlory = false end
        for _, index in ipairs(event.slots) do
            if event.kind == "success_drop" then successAnimations[index] = event
            else animations[index] = event end
        end
    end
    g.push("all"); g.setLineWidth(1); g.setLineStyle("rough")
    g.setFont(session.scene.accents.small)
    local captionY = layout.y + c.slotSize + c.captionGap
    local panelHeight = captionY + g.getFont():getHeight() + c.padding - layout.panelY
    g.setColor(c.background[1], c.background[2], c.background[3], c.background[4] * progress(age, 0, c.openingPanelDuration))
    g.rectangle("fill", layout.panelX, layout.panelY, layout.width + c.padding * 2, panelHeight)
    local function slotX(index) return layout.x + (index - 1) * (c.slotSize + c.slotGap) end
    for i, state in ipairs(clock.slots) do
        local x, event = slotX(i), animations[i]
        local successEvent = successAnimations[i]
        local appear = opening(i)
        local color = state == "locked" and c.locked or clock.successes[i] and c.success or c.border
        local flash = 1 - appear
        g.setColor(color[1] + (c.gloryColor[1] - color[1]) * flash,
            color[2] + (c.gloryColor[2] - color[2]) * flash,
            color[3] + (c.gloryColor[3] - color[3]) * flash, color[4] * math.min(1, appear * 3))
        g.rectangle("line", x + 0.5, layout.y + 0.5, c.slotSize - 1, c.slotSize - 1)
        local p = event and math.min(1, event.elapsed / math.max(0.0001, duration(event, c))) or 1
        local falling = event and event.kind == "drop" and not c.reducedMotion
        if (clock.successes[i] and not successEvent) or (falling and event.overwrittenSuccess) then
            tile(x, layout.y + (c.slotSize - sh) / 2, 1, true)
        end
        if falling then
            local t = p < 0.85 and (p / 0.85)^2 or 1 - math.sin((p - 0.85) / 0.15 * math.pi) * 0.05
            tile(x, pendingY + (layout.y + (c.slotSize - ih) / 2 - pendingY) * t, 1)
        elseif not showGlory and event and event.kind == "clear" then tile(x, pendingY, 1 - p)
        elseif not showGlory and state == "pending" then
            local populate = event and event.kind == "populate" and (c.reducedMotion and 1 or p) or 1
            local visible = math.min(appear, populate)
            local offset = c.reducedMotion and 0 or c.populateOffset * (1 - visible)^2
            tile(x, pendingY - offset, visible)
        elseif state == "locked" then tile(x, layout.y + (c.slotSize - ih) / 2, 1) end
    end
    -- Draw converted tiles last so a move from a different column stays visible.
    for index, event in pairs(successAnimations) do
        if clock.successes[index] then
            local p = c.reducedMotion and 1 or math.min(1, event.elapsed / math.max(0.0001, c.dropDuration))
            local t = 1 - (1 - p)^2
            local x = slotX(event.sourceIndex) + (slotX(index) - slotX(event.sourceIndex)) * t
            tile(x, pendingY + (layout.y + (c.slotSize - sh) / 2 - pendingY) * t, 1, true)
        end
    end
    if showGlory then
        -- The mission heading is Not Jam UI 12 at 12 px, already mission-owned.
        local font = session.scene.accents.heading
        g.setFont(font)
        local alpha = (1 + math.cos((session.doomGloryTime or 0) * 2 * math.pi / c.gloryPulseDuration)) / 2
        g.setColor(c.gloryColor[1], c.gloryColor[2], c.gloryColor[3], alpha)
        g.printf(c.gloryLabel, layout.x, math.floor(pendingY + (math.max(ih, sh) - font:getHeight()) / 2), layout.width, "center")
        g.setFont(session.scene.accents.small)
    end
    local deck = session.locationDecks.byCell[DeckEffects.jaclCell(session)]
    local remaining = deck and #deck.drawPile or 0
    local mill = session.lastDoomMill
    local captionColor = mill and mill.elapsed < 0.6 and c.locked or c.text
    g.setColor(captionColor[1], captionColor[2], captionColor[3], captionColor[4] * opening(#clock.slots))
    g.printf(c.deckLabel .. "  " .. remaining .. "   /   " .. Clock.strength(clock) .. " PER PHASE",
        layout.x, captionY, layout.width, "center")
    g.pop()
end
-- Render above test feedback and other overlays so the warning fills the screen.
function View.drawWarning(session, width, height)
    local warning = session.doomWarning
    if not warning then return end
    local c, g = config(), love.graphics
    local alpha = 1 - progress(warning.elapsed, c.warningFlashHold, c.warningFlashDuration - c.warningFlashHold)
    if c.reducedMotion then alpha = alpha * 0.25 end
    g.push("all")
    g.setColor(c.warningFlashColor[1], c.warningFlashColor[2], c.warningFlashColor[3], c.warningFlashColor[4] * alpha)
    g.rectangle("fill", 0, 0, width, height)
    g.pop()
end
return View
