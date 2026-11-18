local Clock = {}
local function whole(n) return type(n) == "number" and n >= 0 and n < math.huge and n % 1 == 0 end
function Clock.new(rules)
    assert(whole(rules.slotCount) and rules.slotCount > 0, "Invalid doom slot count")
    assert(whole(rules.cardsMilledPerLockedSlot), "Invalid doom milling rate")
    assert(whole(rules.cardsPreventedPerAutosuccess), "Invalid autosuccess milling reduction")
    local tests = {}
    for _, kind in ipairs({ "encounter", "battlefield", "clash" }) do
        assert(type(rules.tests[kind]) == "boolean", "Invalid doom test category " .. kind)
        tests[kind] = rules.tests[kind]
    end
    local slots = {}; for i = 1, rules.slotCount do slots[i] = "pending" end
    return { slots = slots, successes = {}, revision = 0, phase = 1, warningUsed = false,
        rate = rules.cardsMilledPerLockedSlot, relief = rules.cardsPreventedPerAutosuccess, tests = tests }
end
function Clock.locked(clock)
    local n = 0; for _, state in ipairs(clock.slots) do if state == "locked" then n = n + 1 end end
    return n
end
function Clock.strength(clock)
    local successes = 0
    for _, present in pairs(clock.successes) do if present then successes = successes + 1 end end
    return math.max(0, Clock.locked(clock) * clock.rate - successes * clock.relief)
end
function Clock.prepare(clock, kind, result)
    local slots, successes, changed, events = {}, {}, {}, {}
    local warning = kind == "test" and result.special == "auto_failure" and not clock.warningUsed
    for i, state in ipairs(clock.slots) do slots[i], successes[i] = state, clock.successes[i] end
    local function set(i, state, effect)
        local previousSuccess = successes[i]
        slots[i] = state
        if state == "locked" then successes[i] = nil end
        changed[#changed + 1] = i
        events[#events + 1] = { kind = effect, slots = { i }, overwrittenSuccess = previousSuccess }
    end
    if kind == "test" then
        local category = result.clash and "clash" or result.battlefield and "battlefield" or "encounter"
        if warning then
            -- The first revealed autofail is a warning even without a drop target.
            -- Keep its waiting icon; phase-end advancement can still lock it.
        elseif clock.tests[category] then
            if result.special == "auto_failure" then
                local target
                for i = 1, #slots do if slots[i] == "pending" then target = i; break end end
                if target then
                    set(target, "locked", "drop")
                else
                    -- With no waiting icon, queue one for a later draw or phase end.
                    -- An autosuccess stays in place until the queued Glory drops.
                    for i = 1, #slots do if slots[i] ~= "locked" then target = i; break end end
                    if target then set(target, "pending", "populate") end
                end
            elseif result.special == "auto_success" then
                local source, target
                for i = #slots, 1, -1 do
                    if not source and slots[i] == "pending" then source = i end
                    if not target and slots[i] ~= "locked" and not successes[i] then target = i end
                end
                -- Conversion consumes one waiting image, independently of its destination.
                -- Success tiles block other successes, but never block waiting autofails.
                if source and target then
                    set(source, "cleared", "convert")
                    successes[target] = true
                    events[#events + 1] = { kind = "success_drop", slots = { target }, sourceIndex = source }
                end
            elseif result.success then
                for i = #slots, 1, -1 do if slots[i] == "pending" then set(i, "cleared", "clear"); break end end
            end
        end
    elseif kind == "end_phase" then
        for i, state in ipairs(slots) do if state == "pending" then set(i, "locked", "drop") end end
    elseif kind == "begin_phase" then
        for i, state in ipairs(slots) do if state ~= "locked" then set(i, "pending", "populate") end end
    else error("Unknown doom change " .. tostring(kind)) end
    return { source = clock, revision = clock.revision, slots = slots, successes = successes,
        changed = changed, events = events, kind = kind, warning = warning,
        warningUsed = clock.warningUsed or warning,
        phase = clock.phase + (kind == "begin_phase" and 1 or 0) }
end
function Clock.canCommit(clock, plan)
    return plan and not plan.committed and plan.source == clock and plan.revision == clock.revision
end
function Clock.commit(session, plan)
    local clock = session.doomClock
    if not Clock.canCommit(clock, plan) then return false end
    clock.slots, clock.successes, clock.phase, clock.revision = plan.slots, plan.successes, plan.phase, clock.revision + 1
    clock.warningUsed = plan.warningUsed
    if plan.warning then
        session.doomWarning = { elapsed = 0 }
        if session.scene then require("src.ui.mission_backdrop").escalate(session.scene) end
    end
    plan.committed = true
    session.doomPresentation = session.doomPresentation or {}
    for _, event in ipairs(plan.events) do
        event.elapsed = 0
        session.doomPresentation[#session.doomPresentation + 1] = event
    end
    return true
end
return Clock
