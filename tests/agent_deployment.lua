return function(write)
    local Machine = require("src.states.state_machine")
    local Preparation = require("src.states.mission_preparation")
    local Deployment = require("src.states.mission_deployment")
    local Model = require("src.sys.agent_deployment")
    local machine = Machine.new()
    local prep = Preparation.new(machine, 1280, 720)
    local state = Deployment.new(machine, 1280, 720)
    machine:register("mission_preparation", prep)
    machine:register("mission_deployment", state)
    machine:change("mission_preparation")
    assert(prep:deploy())
    local moves = 0
    assert(state.audio.sources.agentMove)
    local actualPlay = state.audio.playOverlapping
    state.audio.playOverlapping = function(self, id)
        if id == "agentMove" then moves = moves + 1 end
        return actualPlay(self, id)
    end
    local roster, grid = state.roster, state.grid
    local ids = state.package.agentIds
    local populated = {}
    for _, cell in ipairs(grid.cells) do
        assert(grid:hit(cell.x, cell.y) == cell)
        if state.assignments[cell.id] then populated[#populated + 1] = cell end
    end
    assert(#populated >= 2, "Drag checks need at least two populated cells")
    local first, second = populated[1], populated[2]
    local a = roster.entries[1]
    local function drag(entry, x, y)
        state:mousepressed(entry.x + 5, entry.y + 5, 1)
        state:pointermoved(x, y)
        state:mousereleased(x, y, 1)
    end
    drag(a, first.x, first.y)
    assert(next(state.agentDeployment.placements) == nil and not state.drag.pending)
    state:update(state.promptStart)
    assert(not state:inputReady())
    drag(a, first.x, first.y)
    assert(next(state.agentDeployment.placements) == nil)
    state:update(0.16)
    assert(state:inputReady())
    state:update(0.15) -- Let the visual Ready button finish its own fade.
    assert(not state.agentDeployment:assign("unknown", first.id))
    assert(not state.agentDeployment:assign(ids[1], "unknown"))
    local canvas = love.graphics.newCanvas(1280, 720)
    local function render(name)
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        love.graphics.setScissor(0, 0, 1280, 720)
        state:draw()
        local x, y, w, h = love.graphics.getScissor()
        assert(x == 0 and y == 0 and w == 1280 and h == 720)
        love.graphics.setScissor()
        love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        write(name, pixels:encode("png"):getString())
        pixels:release()
    end
    local rowCounts = { { 1 }, { 2 }, { 2, 1 }, { 2, 2 }, { 3, 2 }, { 3, 3 } }
    for count = 1, 6 do
        drag(roster.entries[count], first.x, first.y)
        assert(#state.agentDeployment:occupants(first.id) == count and moves == count)
        assert(state.agentDeployment:allAssigned() == (count == 6))
        local rows = {}
        for _, entry in ipairs(state.agentView.entries) do
            assert(entry.x % 1 == 0 and entry.y % 1 == 0)
            rows[entry.y] = (rows[entry.y] or 0) + 1
        end
        local ys = {}
        for y in pairs(rows) do ys[#ys + 1] = y end
        table.sort(ys)
        assert(#ys == #rowCounts[count])
        for i, y in ipairs(ys) do assert(rows[y] == rowCounts[count][i]) end
        if #ys == 2 then assert(ys[2] - ys[1] == 51) end
        state:pointermoved(nil, nil)
        state:update(0.05)
        assert(state.agentView.rosterBrightness[ids[count]] > 0.5)
        state:update(0.05)
        for i, id in ipairs(ids) do
            assert(math.abs(state.agentView.rosterBrightness[id] - (i <= count and 0.5 or 1)) < 0.00001)
        end
        render("agent_cluster_" .. count .. ".png")
    end
    -- Every agent has exposed pixels that select it, even in a six-agent stack.
    for _, entry in ipairs(state.agentView.entries) do
        state.agentView:clearHover()
        local hit = state.agentView:hover(entry.x + 1, entry.y + 1)
        assert(hit and hit.id == entry.id)
        assert(state.agentView:hover(entry.x + 45, entry.y + 20).id == entry.id)
    end
    state.agentView.hovered = ids[1]
    state:update(0.1)
    assert(state.agentView.rosterBrightness[ids[1]] == 1)
    render("agent_cluster_hover.png")
    local placed = state.agentView.byId[ids[1]]
    drag(placed, second.x, second.y)
    assert(state.agentDeployment.placements[ids[1]] == second.id
        and #state.agentDeployment:occupants(first.id) == 5)
    assert(moves == 7)
    drag(a, second.x, second.y)
    assert(moves == 7) -- Same-location drops are silent.
    -- Invalid targets, a non-drag click, right click, and cancellation preserve the assignment.
    drag(a, 10, 10)
    assert(state.agentDeployment.placements[ids[1]] == second.id)
    state:mousepressed(a.x + 5, a.y + 5, 1)
    state:mousereleased(a.x + 6, a.y + 5, 1)
    assert(state.agentDeployment.placements[ids[1]] == second.id)
    state:mousepressed(a.x + 5, a.y + 5, 2)
    state:mousereleased(first.x, first.y, 2)
    assert(state.agentInspectionPanel and not state.drag.pending)
    state:keypressed("escape")
    for _, cancel in ipairs({
        function() state:focus(false) end,
        function() state:keypressed("escape") end,
        function() state:pointermoved(nil, nil) end,
    }) do
        state:mousepressed(a.x + 5, a.y + 5, 1)
        state:pointermoved(first.x, first.y)
        local pose = state.drag:pose()
        assert(pose and pose.x % 1 == 0 and pose.y % 1 == 0)
        cancel()
        state:mousereleased(first.x, first.y, 1)
        assert(not state.drag.pending and state.agentDeployment.placements[ids[1]] == second.id)
    end
    local eligible = state.agentDeployment.eligible[first.id]
    state.agentDeployment.eligible[first.id] = nil
    drag(a, first.x, first.y)
    assert(state.agentDeployment.placements[ids[1]] == second.id)
    state.agentDeployment.eligible[first.id] = eligible
    -- Bounding-box corner must not count as this hex.
    assert(grid:hit(first.x - 50, first.y - 45) ~= first)
    drag(state.agentView.byId[ids[1]], roster.x + 10, roster.y + 10)
    assert(not state.agentDeployment.placements[ids[1]] and moves == 7)
    assert(not state.agentDeployment:allAssigned())
    state:update(0)
    assert(state.agentView.rosterBrightness[ids[1]] == 1)
    for i = 1, 3 do drag(roster.entries[i], second.x, second.y) end
    state:pointermoved(nil, nil)
    render("agent_clusters_adjacent.png")
    local image = roster.entries[1].image
    roster.entries[1].image = nil
    state:draw()
    roster.entries[1].image = image
    state:mousepressed(a.x + 5, a.y + 5, 1)
    state:pointermoved(first.x, first.y)
    render("agent_drag.png")
    local controller = state.drag
    machine:change("mission_preparation")
    assert(not controller.pending and not state.agentDeployment and not roster.entries[1].image)
    prep:exit()
    canvas:release()
    -- Logical assignments are independent of the source IDs and location tables.
    local sourceIds, locations = { "a", "b" }, { west = "location" }
    local model = Model.new(sourceIds, locations)
    sourceIds[1], locations.west = "changed", nil
    assert(model:assign("a", "west") and model:assign("b", "west"))
    assert(#model:occupants("west") == 2 and model:assign("a", nil))
end
