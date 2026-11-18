return function(write)
    local Display = require("src.sys.location_card_display")
    local cards = require("data.loc_cards.index").refresh()
    local enemy, barrier = Display.normalize(cards.byId.forgiven), Display.normalize(cards.byId.security_door)
    assert(enemy.tests[1].type == "steel" and enemy.tests[1].value == 3 and enemy.tests[2].value == 2)
    assert(#enemy.stats == 3 and enemy.stats[1].key == "health" and enemy.stats[1].value == 1)
    assert(enemy.stats[2].key == "damage" and enemy.stats[2].value == 1
        and enemy.stats[3].key == "trauma" and enemy.stats[3].value == 1)
    local ratings = Display.normalize({ name = "Ratings", damage = 0, trauma = 0 })
    assert(#ratings.stats == 2 and ratings.stats[1].value == 0 and ratings.stats[2].value == 0)
    assert(#Display.normalize({ name = "Trauma", trauma = 2 }).stats == 1)
    assert(#barrier.stats == 0 and barrier.tests[1].value == 8 and barrier.tests[2].value == 2)
    assert(barrier.type == "BARRIER" and barrier.cost == 0 and barrier.slots == 0)
    local zero = Display.normalize({ name = "Zero", health = 0, defiance = 0, cost = 9, asset_slots = 3 })
    assert(#zero.stats == 2 and zero.stats[1].value == 0 and zero.cost == 0 and zero.slots == 0)
    for _, v in ipairs({ -1, 1.5, "3", false, math.huge }) do
        assert(not pcall(Display.normalize, { name = "Invalid", talent_tests = { { type = "steel", val = v } } }))
        assert(not pcall(Display.normalize, { name = "Invalid", health = v }))
        assert(not pcall(Display.normalize, { name = "Invalid", damage = v }))
        assert(not pcall(Display.normalize, { name = "Invalid", trauma = v }))
    end
    assert(not pcall(Display.normalize, { name = "Bad", talent_tests = false }))
    assert(not pcall(Display.normalize, { name = "Bad", talent_tests = { [2] = { type = "steel", val = 2 } } }))
    local Theme = require("data.preparation_theme")
    local fonts = { heading = love.graphics.newFont(Theme.headingFont, Theme.headingSize),
        small = love.graphics.newFont(Theme.smallFont, Theme.smallSize) }
    local Preview = require("src.ui.card_preview")
    local settings = require("data.location_card_preview_view")
    local many = { name = "A LONG LOCATION CARD NAME THAT WRAPS", card_type = "BARRIER", health = 0, damage = 2, trauma = 3, talent_tests = {}, card_display = {} }
    for i = 1, 22 do many.talent_tests[i] = { type = "reason", val = i } end
    many.card_display.p1 = { "A [talent]FORMATTED[/talent] RULE." }
    local definitions = { byId = { forgiven = cards.byId.forgiven, security_door = cards.byId.security_door, missing = many,
        zero = { name = "ZERO", damage = 0, trauma = 0 }, rules = { name = "RULES", card_display = {} } } }
    for i = 1, 20 do definitions.byId.rules.card_display["p" .. i] = { "Long [tag]RULE[/tag] TEXT for preview scrolling and wrapping." } end
    local list = {}; for id in pairs(definitions.byId) do list[#list + 1] = { cardId = id } end
    local view = Preview.new(definitions, list, settings, fonts, { bounds = { x = 405, width = 470 } }, 720, Display.normalize)
    assert(view.layouts.security_door.footerHeight == 0 and view.layouts.security_door.pipsWidth == 0)
    assert(view.layouts.zero.hasStats and view.layouts.zero.statRows[1].text == "DAMAGE 0")
    local rows = view.layouts.forgiven.statRows
    assert(rows[2].text == "DAMAGE 1" and rows[3].text == "TRAUMA 1")
    assert(rows[2].y - rows[1].y == fonts.heading:getHeight() + settings.gap + settings.statGroupGap)
    assert(rows[3].y == rows[2].y and rows[2].align == "left" and rows[3].align == "right")
    assert(rows[2].x == 0 and rows[3].x + rows[3].width == view.layouts.forgiven.width)
    assert(view.layouts.zero.statRows[1].y == view.layouts.zero.statRows[2].y)
    assert(view.layouts.zero.statRows[1].y == 0)
    assert(settings.damageColor == settings.healthColor and settings.traumaColor == settings.defianceColor)
    assert(view.layouts.missing.wholeScroll and view.layouts.rules.overflow > 0)
    assert(view.layouts.security_door.testRows[1].label == "STEEL" and view.layouts.security_door.testRows[1].value == "8")
    assert(not view.layouts.missing.rules:find("[talent]", 1, true))
    local function render(id, name, scroll)
        view:show(id); if scroll then view:wheelmoved(-1000) end
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); view:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    render("security_door", "location_preview_barrier.png")
    render("forgiven", "location_preview_enemy.png")
    render("missing", "location_preview_overflow.png", true)
    assert(view.scroll == view.layouts.missing.overflow and #view.diagnostics >= 3)
    -- Distinct collections may use identical IDs without mixing content or artwork.
    local agent = Preview.new({ byId = { security_door = { name = "AGENT CARD", cost = 2 } } },
        { { cardId = "security_door" } }, require("data.card_preview_view"), fonts,
        { bounds = { x = 405, width = 470 } }, 720)
    local sounds = 0
    local controller = require("src.ui.card_preview_controller").new(agent, view,
        { playOverlapping = function() sounds = sounds + 1 end })
    controller:show("player_card", { instanceId = 1, cardId = "security_door" })
    assert(agent.cardId == "security_door" and not view.cardId)
    controller:show("location", { instanceId = "location_1", cardId = "security_door" })
    assert(not agent.cardId and view.cardId == "security_door" and sounds == 2)
    controller:show("location", { instanceId = "location_2", cardId = "security_door" })
    assert(controller.instanceId == "location_2" and sounds == 2)
    controller:show("location", { instanceId = "overflow", cardId = "missing" })
    assert(controller:wheelmoved(-1) and view.scroll > 0)
    controller:show("location", { instanceId = "enemy1", cardId = "forgiven", engagedAgentId = "AGENT ONE" })
    local cached = view.images[settings.artDirectory .. "/forgiven.png"]
    assert(view.engagementText == "ENGAGED WITH AGENT ONE" and not view.displays.forgiven.engagementText)
    controller:show("location", { instanceId = "enemy2", cardId = "forgiven", engagedAgentId = "AGENT TWO" })
    assert(view.engagementText == "ENGAGED WITH AGENT TWO" and view.images[settings.artDirectory .. "/forgiven.png"] == cached)
    controller:show("location", { instanceId = "enemy3", cardId = "forgiven" })
    assert(not view.instanceDisplay and not view.engagementText)
    controller:clear(); assert(not controller.source and not view.cardId and not agent.cardId)
    controller:release(); assert(next(view.images) == nil and next(agent.images) == nil)
    fonts.heading:release(); fonts.small:release()
end
