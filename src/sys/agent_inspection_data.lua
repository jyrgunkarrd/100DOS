local Fate = require("src.sys.fate_pool_display")
local Data = {}

local function add(counts, id, quantity)
    counts[id] = (counts[id] or 0) + quantity
end

local function summarize(counts, definitions)
    local result = { rows = {}, total = 0 }
    for id, quantity in pairs(counts) do
        local definition = definitions[id]
        local row = { id = id, name = definition and definition.name or id, quantity = quantity }
        result.rows[#result.rows + 1] = row
        result.total = result.total + quantity
    end
    table.sort(result.rows, function(a, b)
        local first, second = a.name:lower(), b.name:lower()
        if first == second then return a.id < b.id end
        return first < second
    end)
    return result
end

-- Count by definition before creating rows so pile order and instance identities stay private.
function Data.build(id, agent, cardDefinitions, live, pool, plannedFateDefinitions)
    local deck, discard = {}, {}
    if live then
        for _, card in ipairs(live.drawPile) do add(deck, card.cardId, 1) end
        for _, card in ipairs(live.discardPile or {}) do add(discard, card.cardId, 1) end
    else
        for _, recipe in ipairs(agent.card_deck or {}) do add(deck, recipe.card_id, recipe.card_qty) end
    end
    return {
        name = agent.name, live = live ~= nil, planned = pool == nil,
        deck = summarize(deck, cardDefinitions),
        discard = summarize(discard, cardDefinitions),
        fate = pool and Fate.pool(pool, id) or Fate.planned(agent.fate or {}, plannedFateDefinitions or {}),
    }
end

return Data
