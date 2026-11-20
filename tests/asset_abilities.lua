return function()
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation")
    assert(machine.current:deploy())
    local deploy, cell = machine.current, "north"
    deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, cell) end
    deploy.agentView:refresh()
    assert(deploy:beginAction())
    local mission = machine.current
    mission:update(1)
    local id = mission.session.package.agentIds[1]
    mission.selectedId = id
    assert(mission:beginAgentAction())
    local state, s = machine.current, machine.current.session
    state:update(2)
    local status, deck = s.agentStatus.byAgent[id], s.locationDecks.byCell[cell]
    local piles = s.agentCards.byAgent[id]
    local first = { cardId = "catburglar", instanceId = 10001 }
    local second = { cardId = "catburglar", instanceId = 10002 }
    local third = { cardId = "catburglar", instanceId = 10003 }
    piles.hand = { first, second, third }
    status.actionPoints, status.resources = 3, 5
    local Resolution = require("src.sys.agent_action_resolution")
    local function equip(card)
        assert(Resolution.execute(s, id, "play_card", { instanceId = card.instanceId, start = 1 }))
        state.hand.cards = piles.hand
        state.hand:layout()
    end
    local function click(x, y)
        state:pointermoved(x, y)
        state:mousepressed(x, y, 1)
        state:mousereleased(x, y, 1)
    end
    local function menuChoice(key)
        local menu = assert(state.assetMenu)
        for i, row in ipairs(menu.rows) do
            if row.ability.id == key then
                assert(not row.reason, row.reason)
                local x, y, width
                if row.args.zone == "hand" then
                    for _, entry in ipairs(state.hand.entries) do
                        if entry.card.instanceId == row.args.instanceId then x, y, width = entry.x, entry.y, state.hand.width end
                    end
                else
                    local asset = s.agentAssets.byAgent[id].placements[1]
                    x, y, width = state.equipment:bounds(asset.start, asset.size)
                end
                assert(menu.x == x + math.floor((width - menu.width) / 2))
                if key == "expend" then assert(menu.y + i * menu.rowHeight == y) end
                click(menu.x + 5, menu.y + (i - 1) * menu.rowHeight + 5)
                assert(not state.assetMenu)
                return
            end
        end
        error("Missing ability " .. key)
    end
    local function button(key)
        for _, b in ipairs(state.testPanel:buttons()) do
            if b.id == key then click(b.x + 5, b.y + 5); return end
        end
        error("Missing test button " .. tostring(key))
    end
    equip(first)
    local door = { cardId = "security_door", instanceId = "test-door" }
    deck.inPlay, deck.inPlayOrder = { [door.instanceId] = door }, { door.instanceId }
    s.locationDecks.pool.byId.security_door = require("data.loc_cards.barriers.security_door")
    local panel = state.testPanel
    for _, test in ipairs({ 1, 2 }) do
        panel:open(door)
        button(test)
        local left, top = state.equipment:bounds(1, 1)
        local right = state.equipment:bounds(3, 1)
        click(left + 4, top + 4)
        assert(panel:evaluate().assetBonus == 1)
        click(right + 4, top + 4)
        assert(panel:evaluate().assetBonus == 0)
        click(right + 4, top + 4)
        assert(panel:evaluate().assetBonus == 1 and not s.agentAssets:at(id, 1).exhausted)
        if test == 1 then button("cancel") end
    end
    s.fatePool.entries = { { tileId = "autosuccess" } }
    button("confirm")
    assert(s.agentAssets:at(id, 1).exhausted and not deck.inPlay[door.instanceId])
    assert(#require("src.sys.asset_abilities").exhaustOptions(s, id, { tags = { "lock" } }) == 0)
    state:update(5)
    local x, y = state.equipment:bounds(2, 1)
    s.locationDecks.pool.byId.blast_door = require("data.loc_cards.jacl_systems.blast_door")
    deck.drawPile[#deck.drawPile + 1] = { cardId = "blast_door", instanceId = "next-door" }
    local revealed = { cardId = "security_door", instanceId = "revealed-door", faceUp = true }
    deck.drawPile[#deck.drawPile + 1] = revealed
    local explore = require("src.sys.location_exploration")
    assert(explore.evaluate(s, id, state.exploration.rules).valid)
    local attacker = { instanceId = "guard", cardId = "forgiven", engagedAgentId = id, health = 3 }
    deck.inPlay.guard = attacker
    deck.inPlayOrder[#deck.inPlayOrder + 1] = "guard"
    status.health, status.defiance = 100, 100
    status.actionPoints = 0
    click(x + 4, y + 4)
    menuChoice("expend")
    assert(s.attackFeedback and #s.attackFeedback.events == 1 and s.attackFeedback.events[1].instanceId == "guard")
    attacker.engagedAgentId = nil
    assert(piles.discardPile[#piles.discardPile] == first and not s.agentAssets:at(id, 2))
    state:update(5)
    local entry = state.hand.entries[1]
    assert(entry.card == second)
    assert(deck.inPlay[revealed.instanceId])
    assert(explore.evaluate(s, id, state.exploration.rules).reason == "Blocked by Security Door")
    click(entry.x + 5, entry.y + 5)
    assert(state.assetMenu.rows[1].reason and piles.hand[1] == second)
    state:keypressed("escape")
    assert(s.locationDecks:discard(cell, revealed.instanceId))
    click(entry.x + 5, entry.y + 5)
    menuChoice("expend")
    assert(status.actionPoints == 0 and piles.discardPile[#piles.discardPile] == second)
    state:update(5)
    status.actionPoints = 1
    equip(third)
    click(x + 4, y + 4)
    menuChoice("retask")
    assert(status.actionPoints == 0 and status.turnTalentBonuses.fire == 2)
    for slot = 1, 3 do assert(not s.agentAssets:at(id, slot)) end
    local copies = 0
    for _, card in ipairs(piles.drawPile) do if card == third then copies = copies + 1 end end
    assert(copies == 1)
    local pair = s.armies.byCell[cell]
    for _, side in ipairs({ "allied", "enemy" }) do
        pair[side].forces = { { id = side, forceId = s.armies.pools[side].regular[1] } }
    end
    local locationId = s.assignments[cell]
    local location = s.locations.byId[locationId]
    local replacement = {}
    for key, value in pairs(location) do replacement[key] = value end
    replacement.battlefield_talent = { { type = "fire", qty = 2 } }
    s.locations.byId[locationId] = replacement
    local clashes = require("src.sys.battlefield_clashes")
    clashes.enqueue(pair, clashes.prepareBatch("test", { amt = 1 }))
    assert(state:endTurn() and s.pendingEndTurn)
    button(1)
    local printed = require("src.sys.talent_values").sum(s.agentCards.agents.byId[id].talents, "fire")
    assert(panel:evaluate().base == printed + 2)
    button("confirm")
    assert(s.talentFeedback.base == printed + 2 and status.turnTalentBonuses.fire == 2)
    state:update(5)
    assert(status.exhausted and not status.turnTalentBonuses)
    local testAsset = { exhausted = true }
    local refresh = { agentAssets = { byAgent = { a = { placements = { testAsset } } } } }
    require("src.sys.agent_turn").commitRefresh(refresh, {})
    assert(not testAsset.exhausted)
    s.locations.byId[locationId] = location
    machine.current:exit()
end
