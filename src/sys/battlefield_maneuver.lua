local Topology = require("src.sys.board_topology")
local State = require("src.sys.battlefield_state")
local EngagementRecord = require("src.sys.battlefield_engagement_record")
local Triggers = require("src.sys.force_triggers")
local CardEntry = require("src.sys.location_card_entry")
local Receipt = require("src.sys.milling_receipt")
local Rules = require("data.battlefield_rules")
local Maneuver = {}
function Maneuver.begin(session, agentId, cell, margin, random)
    session.pendingManeuver = { agentId = agentId, cell = cell, armies = session.armies,
        revision = session.armies.revision, margin = margin, random = random }
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
    local armies = session.armies
    local definition = armies.catalogue.byId[unit.forceId]
    local enemy = armies.byCell[destination].enemy
    local target, amount = Triggers.afterManeuver(definition, pending.margin, enemy.forces, pending.random)
    local damage, mill, receipt
    local decks = session.locationDecks
    if target then
        damage = State.prepareDamage(armies, destination, "enemy", amount, target.id)
        local kills = #damage.removed
        if kills > 0 then
            mill = decks:prepareMill(destination, kills * Rules.cardsMilledPerEnemyEliminated)
            for index, card in ipairs(mill.entered) do
                local entry = { card = card, inPlay = mill.inPlay }
                CardEntry.prepare(session, destination, entry, pending.agentId)
                mill.entered[index] = entry.card
            end
            receipt = Receipt.new(decks, destination, mill, "maneuver", kills)
            if not decks:canCommitMill(destination, mill) then return false, "MANEUVER CHANGED" end
        end
    end
    -- Resolve the move and its staged consequences together before returning any feedback.
    State.transfer(armies, source, destination, unitId)
    local hit
    if damage then
        local before = EngagementRecord.capture(armies, destination)
        State.commitDamage(armies, damage)
        hit = EngagementRecord.complete(before, EngagementRecord.capture(armies, destination), {
            enemy = { damage = amount, removed = damage.removed, absorbed = damage.absorbed,
                replacements = damage.replacements },
            allied = { damage = 0, removed = {}, absorbed = 0 },
        })
        hit.battlefieldKind, hit.agentId = "maneuver", pending.agentId
        hit.name = session.locations.byId[session.assignments[destination]].name
        hit.sourceName = definition.name or unit.forceId
        hit.targetName = armies.catalogue.byId[target.forceId].name or target.forceId
        hit.milling = receipt
    end
    session.pendingManeuver = nil
    session.actionRevision = (session.actionRevision or 0) + 1
    if mill then
        assert(decks:commitMill(destination, mill))
        for _, card in ipairs(mill.entered) do CardEntry.committed(session, destination, card) end
        decks.byCell[destination].lastMilling = receipt
    end
    return true, { unitId = unit.id, forceId = unit.forceId, fromCell = source, toCell = destination,
        hit = hit, milling = receipt }
end
function Maneuver.decline(session, pending)
    if pending and session.pendingManeuver == pending then
        session.pendingManeuver = nil
        session.actionRevision = (session.actionRevision or 0) + 1
    end
end
return Maneuver
