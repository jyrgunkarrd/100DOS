local Rules = require("data.talent_test_rules")
local Fate = require("src.sys.fate_tile_definition")
local Tests = {}
function Tests.resolve(card)
    local result, seen = {}, {}
    local entries = card.talent_tests == nil and {} or card.talent_tests
    assert(type(entries) == "table", "Invalid location talent_tests")
    local count = 0
    for key in pairs(entries) do
        count = count + 1
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #entries,
            "Location talent_tests must be a dense array")
    end
    assert(count == #entries, "Location talent_tests must be a dense array")
    for i, entry in ipairs(entries) do
        assert(type(entry) == "table", "Invalid talent test")
        local kind = entry.kind or "interact"
        local defaults = assert(Rules.kinds[kind], "Unknown talent test kind")
        local talent = entry.talent or entry.type or defaults.talent
        assert(Rules.talents[talent], "Unknown test talent")
        local id = entry.id or (kind .. "_" .. i)
        assert(type(id) == "string" and id:match("%S") and not seen[id], "Invalid or duplicate talent test ID")
        assert(type(entry.val) == "number" and entry.val >= 0 and entry.val < math.huge and entry.val % 1 == 0,
            "Invalid talent test value")
        local enemy = require("src.sys.location_card_traits").enemy(card)
        assert(kind == "interact" or enemy, "Strike/Evade requires an enemy")
        assert(not enemy or kind ~= "interact", "Enemy test requires Strike or Evade")
        seen[id] = true
        result[#result + 1] = { id = id, kind = kind, talent = talent, value = entry.val,
            label = kind == "interact" and talent:upper() or defaults.label .. " - " .. talent:upper(),
            effect = defaults.effect, damage = defaults.damage, provokes = defaults.provokes }
    end
    return result
end
function Tests.calculate(base, committed, difficulty, tile)
    local modifier = Fate.modifier(tile)
    local total = base + committed + modifier
    local success = total >= difficulty
    if tile.special == "auto_failure" then success = false
    elseif tile.special == "auto_success" then success = true end
    return { base = base, committed = committed, modifier = modifier, total = total,
        difficulty = difficulty, success = success, special = tile.special }
end
return Tests
