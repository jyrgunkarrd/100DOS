local Common = require("src.sys.card_display")
local Display = {}
local function count(value, label)
    assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
        "Invalid location card " .. label)
    return value
end
function Display.normalize(card)
    local result = Common.common(card)
    result.type = result.type and result.type:upper()
    result.cost, result.slots, result.health, result.defiance = 0, 0, 0, 0
    result.methods, result.talents, result.tests, result.stats = {}, {}, {}, {}
    for _, key in ipairs({ "health", "defiance", "damage", "trauma" }) do
        if card[key] ~= nil then
            result.stats[#result.stats + 1] = { key = key, value = count(card[key], key),
                group = (key == "damage" or key == "trauma") and "ratings" or "stats" }
        end
    end
    for _, test in ipairs(require("src.sys.talent_tests").resolve(card)) do
        result.tests[#result.tests + 1] = { type = test.talent, value = test.value, label = test.label }
    end
    return result
end
return Display
