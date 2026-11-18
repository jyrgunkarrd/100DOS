local Recipe = {}

function Recipe.whole(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

function Recipe.validate(entries, label)
    assert(type(entries) == "table", label .. ": deck_build must be an array")
    for key in pairs(entries) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #entries,
            label .. ": deck_build must be a dense array")
    end
    local total = 0
    for _, entry in ipairs(entries) do
        assert(type(entry) == "table" and type(entry.type) == "string" and entry.type:match("%S"),
            label .. ": invalid deck_build type")
        assert(Recipe.whole(entry.qty), label .. ": deck_build qty must be a nonnegative integer")
        total = total + entry.qty
        assert(Recipe.whole(total), label .. ": deck_build total must be finite")
    end
    return total
end

-- Fresh entries, stable first-seen ordering, and explicit zero-count types.
function Recipe.combine(sources)
    local total = 0
    for _, source in ipairs(sources) do
        total = total + Recipe.validate(source.recipe, source.label)
    end
    assert(Recipe.whole(total), "Combined deck_build total must be finite")
    local entries, byType = {}, {}
    for _, source in ipairs(sources) do
        for _, entry in ipairs(source.recipe) do
            if not byType[entry.type] then
                local combined = { type = entry.type, qty = 0 }
                byType[entry.type] = combined
                entries[#entries + 1] = combined
            end
            byType[entry.type].qty = byType[entry.type].qty + entry.qty
        end
    end
    return entries, total
end

return Recipe
