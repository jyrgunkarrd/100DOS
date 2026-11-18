local Rules = require("data.battlefield_rules")
local Tests = {}
function Tests.resolve(location, kind, difficultyBonus)
    local result, seen = {}, {}
    local jacl = kind and require("data.jacl_actions").actions[kind]
    local entries = location.battlefield_talent or {}
    if jacl then
        entries = {}; for _, talent in ipairs(jacl.talents) do entries[#entries + 1] = { type = talent, qty = jacl.difficulty } end
    end
    assert(type(entries) == "table", "Invalid battlefield talents")
    for key, entry in pairs(entries) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #entries, "Battlefield talents must be an array")
        assert(type(entry) == "table" and require("data.talent_test_rules").talents[entry.type], "Invalid battlefield talent")
        assert(not seen[entry.type], "Duplicate battlefield talent")
        assert(type(entry.qty) == "number" and entry.qty >= 0 and entry.qty < math.huge and entry.qty % 1 == 0, "Invalid battlefield difficulty")
        seen[entry.type] = true
    end
    for _, entry in ipairs(entries) do
        result[#result + 1] = { id = entry.type, talent = entry.type, kind = "interact",
            label = entry.type:upper(), printed = entry.qty,
            value = math.max(0, entry.qty + (kind and not jacl and Rules.actions[kind].adjustment or 0)) + (difficultyBonus or 0) }
    end
    return result
end
return Tests
