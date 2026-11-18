-- Playback consumes immutable results only. No game rules run from this view.
local C = require("data.phase_end_view")
local Milling = require("src.ui.location_milling_feedback")
local Feedback = {}; Feedback.__index = Feedback
function Feedback.reducedMotion()
    return C.reducedMotion or require("data.doom_clock_view").reducedMotion or require("data.silencer_view").reducedMotion
end
function Feedback.validate()
    for _, key in ipairs({ "sabotageDuration", "hitDuration", "hitTime", "destructionHold", "fadeDuration", "width", "height", "artSize" }) do
        assert(type(C[key]) == "number" and C[key] > 0 and C[key] < math.huge, "Invalid phase view " .. key)
    end
    assert(type(C.reducedMotion) == "boolean" and type(C.securityIcon) == "string", "Invalid phase view options")
    for _, key in ipairs({ "background", "text", "securityColor", "damageColor" }) do
        for i = 1, 4 do
            local v = C[key] and C[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid phase view color " .. key)
        end
    end
    for _, key in ipairs({ "security", "blocked", "health", "destroyed", "noTarget", "sabotage" }) do
        assert(type(C.labels[key]) == "string", "Missing phase view label " .. key)
    end
    for _, source in ipairs({ "silencer", "glory" }) do
        assert(type(C.sources[source].title) == "string" and type(C.sources[source].cause) == "string", "Invalid milling source " .. source)
    end
    assert(C.hitTime < C.hitDuration and C.fadeDuration <= C.destructionHold, "Invalid phase impact timing")
end
function Feedback.new(session)
    Feedback.validate()
    local self = setmetatable({ session = session, milling = Milling.new(session),
        security = require("src.ui.silencer_security_feedback").new(session),
        audio = require("src.sys.audio_controller").new({ mill = require("data.location_milling_view").sound }) }, Feedback)
    if session.audio then self.audio:setVolume(session.audio.volume) end
    return self
end
local function activate(session, playback)
    local view = session.scene and session.scene.phaseFeedbackView
    if not view then return end
    local event = playback.events[playback.index]
    if event.kind == "mill" then view.milling:bind(event.record); view.audio:playOverlapping("mill")
    elseif event.kind == "security" then view.security:bind(event) end
end
function Feedback.start(session, events)
    Feedback.validate()
    local playback = { events = {}, index = 1, elapsed = 0 }
    for _, event in ipairs(events or {}) do
        local duration = event.kind == "mill" and Milling.duration(event.record)
            or (event.kind == "security" and (C.hitDuration + (event.destroyed and C.destructionHold or 0)) or C.sabotageDuration)
        if duration > 0 then
            local copy = {}; for key, value in pairs(event) do copy[key] = value end
            copy.duration = duration; playback.events[#playback.events + 1] = copy
        end
    end
    if #playback.events == 0 then return end
    session.phaseFeedback = playback
    activate(session, playback)
end
function Feedback.update(session, dt)
    local view = session.scene and session.scene.phaseFeedbackView
    if view then view.audio:update() end
    local p = session.phaseFeedback
    if not p then return dt end
    p.elapsed = p.elapsed + math.max(0, dt)
    while p.elapsed >= p.events[p.index].duration do
        p.elapsed = p.elapsed - p.events[p.index].duration
        p.index = p.index + 1
        if p.index > #p.events then session.phaseFeedback = nil; return p.elapsed end
        activate(session, p)
    end
    return 0
end
function Feedback:draw(width, height, font)
    local p = self.session.phaseFeedback
    if not p then return end
    local e = p.events[p.index]
    if e.kind == "mill" then self.milling:draw(p.elapsed, width, height, font, Feedback.reducedMotion(), 1)
    elseif e.kind == "security" then self.security:draw(p.elapsed, width, height, font, Feedback.reducedMotion())
    else
        local g = love.graphics
        local cx, landing = self.session.scene.jaclPreview:transportAnchor()
        g.push("all"); g.setFont(font)
        g.setColor(C.background); g.rectangle("fill", cx - 130, landing - 62, 260, 38)
        g.setColor(C.damageColor); g.printf(C.labels.sabotage .. " +" .. e.count, cx - 130, landing - 50, 260, "center")
        g.pop()
    end
end
function Feedback:release() self.milling:release(); self.security:release(); self.audio:release() end
return Feedback
