local Config = require("data.battlefield_view")
local Battlefield = require("src.sys.battlefield_state")
local ForcePreview = require("src.ui.force_preview")
local Inspect = {}
local function hit(bounds, x, y)
    return bounds and x and y and x >= bounds.x and x < bounds.x + bounds.width
        and y >= bounds.y and y < bounds.y + bounds.height
end
local function blocked(state)
    return state.transition or (state.actions and state.actions.open) or (state.drag and (state.drag.card or state.drag.pending or state.drag.active))
        or (state.testPanel and state.testPanel.card) or (state.maneuver and state.maneuver.open)
        or (state.resolving and state:resolving())
end
local function targetAt(session, x, y)
    local cell = session.grid:hit(x, y)
    if cell and session.assignments[cell.id] then return cell.id end
    local view = session.armyView
    for _, label in ipairs(view and view.labels or {}) do
        if hit(label, x, y) or hit(view:protectionLabel(label), x, y)
            or hit(view:clashLabel(label), x, y) then return label.cellId end
    end
end
function Inspect.mousepressed(state, x, y, button)
    if button ~= 1 and button ~= 2 then return false end
    if button == 1 then state.battlefieldDismissPressed = nil end
    if state.battlefieldInspectionCell then
        Inspect.clear(state)
        state.battlefieldDismissPressed = button == 1 or nil
        return true
    end
    if button ~= 2 or not x or not y or blocked(state) then return false end
    local session = state.session or state
    local target = session.armies and targetAt(session, x, y)
    if not target then return false end
    -- Clear any pressed controls and other previews before capturing map input.
    state:focus(false)
    state.battlefieldInspectionCell = target
    Inspect.pointer(state, x, y)
    return true
end
function Inspect.mousereleased(state, button)
    if button == 1 and state.battlefieldDismissPressed then
        state.battlefieldDismissPressed = nil
        return true
    end
    return state.battlefieldInspectionCell ~= nil
end
local function syncPreview(state)
    local layout = state.battlefieldInspectionLayout
    local x, y = state.battlefieldPointerX, state.battlefieldPointerY
    local id
    if layout and hit(layout.viewport, x, y) then
        for _, row in ipairs(layout.rows) do
            if hit(row, x, y + (state.battlefieldScroll or 0)) then id = row.id; break end
        end
    end
    if id and not state.battlefieldForcePreview then
        state.battlefieldForcePreview = ForcePreview.new(state.session or state)
    end
    if state.battlefieldForcePreview then
        state.battlefieldForcePreview:show(id, layout and layout.panel)
    end
end
function Inspect.pointer(state, x, y)
    if not state.battlefieldInspectionCell then return false end
    state.battlefieldPointerX, state.battlefieldPointerY = x, y
    syncPreview(state)
    return true
end
function Inspect.wheel(state, delta)
    if not state.battlefieldInspectionCell or blocked(state) then return false end
    if state.battlefieldForcePreview and state.battlefieldForcePreview:wheel(delta) then return true end
    state.battlefieldScroll = math.max(0, math.min(state.battlefieldScrollMax or 0,
        (state.battlefieldScroll or 0) - delta * Config.inspection.scrollStep))
    syncPreview(state)
    return true
end
function Inspect.update(state)
    if state.battlefieldInspectionCell and blocked(state) then Inspect.clear(state) end
