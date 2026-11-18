local Recipe = require("src.sys.location_deck_recipe")
local Location = {}

function Location.build(selection, catalogues, settings)
    assert(type(settings.idPrefix) == "string" and settings.idPrefix:match("%S"),
        "JACL location requires an ID prefix")
    local jacl = assert(catalogues.jacls.byId[selection.jaclId],
        "JACL location: unknown JACL " .. tostring(selection.jaclId))
    local captain = assert(catalogues.captains.byId[selection.captainId],
        "JACL location: unknown Captain " .. tostring(selection.captainId))
    local recipe, size = Recipe.combine({
        { recipe = jacl.deck_build, label = "JACL " .. selection.jaclId },
        { recipe = captain.deck_build, label = "Captain " .. selection.captainId },
    })
    local pool, seen = {}, {}
    for _, source in ipairs({ jacl, captain }) do
        local label = "JACL deck source " .. tostring(source.id or source.name)
        assert(Recipe.whole(source.deck_size)
            and source.deck_size == Recipe.validate(source.deck_build, label),
            label .. ": deck_size must match deck_build total")
        assert(type(source.card_pool) == "table", label .. ": card_pool must be an array")
        local count = 0
        for key, id in pairs(source.card_pool) do
            count = count + 1
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #source.card_pool
                and type(id) == "string" and id:match("%S"), label .. ": invalid card_pool entry")
        end
        assert(count == #source.card_pool, label .. ": card_pool must be dense")
        for _, id in ipairs(source.card_pool) do
            if not seen[id] then pool[#pool + 1] = id; seen[id] = true end
        end
    end
    return {
        id = settings.idPrefix .. selection.jaclId,
        name = jacl.name or selection.jaclId,
        jaclId = selection.jaclId,
        captainId = selection.captainId,
        card_pool = pool,
        deck_build = recipe,
        deck_size = size,
    }
end

return Location
