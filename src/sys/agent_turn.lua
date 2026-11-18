local Status = require("src.sys.agent_status")
local Clashes = require("src.sys.battlefield_clashes")
local Turn = {}

function Turn.prepareActivation(session, id)
    assert(not require("src.sys.mission_outcome").finished(session), "Mission complete")
    assert(not session.phaseTransition, "Phase transition in progress")
    assert(not session.pendingHuntEscape, "Champion escape is pending")
    assert(not session.attackFeedback and not session.talentFeedback, "Attacks are resolving")
    assert(session.agentCards and session.agentStatus, "Mission must begin before activation")
    assert(session.agentStatus.byAgent[id], "Unknown agent")
    assert(not Status.isExhausted(session.agentStatus, id), "Agent is exhausted")
    assert(not session.activeAgentId or session.activeAgentId == id, "Another agent is active")
    local count = session.activeAgentId == id and 0 or session.agentCards.rules[id].activationDrawCount
    return session.agentCards:prepareDraw(id, count)
end

function Turn.commitActivation(session, id, staged)
    assert(not require("src.sys.mission_outcome").finished(session) and not session.pendingHuntEscape, "Mission unavailable")
    assert(not session.attackFeedback and not session.talentFeedback, "Attacks are resolving")
    if session.activeAgentId == id then return end
    assert(not session.activeAgentId and not Status.isExhausted(session.agentStatus, id), "Invalid activation")
    local controlMill = require("src.sys.location_control_milling").prepare(session, id)
    session.agentCards:commitHand(id, staged)
    session.activeAgentId = id
    require("src.sys.location_control_milling").commit(session, controlMill)
    require("src.sys.location_card_state").engageAt(session, id)
end

-- Done starts the required tests before the turn-ending status and attacks.
function Turn.prepare(session, id)
    if session.activeAgentId ~= id or session.attackFeedback or session.talentFeedback
        or Status.isExhausted(session.agentStatus, id) then return nil, "AGENT UNAVAILABLE" end
    local pending = session.pendingEndTurn
    if not pending then
        local spawn = require("src.sys.clash_reinforcements").prepare(session, id)
        if spawn then
            return { status = {}, result = { reinforcement = true }, provokingKind = false,
                publish = function() return require("src.sys.clash_reinforcements").commit(session, spawn) end }
        end
    end
    local clash, cell = Clashes.ready(session, id)
    if clash then
        if pending then return nil, "FINISH THE PENDING CLASH" end
        return { status = {}, result = { clash = clash }, provokingKind = false, publish = function()
            if session.pendingEndTurn or Clashes.ready(session, id) ~= clash then return false end
            session.pendingEndTurn = { agentId = id, cell = cell }
            return true
        end }
    end
    return { endsTurn = true, status = { exhausted = true, actionPoints = 0 },
        result = true, publish = function()
            if session.pendingEndTurn ~= pending or Clashes.ready(session, id) then return false end
            session.pendingEndTurn = nil
            return true
        end }
end
function Turn.finish(session, id)
    return require("src.sys.agent_action_resolution").execute(session, id, "end_turn", {})
end

function Turn.prepareRefresh(session)
    if require("src.sys.mission_outcome").finished(session) or session.pendingHuntEscape then return false end
    if session.activeAgentId or session.attackFeedback or session.talentFeedback or session.phaseTransition then return false end
    if not Status.allExhausted(session.agentStatus) then return false end
    local gain = require("data.agent_status_defaults").phaseResourceGain
    assert(type(gain) == "number" and gain >= 0 and gain < math.huge and gain % 1 == 0, "Invalid phase resource gain")
    local staged = {}
    for id, state in pairs(session.agentStatus.byAgent) do
        if not Status.isDefeatedState(state) then
            local resources = state.resources + gain
            assert(resources < math.huge and type(state.actionPointCapacity) == "number"
                and state.actionPointCapacity >= 0 and state.actionPointCapacity < math.huge
                and state.actionPointCapacity % 1 == 0, "Invalid phase refresh state")
            staged[id] = { resources = resources }
        end
    end
    return staged
end
function Turn.commitRefresh(session, staged)
    -- Everything that can fail is prepared before any live state changes.
    for id, nextState in pairs(staged) do
        local state = session.agentStatus.byAgent[id]
        state.resources, state.actionPoints, state.exhausted = nextState.resources, state.actionPointCapacity, false
    end
    require("src.sys.location_card_state").readyAll(session)
    return true
end
function Turn.refreshAll(session)
    local staged = Turn.prepareRefresh(session)
    if not staged then return false end
    return Turn.commitRefresh(session, staged)
end
return Turn
