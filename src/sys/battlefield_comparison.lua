local Tests = require("src.sys.battlefield_tests")
local Values = require("src.sys.talent_values")
local Rules = require("data.battlefield_comparison_rules")
local Comparison = {}

-- Read-only base margins, never probabilities. Only legal destinations set the ranking.
function Comparison.build(assignments, locations, agent, eligible, jaclCellId)
    assert(Rules.scoreMode == "margin", "Unsupported comparison scoring policy")
    local result = { byCell = {}, agentName = agent.name, agentId = agent.id,
        baselineTalent = Rules.baselineTalent, eligibleCount = 0, purposeStrongest = true }
    local scores, minimum, availableMargins = {}, nil, {}
    for cellId, locationId in pairs(assignments) do
        local location = assert(locations.byId[locationId], "Unknown comparison location: " .. locationId)
        local entry = { tests = {}, name = location.name or locationId, eligible = eligible[cellId] == true,
            jacl = cellId == jaclCellId }
        result.byCell[cellId] = entry
        if not entry.jacl then
            for _, test in ipairs(Tests.resolve(location)) do
                if scores[test.talent] == nil then scores[test.talent] = Values.sum(agent.talents or {}, test.talent) end
                local score = scores[test.talent]
                local record = { talent = test.talent, score = score, difficulty = test.printed, margin = score - test.printed }
                if entry.eligible then
                    availableMargins[record.margin] = true
                end
                if test.talent == Rules.baselineTalent then entry.baseline = record end
                if not Rules.hiddenTalents[test.talent] then
                    entry.tests[#entry.tests + 1] = record
                    entry.margin = entry.margin and math.max(entry.margin, record.margin) or record.margin
                end
            end
            table.sort(entry.tests, function(a, b)
                if a.difficulty == b.difficulty then return a.talent < b.talent end
                return a.difficulty < b.difficulty
            end)
        end
        if entry.eligible and entry.margin ~= nil then
            result.eligibleCount = result.eligibleCount + 1
            result.bestMargin = result.bestMargin and math.max(result.bestMargin, entry.margin) or entry.margin
            minimum = minimum and math.min(minimum, entry.margin) or entry.margin
            if not entry.baseline or entry.baseline.margin <= entry.margin then result.purposeStrongest = false end
        end
    end
    result.noPreference = result.eligibleCount > 0 and minimum == result.bestMargin
    result.purposeStrongest = result.eligibleCount > 0 and result.purposeStrongest
    -- Rank individual printed-test margins across legal destinations.
    -- Equal margins always share a band, including Purpose.
    local margins = {}
    for margin in pairs(availableMargins) do margins[#margins + 1] = margin end
    table.sort(margins, function(a, b) return a > b end)
    local function band(margin)
        if margin == margins[1] then return "best" end
        if margin == margins[2] then return "next" end
        return "worst"
    end
    for _, entry in pairs(result.byCell) do
        if entry.baseline then entry.baseline.band = band(entry.baseline.margin) end
        entry.best = entry.eligible and entry.margin ~= nil and entry.margin == result.bestMargin
        for _, test in ipairs(entry.tests) do
            test.band = band(test.margin)
            test.emphasized = entry.eligible and test.margin == result.bestMargin
                and not (Rules.suppressUniformEmphasis and result.noPreference)
            if entry.baseline then
                test.baselineRelation = test.margin > entry.baseline.margin and "above"
                    or test.margin == entry.baseline.margin and "equal" or "below"
            end
        end
    end
    return result
end
return Comparison
