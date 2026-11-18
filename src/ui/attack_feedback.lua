local Feedback = {}
Feedback.__index = Feedback
function Feedback.new(settings)
    for _, key in ipairs({ "stepDuration", "hitTime", "defeatHold" }) do
        local v = settings[key]
        assert(type(v) == "number" and v >= 0 and v < math.huge, "Invalid attack feedback " .. key)
    end
    assert(settings.stepDuration > 0 and settings.hitTime <= settings.stepDuration, "Invalid attack feedback timing")
    for _, key in ipairs({ "title", "defeated", "health", "defiance" }) do assert(type(settings[key]) == "string", "Missing attack feedback label") end
    for _, key in ipairs({ "color", "healthColor", "defianceColor", "backgroundColor", "textColor" }) do
        for i = 1, 4 do local v = settings[key] and settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid attack feedback color") end
    end
    return setmetatable({ settings = settings, elapsed = 0 }, Feedback)
end
-- Preload once during interface preparation; impact playback never loads files.
function Feedback:bindAudio(session, agentId, backend)
    local sounds = {}
    for id, definition in pairs(session.locationCardPool.byId) do
        if definition.atk_sfx then sounds["attack:" .. id] = "assets/audio/sfx/atk/" .. definition.atk_sfx .. ".wav" end
    end
    local agent = session.agentCards.agents.byId[agentId]
    if agent.defeat_sfx then sounds.defeat = "assets/audio/sfx/def/" .. agent.defeat_sfx .. ".wav" end
    if self.audio then self.audio:release() end
    self.audio = require("src.sys.audio_controller").new(sounds, backend)
    if session.audio then self.audio:setVolume(session.audio.volume) end
end
function Feedback:start(record) self.record, self.elapsed, self.sounded = record, 0, 0 end
function Feedback:busy() return self.record ~= nil end
function Feedback:update(dt)
    if self.audio then self.audio:update() end
    if not self.record then return false end
    self.elapsed = self.elapsed + math.max(0, dt)
    -- Process every crossed impact, including frames spanning several attacks.
    for i = self.sounded + 1, #self.record.events do
        if self.elapsed < (i - 1) * self.settings.stepDuration + self.settings.hitTime then break end
        self.sounded = i
        local event = self.record.events[i]
        if self.audio then
            if event.cardId then self.audio:playOverlapping("attack:" .. event.cardId) end
            if event.defeated then self.audio:playOverlapping("defeat") end
        end
    end
    return self.elapsed >= #self.record.events * self.settings.stepDuration + (self.record.defeated and self.settings.defeatHold or 0)
end
function Feedback:current()
    if not self.record then return end
    local index = math.min(#self.record.events, math.floor(self.elapsed / self.settings.stepDuration) + 1)
    local hit = self.elapsed >= (index - 1) * self.settings.stepDuration + self.settings.hitTime
    return self.record.events[index], index, hit
end
function Feedback:status(status)
    local event, _, hit = self:current()
    if not event then return status end
    local display = {}
    for key, value in pairs(status) do display[key] = value end
    display.health, display.defiance = hit and event.health or event.beforeHealth, hit and event.defiance or event.beforeDefiance
    display.defeated = hit and event.defeated or false
    display.exhausted = display.defeated
    return display
end
function Feedback:draw(width, height, font)
    if self.cutin then self.cutin:draw(self, width, height, font) end
end
function Feedback:clear() self.record = nil end
function Feedback:release()
    self:clear()
    if self.audio then self.audio:release(); self.audio = nil end
end
return Feedback
