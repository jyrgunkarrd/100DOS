local Pool = {}

function Pool.build(assignments, locations, cards)
    local result = { ids = {}, byId = {}, byType = {} }
    for _, locationId in pairs(assignments) do
        local location = locations.byId[locationId]
        assert(location, "Unknown location: " .. tostring(locationId))
        local entries = location.card_pool
        assert(type(entries) == "table", locationId .. ": card_pool must be an array")
        for key in pairs(entries) do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #entries,
                locationId .. ": card_pool must be a dense array")
        end
        for _, id in ipairs(entries) do
            local card = type(id) == "string" and cards.byId[id]
            assert(card, locationId .. ": unknown location card ID " .. tostring(id))
            assert(not require("src.sys.location_card_traits").hunt(card),
                locationId .. ": hunt cards must come from the champion roster: " .. id)
            assert(type(card.card_type) == "string" and card.card_type:match("%S"),
                locationId .. ": missing card_type for " .. id)
            require("src.sys.talent_tests").resolve(card)
            require("src.sys.location_card_effects").validate(card)
            require("src.sys.location_card_state").initialize({}, card)
            if not result.byId[id] then
                result.ids[#result.ids + 1] = id
                result.byId[id] = card
            end
        end
    end
    table.sort(result.ids)
    for _, id in ipairs(result.ids) do
        local kind = result.byId[id].card_type
        result.byType[kind] = result.byType[kind] or {}
        table.insert(result.byType[kind], id)
    end
    return result
end

return Pool
