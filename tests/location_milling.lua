return function(state, render)
    local Decks = require("src.sys.location_decks")
    local cardA = { instanceId = "a", cardId = "one" }
    local cardB = { instanceId = "b", cardId = "two" }
    local cardC = { instanceId = "c", cardId = "one" }
    local active = { instanceId = "active", cardId = "one", engagedAgentId = "agent" }
    local deck = { locationId = "loc", locationName = "Test", revision = 0, types = {},
        drawPile = { cardA, cardB, cardC }, discardPile = {}, inPlay = { active = active }, inPlayOrder = { "active" } }
    local decks = setmetatable({ byCell = { field = deck }, pool = { byId = {
        one = { name = "First", card_type = "ENEMY" }, two = { name = "Second", card_type = "BARRIER" } } } }, Decks)
    local plan = decks:prepareMill("field", 2)
    assert(#deck.drawPile == 3 and #deck.discardPile == 0 and deck.revision == 0)
    assert(plan.cards[1].instanceId == "c" and plan.cards[2].instanceId == "b")
    assert(decks:commitMill("field", plan) and not decks:commitMill("field", plan))
    assert(deck.discardPile[1] == cardC and deck.discardPile[2] == cardB and deck.drawPile[1] == cardA)
    assert(deck.inPlay.active == active and active.engagedAgentId == "agent" and #deck.inPlayOrder == 1)
    cardC.cardId = "changed"
    assert(plan.cards[1].cardId == "one", "Receipt must be detached from mutable cards")
    local stale = decks:prepareMill("field", 1)
    decks:draw("field")
    assert(not decks:commitMill("field", stale))
    local empty = decks:prepareMill("field", 10)
    assert(empty.actual == 0 and empty.after == 0 and #deck.discardPile == 2)
    assert(not pcall(decks.prepareMill, decks, "field", -1))

    local session, feedback, panel = state.session, state.testFeedback, state.exploration
    local pool = session.locationCardPool
    local cards = {}
    for i, id in ipairs(pool.ids) do
        cards[#cards + 1] = { instanceId = "mill_preview" .. i, cardId = id, name = pool.byId[id].name or id }
    end
    assert(#cards > 0)
    local function receipt(count)
        local r = { cards = {}, requested = count, actual = count, eliminated = count, before = count + 2,
            after = 2, locationId = session.assignments[panel.cell], locationName = "MILLING TEST", cell = panel.cell }
        for i = 1, count do r.cards[i] = cards[(i - 1) % #cards + 1] end
        return r
    end
    local Snapshot = require("src.sys.battlefield_engagement_record")
    local before = Snapshot.capture(session.armies, panel.cell)
    local record = Snapshot.complete(before, before, {
        enemy = { damage = 0, absorbed = 0, removed = {} }, allied = { damage = 0, absorbed = 0, removed = {} } })
    record.battlefield, record.battlefieldKind, record.agentId = true, "engage", state.activeAgentId
    record.test, record.success, record.name = { kind = "interact", label = "STEEL" }, true, "MILLING TEST"
    record.difficulty, record.base, record.committed, record.modifier, record.total = 1, 1, 0, 0, 1
    local revision, drawCount = session.armies.revision, #session.locationDecks.byCell[panel.cell].drawPile
    local function start(r)
        record.milling = r; feedback:start(record)
        assert(feedback.millingStart)
    end
    local function at(age, filename)
        feedback.elapsed = feedback.millingStart + age; render(filename)
    end
    start(receipt(3))
    assert(feedback.audio.sources.milling)
    local play, millSounds = feedback.audio.playOverlapping, 0
    feedback.audio.playOverlapping = function(_, cue)
        if cue == "milling" then millSounds = millSounds + 1 end
    end
    feedback:update(feedback.millingStart - 0.001)
    assert(millSounds == 0)
    feedback:update(0.002); feedback:update(0); feedback:update(100)
    assert(millSounds == 1, "Milling sound plays once at the animation start")
    feedback:clear(); feedback:update(100)
    assert(millSounds == 1)
    start(receipt(1)); feedback:clear(); feedback:update(100)
    assert(millSounds == 1, "Cancelled milling must not play its pending cue")
    record.milling = receipt(0); feedback:start(record); feedback:update(100)
    assert(millSounds == 1, "No milling presentation means no milling cue")
    start(receipt(3)); feedback:update(100)
    assert(millSounds == 2, "A new animation plays its cue even across a large frame")
    feedback.audio.playOverlapping = play
    start(receipt(3))
    local view = feedback.millingView
    for _, card in ipairs(cards) do
        local image = view.images[card.cardId]
        if image then assert(image:getFilter() == "nearest") end
    end
    assert(view:cardPose(1, 0.3, false).scale == 1)
    assert(view:cardPose(1, 0.3, true).x == 0)
    -- Observe the actual draw transforms: artwork is never rescaled or placed between pixels.
    local draw, seen = love.graphics.draw, 0
    love.graphics.draw = function(image, x, y, rotation, sx, sy, ...)
        for _, art in pairs(view.images) do
            if image == art then
                assert((sx or 1) == 1 and (sy or 1) == 1 and x % 1 == 0 and y % 1 == 0)
                seen = seen + 1
            end
        end
        return draw(image, x, y, rotation, sx, sy, ...)
    end
    local ok, err = pcall(at, 0.32, "location_milling_cards.png")
    love.graphics.draw = draw; assert(ok, err); assert(seen > 0)
    at(0.95, "location_milling_arrival.png")
    feedback.characterCutin.settings.reducedMotion = true
    at(0.32, "location_milling_reduced.png")
    feedback.characterCutin.settings.reducedMotion = false
    local one = receipt(1); start(one)
    at(0.3, "location_milling_single.png")
    view.images[one.cards[1].cardId] = nil
    at(0.3, "location_milling_missing.png")
    local large = receipt(50); start(large)
    assert(feedback.settings.stepDuration - feedback.millingStart <= 1.8)
    at(0.5, "location_milling_large.png")
    local noCards = receipt(0); noCards.requested, noCards.eliminated, noCards.before, noCards.after = 3, 3, 0, 0
    start(noCards); at(0.2, "location_milling_empty.png")
    local partial = receipt(1); partial.requested, partial.eliminated, partial.before, partial.after = 3, 3, 1, 0
    start(partial); at(0.9, "location_milling_partial.png")
    feedback:update(100); feedback:clear()
    assert(session.armies.revision == revision and #session.locationDecks.byCell[panel.cell].drawPile == drawCount)
    record.milling = receipt(0); feedback:start(record); assert(not feedback.millingStart); feedback:clear()

    state:focus(false)
    local live = session.locationDecks.byCell[panel.cell]
    local saved = live.lastMilling
    live.lastMilling = receipt(3)
    local box = panel:receiptBox()
    state:mousepressed(box.x + 4, box.y + 4, 1); state:mousereleased(box.x + 4, box.y + 4, 1)
    assert(panel.receiptOpen and not state.testPanel.card)
    local x, y = panel.x + 5, panel.listY + 43
    state:pointermoved(x, y)
    assert(state.previews.source == "location" and not panel:hoveredCard())
    assert(state.previews.views.location.settings.artSize >= 192)
    render("location_milling_receipt.png")
    state:mousepressed(x, y, 1); state:mousereleased(x, y, 1)
    assert(not state.testPanel.card, "Receipt entries are read-only")
    -- Exercise overflow without depending on today's small encounter catalogue.
    local long = receipt(0); long.actual = 20
    for i = 1, 20 do long.cards[i] = { instanceId = "scroll" .. i, cardId = "scroll" .. i, name = "Milled encounter " .. i } end
    live.lastMilling = long
    panel:pointermoved(x, y)
    local handFirst = state.hand.first
    assert(panel:wheelmoved(-100) and panel.receiptFirst > 1 and state.hand.first == handFirst)
    state.previews:clear(); render("location_milling_receipt_scrolled.png")
    local cell = panel.cell
    panel:setCell("north"); panel:setCell(cell)
    assert(panel:receipt() == long and not panel.receiptOpen)
    live.lastMilling = saved
end
