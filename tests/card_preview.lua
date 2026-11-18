return function(write)
    local Formatted = require("src.ui.formatted_text")
    local colors = require("data.text_format_colors")
    local base = { 1, 1, 1, 1 }
    local plain, colored = Formatted.parse("A [tag]LOCK [talent]FIRE[/talent] TAG[/tag].", base)
    assert(plain == "A LOCK FIRE TAG." and colored[3] == colors.tag and colored[5] == colors.talent
        and colored[7] == colors.tag and colored[9] == base)
    assert(Formatted.parse("[unknown]x[/unknown] [/tag]", base) == "[unknown]x[/unknown] [/tag]")
    for name, color in pairs(colors) do
        local visible, runs = Formatted.parse("[" .. name .. "]*[/" .. name .. "]", base)
        assert(visible == "*" and runs[1] == color)
    end
    local Display = require("src.sys.card_display")
    local normalized = Display.normalize({ name = "TEST", cost = 0,
        methods = { { type = "shadow", qty = 2 } }, card_display = {
        p10 = { "TEN" }, p2 = { "TWO", "SECOND LINE" }, p1 = { "ONE" },
    } })
    assert(normalized.paragraphs[1].number == 1 and normalized.paragraphs[2].number == 2
        and normalized.paragraphs[3].number == 10 and normalized.paragraphs[2].text == "TWO\nSECOND LINE")
    assert(#normalized.methods == 2 and normalized.health == 0 and normalized.slots == 0)
    assert(not pcall(Display.normalize, { name = "BAD", cost = 1, health = -1 }))
    for _, qty in ipairs({ -1, 1.5, "2" }) do
        assert(not pcall(Display.normalize, { name = "BAD", cost = 1, methods = { { type = "shadow", qty = qty } } }))
    end
    local canonical = { name = "TEST", cost = 2, card_type = "ASSET", health = 3, defiance = 4,
        tags = { "human" }, talents = { { type = "fire", qty = 2 } },
        card_display = { type = "STALE", health = 99, tags = { "STALE" }, talents = { "STALE" } } }
    local resolved = Display.normalize(canonical)
    assert(resolved.type == "ASSET" and resolved.health == 3 and resolved.defiance == 4
        and resolved.tags[1] == "human" and #resolved.talents == 2 and resolved.talents[2] == "fire")
    assert(canonical.talents[1].qty == 2 and canonical.tags[1] == "human")
    assert(not pcall(Display.normalize, { name = "BAD", cost = 1, card_display = { p1 = { "A" }, p01 = { "B" } } }))
    local Theme = require("data.preparation_theme")
    local fonts = { heading = love.graphics.newFont(Theme.headingFont, Theme.headingSize),
        small = love.graphics.newFont(Theme.smallFont, Theme.smallSize) }
    assert(fonts.heading:hasGlyphs("*^#+!"), "Preview font must support rule and stat glyphs")
    local settings = require("data.card_preview_view")
    local card = { name = "A LONG CARD NAME THAT WRAPS WITHOUT COVERING THE COST", cost = 12,
        asset_slots = 2, tags = { "LONG TAG", "ANOTHER TAG", "THIRD TAG" },
        talents = { { type = "missing_icon", qty = 1 } }, methods = { { type = "shadow", qty = 2 } },
        health = 2, defiance = 3, card_display = {} }
    for i = 1, 20 do card.card_display["p" .. i] = { "PARAGRAPH " .. i .. ": A [talent]LONG RULE[/talent] TO VERIFY SCROLLING AND WRAPPING." } end
    local Preview = require("src.ui.card_preview")
    local view = Preview.new({ byId = { missing_art = card, empty = { name = "EMPTY", cost = 0 } } },
        { { cardId = "missing_art" }, { cardId = "empty" } }, settings, fonts,
        { bounds = { x = 405, width = 470 } }, 720)
    assert(view.x == 520 and #view.diagnostics == 3)
    assert(view.rulesFont:getHeight() == 16 and view.rulesFont:hasGlyphs("*^#+!"))
    local l = view.layouts.missing_art
    assert(not l.rules:find("[talent]", 1, true))
    local _, visibleLines = view.rulesFont:getWrap(l.rules, l.width)
    local _, coloredLines = view.rulesFont:getWrap(l.coloredRules, l.width)
    assert(#visibleLines == #coloredLines, "Formatting must not change wrapping")
    assert(l.overflow > 0 and not l.wholeScroll and l.height == 672)
    assert(view.layouts.empty.footerHeight == 0 and view.layouts.empty.tagsY == nil)
    view:show("missing_art")
    view:wheelmoved(-1000)
    assert(view.scroll == l.overflow)
    view:show("missing_art")
    assert(view.scroll == l.overflow, "Duplicate copies must not reset preview scroll")
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(canvas); love.graphics.clear()
    view:draw()
    love.graphics.setCanvas()
    local pixels = canvas:newImageData()
    write("card_preview_overflow.png", pixels:encode("png"):getString())
    pixels:release(); canvas:release()
    view:wheelmoved(1000); assert(view.scroll == 0)
    view:show("empty"); assert(view.scroll == 0)
    view:show(nil); assert(not view.cardId)
    view:release(); assert(next(view.images) == nil)
    fonts.heading:release(); fonts.small:release()
end
