return function(state, render)
    local Pulse = require("src.ui.outline_pulse")
    local Overlay = require("src.ui.battlefield_maneuver_overlay")
    local panel, s = state.maneuver, state.session
    local c = panel.settings
    assert(Pulse.pose(0, c.previewPulse).progress == 0)
    assert(math.abs(Pulse.pose(0.45, c.previewPulse).progress - 0.5) < 0.00001)
    assert(Pulse.pose(0.89, c.previewPulse).alpha < 0.02)
    assert(not Pulse.pose(1.3, c.reservePulse) and not Pulse.pose(0.5, c.previewPulse, true))
    assert(not pcall(Pulse.validate, { period = 0, duration = 1, lineWidth = 2, alpha = 1 }))
    local cell
    for _, entry in ipairs(s.grid.cells) do if entry.id == s.armies.jaclCellId then cell = entry end end
    local army = s.armies.byCell[s.armies.jaclCellId].allied
    local original = army.forces
    local age, hovered, unitId, mode, reduced = panel.age, panel.hovered, panel.unitId, panel.mode, panel.reducedMotion
    local font = s.scene.accents.heading
    local badge = Overlay.badgeBounds(cell, #original, font, c.reserveBadge)
    local bottom = -math.huge
    for i = 2, #cell.vertices, 2 do bottom = math.max(bottom, cell.vertices[i]) end
    assert(badge.size == 22 and math.abs(badge.x + badge.size / 2 - cell.x) <= 1)
    assert(bottom - badge.y - badge.size >= 5 and bottom - badge.y - badge.size < 6)
    local large = Overlay.badgeBounds(cell, 123456, font, c.reserveBadge)
    assert(large.size >= font:getWidth("123456") + 2 * c.reserveBadge.padding)
    assert(large.size > badge.size)
    panel.unitId = s.armies.byCell[panel.pending.cell].allied.forces[1].id
    panel.mode, panel.hovered = "local", "cell:" .. cell.id
    assert(#original > 0)
    local revision, pending = s.armies.revision, s.pendingManeuver
    for _, sample in ipairs({ { 0, "start" }, { 0.45, "mid" }, { 0.89, "end" }, { 1.3, "rest" } }) do
        panel.age = sample[1]
        render("maneuver_markers_" .. sample[2] .. ".png")
    end
    -- Capture overlay primitives to ensure the solid marker stays small while the ring expands.
    local rectangle, solids, rings = love.graphics.rectangle, {}, {}
    love.graphics.rectangle = function(kind, x, y, w, h, ...)
        if math.abs(x + w / 2 - cell.x) < 1 and math.abs(y + h / 2 - cell.y) < 1 then
            local output = kind == "fill" and solids or rings
            output[#output + 1] = w
            assert(w == h and x % 1 == 0 and y % 1 == 0)
        end
        return rectangle(kind, x, y, w, h, ...)
    end
    panel.age = 0.45
    local ok, err = pcall(Overlay.draw, panel, font)
    love.graphics.rectangle = rectangle; assert(ok, err)
    assert(#solids == 1 and solids[1] == 12 and #rings == 1 and rings[1] == 28)
    panel.reducedMotion = true
    render("maneuver_markers_reduced.png")
    panel.reducedMotion = false
    army.forces = {}
    for i = 1, 12 do army.forces[i] = { id = "marker_test" .. i, forceId = original[1].forceId } end
    render("maneuver_markers_reserves_12.png")
    army.forces = {}
    render("maneuver_markers_no_reserves.png")
    army.forces = original
    panel.unitId, panel.mode = nil, "reserve"
    render("maneuver_markers_reserve_source.png")
    panel.age, panel.hovered, panel.unitId, panel.mode, panel.reducedMotion = age, hovered, unitId, mode, reduced
    assert(s.armies.revision == revision and s.pendingManeuver == pending)
end
