return function(write)
    local Hunt = require("src.sys.mission_hunt")
    local Decks = require("src.sys.location_decks")
    local Entry = require("src.sys.location_card_entry")
    local Elimination = require("src.sys.location_card_elimination")
    local Resolution = require("src.sys.agent_action_resolution")
    local Turn = require("src.sys.agent_turn")
    local View = require("src.ui.hunt_distribution")
    local Targets = require("src.sys.mission_targets")
    local catalogue = require("data.loc_cards.index").refresh()
    local function rng(seed) return love.math.newRandomGenerator(seed or 11) end
    local first = { random = function() return 1 end }
    local biome = { champ_pool = { "chp_cardinal" } }
    local function source()
        local assignments, byCell = { center = "ordinary" }, { center = { enemy = { value = 0 } } }
        for i = 1, 8 do
            assignments["cell" .. i] = "ordinary"
            byCell["cell" .. i] = { enemy = { value = 1 } }
        end
        local pool = { ids = { "enemy" }, byType = { ENEMY = { "enemy" } }, byId = {
            enemy = { id = "enemy", name = "Enemy", card_type = "ENEMY", health = 2, damage = 1, trauma = 0,
                talent_tests = { { id = "strike", kind = "strike", val = 0 }, { id = "evade", kind = "evade", val = 0 } } } } }
        local decks = Decks.new(assignments, { byId = { ordinary = { name = "Ordinary", deck_size = 2,
            deck_build = { { type = "ENEMY", qty = 2 } } } } }, pool, rng())
        return { assignments = assignments, locationDecks = decks, locationCardPool = pool,
            armies = { jaclCellId = "center", byCell = byCell } }
    end
    local function fixture(seed)
        local s = source()
        for key, value in pairs(Hunt.prepareInitial(s, biome, catalogue, rng(seed))) do s[key] = value end
        s.agentDeployment = { placements = { a = "cell1", b = "cell1" } }
        s.agentStatus = { byAgent = {
            a = { health = 20, defiance = 20, resources = 5, actionPoints = 3, actionPointCapacity = 3 },
            b = { health = 20, defiance = 20, resources = 5, actionPoints = 3, actionPointCapacity = 3 } } }
        s.agentCards = { agents = { byId = { a = { talents = { { type = "steel", qty = 10 } } },
            b = { talents = { { type = "steel", qty = 10 } } } } }, definitions = { byId = {} },
            byAgent = { a = { hand = {}, discardPile = {} }, b = { hand = {}, discardPile = {} } } }
        s.fatePool = { entries = { { tileId = "neutral" } }, definitions = { neutral = { value = 0 } } }
        s.activeAgentId = "a"; return s
    end
    local function reveal(s, id, agentId)
        local card, cell, zone = Hunt.find(s, id)
        assert(zone == "drawPile")
        local deck = s.locationDecks.byCell[cell]
        for i, entry in ipairs(deck.drawPile) do if entry.instanceId == id then table.remove(deck.drawPile, i); break end end
        deck.drawPile[#deck.drawPile + 1] = card
        s.agentDeployment.placements[agentId or "a"] = cell
        local staged = s.locationDecks:prepareDraw(cell)
        Entry.prepare(s, cell, staged, agentId or "a")
        assert(s.locationDecks:commitDraw(cell, staged)); Entry.committed(s, cell, staged.card)
        return staged.card, cell
    end
    local function eliminate(s, id)
        local card, cell = reveal(s, id); card.health = 0
        assert(Elimination.commit(s, cell, id, first))
        assert(not Elimination.commit(s, cell, id, first), "Elimination must be idempotent")
        return card, cell
    end
    local function clear(s) s.talentFeedback, s.attackFeedback = nil, nil end

    -- Exact coverage, independent repeated guards, reproducibility and source isolation.
    local untouched = source()
    local prepared = Hunt.prepareInitial(untouched, biome, catalogue, rng())
    assert(#untouched.locationDecks.byCell.cell1.drawPile == 2 and #untouched.locationCardPool.ids == 1)
    assert(prepared.locationDecks ~= untouched.locationDecks and prepared.locationCardPool ~= untouched.locationCardPool)
    local s, same = fixture(), fixture()
    local seen, roles = {}, {}
    for cell, deck in pairs(s.locationDecks.byCell) do
        assert(#deck.drawPile == (cell == "center" and 2 or 3))
        local count = 0
        for i, card in ipairs(deck.drawPile) do
            assert(not seen[card.instanceId]); seen[card.instanceId] = true
            assert(card.cardId == same.locationDecks.byCell[cell].drawPile[i].cardId)
            local definition = s.locationCardPool.byId[card.cardId]
            if require("src.sys.location_card_traits").hunt(definition) then
                count = count + 1; roles[definition.card_type] = (roles[definition.card_type] or 0) + 1
                assert(card.health == definition.health and card.exhausted == false)
            end
        end
        assert(count == (cell == "center" and 0 or 1))
        local summary = s.locationDecks:summary(cell)
        assert(not summary.byType.CHAMPION and not summary.byType.COMPANY and not summary.byType.BODYGUARD)
        local public = s.locationDecks:publicSummary(cell)
        assert(public.total == 2 and (public.concealed == true) == (cell ~= "center"))
    end
    assert(roles.CHAMPION == 1 and roles.COMPANY == 5 and roles.BODYGUARD == 2)
    assert(#s.missionHunt.companyIds == 5 and #s.missionHunt.bodyguardIds == 2)
    assert(next(Hunt.markers(s)) == nil)
    assert(catalogue.byId.chp_cardinal.health == 2)

    -- Invalid candidates fail before RNG or source mutations, including unselected candidates.
    local calls = 0
    local counted = { random = function() calls = calls + 1; return 1 end }
    local function invalid(b, c)
        local raw = source(); assert(not pcall(Hunt.prepareInitial, raw, b, c or catalogue, counted))
        assert(calls == 0 and #raw.locationDecks.byCell.cell1.drawPile == 2)
    end
    invalid({ champ_pool = {} }); invalid({ champ_pool = { "missing" } })
    invalid({ champ_pool = { "chp_cardinal", "chp_cardinal" } })
    invalid({ champ_pool = { [1] = "chp_cardinal", [3] = "missing" } })
    local function badChampion(change)
        local champion = {}; for k, v in pairs(catalogue.byId.chp_cardinal) do champion[k] = v end
        change(champion)
        local byId = {}; for k, v in pairs(catalogue.byId) do byId[k] = v end; byId.chp_cardinal = champion
        invalid(biome, { byId = byId })
    end
    badChampion(function(c) c.company = { "missing" } end)
    badChampion(function(c) c.company = { "cmp_thumb", "cmp_thumb" } end)
    badChampion(function(c) c.bodyguards = {} end)
    badChampion(function(c) c.bodyguards = { "cmp_thumb" } end)
    badChampion(function(c) c.health = 0 end)
    local raw = source(); raw.assignments.cell8, raw.assignments.cell7, raw.assignments.cell6 = nil, nil, nil
    assert(not pcall(Hunt.prepareInitial, raw, biome, catalogue, counted) and calls == 0)

    -- Ordinary combat behavior applies to all roles. Intel only marks a hidden target.
    s = fixture()
    local guardId = s.missionHunt.bodyguardIds[1]
    local guard, guardCell = reveal(s, guardId)
    assert(guard.engagedAgentId == "a")
    local attackers = require("src.sys.opportunity_attacks").collect(s, "a", "explore")
    assert(#attackers == 1 and attackers[1].instanceId == guardId)
    local ok, result = Resolution.execute(s, "a", "talent_test", { instanceId = guardId, testId = "strike", random = first })
    assert(ok and result.defeated and guard.health == 0)
    assert(s.missionHunt.secured[guardCell] and Hunt.markers(s)[guardCell].secured)
    local champion, championCell, zone = Hunt.find(s, s.missionHunt.championInstanceId)
    assert(zone == "drawPile" and s.missionHunt.located[champion.instanceId] == championCell)
    assert(#s.locationDecks.byCell[championCell].inPlayOrder == 0, "Intel must not put its target in play")
    assert(Hunt.markers(s)[championCell].targets[1] == "Cardinal Hand")
    clear(s)
    local _, securedCell = eliminate(s, s.missionHunt.companyIds[1])
    assert(s.missionHunt.secured[securedCell] and Hunt.markers(s)[securedCell].secured)

    -- Flee preserves wounds, clears engagement and old intel, replaces surviving guards.
    champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    champion.health, champion.exhausted = 1, true
    local oldGuard = s.missionHunt.bodyguardIds[2]
    reveal(s, oldGuard)
    for _, pair in pairs(s.armies.byCell) do pair.enemy.value = 0 end
    Hunt.queueEscape(s)
    s.attackFeedback = {}; assert(not Hunt.resolvePending(s, first)); s.attackFeedback = nil
    local plan = assert(Hunt.prepareEscape(s, first))
    local serial = s.missionHunt.serial
    s.locationDecks.byCell[championCell].revision = s.locationDecks.byCell[championCell].revision + 1
    assert(not Hunt.commitEscape(plan) and s.missionHunt.serial == serial)
    assert(Hunt.resolvePending(s, first) and not s.pendingHuntEscape)
    champion, championCell, zone = Hunt.find(s, s.missionHunt.championInstanceId)
    assert(champion.health == 1 and not champion.exhausted and not champion.engagedAgentId and zone == "drawPile")
    assert(championCell ~= securedCell and s.missionHunt.located[champion.instanceId] == championCell)
    assert(#s.missionHunt.bodyguardIds == 5 and s.missionHunt.escapes == 1)
    assert(championCell ~= guardCell)
    assert(not Hunt.find(s, oldGuard), "Surviving old bodyguard must be withdrawn")
    local dead, _, deadZone = Hunt.find(s, guardId)
    assert(dead and dead.health == 0 and deadZone == "discardPile", "Eliminated guards remain eliminated")
    assert(not Hunt.resolvePending(s, first) and not Hunt.commitEscape(plan))
    -- A hidden company plus a replacement screen must not advertise an extra hunt card.
    for _, cell in ipairs(s.missionHunt.cells) do
        assert(s.locationDecks:publicSummary(cell).total == 2)
    end
    local company = Hunt.find(s, s.missionHunt.companyIds[2]); assert(company and company.health == 1)

    -- Intel expires on the next escape unless the new destination is undefended.
    reveal(s, champion.instanceId)
    for _, pair in pairs(s.armies.byCell) do pair.enemy.value = 1 end
    Hunt.queueEscape(s); assert(Hunt.resolvePending(s, rng(41)))
    assert(not s.missionHunt.located[champion.instanceId])

    -- Milling every special role enters play and prepares local engagement without live mutation.
    s = fixture()
    local ids = { s.missionHunt.championInstanceId, s.missionHunt.companyIds[1], s.missionHunt.bodyguardIds[1] }
    for _, id in ipairs(ids) do
        local card, cell = Hunt.find(s, id)
        local deck = s.locationDecks.byCell[cell]
        for i, value in ipairs(deck.drawPile) do if value.instanceId == id then table.remove(deck.drawPile, i); break end end
        deck.drawPile[#deck.drawPile + 1] = card
        s.agentDeployment.placements.a = cell
        local mill = s.locationDecks:prepareMill(cell, 1)
        local publicBefore, publicAfter, concealed = s.locationDecks:publicMillCounts(cell, mill)
        assert(publicBefore == 2 and publicAfter == 2 and concealed)
        assert(#mill.entered == 1 and #mill.discardPile == 0 and not card.engagedAgentId)
        local entry = { card = mill.entered[1], inPlay = mill.inPlay }
        Entry.prepare(s, cell, entry, "a"); mill.entered[1] = entry.card
        assert(not card.engagedAgentId and entry.card.engagedAgentId == "a")
        assert(s.locationDecks:commitMill(cell, mill))
        Entry.committed(s, cell, entry.card)
        local entered, enteredCell, enteredZone = Hunt.find(s, id)
        assert(enteredCell == cell and enteredZone == "inPlay" and entered.engagedAgentId == "a")
        assert(mill.cards[1].destination == "inPlay" and not s.locationDecks:commitMill(cell, mill))
    end

    -- A completed Agent turn queues exactly one escape, never a premature Done clash.
    s = fixture(); champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    champion.exhausted = true -- No end-turn attack in this timing check.
    assert(Turn.finish(s, "a") and s.pendingHuntEscape and not s.activeAgentId)
    assert(not Turn.finish(s, "a") and not Turn.refreshAll(s))
    assert(Hunt.resolvePending(s, first) and s.missionHunt.escapes == 1)
    assert(not Hunt.resolvePending(s, first))

    -- Starting required Done clashes is not the end of the Agent's turn.
    s = fixture(); champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    local pair = s.armies.byCell[championCell]
    s.armies.catalogue = { byId = { test = { strength = "regular" } } }
    s.armies.rules = { strength = { regular = 1 } }
    pair.allied, pair.enemy.forces = { forces = { { forceId = "test" } } }, { { forceId = "test" } }
    pair.clashes = { { remaining = 1, damage = 0, difficulty = 0 } }
    s.locations = { byId = { ordinary = { battlefield_talent = { { type = "steel", qty = 1 } } } } }
    local ended, clash = Turn.finish(s, "a")
    assert(ended and clash.clash and s.activeAgentId == "a" and not s.pendingHuntEscape)
    assert(not Hunt.resolvePending(s, first))

    -- Defeat during another action also completes the turn and queues one escape.
    s = fixture(); champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    s.agentStatus.byAgent.a.health = 1
    assert(Resolution.execute(s, "a", "gain_resource", {}))
    assert(s.agentStatus.byAgent.a.defeated and s.pendingHuntEscape and s.attackFeedback)
    assert(not Hunt.resolvePending(s, first))
    clear(s); assert(Hunt.resolvePending(s, first) and s.missionHunt.escapes == 1)

    -- A single remaining destination needs no guards and may be the previous location.
    s = fixture(); champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    for _, cell in ipairs(s.missionHunt.cells) do if cell ~= championCell then s.missionHunt.secured[cell] = true end end
    Hunt.queueEscape(s); assert(Hunt.resolvePending(s, first))
    assert(#s.missionHunt.bodyguardIds == 0 and select(2, Hunt.find(s, champion.instanceId)) == championCell)

    -- Already located targets never consume another bodyguard clue; no-target kills are valid.
    s = fixture()
    local targets = { s.missionHunt.championInstanceId }
    for _, id in ipairs(s.missionHunt.companyIds) do targets[#targets + 1] = id end
    for _, id in ipairs(targets) do s.missionHunt.located[id] = select(2, Hunt.find(s, id)) end
    local _, noIntelCell = eliminate(s, s.missionHunt.bodyguardIds[1])
    assert(s.missionHunt.notice == "NO NEW INTELLIGENCE" and s.missionHunt.secured[noIntelCell])

    -- Either securing role exposes a cooccupied hidden champion.
    for _, roleIds in ipairs({ "companyIds", "bodyguardIds" }) do
    s = fixture()
    local member, memberCell = Hunt.find(s, s.missionHunt[roleIds][1])
    champion, championCell = Hunt.find(s, s.missionHunt.championInstanceId)
    local from = s.locationDecks.byCell[championCell]
    for i, card in ipairs(from.drawPile) do if card.instanceId == champion.instanceId then table.remove(from.drawPile, i); break end end
    table.insert(s.locationDecks.byCell[memberCell].drawPile, champion)
    eliminate(s, member.instanceId)
    champion, championCell, zone = Hunt.find(s, champion.instanceId)
    assert(zone == "inPlay" and championCell == memberCell and s.missionHunt.secured[memberCell])
    for _, cell in ipairs(s.missionHunt.cells) do s.missionHunt.secured[cell] = true end
    Hunt.queueEscape(s); assert(not Hunt.resolvePending(s, first) and not s.pendingHuntEscape)
    assert(select(3, Hunt.find(s, champion.instanceId)) == "inPlay")

    end

    -- Each attempted secure brings out one hidden Company. Exposed Companies still block.
    do
        local game = fixture()
        local hunt = game.missionHunt
        local guard, cell = reveal(game, hunt.bodyguardIds[1])
        local deck = game.locationDecks.byCell[cell]
        local function relocate(id)
            local card, fromCell = Hunt.find(game, id)
            local pile = game.locationDecks.byCell[fromCell].drawPile
            for i, candidate in ipairs(pile) do
                if candidate == card then table.remove(pile, i); break end
            end
            table.insert(deck.drawPile, card)
        end
        local one, two, three = unpack(hunt.companyIds)
        for _, id in ipairs({ one, two, three, hunt.championInstanceId }) do relocate(id) end
        reveal(game, three)
        local function defeat(id, random)
            deck.inPlay[id].health = 0
            assert(Elimination.commit(game, cell, id, random or first))
        end
        defeat(guard.instanceId, { random = function(_, n) return n end })
        assert(deck.inPlay[two] and deck.inPlay[two].engagedAgentId == "a" and not deck.inPlay[one])
        assert(not hunt.secured[cell] and not deck.inPlay[hunt.championInstanceId] and hunt.notice)
        defeat(two)
        assert(deck.inPlay[one] and deck.inPlay[three] and not hunt.secured[cell])
        defeat(three)
        assert(#deck.inPlayOrder == 1 and deck.inPlayOrder[1] == one and not hunt.secured[cell])
        defeat(one)
        assert(hunt.secured[cell] and deck.inPlay[hunt.championInstanceId].engagedAgentId == "a")
    end

    -- Immediate victory suppresses queued retaliation and prevents any later action/refresh.
    s = fixture(); champion, championCell = reveal(s, s.missionHunt.championInstanceId)
    champion.health = 1
    local stale = assert(Resolution.prepare(s, "a", "gain_resource", {}))
    ok, result = Resolution.execute(s, "a", "talent_test", { instanceId = champion.instanceId, testId = "strike", random = first })
    assert(ok and result.defeated and s.missionOutcome.kind == "victory" and not s.activeAgentId)
    assert(not s.pendingHuntEscape and not s.attackFeedback)
    assert(not Resolution.commit(stale) and not Resolution.prepare(s, "a", "end_turn", {}))
    assert(not Turn.refreshAll(s) and not pcall(Turn.prepareActivation, s, "b"))
    assert(not require("src.sys.location_exploration").evaluate(s, "a", require("data.location_exploration_rules")).valid)

    -- Session ownership carries the hunt, pending escape and terminal result across screens.
    local transfer = require("src.sys.mission_session").take(s)
    assert(transfer.missionHunt and transfer.missionOutcome and not s.missionHunt)
    require("src.sys.mission_session").release(transfer); assert(not transfer.missionHunt and not transfer.missionOutcome)

    -- Real UI: initial/flee animation, marked-but-hidden champion, reduced motion, victory and restart.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deployment = machine.current; deployment:update(2)
    for _, id in ipairs(deployment.package.agentIds) do deployment.agentDeployment:assign(id, "center") end
    deployment.agentView:refresh(); assert(deployment:beginAction())
    local mission = machine.current; local live = mission.session
    local footer = assert(live.missionFooter)
    local targetEntries = Targets.read(live)
    assert(#targetEntries == 6 and targetEntries[1].champion and targetEntries[1].health == 2)
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString()); pixels:release(); canvas:release()
    end
    assert(not mission:inputReady()); render("hunt_initial.png")
    local _, targetLayout = footer:prepare(live)
    local targetPanel = targetLayout.panels[1]
    mission:pointermoved(targetPanel.x + 2, targetPanel.y + targetPanel.height - 2)
    assert(footer.previews.cardId == live.missionHunt.championId, "Hidden target must preview during hunt distribution")
    render("target_hover_mission.png")
    mission:focus(false); assert(not footer.hoveredId)
    mission:update(0.5); render("hunt_distribution.png")
    local serialBefore = live.missionHunt.serial
    mission:keypressed("space"); mission:update(1)
    assert(mission:inputReady() and live.missionHunt.serial == serialBefore)
    local id = live.package.agentIds[1]
    local boss, bossCell = Hunt.find(live, live.missionHunt.championInstanceId)
    live.missionHunt.located[boss.instanceId] = bossCell
    render("hunt_located.png")
    local securedPreviewCell = live.missionHunt.cells[1]
    live.missionHunt.secured[securedPreviewCell] = true
    render("hunt_label_alignment.png")
    live.missionHunt.secured[securedPreviewCell] = nil
    local bossDeck = live.locationDecks.byCell[bossCell]
    for i, card in ipairs(bossDeck.drawPile) do if card == boss then table.remove(bossDeck.drawPile, i); break end end
    bossDeck.drawPile[#bossDeck.drawPile + 1] = boss
    live.agentDeployment:assign(id, bossCell); live.agentView:refresh()
    mission.selectedId = id; assert(mission:beginAgentAction())
    local active = machine.current; active:update(2)
    live.agentStatus.byAgent[id].health, live.agentStatus.byAgent[id].defiance = 100, 100
    live.fatePool = { entries = { { tileId = "win" } }, definitions = { win = { value = 0, special = "auto_success" } } }
    -- Guarantee discovery without requiring a favorable ordinary-deck order.
    assert(active:explore()); active:update(20)
    boss = Hunt.find(live, live.missionHunt.championInstanceId)
    assert(boss.health == 2 and boss.engagedAgentId == id)
    assert(active:performAction("talent_test", { instanceId = boss.instanceId, testId = "strike",
        random = { random = function() return 1 end } }))
    active:update(20)
    assert(boss.health == 1)
    assert(Targets.read(live)[1].health == 1 and live.missionFooter == footer)
    active:pointermoved(targetPanel.x + 2, targetPanel.y + 2)
    assert(footer.previews.views.location.runtimeHealth == 1)
    render("target_hover_agent.png")
    active:focus(false); assert(not footer.hoveredId)
    for cell in pairs(live.armies.byCell) do require("src.sys.battlefield_state").damage(live.armies, cell, "enemy", 999) end
    assert(active:endTurn() and live.pendingHuntEscape and machine.current == active)
    active:update(20)
    assert(machine.currentName == "mission_action" and live.missionHunt.escapes == 1)
    mission = machine.current
    boss, bossCell, zone = Hunt.find(live, boss.instanceId)
    assert(zone == "drawPile" and boss.health == 1 and live.missionHunt.located[boss.instanceId] == bossCell)
    targetEntries = Targets.read(live)
    assert(targetEntries[1].instanceId == boss.instanceId and targetEntries[1].health == 1
        and not targetEntries[1].eliminated and live.missionFooter == footer)
    assert(not boss.engagedAgentId and live.huntPresentation and not mission:inputReady())
    render("hunt_flee.png")
    mission:update(0.5); render("hunt_flee_distribution.png")
    local settings = require("data.hunt_distribution_view")
    settings.reducedMotion = true
    render("hunt_distribution_reduced.png")
    settings.reducedMotion = false
    mission:keypressed("space"); mission:update(1); render("hunt_zero_strength.png")
    assert(select(3, Hunt.find(live, boss.instanceId)) == "drawPile", "Zero strength must reveal only a marker")
    local nextAgent = live.package.agentIds[2]
    bossDeck = live.locationDecks.byCell[bossCell]
    for i, card in ipairs(bossDeck.drawPile) do if card.instanceId == boss.instanceId then table.remove(bossDeck.drawPile, i); break end end
    bossDeck.drawPile[#bossDeck.drawPile + 1] = boss
    live.agentDeployment:assign(nextAgent, bossCell); live.agentView:refresh()
    mission.selectedId = nextAgent; assert(mission:beginAgentAction())
    active = machine.current; active:update(2)
    assert(active:explore()); active:update(20)
    assert(active:performAction("talent_test", { instanceId = boss.instanceId, testId = "strike", random = first }))
    assert(live.missionOutcome and active.testFeedback:busy())
    local outcomeView = require("src.ui.mission_outcome")
    local originalDraw, outcomeDraws = outcomeView.draw, 0
    outcomeView.draw = function(...)
        outcomeDraws = outcomeDraws + 1
        return originalDraw(...)
    end
    active:keypressed("return")
    assert(machine.current == active, "Restart must wait for the winning combat animation")
    active:update(active.testFeedback.settings.hitTime + 0.01)
    assert(active.testFeedback:busy() and active.testFeedback.sounded, "Winning impact must animate and play audio")
    render("hunt_winning_hit.png")
    assert(outcomeDraws == 0, "Victory must not cover the winning hit")
    assert(not active:performAction("gain_resource"), "Victory must still block further gameplay")
    active:update(active.testFeedback.settings.stepDuration + 0.01)
    assert(not active:combatFeedbackBusy() and not live.talentFeedback)
    render("hunt_victory.png")
    assert(outcomeDraws == 1, "Victory appears after combat completes")
    outcomeView.draw = originalDraw
    targetEntries = Targets.read(live)
    assert(targetEntries[1].health == 0 and targetEntries[1].eliminated)
    active:pointermoved(targetPanel.x + 2, targetPanel.y + 2)
    assert(footer.previews.views.location.runtimeHealth == 0)
    render("target_hover_victory.png")
    assert(not targetEntries[2].eliminated, "Champion victory must not mark living company eliminated")
    active:keypressed("return"); assert(machine.currentName == "mission_preparation" and not live.missionHunt)
    assert(not live.missionFooter and not footer.track.font and next(footer.track.images) == nil)
    machine.current:exit()
end
