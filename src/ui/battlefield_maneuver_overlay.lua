local Model = require("src.sys.battlefield_maneuver")
local Pulse = require("src.ui.outline_pulse")
local Overlay = {}
function Overlay.badgeBounds(cell, count, font, settings)
    local size = math.ceil(math.max(settings.size, font:getWidth(tostring(count)) + settings.padding * 2,
        font:getHeight() + settings.padding * 2) / 2) * 2
    local bottom = cell.y
    for i = 2, #cell.vertices, 2 do bottom = math.max(bottom, cell.vertices[i]) end
    return { x = math.floor(cell.x - size / 2), y = math.floor(bottom - settings.bottomInset - size), size = size }
end
function Overlay.draw(panel, font)
    local s, p, c, g = panel.session, panel.pending, panel.settings, love.graphics
    if not panel.open or panel.flight then return end
    local targets = {}
    if panel.unitId or panel.mode == "reserve" then
        for _, id in ipairs(Model.targets(s, p, panel:source())) do targets[id] = true end
    end
    local reserves = #s.armies.byCell[s.armies.jaclCellId].allied.forces
    local hover = panel.hovered and panel.hovered:match("^cell:(.+)$")
    local moveStyle = require("data.agent_action_panel_view")
    g.push("all"); g.setFont(font); g.setLineStyle("rough"); g.setLineWidth(3)
    -- Outward availability rings sit beneath all target fills, outlines and badges.
    if reserves > 0 then
        for _, cell in ipairs(s.grid.cells) do
            if cell.id == s.armies.jaclCellId then
                Pulse.hex(cell, c.reservePulse.spread, Pulse.pose(panel.age, c.reservePulse, panel.reducedMotion), c.reservePulse, c.reserve)
            end
        end
    end
    for _, cell in ipairs(s.grid.cells) do
        local source = cell.id == p.cell or cell.id == s.armies.jaclCellId and reserves > 0
        if targets[cell.id] then
            g.setColor(moveStyle.targetColor); g.polygon("fill", cell.vertices)
            g.setColor(moveStyle.hoverColor); g.polygon("line", cell.vertices)
        elseif source and cell.id ~= s.armies.jaclCellId then
            local alpha = panel.reducedMotion and 1 or 0.7 + math.sin(panel.age * 4) * 0.3
            g.setColor(c.accent[1], c.accent[2], c.accent[3], alpha); g.polygon("line", cell.vertices)
        end
        if cell.id == s.armies.jaclCellId and reserves > 0 then
            g.setLineWidth(c.reserveOutlineWidth); g.setColor(c.reserve)
            g.polygon("line", Pulse.hexVertices(cell, targets[cell.id] and -c.reserveTargetInset or 0))
            g.setLineWidth(3)
        end
        if hover == cell.id and targets[cell.id] and panel.unitId then
            Pulse.square(cell.x, cell.y, c.previewSize, c.previewRingSize,
                Pulse.pose(panel.age, c.previewPulse, panel.reducedMotion), c.previewPulse, c.previewColor)
            g.setColor(c.previewColor)
            g.rectangle("fill", math.floor(cell.x - c.previewSize / 2),
                math.floor(cell.y - c.previewSize / 2), c.previewSize, c.previewSize)
        end
        if cell.id == s.armies.jaclCellId and reserves > 0 then
            local badge = Overlay.badgeBounds(cell, reserves, font, c.reserveBadge)
            g.setColor(c.reserve)
            g.printf(tostring(reserves), badge.x,
                badge.y + math.floor((badge.size - font:getHeight()) / 2) + c.reserveBadge.textOffsetY, badge.size, "center")
        end
    end
    g.pop()
end
return Overlay
