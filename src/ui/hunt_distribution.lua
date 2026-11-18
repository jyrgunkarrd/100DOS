-- Stateless presentation: identical tokens have no link to hidden card identities.
local Hunt = require("src.sys.mission_hunt")
local Outcome = require("src.sys.mission_outcome")
local CardBack = require("src.ui.hunt_card_back")
local MarkerStyle = require("data.jacl_action_view")
local View = {}
local function config() return require("data.hunt_distribution_view") end
local function clamp(t) return math.max(0, math.min(1, t)) end
function View.validate()
    local c = config()
    for _, key in ipairs({ "gatherDuration", "shuffleDuration", "dealDuration", "pulseDuration", "cardWidth", "cardHeight" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid hunt view " .. key)
    end
    assert(type(c.stagger) == "number" and c.stagger >= 0 and c.stagger < math.huge, "Invalid hunt stagger")
    assert(type(c.reducedMotion) == "boolean" and type(c.soundId) == "string", "Invalid hunt presentation options")
    for _, key in ipairs({ "background", "accent", "secured", "text" }) do
        for i = 1, 4 do
            local value = c[key] and c[key][i]
            assert(type(value) == "number" and value >= 0 and value <= 1, "Invalid hunt color " .. key)
        end
    end
    for _, key in ipairs({ "initial", "escape", "hidden", "secured", "located", "victory", "defeated", "continue", "skip" }) do
        assert(type(c.labels and c.labels[key]) == "string", "Missing hunt label " .. key)
    end
end
function View.duration(event)
    local c = config()
    return c.gatherDuration + c.shuffleDuration + c.dealDuration
        + math.max(0, #event.cells - 1) * c.stagger + c.pulseDuration
end
function View.busy(session) return Outcome.finished(session) or session.huntPresentation ~= nil or session.phaseTransition ~= nil or session.phaseFeedback ~= nil end
function View.update(session, dt)
    local event = session.huntPresentation
    if not event then return end
    if not event.sounded then
        event.sounded = true
        if session.audio then session.audio:playOverlapping(config().soundId) end
    end
    event.elapsed = event.elapsed + math.max(0, dt)
    if event.elapsed >= View.duration(event) then session.huntPresentation = nil end
end
function View.keypressed(state, key)
    local session = state.session
    if session.phaseFeedback then return true end
    if Outcome.finished(session) then
        if key == "return" or key == "kpenter" then state.stateMachine:change("mission_preparation") end
        return true
    end
    if session.phaseTransition then return true end
    if session.huntPresentation then
        if key == "space" or key == "escape" then session.huntPresentation = nil end
        return true
    end
    return false
end
-- Hex outlines belong below Agent portraits; banners are drawn separately above them.
function View.outlines(session)
    if session.huntPresentation then return end
    local c, g = config(), love.graphics
    local markers = Hunt.markers(session)
    g.push("all"); g.setLineWidth(2)
    for _, cell in ipairs(session.grid.cells) do
        local marker = markers[cell.id]
        if marker then
            g.setColor(marker.secured and c.secured or c.accent)
            g.polygon("line", cell.vertices)
        end
    end
    g.pop()
end
function View.markers(session, font)
    if session.huntPresentation then return end
    local c, g = config(), love.graphics
    local markers = Hunt.markers(session)
    g.push("all"); if font then g.setFont(font) end
    for _, cell in ipairs(session.grid.cells) do
        local marker = markers[cell.id]
        if marker then
            local names = table.concat(marker.targets, " / ")
            local label = names ~= "" and (c.labels.located .. ": " .. names) or c.labels.secured
            if marker.secured and names ~= "" then label = c.labels.secured .. " / " .. label end
            -- Secured banners sit at the hex center; sightings keep their upper position.
            local width, height = MarkerStyle.markerWidth, MarkerStyle.markerHeight
            local x = math.floor(cell.x - width / 2)
            local y = math.floor(marker.secured and (cell.y - height / 2) or (cell.y - 21))
            if g.getFont():getWidth(label) > width - 6 then
                -- Full names remain available in the legend below the map.
                label = (marker.secured and c.labels.secured .. " / " or "") .. c.labels.located
            end
            g.setColor(MarkerStyle.background); g.rectangle("fill", x, y, width, height)
            g.setLineWidth(1)
            g.setColor(marker.secured and c.secured or c.accent); g.rectangle("line", x, y, width, height)
            g.printf(label, x, y + 4, width, "center")
        end
    end
    local legends = {}
    for _, cell in ipairs(session.grid.cells) do
        local marker = markers[cell.id]
        if marker and #marker.targets > 0 then
            local deck = session.locationDecks.byCell[cell.id]
            legends[#legends + 1] = table.concat(marker.targets, ", ") .. " @ " .. deck.locationName
        end
    end
    -- A previous intelligence notice must not keep an empty report visible.
    if #legends > 0 then
        local b = session.grid.bounds
        local label = table.concat(legends, "   |   ")
        local rows = {}
        if label ~= "" then rows[#rows + 1] = { text = label, color = c.accent } end
        if session.missionHunt.notice then rows[#rows + 1] = { text = session.missionHunt.notice, color = c.text } end
        local height = 0
        for _, row in ipairs(rows) do
            local _, lines = g.getFont():getWrap(row.text, b.width)
            row.textHeight = g.getFont():getHeight() * (1 + (#lines - 1) * g.getFont():getLineHeight())
            row.height = row.textHeight + c.legendPaddingY * 2
            height = height + row.height
        end
        local y = math.floor(b.y + b.height + 23)
        g.setColor(0.015, 0.025, 0.035, 0.95); g.rectangle("fill", b.x - 4, y, b.width + 8, height)
        for _, row in ipairs(rows) do
            g.setColor(row.color)
            g.printf(row.text, b.x, math.floor(y + (row.height - row.textHeight) / 2 + c.markerTextOffsetY), b.width, "center")
            y = y + row.height
        end
    end
    g.pop()
end
local function cardBack(x, y, alpha, c)
    x, y = math.floor(x - c.cardWidth / 2), math.floor(y - c.cardHeight / 2)
    CardBack.draw(x, y, c.cardWidth, c.cardHeight, alpha, c)
end
function View.draw(session, width, height, font, heading)
    if session.phaseFeedback then return end
    local c, g = config(), love.graphics
    if Outcome.finished(session) then
        require("src.ui.mission_outcome").draw(session, width, height, font, heading)
        return
    end
    local event = session.huntPresentation
    if not event then return end
    local b = session.grid.bounds
    local cx, cy = b.x + b.width / 2, b.y + b.height / 2
    local age, start = event.elapsed, c.gatherDuration + c.shuffleDuration
    local cells = {}; for _, cell in ipairs(session.grid.cells) do cells[cell.id] = cell end
    g.push("all"); g.setLineWidth(1); g.setLineStyle("rough")
    g.setColor(0.01, 0.025, 0.035, 0.8); g.rectangle("fill", 0, 0, width, session.grid.height)
    g.setFont(heading or font or g.getFont()); g.setColor(c.text)
    g.printf(c.labels[event.kind] .. " / " .. event.championName, b.x - 100, 8, b.width + 200, "center")
    g.setFont(font or g.getFont()); g.setColor(c.accent)
    g.printf(c.labels.hidden .. "   /   " .. c.labels.skip, b.x - 100, session.grid.height - 22, b.width + 200, "center")
    if age < start then
        local p = clamp(age / c.gatherDuration)
        for i = 1, math.min(#event.cells, 8) do
            local offset = c.reducedMotion and 0 or (i - (#event.cells + 1) / 2) * 13 * (1 - p)
            if age >= c.gatherDuration and not c.reducedMotion then offset = math.sin((age - c.gatherDuration) * 55 + i) * 9 end
            local source = event.sourceCell and cells[event.sourceCell]
            local x = source and source.x + (cx - source.x) * p or cx
            local y = source and source.y + (cy - source.y) * p or cy
            cardBack(x + offset, y + i * 2, c.reducedMotion and clamp(age / c.gatherDuration) or 1, c)
        end
    else
        for i, id in ipairs(event.cells) do
            local target = cells[id]
            if target then
                local p = clamp((age - start - (i - 1) * c.stagger) / c.dealDuration)
                local eased = 1 - (1 - p)^2
                if p < 1 then
                    if c.reducedMotion then cardBack(cx, cy, 1 - p, c)
                    else cardBack(cx + (target.x - cx) * eased, cy + (target.y - cy) * eased, 1, c) end
                else
                    local pulse = 1 - clamp((age - start - (i - 1) * c.stagger - c.dealDuration) / c.pulseDuration)
                    g.setColor(c.accent[1], c.accent[2], c.accent[3], pulse * 0.5); g.polygon("fill", target.vertices)
                end
            end
        end
    end
    g.pop()
end
return View
