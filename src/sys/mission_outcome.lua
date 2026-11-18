local Outcome = {}
local function clearPending(session)
    session.reinforcementFeedback = nil
    session.pendingHuntEscape, session.huntPresentation = nil, nil
    session.pendingEndTurn, session.pendingManeuver, session.phaseTransition = nil, nil, nil
    session.activeAgentId, session.attackFeedback, session.talentFeedback = nil, nil, nil
end
function Outcome.finished(session) return session and session.missionOutcome ~= nil end
function Outcome.victory(session, card)
    if Outcome.finished(session) then return false end
    session.missionOutcome = { kind = "victory", championId = card.cardId, instanceId = card.instanceId }
    clearPending(session)
    return true
end
function Outcome.failure(session, reason)
    if Outcome.finished(session) then return false end
    session.missionOutcome = { kind = "failure", reason = reason }
    clearPending(session)
    return true
end
return Outcome
