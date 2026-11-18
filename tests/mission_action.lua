return function(write)
    local Machine = require("src.states.state_machine")
    local Prep = require("src.states.mission_preparation")
    local Deployment = require("src.states.mission_deployment")
    local Action = require("src.states.mission_action")
    local machine = Machine.new()
    local prep, deploy, action = Prep.new(machine, 1280, 720), Deployment.new(machine, 1280, 720), Action.new(machine, 1280, 720)
    machine:register("mission_preparation", prep)
    machine:register("mission_deployment", deploy)
    machine:register("mission_action", action)
    machine:change("mission_preparation")
    assert(prep:deploy())
    local readyPlays, selectionPlays = 0, 0
    assert(deploy.audio.sources.selection)
    assert(deploy.audio.sources.ready)
    local actualPlay = deploy.audio.playOverlapping
    deploy.audio.playOverlapping = function(self, id)
        if id == "ready" then readyPlays = readyPlays + 1 end
        if id == "selection" then selectionPlays = selectionPlays + 1 end
        return actualPlay(self, id)
    end
    assert(not deploy:canReady())
    deploy:update(2)
    local bx, by = deploy.readyButton:layout(deploy:promptLayout())
    bx, by = bx + 4, by + 4
    local function readyClick()
        deploy:mousepressed(bx, by, 1)
        deploy:mousereleased(bx, by, 1)
    end
    readyClick()
    assert(machine.current == deploy)
    local ids = deploy.package.agentIds
    local cell
    for _, c in ipairs(deploy.grid.cells) do if deploy.assignments[c.id] then cell = c; break end end
    for _, id in ipairs(ids) do deploy.agentDeployment:assign(id, cell.id) end
    deploy.agentView:refresh()
    deploy:update(0.2)
    assert(deploy:canReady())
    deploy:mousereleased(bx, by, 1)
    assert(machine.current == deploy)
    deploy:mousepressed(bx, by, 1)
    deploy:mousereleased(nil, nil, 1)
    assert(machine.current == deploy)
    deploy:mousepressed(bx, by, 1)
    deploy:focus(false)
    deploy:mousereleased(bx, by, 1)
    assert(machine.current == deploy)
    local first = deploy.roster.entries[1]
    deploy:mousepressed(first.x + 4, first.y + 4, 1)
    deploy:pointermoved(bx, by)
    assert(not deploy:canReady())
    deploy:mousereleased(bx, by, 1)
    assert(machine.current == deploy)
    local originalLoad = love.filesystem.load
    love.filesystem.load = function(path)
        if path == "data/mission_action.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not deploy:beginAction())
    love.filesystem.load = originalLoad
    assert(machine.current == deploy and deploy.actionError and deploy.roster.entries[1].image)
    -- Invalid opening rules keep deployment intact and do not publish partial hands.
    love.filesystem.load = function(path)
        if path == "data/card_system_defaults.lua" then
            return function() return { startingHandSize = -1, activationDrawCount = 1 } end
        end
        return originalLoad(path)
    end
    assert(not deploy:beginAction())
    love.filesystem.load = originalLoad
    assert(not deploy.agentCards and not deploy.agentStatus and machine.current == deploy)
    local scene, grid, art, roster, model, package, audio, ready = deploy.scene, deploy.grid,
        deploy.art, deploy.roster, deploy.agentDeployment, deploy.package, deploy.audio, deploy.readyButton
    local time = scene.entranceTime
    assert(readyPlays == 0)
    readyClick()
    assert(readyPlays == 1)
    assert(machine.current == action and not deploy.roster and not deploy.scene and not deploy.agentDeployment)
    assert(next(ready.images) ~= nil and action.oldReady == ready)
    local s = action.session
    for _, id in ipairs(ids) do
        assert(#s.agentCards.byAgent[id].hand == 5 and #s.agentCards.byAgent[id].drawPile == 15)
    end
    assert(not require("src.sys.mission_lifecycle").prepare(s))
    local fresh = require("src.sys.mission_lifecycle").prepare({ package = package })
    assert(fresh.agentCards ~= s.agentCards and fresh.agentStatus ~= s.agentStatus)
    for _, id in ipairs(ids) do
        assert(#fresh.agentCards.byAgent[id].hand == 5)
        assert(fresh.agentCards.byAgent[id].hand[1] ~= s.agentCards.byAgent[id].hand[1])
    end

    assert(s.scene == scene and s.grid == grid and s.art == art and s.roster == roster
        and s.agentDeployment == model and s.package == package and s.audio == audio)
    assert(scene.entranceTime == time and not action.selectedId and not action:inputReady())
    assert(action.panel.width == 89 and action.panel.height == 21)
    assert(action.panel.x % 1 == 0 and action.panel.y % 1 == 0
        and math.abs(action.panel.x + 44.5 - (roster.x + roster.width / 2)) <= 0.5)
    assert(action.panel.promptY < roster.y and action.panel.y > roster.y + roster.height)
    assert(action.panel.images["false"] and action.panel.images["true"])
    local canvas = love.graphics.newCanvas(1280, 720)
    local function render(name)
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        action:draw()
        love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        write(name, pixels:encode("png"):getString())
        pixels:release()
    end
    render("mission_action_transition_start.png")
    action:mousepressed(first.x + 2, first.y + 2, 1)
    action:mousereleased(first.x + 2, first.y + 2, 1)
    assert(not action.selectedId)
    action:update(0.08)
    render("mission_action_transition_mid.png")
    action:update(0.12)
    -- Hunt distribution is an independent, skippable mission-start presentation.
    assert(action.session.huntPresentation and not action:inputReady())
    action:keypressed("space")
    assert(action:inputReady() and next(ready.images) == nil and not action.oldReady)
    render("mission_action.png")
    local function click(entry)
        action:mousepressed(entry.x + 2, entry.y + 2, 1)
        action:mousereleased(entry.x + 2, entry.y + 2, 1)
    end
    click(roster.entries[1])
    assert(action.selectedId == ids[1] and s.agentView.selected == ids[1] and selectionPlays == 1)
    action:update(0.03)
    click(roster.entries[1])
    assert(selectionPlays == 1 and action.portraitAge == 0.03)
    assert(action.portrait.names[ids[1]] == require("data.agents.index").refresh().byId[ids[1]].name)
    assert(action.portrait.images[ids[1]] and action.portrait.size == 176)
    assert(action.portrait.x > grid.bounds.x + grid.bounds.width and action.portrait.x % 1 == 0
        and action.portrait.y % 1 == 0)
    click(roster.entries[2])
    assert(action.selectedId == ids[2] and selectionPlays == 2 and action.portraitAge == 0)
    action:mousepressed(0, 0, 2)
    assert(not action.selectedId and not s.agentView.selected and not action.portraitAge)
    s.agentView:clearHover()
    click(s.agentView.byId[ids[1]])
    assert(action.selectedId == ids[1])
    action:pointermoved(nil, nil)
    assert(s.agentView:hit(s.agentView.byId[ids[1]].x + 45, s.agentView.byId[ids[1]].y + 25).id == ids[1])
    local startPose = action.portrait:revealPose(action.portraitAge)
    assert(startPose.height == 1 and startPose.nameAlpha == 0)
    render("agent_portrait_reveal_start.png")
    action:update(0.04)
    local middle = action.portrait:revealPose(action.portraitAge)
    assert(middle.height > 1 and middle.height < 176 and middle.nameAlpha == 0
        and middle.y % 1 == 0)
    render("agent_portrait_reveal_mid.png")
    action:update(0.05)
    assert(action.portrait:revealPose(action.portraitAge).nameAlpha > 0
        and action.portrait:revealPose(action.portraitAge).nameAlpha < 1)
    action:update(0.04)
    assert(action.portrait:revealPose(action.portraitAge).height == 176
        and action.portrait:revealPose(action.portraitAge).nameAlpha == 1)
    render("mission_action_selected.png")
    -- An attempted drag, empty click, and canceled Act click do not move agents or execute actions.
    action:mousepressed(first.x + 2, first.y + 2, 1)
    action:pointermoved(640, 180)
    action:mousereleased(640, 180, 1)
    action:mousepressed(10, 10, 1)
    action:mousereleased(10, 10, 1)
    action:mousepressed(action.panel.x + 2, action.panel.y + 2, 1)
    action:mousereleased(nil, nil, 1)
    assert(machine.current == action and action.selectedId == ids[1])
    for _, id in ipairs(ids) do assert(model.placements[id] == cell.id) end
    action:mousepressed(roster.entries[2].x + 2, roster.entries[2].y + 2, 1)
    action:focus(false)
    action:mousereleased(roster.entries[2].x + 2, roster.entries[2].y + 2, 1)
    assert(action.selectedId == ids[1])
    local beforeUpdate = scene.entranceTime
    action:update(0.25)
    assert(readyPlays == 1 and selectionPlays == 3)
    assert(math.abs(scene.entranceTime - (beforeUpdate + 0.25)) < 0.00001)
    local panel, portrait = action.panel, action.portrait
    -- Missing full portraits use a placeholder without changing selection.
    local originalImage = portrait.images[ids[1]]
    portrait.images[ids[1]] = nil
    action:draw()
    portrait.images[ids[1]] = originalImage
    machine:change("mission_preparation")
    assert(not action.session and next(portrait.images) == nil and next(panel.images) == nil and not roster.entries[1].image
        and not scene.parallax and next(art.images) == nil and next(audio.sources) == nil)
    -- Leaving during the fade releases the retained Ready artwork and full portraits.
    assert(prep:deploy())
    deploy:update(2)
    local validCell
    for id in pairs(deploy.assignments) do validCell = id; break end
    for _, id in ipairs(deploy.package.agentIds) do deploy.agentDeployment:assign(id, validCell) end
    deploy.agentView:refresh()
    assert(deploy:beginAction())
    local retainedReady, retainedPortrait = action.oldReady, action.portrait
    action:update(0.04)
    machine:change("mission_preparation")
    assert(next(retainedReady.images) == nil and next(retainedPortrait.images) == nil)
    prep:exit()
    canvas:release()
end
