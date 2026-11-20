local Status = require("src.sys.agent_status")
local Opportunity = require("src.sys.opportunity_attacks")
local Attack = require("src.sys.attack_resolution")
local Engagement = require("src.sys.location_engagement")
local Cost = require("src.sys.fate_bonus_cost")
local Resolution = {}
function Resolution.prepare(session, agentId, kind, args)
    local owned = {}; for key,value in pairs(args or {}) do owned[key] = value end
    for _,key in ipairs({"committedIds", "bonusCounts", "exhaustIds"}) do
        if type(owned[key]) == "table" then
            local snapshot = {}; for k,v in pairs(owned[key]) do snapshot[k] = v end; owned[key] = snapshot
        end
    end
    args = owned
    if session.reinforcementFeedback then return nil, "REINFORCEMENTS ARRIVING" end
    if require("src.sys.mission_outcome").finished(session) then return nil, "MISSION COMPLETE" end
    if session.pendingManeuver then return nil, "FINISH THE PENDING MANEUVER" end
    local status = session.agentStatus and session.agentStatus.byAgent[agentId]
    if not status or session.activeAgentId ~= agentId or Status.isExhausted(session.agentStatus, agentId)
        or session.attackFeedback or session.talentFeedback then return nil, "AGENT UNAVAILABLE" end
    if session.pendingEndTurn and kind ~= "end_turn" and (kind ~= "battlefield" or not args.clash) then
        return nil, "FINISH THE PENDING CLASH"
    end
    if args.exhaustIds ~= nil and (type(args.exhaustIds) ~= "table"
        or (next(args.exhaustIds) and kind ~= "talent_test")) then
        return nil, "INVALID ASSET SELECTION"
    end
    local reserve = require("src.sys.fate_reserve")
    local selection, bonusReason = reserve.evaluate(session.fatePool, args.bonusCounts)
    if not selection then return nil, bonusReason end
    local bonusBefore = {}
    for i, entry in ipairs(reserve.entries(session.fatePool)) do bonusBefore[i] = entry end
    local module = kind == "explore" and "src.sys.location_exploration" or kind == "play_card" and "src.sys.card_play"
        or kind == "location_action" and "src.sys.location_actions"
        or kind == "talent_test" and "src.sys.talent_test_action"
        or kind == "battlefield" and "src.sys.battlefield_action"
        or kind == "end_turn" and "src.sys.agent_turn"
    local basic = kind == "move" or kind == "draw_card" or kind == "gain_resource"
    if kind == "asset_ability" then module = "src.sys.asset_abilities" end
    if basic then module = "src.sys.agent_basic_actions" end
    assert(module, "Unknown Agent action")
    -- Snapshot attackers before preparing the action, excluding newly revealed Enemies.
    local action, reason = require(module).prepare(session, agentId, args, kind)
    if not action then return nil, reason end
    local isTest = kind == "talent_test" or kind == "battlefield" or kind == "location_action"
    if not isTest and next(selection.counts) then return nil, "BONUS TILES REQUIRE A TEST" end
    local payment, costReason = Cost.stage(status, selection.cost)
    if not payment then return nil, costReason end
    for key, value in pairs(payment) do action.status[key] = value end
    local poolBefore = session.fatePool
    local publish = action.publish
    if isTest then action.publish = function()
        if session.fatePool ~= poolBefore then return false end
        local current = reserve.entries(session.fatePool)
        if #current ~= #bonusBefore then return false end
        for i, entry in ipairs(bonusBefore) do if current[i] ~= entry then return false end end
        if not publish() then return false end
        if session.fatePool then reserve.consume(session.fatePool, selection) end
        if type(action.result) == "table" then
            action.result.reserveBonus = selection.value
            if next(payment) then action.result.reserveCost = selection.cost end
        end
        return true
    end end
    local requests = action.provokingKind == false and {} or Opportunity.collect(session, agentId, action.provokingKind or kind)
    local stagedStatus, before = {}, {}
    for key, value in pairs(status) do stagedStatus[key], before[key] = value, value end
    for key, value in pairs(action.status) do stagedStatus[key] = value end
    -- Without protection this is the maximum possible harm. UI can stage its defeat transition safely.
    local final, events = Attack.resolve(stagedStatus, requests)
    local deckRevisions = {}
    if session.locationDecks then
        for cell, deck in pairs(session.locationDecks.byCell) do deckRevisions[cell] = { deck = deck, revision = deck.revision } end
    end
    local placement = session.agentDeployment and session.agentDeployment.placements[agentId]
    return { session = session, agentId = agentId, kind = kind, revision = session.actionRevision or 0,
        requests = requests, stagedStatus = stagedStatus, harmRandom = args.harmRandom,
        before = before, action = action, status = final, events = events, deckRevisions = deckRevisions, placement = placement }
