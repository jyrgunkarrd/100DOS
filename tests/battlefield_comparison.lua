return function(write)
    local Model = require("src.sys.battlefield_comparison")
    local agent = { id = "a", name = "Agent", talents = { { type = "steel", qty = 4 }, { type = "reason", qty = 2 } } }
    local function location(steel, reason)
        return { battlefield_talent = { { type = "steel", qty = steel }, { type = "reason", qty = reason } } }
    end
    local locations = { byId = { a = location(3, 4), b = location(2, 4), c = location(2, 6),
        distant = location(0, 0), jacl = location(0, 0) } }
    local assignments = { a = "a", b = "b", c = "c", distant = "distant", center = "jacl" }
    local result = Model.build(assignments, locations, agent, { a = true, b = true, c = true, center = true }, "center")
    assert(result.bestMargin == 2 and result.byCell.b.best and result.byCell.c.best and not result.byCell.a.best)
    assert(not result.byCell.distant.best and not result.byCell.center.best and #result.byCell.center.tests == 0)
    assert(result.byCell.a.tests[1].score == 4 and result.byCell.a.tests[1].difficulty == 3)
    assert(result.byCell.a.tests[2].margin == -2)
    assert(locations.byId.a.battlefield_talent[1].qty == 3 and agent.talents[1].qty == 4)
    local weak = { name = "Weak", talents = {} }
    result = Model.build(assignments, locations, weak, { a = true, b = true, c = true }, "center")
    assert(result.bestMargin == -2 and result.byCell.b.best and result.byCell.c.best)
    result = Model.build(assignments, locations, agent, {}, "center")
    assert(result.bestMargin == nil)
    for _, entry in pairs(result.byCell) do assert(not entry.best) end

    -- Purpose is a hidden baseline, never a contributor to alternative ranking.
    local revised = { byId = {
        a = { name = "A", battlefield_talent = { { type = "fire", qty = 4 }, { type = "purpose", qty = 2 }, { type = "steel", qty = 3 } } },
        b = { name = "B", battlefield_talent = { { type = "purpose", qty = 2 }, { type = "reason", qty = 3 }, { type = "rhyme", qty = 4 } } },
        distant = { name = "Distant", battlefield_talent = { { type = "purpose", qty = 2 }, { type = "steel", qty = 0 } } },
    } }
    local mapping, valid = { a = "a", b = "b", distant = "distant" }, { a = true, b = true }
    local specialist = { name = "Specialist", talents = { { type = "purpose", qty = 5 }, { type = "steel", qty = 5 } } }
    local m = Model.build(mapping, revised, specialist, valid, "center")
    assert(m.purposeStrongest and not m.noPreference and m.bestMargin == 2)
    assert(m.byCell.a.baseline.band == "best" and m.byCell.b.baseline.band == "best")
    assert(m.byCell.a.tests[1].band == "next" and m.byCell.a.tests[2].band == "worst")
    assert(m.byCell.b.tests[1].band == "worst" and m.byCell.b.tests[2].band == "worst")
    -- Harder checks rank by their own margin. Unreachable easier
    -- Steel checks do not displace Purpose as the best test.
    revised.byId.b.battlefield_talent[3] = { type = "steel", qty = 4 }
    local harder = Model.build(mapping, revised, specialist, valid, "center")
    assert(harder.byCell.b.tests[2].band == "worst" and harder.byCell.a.baseline.band == "best")
    assert(harder.byCell.a.tests[1].band == "next")
    revised.byId.b.battlefield_talent[3] = { type = "rhyme", qty = 4 }
    assert(#m.byCell.a.tests == 2 and m.byCell.a.tests[1].talent == "steel" and m.byCell.a.tests[1].emphasized)
    assert(m.byCell.a.tests[1].baselineRelation == "below" and not m.byCell.distant.tests[1].emphasized)
    local generalist = { name = "Apex", talents = {} }
    for _, talent in ipairs({ "purpose", "steel", "fire", "reason", "rhyme", "passion" }) do
        generalist.talents[#generalist.talents + 1] = { type = talent, qty = 3 }
    end
    m = Model.build(mapping, revised, generalist, valid, "center")
    assert(m.noPreference and m.purposeStrongest and m.bestMargin == 0)
    for _, entry in pairs(m.byCell) do for _, test in ipairs(entry.tests) do assert(not test.emphasized and test.talent ~= "purpose") end end
    specialist.talents[1].qty = 4
    m = Model.build(mapping, revised, specialist, valid, "center")
    assert(not m.purposeStrongest and m.byCell.a.tests[1].baselineRelation == "equal")
    assert(m.byCell.a.baseline.band == "best" and m.byCell.a.tests[1].band == "best")
    specialist.talents[1].qty = 1
    m = Model.build(mapping, revised, specialist, valid, "center")
    assert(m.byCell.a.tests[1].baselineRelation == "above")
    m = Model.build(mapping, revised, specialist, {}, "center")
    assert(m.eligibleCount == 0 and not m.noPreference and not m.purposeStrongest)
    assert(#revised.byId.a.battlefield_talent == 3 and revised.byId.a.battlefield_talent[2].type == "purpose")

    -- Tomorrow's Reason 4 vs 4 and Passion 3 vs 3 at Black Farm must
    -- match Purpose 2 vs 2, even with an easier Reason test elsewhere.
    local tomorrow = require("data.agents.tomorrow")
    local farmLocations = { byId = {
        farm = require("data.locations.roswell_shallows.black_farm"),
        easier = { battlefield_talent = { { type = "purpose", qty = 2 }, { type = "reason", qty = 3 } } },
    } }
    local farmMap = { farm = "farm", easier = "easier" }
    local farmModel = Model.build(farmMap, farmLocations, tomorrow, { farm = true, easier = true }, "center")
    local farm = farmModel.byCell.farm
    assert(farm.baseline.margin == 0 and farm.baseline.band == "next")
    for _, test in ipairs(farm.tests) do assert(test.margin == 0 and test.band == farm.baseline.band) end
    assert(farmModel.byCell.easier.tests[1].band == "best")
    farmModel = Model.build(farmMap, farmLocations, tomorrow, { farm = true }, "center")
    assert(farmModel.byCell.farm.baseline.band == "best")
    for _, test in ipairs(farmModel.byCell.farm.tests) do assert(test.band == "best") end

    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deploy = machine.current; deploy:update(2)
    local state = deploy
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.push("all"); love.graphics.setCanvas(canvas); love.graphics.clear(); state:draw(); love.graphics.setCanvas(); love.graphics.pop()
        local data = canvas:newImageData(); local encoded = data:encode("png")
        write(name, encoded:getString()); encoded:release(); data:release(); canvas:release()
    end
    local originalKeys = love.keyboard.isDown
    local held
    love.keyboard.isDown = function(...)
        for _, key in ipairs({ ... }) do if key == held then return true end end
        return false
    end
    local ok, message = xpcall(function()
        local id = deploy.package.agentIds[1]
        deploy.agentDeployment:assign(deploy.package.agentIds[2], "south")
        deploy.agentView:refresh()
        local portrait = deploy.roster.entries[1]
        deploy:mousepressed(portrait.x + 4, portrait.y + 4, 1)
        assert(not deploy:comparisonModel(), "Click without drag must not open comparison")
        deploy:pointermoved(940, 260)
        assert(deploy.drag.active and deploy:comparisonModel().agentId == id)
        local model = deploy:comparisonModel()
        assert(#model.byCell.center.tests == 0 and not model.byCell.center.best)
        -- Native 32px icons and their value lines fit inside every hex for 1/2/3 tests.
        for _, hex in ipairs(deploy.grid.cells) do
            for count = 1, 3 do
                for _, slot in ipairs(deploy.comparison:slots(count)) do
                    local x, y = math.floor(hex.x + slot.x - 16), math.floor(hex.y + slot.y)
                    for _, point in ipairs({ { x, y }, { x + 31, y },
                        { x, y + 31 }, { x + 31, y + 31 },
                        { x + 8, y + 32 + deploy.scene.accents.small:getHeight() - 1 },
                        { x + 23, y + 32 + deploy.scene.accents.small:getHeight() - 1 } }) do
                        local hit = deploy.grid:hit(point[1], point[2])
                        assert(hit and hit.id == hex.id, "Comparison content exceeds hex bounds")
                    end
                end
            end
        end
        render("battlefield_comparison_deployment.png")
        local north
        for _, hex in ipairs(deploy.grid.cells) do if hex.id == "north" then north = hex end end
        deploy:pointermoved(north.x, north.y)
        assert(deploy:comparisonModel().hoveredCell == "north")
        render("battlefield_comparison_hover.png")
        local originalAgent = deploy.comparison.agents.byId[id]
        deploy.comparison.agents.byId[id] = generalist
        assert(deploy:comparisonModel().noPreference)
        deploy:pointermoved(940, 260)
        render("battlefield_comparison_generalist.png")
        specialist.talents[1].qty = 5
        deploy.comparison.agents.byId[id] = specialist
        assert(deploy:comparisonModel().purposeStrongest)
        render("battlefield_comparison_purpose.png")
        deploy.comparison.agents.byId[id] = originalAgent
        for _, entry in pairs(model.byCell) do
            for _, test in ipairs(entry.tests) do
                assert(test.talent ~= "purpose")
                local alpha = deploy.comparison:testAlpha(model, entry, test)
                if entry.eligible then assert(alpha > deploy.comparison.settings.unavailableAlpha) end
            end
        end
        for _, entry in pairs(model.byCell) do
            for _, test in ipairs(entry.tests) do
                local icon = deploy.comparison.assets:load(deploy.comparison.settings.talentDirectory .. "/" .. test.talent .. ".png")
                assert(icon and icon:getWidth() == 32 and icon:getHeight() == 32)
            end
        end
        for _, key in ipairs({ "lctrl", "rctrl" }) do
            held = key
            assert(require("src.ui.battlefield_comparison").positionsHeld())
            render("battlefield_comparison_deployment_positions.png")
            assert(deploy.drag.active and deploy:comparisonModel() and deploy.agentDeployment.placements[id] == nil)
        end
        held = nil
        deploy:keypressed("escape"); assert(not deploy:comparisonModel())
        deploy:mousepressed(portrait.x + 4, portrait.y + 4, 1); deploy:pointermoved(940, 260)
        deploy:focus(false); assert(not deploy:comparisonModel())
        deploy:mousepressed(portrait.x + 4, portrait.y + 4, 1); deploy:pointermoved(640, 180)
        deploy:mousereleased(640, 180, 1)
        assert(deploy.agentDeployment.placements[id] == "center" and not deploy:comparisonModel())
        for _, agentId in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(agentId, "north") end
        deploy.agentView:refresh(); assert(deploy:beginAction())
        local mission = machine.current; mission:update(1)
        mission.selectedId = id; assert(mission:beginAgentAction())
        state = machine.current; state:update(2)
        local session, panel = state.session, state.actions
        local ap = session.agentStatus.byAgent[id].actionPoints
        local function click(x, y) state:pointermoved(x, y); state:mousepressed(x, y, 1); state:mousereleased(x, y, 1) end
        local function targetMove()
            click(panel.button.x + 4, panel.button.y + 4)
            local row = panel.rows[1]; click(row.x + 4, row.y + 4)
            assert(panel.targeting)
        end
        targetMove()
        model = assert(state:comparisonModel())
        assert(not model.byCell.north.eligible and not model.byCell.south.eligible and model.byCell.center.eligible)
        local eligible = {}
        for _, cellId in ipairs(require("src.sys.board_topology").locations(session, "north")) do eligible[cellId] = true end
        for cellId, entry in pairs(model.byCell) do
            assert(entry.eligible == (eligible[cellId] == true))
            if entry.best then assert(eligible[cellId] and cellId ~= "center") end
        end
        local target
        for _, hex in ipairs(session.grid.cells) do if eligible[hex.id] and hex.id ~= "center" then target = hex; break end end
        assert(target)
        state:pointermoved(target.x, target.y)
        assert(state:comparisonModel().hoveredCell == target.id)
        render("battlefield_comparison_move.png")
        held = "lctrl"; render("battlefield_comparison_move_positions.png")
        assert(panel.targeting and session.agentStatus.byAgent[id].actionPoints == ap)
        held = nil
        state:keypressed("escape"); assert(not state:comparisonModel() and session.agentStatus.byAgent[id].actionPoints == ap)
        targetMove(); state:focus(false); assert(not state:comparisonModel())
        targetMove(); click(640, 180)
        assert(session.agentDeployment.placements[id] == "center" and session.agentStatus.byAgent[id].actionPoints == ap - 1)
        assert(not state:comparisonModel())
        state:exit()
    end, debug.traceback)
    love.keyboard.isDown = originalKeys
    assert(ok, message)
end
