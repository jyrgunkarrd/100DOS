local Audio = {}
Audio.__index = Audio

-- Cache short sound effects once; replaying a cue restarts its existing source
-- so rapid UI interaction cannot accumulate unbounded overlapping voices.
function Audio.new(definitions, backend)
    local self = setmetatable({ sources = {}, voices = {}, diagnostics = {}, volume = 1,
        backend = backend or love.audio, failed = {} }, Audio)
    for id, path in pairs(definitions) do
        self:load(id, path)
    end
    return self
end

function Audio:load(id, path)
    if self.sources[id] or self.failed[id] then return end
    local ok, source = pcall(self.backend.newSource, path, "static")
    if ok then
        if self.volume ~= 1 then source:setVolume(self.volume) end
        self.sources[id] = source
    else
        self.failed[id] = true
        local message = "Cannot load sound '" .. id .. "' (" .. path .. "): " .. tostring(source)
        self.diagnostics[#self.diagnostics + 1] = message
        print("[Audio] " .. message)
    end
end

function Audio:setVolume(volume)
    assert(type(volume) == "number" and volume >= 0 and volume <= 1,
        "Audio volume must be between 0 and 1")
    self.volume = volume
    for _, source in pairs(self.sources) do source:setVolume(volume) end
    for _, voice in ipairs(self.voices) do voice.source:setVolume(volume) end
end

-- Independent voices let consecutive impacts ring out without restarting.
function Audio:playOverlapping(id)
    local source = self.sources[id]
    if not source or self.volume == 0 then return false end
    self:update()
    local voice = source:clone()
    voice:setVolume(self.volume)
    local played = voice:play()
    if played then
        self.voices[#self.voices + 1] = { id = id, source = voice }
    else
        voice:release()
    end
    return played
end

function Audio:update()
    for i = #self.voices, 1, -1 do
        if not self.voices[i].source:isPlaying() then
            self.voices[i].source:release()
            table.remove(self.voices, i)
        end
    end
end

function Audio:play(id)
    local source = self.sources[id]
    if not source then return false end
    source:stop()
    if self.volume == 0 then return false end
    return source:play()
end

function Audio:stop(id)
    for i = #self.voices, 1, -1 do
        local voice = self.voices[i]
        if not id or voice.id == id then
            voice.source:stop()
            voice.source:release()
            table.remove(self.voices, i)
        end
    end
    if id then
        if self.sources[id] then self.sources[id]:stop() end
    else
        for _, source in pairs(self.sources) do source:stop() end
    end
end

function Audio:release()
    self:stop()
    for _, source in pairs(self.sources) do source:release() end
    self.sources = {}
end

return Audio
