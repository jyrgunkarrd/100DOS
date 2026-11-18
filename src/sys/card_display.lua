local Display = {}
local function count(value, label)
    value = value or 0
    assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0,
        "Invalid card display " .. label)
    return value
end
local function strings(value, label)
    if value == nil then return {} end
    assert(type(value) == "table", "Invalid card display " .. label)
    local result, entries = {}, 0
    for key, text in pairs(value) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #value,
            "Card display " .. label .. " must be a dense array")
        assert(type(text) == "string" and text:match("%S"), "Invalid card display " .. label)
        entries = entries + 1
    end
    assert(entries == #value, "Sparse card display " .. label)
    for i, text in ipairs(value) do result[i] = text end
    return result
end
-- Expand quantities into icon occurrences without changing the definition.
local function icons(value, label)
    if value == nil then return {} end
    assert(type(value) == "table", "Invalid card " .. label)
    local result, entries = {}, 0
    for key, entry in pairs(value) do
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #value,
            "Card " .. label .. " must be a dense array")
        assert(type(entry) == "table" and type(entry.type) == "string" and entry.type:match("%S")
            and type(entry.qty) == "number", "Invalid card " .. label .. " entry")
        count(entry.qty, label .. " quantity")
        entries = entries + 1
    end
    assert(entries == #value, "Sparse card " .. label)
    for _, entry in ipairs(value) do
        for _ = 1, entry.qty do result[#result + 1] = entry.type end
    end
    return result
end

function Display.common(card)
    assert(type(card.name) == "string" and card.name:match("%S"), "Missing card name")
    local display = card.card_display or {}
    assert(type(display) == "table", "Invalid card_display")
    assert(card.card_type == nil or type(card.card_type) == "string", "Invalid card type")
    local result = { name = card.name, type = card.card_type,
        tags = strings(card.tags, "tags"), paragraphs = {} }
    local seen = {}
    for key, value in pairs(display) do
        local number = type(key) == "string" and key:match("^p(%d+)$")
        if number then
            number = tonumber(number)
            assert(number >= 1 and number < math.huge and not seen[number], "Invalid or duplicate paragraph number")
            seen[number] = true
            result.paragraphs[#result.paragraphs + 1] = { number = number,
                text = table.concat(strings(value, key), "\n") }
        end
    end
    table.sort(result.paragraphs, function(a, b) return a.number < b.number end)
    return result
end
function Display.normalize(card)
    local result = Display.common(card)
    result.cost, result.slots = count(card.cost, "cost"), count(card.asset_slots, "asset_slots")
    result.health, result.defiance = count(card.health, "health"), count(card.defiance, "defiance")
    result.methods, result.talents = icons(card.methods, "methods"), icons(card.talents, "talents")
    return result
end
return Display
