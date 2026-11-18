local Artwork = require("src.ui.layered_artwork")
local Animation = require("src.ui.animation")
local Transition = {}
Transition.__index = Transition

-- Build and validate without taking ownership of preparation's resources yet.
function Transition.new(source, target, grid, settings)
    local c = {}
    for _, key in ipairs({ "agentDuration", "crossfadeStart", "crossfadeDuration",
        "fadeDuration", "dropDuration", "dropStagger", "groupPause" }) do
        local n = settings[key]
        assert(type(n) == "number" and n >= 0 and n < math.huge, "Invalid transition " .. key)
        c[key] = n
    end
    assert(c.crossfadeStart + c.crossfadeDuration <= c.agentDuration
        and c.fadeDuration <= c.agentDuration, "Transition fades must finish before agents settle")
    local self = setmetatable({ time = 0, config = c, target = target,
        sourceTime = source.entranceTime, agents = {}, drops = {}, order = {},
        width = grid.width, height = grid.height }, Transition)
    assert(#source.agentRoster.entries == #target.entries, "Transition agent counts differ")
    for i, entry in ipairs(source.agentRoster.entries) do
        assert(entry.id == target.entries[i].id, "Transition agent order differs")
        self.agents[i] = { x = entry.x, y = source.agentRoster:entrancePose(i, self.sourceTime).y,
            size = source.agentRoster.config.portraitSize }
    end
    local cells = {}
    for _, cell in ipairs(grid.cells) do cells[cell.id] = cell end
    local function denseArray(array)
        assert(type(array) == "table" and #array > 0, "Transition groups must be nonempty arrays")
        for key in pairs(array) do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #array,
                "Transition groups must be dense arrays")
        end
    end
    denseArray(settings.groups)
    local start = c.agentDuration
    for _, group in ipairs(settings.groups) do
        denseArray(group)
        for i, id in ipairs(group) do
            local cell = cells[id]
            assert(cell and not self.drops[id], "Unknown or repeated transition cell: " .. tostring(id))
            local bottom = -math.huge
            for j = 2, #cell.vertices, 2 do bottom = math.max(bottom, cell.vertices[j]) end
            self.drops[id] = { start = start + (i - 1) * c.dropStagger,
                offset = -bottom - grid.lineWidth / 2 - 1 }
            self.order[#self.order + 1] = cell
        end
        self.duration = start + (#group - 1) * c.dropStagger + c.dropDuration
        start = self.duration + c.groupPause
    end
    assert(#self.order == #grid.cells, "Transition must include every board cell exactly once")
    return self
end

function Transition:take(source)
    self.sourceRoster, source.agentRoster = source.agentRoster, nil
    self.buttons, source.buttons = source.buttons, nil
    for _, button in ipairs(self.buttons) do button:cancelPress() end
    self:update(0)
end

function Transition:agentPose(index)
    local c, source, target = self.config, self.agents[index], self.target.entries[index]
    local t = Animation.easeOutQuad(Animation.progress(self.time, 0, c.agentDuration))
    return {
        x = Animation.lerp(source.x, target.x, t),
        y = Animation.lerp(source.y, target.y, t),
        size = Animation.lerp(source.size, self.target.size, t),
        blend = Animation.progress(self.time, c.crossfadeStart, c.crossfadeDuration),
    }
end

function Transition:cellPose(cell)
    local drop = self.drops[cell.id]
    local p = Animation.progress(self.time, drop.start, self.config.dropDuration)
    return { visible = self.time >= drop.start,
        offsetY = Animation.lerp(drop.offset, 0, Animation.easeInQuad(p)) }
end

function Transition:update(dt)
    self.time = self.time + math.max(0, dt)
    if self.time >= self.config.fadeDuration and self.buttons then
        for _, button in ipairs(self.buttons) do button:release() end
        self.buttons = nil
    end
    if self.time >= self.config.agentDuration and self.sourceRoster then
        self.sourceRoster:release()
        self.sourceRoster = nil
    end
end

local function drawPortrait(entry, pose, alpha, mini)
    if alpha <= 0 then return end
    local g = love.graphics
    if not mini then
        -- Keep the full portrait and its decorative layers together at native
        -- size while the moving miniature fades in underneath them.
        local size = 176
        if entry.image then size = math.max(entry.image:getDimensions()) end
        pose = { x = pose.x + (pose.size - size) / 2,
            y = pose.y + (pose.size - size) / 2, size = size }
    end
    Artwork.draw(not mini and entry.artwork or nil, math.floor(pose.x + 0.5), math.floor(pose.y + 0.5),
        pose.size, pose.size, function()
        if entry.image then
            local iw, ih = entry.image:getDimensions()
            local scale = math.min(pose.size / iw, pose.size / ih)
            local x = math.floor(pose.x + (pose.size - iw * scale) / 2 + 0.5)
            local y = math.floor(pose.y + (pose.size - ih * scale) / 2 + 0.5)
            g.setColor(1, 1, 1, alpha)
            g.draw(entry.image, x, y, 0, scale, scale)
        else
            g.setColor(0.12, 0.12, 0.12, alpha)
            g.rectangle("fill", pose.x, pose.y, pose.size, pose.size)
            if mini then
                local x, y, d = pose.x + pose.size / 2, pose.y + pose.size / 2, math.min(6, pose.size / 4)
                g.setColor(0.34, 0.39, 0.39, alpha)
                g.setLineWidth(1)
                g.line(x - d, y - d, x + d, y + d)
                g.line(x - d, y + d, x + d, y - d)
            end
        end
    end, { 1, 1, 1, alpha })
end

function Transition:drawAgents()
    local g = love.graphics
    g.push("all")
    g.intersectScissor(0, 0, self.width, self.height)
    local alpha = 1 - Animation.progress(self.time, 0, self.config.fadeDuration)
    if self.sourceRoster then
        if alpha > 0 then
            self.sourceRoster:draw(self.sourceTime, { decorationsOnly = true, alpha = alpha })
        end
        for i, entry in ipairs(self.sourceRoster.entries) do
            local pose = self:agentPose(i)
            drawPortrait(entry, pose, 1 - pose.blend, false)
            drawPortrait(self.target.entries[i], pose, pose.blend, true)
        end
    else
        self.target:draw()
    end
    for _, button in ipairs(self.buttons or {}) do button:draw(alpha) end
    g.pop()
end

function Transition:release()
    if self.sourceRoster then self.sourceRoster:release(); self.sourceRoster = nil end
    for _, button in ipairs(self.buttons or {}) do button:release() end
    self.buttons = nil
end

return Transition
