return function()
    local Assets, Play = require("src.sys.agent_assets"), require("src.sys.card_play")
    local slots = require("data.agent_equipment_slots")
    local definitions = { byId = {
        asset = { card_type = "ASSET", cost = 4, asset_slots = 2, health = 2, defiance = 3 },
        free = { card_type = "ASSET", cost = 0, asset_slots = 1 },
        other = { card_type = "ACTION", cost = 1 },
        huge = { card_type = "ASSET", cost = 0, asset_slots = 8 },
    } }
    local function fresh()
        return { activeAgentId = "a", agentCards = { definitions = definitions, byAgent = {
            a = { hand = { { instanceId = 1, cardId = "asset" }, { instanceId = 2, cardId = "asset" },
                { instanceId = 3, cardId = "free" }, { instanceId = 4, cardId = "other" }, { instanceId = 5, cardId = "huge" } }, drawPile = {} },
            b = { hand = {}, drawPile = {} } } },
            agentStatus = { byAgent = { a = { resources = 4, actionPoints = 3, actionPointCapacity = 3 },
                b = { resources = 5, actionPoints = 3, actionPointCapacity = 3 } } },
            agentAssets = Assets.new({ "a", "b" }, slots) }
    end
    local s = fresh()
    assert(Play.evaluate(s, "a", 1).valid)
    assert(not Play.commit(s, "a", 1, nil) and s.agentStatus.byAgent.a.resources == 4)
    assert(Play.commit(s, "a", 1, 2))
    assert(s.agentStatus.byAgent.a.resources == 0 and s.agentStatus.byAgent.a.actionPoints == 2)
    assert(#s.agentCards.byAgent.a.hand == 4 and s.agentCards.byAgent.a.hand[1].instanceId == 2)
    local asset = s.agentAssets:at("a", 2)
    assert(asset == s.agentAssets:at("a", 3) and asset.instanceId == 1 and asset.health == 2 and asset.defiance == 3)
    assert(not s.agentAssets:at("b", 2) and s.agentStatus.byAgent.b.resources == 5)
    assert(not Play.commit(s, "a", 1, 4), "Repeated release cannot charge twice")
    assert(not Play.commit(s, "a", 2, 4) and s.agentStatus.byAgent.a.resources == 0)
    assert(s.agentStatus.byAgent.a.actionPoints == 2)
    assert(Play.commit(s, "a", 3, 1) and s.agentStatus.byAgent.a.resources == 0)
    assert(s.agentStatus.byAgent.a.actionPoints == 1 and s.agentStatus.byAgent.a.actionPointCapacity == 3)
    assert(not Play.evaluate(s, "a", 4).valid and not Play.evaluate(s, "a", 5).valid)
    s = fresh()
    for _, i in ipairs({ 2, 4, 6 }) do s.agentAssets.byAgent.a.occupied[slots[i].id] = {} end
    assert(not Play.evaluate(s, "a", 1).valid, "Fragmented space is not a valid footprint")
    assert(not Play.commit(s, "a", 1, 1) and #s.agentCards.byAgent.a.hand == 5 and s.agentStatus.byAgent.a.resources == 4)
    assert(s.agentStatus.byAgent.a.actionPoints == 3)
    s = fresh()
    s.agentAssets.byAgent.a.occupied[slots[2].id] = {}
    assert(Play.evaluate(s, "a", 1).valid and not Play.evaluate(s, "a", 1, 1).valid)
    assert(not Play.commit(s, "a", 1, 7))
    -- Eligibility must be recomputed at drop, not trusted from the drag start.
    assert(Play.evaluate(s, "a", 1, 4).valid)
    s.agentStatus.byAgent.a.resources = 3
    assert(not Play.commit(s, "a", 1, 4) and #s.agentCards.byAgent.a.hand == 5)
    assert(s.agentStatus.byAgent.a.actionPoints == 3)
    s = fresh()
    s.agentStatus.byAgent.a.actionPoints = 1
    assert(Play.commit(s, "a", 3, 1) and s.agentStatus.byAgent.a.actionPoints == 0)
    assert(s.agentStatus.byAgent.a.resources == 4 and s.agentStatus.byAgent.b.actionPoints == 3)
    assert(Play.evaluate(s, "a", 1, 3).reason == "NO ACTION POINTS")
    assert(not Play.commit(s, "a", 1, 3) and #s.agentCards.byAgent.a.hand == 4)
    s = fresh()
    assert(Play.evaluate(s, "a", 3, 1).valid)
    s.agentStatus.byAgent.a.actionPoints = 0
    assert(not Play.commit(s, "a", 3, 1), "Free cards still need an action; recheck at drop")
    assert(#s.agentCards.byAgent.a.hand == 5 and #s.agentAssets.byAgent.a.placements == 0
        and s.agentStatus.byAgent.a.resources == 4)
    local source = { agentAssets = s.agentAssets }
    local session = require("src.sys.mission_session").take(source)
    assert(session.agentAssets == s.agentAssets and not source.agentAssets)
end
