local Rules = require("data.battlefield_rules")
local State = require("src.sys.battlefield_state")
local Record = require("src.sys.battlefield_engagement_record")
local Engagement = {}
function Engagement.validate(rules)
    rules = rules or Rules.engagement
    assert(type(rules.strengthPerDamage) == "number" and rules.strengthPerDamage > 0
        and rules.strengthPerDamage < math.huge, "Invalid engagement strength divisor")
    assert(rules.rounding == "down", "Invalid engagement rounding")
    assert(type(rules.alliedRequiresSuccess) == "boolean", "Invalid engagement success requirement")
end
-- Incoming damage by receiving side, calculated entirely from starting strength.
function Engagement.calculate(before, success, rules, enemyDamageBonus)
    rules = rules or Rules.engagement
    Engagement.validate(rules)
    return {
        enemy = (success or not rules.alliedRequiresSuccess) and math.floor(before.allied.value / rules.strengthPerDamage) or 0,
        allied = math.floor(before.enemy.value / rules.strengthPerDamage) + (enemyDamageBonus or 0),
    }
end
local function copy(t)
    local result = {}; for k, v in pairs(t) do result[k] = v end; return result
end
function Engagement.prepare(armies, cellId, success, enemyDamageBonus)
    local source = armies.byCell[cellId]
    local staged = copy(armies)
    staged.byCell = { [cellId] = copy(source) }
    for _, side in ipairs({ "enemy", "allied" }) do
        staged.byCell[cellId][side] = copy(source[side])
        staged.byCell[cellId][side].forces = copy(source[side].forces)
    end
    local original, revision = armies, armies.revision
    armies = staged
    local pair = armies.byCell[cellId]
    local before = Record.capture(pair, armies.catalogue)
    local damage = Engagement.calculate(before, success, nil, enemyDamageBonus)
    -- Both amounts are fixed before either mutation; casualties cannot cancel retaliation.
    local exchanges = {}
    for _, side in ipairs({ "enemy", "allied" }) do
        local removed, absorbed = {}, 0
        if damage[side] > 0 then removed, absorbed = State.damage(armies, cellId, side, damage[side]) end
        exchanges[side] = { damage = damage[side], removed = removed, absorbed = absorbed }
    end
    return { source = source, owner = original, revision = revision, staged = staged, cell = cellId,
        result = Record.complete(before, Record.capture(pair, armies.catalogue), exchanges) }
end
function Engagement.canCommit(plan)
    return plan and not plan.committed and plan.owner.revision == plan.revision
        and plan.owner.byCell[plan.cell] == plan.source
end
function Engagement.commit(plan)
    if not Engagement.canCommit(plan) then return false end
    local pair = plan.staged.byCell[plan.cell]
    for _, side in ipairs({ "enemy", "allied" }) do
        for _, key in ipairs({ "forces", "value", "counts" }) do plan.source[side][key] = pair[side][key] end
    end
    plan.source.protection, plan.source.revision = pair.protection, pair.revision
    plan.owner.revision, plan.committed = plan.staged.revision, true
    return plan.result
end
function Engagement.resolve(armies, cellId, success)
    return Engagement.commit(Engagement.prepare(armies, cellId, success))
end
return Engagement
