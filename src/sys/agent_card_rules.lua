local Rules = {}
local keys = { "startingHandSize", "activationDrawCount" }

function Rules.resolve(defaults, override, owner)
    assert(type(defaults) == "table", "Missing agent card defaults")
    assert(override == nil or type(override) == "table", "Invalid card_rules: " .. tostring(owner))
    local result = {}
    for _, key in ipairs(keys) do
        local value = defaults[key]
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid card default " .. key)
        if override and override[key] ~= nil then value = override[key] end
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
            "Invalid agent " .. tostring(owner) .. " card_rules." .. key)
        result[key] = value
    end
    if override then
        for key in pairs(override) do
            assert(result[key] ~= nil, "Unknown agent " .. tostring(owner) .. " card rule: " .. tostring(key))
        end
    end
    return result
end
return Rules
