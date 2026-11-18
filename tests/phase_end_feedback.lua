return function(write)
    local Activity = require("src.sys.silencer_activity")
    local Phase = require("src.sys.mission_phase")
    local Feedback = require("src.ui.phase_end_feedback")
    local Clock = require("src.sys.doom_clock")
    local Status = require("src.sys.agent_status")
    local catalogue = require("src.sys.silencer_catalogue").load(require("data.biomes.the_cut"))
    local last = { random = function(_, n) return n end }
    local function fixture(size, squads, security, glory)
        local pool = { ids = { "security_door" }, byId = { security_door = { name = "Door", card_type = "BARRIER" } }, byType = { BARRIER = { "security_door" } } }
        local decks = require("src.sys.location_decks").new({ center = "jacl" }, { byId = { jacl = {
            name = "JACL", deck_size = size, deck_build = { { type = "BARRIER", qty = size } } } } }, pool)
        local s = { locationDecks = decks, locationCardPool = pool, jaclSecurity = security,
            doomClock = Clock.new(require("data.doom_clock_rules")), package = { biomeId = "the_cut" },
            fatePool = { entries = { { tileId = "autofail" } }, definitions = { autofail = require("data.fate_tiles.autofail") } },
            agentStatus = Status.new({ "a" }, { byId = { a = { health = 10, defiance = 10 } } }, require("data.agent_status_defaults")) }
        s.silencers = Activity.new(catalogue, pool)
        for i = 1, #s.doomClock.slots do s.doomClock.slots[i] = i <= glory and "locked" or "cleared" end
        for i = 1, squads do
            local card = { instanceId = "squad_" .. i, cardId = "fools_meat", health = 1, deployedPhase = 0 }
            decks.byCell.center.inPlay[card.instanceId] = card
            decks.byCell.center.inPlayOrder[i] = card.instanceId
        end
        require("src.sys.mission_deck_effects").bind(s)
        return s
    end
    local s = fixture(20, 3, 2, 1)
    local receipt = Activity.resolve(s, last)
    assert(receipt.events[1].kind == "sabotage" and receipt.events[1].count == 3)
    local hit = receipt.events[2]
    assert(hit.instanceId == "squad_3" and hit.beforeHealth == 1 and hit.health == 0 and hit.destroyed)
    assert(hit.beforeSecurity == 2 and hit.security == 1 and not s.locationDecks.byCell.center.inPlay[hit.instanceId])
    assert(receipt.events[3].instanceId == "squad_2" and receipt.milling.actual == 1)
    assert(receipt.milling.cards[1].destination == "inPlay" and receipt.milling.cards[1].source == "silencer")
    assert(Activity.resolve(s, last) == receipt and s.jaclSecurity == 0)

    -- Multiple hits on a surviving instance keep distinct before/after snapshots.
    local repeated = fixture(20, 3, 2, 0)
    repeated.locationDecks.byCell.center.inPlay.squad_3.health = 3
    local r = Activity.resolve(repeated, last)
    assert(r.events[2].instanceId == r.events[3].instanceId)
    assert(r.events[2].beforeHealth == 3 and r.events[2].health == 2)
    assert(r.events[3].beforeHealth == 2 and r.events[3].health == 1 and not r.events[3].destroyed)

    -- Actual phase ordering, both milling sources in review, and no early refresh.
    s = fixture(30, 3, 1, 2)
    Status.exhaust(s.agentStatus, "a"); assert(Phase.begin(s))
    assert(s.phaseFeedback and s.agentStatus.byAgent.a.exhausted and s.doomClock.phase == 1)
    assert(not Phase.begin(s))
    Phase.update(s, 30)
    assert(not s.phaseFeedback and not s.phaseTransition and s.doomClock.phase == 2)
    local review = s.locationDecks.byCell.center.lastMilling
    assert(review.actual == 4 and review.before == 30 and review.after == 26)
    assert(review.cards[1].source == "silencer" and review.cards[3].source == "glory")
    Phase.update(s, 30); assert(#s.locationDecks.byCell.center.drawPile == 26)

    -- Fully blocked attacks and zero Glory produce no mill view or deck loss.
    local blocked = fixture(20, 2, 2, 0)
    Status.exhaust(blocked.agentStatus, "a"); assert(Phase.begin(blocked))
    for _, event in ipairs(blocked.phaseFeedback.events) do assert(event.kind ~= "mill") end
    Phase.update(blocked, 30)
    assert(#blocked.locationDecks.byCell.center.drawPile == 20 and not blocked.locationDecks.byCell.center.lastMilling)
    -- Many small frames and reduced motion reach the same rules result as a long frame.
    local reduced = fixture(20, 2, 2, 0)
    local config = require("data.phase_end_view"); config.reducedMotion = true
    Status.exhaust(reduced.agentStatus, "a"); assert(Phase.begin(reduced))
    for _ = 1, 600 do Phase.update(reduced, 0.01) end
    config.reducedMotion = false
    assert(not reduced.phaseFeedback and not reduced.phaseTransition and reduced.doomClock.phase == 2)
    assert(#reduced.locationDecks.byCell.center.drawPile == 20 and reduced.jaclSecurity == 0)

    -- Exhaustion records the fatal cards, blocks restart, and never refreshes.
    for _, attackers in ipairs({ 0, 2 }) do
        s = fixture(1, attackers, 0, 2)
        Status.exhaust(s.agentStatus, "a"); assert(Phase.begin(s))
        if not s.missionOutcome then Phase.update(s, 0.8) end
        assert(s.missionOutcome and s.phaseFeedback and not s.phaseTransition)
        assert(s.locationDecks.byCell.center.lastMilling.actual == 1)
        local restarted = false
        local state = { session = s, stateMachine = { change = function() restarted = true end } }
        require("src.ui.hunt_distribution").keypressed(state, "return")
        assert(not restarted and not Phase.begin(s))
        Phase.update(s, 30)
        assert(not s.phaseFeedback and s.doomClock.phase == 1 and s.agentStatus.byAgent.a.exhausted)
        assert(#s.silencers.transports == (attackers == 0 and 3 or 0))
    end

    -- Render real assets and both result types, including reduced motion.
    s = fixture(20, 3, 2, 0)
    receipt = Activity.resolve(s, last)
    s.scene = { jaclPreview = { transportAnchor = function() return 640, 640, 1280, 720 end } }
    local view = Feedback.new(s); s.scene.phaseFeedbackView = view
    local canvas = love.graphics.newCanvas(1280, 720)
    local font = love.graphics.newFont("assets/fonts/Undead Pixel 8.ttf", 8)
    local function render(name, event, age)
        Feedback.start(s, { event }); Feedback.update(s, age)
        love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(0.08, 0.1, 0.14)
        view:draw(1280, 720, font)
        love.graphics.setCanvas(); love.graphics.pop()
        local pixels = canvas:newImageData(); write(name .. ".png", pixels:encode("png"):getString()); pixels:release()
    end
    render("phase_security_destroyed", receipt.events[2], 0.4)
    render("phase_security_damage", r.events[2], 0.4)
    render("phase_silencer_mill", receipt.events[#receipt.events], 0.4)
    local gloryRecord = require("src.sys.milling_receipt").new(s.locationDecks, "center", s.locationDecks:prepareMill("center", 3), "glory")
    render("phase_glory_mill", { kind = "mill", record = gloryRecord }, 0.4)
    local c = require("data.phase_end_view"); c.reducedMotion = true
    render("phase_security_reduced", receipt.events[2], 0.4)
    c.reducedMotion = false
    view:release(); canvas:release(); font:release()
    write("phase_feedback_results.txt", "PASS: ordered phase playback, damage snapshots, source receipts, exhaustion and real-asset rendering\n")
end
