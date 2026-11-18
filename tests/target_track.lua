return function(write)
    local Targets = require("src.sys.mission_targets")
    local Accents = require("src.ui.preparation_accents")
    local Footer = require("src.ui.mission_footer")
    local catalogue = require("data.loc_cards.index").refresh()
    local champion = catalogue.byId.chp_cardinal
    local s = { missionHunt = { championId = champion.id, championInstanceId = "boss", companyIds = {} },
        locationDecks = { pool = catalogue, byCell = { hidden = { drawPile = {}, discardPile = {}, inPlay = {} } } } }
    local deck = s.locationDecks.byCell.hidden
    deck.drawPile[1] = { instanceId = "boss", cardId = champion.id, health = champion.health }
    for i, id in ipairs(champion.company) do
        s.missionHunt.companyIds[i] = "company" .. i
        deck.drawPile[#deck.drawPile + 1] = { instanceId = "company" .. i, cardId = id, health = catalogue.byId[id].health }
    end
    -- Bodyguards are deliberately absent from the objective projection.
    deck.drawPile[#deck.drawPile + 1] = { instanceId = "guard", cardId = "bdy_talon", health = 1 }
    local entries = Targets.read(s)
    assert(#entries == 6 and entries[1].champion and entries[1].cardId == champion.id)
    assert(entries[2].cardId == champion.company[1] and entries[6].cardId == champion.company[5])
    assert(not entries[1].cell and not entries[1].zone)
    assert(#Targets.read({}) == 0)

    local accents = Accents.new(1280, 720)
    local scene = { accents = accents, biome = { id = "the_cut", name = "The Cut" } }
    local footer = Footer.new(scene, s)
    assert(#footer.track.diagnostics == 0)
    local _, layout = footer:prepare(s)
    local label = accents:biomeLayout(scene.biome)
    assert(layout.width == 248 and layout.height == 54)
    assert(layout.x + layout.width + footer.track.settings.labelGap == label.x)
    assert(layout.y + layout.height == label.y + label.height)
    for _, p in ipairs(layout.panels) do
        assert(p.portraitWidth == 30 and p.portraitHeight == 30)
        assert(p.portraitX % 1 == 0 and p.portraitY % 1 == 0)
    end
    -- Damage, concealment and replacement instances never require a revision bump.
    deck.drawPile[1] = { instanceId = "boss", cardId = champion.id, health = 1 }
    local eliminated = table.remove(deck.drawPile, 2)
    eliminated.health = 0; deck.discardPile[1] = eliminated
    entries = Targets.read(s)
    assert(entries[1].health == 1 and entries[1].maxHealth == 2 and not entries[1].eliminated)
    assert(entries[2].instanceId == eliminated.instanceId and entries[2].eliminated)
    local _, diagnostics
    deck.discardPile = {}
    entries, diagnostics = Targets.read(s)
    assert(entries[2].health == nil and not entries[2].eliminated and #diagnostics == 1)
    deck.discardPile[1] = eliminated

    -- Fit both biome labels and the current hunt limit (one target per non-JACL cell).
    local biomes = require("data.biomes.index").refresh()
    for _, id in ipairs(biomes.ids) do
        local bounds = accents:biomeLayout(biomes.byId[id])
        local many = {}; for i = 1, 8 do many[i] = entries[(i - 1) % #entries + 1] end
        assert(footer.track:layout(many, bounds).x >= 16)
    end
    assert(not pcall(footer.track.layout, footer.track, entries, { x = 100, y = 650, height = 54 }))
    -- A larger asset reserves native space instead of being downscaled.
    footer.track.images.large = { getDimensions = function() return 44, 48 end }
    local large = footer.track:layout({ { cardId = "large", health = 100, maxHealth = 100 } }, label)
    assert(large.panels[1].portraitWidth == 44 and large.panels[1].width >= 52 and large.height >= 72)
    footer.track.images.large = nil

    -- Verify actual rendered opacity, cross-out, champion marker and graphics state.
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(canvas); love.graphics.clear(0.12, 0.14, 0.16, 1)
    love.graphics.setColor(0.2, 0.3, 0.4, 0.5); love.graphics.setLineWidth(3)
    footer:draw(s)
    local red, green, blue, alpha = love.graphics.getColor()
    assert(math.abs(red - 0.2) < 0.001 and math.abs(alpha - 0.5) < 0.001 and love.graphics.getLineWidth() == 3)
    love.graphics.setCanvas()
    local pixels = canvas:newImageData()
    local first, second = layout.panels[1], layout.panels[2]
    red, green, blue, alpha = pixels:getPixel(second.x, second.y)
    assert(red == 0 and green == 0 and blue == 0 and alpha == 1)
    red, green = pixels:getPixel(first.x, first.y)
    assert(red > 0.9 and green > 0.5, "Champion gold border missing")
    red, green = pixels:getPixel(second.portraitX + 14, second.portraitY + 14)
    assert(red > 0.8 and green < 0.5, "Eliminated target cross missing")
    write("target_track.png", pixels:encode("png"):getString())
    pixels:release(); canvas:release()
    -- Every full panel previews, even the health strip and eliminated portraits.
    for i, panel in ipairs(layout.panels) do
        assert(footer:pointer(s, panel.x + 1, panel.y + panel.height - 1))
        assert(footer.previews.instanceId == entries[i].instanceId)
        assert(footer.previews.cardId == entries[i].cardId)
    end
    assert(footer:pointer(s, second.x + 2, second.y + 2))
    assert(footer.previews.views.location.runtimeHealth == 0)
    assert(footer:wheel(-1))
    -- Pan both ways across every pixel: gaps must never clear the preview.
    for _, direction in ipairs({ 1, -1 }) do
        local start = direction == 1 and layout.x or layout.x + layout.width - 1
        local finish = direction == 1 and layout.x + layout.width - 1 or layout.x
        for x = start, finish, direction do
            assert(footer:pointer(s, x, first.y + 1), "Preview flickered while crossing the target row")
            assert(footer.hoveredId and footer.previews.source == "location")
        end
    end
    local midpoint = (first.x + first.width + second.x) / 2
    assert(footer:pointer(s, midpoint - 0.1, first.y + 1) and footer.hoveredId == entries[1].instanceId)
    assert(footer:pointer(s, midpoint, first.y + 1) and footer.hoveredId == entries[2].instanceId)
    for _, point in ipairs({ { layout.x - 0.1, first.y + 1 },
        { layout.x + layout.width, first.y + 1 }, { first.x + 1, first.y - 0.1 },
        { first.x + 1, first.y + first.height } }) do
        assert(not footer:pointer(s, point[1], point[2]), "Target hover must stop at the row edges")
    end
    assert(not footer.hoveredId and not footer.previews.source)
    assert(footer:pointer(s, first.x + 2, first.y + 2))
    deck.drawPile[1].health = 0
    footer:drawPreview(s)
    assert(footer.previews.views.location.runtimeHealth == 0, "Stationary hover must reflect live health")
    assert(not footer:pointer(s, nil, nil) and not footer.previews.source)
    require("tests.target_track_animation")(write, footer, s)
    -- Missing assets retain a panel, and only emit one diagnostic per path.
    footer.track:load({ { cardId = "missing_target_test" } })
    footer.track:load({ { cardId = "missing_target_test" } })
    assert(#footer.track.diagnostics == 1)
    local session = { missionFooter = footer }
    local transferred = require("src.sys.mission_session").take(session)
    assert(transferred.missionFooter == footer and not session.missionFooter)
    require("src.sys.mission_session").release(transferred)
    assert(not footer.track.font and next(footer.track.images) == nil and not footer.previews)
    accents:release()
end
