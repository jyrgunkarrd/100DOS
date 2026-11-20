return function(write)
    local Decks = require("src.sys.location_decks")
    local Explore = require("src.sys.location_exploration")
    local rules = require("data.location_exploration_rules")
    local definitions = { e = { card_type = "ENEMY", health = 2, name = "Enemy" }, b = { card_type = "BARRIER", name = "Barrier" } }
    local pool = { ids = { "e", "b" }, byId = definitions, byType = { ENEMY = { "e" }, BARRIER = { "b" } } }
    local locations = { byId = { a = { name = "Test", deck_size = 3, deck_build = {
        { type = "ENEMY", qty = 2 }, { type = "BARRIER", qty = 1 } } } } }
    local decks = Decks.new({ west = "a", east = "a" }, locations, pool, love.math.newRandomGenerator(7))
    local s = { locationDecks = decks, activeAgentId = "one", agentDeployment = { placements = { one = "west", two = "west" } },
        agentStatus = { byAgent = { one = { actionPoints = 3, resources = 5, health = 6, defiance = 6 }, two = { actionPoints = 3, health = 6, defiance = 6 } } } }
    local status = s.agentStatus.byAgent.one
    local before = decks:summary("west")
    assert(before.total == 3 and before.byType.ENEMY == 2 and before.byType.BARRIER == 1)
    local staged = decks:prepareDraw("west")
    assert(decks:summary("west").total == 3 and #decks.byCell.west.inPlayOrder == 0)
    local ok, card = Explore.commit(s, "one", rules)
    assert(ok and status.actionPoints == 2 and status.resources == 5)
    assert(not decks:commitDraw("west", staged), "Stale prepared draws must not replay")
    local after = decks:summary("west")
    local kind = definitions[card.cardId].card_type
    assert(after.total == 2 and after.byType[kind] == before.byType[kind] - 1)
    for t, n in pairs(before.byType) do if t ~= kind then assert(after.byType[t] == n) end end
    assert(decks:summary("east").total == 3 and decks.byCell.west.inPlayOrder[1] == card.instanceId)
    assert(not Explore.commit(s, "two", rules))
    status.exhausted = true; assert(not Explore.commit(s, "one", rules)); status.exhausted = false
    status.actionPoints = 0; assert(not Explore.commit(s, "one", rules)); status.actionPoints = 2
    s.agentDeployment.placements.one = nil; assert(not Explore.commit(s, "one", rules)); s.agentDeployment.placements.one = "west"
    local original = decks.prepareDraw
    decks.prepareDraw = function() error("injected draw failure") end
    assert(not pcall(Explore.commit, s, "one", rules))
    assert(status.actionPoints == 2 and decks:summary("west").total == 2)
    decks.prepareDraw = original
    assert(Explore.commit(s, "one", rules)); s.attackFeedback = nil
    assert(Explore.commit(s, "one", rules)); s.attackFeedback = nil
    assert(status.actionPoints == 0 and not Explore.commit(s, "one", rules))
    local empty = decks:summary("west")
    assert(empty.total == 0 and empty.byType.ENEMY == 0 and empty.byType.BARRIER == 0 and empty.revealed == 3)
    status.actionPoints = 3; assert(not Explore.commit(s, "one", rules) and status.actionPoints == 3)
    local order = decks.byCell.west.inPlayOrder
    local last = order[3]
    assert(decks:discard("west", order[2]) and #order == 2 and order[2] == last)
    assert(decks:summary("west").total == 0 and decks:summary("west").revealed == 2)
    for _, cost in ipairs({ -1, 0.5, math.huge, "1" }) do assert(not pcall(Explore.validate, { actionPointCost = cost })) end

    -- Real content, UI cancellation, failed preparation, and shared location persistence.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deployment = machine.current; deployment:update(2)
    -- Scrolling an exhausted ordinary deck remains playable; JACL exhaustion
    -- is terminal and is covered by tests.doom_clock.
    local cell
    for id in pairs(deployment.assignments) do if id ~= "center" then cell = id; break end end
    for _, id in ipairs(deployment.package.agentIds) do deployment.agentDeployment:assign(id, cell) end
    deployment.agentView:refresh(); assert(deployment:beginAction())
    local mission = machine.current; mission:update(1)
    local session = mission.session
    local ids = session.package.agentIds
    -- Keep this exploration fixture independent of hunt insertions.
    local pile = session.locationDecks.byCell[cell].drawPile
    for i = #pile, 1, -1 do
        if require("src.sys.location_card_traits").hunt(session.locationCardPool.byId[pile[i].cardId]) then table.remove(pile, i) end
    end
    -- This scenario checks shared-location persistence, not lethal combat. Random
    -- low-health Agents must survive the exploration and end-turn attacks.
    for _, id in ipairs(ids) do
        session.agentStatus.byAgent[id].health = 100
        session.agentStatus.byAgent[id].defiance = 100
    end
    local Engagement = require("src.sys.location_engagement")
    local function putEnemyOnTop()
        local pile = session.locationDecks.byCell[cell].drawPile
        for i, card in ipairs(pile) do
            if session.locationCardPool.byId[card.cardId].card_type == "ENEMY" then
                pile[i], pile[#pile] = pile[#pile], card; return
            end
        end
    end
    putEnemyOnTop()
    mission.selectedId = ids[1]
    local load = love.filesystem.load
    love.filesystem.load = function(path)
        if path == "data/location_exploration_view.lua" then return function() return {} end end
        return load(path)
    end
    assert(not mission:beginAgentAction())
    love.filesystem.load = load
    assert(#session.agentCards.byAgent[ids[1]].hand == 5 and session.locationDecks:summary(cell).total == 20)
    assert(mission:beginAgentAction())
    local active = machine.current
    assert(not active:explore()); active:update(1)
    local panel = active.exploration
    active.actions:setTab("location")
    active.actions:setOpen(true)
    local x, y = active.actions.rows[1].x+4,active.actions.rows[1].y+4
    local function click()
        if not active.actions.open then
            local b=active.actions.button
            active:mousepressed(b.x+4,b.y+4,1); active:mousereleased(b.x+4,b.y+4,1)
        end
        active:mousepressed(x, y, 1); active:mousereleased(x, y, 1)
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); active:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString())
        pixels:release(); canvas:release()
    end
    render("location_exploration_empty.png")
    active:mousepressed(x, y, 1); active:focus(false); active:mousereleased(x, y, 1)
    active:mousepressed(x, y, 1); active:mousereleased(0, 0, 1)
    active:mousepressed(x, y, 1); active:keypressed("escape"); active:mousereleased(x, y, 1)
    active:mousepressed(x, y, 1); active:mousepressed(x, y, 2); active:mousereleased(x, y, 1)
    assert(session.locationDecks:summary(cell).total == 20)
    active.actions:close()
    local handCard = active.hand.entries[1]
    active:mousepressed(handCard.x + 2, handCard.y + 2, 1)
    active:pointermoved(x, y); assert(not active:explore()); active:mousereleased(x, y, 1)
    assert(session.locationDecks:summary(cell).total == 20)
    click()
    local status = session.agentStatus.byAgent[ids[1]]
    assert(status.actionPoints == 2 and status.resources == 5 and session.locationDecks:summary(cell).total == 19)
    active:mousereleased(x, y, 1); click(); assert(not active:explore())
    assert(session.locationDecks:summary(cell).total == 19)
    assert(Engagement.count(session, ids[1]) == 1)
    assert(active.actions.open, "Actions remain open after Explore")
    active.actions:close()
    active:pointermoved(panel.x + 3, panel.listY + 3)
    assert(active.previews.views.location.engagementText == "ENGAGED WITH " .. panel:agentName(ids[1]))
    render("location_engagement_reveal.png")
    active:pointermoved(x, y)
    render("location_exploration_reveal.png")
    -- Keep this sequence focused on repeated exploration and engagement.
    for _ = 1, 2 do
        active:update(2)
        putEnemyOnTop()
        click()
    end
    active:update(2)
    assert(status.actionPoints == 0 and session.locationDecks:summary(cell).total == 17)
    click(); assert(session.locationDecks:summary(cell).total == 17)
    assert(active:allActionsSpent() and not active.done.hovered and machine.current == active)
    render("location_exploration_no_actions.png")
    local firstCard = session.locationDecks.byCell[cell].inPlayOrder[1]
    assert(active:endTurn())
    if active.feedback:busy() then active:update(20) end
    assert(next(panel.images) == nil)
    mission = machine.current; mission:update(1); mission.selectedId = ids[2]; assert(mission:beginAgentAction())
    active = machine.current; active:update(1); panel = active.exploration
    assert(panel.cell == cell and session.locationDecks.byCell[cell].inPlayOrder[1] == firstCard)
    assert(session.locationDecks.byCell[cell].inPlay[firstCard].engagedAgentId == ids[1])
    putEnemyOnTop()
    assert(active:explore()); active:update(2)
    assert(session.locationDecks:summary(cell).total == 16)
    assert(Engagement.count(session, ids[2]) == 1)
    local newlyRevealed = session.locationDecks.byCell[cell].inPlayOrder[4]
    assert(session.locationDecks.byCell[cell].inPlay[newlyRevealed].engagedAgentId == ids[2])
    panel.first = panel:lastPageStart()
    local entries = panel:visibleCards()
    local lastEntry = entries[#entries]
    active:pointermoved(lastEntry.x + 3, lastEntry.y + 3)
    render("location_engagement_shared.png")
    for i = 1, #entries - 1 do
        assert(entries[i + 1].y == entries[i].y + entries[i].hitHeight)
        active:pointermoved(entries[i].x + 3, entries[i].y + entries[i].hitHeight - 1)
        assert(active.previews.instanceId == entries[i].card.instanceId)
    end
    local oldName = panel.agentNames[ids[2]]
    panel.agentNames[ids[2]] = "AN AGENT WITH A VERY LONG NAME THAT MUST WRAP IN THE PREVIEW AND TRUNCATE ON THE TILE"
    active:pointermoved(lastEntry.x + 3, lastEntry.y + 3)
    render("location_engagement_long_name.png")
    panel.agentNames[ids[2]] = oldName
    active:focus(false)
    -- Fill the view to exercise scrolling and an empty deck with unresolved cards.
    local card
    while true do
        local drawn = session.locationDecks:draw(cell)
        if not drawn then break end
        card = drawn
    end
    panel:revealed(card); active:update(0.3)
    assert(panel.first > 1 and not active:explore())
    panel:pointermoved(panel.x + 3, panel.listY + 3)
    local first = panel.first
    active:wheelmoved(0, 1); assert(panel.first == first - 1)
    panel:pointermoved(800, 400); first = panel.first
    active:wheelmoved(0, 1); assert(panel.first == first)
    render("location_exploration_depleted.png")
    -- Inspection works with an empty deck and no actions; it never changes gameplay state.
    local beforeActions = session.agentStatus.byAgent[ids[2]].actionPoints
    session.agentStatus.byAgent[ids[2]].actionPoints = 0
    local deck = session.locationDecks.byCell[cell]
    local revision, orderCount = deck.revision, #deck.inPlayOrder
    active:pointermoved(panel.x + 3, panel.listY + 3)
    assert(active.previews.source == "location" and not active.preview.cardId)
    local hovered = panel:hoveredCard()
    assert(active.previews.instanceId == hovered.instanceId)
    render("location_preview_in_game.png")
    local oldFirst = panel.first
    active:wheelmoved(0, 1)
    assert(panel.first == oldFirst - 1 and active.previews.instanceId == panel:hoveredCard().instanceId)
    local down = love.keyboard.isDown
    love.keyboard.isDown = function() return true end
    oldFirst = panel.first
    active:wheelmoved(0, -1)
    love.keyboard.isDown = down
    assert(panel.first == oldFirst, "Shift-wheel must not scroll the location list")
    local handEntry = active.hand.entries[1]
    active:pointermoved(handEntry.x + 2, handEntry.y + 2)
    assert(active.previews.source == "player_card" and not active.previews.views.location.cardId)
    active:mousepressed(handEntry.x + 2, handEntry.y + 2, 1)
    active:pointermoved(panel.x + 3, panel.listY + 3)
    assert(not active.previews.source)
    active:focus(false)
    active:pointermoved(panel.x + 3, panel.listY + 3); active:keypressed("escape")
    active:update(0); assert(not active.previews.source)
    active:pointermoved(panel.x + 3, panel.listY + 3); active:focus(false)
    assert(not active.previews.source)
    local visible = panel:visibleCards()
    for i = 1, #visible - 1 do
        local entry = visible[i]
        for gapY = entry.y + entry.height, visible[i + 1].y - 1 do
            active:pointermoved(panel.x + 3, gapY)
            assert(active.previews.source == "location" and active.previews.instanceId == entry.card.instanceId,
                "Internal gaps must retain the preceding location card preview")
        end
        active:pointermoved(panel.x + 3, visible[i + 1].y)
        assert(active.previews.instanceId == visible[i + 1].card.instanceId)
    end
    local last = visible[#visible]
    for _, point in ipairs({ { panel.x - 1, panel.listY + 3 },
        { panel.x + panel.width, panel.listY + 3 }, { panel.x + 3, panel.listY - 1 },
        { panel.x + 3, last.y + last.height } }) do
        active:pointermoved(point[1], point[2])
        assert(not active.previews.source, "Outer bounds must still dismiss location previews")
    end
    active:pointermoved(panel.x + 3, panel.y + 52)
    assert(not active.previews.source, "Deck summary and button never reveal undrawn cards")
    assert(deck.revision == revision and #deck.inPlayOrder == orderCount and session.agentStatus.byAgent[ids[2]].actionPoints == 0)
    session.agentStatus.byAgent[ids[2]].actionPoints = beforeActions
    -- Fallback labels, long names, and missing artwork stay drawable without costs.
    local settings = {}
    for k, v in pairs(require("data.location_exploration_view")) do settings[k] = v end
    settings.directory = "missing_location_test"; settings.typeLabels = {}; settings.typeOrder = {}
    local fallback = require("src.ui.location_exploration_panel").new(session, ids[2], settings, rules, panel.fonts)
    for _, def in pairs(fallback.definitions) do def.name = "A VERY LONG LOCATION CARD NAME THAT MUST FIT WITHOUT A COST BOX" end
    assert(#fallback.diagnostics == #session.locationCardPool.ids and fallback.types[1] == "BARRIER")
    fallback:draw(true); fallback:release()
    for _, id in ipairs(ids) do
        session.agentStatus.byAgent[id].exhausted = true
        session.agentStatus.byAgent[id].actionPoints = 0
    end
    session.activeAgentId = nil
    assert(require("src.sys.agent_turn").refreshAll(session))
    assert(session.locationDecks:summary(cell).total == 0 and session.locationDecks:summary(cell).revealed == 20)
    assert(session.locationDecks.byCell[cell].inPlay[firstCard].engagedAgentId == ids[1]
        and session.locationDecks.byCell[cell].inPlay[newlyRevealed].engagedAgentId == ids[2])
    machine:change("mission_preparation")
    assert(next(panel.images) == nil and not session.locationDecks)
    machine.current:exit()
end
