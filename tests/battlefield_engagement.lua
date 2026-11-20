return function(state, render)
    local Snapshot = require("src.sys.battlefield_engagement_record")
    local Battlefield = require("src.sys.battlefield_state")
    local session, feedback = state.session, state.testFeedback
    local kinds = { enemy = {}, allied = {} }
    for _, id in ipairs(session.armies.catalogue.ids) do
        local def = session.armies.catalogue.byId[id]
        kinds[def.faction][def.strength] = id
    end
    local function result(side, damage, protection, count, otherDamage, rank)
        local armies = { byCell = { field = { protection = protection } },
            catalogue = session.armies.catalogue, rules = session.armies.rules }
        local pair = armies.byCell.field
        for _, faction in ipairs({ "enemy", "allied" }) do
            pair[faction] = { forces = {} }
            for i = 1, count do
                pair[faction].forces[i] = { id = faction .. i,
                    forceId = kinds[faction][rank or (i % 3 == 1 and "elite" or "regular")] }
            end
        end
        Battlefield.touch(armies, "field")
        local r = { battlefield = true, battlefieldKind = "engage", agentId = state.activeAgentId,
            name = "STACK PRESENTATION", test = { label = "STEEL", kind = "battlefield" },
            difficulty = 3, base = 3, committed = 0, modifier = side == "enemy" and 0 or -1,
            total = side == "enemy" and 3 or 2,
            success = side == "enemy" }
        local before = Snapshot.capture(armies, "field")
        local exchanges = {}
        for _, receiver in ipairs({ "enemy", "allied" }) do
            local amount = receiver == side and damage or (otherDamage or 0)
            local removed, absorbed, replacements, bonusAbsorbed = Battlefield.damage(armies, "field", receiver, amount)
            exchanges[receiver] = { damage = amount, removed = removed, absorbed = absorbed,
                replacements = replacements, bonusAbsorbed = bonusAbsorbed }
        end
        local record = Snapshot.complete(before, Snapshot.capture(armies, "field"), exchanges)
        for key, value in pairs(record) do r[key] = value end
        return r
    end
    local function start(r)
        feedback:start(r)
        assert(feedback.cutin == feedback.armyCutin)
        return feedback.armyCutin
    end
    local function at(age, name)
        feedback.elapsed = feedback.settings.hitTime + age
        render(name)
    end
    local function verifyExchange(r)
        local amounts = require("src.sys.battlefield_engagement").calculate(r.armiesBefore, r.success)
        for _, side in ipairs({ "enemy", "allied" }) do assert(amounts[side] == r.sides[side].damage) end
    end
    local r = result("enemy", 3, 0, 7)
    local cutin = start(r)
    for _, side in ipairs({ "enemy", "allied" }) do
        local slots = cutin.layouts[side].slots
        assert(slots[#slots].unit.elite and not slots[1].unit.elite)
        for _, slot in ipairs(slots) do assert(slot.width == 176 and slot.height == 176) end
    end
    at(-0.05, "battlefield_stack_ready.png")
    at(0.04, "battlefield_stack_impact.png")
    local age = cutin.timelines.enemy.casualtyStart + cutin.view.liftDuration
    local pose = cutin:casualtyPose(r.sides.enemy.removed[1].id, age)
    assert(pose.lift > 0.99999 and pose.destruction < 0.00001)
    assert(not cutin.layouts.enemy.byId[r.sides.enemy.removed[1].id].unit.elite)
    at(age, "battlefield_stack_casualty.png")
    at(age + cutin.view.casualtyHold + 0.12, "battlefield_stack_destruction.png")
    at(cutin.timelines.enemy.casualtyEnd + 0.2, "battlefield_stack_survivors.png")
    assert(not feedback:update(0))
    assert(feedback:update(100))
    feedback:clear(); assert(not feedback:busy() and not cutin.record)
    r = result("allied", 2, 2, 7); cutin = start(r)
    assert(#r.sides.allied.removed == 0 and r.armiesAfter.protection == 0 and not r.sides.allied.defeated)
    local alliedElite = kinds.allied.elite
    kinds.allied.elite = "elite_abrams"
    r = result("allied", 2, 0, 2, 0, "elite"); cutin = start(r)
    assert(r.armiesBefore.protection == 2 and r.armiesAfter.protection == 2)
    assert(r.sides.allied.bonusAbsorbed == 2 and #r.sides.allied.removed == 0)
    at(0.12, "battlefield_stack_protected.png")
    kinds.allied.elite = alliedElite
    r = result("allied", 6, 1, 4); cutin = start(r)
    at(cutin.timelines.allied.casualtyStart + 0.18, "battlefield_stack_allied_loss.png")
    at(cutin.timelines.allied.casualtyEnd + 0.1, "battlefield_stack_defeat_scan.png")
    at(cutin.timelines.allied.casualtyEnd + 0.4, "battlefield_stack_defeated.png")
    r = result("enemy", 6, 0, 4); cutin = start(r)
    at(cutin.timelines.enemy.casualtyEnd + 0.1, "battlefield_stack_enemy_defeat.png")
    feedback.characterCutin.settings.reducedMotion = true
    cutin = start(r)
    assert(cutin.settings.reducedMotion and cutin:pose(feedback).offset == 0)
    at(cutin.timelines.enemy.casualtyStart + 0.2, "battlefield_stack_reduced_motion.png")
    feedback.characterCutin.settings.reducedMotion = false
    r = result("enemy", 100, 0, 120); cutin = start(r)
    assert((#r.sides.enemy.removed - 1) * cutin.timelines.enemy.stagger <= cutin.view.maxCascadeDuration + 0.0001)
    for _, slot in ipairs(cutin.layouts.enemy.slots) do
        assert(slot.x >= 0 and slot.x + slot.width <= cutin.view.panelWidth - cutin.view.padding * 2 - cutin.view.liftDistance + 0.001)
        assert(slot.y >= 0 and slot.y + slot.height <= cutin.view.stackHeight + 0.001)
    end
    at(-0.05, "battlefield_stack_large.png")
    local entry = cutin.portraits:entry(r.armiesBefore.enemy.forces[1].forceId)
    local savedImage = entry.image
    entry.image = nil
    at(-0.05, "battlefield_stack_missing_art.png")
    entry.image = savedImage
    -- Both sides animate independently, with allied protection delaying only allied casualties.
    r = result("enemy", 5, 1, 7, 5); verifyExchange(r); cutin = start(r)
    assert(cutin.timelines.allied.casualtyStart > cutin.timelines.enemy.casualtyStart)
    at(0.04, "battlefield_exchange_impact.png")
    at(cutin.timelines.allied.casualtyStart + 0.14, "battlefield_exchange_casualties.png")
    assert(cutin:casualtyPose(r.sides.enemy.removed[1].id, 0.5))
    assert(cutin:casualtyPose(r.sides.allied.removed[1].id, 0.5))
    at(math.max(cutin.timelines.enemy.casualtyEnd, cutin.timelines.allied.casualtyEnd) + 0.2,
        "battlefield_exchange_survivors.png")
    r = result("enemy", 4, 0, 4, 4, "elite"); verifyExchange(r); cutin = start(r)
    assert(r.sides.enemy.defeated and r.sides.allied.defeated)
    at(cutin.timelines.enemy.casualtyEnd + 0.1, "battlefield_exchange_mutual_defeat_scan.png")
    at(cutin.timelines.enemy.casualtyEnd + 0.4, "battlefield_exchange_mutual_defeat.png")
    feedback.characterCutin.settings.reducedMotion = true
    cutin = start(r)
    at(cutin.timelines.enemy.casualtyStart + 0.2, "battlefield_exchange_reduced_motion.png")
    feedback.characterCutin.settings.reducedMotion = false
    r = result("enemy", 0, 4, 1, 0, "regular"); verifyExchange(r); cutin = start(r)
    assert(next(cutin.casualties) == nil)
    at(0.04, "battlefield_exchange_zero_damage.png")
    -- Playback duration uses the longer side, not the sum of both sequences.
    r = result("enemy", 1, 0, 7, 6); cutin = start(r)
    local finish = math.max(cutin.timelines.enemy.casualtyEnd, cutin.timelines.allied.casualtyEnd)
        + cutin.view.settleDuration + cutin.view.resultHold
    assert(math.abs(feedback.settings.stepDuration - feedback.settings.hitTime - finish - feedback.view.exitDuration) < 0.00001)
    local revision = session.armies.revision
    feedback:update(100)
    assert(session.armies.revision == revision)
    -- One explosion at the first casualty destruction, on either side (also reduced motion).
    assert(feedback.audio.sources.armyCasualty)
    local play, explosions = feedback.audio.playOverlapping, 0
    feedback.audio.playOverlapping = function(_, cue)
        if cue == "armyCasualty" then explosions = explosions + 1 end
    end
    for _, scenario in ipairs({ { "enemy", 2, 0, 0 }, { "allied", 3, 1, 0 }, { "enemy", 2, 0, 2 } }) do
        feedback.characterCutin.settings.reducedMotion = scenario[1] == "allied"
        start(result(scenario[1], scenario[2], scenario[3], 4, scenario[4]))
        local before = explosions
        feedback:update(feedback.casualtySoundTime - 0.001)
        assert(explosions == before)
        feedback:update(0.002); feedback:update(0); feedback:update(100)
        assert(explosions == before + 1)
        feedback:clear(); feedback:update(100)
        assert(explosions == before + 1)
    end
    feedback.characterCutin.settings.reducedMotion = false
    local before = explosions
    start(result("allied", 2, 2, 4)); feedback:update(100)
    assert(not feedback.casualtySoundTime and explosions == before, "Fully absorbed damage has no explosion")
    start(result("enemy", 0, 0, 4)); feedback:update(100)
    assert(explosions == before, "Zero casualties have no explosion")
    start(result("enemy", 2, 0, 4)); feedback:clear(); feedback:update(100)
    assert(explosions == before, "Cancelled playback cannot emit a pending explosion")
    feedback.audio.playOverlapping = play
    kinds.allied.regular = "reg_vicky"
    r = result("allied", 9, 0, 2, 0, "regular")
    assert(#r.sides.allied.removed == 2 and not r.sides.allied.defeated)
    for _, reduced in ipairs({ false, true }) do
        feedback.characterCutin.settings.reducedMotion = reduced
        cutin = start(r)
        local timeline, layout = cutin.timelines.allied, cutin.layouts.allied
        local first = r.sides.allied.removed[1]
        assert(layout.origins[first.replacementId] == layout.byId[first.id])
        local drawn, draw = {}, cutin.portraits.draw
        function cutin.portraits:draw(id, ...)
            drawn[id] = (drawn[id] or 0) + 1
            return draw(self, id, ...)
        end
        local age = timeline.casualtyStart + cutin.view.liftDuration + cutin.view.casualtyHold
        at(age + cutin.view.destructionDuration * 0.75, "battlefield_conversion.png")
        assert(drawn.reg_cold_hand == 1 and drawn.reg_vicky >= 1)
        drawn = {}
        at(timeline.casualtyEnd + cutin.view.settleDuration, "battlefield_conversion_settled.png")
        assert(drawn.reg_cold_hand == 2 and not drawn.reg_vicky)
        cutin.portraits.draw = draw
    end
    feedback.characterCutin.settings.reducedMotion = false
    feedback:clear()
    feedback:start({ battlefield = true, battlefieldKind = "entrench", locationId = session.assignments["south"] })
    assert(feedback.cutin == feedback.characterCutin)
    assert(feedback.settings.stepDuration == feedback.settings.hitTime + feedback.view.holdDuration + feedback.view.exitDuration)
    feedback:clear()
end
