local Activity = {}
local Milling = require("src.sys.milling_receipt")
local Rules = require("data.silencer_rules")
local Outcome = require("src.sys.mission_outcome")
local function pick(random, n) return random and random:random(n) or love.math.random(n) end
function Activity.new(catalogue, pool)
    for key, value in pairs(Rules) do
        assert(type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0, "Invalid Silencer rule " .. key)
    end
    for _, definitions in ipairs({ catalogue.troops, catalogue.sabotage }) do
        for id, definition in pairs(definitions) do
            assert(not pool.byId[id] or pool.byId[id].card_type == definition.card_type, "Conflicting Silencer card ID: " .. id)
            if not pool.byId[id] then pool.ids[#pool.ids + 1] = id; pool.byId[id] = definition end
        end
    end
    table.sort(pool.ids)
    return { catalogue = catalogue, transports = {}, serial = 0 }
end
local function instance(state, cardId)
    state.serial = state.serial + 1
    return { cardId = cardId, instanceId = "silencer_card_" .. state.serial }
end
local function living(session, cell, phase)
    local result, deck = {}, session.locationDecks.byCell[cell]
    for _, id in ipairs(deck.inPlayOrder) do
        local card = deck.inPlay[id]
        if session.locationDecks.pool.byId[card.cardId].card_type == "SILENCER" and card.health > 0
            and (not phase or (card.deployedPhase and card.deployedPhase < phase)) then result[#result + 1] = card end
    end
    return result
end
-- Called once by the phase coordinator while player input is locked.
function Activity.resolve(session, random)
    local state = session.silencers
    if not state or Outcome.finished(session) then return end
    local cell = require("src.sys.mission_deck_effects").jaclCell(session)
    local decks, phase = session.locationDecks, session.doomClock.phase
    if state.lastResolvedPhase == phase then return state.receipt end
    state.lastResolvedPhase = phase
    local deck = decks.byCell[cell]
    local eligible = living(session, cell, phase)
    local receipt = { converted = 0, blocked = 0, milled = 0, damage = 0, deployed = 0, elapsed = 0, events = {} }
    state.receipt = receipt
    for _, squad in ipairs(eligible) do
        for _ = 1, Rules.conversionsPerSquad do
            local candidates = {}
            for i, card in ipairs(deck.drawPile) do
                if decks.pool.byId[card.cardId].card_type ~= "SABOTAGE" then candidates[#candidates + 1] = i end
            end
            if #candidates > 0 then
                local index = candidates[pick(random, #candidates)]
                local choices = decks.pool.byId[squad.cardId].sabotage
                local replacement = instance(state, choices[pick(random, #choices)])
                if deck.revealedTopId == deck.drawPile[index].instanceId then deck.revealedTopId = nil end
                deck.drawPile[index] = replacement
                deck.types.SABOTAGE = true
                deck.revision = deck.revision + 1
                receipt.converted = receipt.converted + 1
            end
        end
    end
    if receipt.converted > 0 then receipt.events[#receipt.events + 1] = { kind = "sabotage", count = receipt.converted } end
    for _ = 1, #eligible * Rules.millsPerSquad do
        if Outcome.finished(session) then return receipt end
        if (session.jaclSecurity or 0) > 0 then
            local event = { kind = "security", beforeSecurity = session.jaclSecurity, security = session.jaclSecurity - 1 }
            receipt.events[#receipt.events + 1] = event
            session.jaclSecurity = session.jaclSecurity - 1
            receipt.blocked = receipt.blocked + 1
            local targets = living(session, cell)
            if #targets > 0 then
                local target = targets[pick(random, #targets)]
                local damage = math.min(target.health, Rules.securityDamage)
                event.instanceId, event.cardId = target.instanceId, target.cardId
                event.name = decks.pool.byId[target.cardId].name or target.cardId
                event.beforeHealth, event.health, event.damage = target.health, target.health - damage, damage
                event.destroyed = event.health == 0
                target.health = target.health - damage
                receipt.damage = receipt.damage + damage
                deck.revision = deck.revision + 1
                if target.health == 0 then require("src.sys.location_card_elimination").commit(session, cell, target.instanceId, random) end
            end
        else
            local mill = decks:prepareMill(cell, 1)
            local record = Milling.new(decks, cell, mill, "silencer")
            assert(decks:commitMill(cell, mill))
            receipt.milling = Milling.append(receipt.milling, record)
            receipt.milled = receipt.milled + mill.actual
            local previous = receipt.events[#receipt.events]
            if previous and previous.kind == "mill" then previous.record = receipt.milling
            else receipt.events[#receipt.events + 1] = { kind = "mill", record = receipt.milling } end
            for _, card in ipairs(mill.entered) do require("src.sys.location_card_entry").committed(session, cell, card) end
        end
    end
    if Outcome.finished(session) then return receipt end
    local kind = #state.transports == 0 and "arrive" or "deploy"
    if kind == "arrive" then
        local count = Rules.baseTransports + require("src.sys.doom_clock").locked(session.doomClock) * Rules.transportsPerGlory
        for i = 1, count do
            local id = state.catalogue.choices[pick(random, #state.catalogue.choices)]
            state.transports[i] = { id = id, order = i, vis_order = state.catalogue.transports[id].vis_order }
        end
    else
        for _, transport in ipairs(state.transports) do
            local definition = state.catalogue.transports[transport.id]
            local choices = state.catalogue.pools[definition.silencer_squads]
            for _ = 1, Rules.squadsPerTransport do
                local card = instance(state, choices[pick(random, #choices)])
                card.deployedPhase = phase
                require("src.sys.location_card_state").initialize(card, decks.pool.byId[card.cardId])
                deck.inPlay[card.instanceId] = card
                deck.inPlayOrder[#deck.inPlayOrder + 1] = card.instanceId
                deck.revision = deck.revision + 1
                receipt.deployed = receipt.deployed + 1
                require("src.sys.location_card_entry").committed(session, cell, card)
            end
        end
    end
    state.presentation = { kind = kind, elapsed = 0, transports = state.transports }
    if kind == "deploy" then state.transports = {} end
    require("src.sys.transport_fate_effects").sync(session, state.presentation.transports)
    return receipt
end
return Activity
