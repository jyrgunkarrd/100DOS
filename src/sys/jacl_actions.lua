local Rules = require("data.jacl_actions")
local State = require("src.sys.battlefield_state")
local Record = require("src.sys.battlefield_engagement_record")
local Reveal = require("src.sys.fate_reveal")
local Action = {}
local function copy(t) local r = {}; for k, v in pairs(t or {}) do r[k] = v end; return r end
local function same(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do if b[i] ~= v then return false end end
    return true
end
function Action.targets(s)
    local cells = {}
    for cell in pairs(s.assignments) do
        local pair = s.armies.byCell[cell]
        if cell ~= s.armies.jaclCellId and pair and #pair.enemy.forces > 0 then cells[#cells + 1] = cell end
    end
    table.sort(cells); return cells
end
function Action.available(s, id, kind, clash)
    local function no(reason) return { valid = false, reason = reason } end
    local rule, status = Rules.actions[kind], s.agentStatus and s.agentStatus.byAgent[id]
    if not rule or clash then return no("Invalid JACL action") end
    if require("src.sys.mission_outcome").finished(s) then return no("Mission complete") end
    if not status or s.activeAgentId ~= id or require("src.sys.agent_status").isExhausted(s.agentStatus, id)
        or s.attackFeedback or s.talentFeedback then return no("Agent unavailable") end
    if s.pendingManeuver or s.pendingEndTurn then return no("Finish pending action") end
    local cell = s.agentDeployment.placements[id]
    if not s.armies or cell ~= s.armies.jaclCellId then return no("Agent must be at JACL") end
    if status.actionPoints < rule.actionPointCost then return no("Requires " .. rule.actionPointCost .. " AP") end
    if kind == "security" and (s.jaclSecurity or 0) >= Rules.securityCap then return no("Security full") end
    local targets = Action.targets(s)
    if kind == "bombard" and #targets == 0 then return no("No enemy forces to bombard") end
    return { valid = true, status = status, cell = cell, targets = targets,
        location = s.locations.byId[s.assignments[cell]], rule = rule }
end
function Action.evaluate(s, id, args)
    local v = Action.available(s, id, args.battlefieldKind, args.clash)
    if not v.valid then return nil, v.reason end
    if args.battlefieldKind == "bombard" then
        local found = false
        for _, cell in ipairs(v.targets) do if cell == args.targetCell then found = true end end
        if not found then return nil, "Choose an enemy army" end
    end
    for _, test in ipairs(require("src.sys.battlefield_tests").resolve(v.location, args.battlefieldKind)) do
        if test.id == args.testId then v.test = test end
    end
    if not v.test then return nil, "CHOOSE A TEST" end
    local committed, reason = require("src.sys.talent_commitments").evaluate(s, id, v.test.talent, args.committedIds, args.bonusCounts)
    if not committed then return nil, reason end
    for k, value in pairs(committed) do v[k] = value end
    require("src.sys.fate_draw").validate(s.fatePool)
    return v
end
function Action.prepare(s, id, input)
    local args = copy(input); args.committedIds = copy(input.committedIds)
    local v, reason = Action.evaluate(s, id, args)
    if not v then return nil, reason end
    local kind, armies, decks, hunt = args.battlefieldKind, s.armies, s.locationDecks, s.missionHunt
    local revision, security, huntRevision = armies.revision, s.jaclSecurity or 0, hunt and hunt.revision
    local fatePool = s.fatePool
    local beforeHand, beforeDiscard = copy(v.handState.hand), copy(v.handState.discardPile)
    local hand, discard = {}, copy(beforeDiscard)
    for _, card in ipairs(beforeHand) do local to = v.selected[card.instanceId] and discard or hand; to[#to + 1] = card end
    local snapshots = {}
    for cell, deck in pairs(decks.byCell) do snapshots[cell] = { deck = deck, revision = deck.revision } end
    local scan, mill, receipt
    if kind == "triangulate" then scan = decks:prepareScan(armies.jaclCellId)
    elseif kind == "bombard" then
        mill = decks:prepareMill(args.targetCell, require("data.battlefield_rules").cardsMilledPerEnemyEliminated)
        for i, card in ipairs(mill.entered) do
            local entry = { card = card, inPlay = mill.inPlay }
            require("src.sys.location_card_entry").prepare(s, args.targetCell, entry, id)
            mill.entered[i] = entry.card
        end
        receipt = require("src.sys.milling_receipt").new(decks, args.targetCell, mill, "bombardment", 1)
    end
    local result = { battlefield = true, jacl = true, battlefieldKind = kind, agentId = id,
        cell = v.cell, targetCell = args.targetCell, test = v.test, name = v.rule.label .. " - " .. v.location.name,
        locationId = s.assignments[v.cell] }
    local published = false
    return { result = result, provokingKind = "jacl_" .. kind,
        status = { actionPoints = v.status.actionPoints - v.rule.actionPointCost },
        publish = function()
            if published or s.armies ~= armies or armies.revision ~= revision or s.locationDecks ~= decks
                or s.fatePool ~= fatePool or (s.jaclSecurity or 0) ~= security or s.missionHunt ~= hunt
                or (hunt and hunt.revision ~= huntRevision) or s.agentCards.byAgent[id] ~= v.handState
                or not same(v.handState.hand, beforeHand) or not same(v.handState.discardPile or {}, beforeDiscard) then return false end
            for cell, snap in pairs(snapshots) do
                if decks.byCell[cell] ~= snap.deck or snap.deck.revision ~= snap.revision then return false end
            end
            local current = Action.evaluate(s, id, args)
            if not current or current.cell ~= v.cell or current.base ~= v.base or current.bonus ~= v.bonus
                or current.unit ~= v.unit then return false end
            local effect = Reveal.prepare(s, result, v.base, v.bonus, v.test.value, args.random)
            result.summary = "NO EFFECT"
            if result.success then
                if kind == "security" then
                    s.jaclSecurity = math.min(Rules.securityCap, security + v.rule.gain)
                    result.summary = "SECURITY " .. security .. " > " .. s.jaclSecurity .. " / " .. Rules.securityCap
                elseif kind == "triangulate" then
                    assert(decks:commitScan(scan, args.random))
                    result.scan = scan.results
                    local count = 0
                    for _, entry in ipairs(scan.results) do
                        if entry.card then
                            count = count + 1
                            if hunt then hunt.located[entry.card.instanceId] = entry.cell end
                        end
                    end
                    if hunt then hunt.revision = hunt.revision + 1 end
                    result.summary = count .. " TOP CARDS REVEALED"
                else
                    local pair = armies.byCell[args.targetCell]
                    local before = Record.capture(pair, armies.catalogue)
                    local index = args.random and args.random:random(#pair.enemy.forces) or love.math.random(#pair.enemy.forces)
                    local unit = State.removeForce(armies, args.targetCell, "enemy", pair.enemy.forces[index].id)
                    local exchange = Record.complete(before, Record.capture(pair, armies.catalogue), {
                        enemy = { damage = 1, absorbed = 0, removed = { unit } },
                        allied = { damage = 0, absorbed = 0, removed = {} } })
                    assert(decks:commitMill(args.targetCell, mill))
                    for _, card in ipairs(mill.entered) do require("src.sys.location_card_entry").committed(s, args.targetCell, card) end
                    decks.byCell[args.targetCell].lastMilling = receipt
                    for k, value in pairs(exchange) do result[k] = value end
                    result.milling, result.locationId = receipt, s.assignments[args.targetCell]
                    result.name = decks.byCell[args.targetCell].locationName
                end
            end
            v.handState.hand, v.handState.discardPile = hand, discard
            Reveal.commit(effect); published = true; s.talentFeedback = result
            return true
        end }
end
return Action
