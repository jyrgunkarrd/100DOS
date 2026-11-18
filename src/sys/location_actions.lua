local A = {}
local Rules = require("data.location_actions")
function A.tests(kind)
    local r = assert(Rules.actions[kind], "Unknown location action")
    local whole = require("src.sys.location_deck_recipe").whole
    assert(whole(r.actionPointCost) and r.actionPointCost > 0 and whole(r.difficulty)
        and whole(r.count) and r.count > 0, "Invalid location action numbers")
    assert(require("data.talent_test_rules").talents[r.talent], "Invalid location action talent")
    return {{ id = kind, kind = kind, talent = r.talent, value = r.difficulty, label = r.talent:upper() }}
end
function A.available(s, id, kind)
    local r, status = Rules.actions[kind], s.agentStatus.byAgent[id]
    local function no(reason) return { valid = false, reason = reason } end
    if not r or require("src.sys.mission_outcome").finished(s) then return no("Action unavailable") end
    if s.activeAgentId ~= id or require("src.sys.agent_status").isExhausted(s.agentStatus,id)
        or s.attackFeedback or s.talentFeedback or s.pendingManeuver or s.pendingEndTurn then return no("Agent unavailable") end
    if status.actionPoints < r.actionPointCost then return no("Requires " .. r.actionPointCost .. " AP") end
    local cell = s.agentDeployment.placements[id]
    local deck = s.locationDecks.byCell[cell]
    if not deck or (kind == "charm" and #deck.drawPile == 0) then return no("Location deck empty") end
    return { valid = true, rule = r, status = status, cell = cell, deck = deck }
end
function A.evaluate(s,id,args)
    local v = A.available(s,id,args.locationKind)
    if not v.valid then return nil,v.reason end
    v.test = A.tests(args.locationKind)[1]
    if args.testId ~= v.test.id then return nil,"CHOOSE A TEST" end
    local c,reason = require("src.sys.talent_commitments").evaluate(s,id,v.test.talent,args.committedIds,args.bonusCounts)
    if not c then return nil,reason end
    for k,x in pairs(c) do v[k] = x end
    require("src.sys.fate_draw").validate(s.fatePool)
    return v
end
function A.prepare(s,id,args)
    local v,reason = A.evaluate(s,id,args)
    if not v then return nil,reason end
    local hand,discard,before,beforeDiscard = {},{},{},{}
    for i,card in ipairs(v.handState.discardPile or {}) do discard[i],beforeDiscard[i] = card,card end
    for i,card in ipairs(v.handState.hand) do
        before[i] = card
        local target = v.selected[card.instanceId] and discard or hand
        target[#target+1] = card
    end
    local tile = args.locationKind == "ingenuity" and assert(require("data.fate_tiles.index").refresh().byId[v.rule.tileId])
    if tile then require("src.sys.fate_tile_definition").validate(tile,tile.id); assert(tile.bonus) end
    local revision = v.deck.revision
    local result = { battlefield = true, locationAction = true, agentId = id, cell = v.cell,
        locationId = s.assignments[v.cell], name = v.rule.label, test = v.test }
    return { result = result, provokingKind = "talent_test",
        status = { actionPoints = v.status.actionPoints - v.rule.actionPointCost },
        publish = function()
            if s.agentCards.byAgent[id] ~= v.handState or v.deck.revision ~= revision
                or #v.handState.hand ~= #before or #(v.handState.discardPile or {}) ~= #beforeDiscard then return false end
            for i,card in ipairs(beforeDiscard) do if v.handState.discardPile[i] ~= card then return false end end
            local current = A.evaluate(s,id,args)
            if not current or current.base ~= v.base or current.bonus ~= v.bonus then return false end
            for i,card in ipairs(before) do if v.handState.hand[i] ~= card then return false end end
            local effect = require("src.sys.fate_reveal").prepare(s,result,v.base,v.bonus,v.test.value,args.random)
            v.handState.hand,v.handState.discardPile = hand,discard
            result.summary = "NO EFFECT"
            if result.success then
                if tile then
                    require("src.sys.fate_reserve").add(s.fatePool,tile,v.rule.count,"INGENUITY")
                    result.summary = "+" .. v.rule.count .. " GENIUS / BONUS RESERVE"
                else
                    local revealed,entered = s.locationDecks:charm(v.cell,v.rule.count,s)
                    result.summary = revealed .. " REVEALED / " .. entered .. " ENTERED PLAY"
                end
            end
            require("src.sys.fate_reveal").commit(effect)
            s.talentFeedback = result
            return true
        end }
end
return A
