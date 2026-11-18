return function(write)
    local Spawn = require("src.sys.clash_reinforcements")
    local Clashes = require("src.sys.battlefield_clashes")
    local State = require("src.sys.battlefield_state")
    local Turn = require("src.sys.agent_turn")
    local first = { random = function(_, n) return n and 1 or 0 end }
    local function fixture(allies, cell)
        cell = cell or "field"
        local s = { activeAgentId = "a", agentDeployment = { placements = { a = cell } },
            agentStatus = { byAgent = { a = { health = 5, defiance = 5, actionPoints = 0 } } },
            armies = { jaclCellId = "center", revision = 0, reinforcementSerial = 0,
                catalogue = { byId = { soldier = { strength = "regular" } } },
                rules = { strength = { regular = 1 }, weights = { enemy = { normal = 1, supreme = 1 } } },
                templates = { enemy = { ids = { "only" }, byId = { only = { { str = "regular", qty = 2 } } } } },
                pools = { enemy = { regular = { "soldier" }, elite = {} } },
                byCell = { [cell] = { protection = 2, revision = 0,
                    allied = { forces = allies and { { id = "friend", forceId = "soldier" } } or {} },
                    enemy = { forces = {} }, clashes = { { remaining = 3, damage = 7, difficulty = 9 } } } } } }
        State.touch(s.armies, cell)
        return s, s.armies.byCell[cell]
    end
    local s, pair = fixture(false)
    local plan = Spawn.prepare(s, "a", first)
    assert(Clashes.count(pair) == 3 and #pair.enemy.forces == 0 and s.armies.reinforcementSerial == 0)
    assert(Spawn.commit(s, plan) and not Spawn.commit(s, plan))
    assert(Clashes.count(pair) == 2 and pair.enemy.value == 2 and pair.protection == 2)
    assert(pair.clashes[1].damage == 7 and pair.clashes[1].difficulty == 9)
    local oldArmy, oldUnit = pair.enemy.id, pair.enemy.forces[1].id
    assert(s.pendingEndTurn and not Spawn.prepare(s, "a", first))
    require("src.ui.clash_reinforcement_feedback").update(s, 10)
    pair.enemy.forces = {}; State.touch(s.armies, "field")
    assert(not Spawn.prepare(s, "a", first), "Cannot spawn twice in one pending end turn")
    local finish = Turn.prepare(s, "a"); assert(finish.endsTurn and finish.publish())
    plan = Spawn.prepare(s, "a", first); assert(Spawn.commit(s, plan))
    assert(pair.enemy.templateId == "only" and pair.enemy.id ~= oldArmy and pair.enemy.forces[1].id ~= oldUnit)
    assert(Clashes.count(pair) == 1)
    s, pair = fixture(true, "center"); assert(not Spawn.prepare(s, "a", first))
    s, pair = fixture(true); pair.clashes = {}; assert(not Spawn.prepare(s, "a", first))
    s, pair = fixture(true); pair.enemy.forces = { { forceId = "soldier" } }; State.touch(s.armies, "field")
    assert(not Spawn.prepare(s, "a", first))
    s, pair = fixture(true); plan = Spawn.prepare(s, "a", first)
    State.touch(s.armies, "field"); assert(not Spawn.commit(s, plan) and Clashes.count(pair) == 3)
    s, pair = fixture(true); s.armies.pools.enemy.regular = {}
    assert(not pcall(Spawn.prepare, s, "a", first) and Clashes.count(pair) == 3 and #pair.enemy.forces == 0)

    -- Actual Done flow: arrival blocks input, then resumes ordinary Clash tests.
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deploy = machine.current; deploy:update(2)
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, "north") end
    deploy.agentView:refresh(); assert(deploy:beginAction())
    local mission = machine.current; mission:update(5)
    mission.selectedId = mission.session.package.agentIds[1]; assert(mission:beginAgentAction())
    local action = machine.current; action:update(5); s = action.session
    pair = s.armies.byCell.north
    pair.allied.forces = { { id = "test_friend", forceId = s.armies.pools.allied.regular[1] } }
    pair.enemy.forces = {}; pair.clashes = { { remaining = 3, damage = 0, difficulty = 0 } }
    State.touch(s.armies, "north")
    assert(action:endTurn() and s.reinforcementFeedback and s.pendingEndTurn)
    assert(Clashes.count(pair) == 2 and not action:endTurn() and not action:basicActionsEnabled())
    action:update(0.2)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(); action:draw()
    love.graphics.setCanvas(); love.graphics.pop()
    local pixels = canvas:newImageData(); write("clash_reinforcement.png", pixels:encode("png"):getString())
    pixels:release(); canvas:release()
    action:update(10)
    assert(not s.reinforcementFeedback and action.testPanel.battlefieldArgs.clash == pair.clashes[1])
    -- Simulate the army being eliminated by those tests: no second reinforcement.
    action.testPanel:close(); pair.enemy.forces = {}; State.touch(s.armies, "north")
    assert(action:endTurn())
    if machine.currentName == "agent_action" then machine.current:update(10) end
    assert(machine.currentName == "mission_action" and Clashes.count(pair) == 2)
    machine.current:exit()
    write("clash_reinforcement_results.txt", "PASS: repeatable army templates, unique instances, atomic Clash cost, exclusions, stale plans and end-turn UI continuation\n")
end
