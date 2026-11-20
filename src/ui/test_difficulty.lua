local Theme = require("data.preparation_theme")
local Difficulty = {}

-- Compare with the printed difficulty so caps and stacked adjustments show their net effect.
local function adjusted(value, delta, favorable, normalColor)
    if delta == 0 then return tostring(value), normalColor end
    return string.format("%+d  %d", delta, value), favorable and Theme.accent or Theme.penaltyColor
end

function Difficulty.format(test, value, normalColor)
    local delta = value - (test.printed or value)
    return adjusted(value, delta, delta < 0, normalColor)
end

function Difficulty.strength(value, printed, normalColor)
    return adjusted(value, value - printed, value > printed, normalColor)
end

function Difficulty.line(prefix, test, value, normalColor, suffix)
    local number, color = Difficulty.format(test, value, normalColor)
    return { normalColor, prefix, color, number, normalColor, suffix or "" }
end

function Difficulty.forceTerms(record)
    local terms = ""
    for _, source in ipairs(record.forceSources or {}) do
        terms = terms .. " + " .. source.value .. " " .. source.label
    end
    return terms
end

function Difficulty.result(record)
    if record.special then return record.success and "AUTO SUCCESS" or "AUTO FAILURE" end
    return record.base .. " + " .. (record.committed - (record.forceBonus or 0)) .. Difficulty.forceTerms(record)
        .. (record.modifier >= 0 and " + " or " - ") .. math.abs(record.modifier)
        .. " = " .. record.total .. " vs " .. record.difficulty
end

return Difficulty
