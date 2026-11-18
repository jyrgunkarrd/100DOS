local Rules = require("data.battlefield_rules")
local Tests = require("src.sys.battlefield_tests")
local State = require("src.sys.battlefield_state")
local Topology = require("src.sys.board_topology")
local Fate = require("src.sys.fate_draw")
local Reveal = require("src.sys.fate_reveal")
local Clashes = require("src.sys.battlefield_clashes")
local Action = {}
function Action.available(session, agentId, kind, clash)
    if require("data.jacl_actions").actions[kind] then return require("src.sys.jacl_actions").available(session, agentId, kind, clash) end
    local status = session.agentStatus and session.agentStatus.byAgent[agentId]
    local function no(reason) return { valid = false, reason = reason } end
    if require("src.sys.mission_outcome").finished(session) then return no("Mission complete") end
    if session.pendingManeuver then return no("FINISH THE PENDING MANEUVER") end
    if not Rules.actions[kind] then return no("Unknown battlefield action") end
    if not status or session.activeAgentId ~= agentId or require("src.sys.agent_status").isExhausted(session.agentStatus, agentId)
        or session.attackFeedback or session.talentFeedback then return no("Agent unavailable") end
    local armies, cell = session.armies, session.agentDeployment.placements[agentId]
    local pending = session.pendingEndTurn
    if clash then
        if kind ~= "engage" or not pending or pending.agentId ~= agentId or pending.cell ~= cell
            or Clashes.ready(session, agentId) ~= clash then return no("Clash changed") end
    elseif pending then
        return no("Finish the pending clash")
    elseif status.actionPoints < Rules.actionPointCost then
        return no("No action points")
    end
    if not armies or cell == armies.jaclCellId then return no("No battlefield actions here") end
    local pair = armies.byCell[cell]
    local location = session.locations and session.locations.byId[session.assignments[cell]]
    if not pair or not location or #Tests.resolve(location, kind) == 0 then return no("No battlefield tests") end
    if (kind == "engage" or kind == "entrench") and #pair.allied.forces == 0 then return no("No allied forces") end
    if kind == "engage" and #pair.enemy.forces == 0 then return no("No enemy forces") end
    if kind == "entrench" and pair.protection >= Rules.shieldCap then return no("Protection already full") end
    if kind == "maneuver" then
        local reserve = armies.byCell[armies.jaclCellId]
        if not (#pair.allied.forces > 0 and #Topology.locations(session, cell) > 0)
            and not (reserve and #reserve.allied.forces > 0) then return no("No forces to maneuver") end
    end
    return { valid = true, cell = cell, pair = pair, location = location, status = status }
end
function Action.evaluate(session, agentId, args)
    if require("data.jacl_actions").actions[args.battlefieldKind] then return require("src.sys.jacl_actions").evaluate(session, agentId, args) end
    local value = Action.available(session, agentId, args.battlefieldKind, args.clash)
    if not value.valid then return nil, value.reason end
    local kind = args.battlefieldKind
    if kind == "engage" then require("src.sys.battlefield_engagement").validate() end
    for _, test in ipairs(Tests.resolve(value.location, kind, args.clash and args.clash.difficulty)) do
        if test.id == args.testId then value.test = test end
    end
    if not value.test then return nil, "CHOOSE A TEST" end
    local commitments, reason = require("src.sys.talent_commitments").evaluate(session, agentId, value.test.talent, args.committedIds, args.bonusCounts)
    if not commitments then return nil, reason end
    for key, entry in pairs(commitments) do value[key] = entry end
    Fate.validate(session.fatePool)
    return value
end
function Action.prepare(session, agentId, args)
    if require("data.jacl_actions").actions[args.battlefieldKind] then return require("src.sys.jacl_actions").prepare(session, agentId, args) end
    local value, reason = Action.evaluate(session, agentId, args)
    if not value then return nil, reason end
    -- Own the target selection so later UI changes cannot retarget a prepared action.
    local input = {}; for key, value in pairs(args) do input[key] = value end
    input.committedIds = {}; for i, id in ipairs(args.committedIds or {}) do input.committedIds[i] = id end
    args = input
    local armies, revision, pool = session.armies, session.armies.revision, session.fatePool
    local hand, discard, beforeHand, beforeDiscard = {}, {}, {}, {}
    for i, card in ipairs(value.handState.discardPile or {}) do discard[i], beforeDiscard[i] = card, card end
    for i, card in ipairs(value.handState.hand) do
        beforeHand[i] = card
        local target = value.selected[card.instanceId] and discard or hand
        target[#target + 1] = card
    end
    local function same(a, b)
        if #a ~= #b then return false end
        for i, v in ipairs(a) do if b[i] ~= v then return false end end
        return true
    end
    local kind = args.battlefieldKind
    local engagement, choices, decks
    if kind == "engage" then
        engagement, choices, decks = require("src.sys.battlefield_engagement"), {}, session.locationDecks
        local rate = Rules.cardsMilledPerEnemyEliminated
        assert(type(rate) == "number" and rate >= 0 and rate < math.huge and rate % 1 == 0, "Invalid milling rate")
        -- Prepare both outcomes before Fate or any publication. No partial army/deck commits.
        for _, success in ipairs({ true, false }) do
            local army = engagement.prepare(armies, value.cell, success, args.clash and args.clash.damage)
            local kills = #army.result.sides.enemy.removed
            local mill = decks:prepareMill(value.cell, kills * rate)
            for i, card in ipairs(mill.entered) do
                local entry = { card = card, inPlay = mill.inPlay }
                require("src.sys.location_card_entry").prepare(session, value.cell, entry, agentId)
                mill.entered[i] = entry.card
            end
            local receipt = require("src.sys.milling_receipt").new(decks, value.cell, mill, "forces", kills)
            army.result.milling = receipt
            choices[success] = { army = army, mill = mill, receipt = receipt }
        end
    end
    local result = { battlefield = true, agentId = agentId, name = value.location.name,
        test = value.test, cell = value.cell, battlefieldKind = kind, locationId = session.assignments[value.cell],
        clash = args.clash and true }
    return { result = result, provokingKind = not args.clash and "battlefield_" .. kind,
        status = { actionPoints = value.status.actionPoints - (args.clash and 0 or Rules.actionPointCost) },
        publish = function()
            if session.armies ~= armies or armies.revision ~= revision or session.fatePool ~= pool
                or session.agentCards.byAgent[agentId] ~= value.handState
                or not same(value.handState.hand, beforeHand) or not same(value.handState.discardPile or {}, beforeDiscard) then return false end
            local current = Action.evaluate(session, agentId, args)
            if not current or current.cell ~= value.cell or current.unit ~= value.unit
                or current.base ~= value.base or current.bonus ~= value.bonus or current.test.value ~= value.test.value then return false end
            if choices then
                if session.locationDecks ~= decks then return false end
                for _, choice in pairs(choices) do
                    if not engagement.canCommit(choice.army) or not decks:canCommitMill(value.cell, choice.mill) then return false end
                end
            end
            local effect = Reveal.prepare(session, result, value.base, value.bonus, value.test.value, args.random)
            if kind == "engage" then
                local choice = choices[result.success]
                -- Both plans validated above; synchronous publication cannot interleave.
                assert(decks:commitMill(value.cell, choice.mill))
                for _, card in ipairs(choice.mill.entered) do
                    require("src.sys.location_card_entry").committed(session, value.cell, card)
                end
                local exchange = assert(engagement.commit(choice.army))
                decks.byCell[value.cell].lastMilling = choice.receipt
                for key, entry in pairs(exchange) do result[key] = entry end
                if args.clash then Clashes.consume(value.pair, args.clash) end
            elseif kind == "entrench" then
                if result.success then State.entrench(armies, value.cell) end
                result.summary = result.success and ("ALLIED PROTECTION SET TO " .. armies.byCell[value.cell].protection) or "PROTECTION UNCHANGED"
            else
                if result.success then require("src.sys.battlefield_maneuver").begin(session, agentId, value.cell) end
                result.summary = result.success and "CHOOSE ONE FORCE TO MANEUVER" or "NO FORCES MOVED"
            end
            value.handState.hand, value.handState.discardPile = hand, discard
            Reveal.commit(effect)
            session.talentFeedback = result
            return true
        end }
end
return Action
