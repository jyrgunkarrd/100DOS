return function(write, footer, session)
    local Animation = require("src.ui.target_track_animation")
    local c = require("data.target_track_animation")
    local distribution = require("data.hunt_distribution_view")
    local HuntView = require("src.ui.hunt_distribution")
    local entries = require("src.sys.mission_targets").read(session)
    Animation.validate(c)
    for _, key in ipairs({ "crossfadeDuration", "stagger", "highlightDuration", "highlightStrength", "escapePulseDuration", "reducedFadeDuration" }) do
        local invalid = {}; for k, v in pairs(c) do invalid[k] = v end
        invalid[key] = -1
        assert(not pcall(Animation.validate, invalid))
    end
    local event = { kind = "initial", elapsed = 0, cells = { 1, 2, 3, 4, 5, 6, 7, 8 } }
    local start = distribution.gatherDuration + distribution.shuffleDuration
    local poses = Animation.sample(event, entries, c)
    for _, pose in ipairs(poses) do assert(pose.reveal == 0 and pose.backAlpha == 1) end
    event.elapsed = start + c.crossfadeDuration / 2
    poses = Animation.sample(event, entries, c)
    assert(math.abs(poses[1].reveal - 0.5) < 0.001 and poses[1].reveal > poses[2].reveal)
    event.elapsed = HuntView.duration(event)
    for _, pose in ipairs(Animation.sample(event, entries, c)) do
        assert(pose.reveal == 1 and pose.backAlpha == 0 and pose.highlight == 0)
    end
    -- Longer custom timings compress to the distribution window rather than extend it.
    local slow = {}; for k, v in pairs(c) do slow[k] = v end
    slow.crossfadeDuration, slow.stagger = 2, 1
    for _, pose in ipairs(Animation.sample(event, entries, slow)) do assert(pose.reveal == 1) end
    local reducedBefore = distribution.reducedMotion
    distribution.reducedMotion = true
    event.elapsed = start + c.reducedFadeDuration / 2
    poses = Animation.sample(event, entries, c)
    for _, pose in ipairs(poses) do
        assert(math.abs(pose.reveal - 0.5) < 0.001 and pose.highlight == 0)
    end
    distribution.reducedMotion = reducedBefore
    -- An escape never hides existing progress; only a living champion pulses.
    local escape = { kind = "escape", elapsed = 0 }
    local living = { { champion = true }, { champion = false }, { champion = true, eliminated = true } }
    poses = Animation.sample(escape, living, c)
    assert(poses[1].highlight > 0 and poses[2].highlight == 0 and poses[3].highlight == 0)
    for _, pose in ipairs(poses) do assert(pose.reveal == 1 and pose.backAlpha == 0) end
    for _, pose in ipairs(Animation.sample(nil, entries, c)) do assert(pose.reveal == 1) end

    local original = session.huntPresentation
    local _, layout = footer:prepare(session)
    local first = layout.panels[1]
    local function render(name, age)
        event.elapsed = age; session.huntPresentation = event
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(0.12, 0.14, 0.16, 1)
        love.graphics.setScissor(0, 0, 1280, 720)
        love.graphics.setColor(0.2, 0.3, 0.4, 0.5); love.graphics.setLineWidth(3)
        footer:draw(session)
        local r, _, _, a = love.graphics.getColor()
        local sx, sy, sw, sh = love.graphics.getScissor()
        assert(math.abs(r - 0.2) < 0.001 and math.abs(a - 0.5) < 0.001)
        assert(sx == 0 and sy == 0 and sw == 1280 and sh == 720 and love.graphics.getLineWidth() == 3)
        love.graphics.setScissor(); love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        if age == 0 then
            r = pixels:getPixel(first.portraitX, first.portraitY)
            assert(r > 0.8, "Anonymous card-back border missing during gather")
            assert(footer:pointer(session, first.x + 1, first.y + 1), "Hover must work before portrait reveal")
            assert(footer.previews.cardId == entries[1].cardId)
            footer:clearHover()
        end
        write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    render("target_reveal_backs.png", 0)
    render("target_reveal_crossfade.png", start + c.crossfadeDuration / 2)
    render("target_reveal_settled.png", HuntView.duration(event))
    -- The existing skip operation settles the footer without another animation clock.
    session.huntPresentation = event
    assert(HuntView.keypressed({ session = session }, "space") and not session.huntPresentation)
    for _, pose in ipairs(Animation.sample(session.huntPresentation, entries, c)) do assert(pose.reveal == 1) end
    session.huntPresentation = original
end
