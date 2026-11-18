return function(write)
    local Routing = require("src.sys.army_routing")
    local Targets = require("src.sys.mission_targets")
    local Hunt = require("src.sys.mission_hunt")
    local Clashes = require("src.sys.battlefield_clashes")
    local State = require("src.sys.battlefield_state")
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy = machine.current
    deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, "north") end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local host, s = machine.current, machine.current.session
    host:update(20)
    local ids = s.missionHunt.companyIds
    assert(#ids >= 2)
    local id, second = ids[1], ids[2]
    assert(not Routing.available(s, id))
    Hunt.find(s, id).health = 0
    Hunt.find(s, second).health = 0
    assert(not Routing.available(s, s.missionHunt.championInstanceId))
    assert(not Routing.prepare(s, id, s.armies.jaclCellId))
    assert(not Routing.prepare(s, id, "missing"))
    local pair = s.armies.byCell.north
    pair.protection = 3
    local allies = pair.allied.forces
    local regular, elite = s.armies.pools.enemy.regular[1], s.armies.pools.enemy.elite[1]
    pair.enemy.forces = { { id = "r", forceId = regular }, { id = "e", forceId = elite } }
    pair.clashes = { { tileId = "brutality", remaining = 3 } }
    State.touch(s.armies, "north")
    local stale = assert(Routing.prepare(s, id, "north"))
    State.touch(s.armies, "north")
    assert(not stale:commit() and #pair.enemy.forces == 2)
    local before = #Targets.read(s)
    local function panelFor(company)
        local entries, layout = s.missionFooter:prepare(s)
        for i, entry in ipairs(entries) do if entry.instanceId == company then return layout.panels[i] end end
        error("Missing Company panel")
    end
    local function drag(company, x, y)
        local panel = panelFor(company)
        host:mousepressed(panel.x + 3, panel.y + 3, 1)
        assert(s.missionFooter.routing.drag.pending)
        host:pointermoved(x, y)
        host:mousereleased(x, y, 1)
    end
    drag(id, 1, 1)
    assert(#Targets.read(s) == before and #pair.enemy.forces == 2)
    local panel = panelFor(id)
    host:mousepressed(panel.x + 3, panel.y + 3, 1)
    host:pointermoved(640, 360)
    host:keypressed("escape")
    assert(not s.missionFooter.routing.drag.pending and Routing.available(s, id))
    local cell
    for _, c in ipairs(s.grid.cells) do if c.id == "north" then cell = c end end
    -- Put a hunt card on top to verify routing uses ordinary special-card entry.
    local third = ids[3]
    if third then
        local card = assert(Hunt.find(s, third))
        for _, deck in pairs(s.locationDecks.byCell) do
            for _, zone in ipairs({ "drawPile", "discardPile" }) do
                for i = #deck[zone], 1, -1 do
                    if deck[zone][i].instanceId == third then table.remove(deck[zone], i) end
                end
            end
            deck.inPlay[third] = nil
            for i = #deck.inPlayOrder, 1, -1 do
                if deck.inPlayOrder[i] == third then table.remove(deck.inPlayOrder, i) end
            end
            deck.revision = deck.revision + 1
        end
        table.insert(s.locationDecks.byCell.north.drawPile, card)
    end
    local deckBefore = #s.locationDecks.byCell.north.drawPile
    local secured = s.missionHunt.secured.north
    drag(id, cell.x, cell.y)
    if third then assert(s.locationDecks.byCell.north.inPlay[third] and s.missionHunt.located[third] == "north") end
    assert(pair.routedBy == id and #pair.enemy.forces == 0 and pair.enemy.value == 0)
    assert(pair.allied.forces == allies and pair.protection == 3)
    assert(s.missionHunt.secured.north == secured)
    assert(#pair.clashes == 0 and Clashes.count(pair) == 0)
    assert(#Targets.read(s) == before - 1 and not Routing.available(s, id))
    local receipt = s.locationDecks.byCell.north.lastMilling
    assert(receipt.eliminated == 2 and receipt.requested == 2 * require("data.battlefield_rules").cardsMilledPerEnemyEliminated)
    assert(#s.locationDecks.byCell.north.drawPile == deckBefore - receipt.actual)
    assert(not Routing.prepare(s, second, "north"))
    Clashes.enqueue(pair, { remaining = 4 })
    assert(#pair.clashes == 0)
    local fateEntries = s.fatePool.entries
    s.fatePool.entries = { { tileId = "brutality" } }
    local reveal = require("src.sys.fate_reveal")
    local effect = reveal.prepare(s, { cell = "north" }, 3, 0, 2)
    assert(not effect.batch)
    reveal.commit(effect)
    s.fatePool.entries = fateEntries
    assert(#pair.clashes == 0)
    local canvas = love.graphics.newCanvas(1280, 720)
    local function render(name)
        love.graphics.setCanvas(canvas); love.graphics.clear(); host:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); local encoded = pixels:encode("png")
        write(name, encoded:getString()); encoded:release(); pixels:release()
    end
    host:update(0.3)
    render("routing_milling.png")
    host:update(20)
    render("routing_map.png")
    for _, label in ipairs(s.armyView.labels) do
        if label.cellId == "north" then assert(label.enemy == "X" and not s.armyView:clashLabel(label)) end
    end
    host.selectedId = s.package.agentIds[1]; assert(host:beginAgentAction())
    host = machine.current; host:update(20)
    if s.phaseFeedback then host:update(20) end
    assert(not Clashes.ready(s, host.activeAgentId))
    assert(not require("src.sys.clash_reinforcements").ready(s, host.activeAgentId))
    local south = s.armies.byCell.south
    south.enemy.forces = {}; State.touch(s.armies, "south")
    for _, c in ipairs(s.grid.cells) do if c.id == "south" then cell = c end end
    drag(second, cell.x, cell.y)
    assert(south.routedBy == second and s.locationDecks.byCell.south.lastMilling.requested == 0)
    render("routing_agent.png")
    canvas:release(); host:exit()
    write("routing_results.txt", "PASS: single use, stale plans, cancellation, both views, milling, permanent routing, labels and reinforcement prevention\n")
end
