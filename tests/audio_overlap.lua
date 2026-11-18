return function()
    local Audio = require("src.sys.audio_controller")
    local voices = {}
    local template = {
        clone = function()
            local voice = { playing = false, stopped = false, released = false }
            function voice:play() self.playing = true; return true end
            function voice:isPlaying() return self.playing end
            function voice:setVolume(value) self.volume = value end
            function voice:stop() self.playing = false; self.stopped = true end
            function voice:release() self.released = true end
            voices[#voices + 1] = voice
            return voice
        end,
        setVolume = function() end, stop = function() end, release = function() end,
    }
    local audio = Audio.new({ agent = "agent.wav", hex = "hex.wav" }, {
        newSource = function() return template end,
    })
    assert(audio:playOverlapping("agent"))
    assert(audio:playOverlapping("hex") and audio:playOverlapping("hex"))
    assert(#audio.voices == 3 and not voices[1].stopped and not voices[2].stopped)
    audio:setVolume(0.4)
    for _, voice in ipairs(voices) do assert(voice.volume == 0.4) end
    voices[2].playing = false
    audio:update()
    assert(voices[2].released and #audio.voices == 2 and not voices[1].released)
    audio:stop("hex")
    assert(voices[3].stopped and voices[3].released and #audio.voices == 1)
    audio:setVolume(0)
    assert(not audio:playOverlapping("hex") and #voices == 3)
    assert(not audio:playOverlapping("missing"))
    audio:release()
    assert(voices[1].stopped and voices[1].released and #audio.voices == 0)
end
