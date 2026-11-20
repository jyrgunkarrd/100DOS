local Values = {}
function Values.sum(entries, talent)
    local total, count = 0, 0
    assert(type(entries) == "table", "Talents must be an array")
    for key, entry in pairs(entries) do
        count = count + 1
        assert(type(key) == "number" and key >= 1 and key % 1 == 0 and key <= #entries,
            "Talents must be a dense array")
        assert(type(entry) == "table" and require("data.talent_test_rules").talents[entry.type], "Unknown talent")
        assert(type(entry.qty) == "number" and entry.qty >= 0 and entry.qty < math.huge and entry.qty % 1 == 0,
            "Invalid talent quantity")
        if entry.type == talent then total = total + entry.qty end
    end
    assert(count == #entries and total < math.huge, "Invalid talent array or total")
    return total
end
function Values.effective(agent, talent, status)
    local bonuses = status and status.turnTalentBonuses
    local modifier = bonuses and bonuses[talent] or 0
    return Values.sum(agent.talents or {}, talent) + modifier, modifier
end
return Values
