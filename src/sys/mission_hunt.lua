local Traits = require("src.sys.location_card_traits")
local CardState = require("src.sys.location_card_state")
local Outcome = require("src.sys.mission_outcome")
local Hunt = {}
local function copy(source)
    local result = {}; for key, value in pairs(source or {}) do result[key] = value end; return result
end
local function pick(random, count) return random and random:random(count) or love.math.random(count) end
local function shuffle(list, random)
    for i, card in ipairs(list) do if card.faceUp then list[i] = copy(card); list[i].faceUp = nil end end
    for i = #list, 2, -1 do local j = pick(random, i); list[i], list[j] = list[j], list[i] end
end
local function array(list, label, nonempty)
    assert(type(list) == "table", label .. " must be an array")
    local seen, count = {}, 0
    for key in pairs(list) do
        count = count + 1
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #list, label .. " must be dense")
    end
    assert(count == #list and (not nonempty or count > 0), label .. " must not be empty")
    for _, id in ipairs(list) do
        assert(type(id) == "string" and id:match("%S") and not seen[id], label .. " has invalid or duplicate IDs")
        seen[id] = true
    end
end
local function validateCard(catalogue, id, role)
    local card = assert(catalogue.byId[id], "Unknown hunt card: " .. tostring(id))
    assert(card.card_type == role, id .. ": expected " .. role)
    assert(type(card.name) == "string" and card.name:match("%S"), id .. ": missing name")
    CardState.initialize({}, card)
    require("src.sys.talent_tests").resolve(card)
    require("src.sys.attack_resolution").rating(card.damage, "damage")
    require("src.sys.attack_resolution").rating(card.trauma, "trauma")
    return card
end
local function cellsFor(session)
    local cells = {}
    local jacl = session.armies and session.armies.jaclCellId or require("data.jacl_location_rules").cellId
    for cell in pairs(session.assignments) do
        if cell ~= jacl and session.locationDecks.byCell[cell] then cells[#cells + 1] = cell end
    end
    table.sort(cells); return cells
end
local function cloneDecks(decks)
    local result = setmetatable(copy(decks), getmetatable(decks)); result.byCell = {}
    for cell, deck in pairs(decks.byCell) do
        local nextDeck = copy(deck)
        for _, key in ipairs({ "drawPile", "discardPile", "inPlay", "inPlayOrder", "types" }) do nextDeck[key] = copy(deck[key]) end
        result.byCell[cell] = nextDeck
    end
    return result
end
local function instance(hunt, cardId, pool)
    hunt.serial = hunt.serial + 1
    local card = { instanceId = "hunt_card_" .. hunt.serial, cardId = cardId }
    CardState.initialize(card, pool.byId[cardId]); return card
end
local function presentation(hunt, kind, cells, sourceCell)
    return { kind = kind, cells = copy(cells), sourceCell = sourceCell, elapsed = 0,
        championName = hunt.championName }
end

-- Every candidate is validated before the first draw, and only detached models change.
function Hunt.prepareInitial(source, biome, catalogue, random)
    local cells = cellsFor(source)
    assert(#cells > 0, "Champion hunt requires a non-JACL location")
    array(biome.champ_pool, "Biome champ_pool", true)
    for _, id in ipairs(biome.champ_pool) do
        local champion = validateCard(catalogue, id, "CHAMPION")
        array(champion.company, id .. " company", false)
        array(champion.bodyguards, id .. " bodyguards", true)
        assert(#champion.company + 1 <= #cells, id .. ": company exceeds available locations")
        for _, member in ipairs(champion.company) do validateCard(catalogue, member, "COMPANY") end
        for _, guard in ipairs(champion.bodyguards) do validateCard(catalogue, guard, "BODYGUARD") end
    end
    local rules = copy(require("data.mission_hunt_rules"))
    assert(type(rules.revealChampionAtZeroStrength) == "boolean", "Invalid champion reveal rule")
    local definition = catalogue.byId[biome.champ_pool[pick(random, #biome.champ_pool)]]
    local hunt = { championId = definition.id, championName = definition.name, serial = 0, revision = 0,
        companyIds = {}, bodyguardIds = {}, bodyguardPool = copy(definition.bodyguards), cells = cells,
        secured = {}, located = {}, rules = rules, escapes = 0 }
    local pool = { ids = copy(source.locationDecks.pool.ids), byId = copy(source.locationDecks.pool.byId), byType = {} }
    for kind, ids in pairs(source.locationDecks.pool.byType) do pool.byType[kind] = copy(ids) end
    -- Hunt-only definitions are available to previews, but never to ordinary deck recipes.
    local function include(id)
        if not pool.byId[id] then pool.ids[#pool.ids + 1] = id; pool.byId[id] = catalogue.byId[id] end
    end
    include(definition.id)
    for _, id in ipairs(definition.company) do include(id) end
    for _, id in ipairs(definition.bodyguards) do include(id) end
    table.sort(pool.ids)
    local decks = cloneDecks(source.locationDecks); decks.pool = pool
    decks.huntCells = {}; for _, cell in ipairs(cells) do decks.huntCells[cell] = true end
    local champion = instance(hunt, definition.id, pool)
    hunt.championInstanceId = champion.instanceId
    local group = { champion }
    for _, id in ipairs(definition.company) do
        local card = instance(hunt, id, pool); hunt.companyIds[#hunt.companyIds + 1] = card.instanceId
        group[#group + 1] = card
    end
    while #group < #cells do
        local card = instance(hunt, definition.bodyguards[pick(random, #definition.bodyguards)], pool)
        hunt.bodyguardIds[#hunt.bodyguardIds + 1] = card.instanceId; group[#group + 1] = card
    end
    shuffle(group, random)
    for i, cell in ipairs(cells) do
        local deck = decks.byCell[cell]
        deck.drawPile[#deck.drawPile + 1] = group[i]; shuffle(deck.drawPile, random)
        deck.revision = deck.revision + 1
    end
    return { missionHunt = hunt, locationCardPool = pool, locationDecks = decks,
        huntPresentation = presentation(hunt, "initial", cells) }
end

function Hunt.find(session, instanceId)
    for cell, deck in pairs(session.locationDecks.byCell) do
        if deck.inPlay[instanceId] then return deck.inPlay[instanceId], cell, "inPlay" end
        for _, zone in ipairs({ "drawPile", "discardPile" }) do
            for _, card in ipairs(deck[zone]) do if card.instanceId == instanceId then return card, cell, zone end end
        end
    end
end
function Hunt.enter(session, cell, card)
    local hunt = session.missionHunt
    if hunt and Traits.hunt(session.locationDecks.pool.byId[card.cardId]) then
        hunt.located[card.instanceId] = cell; hunt.revision = hunt.revision + 1
    end
end

local function attemptSecure(session, cell, random)
    local hunt, decks = session.missionHunt, session.locationDecks
    local deck = decks.byCell[cell]
    local hidden, championIndex = {}, nil
    for i, card in ipairs(deck.drawPile) do
        if card.instanceId == hunt.championInstanceId then
            championIndex = i
        elseif decks.pool.byId[card.cardId].card_type == "COMPANY" and card.health > 0 then
            hidden[#hidden + 1] = i
        end
    end
    local index
    if #hidden > 0 then
        index = hidden[#hidden == 1 and 1 or pick(random, #hidden)]
    else
        for _, card in pairs(deck.inPlay) do
            if decks.pool.byId[card.cardId].card_type == "COMPANY" and card.health > 0 then return end
        end
        hunt.secured[cell] = true
        index = championIndex
    end
    if index then
        local card = table.remove(deck.drawPile, index)
        card.faceUp, card.engagedAgentId = nil, nil
        if deck.revealedTopId == card.instanceId then deck.revealedTopId = nil end
        local entry = { card = card, inPlay = deck.inPlay }
        require("src.sys.location_card_entry").prepare(session, cell, entry, session.activeAgentId)
        deck.inPlay[card.instanceId] = entry.card
        deck.inPlayOrder[#deck.inPlayOrder + 1] = card.instanceId
        deck.revision = deck.revision + 1
        Hunt.enter(session, cell, entry.card)
    end
end

-- Defeat effects run only after a real elimination, never after discard or withdrawal.
function Hunt.eliminated(session, cell, card, random)
    local hunt = session.missionHunt
    if not hunt or Outcome.finished(session) then return end
    local role = session.locationDecks.pool.byId[card.cardId].card_type
    hunt.located[card.instanceId] = nil
    if role == "CHAMPION" then Outcome.victory(session, card)
    elseif role == "COMPANY" or role == "BODYGUARD" then
        attemptSecure(session, cell, random)
    end
    if role == "BODYGUARD" then
        local candidates = { hunt.championInstanceId }
        for _, id in ipairs(hunt.companyIds) do candidates[#candidates + 1] = id end
        local eligible = {}
        for _, id in ipairs(candidates) do
            local target, targetCell, zone = Hunt.find(session, id)
            if target and target.health > 0 and zone == "drawPile" and hunt.located[id] ~= targetCell then
                eligible[#eligible + 1] = { id = id, cell = targetCell }
            end
        end
        local target = #eligible > 0 and eligible[pick(random, #eligible)] or nil
        if target then hunt.located[target.id] = target.cell end
        hunt.notice = target and "INTELLIGENCE: TARGET LOCATION REVEALED" or "NO NEW INTELLIGENCE"
    end
    hunt.revision = hunt.revision + 1
end

function Hunt.queueEscape(session)
    local hunt = session.missionHunt
    if not hunt or Outcome.finished(session) then return end
    local card, _, zone = Hunt.find(session, hunt.championInstanceId)
    if card and card.health > 0 and zone == "inPlay" then session.pendingHuntEscape = true end
end

-- Stage a whole-board move. Live arrays, card state and RNG are untouched on stale commit.
function Hunt.prepareEscape(session, random)
    local hunt = session.missionHunt
    if not hunt or Outcome.finished(session) then return nil end
    local champion, sourceCell, zone = Hunt.find(session, hunt.championInstanceId)
    if not champion or champion.health <= 0 or zone ~= "inPlay" then return nil end
    local cells = {}; for _, cell in ipairs(hunt.cells) do if not hunt.secured[cell] then cells[#cells + 1] = cell end end
    if #cells == 0 then return nil end -- Cornered: the champion stays visible in play.
    local revisions = {}
    for cell, deck in pairs(session.locationDecks.byCell) do revisions[cell] = { deck = deck, revision = deck.revision } end
    return { session = session, hunt = hunt, revision = hunt.revision, decks = session.locationDecks,
        revisions = revisions, cells = cells, champion = champion, sourceCell = sourceCell, random = random,
        health = champion.health, exhausted = champion.exhausted, engagedAgentId = champion.engagedAgentId,
        armies = session.armies, armyRevision = session.armies and session.armies.revision }
end
function Hunt.commitEscape(plan)
    if not plan or plan.committed then return false end
    local s, hunt = plan.session, plan.hunt
    if Outcome.finished(s) or s.missionHunt ~= hunt or hunt.revision ~= plan.revision or s.locationDecks ~= plan.decks then return false end
    if s.armies ~= plan.armies or (s.armies and s.armies.revision) ~= plan.armyRevision then return false end
    for cell, entry in pairs(plan.revisions) do
        if s.locationDecks.byCell[cell] ~= entry.deck or entry.deck.revision ~= entry.revision then return false end
    end
    local champion, cell, zone = Hunt.find(s, hunt.championInstanceId)
    if champion ~= plan.champion or cell ~= plan.sourceCell or zone ~= "inPlay" then return false end
    if champion.health ~= plan.health or champion.exhausted ~= plan.exhausted or champion.engagedAgentId ~= plan.engagedAgentId then return false end
    local nextHunt = copy(hunt)
    nextHunt.located, nextHunt.bodyguardIds = copy(hunt.located), {}
    local decks = cloneDecks(s.locationDecks)
    local removed = { [hunt.championInstanceId] = true }
    for _, id in ipairs(hunt.bodyguardIds) do
        local card = Hunt.find(s, id)
        if card and card.health > 0 then removed[id] = true end
    end
    for _, deck in pairs(decks.byCell) do
        for _, key in ipairs({ "drawPile", "discardPile", "inPlayOrder" }) do
            local list = {}
            for _, value in ipairs(deck[key]) do
                local id = type(value) == "table" and value.instanceId or value
                if not removed[id] then list[#list + 1] = value end
            end
            deck[key] = list
        end
        for id in pairs(removed) do deck.inPlay[id] = nil end
        deck.revealedTopId = nil
        deck.revision = deck.revision + 1
    end
    local moved = copy(champion); moved.faceUp = nil; moved.engagedAgentId = nil; moved.exhausted = false
    local group = { moved }; nextHunt.located[moved.instanceId] = nil
    for _ = 2, #plan.cells do
        local card = instance(nextHunt, hunt.bodyguardPool[pick(plan.random, #hunt.bodyguardPool)], decks.pool)
        nextHunt.bodyguardIds[#nextHunt.bodyguardIds + 1] = card.instanceId; group[#group + 1] = card
    end
    shuffle(group, plan.random)
    for i, target in ipairs(plan.cells) do
        local deck, card = decks.byCell[target], group[i]
        deck.drawPile[#deck.drawPile + 1] = card; shuffle(deck.drawPile, plan.random)
        if card.instanceId == hunt.championInstanceId and hunt.rules.revealChampionAtZeroStrength then
            local pair = s.armies and s.armies.byCell[target]
            if pair and pair.enemy.value == 0 then nextHunt.located[card.instanceId] = target end
        end
    end
    nextHunt.escapes, nextHunt.revision = hunt.escapes + 1, hunt.revision + 1
    s.locationDecks, s.missionHunt = decks, nextHunt
    s.huntPresentation = presentation(nextHunt, "escape", plan.cells, plan.sourceCell)
    s.pendingHuntEscape = nil; s.actionRevision = (s.actionRevision or 0) + 1
    plan.committed = true; return true
end
function Hunt.resolvePending(session, random)
    if not session.pendingHuntEscape or session.attackFeedback or session.talentFeedback then return false end
    local plan = Hunt.prepareEscape(session, random)
    if not plan then session.pendingHuntEscape = nil; return false end
    return Hunt.commitEscape(plan)
end

-- Only discovered information crosses into the map view.
function Hunt.markers(session)
    local result, hunt = {}, session.missionHunt
    if not hunt then return result end
    for cell in pairs(hunt.secured) do result[cell] = { secured = true, targets = {} } end
    local ids = { hunt.championInstanceId }
    for _, id in ipairs(hunt.companyIds) do ids[#ids + 1] = id end
    for _, id in ipairs(hunt.bodyguardIds) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local card, cell, zone = Hunt.find(session, id)
        if card and card.health > 0 and (zone == "inPlay" or (zone == "drawPile" and hunt.located[id] == cell)) then
            result[cell] = result[cell] or { targets = {} }
            result[cell].targets[#result[cell].targets + 1] = session.locationDecks.pool.byId[card.cardId].name
        end
    end
    return result
end
return Hunt
