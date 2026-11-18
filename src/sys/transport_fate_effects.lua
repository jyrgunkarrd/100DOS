local Effects = {}
function Effects.validate(transport, definitions)
    local entries = transport.ongoing_fate
    if entries == nil then return end
    assert(type(entries) == "table", "ongoing_fate must be an array: " .. transport.id)
    local count = 0
    for i, id in pairs(entries) do
        count = count + 1
        assert(type(i) == "number" and i % 1 == 0 and i >= 1 and i <= #entries
            and type(id) == "string", "Invalid transport ongoing_fate: " .. transport.id)
        local tile = assert(definitions[id], "Unknown transport fate tile: " .. tostring(id))
        require("src.sys.fate_tile_definition").validate(tile, id)
        assert(not tile.bonus, "Transport ongoing_fate requires drawable tiles: " .. id)
    end
    assert(count == #entries, "Sparse transport ongoing_fate: " .. transport.id)
end

-- Replace only transport-owned contributions. Other sources retain their identity.
function Effects.sync(session, transports)
    local state, pool = session.silencers, session.fatePool
    if not state or not pool then return end
    transports = transports or state.ongoingTransports or state.transports
    local entries, previous = {}, {}
    for _, entry in ipairs(pool.entries) do
        if entry.transportEffect then
            previous[entry.sourceId .. ":" .. entry.sourceIndex] = entry
        else entries[#entries + 1] = entry end
    end
    local definitions = require("data.fate_tiles.index").refresh().byId
    for _, transport in ipairs(transports) do
        local definition = assert(state.catalogue.transports[transport.id])
        Effects.validate(definition, definitions)
        if not transport.instanceId then
            state.transportSerial = (state.transportSerial or 0) + 1
            transport.instanceId = "silencer_transport_" .. state.transportSerial
        end
        for i, tileId in ipairs(definition.ongoing_fate or {}) do
            pool.definitions[tileId] = pool.definitions[tileId] or definitions[tileId]
            local entry = previous[transport.instanceId .. ":" .. i]
            if not entry or entry.tileId ~= tileId then
                entry = { tileId = tileId, sourceType = "transport", sourceId = transport.instanceId,
                    sourceIndex = i, sourceName = definition.name, transportEffect = true }
            end
            entries[#entries + 1] = entry
        end
    end
    state.ongoingTransports, pool.entries = transports, entries
end
return Effects
