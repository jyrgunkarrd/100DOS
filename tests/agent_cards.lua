return function(write)
    local Cards = require("src.sys.agent_cards")
    local defaults = require("data.card_system_defaults")
    local definitions = { byId = { a = { name = "ALPHA", cost = 0 }, b = { name = "BETA", cost = 4 } } }
    local agents = { byId = {
        one = { card_deck = { { card_id = "a", card_qty = 6 }, { card_id = "b", card_qty = 4 } } },
        two = { card_deck = { { card_id = "b", card_qty = 3 } } },
    } }
    local function create(seed)
        return Cards.new({ "one", "two" }, agents, definitions, defaults, love.math.newRandomGenerator(seed))
    end
    local cards, same = create(42), create(42)
    local unique, counts = {}, { a = 0, b = 0 }
    for id, state in pairs(cards.byAgent) do
        for i, card in ipairs(state.drawPile) do
            assert(not unique[card.instanceId]); unique[card.instanceId] = true
            counts[card.cardId] = counts[card.cardId] + 1
            assert(card.instanceId == same.byAgent[id].drawPile[i].instanceId)
        end
    end
    assert(counts.a == 6 and counts.b == 7)
    local staged = cards:prepareDrawTo("one", 5)
    assert(#staged.hand == 5 and #staged.drawPile == 5 and #cards.byAgent.one.hand == 0)
    cards:commitHand("one", staged)
    local again = cards:prepareDrawTo("one", 5)
    assert(#again.drawPile == 5)
    for i = 1, 5 do assert(again.hand[i] == staged.hand[i]) end
    table.remove(staged.hand); table.remove(staged.hand)
    local topped = cards:prepareDrawTo("one", 5)
    assert(#topped.hand == 5 and #topped.drawPile == 3 and topped.hand[1] == staged.hand[1])
    topped.hand[#topped.hand + 1] = table.remove(topped.drawPile)
    cards:commitHand("one", topped)
    assert(#cards:prepareDrawTo("one", 5).hand == 6 and #cards:prepareDrawTo("one", 5).drawPile == 2)
    local short = cards:prepareDrawTo("two", 5)
    assert(#short.hand == 3 and #short.drawPile == 0)
    cards:commitHand("two", short)
    assert(#cards:prepareDrawTo("two", 5).hand == 3)
    -- Fixed draws preserve excess hands and draw only available cards.
    local drawn = cards:prepareDraw("one", 1)
    assert(#drawn.hand == 7 and #drawn.drawPile == 1 and #cards.byAgent.one.hand == 6)
    cards:commitHand("one", drawn)
    cards:commitHand("one", cards:prepareDraw("one", 10))
    assert(#cards.byAgent.one.hand == 8 and #cards.byAgent.one.drawPile == 0)
    assert(#cards:prepareDraw("one", 1).hand == 8)
    assert(#cards:prepareDraw("two", 1).hand == 3)
    local empty = create(42)
    assert(#empty:prepareDraw("one", 1).hand == 1)
    assert(#empty:prepareDraw("one", 0).hand == 0)
    local Rules = require("src.sys.agent_card_rules")
    local rules = Rules.resolve(defaults, { startingHandSize = 0, activationDrawCount = 2 }, "test")
    assert(rules.startingHandSize == 0 and rules.activationDrawCount == 2)
    assert(Rules.resolve(defaults, { startingHandSize = 3 }, "test").activationDrawCount == 1)
    for _, invalid in ipairs({ -1, 1.5, math.huge, "5", false }) do
        assert(not pcall(Rules.resolve, defaults, { startingHandSize = invalid }, "bad"))
        assert(not pcall(Rules.resolve, defaults, { activationDrawCount = invalid }, "bad"))
    end
    assert(not pcall(Rules.resolve, defaults, { typo = 5 }, "bad"))
    agents.byId.one.card_rules = { startingHandSize = 3, activationDrawCount = 2 }
    local custom = create(42)
    assert(custom.rules.one.startingHandSize == 3 and custom.rules.one.activationDrawCount == 2)
    assert(custom.rules.two.startingHandSize == 5)
    agents.byId.one.card_rules = nil
    assert(#agents.byId.one.card_deck == 2 and agents.byId.one.card_deck[1].card_qty == 6)
    for _, entry in ipairs({ { card_id = "missing", card_qty = 1 },
        { card_id = "a", card_qty = -1 }, { card_id = "a", card_qty = 1.5 } }) do
        assert(not pcall(Cards.new, { "bad" }, { byId = { bad = { card_deck = { entry } } } }, definitions, defaults))
    end
    local Session = require("src.sys.mission_session")
    local source = { agentCards = cards }
    local session = Session.take(source)
    assert(not source.agentCards and session.agentCards == cards)
    Session.release(session)
    assert(not session.agentCards)

    local Hand = require("src.ui.agent_hand")
    local settings = require("data.agent_hand_view")
    local font = love.graphics.newFont(require("data.preparation_theme").smallFont, 8)
    local equipment = { x = 882, y = 304, settings = { labelGap = 4 } }
    local realDefinitions = require("data.cards.index").refresh()
    local list = {}
    for i = 1, 40 do list[i] = { instanceId = i, cardId = "catburglar" } end
    local view = Hand.new(list, realDefinitions, settings, font, equipment, 1072)
    assert(view.width == 182 and view.step >= settings.minimumStep and #view.entries < #list)
    assert(view:revealDuration() <= settings.revealMaximum + 0.000001)
    assert(view:revealPose(1, settings.revealMaximum + 0.000001).alpha == 1)
    local first = view.entries[1]
    view:hover(first.x + 5, first.y + 1)
    assert(view.hovered == 1)
    view:hover(first.x + 5, first.y + view.step + 1)
    assert(view.hovered == 2, "Raised card must not trap hover over the next strip")
    for _ = 1, 50 do view:wheelmoved(0, -1) end
    assert(view.entries[#view.entries].card.instanceId == 40)
    local last = view.entries[#view.entries]
    assert(last.y + settings.height <= view.bottom and view.entries[1].y >= view.top)
    view:hover(last.x + 5, last.y + 1)
    assert(view.hovered == 40)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    view:draw()
    love.graphics.setCanvas()
    local pixels = canvas:newImageData()
    write("agent_hand_overflow.png", pixels:encode("png"):getString())
    pixels:release(); canvas:release()
    view:clearHover()
    local oldFirst = view.first
    view:wheelmoved(0, 1)
    assert(view.first == oldFirst and not view.hovered)
    view:release()
    assert(next(view.images) == nil)
    -- Missing art and long names remain drawable with the same tile geometry.
    local fallback = Hand.new({ { instanceId = 1, cardId = "missing_test" } },
        { byId = { missing_test = { name = "A VERY LONG CARD NAME THAT MUST FIT", cost = 12 } } },
        settings, font, equipment, 1072)
    assert(#fallback.diagnostics == 1)
    fallback:draw(); fallback:release(); font:release()
end
