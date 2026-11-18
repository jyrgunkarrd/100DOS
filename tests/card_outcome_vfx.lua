return function(state, render)
    local feedback, session = state.testFeedback, state.session
    local original, elapsed = feedback.result, feedback.elapsed
    local revision = session.armies.revision
    local data = require("data.card_outcome_vfx")
    local resolver = require("src.sys.card_outcome_vfx")
    resolver.validate(data, feedback.view.holdDuration)
    assert(not pcall(resolver.validate, data, 0.2))
    for _, kind in ipairs({ "maneuver", "entrench" }) do
        local record = {}
        for k, v in pairs(original) do record[k] = v end
        record.battlefieldKind, record.special = kind, nil
        record.summary = kind == "maneuver" and "CHOOSE ONE FORCE TO MANEUVER" or "ALLIED PROTECTION SET TO 2"
        feedback:start(record)
        assert(feedback.outcomeImage and feedback.outcomeProfile)
        assert(feedback:outcomePose().sweep == nil, "No effect before Fate resolves")
        local function at(age, suffix)
            feedback.elapsed = feedback.settings.hitTime + age
            render("battlefield_" .. kind .. "_vfx_" .. suffix .. ".png")
            assert(session.armies.revision == revision and not state.maneuver.open)
            return feedback:outcomePose()
        end
        local pose = at(0.175, "scan")
        assert(math.abs(pose.artMix - 0.5) < 0.0001 and pose.contentAlpha == 1)
        pose = at(0.35, "art")
        assert(math.abs(pose.artMix - 1) < 0.0001 and pose.contentAlpha > 0.999)
        pose = at(0.63, "fade")
        assert(pose.contentAlpha == 0 and pose.frameAlpha > 0 and pose.frameAlpha < 1)
        pose = at(0.71, "finished")
        assert(pose.contentAlpha == 0 and pose.frameAlpha == 0)
        feedback.cutin.settings.reducedMotion = true
        at(0.175, "reduced")
        feedback.cutin.settings.reducedMotion = false
        local entry, path = data.battlefield[kind], data.battlefield[kind].art
        entry.art = "assets/images/cards/card_vfx/missing-test-art.png"
        feedback:start(record)
        entry.art = path
        assert(not feedback.outcomeImage and feedback.locationImage)
        at(0.35, "missing_art")
        record.success = false
        feedback:start(record)
        assert(not feedback.outcomeImage and not feedback.outcomeProfile)
        pose = at(0.05, "failure")
        assert(not pose.sweep and pose.failureFlash > 0)
        record.success, record.special = true, "auto_success"
        feedback:start(record)
        assert(feedback.outcomeImage)
        feedback:clear()
        assert(not feedback.outcomeImage and not feedback.outcomeProfile)
    end
    assert(not resolver.resolve({ battlefield = true, battlefieldKind = "engage", success = true }, data))
    assert(not resolver.resolve({ battlefieldKind = "maneuver", success = true }, data))
    feedback:start(original); feedback.elapsed = elapsed
end
