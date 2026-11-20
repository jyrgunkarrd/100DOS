local Definition = {}

function Definition.modifier(tile)
    local value = tile.value or 0
    return tile.negative and value > 0 and -value or value
end

function Definition.display(tile)
    return { name = tile.name, img = tile.img, value = tile.value }
end

local function nonnegative(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function whole(value)
    return nonnegative(value) and value <= 2 ^ 53 - 1 and value % 1 == 0
end

function Definition.validate(tile, id)
    local label = "Fate tile " .. id .. ": "
    assert(tile.name == nil or (type(tile.name) == "string" and tile.name:match("%S")),
        label .. "name must be a nonempty string")
    assert(tile.value == nil or nonnegative(tile.value), label .. "value must be a finite nonnegative number")
    assert(tile.negative == nil or type(tile.negative) == "boolean", label .. "negative must be a boolean")
    assert(tile.img == nil or type(tile.img) == "boolean", label .. "img must be a boolean")
    assert(not tile.img or id:match("^[%w_-]+$"), label .. "image needs a filename-safe ID")
    assert(tile.special == nil or tile.special == "auto_failure" or tile.special == "auto_success",
        label .. "unknown special outcome")
    assert(tile.bonus == nil or type(tile.bonus) == "boolean", label .. "bonus must be a boolean")
    assert(not tile.bonus or (not tile.special and not tile.clash), label .. "bonus tiles support numeric modifiers only")
    if tile.extra_cost ~= nil then
        assert(tile.bonus and type(tile.extra_cost) == "table", label .. "extra_cost requires a bonus tile and a table")
        for key, value in pairs(tile.extra_cost) do
            assert((key == "dmg" or key == "trm") and whole(value), label .. "invalid extra_cost component")
        end
    end
    local clash = tile.clash
    if clash == nil then return end
    assert(type(clash) == "table", label .. "clash must be a table")
    assert(whole(clash.amt) and clash.amt > 0, label .. "clash.amt must be a positive integer")
    for _, key in ipairs({ "en_dmg", "en_bonus" }) do
        assert(clash[key] == nil or whole(clash[key]), label .. "clash." .. key .. " must be a nonnegative integer")
    end
end

return Definition
