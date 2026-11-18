local Catalogue = {}
local function array(values, label)
    assert(type(values) == "table" and #values > 0, label .. " must be a nonempty array")
    local count = 0
    for key, value in pairs(values) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #values
            and type(value) == "string", "Invalid " .. label)
        count = count + 1
    end
    assert(count == #values, "Sparse " .. label)
end
function Catalogue.build(biome, definitions, squads, cards)
    local result = { transports = {}, troops = {}, sabotage = {}, pools = {}, choices = {} }
    for _, pool in ipairs(squads) do
        assert(type(pool.pool_id) == "string" and not result.pools[pool.pool_id], "Duplicate squad pool")
        array(pool.silencer_id, pool.pool_id)
        result.pools[pool.pool_id] = pool.silencer_id
    end
    array(biome.silencer_pool, "Biome silencer_pool")
    for _, id in ipairs(biome.silencer_pool) do
        local transport = assert(definitions.byId[id], "Unknown Silencer transport: " .. id)
        assert(type(transport.vis_order) == "number" and transport.vis_order == transport.vis_order
            and math.abs(transport.vis_order) < math.huge, "Invalid vis_order: " .. id)
        require("src.sys.transport_fate_effects").validate(transport, require("data.fate_tiles.index").refresh().byId)
        result.transports[id] = transport
        result.choices[#result.choices + 1] = id
        local pool = assert(result.pools[transport.silencer_squads], "Unknown transport squad pool: " .. id)
        for _, squadId in ipairs(pool) do
            local squad = assert(definitions.byId[squadId], "Unknown Silencer squad: " .. squadId)
            assert(squad.card_type == "SILENCER", "Expected SILENCER: " .. squadId)
            require("src.sys.location_card_state").initialize({}, squad)
            require("src.sys.talent_tests").resolve(squad)
            require("src.sys.attack_resolution").rating(squad.damage, "damage")
            require("src.sys.attack_resolution").rating(squad.trauma, "trauma")
            result.troops[squadId] = squad
            array(squad.sabotage, squadId .. " sabotage")
            for _, sabotageId in ipairs(squad.sabotage) do
                local card = assert(cards.byId[sabotageId], "Unknown sabotage: " .. sabotageId)
                assert(card.card_type == "SABOTAGE", "Expected SABOTAGE: " .. sabotageId)
                require("src.sys.talent_tests").resolve(card)
                for _, tileId in ipairs(card.ongoing_fate or {}) do
                    assert(require("data.fate_tiles.index").refresh().byId[tileId], "Unknown ongoing fate tile: " .. tostring(tileId))
                end
                result.sabotage[sabotageId] = card
            end
        end
    end
    return result
end
function Catalogue.load(biome)
    return Catalogue.build(biome, require("data.silencers.index").refresh(),
        require("data.silencer_squads"), require("data.loc_cards.index").refresh())
end
return Catalogue
