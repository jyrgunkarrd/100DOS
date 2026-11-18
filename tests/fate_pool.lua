return function()
    local Pool = require("src.sys.fate_pool")
    local Index = require("data.fate_tiles.index")
    local settings = require("data.fate_pool_defaults")
    local catalogues = {
        agents = require("data.agents.index").refresh(),
        captains = require("data.captains.index").refresh(),
        jacls = require("data.jacls.index").refresh(),
    }
    local selection = { agentIds = {}, captainId = "saber", jaclId = "val" }
    for i = 1, 6 do selection.agentIds[i] = catalogues.agents.ids[i] end
    local tiles = Index.refresh()
    local function build() return Pool.build(selection, catalogues, tiles, settings) end
    local function rejects(callback, message)
        local ok, failure = pcall(callback)
        assert(not ok and tostring(failure):find(message, 1, true), tostring(failure))
    end
    local pool, counts = build(), {}
    assert(#pool.entries == 20)
    for i, entry in ipairs(pool.entries) do
        counts[entry.tileId] = (counts[entry.tileId] or 0) + 1
        if i <= 18 then
            assert(entry.sourceType == "agent" and entry.sourceId == selection.agentIds[math.ceil(i / 3)])
            assert(entry.sourceIndex == (i - 1) % 3 + 1)
        end
    end
    assert(counts.neutral == 6 and counts.brutality == 6 and counts.neg_two == 6
        and counts.autosuccess == 1 and counts.autofail == 1)
    assert(pool.entries[19].sourceId == "saber" and pool.entries[20].sourceId == "val")
    assert(pool.definitions.neg_two.negative and pool.definitions.neg_two.value == 2)
    assert(pool.definitions.autofail.special == "auto_failure" and pool.definitions.autofail.img
        and pool.definitions.autofail.value == nil)
    local other = build()
    pool.entries[1].tileId = "changed"
    pool.definitions.neg_two.value = 99
    assert(other.entries[1].tileId == "neutral" and other.definitions.neg_two.value == 2)
    assert(tiles.byId.neg_two.value == 2)
    tiles.byId.neutral.value = 9
    assert(other.definitions.neutral.value == 0)
    tiles.byId.neutral.value = 0

    local a = catalogues.agents.byId[selection.agentIds[1]]
    local b = catalogues.agents.byId[selection.agentIds[2]]
    local originalA, originalB = a.fate, b.fate
    a.fate = { "neutral", "neutral", "neutral" }
    local repeated = build()
    assert(repeated.entries[1].tileId == repeated.entries[2].tileId
        and repeated.entries[1] ~= repeated.entries[2])
    local Display = require("src.sys.fate_pool_display")
    local summary = Display.pool(repeated)
    local rows = {}
    for _, row in ipairs(summary.rows) do rows[row.id] = row end
    assert(summary.total == 20 and rows.neutral.quantity == 8 and #rows.neutral.contributors == 6)
    local sourceCounts = {}
    for _, source in ipairs(rows.neutral.contributors) do sourceCounts[source.id] = source.quantity end
    assert(sourceCounts[selection.agentIds[1]] == 3)
    assert(rows.autosuccess.contributors[1].kind == "captain"
        and rows.autosuccess.contributors[1].name == catalogues.captains.byId.saber.name.text)
    assert(rows.autofail.contributors[1].kind == "jacl"
        and rows.autofail.contributors[1].name == catalogues.jacls.byId.val.name)
    assert(Display.pool(repeated, selection.agentIds[1]).rows[1].quantity == 3)
    rows.neutral.contributors[1].quantity = 100
    assert(Display.pool(repeated).rows[1].quantity == 8 and #repeated.entries == 20)
    local sharedName = Display.pool({ definitions = { a = { name = "SAME" }, b = { name = "SAME" } }, entries = {
        { tileId = "b" }, { tileId = "a", sourceType = "agent", sourceId = "same" },
        { tileId = "a", sourceType = "captain", sourceId = "same" },
    } })
    assert(#sharedName.rows == 2 and sharedName.rows[1].id == "a" and sharedName.rows[1].quantity == 2)
    assert(#sharedName.rows[1].contributors == 2 and sharedName.rows[1].contributors[1].name == "same")
    -- Contributions are checked collectively, not fixed at three per Agent.
    a.fate, b.fate = { "neutral", "neutral" }, { "neutral", "neutral", "neutral", "neutral" }
    assert(#build().entries == 20)
    b.fate = originalB
    rejects(build, "Agents contributed 17")
    a.fate = { "missing" }
    rejects(build, "unknown tile missing")
    a.fate = { [1] = "neutral", [3] = "neutral" }
    rejects(build, "dense array")
    a.fate = nil
    rejects(build, "must be an array")
    a.fate = originalA
    local captain = catalogues.captains.byId.saber
    captain.fate = { "autosuccess", "autosuccess" }
    rejects(build, "Captain contributed 2")
    captain.fate = { "autosuccess" }
    catalogues.jacls.byId.val.fate = {}
    rejects(build, "JACL contributed 0")
    catalogues.jacls.byId.val.fate = { "autofail" }
    selection.captainId = "missing"
    rejects(build, "unknown captain missing")
    selection.captainId = "saber"
    selection.agentIds[2] = selection.agentIds[1]
    rejects(build, "duplicate Agent")
    selection.agentIds[2] = catalogues.agents.ids[2]
    rejects(function() Pool.build(selection, catalogues, tiles,
        { agents = 18, captain = 1, jacl = 1, total = 21 }) end, "sum to total")

    local definition = { id = "test", value = 0 }
    local fs = {
        getInfo = function(path) return { type = path:match("%.lua$") and "file" or "directory" } end,
        getDirectoryItems = function() return { "test.lua" } end,
        load = function() return function() return definition end end,
    }
    for _, value in ipairs({ -1, math.huge, 0 / 0, "zero" }) do
        definition.value = value
        rejects(function() Index.refresh("fixture", fs) end, "value must be")
    end
    definition.value, definition.negative = 0, "yes"
    rejects(function() Index.refresh("fixture", fs) end, "negative must be")
    definition.negative, definition.special = nil, ""
    rejects(function() Index.refresh("fixture", fs) end, "unknown special")
    definition.special = nil
    definition.value, definition.name = nil, ""
    rejects(function() Index.refresh("fixture", fs) end, "name must be")
    definition.name, definition.img = "Test", "yes"
    rejects(function() Index.refresh("fixture", fs) end, "img must be")
    definition.img, definition.clash = true, { amt = 0 }
    rejects(function() Index.refresh("fixture", fs) end, "clash.amt must be")
    definition.clash.amt, definition.clash.en_dmg = 2, 1.5
    rejects(function() Index.refresh("fixture", fs) end, "clash.en_dmg must be")
    definition.clash.en_dmg, definition.clash.en_bonus = nil, -1
    rejects(function() Index.refresh("fixture", fs) end, "clash.en_bonus must be")
    definition.clash.en_bonus = nil
    assert(Index.refresh("fixture", fs).byId.test.value == nil)
    fs.getDirectoryItems = function() return { "test.lua", "duplicate.lua" } end
    rejects(function() Index.refresh("fixture", fs) end, "Duplicate Fate tile")

    local Session = require("src.sys.mission_session")
    local holder = { fatePool = other }
    local session = Session.take(holder)
    assert(not holder.fatePool and session.fatePool == other)
    Session.release(session)
    assert(not session.fatePool)
end
