return function(write)
    local Clock = require("src.sys.doom_clock")
    local Phase = require("src.sys.mission_phase")
    local Effects = require("src.sys.mission_deck_effects")
    local Outcome = require("src.sys.mission_outcome")
    local Decks = require("src.sys.location_decks")
    local Status = require("src.sys.agent_status")
    local View = require("src.ui.doom_clock")
    local rules = require("data.doom_clock_rules")
    local function fixture(size, firstWarning)
        local pool = { byId = { x = { name = "Door", card_type = "BARRIER" } }, byType = { BARRIER = { "x" } } }
        local locations = { byId = { loc = { deck_size = size, deck_build = { { type = "BARRIER", qty = size } } } } }
        local decks = Decks.new({ center = "loc", west = "loc" }, locations, pool, love.math.newRandomGenerator(9))
        local agents = { byId = { a = { health = 10, defiance = 10 } } }
        local s = { doomClock = Clock.new(rules), locationDecks = decks,
            agentStatus = Status.new({ "a" }, agents, require("data.agent_status_defaults")) }
        -- Most scenarios below test established doom; warning scenarios opt in.
        s.doomClock.warningUsed = not firstWarning
        Effects.bind(s)
        return s
    end
    local function test(s, success, special, extra)
        local result = extra or {}; result.success, result.special = success, special
        local plan = Clock.prepare(s.doomClock, "test", result)
        assert(Clock.commit(s, plan)); return plan
    end
    local function exhaust(s) Status.exhaust(s.agentStatus, "a") end
    -- HIS GLORY pulses only for an all-Glory track, never Conviction occupants.
    local glorySession = fixture(20)
    for _ = 1, 5 do test(glorySession, true, "auto_success") end
    View.update(glorySession, 1); assert(glorySession.doomGloryTime == 0)
    assert(Clock.commit(glorySession, Clock.prepare(glorySession.doomClock, "begin_phase")))
    for _ = 1, 4 do test(glorySession, false, "auto_failure") end
    test(glorySession, true) -- Clear the final waiting Glory, leaving Conviction.
    View.update(glorySession, 1); assert(glorySession.doomGloryTime == 0)
    test(glorySession, false, "auto_failure") -- Queue above Conviction.
    View.update(glorySession, 1); assert(glorySession.doomGloryTime == 0)
    test(glorySession, false, "auto_failure") -- Replace the final Conviction.
    View.update(glorySession, 1); assert(glorySession.doomGloryTime > 0)
    -- One warning per mission, only from revealed autofails. Preparation and
    -- stale/repeated commits must not spend it or create a second flash.
    local warningSession = fixture(20, true)
    local warningPlan = Clock.prepare(warningSession.doomClock, "test", { special = "auto_failure", success = false })
    assert(not warningSession.doomClock.warningUsed and not warningSession.doomWarning)
    test(warningSession, true)
    assert(not Clock.commit(warningSession, warningPlan) and not warningSession.doomClock.warningUsed)
    warningPlan = test(warningSession, false, "auto_failure")
    assert(warningSession.doomClock.warningUsed and warningSession.doomWarning and Clock.locked(warningSession.doomClock) == 0)
    assert(warningSession.doomClock.slots[1] == "pending" and not Clock.commit(warningSession, warningPlan))
    local flash = warningSession.doomWarning
    test(warningSession, false, "auto_failure")
    assert(Clock.locked(warningSession.doomClock) == 1 and warningSession.doomWarning == flash)
    View.update(warningSession, 1); assert(not warningSession.doomWarning)
    -- Automatic advancement locks every lingering icon without consuming warning.
    warningSession = fixture(20, true); exhaust(warningSession)
    assert(Phase.begin(warningSession)); Phase.update(warningSession, 1)
    assert(Clock.locked(warningSession.doomClock) == 5 and not warningSession.doomClock.warningUsed)
    assert(#warningSession.locationDecks.byCell.center.drawPile == 15)
    test(warningSession, false, "auto_failure")
    assert(warningSession.doomClock.warningUsed and warningSession.doomWarning)
    assert(Clock.locked(warningSession.doomClock) == 5)
    -- No pending icons, and an all-success track, also trigger the warning.
    for _, cleared in ipairs({ true, false }) do
        warningSession = fixture(20, true)
        for _ = 1, 5 do test(warningSession, true, not cleared and "auto_success" or nil) end
        local before = table.concat(warningSession.doomClock.slots, ",")
        test(warningSession, false, "auto_failure")
        assert(warningSession.doomClock.warningUsed and warningSession.doomWarning)
        assert(table.concat(warningSession.doomClock.slots, ",") == before)
    end
    assert(not fixture(20, true).doomClock.warningUsed)
    -- Both biome alternates swap only the base layer and release cleanly.
    local Parallax = require("src.ui.parallax_view")
    for _, biome in ipairs({ "the_cut", "roswell_shallows" }) do
        local visuals = require("src.sys.biome_visual_catalogue").refresh(biome)
        assert(visuals.doomBackground.path:find("bg_doom.png", 1, true))
        local parallax = Parallax.new(visuals, nil, { x = 0, y = 360, width = 1280, height = 360 })
        parallax:update(0.5)
        local layers, offsets = {}, {}
        for i, layer in ipairs(parallax.layers) do layers[i], offsets[i] = layer, layer.offset end
        assert(parallax:activateDoom() and parallax.doomActive and parallax:activateDoom())
        assert(parallax.layers[1] ~= layers[1] and parallax.layers[1].key == "bg")
        for i = 2, #layers do assert(parallax.layers[i] == layers[i] and parallax.layers[i].offset == offsets[i]) end
        parallax:release(); assert(#parallax.layers == 0 and not parallax.doomBackground)
    end
    local s = fixture(20)
    assert(#s.doomClock.slots == 5 and Clock.locked(s.doomClock) == 0 and s.doomClock.phase == 1)
    local plan = Clock.prepare(s.doomClock, "test", { success = true })
    assert(s.doomClock.slots[5] == "pending")
    assert(Clock.commit(s, plan) and not Clock.commit(s, plan))
    assert(s.doomClock.slots[5] == "cleared")
    local stale = Clock.prepare(s.doomClock, "test", { success = true })
    test(s, false) -- Ordinary failures neither clear nor lock slots.
    assert(not Clock.commit(s, stale) and Clock.locked(s.doomClock) == 0 and s.doomClock.slots[4] == "pending")
    test(s, true)
    test(s, true, nil, { battlefield = true })
    test(s, false, "auto_failure", { clash = true })
    assert(s.doomClock.slots[1] == "locked" and s.doomClock.slots[2] == "pending")
    exhaust(s)
    local beforeResources = s.agentStatus.byAgent.a.resources
    assert(Phase.begin(s) and not Phase.begin(s))
    assert(Clock.locked(s.doomClock) == 2 and s.phaseTransition and #s.locationDecks.byCell.center.drawPile == 20)
    assert(s.agentStatus.byAgent.a.exhausted and not require("src.sys.agent_turn").refreshAll(s))
    Phase.update(s, 0.1)
    assert(#s.locationDecks.byCell.center.drawPile == 20 and s.doomClock.phase == 1)
    Phase.update(s, 3)
    assert(not s.phaseTransition and #s.locationDecks.byCell.center.drawPile == 18)
    assert(#s.locationDecks.byCell.center.discardPile == 2 and s.doomClock.phase == 2)
    assert(s.doomClock.slots[1] == "locked" and s.doomClock.slots[2] == "locked")
    for i = 3, 5 do assert(s.doomClock.slots[i] == "pending") end
    assert(not s.agentStatus.byAgent.a.exhausted and s.agentStatus.byAgent.a.resources == beforeResources + 1)
    Phase.update(s, 10); assert(#s.locationDecks.byCell.center.drawPile == 18)
    assert(not Phase.begin(s))
    -- Clearing available images prevents automatic phase-end advancement.
    for _ = 1, 3 do test(s, true) end
    assert(Clock.locked(s.doomClock) == 2)
    exhaust(s); assert(Phase.begin(s))
    assert(s.phaseFeedback and s.agentStatus.byAgent.a.exhausted)
    Phase.update(s, 3)
    assert(not s.phaseTransition and #s.locationDecks.byCell.center.drawPile == 16)
    -- No tests fills the track; a full track keeps milling without overflow.
    exhaust(s); assert(Phase.begin(s)); Phase.update(s, 3)
    assert(Clock.locked(s.doomClock) == 5 and #s.locationDecks.byCell.center.drawPile == 11)
    test(s, true); test(s, false, "auto_failure"); assert(Clock.locked(s.doomClock) == 5)
    exhaust(s); assert(Phase.begin(s)); assert(#s.locationDecks.byCell.center.drawPile == 6)
    -- With no waiting icons, an autofail supplies one above the leftmost
    -- non-autofail slot, leaving it queued and clearable.
    s = fixture(20)
    for _ = 1, 5 do test(s, true) end
    local supplied = Clock.prepare(s.doomClock, "test", { success = false, special = "auto_failure" })
    assert(Clock.locked(s.doomClock) == 0)
    assert(Clock.commit(s, supplied) and not Clock.commit(s, supplied))
    assert(s.doomClock.slots[1] == "pending" and supplied.events[1].kind == "populate" and supplied.events[1].slots[1] == 1)
    assert(Clock.locked(s.doomClock) == 0 and Clock.strength(s.doomClock) == 0)
    for i = 2, 5 do assert(s.doomClock.slots[i] == "cleared") end
    test(s, true); assert(s.doomClock.slots[1] == "cleared")
    test(s, false, "auto_failure"); assert(s.doomClock.slots[1] == "pending")
    test(s, false, "auto_failure"); assert(s.doomClock.slots[1] == "locked")
    test(s, false, "auto_failure"); assert(s.doomClock.slots[2] == "pending")
    assert(Clock.commit(s, Clock.prepare(s.doomClock, "end_phase")))
    assert(s.doomClock.slots[2] == "locked")
    -- When an icon IS waiting, use it rather than supplying one over a cleared slot.
    s = fixture(20)
    for _ = 1, 4 do test(s, true) end
    test(s, false, "auto_failure") -- Locks slot 1 using its waiting icon.
    assert(Clock.commit(s, Clock.prepare(s.doomClock, "begin_phase")))
    test(s, true) -- Clears 5, leaving pending 2-4.
    test(s, false, "auto_failure"); assert(s.doomClock.slots[2] == "locked" and s.doomClock.slots[5] == "cleared")
    -- Queue above autosuccesses without overwriting them until the next draw.
    s = fixture(20)
    for _ = 1, 5 do test(s, true, "auto_success") end
    test(s, false, "auto_failure")
    assert(s.doomClock.slots[1] == "pending" and s.doomClock.successes[1] and Clock.locked(s.doomClock) == 0)
    test(s, false, "auto_failure")
    assert(s.doomClock.slots[1] == "locked" and not s.doomClock.successes[1] and s.doomClock.successes[2])
    for _ = 1, 4 do
        test(s, false, "auto_failure")
        test(s, false, "auto_failure")
    end
    assert(Clock.locked(s.doomClock) == 5)
    local noRoom = test(s, false, "auto_failure")
    assert(#noRoom.events == 0 and Clock.locked(s.doomClock) == 5)
    -- The warning still precedes the new fallback on a cleared track.
    s = fixture(20, true)
    for _ = 1, 5 do test(s, true) end
    test(s, false, "auto_failure"); assert(Clock.locked(s.doomClock) == 0 and s.doomClock.warningUsed)
    test(s, false, "auto_failure"); assert(s.doomClock.slots[1] == "pending" and Clock.locked(s.doomClock) == 0)
    -- Autosuccess conversion replaces ordinary success clearing, consumes the
    -- rightmost waiting icon, and targets the rightmost truly empty slot.
    s = fixture(20)
    test(s, true) -- Slot 5 is empty, with no waiting image.
    local conversion = Clock.prepare(s.doomClock, "test", { success = true, special = "auto_success" })
    assert(not s.doomClock.successes[5] and s.doomClock.slots[4] == "pending")
    assert(Clock.commit(s, conversion) and not Clock.commit(s, conversion))
    assert(s.doomClock.successes[5] and s.doomClock.slots[4] == "cleared")
    assert(s.doomClock.slots[3] == "pending" and Clock.strength(s.doomClock) == 0)
    test(s, true, "auto_success")
    assert(s.doomClock.successes[4] and s.doomClock.successes[5] and not s.doomClock.successes[3])
    assert(s.doomClock.slots[3] == "cleared")
    test(s, false, "auto_failure") -- Lock 1, leaving only pending 2.
    test(s, true) -- Clear 2, protecting the success tiles through this phase.
    exhaust(s); assert(Phase.begin(s))
    assert(not s.phaseTransition and #s.locationDecks.byCell.center.drawPile == 20)
    assert(s.lastDoomMill.actual == 0 and Clock.strength(s.doomClock) == 0)
    assert(s.doomClock.successes[4] and s.doomClock.successes[5])
    assert(s.doomClock.slots[4] == "pending" and s.doomClock.slots[5] == "pending")
    -- The rightmost waiting icon may be ABOVE an existing success. Moving it
    -- to empty slot 3 preserves that success and the waiting autofail at 3.
    test(s, true, "auto_success")
    assert(s.doomClock.successes[3] and s.doomClock.successes[4] and s.doomClock.successes[5])
    assert(s.doomClock.slots[5] == "cleared" and s.doomClock.slots[3] == "pending")
    test(s, false, "auto_failure") -- Locks 2.
    test(s, false, "auto_failure") -- Overwrites success at 3.
    assert(s.doomClock.slots[3] == "locked" and not s.doomClock.successes[3])
    assert(s.doomClock.successes[4] and Clock.strength(s.doomClock) == 1)
    -- Phase-end autofails overwrite the remaining pending-covered success too.
    exhaust(s); assert(Phase.begin(s)); Phase.update(s, 3)
    assert(s.doomClock.slots[4] == "locked" and not s.doomClock.successes[4])
    assert(s.doomClock.successes[5] and s.doomClock.slots[5] == "pending")
    assert(Clock.strength(s.doomClock) == 3 and #s.locationDecks.byCell.center.drawPile == 17)
    -- A track occupied by locked failures AND successes has no success room.
    local snapshot = table.concat(s.doomClock.slots, ",")
    test(s, true, "auto_success")
    assert(table.concat(s.doomClock.slots, ",") == snapshot and s.doomClock.successes[5])
    test(s, false, "auto_failure")
    assert(not s.doomClock.successes[5] and Clock.locked(s.doomClock) == 5)
    test(s, true, "auto_success"); assert(Clock.strength(s.doomClock) == 5)
    -- Empty slots without waiting images cannot create autosuccess tokens.
    s = fixture(20)
    for _ = 1, 5 do test(s, true) end
    test(s, true, "auto_success")
    assert(next(s.doomClock.successes) == nil and Clock.strength(s.doomClock) == 0)
    -- An all-success track blocks further conversions despite new waiting icons.
    s = fixture(20)
    for _ = 1, 5 do test(s, true, "auto_success") end
    assert(Clock.locked(s.doomClock) == 0 and Clock.strength(s.doomClock) == 0)
    exhaust(s); assert(Phase.begin(s)); assert(#s.locationDecks.byCell.center.drawPile == 20)
    snapshot = table.concat(s.doomClock.slots, ",")
    test(s, true, "auto_success"); assert(table.concat(s.doomClock.slots, ",") == snapshot)
    test(s, false, "auto_failure"); assert(not s.doomClock.successes[1] and s.doomClock.slots[1] == "locked")
    -- Overmilling fails before refresh/replenishment and never reshuffles.
    s = fixture(3); exhaust(s)
    beforeResources = s.agentStatus.byAgent.a.resources
    assert(Phase.begin(s)); Phase.update(s, 3)
    assert(Outcome.finished(s) and s.missionOutcome.kind == "failure" and s.missionOutcome.reason == "jacl_deck_exhausted")
    assert(#s.locationDecks.byCell.center.drawPile == 0 and #s.locationDecks.byCell.center.discardPile == 3)
    assert(s.agentStatus.byAgent.a.exhausted and s.agentStatus.byAgent.a.resources == beforeResources)
    assert(not s.phaseTransition and s.doomClock.phase == 1 and not Phase.begin(s))
    assert(not Outcome.victory(s, {}) and not Outcome.failure(s, "again"))
    -- All deck commits notify exhaustion, including non-doom effects and draws.
    s = fixture(1)
    s.locationDecks:draw("west"); assert(not Outcome.finished(s))
    local draw = s.locationDecks:prepareDraw("center")
    assert(not Outcome.finished(s)); assert(s.locationDecks:commitDraw("center", draw))
    assert(Outcome.finished(s) and not s.locationDecks:commitDraw("center", draw))
    s = fixture(2)
    local mill = s.locationDecks:prepareMill("center", 2)
    assert(s.locationDecks:commitMill("center", mill) and Outcome.finished(s))
    assert(not s.locationDecks:commitMill("center", mill))
    assert(Outcome.finished(fixture(0)))
    -- Exploring the last JACL card commits the card/cost, then ends the mission.
    s = fixture(1)
    s.activeAgentId = "a"
    s.agentDeployment = { placements = { a = "center" } }
    local Explore = require("src.sys.location_exploration")
    local explored, card = Explore.commit(s, "a", require("data.location_exploration_rules"))
    assert(explored and card and s.locationDecks.byCell.center.inPlay[card.instanceId])
    assert(s.missionOutcome.kind == "failure" and not s.activeAgentId and not s.attackFeedback)
    assert(s.agentStatus.byAgent.a.actionPoints == 2)
    assert(not Explore.commit(s, "a", require("data.location_exploration_rules")))
    -- Invalid refresh preparation cannot lock tiles or mill a partial phase.
    s = fixture(20); exhaust(s); s.agentStatus.byAgent.a.actionPointCapacity = -1
    assert(not pcall(Phase.begin, s) and Clock.locked(s.doomClock) == 0 and not s.phaseTransition)
    assert(#s.locationDecks.byCell.center.drawPile == 20)
    -- Shared fate reveal covers ordinary, Battlefield and Clash outcomes once.
    local Reveal = require("src.sys.fate_reveal")
    s = fixture(20)
    local definitions = require("data.fate_tiles.index").refresh().byId
    s.fatePool = { definitions = definitions, entries = { { tileId = "autofail" } } }
    local result = { battlefield = true, clash = true, cell = "west" }
    local effect = Reveal.prepare(s, result, 99, 0, 1, { random = function() return 1 end })
    assert(Clock.locked(s.doomClock) == 0 and not result.success)
    Reveal.commit(effect); assert(Clock.locked(s.doomClock) == 1)
    s.fatePool.entries = { { tileId = "autosuccess" } }
    result = { battlefield = true, cell = "west" }
    effect = Reveal.prepare(s, result, 0, 0, 99, { random = function() return 1 end })
    assert(result.success and result.special == "auto_success" and not s.doomClock.successes[5])
    Reveal.commit(effect)
    assert(s.doomClock.successes[5] and Clock.strength(s.doomClock) == 0)
    -- Real mission UI, lifecycle persistence, native artwork and terminal input.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deploy = machine.current; deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, "center") end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local mission = machine.current
    local session, id = mission.session, mission.session.package.agentIds[1]
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString()); pixels:release(); canvas:release()
    end
    render("doom_opening_start.png")
    mission:update(0.18); render("doom_opening_mid.png")
    mission:update(0.10); render("doom_opening_last_slot.png")
    mission:update(2)
    render("doom_initial.png")
    local completedEntrance = session.doomEntranceTime
    local image = session.art.images.__doom_autofail
    assert(image and image:getWidth() == 30 and image:getHeight() == 30)
    test(session, true) -- Convert from column 4 into the cleared column 5.
    test(session, true, "auto_success"); View.update(session, 0.15)
    render("doom_autosuccess_drop.png")
    View.update(session, 1); render("doom_autosuccess.png")
    assert(session.art.images.__doom_autosuccess and Clock.strength(session.doomClock) == 0)
    local parallax = session.scene.parallax
    local oldBackground = parallax.layers[1]
    local priorSlots = table.concat(session.doomClock.slots, ",")
    local warningResult = { battlefield = true, clash = true, cell = "center" }
    local savedPool = session.fatePool
    session.fatePool = { definitions = definitions, entries = { { tileId = "autofail" } } }
    local warningReveal = Reveal.prepare(session, warningResult, 10, 0, 1, { random = function() return 1 end })
    assert(not session.doomClock.warningUsed and parallax.layers[1] == oldBackground)
    Reveal.commit(warningReveal)
    assert(session.doomClock.warningUsed and parallax.doomActive and parallax.layers[1] ~= oldBackground)
    assert(table.concat(session.doomClock.slots, ",") == priorSlots and not warningResult.success)
    render("doom_warning_flash.png")
    View.update(session, 0.20); render("doom_warning_fade.png")
    View.update(session, 1); render("doom_warning_background.png")
    assert(not session.doomWarning)
    for _ = 1, 3 do test(session, true) end -- No waiting images remain.
    local suppliedReveal = Reveal.prepare(session, {}, 10, 0, 1, { random = function() return 1 end })
    Reveal.commit(suppliedReveal)
    assert(session.doomClock.slots[1] == "pending")
    View.update(session, 0.12); render("doom_supplied_autofail.png")
    session.fatePool = savedPool
    -- Restart the clock for the existing lifecycle/phase integration scenario.
    session.doomClock, session.doomPresentation = Clock.new(rules), {}
    session.doomClock.warningUsed = true -- The real warning has already fired above.
    test(session, true); test(session, false, "auto_failure"); View.update(session, 0.15)
    render("doom_drop.png")
    mission.selectedId = id; assert(mission:beginAgentAction())
    local active = machine.current; active:update(2)
    assert(active.session.doomClock == session.doomClock and session.art.images.__doom_autofail == image)
    assert(session.doomClock.warningUsed and session.scene.parallax.doomActive)
    assert(session.doomEntranceTime == completedEntrance, "Returning screens must not replay the opening")
    render("doom_agent_action.png")
    assert(active:endTurn()); if machine.current == active then active:update(20) end
    mission = machine.current; mission:update(2)
    for _, state in pairs(session.agentStatus.byAgent) do state.exhausted, state.actionPoints = true, 0 end
    local count = #session.locationDecks.byCell.center.drawPile
    assert(mission:nextPhaseRefresh() and session.phaseTransition and not mission:inputReady())
    mission:keypressed("space"); assert(session.phaseTransition)
    render("doom_phase_end.png")
    mission:update(5) -- Includes transport and milling feedback.
    assert(#session.locationDecks.byCell.center.drawPile == count - 4 and session.doomClock.phase == 2)
    assert(mission:inputReady()); render("doom_next_phase.png")
    -- Reduced motion keeps readable result holds, without movement or flashes.
    local view = require("data.doom_clock_view"); view.reducedMotion = true
    for _, state in pairs(session.agentStatus.byAgent) do state.exhausted, state.actionPoints = true, 0 end
    assert(mission:nextPhaseRefresh() and session.phaseFeedback)
    mission:update(5)
    assert(not session.phaseTransition)
    view.reducedMotion = false
    View.update(session, view.dropDuration)
    render("doom_his_glory.png")
    local deck = session.locationDecks.byCell.center
    local finalMill = session.locationDecks:prepareMill("center", #deck.drawPile)
    assert(session.locationDecks:commitMill("center", finalMill))
    assert(session.missionOutcome.kind == "failure" and not mission:beginAgentAction() and not mission:nextPhaseRefresh())
    render("doom_failure.png")
    mission:keypressed("return"); assert(machine.currentName == "mission_preparation" and not mission.session)
    machine.current:exit()
end
