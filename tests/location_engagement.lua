return function()
    local Decks = require("src.sys.location_decks")
    local Explore = require("src.sys.location_exploration")
    local Engagement = require("src.sys.location_engagement")
    local rules = require("data.location_engagement_rules")
    local pool = { byId = { e = { card_type = "ENEMY", health = 2 }, b = { card_type = "BARRIER" } },
        byType = { ENEMY = { "e" }, BARRIER = { "b" } } }
    local decks = Decks.new({ west = "loc" }, { byId = { loc = { deck_size = 4,
        deck_build = { { type = "ENEMY", qty = 3 }, { type = "BARRIER", qty = 1 } } } } }, pool,
        love.math.newRandomGenerator(42))
    local session = { locationDecks = decks, activeAgentId = "a",
        agentDeployment = { placements = { a = "west", b = "west" } },
        agentStatus = { byAgent = { a = { actionPoints = 3, resources = 5, health = 6, defiance = 6 },
            b = { actionPoints = 3, resources = 5, health = 6, defiance = 6 } } } }
    local deck = decks.byCell.west
    local function top(kind)
        for i, card in ipairs(deck.drawPile) do
            if pool.byId[card.cardId].card_type == kind then
                deck.drawPile[i], deck.drawPile[#deck.drawPile] = deck.drawPile[#deck.drawPile], card; return card
            end
        end
        error("Missing fixture card")
    end
    local original = top("ENEMY")
    local staged = decks:prepareDraw("west")
    Engagement.prepare(session, "west", staged, "a", rules)
    assert(staged.card ~= original and staged.card.engagedAgentId == "a" and not original.engagedAgentId)
    assert(not pool.byId.e.engagedAgentId and Engagement.count(session, "a") == 0)
    local commit = decks.commitDraw
    decks.commitDraw = function() return false end
    assert(not Explore.commit(session, "a", { actionPointCost = 1 }))
    assert(not original.engagedAgentId and #deck.drawPile == 4 and session.agentStatus.byAgent.a.actionPoints == 3)
    decks.commitDraw = commit
    local enabled = rules.engageRevealerTypes.ENEMY
    rules.engageRevealerTypes.ENEMY = "invalid"
    assert(not pcall(Explore.commit, session, "a", { actionPointCost = 1 }))
    rules.engageRevealerTypes.ENEMY = enabled
    assert(not original.engagedAgentId and #deck.drawPile == 4 and Engagement.count(session, "a") == 0)
    local ok, first = Explore.commit(session, "a", { actionPointCost = 1 })
    assert(ok and first.engagedAgentId == "a" and Engagement.count(session, "a") == 1)
    top("ENEMY"); session.activeAgentId = "b"
    local ok, second = Explore.commit(session, "b", { actionPointCost = 1 })
    assert(ok and first.cardId == second.cardId and first.instanceId ~= second.instanceId)
    assert(first.engagedAgentId == "a" and second.engagedAgentId == "b")
    top("ENEMY"); assert(Explore.commit(session, "b", { actionPointCost = 1 }))
    assert(Engagement.count(session, "b") == 2)
    session.attackFeedback = nil -- Model-only check: acknowledge completed visual sequence.
    top("BARRIER"); local ok, barrier = Explore.commit(session, "b", { actionPointCost = 1 })
    assert(ok and not barrier.engagedAgentId and Engagement.count(session, "b") == 2)
    for _, state in pairs(session.agentStatus.byAgent) do
        assert(state.health == 6 and state.defiance == 6 and state.resources == 5)
        state.exhausted, state.actionPointCapacity = true, 3
    end
    session.attackFeedback = nil
    session.activeAgentId = nil
    assert(require("src.sys.agent_turn").refreshAll(session))
    assert(first.engagedAgentId == "a" and Engagement.count(session, "b") == 2)
    assert(decks:discard("west", first.instanceId) and not first.engagedAgentId and Engagement.count(session, "a") == 0)
    assert(not decks:discard("west", first.instanceId) and second.engagedAgentId == "b")
end
