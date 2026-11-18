local C = require("data.clash_reinforcement_view")
local View = {}; View.__index = View
function View.new(session)
    for _, key in ipairs({ "groupDuration", "hold", "fadeDuration" }) do
        assert(type(C[key]) == "number" and C[key] > 0 and C[key] < math.huge, "Invalid reinforcement view " .. key)
    end
    return setmetatable({ session = session, portraits = require("src.ui.force_portraits").new(session) }, View)
end
function View.update(session, dt)
    local record = session.reinforcementFeedback
    if not record then return false end
    record.elapsed = record.elapsed + math.max(0, dt)
    if record.elapsed >= #record.groups * C.groupDuration + C.hold then
        session.reinforcementFeedback = nil; return true
    end
    return false
end
function View:draw(width, height, font)
    local r, g = self.session.reinforcementFeedback, love.graphics
    if not r then return end
    local i = math.min(#r.groups, math.floor(r.elapsed / C.groupDuration) + 1)
    local group = r.groups[i]
    local age = r.elapsed - (i - 1) * C.groupDuration
    local reduced = C.reducedMotion or require("data.doom_clock_view").reducedMotion
    local alpha = reduced and 1 or math.min(1, age / C.fadeDuration)
    g.push("all"); g.setFont(font)
    g.setColor(0, 0, 0, 0.6); g.rectangle("fill", 0, 0, width, height)
    for _, cell in ipairs(self.session.grid.cells) do
        if cell.id == r.cell then
            local pulse = reduced and 1 or (0.55 + 0.45 * math.sin(r.elapsed * math.pi / C.groupDuration) ^ 2)
            g.setColor(C.color[1], C.color[2], C.color[3], pulse); g.setLineWidth(3); g.polygon("line", cell.vertices); break
        end
    end
    local x, y = math.floor(width / 2 - 270), math.floor(height / 2 - 180)
    g.setColor(C.background); g.rectangle("fill", x, y, 540, 360)
    g.setColor(C.color); g.rectangle("line", x, y, 540, 360)
    g.printf(C.title .. " / " .. r.cell:upper(), x, y + 16, 540, "center")
    g.printf("CLASH " .. r.before .. " > " .. r.after .. " / ENEMY STRENGTH 0 > " .. r.strength, x, y + 40, 540, "center")
    local w, h = self.portraits:dimensions(group.forceId)
    self.portraits:draw(group.forceId, math.floor(width / 2 - w / 2), y + 70, nil, { 1, 1, 1, alpha })
    local definition = self.session.armies.catalogue.byId[group.forceId]
    g.setColor(1, 1, 1, 1)
    g.printf(group.count .. "x " .. (definition.name or group.forceId) .. " / " .. i .. " OF " .. #r.groups, x, y + 310, 540, "center")
    g.pop()
end
function View:release() self.portraits:release() end
return View
