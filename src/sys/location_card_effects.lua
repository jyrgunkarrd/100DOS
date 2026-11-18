local Effects = {}
function Effects.validate(definition)
    local reward = definition.on_resolve
    if reward == nil then return end
    assert(type(reward) == "table", "on_resolve must be a table: " .. tostring(definition.id))
    for kind, amount in pairs(reward) do
        assert(kind == "security", "Unknown resolution reward: " .. tostring(kind))
        assert(require("src.sys.location_deck_recipe").whole(amount), "Invalid Security reward")
    end
end
function Effects.prepareResolution(session, definition)
    Effects.validate(definition)
    local gain = definition.on_resolve and definition.on_resolve.security
    if gain == nil then return nil end
    local cap, before = require("data.jacl_actions").securityCap, session.jaclSecurity or 0
    local whole = require("src.sys.location_deck_recipe").whole
    assert(whole(cap) and whole(before) and before <= cap, "Invalid JACL Security state")
    return { before = before, after = math.min(cap, before + gain) }
end
function Effects.canResolve(session, reward)
    return not reward or (session.jaclSecurity or 0) == reward.before
end
function Effects.resolve(session, reward, result)
    if not reward then return end
    session.jaclSecurity = reward.after
    result.security = { before = reward.before, after = reward.after, gained = reward.after - reward.before }
end
-- Rebuild only contributions owned by this system; unrelated physical tiles survive.
function Effects.sync(session)
    if not session.fatePool or not session.locationDecks then return end
    local pool, entries = session.fatePool, {}
    for _, entry in ipairs(pool.entries) do
        if not entry.locationEffect then entries[#entries + 1] = entry end
    end
    local cells = {}; for cell in pairs(session.locationDecks.byCell) do cells[#cells + 1] = cell end
    table.sort(cells)
    for _, cell in ipairs(cells) do
        local deck = session.locationDecks.byCell[cell]
        for _, id in ipairs(deck.inPlayOrder) do
            local card = deck.inPlay[id]
            local definition = session.locationDecks.pool.byId[card.cardId]
            for i, tileId in ipairs(definition.ongoing_fate or {}) do
                if not pool.definitions[tileId] then
                    pool.definitions[tileId] = assert(require("data.fate_tiles.index").refresh().byId[tileId], "Unknown ongoing fate tile")
                end
                if pool.definitions[tileId].bonus then
                    pool.bonusSources = pool.bonusSources or {}
                    local key = id .. ":" .. i .. ":" .. tileId
                    if not pool.bonusSources[key] then
                        require("src.sys.fate_reserve").add(pool,pool.definitions[tileId],1,definition.name)
                        pool.bonusSources[key] = true
                    end
                else
                    entries[#entries + 1] = { tileId = tileId, sourceType = "sabotage", sourceId = id,
                        sourceIndex = i, sourceName = definition.name, locationEffect = true }
                end
            end
        end
    end
    pool.entries = entries
end
return Effects
