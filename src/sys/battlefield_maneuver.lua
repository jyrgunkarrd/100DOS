local Topology = require("src.sys.board_topology")
local Maneuver = {}
function Maneuver.begin(session, agentId, cell)
    session.pendingManeuver = { agentId = agentId, cell = cell, armies = session.armies,
        revision = session.armies.revision }
end
function Maneuver.valid(session, pending)
    return not require("src.sys.mission_outcome").finished(session) and pending and session.pendingManeuver == pending and session.activeAgentId == pending.agentId
        and session.agentDeployment.placements[pending.agentId] == pending.cell
        and not require("src.sys.agent_status").isExhausted(session.agentStatus, pending.agentId)
        and session.armies == pending.armies and session.armies.revision == pending.revision
end
function Maneuver.targets(session, pending, source)
    if not Maneuver.valid(session, pending) then return {} end
    if source == session.armies.jaclCellId then return { pending.cell } end
    if source == pending.cell then return Topology.locations(session, source) end
    return {}
end
function Maneuver.commit(session, pending, source, destination, unitId)
    if session.attackFeedback or session.talentFeedback then return false, "WAIT FOR THE TEST AND ATTACKS" end
    if not Maneuver.valid(session, pending) then return false, "MANEUVER CHANGED" end
    local legal = false
    for _, cell in ipairs(Maneuver.targets(session, pending, source)) do if cell == destination then legal = true end end
    if not legal then return false, "CHOOSE A HIGHLIGHTED DESTINATION" end
    local unit
    for _, candidate in ipairs(session.armies.byCell[source].allied.forces) do
        if candidate.id == unitId then unit = candidate; break end
    end
    if not unit then return false, "FORCE NO LONGER AVAILABLE" end
    require("src.sys.battlefield_state").transfer(session.armies, source, destination, unitId)
    session.pendingManeuver = nil
    session.actionRevision = (session.actionRevision or 0) + 1
    return true, { unitId = unit.id, forceId = unit.forceId, fromCell = source, toCell = destination }
end
function Maneuver.decline(session, pending)
    if pending and session.pendingManeuver == pending then
        session.pendingManeuver = nil
        session.actionRevision = (session.actionRevision or 0) + 1
    end
end
return Maneuver
