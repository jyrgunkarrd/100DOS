local Explore = require("src.sys.location_exploration")
local Cards = require("src.sys.agent_cards")
local Abilities = {}

function Abilities.options(session, card, zone)
    local options = {}
    local definition = session.agentCards.definitions.byId[card.cardId]
    for _, ability in ipairs(definition.abilities or {}) do
        if ability.zones[zone] then options[#options + 1] = ability end
    end
    return options
end

local function locate(session, id, instance, zone)
    if zone == "hand" then
        for index, card in ipairs(session.agentCards.byAgent[id].hand) do
            if card.instanceId == instance then return card, index end
        end
    elseif zone == "play" then
        local board = session.agentAssets and session.agentAssets.byAgent[id]
        for _, asset in ipairs(board and board.placements or {}) do
            if asset.instanceId == instance then return asset.card, asset end
        end
    end
end

function Abilities.exhaustOptions(session, id, opponent)
    local board = session.agentAssets and session.agentAssets.byAgent[id]
    local options = {}
    for _, asset in ipairs(board and board.placements or {}) do
        if not asset.exhausted then
            for _, ability in ipairs(Abilities.options(session, asset.card, "play")) do
                if ability.effect == "test_bonus" then
                    for _, tag in ipairs(opponent.tags or {}) do
                        if tag == ability.opposingTag then
                            options[#options + 1] = { asset = asset, amount = ability.amount }
                            break
                        end
                    end
                end
            end
        end
    end
    return options
end

function Abilities.exhaustSelection(session, id, opponent, ids)
    local selected, total = {}, 0
    if ids == nil then return selected, total end
    if type(ids) ~= "table" then return nil, "INVALID ASSET SELECTION" end
    if not next(ids) then return selected, total end
    local available = {}
    for _, option in ipairs(Abilities.exhaustOptions(session, id, opponent)) do
        available[option.asset.instanceId] = option
    end
    for index, instance in pairs(ids) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or index > #ids then
            return nil, "INVALID ASSET SELECTION"
        end
        local option = available[instance]
        if not option then return nil, "ASSET UNAVAILABLE" end
        available[instance] = nil
        selected[index] = option.asset
        total = total + option.amount
    end
    for i = 1, #ids do if not selected[i] then return nil, "INVALID ASSET SELECTION" end end
    return selected, total
end

function Abilities.evaluate(session, id, args)
    local card, source = locate(session, id, args.instanceId, args.zone)
    if not card then return nil, "CARD MOVED" end
    for _, ability in ipairs(Abilities.options(session, card, args.zone)) do
        if ability.id == args.abilityId and (ability.id == "expend" or ability.id == "retask") then
            local status = session.agentStatus.byAgent[id]
            if status.actionPoints < ability.actionPointCost then return nil, "NOT ENOUGH ACTION POINTS" end
            if ability.id == "retask" and source.exhausted then return nil, "ASSET EXHAUSTED" end
            if ability.effect == "explore" then
                local check = Explore.evaluate(session, id, ability)
                if not check.valid then return nil, check.reason end
            end
            return ability, card, source
        end
    end
    return nil, "ABILITY UNAVAILABLE"
end

function Abilities.prepare(session, id, args)
    local ability, card, source = Abilities.evaluate(session, id, args)
    if not ability then return nil, card end
    local piles = session.agentCards.byAgent[id]
    local status = session.agentStatus.byAgent[id]
    local changes = { actionPoints = status.actionPoints - ability.actionPointCost }
    local explore
    if ability.effect == "explore" then
        explore = assert(Explore.prepare(session, id, { rules = ability }))
    elseif ability.effect == "turn_talent" then
        local bonuses = {}
        for talent, amount in pairs(status.turnTalentBonuses or {}) do bonuses[talent] = amount end
        bonuses[ability.talent] = (bonuses[ability.talent] or 0) + ability.amount
        changes.turnTalentBonuses = bonuses
    else
        return nil, "UNKNOWN ASSET EFFECT"
    end
    return { result = explore and explore.result or card, status = changes, provokingKind = explore and "explore" or false,
        publish = function()
            local current, currentCard, currentSource = Abilities.evaluate(session, id, args)
            if current ~= ability or currentCard ~= card or source ~= currentSource or session.agentCards.byAgent[id] ~= piles then return false end
            local shuffled
            if ability.id == "retask" then
                shuffled = {}
                for i, entry in ipairs(piles.drawPile) do shuffled[i] = entry end
                shuffled[#shuffled + 1] = card
                Cards.shuffle(shuffled, args.random or love.math.newRandomGenerator())
            end
            if explore and not explore.publish() then return false end
            if args.zone == "hand" then table.remove(piles.hand, source)
            else session.agentAssets:remove(id, source) end
            if shuffled then piles.drawPile = shuffled
            else piles.discardPile[#piles.discardPile + 1] = card end
            return true
        end }
end
return Abilities
