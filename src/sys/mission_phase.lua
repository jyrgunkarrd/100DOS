local Turn = require("src.sys.agent_turn")
local Clock = require("src.sys.doom_clock")
local Outcome = require("src.sys.mission_outcome")
local DeckEffects = require("src.sys.mission_deck_effects")
local Phase = {}
function Phase.begin(session)
    if Outcome.finished(session) or session.phaseFeedback or session.phaseTransition or session.huntPresentation or session.pendingManeuver then return false end
    local refresh = Turn.prepareRefresh(session)
    if not refresh then return false end
    if not session.doomClock then return Turn.commitRefresh(session, refresh) end
    local ending = Clock.prepare(session.doomClock, "end_phase")
    local strength = Clock.strength({ slots = ending.slots, successes = ending.successes,
        rate = session.doomClock.rate, relief = session.doomClock.relief })
    local cell = DeckEffects.jaclCell(session)
    local view = require("data.doom_clock_view")
    local duration = not view.reducedMotion and #ending.changed > 0 and view.dropDuration or 0
    assert(type(duration) == "number" and duration >= 0 and duration < math.huge, "Invalid doom phase duration")
    -- Lock the boundary before resolving its ordered, input-blocking stages.
    assert(Clock.commit(session, ending))
    session.phaseTransition = { elapsed = 0, duration = duration, refresh = refresh,
        cell = cell, decks = session.locationDecks, strength = strength, stage = "doom" }
    if duration == 0 then Phase.update(session, 0) end
    return true
end
local Feedback = require("src.ui.phase_end_feedback")
local Milling = require("src.sys.milling_receipt")
local function recordMill(session, transition, record)
    transition.receipt = Milling.append(transition.receipt, record)
    transition.receipt.source = "phase"
    transition.decks.byCell[transition.cell].lastMilling = transition.receipt
end
local function glory(session, transition)
    assert(session.locationDecks == transition.decks, "Phase deck changed during transition")
    local mill = transition.decks:prepareMill(transition.cell, transition.strength)
    local record = Milling.new(transition.decks, transition.cell, mill, "glory")
    assert(transition.decks:commitMill(transition.cell, mill))
    for _, card in ipairs(mill.entered) do
        require("src.sys.location_card_entry").committed(session, transition.cell, card)
    end
    if record.requested > 0 then recordMill(session, transition, record) end
    session.lastDoomMill = { before = mill.before, after = mill.after,
        actual = mill.actual, requested = mill.requested, elapsed = 0 }
    transition.stage = "glory"
    Feedback.start(session, { { kind = "mill", record = record } })
    DeckEffects.check(session)
end
function Phase.update(session, dt)
    dt = math.max(0, dt)
    while true do
        -- Failure can clear the rules transition; its final feedback still completes.
        dt = Feedback.update(session, dt)
        if session.phaseFeedback or Outcome.finished(session) then return end
        local transition = session.phaseTransition
        if not transition then return end
        transition.elapsed = transition.elapsed + dt
        if transition.stage == "transports" and session.silencers.presentation then
            session.silencers.presentation.elapsed = transition.elapsed
        end
        if transition.elapsed < transition.duration then return end
        dt = transition.elapsed - transition.duration
        transition.elapsed, transition.duration = 0, 0
        if transition.stage == "doom" then
            if session.silencers then
                local state = session.silencers
                local previous = {}; for i, transport in ipairs(state.transports) do previous[i] = transport end
                local receipt = require("src.sys.silencer_activity").resolve(session)
                transition.transport = state.presentation
                state.presentation, state.feedbackTransports = nil, previous
                require("src.sys.transport_fate_effects").sync(session, previous)
                state.phaseFeedbackActive = true
                transition.stage = "activity"
                if receipt.milling then recordMill(session, transition, receipt.milling) end
                Feedback.start(session, receipt.events)
            else glory(session, transition) end
        elseif transition.stage == "activity" then
            local state = session.silencers
            state.feedbackTransports, state.phaseFeedbackActive = nil, nil
            state.presentation = transition.transport
            require("src.sys.transport_fate_effects").sync(session, state.presentation and state.presentation.transports or state.transports)
            if state.receipt then state.receipt.elapsed = 0 end
            transition.stage = "transports"
            transition.duration = require("src.ui.silencer_activity").duration(state.presentation)
        elseif transition.stage == "transports" then
            session.silencers.presentation = nil
            require("src.sys.transport_fate_effects").sync(session, session.silencers.transports)
            glory(session, transition)
        elseif transition.stage == "glory" then
            Turn.commitRefresh(session, transition.refresh)
            assert(Clock.commit(session, Clock.prepare(session.doomClock, "begin_phase")))
            session.phaseTransition = nil
            return
        end
    end
end
return Phase