end
function Resolution.commit(plan)
    if not plan or plan.committed then return false, "ACTION ALREADY COMMITTED" end
    local s, id = plan.session, plan.agentId
    if s.reinforcementFeedback then return false, "REINFORCEMENTS ARRIVING" end
    if require("src.sys.mission_outcome").finished(s) or s.pendingManeuver or (s.actionRevision or 0) ~= plan.revision or s.activeAgentId ~= id or s.attackFeedback or s.talentFeedback then return false, "ACTION CHANGED" end
    local status = s.agentStatus.byAgent[id]
    if Status.isExhausted(s.agentStatus, id) then return false, "AGENT UNAVAILABLE" end
    if (s.agentDeployment and s.agentDeployment.placements[id]) ~= plan.placement then return false, "AGENT MOVED" end
    for cell, snapshot in pairs(plan.deckRevisions) do
        local deck = s.locationDecks.byCell[cell]
        if deck ~= snapshot.deck or deck.revision ~= snapshot.revision then return false, "LOCATION CHANGED" end
    end
    for key, value in pairs(plan.before) do if status[key] ~= value then return false, "AGENT CHANGED" end end
    if not plan.action.publish() then return false, "ACTION CHANGED" end
    -- A lethal champion hit wins before queued retaliation or Fate clash effects.
    if require("src.sys.mission_outcome").finished(s) then
        for key, value in pairs(plan.action.status) do status[key] = value end
        s.activeAgentId, s.attackFeedback, s.pendingEndTurn, s.pendingManeuver = nil, nil, nil, nil
        plan.status = status
        plan.events, plan.committed = {}, true
        s.actionRevision = plan.revision + 1
        return true, plan.action.result
    end
    -- The action may have equipped, exhausted or removed a card. Roll only after it succeeds.
    local board = s.agentAssets and s.agentAssets.byAgent[id]
    if #plan.requests > 0 and board and #board.placements > 0 then
        local placements = {}
        for i, placement in ipairs(board.placements) do
            local snapshot = {}
            for key, value in pairs(placement) do snapshot[key] = value end
            placements[i] = snapshot
        end
        plan.status, plan.events = Attack.resolve(plan.stagedStatus, plan.requests, placements, plan.harmRandom)
        s.agentAssets:applyHarm(id, plan.events, s.agentCards.byAgent[id], s.agentCards.definitions)
    end
    for key, value in pairs(plan.status) do status[key] = value end
    if status.defeated then
        s.pendingManeuver, s.pendingEndTurn = nil, nil
        if type(plan.action.result) == "table" and plan.action.result.battlefieldKind == "maneuver" and plan.action.result.success then
            plan.action.result.summary = "MANEUVER LOST - AGENT DEFEATED"
        end
        Engagement.clearTarget(s, id); s.activeAgentId = nil
    end
    if plan.action.endsTurn then s.activeAgentId = nil end
    if plan.action.endsTurn or status.defeated then
        status.turnTalentBonuses = nil
        require("src.sys.mission_hunt").queueEscape(s)
    end
    plan.committed = true
    s.actionRevision = plan.revision + 1
    if #plan.events > 0 then s.attackFeedback = { agentId = id, kind = plan.kind, events = plan.events, defeated = status.defeated == true } end
    return true, plan.action.result, s.attackFeedback
end
function Resolution.execute(session, id, kind, args)
    local plan, reason = Resolution.prepare(session, id, kind, args)
    if not plan then return false, reason end
    return Resolution.commit(plan)
end
return Resolution
