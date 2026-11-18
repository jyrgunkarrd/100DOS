return function()
    local Feedback = require("src.ui.attack_feedback")
    local timing = require("data.attack_feedback_view")
    local feedback = Feedback.new(timing)
    local loaded, played, released = {}, {}, 0
    local function source(path)
        return {
            setVolume = function(self, volume) self.volume = volume end,
            clone = function() return source(path) end,
            play = function(self) played[#played + 1] = { path = path, volume = self.volume }; return true end,
            isPlaying = function() return false end,
            stop = function() end,
            release = function() released = released + 1 end,
        }
    end
    feedback:bindAudio({ locationCardPool = { byId = {
        enemy = { atk_sfx = "smg" }, other = { atk_sfx = "chomp" }, silent = {},
    } }, agentCards = { agents = { byId = { a = { defeat_sfx = "fem" } } } },
        audio = { volume = 0.4 } }, "a", {
        newSource = function(path) loaded[path] = true; return source(path) end,
    })
    assert(loaded["assets/audio/sfx/atk/smg.wav"] and loaded["assets/audio/sfx/atk/chomp.wav"]
        and loaded["assets/audio/sfx/def/fem.wav"])
    local record = { events = { { cardId = "enemy" }, { cardId = "other", defeated = true } }, defeated = true }
    feedback:start(record)
    feedback:update(timing.hitTime / 2)
    assert(#played == 0)
    feedback:update(timing.hitTime / 2)
    assert(#played == 1 and played[1].path == "assets/audio/sfx/atk/smg.wav" and played[1].volume == 0.4)
    feedback:update(0); feedback:update(-1)
    assert(#played == 1)
    feedback:update(timing.stepDuration)
    assert(#played == 3 and played[2].path == "assets/audio/sfx/atk/chomp.wav"
        and played[3].path == "assets/audio/sfx/def/fem.wav")
    feedback:update(100)
    assert(#played == 3)
    feedback:clear(); feedback:update(10)
    assert(#played == 3)
    feedback:start(record); feedback:update(100)
    assert(#played == 6, "Large frames must play each impact once")
    feedback:start({ events = { { cardId = "silent" } } }); feedback:update(100)
    assert(#played == 6, "Missing sound metadata is silent")
    feedback.audio:setVolume(0)
    feedback:start(record); feedback:update(100)
    assert(#played == 6, "Muted attacks and defeat must remain silent")
    feedback:release()
    assert(not feedback.audio and not feedback:busy() and released >= 3)

    local talent = require("src.ui.talent_test_feedback").new(
        { settings = require("data.attack_cutin_view") }, nil, nil, "a")
    assert(talent.audio.sources.reveal and talent.audio.sources.success and talent.audio.sources.failure)
    local cues = {}
    talent.audio.playOverlapping = function(_, cue) cues[#cues + 1] = cue end
    for _, outcome in ipairs({ true, false }) do
        local before = #cues
        talent:start({ agentId = "a", success = outcome, test = { kind = "interact" } })
        talent:update(talent.view.enterDuration / 2)
        assert(#cues == before, "Reveal cue must wait for the wipe")
        talent:update(talent.view.enterDuration / 2)
        assert(#cues == before + 1 and cues[#cues] == "reveal")
        talent:update(talent.view.drawDuration)
        assert(#cues == before + 1, "Result cue must wait until after fate is revealed")
        talent:update(talent.view.resultSoundDelay + 0.001)
        assert(#cues == before + 2 and cues[#cues] == (outcome and "success" or "failure"))
        talent:update(100); talent:update(0)
        assert(#cues == before + 2, "Reveal and result cues must each play only once")
    end
    talent:release()
end
