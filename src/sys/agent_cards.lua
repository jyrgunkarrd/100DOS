local Cards = {}
Cards.__index = Cards

local function integer(value, minimum)
    return type(value) == "number" and value >= minimum and value < math.huge and value % 1 == 0
end

local function copy(list)
    local result = {}
    for i, value in ipairs(list) do result[i] = value end
    return result
end

function Cards.shuffle(pile, random)
    for i = #pile, 2, -1 do
        local j = random:random(i)
        pile[i], pile[j] = pile[j], pile[i]
    end
end

function Cards.new(agentIds, agents, definitions, settings, random)
    local Rules = require("src.sys.agent_card_rules")
    Rules.resolve(settings)
    local self = setmetatable({ byAgent = {}, definitions = definitions, agents = agents, rules = {} }, Cards)
    local serial = 0
    -- Validate and expand every recipe before consuming randomness.
    for _, id in ipairs(agentIds) do
        local agent = assert(agents.byId[id], "Unknown card owner: " .. id)
        require("src.sys.talent_values").sum(agent.talents or {}, "steel")
        self.rules[id] = Rules.resolve(settings, agent.card_rules, id)
        assert(type(agent.card_deck) == "table", "Missing card_deck: " .. id)
        local state = { drawPile = {}, hand = {}, discardPile = {} }
        self.byAgent[id] = state
        local count = 0
        for key, entry in pairs(agent.card_deck) do
            assert(integer(key, 1) and key <= #agent.card_deck, "Deck recipe must be a dense array")
            count = count + 1
            assert(type(entry) == "table" and type(entry.card_id) == "string", "Invalid deck entry")
            local card = assert(definitions.byId[entry.card_id], "Unknown card: " .. entry.card_id)
            require("src.sys.talent_values").sum(card.talents or {}, "steel")
            assert(type(card.name) == "string" and card.name:match("%S"), "Missing card name")
            assert(integer(card.cost, 0), "Invalid card cost: " .. entry.card_id)
            assert(integer(entry.card_qty, 1), "Invalid card quantity: " .. entry.card_id)
        end
        assert(count == #agent.card_deck, "Deck recipe must be a dense array")
        for _, entry in ipairs(agent.card_deck) do
            for _ = 1, entry.card_qty do
                serial = serial + 1
                state.drawPile[#state.drawPile + 1] = { instanceId = serial, cardId = entry.card_id }
            end
        end
    end
    random = random or love.math.newRandomGenerator()
    for _, id in ipairs(agentIds) do
        local pile = self.byAgent[id].drawPile
        Cards.shuffle(pile, random)
    end
    return self
end

-- Stage draws without modifying live piles; commit only after preparation succeeds.
function Cards:prepareDraw(id, count)
    assert(integer(count, 0), "Draw count must be a nonnegative integer")
    local current = assert(self.byAgent[id], "Unknown card owner")
    local staged = { drawPile = copy(current.drawPile), hand = copy(current.hand), discardPile = copy(current.discardPile or {}) }
    for _ = 1, math.min(count, #staged.drawPile) do
        staged.hand[#staged.hand + 1] = table.remove(staged.drawPile)
    end
    return staged
end

function Cards:prepareDrawTo(id, size)
    assert(integer(size, 0), "Starting hand size must be a nonnegative integer")
    local current = assert(self.byAgent[id], "Unknown card owner")
    return self:prepareDraw(id, math.max(0, size - #current.hand))
end

function Cards:commitHand(id, staged)
    assert(self.byAgent[id], "Unknown card owner")
    self.byAgent[id] = staged
end

return Cards