end
local function groups(army)
    local result, byId = {}, {}
    for _, unit in ipairs(army.forces) do
        if not byId[unit.forceId] then
            local group = { id = unit.forceId, count = 0 }
            byId[unit.forceId], result[#result + 1] = group, group
        end
        byId[unit.forceId].count = byId[unit.forceId].count + 1
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end
function Inspect.draw(state)
    local cell = state.battlefieldInspectionCell
    if not cell or blocked(state) then return end
    local s = state.session or state
    local pair, location = s.armies.byCell[cell], s.locations and s.locations.byId[s.assignments[cell]]
    if not pair or not location then Inspect.clear(state); return end
    if not state.forcePortraits then state.forcePortraits = require("src.ui.force_portraits").new(s) end
    local enemies, allies = groups(pair.enemy), groups(pair.allied)
    local c, g = Config.inspection, love.graphics
    if not state.battlefieldNameFont then
        state.battlefieldNameFont = g.newFont(c.nameFont, c.nameSize)
        state.battlefieldNameFont:setFilter("nearest", "nearest")
    end
    local tests = require("src.sys.battlefield_tests").resolve(location)
    local portraitWidth, portraitHeight = 176, 176
    for _, entries in ipairs({ enemies, allies }) do
        for _, group in ipairs(entries) do
            local w, h = state.forcePortraits:dimensions(group.id)
            portraitWidth, portraitHeight = math.max(portraitWidth, w), math.max(portraitHeight, h)
        end
    end
    local eliteWidth = s.scene.accents.small:getWidth(c.eliteLabel)
    local captionHeight = c.captionHeight
    for _, entries in ipairs({ enemies, allies }) do
        for _, group in ipairs(entries) do
            local definition = s.armies.catalogue.byId[group.id]
            local nameWidth = portraitWidth - (definition.strength == "elite" and eliteWidth + c.eliteGap or 0)
            local _, lines = s.scene.accents.small:getWrap(definition.name, nameWidth)
            captionHeight = math.max(captionHeight, 4 + s.scene.accents.small:getHeight()
                * (1 + (#lines - 1) * s.scene.accents.small:getLineHeight()))
        end
    end
    local rowHeight = portraitHeight + math.ceil(captionHeight) + c.gap
    local count = math.max(1, #enemies, #allies)
    local quantityWidth = 0
    for _, entries in ipairs({ enemies, allies }) do
        for _, group in ipairs(entries) do
            quantityWidth = math.max(quantityWidth, s.scene.accents.small:getWidth("x" .. group.count))
        end
    end
    local sideWidth = portraitWidth + c.quantityGap + quantityWidth
    local width = math.max(c.width, 2 * sideWidth + 2 * c.padding + c.gap)
    sideWidth = (width - 2 * c.padding - c.gap) / 2
    local font = s.scene.accents.small
    local _, nameLines = state.battlefieldNameFont:getWrap(location.name, width - 2 * c.padding)
    local nameHeight = state.battlefieldNameFont:getHeight()
        * (1 + (#nameLines - 1) * state.battlefieldNameFont:getLineHeight())
    local talentTop = c.padding + math.ceil(nameHeight) + c.gap
    state.battlefieldTalentAssets = state.battlefieldTalentAssets or require("src.sys.artwork_assets").new()
    local talents, cursorX, cursorY, lineHeight = {}, 0, 0, font:getHeight()
    for _, test in ipairs(tests) do
        local image = state.battlefieldTalentAssets:load(c.talentDirectory .. "/" .. test.talent .. ".png")
        local iconWidth, iconHeight = font:getWidth(test.label), font:getHeight()
        if image then iconWidth, iconHeight = image:getDimensions() end
        local value = tostring(test.printed)
        local pairWidth = iconWidth + c.iconValueGap + font:getWidth(value)
        if cursorX > 0 and cursorX + pairWidth > width - 2 * c.padding then
            cursorX, cursorY, lineHeight = 0, cursorY + lineHeight + c.talentRowGap, font:getHeight()
        end
        talents[#talents + 1] = { image = image, label = test.label, value = value,
            x = cursorX, y = cursorY, width = iconWidth, height = iconHeight }
        cursorX, lineHeight = cursorX + pairWidth + c.talentGap, math.max(lineHeight, iconHeight)
    end
    local protectionTop = talentTop + cursorY + lineHeight + c.gap
    local protection = Battlefield.protection(s.armies, cell)
    local protectionText = "ALLIED PROTECTION " .. protection.stored .. "/" .. protection.cap
    for _, source in ipairs(protection.sources) do
        protectionText = protectionText .. " + " .. source.value .. " " .. source.label
    end
    local textWidth = width - 2 * c.padding
    local _, protectionLines = font:getWrap(protectionText, textWidth)
    local protectionHeight = font:getHeight() * (1 + (#protectionLines - 1) * font:getLineHeight())
    local armyTop = protectionTop + math.ceil(protectionHeight) + c.gap
    local countsTop = armyTop + font:getHeight() + 7
    local portraitTop = countsTop + font:getHeight() + c.gap
    local contentHeight = count * rowHeight
    local height = math.min(portraitTop + 8 + contentHeight, c.maxHeight, (state.height or 720) - 8)
    local viewportHeight = height - portraitTop - 8
    state.battlefieldScrollMax = math.max(0, contentHeight - viewportHeight)
    state.battlefieldScroll = math.min(state.battlefieldScroll or 0, state.battlefieldScrollMax)
    local y = math.max(4, math.min(c.y, (state.height or 720) - height - 4))
    local layout = {
        panel = { x = c.x, y = y, width = width, height = height },
        viewport = { x = c.x + c.padding, y = y + portraitTop, width = width - 2 * c.padding, height = viewportHeight },
        rows = {},
    }
    g.push("all"); g.setFont(s.scene.accents.small)
    g.setColor(Config.background); g.rectangle("fill", c.x, y, width, height)
    g.setColor(Config.frame); g.rectangle("line", c.x, y, width, height)
    g.setFont(state.battlefieldNameFont)
    g.setColor(Config.text); g.printf(location.name, c.x + c.padding, y + 12, width - 2 * c.padding)
    g.setFont(s.scene.accents.small)
    for _, talent in ipairs(talents) do
        local left, top = c.x + c.padding + talent.x, y + talentTop + talent.y
        if talent.image then
            g.setColor(1, 1, 1, 1); g.draw(talent.image, left, top)
        else g.setColor(Config.muted); g.print(talent.label, left, top) end
        g.setColor(Config.text)
        g.print(talent.value, left + talent.width + c.iconValueGap, top + math.floor((talent.height - font:getHeight()) / 2))
    end
    if #talents == 0 then
        g.setColor(Config.muted); g.print("NO BATTLEFIELD ACTIONS", c.x + c.padding, y + talentTop)
    end
    g.setColor(Config.allied); g.printf(protectionText, c.x + c.padding, y + protectionTop, textWidth)
    for index, side in ipairs({ "enemy", "allied" }) do
        local army = pair[side]
        local total, counts = require("src.sys.army_value").calculate(army, s.armies.catalogue, s.armies.rules)
        local x = c.x + c.padding + (index - 1) * (sideWidth + c.gap)
        g.setColor(Config[side]); g.print((side == "enemy" and "ENEMIES " or "ALLIES ") .. total, x, y + armyTop)
        g.setColor(Config.muted); g.print(counts.regular .. " REG / " .. counts.elite .. " ELITE", x, y + countsTop)
        g.push("all")
        local viewport = layout.viewport
        local clipX, clipY = g.transformPoint(viewport.x, viewport.y)
        local clipRight, clipBottom = g.transformPoint(viewport.x + viewport.width, viewport.y + viewport.height)
        g.intersectScissor(clipX, clipY, clipRight - clipX, clipBottom - clipY)
        local entries = index == 1 and enemies or allies
        if #entries == 0 then g.print("NO FORCES", x, y + portraitTop + 12) end
        for i, group in ipairs(entries) do
            local rowTop = y + portraitTop + (i - 1) * rowHeight
            local top = rowTop - state.battlefieldScroll
            local left = x
            state.forcePortraits:draw(group.id, left, top)
            local definition = s.armies.catalogue.byId[group.id]
            local elite = definition.strength == "elite"
            local nameWidth = portraitWidth - (elite and eliteWidth + c.eliteGap or 0)
            g.setColor(Config.text); g.printf(definition.name, left, top + portraitHeight + 4, nameWidth)
            if elite then
                g.setColor(c.eliteColor)
                g.print(c.eliteLabel, left + portraitWidth - eliteWidth, top + portraitHeight + 4)
            end
            local imageWidth, imageHeight = state.forcePortraits:dimensions(group.id)
            layout.rows[#layout.rows + 1] = { id = group.id, x = left, y = rowTop, width = portraitWidth,
                height = portraitHeight + math.ceil(captionHeight) }
            g.setColor(Config.text)
            g.print("x" .. group.count, left + imageWidth + c.quantityGap,
                top + math.floor((imageHeight - font:getHeight()) / 2))
            g.setColor(Config[side]); g.print(definition.strength == "elite" and "2" or "1", left + 2, top + portraitHeight - 10)
        end
        g.pop()
    end
    if state.battlefieldScrollMax > 0 then
        local thumbHeight = math.max(20, viewportHeight * viewportHeight / contentHeight)
        local top = y + portraitTop + (viewportHeight - thumbHeight) * state.battlefieldScroll / state.battlefieldScrollMax
        g.setColor(Config.muted); g.rectangle("fill", c.x + width - 6, y + portraitTop, 2, viewportHeight)
        g.setColor(Config.allied); g.rectangle("fill", c.x + width - 7, top, 4, thumbHeight)
    end
    g.pop()
    state.battlefieldInspectionLayout = layout
    syncPreview(state)
    if state.battlefieldForcePreview then state.battlefieldForcePreview:draw() end
end
function Inspect.clear(state)
    state.battlefieldInspectionCell, state.battlefieldScroll, state.battlefieldScrollMax = nil, 0, nil
    state.battlefieldInspectionLayout, state.battlefieldPointerX, state.battlefieldPointerY = nil, nil, nil
    if state.battlefieldForcePreview then state.battlefieldForcePreview:show(nil) end
end
function Inspect.release(state)
    Inspect.clear(state)
    state.battlefieldDismissPressed = nil
    if state.battlefieldForcePreview then state.battlefieldForcePreview:release(); state.battlefieldForcePreview = nil end
    if state.forcePortraits then state.forcePortraits:release(); state.forcePortraits = nil end
    if state.battlefieldNameFont then state.battlefieldNameFont:release(); state.battlefieldNameFont = nil end
    if state.battlefieldTalentAssets then state.battlefieldTalentAssets:release(); state.battlefieldTalentAssets = nil end
end
return Inspect
