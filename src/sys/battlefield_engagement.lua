local Rules = require("data.battlefield_rules")
local State = require("src.sys.battlefield_state")
local Record = require("src.sys.battlefield_engagement_record")
local Triggers = require("src.sys.force_triggers")
local Passives = require("src.sys.force_passives")
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
local function copyAtCell(armies, cellId)
    local source = armies.byCell[cellId]
    local staged = copy(armies)
    staged.byCell = { [cellId] = copy(source) }
    for _, side in ipairs({ "enemy", "allied" }) do
        staged.byCell[cellId][side] = copy(source[side])
        staged.byCell[cellId][side].forces = copy(source[side].forces)
    end
    return staged
end
function Engagement.project(armies, cellId)
    local catalogue = armies.catalogue
    local original = armies.byCell[cellId]
    local source, removed, added = Triggers.beforeEngage(catalogue, original)
    if not source then return end

    local staged = copyAtCell(armies, cellId)
    local pair = staged.byCell[cellId]
    local addedId = removed.id .. ":before_engage:" .. added.id
    pair.enemy.forces[#pair.enemy.forces + 1] = { id = addedId, forceId = added.id }
    State.removeForce(staged, cellId, "allied", removed.id)
    local forceBonus, forceSources = Passives.battlefieldBonus(staged, cellId, "engage")
    local removedDefinition = catalogue.byId[removed.forceId]
    local effect = {
        sourceForceId = source.id, sourceName = source.name or source.id,
        removedId = removed.id, removedForceId = removed.forceId, removedName = removedDefinition.name or removed.forceId,
        addedId = addedId, addedForceId = added.id, addedName = added.name or added.id,
        alliedBefore = original.allied.value, alliedAfter = pair.allied.value,
        enemyBefore = original.enemy.value, enemyAfter = pair.enemy.value,
        protectionBefore = State.protection(armies, cellId).total,
        protectionAfter = State.protection(staged, cellId).total,
        forceBonusBefore = Passives.battlefieldBonus(armies, cellId, "engage"),
        forceBonusAfter = forceBonus,
    }
    return { armies = staged, effect = effect, forceSources = forceSources }
end
function Engagement.prepare(armies, cellId, success, enemyDamageBonus, projection)
    local staged = copyAtCell(projection and projection.armies or armies, cellId)
    local before = Record.capture(staged, cellId)
    local damage = Engagement.calculate(before, success, nil, enemyDamageBonus)
    -- Both amounts are fixed before either mutation; casualties cannot cancel retaliation.
    local exchanges = {}
    for _, side in ipairs({ "enemy", "allied" }) do
        local removed, absorbed, replacements, bonusAbsorbed = {}, 0, {}, 0
        if damage[side] > 0 then
            removed, absorbed, replacements, bonusAbsorbed = State.damage(staged, cellId, side, damage[side])
        end
        exchanges[side] = { damage = damage[side], removed = removed, absorbed = absorbed,
            replacements = replacements, bonusAbsorbed = bonusAbsorbed }
    end
    return { source = armies.byCell[cellId], owner = armies, revision = armies.revision, staged = staged, cell = cellId,
        result = Record.complete(before, Record.capture(staged, cellId), exchanges, projection and projection.effect) }
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
