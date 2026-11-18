local Tests = require("src.sys.talent_tests")
local Fate = require("src.sys.fate_draw")
local Reveal = require("src.sys.fate_reveal")
local Rules = require("data.talent_test_rules")
local Effects = require("src.sys.location_card_effects")
local Action = {}

function Action.evaluate(session, agentId, args)
    if require("src.sys.mission_outcome").finished(session) then return nil, "MISSION COMPLETE" end
    local status = session.agentStatus and session.agentStatus.byAgent[agentId]
    if not status or session.activeAgentId ~= agentId or require("src.sys.agent_status").isExhausted(session.agentStatus, agentId)
        or session.attackFeedback or session.talentFeedback then return nil, "AGENT UNAVAILABLE" end
    local cell = session.agentDeployment.placements[agentId]
    local deck = session.locationDecks.byCell[cell]
    local card = deck and deck.inPlay[args.instanceId]
    if not card then return nil, "CARD NO LONGER AT THIS LOCATION" end
    local definition = session.locationDecks.pool.byId[card.cardId]
    local test
    for _, candidate in ipairs(Tests.resolve(definition)) do if candidate.id == args.testId then test = candidate end end
    if not test then return nil, "CHOOSE A TEST" end
    local cost = Rules.actionPointCost
    assert(type(cost) == "number" and cost >= 1 and cost % 1 == 0 and cost < math.huge, "Invalid test action cost")
    if status.actionPoints < cost then return nil, "NO ACTION POINTS" end
    local commitments, reason = require("src.sys.talent_commitments").evaluate(session, agentId, test.talent, args.committedIds, args.bonusCounts)
    if not commitments then return nil, reason end
    local handState, selected, base, bonus = commitments.handState, commitments.selected, commitments.base, commitments.bonus
    Fate.validate(session.fatePool)
    if require("src.sys.location_card_traits").enemy(definition) then
        assert(type(card.health) == "number" and card.health > 0, "Invalid enemy runtime health")
    end
    return { card = card, definition = definition, test = test, cell = cell, deck = deck,
        handState = handState, selected = selected, base = base, bonus = bonus, cardBonus = commitments.cardBonus, reserveBonus = commitments.reserveBonus, cost = cost }
end

function Action.prepare(session, agentId, args)
    local value, reason = Action.evaluate(session, agentId, args)
    if not value then return nil, reason end
    local reward = value.test.kind == "interact" and Effects.prepareResolution(session, value.definition) or nil
    local hand, discard, beforeHand = {}, {}, {}
    for _, card in ipairs(value.handState.discardPile or {}) do discard[#discard + 1] = card end
    for i, card in ipairs(value.handState.hand) do
        beforeHand[i] = card
        local target = value.selected[card.instanceId] and discard or hand
        target[#target + 1] = card
    end
    local beforeHealth, beforeExhausted, beforeEngaged = value.card.health, value.card.exhausted, value.card.engagedAgentId
    local pool = session.fatePool
    local result = { agentId = agentId, cardId = value.card.cardId, instanceId = value.card.instanceId,
        name = value.definition.name, test = value.test, cell = value.cell,
        beforeHealth = beforeHealth, attackSound = session.agentCards.agents.byId[agentId].atk_sfx,
        defeatSound = value.definition.defeat_sfx }
    return { result = result, provokingKind = value.test.provokes and "talent_test" or value.test.kind,
        status = { actionPoints = session.agentStatus.byAgent[agentId].actionPoints - value.cost },
        publish = function()
            if not Effects.canResolve(session, reward) then return false end
            if session.agentCards.byAgent[agentId] ~= value.handState or session.fatePool ~= pool
                or value.deck.inPlay[value.card.instanceId] ~= value.card
                or value.card.health ~= beforeHealth or value.card.exhausted ~= beforeExhausted
                or value.card.engagedAgentId ~= beforeEngaged or #value.handState.hand ~= #beforeHand then return false end
            for i, card in ipairs(beforeHand) do if value.handState.hand[i] ~= card then return false end end
            -- Randomness occurs only after all stale-plan guards, immediately before publication.
            local effect = Reveal.prepare(session, result, value.base, value.bonus, value.test.value, args.random)
            value.handState.hand, value.handState.discardPile = hand, discard
            if result.success then
                if value.test.effect == "damage" then
                    value.card.health = math.max(0, value.card.health - value.test.damage)
                    result.health, result.defeated = value.card.health, value.card.health == 0
                    if result.defeated then require("src.sys.location_card_elimination").commit(session, value.cell, value.card.instanceId, args.random)
                    else value.deck.revision = value.deck.revision + 1 end
                elseif value.test.effect == "exhaust" then
                    value.card.exhausted, value.card.engagedAgentId = true, nil
                    value.deck.revision = value.deck.revision + 1
                else
                    Effects.resolve(session, reward, result)
                    session.locationDecks:discard(value.cell, value.card.instanceId)
                end
            end
            if not require("src.sys.mission_outcome").finished(session) then Reveal.commit(effect) end
            session.talentFeedback = result
            return true
        end }
end
return Action
