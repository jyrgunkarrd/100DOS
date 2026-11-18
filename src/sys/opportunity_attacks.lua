local Engagement = require("src.sys.location_engagement")
local Attack = require("src.sys.attack_resolution")
local Opportunity = {}
function Opportunity.collect(session, agentId, kind)
    local rules = require("data.attack_rules")
    assert(type(rules.provokingActions) == "table", "Missing provoking action rules")
    for key, value in pairs(rules.provokingActions) do
        assert(type(key) == "string" and type(value) == "boolean", "Invalid provoking action rule")
    end
    local requests = {}
    if not rules.provokingActions[kind] then return requests end
    for _, entry in ipairs(Engagement.ordered(session, agentId)) do
        local card = entry.card
        local definition = assert(session.locationDecks.pool.byId[card.cardId], "Missing attacker definition")
        if require("src.sys.location_card_traits").enemy(definition) and not card.exhausted then
            requests[#requests + 1] = { instanceId = card.instanceId, cardId = card.cardId, cell = entry.cell, name = definition.name or card.cardId,
                damage = Attack.rating(definition.damage, "damage"), trauma = Attack.rating(definition.trauma, "trauma") }
        end
    end
    return requests
end
return Opportunity
