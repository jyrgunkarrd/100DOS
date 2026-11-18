return function(write, fixture, boundary, setGlory)
    local Effects = require("src.sys.transport_fate_effects")
    local Display = require("src.sys.fate_pool_display")
    local s = fixture(80)
    local original = s.fatePool.entries[1]
    local a, b = { id = "ripper", order = 1, vis_order = 2 }, { id = "ripper", order = 2, vis_order = 2 }
    s.silencers.transports = { a, b }
    Effects.sync(s, s.silencers.transports)
    assert(a.instanceId ~= b.instanceId and #s.fatePool.entries == 3)
    local entry = s.fatePool.entries[2]
    assert(entry.tileId == "silence" and entry.sourceName == "Ripper Squid")
    Effects.sync(s); Effects.sync(s)
    assert(#s.fatePool.entries == 3 and s.fatePool.entries[2] == entry)
    require("src.sys.location_card_effects").sync(s)
    assert(#s.fatePool.entries == 3)
    local row
    for _, r in ipairs(Display.pool(s.fatePool).rows) do if r.id == "silence" then row = r end end
    assert(row.quantity == 2 and #row.contributors == 2 and row.contributors[1].kind == "transport")
    local picked = require("src.sys.fate_draw").pick(s.fatePool, { random = function() return 2 end })
    assert(picked == "silence" and #s.fatePool.entries == 3)
    local unrelated = { tileId = "silence", sourceType = "agent", sourceId = "a" }
    table.insert(s.fatePool.entries, unrelated)
    Effects.sync(s, { b })
    assert(#s.fatePool.entries == 3 and s.fatePool.entries[1] == original and s.fatePool.entries[2] == unrelated)
    Effects.sync(s, {})
    assert(#s.fatePool.entries == 2 and s.fatePool.entries[2] == unrelated)
    local definitions = require("data.fate_tiles.index").refresh().byId
    assert(not pcall(Effects.validate, { id = "bad", ongoing_fate = { "missing" } }, definitions))
    assert(not pcall(Effects.validate, { id = "bad", ongoing_fate = { [2] = "silence" } }, definitions))
    for id, tile in pairs(definitions) do
        if tile.bonus then assert(not pcall(Effects.validate, { id = "bad", ongoing_fate = { id } }, definitions)); break end
    end
    -- Drive actual phase boundaries in both presentation modes.
    local config = require("data.silencer_view")
    local reduced = config.reducedMotion
    for _, mode in ipairs({ false, true }) do
        config.reducedMotion = mode
        local live = fixture(80)
        local catalogue = {}; for k, v in pairs(live.silencers.catalogue) do catalogue[k] = v end
        catalogue.choices = { "ripper" }; live.silencers.catalogue = catalogue
        setGlory(live, 0); boundary(live)
        assert(#live.silencers.transports == 1 and #live.fatePool.entries == 2)
        setGlory(live, 0)
        require("src.sys.agent_status").exhaust(live.agentStatus, "a")
        assert(require("src.sys.mission_phase").begin(live))
        if not mode then
            assert(#live.silencers.transports == 0 and #live.fatePool.entries == 2,
                "Contribution must last through departure")
        end
        require("src.sys.mission_phase").update(live, 20)
        assert(#live.silencers.transports == 0 and #live.fatePool.entries == 1)
    end
    config.reducedMotion = reduced
    -- Shared poses, transparent-pixel hit testing, frontmost overlap and real tile artwork.
    local view = require("src.ui.silencer_activity").new(s.silencers,
        { transportAnchor = function() return 640, 540, 1280, 720 end })
    s.silencers.transports, s.silencers.presentation = { a, b }, nil
    local poses = view:poses()
    local top = poses[#poses]
    local mask = view.hover.masks.ripper
    assert(mask and view.hover.tiles.silence)
    local hx, hy
    for y = 0, top.height - 1 do
        for x = 0, top.width - 1 do
            local _, _, _, alpha = mask:getPixel(x, y)
            if alpha > 0.9 then hx, hy = top.x + x, top.y + y; break end
        end
        if hx then break end
    end
    assert(view.hover:hit(hx, hy) == b)
    assert(not view.hover:hit(-1, hy))
    local px, py
    for y = 0, top.height - 1 do
        for x = 0, top.width - 1 do
            local _, _, _, alpha = mask:getPixel(x, y)
            if alpha == 0 then px, py = x, y; break end
        end
        if px then break end
    end
    s.silencers.transports = { b }
    top = view:poses()[1]
    assert(not view.hover:hit(top.x + px, top.y + py))
    assert(#view.hover:rows({ id = "whisper" }) == 0)
    s.silencers.transports = { a, b }
    assert(view.hover:pointer(hx, hy))
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(0.08, 0.1, 0.14, 1)
    view:draw(); view.hover:draw(1280, 720); love.graphics.pop()
    local pixels = canvas:newImageData(); local png = pixels:encode("png")
    write("transport_tooltip.png", png:getString())
    png:release(); pixels:release(); canvas:release(); view:release()
    write("transport_fate_results.txt", "PASS: stacking, ownership, sync, draws, departure, reduced motion, sources, validation and pixel hover\n")
end
