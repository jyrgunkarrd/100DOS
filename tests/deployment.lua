return function(write)
    require("tests.deployment_ready")()
    require("tests.audio_overlap")()
    require("tests.location_board")()
    local Machine = require("src.states.state_machine")
    local Preparation = require("src.states.mission_preparation")
    local Deployment = require("src.states.mission_deployment")
    local Grid = require("src.ui.hex_grid")
    local settings = require("data.deployment_board")
    local grid = Grid.new(settings, 1280, 360)
    local columns = {}
    for _, cell in ipairs(grid.cells) do
        columns[cell.q] = (columns[cell.q] or 0) + 1
        for i = 1, #cell.vertices, 2 do
            assert(cell.vertices[i] > 0 and cell.vertices[i] < 1280)
            assert(cell.vertices[i + 1] > 0 and cell.vertices[i + 1] < 360)
        end
    end
    assert(columns[-2] == 1 and columns[-1] == 2 and columns[0] == 3
        and columns[1] == 2 and columns[2] == 1)
    local invalid = {}
    for key, value in pairs(settings) do invalid[key] = value end
    invalid.radius = 500
    assert(not pcall(Grid.new, invalid, 1280, 360))
    invalid.radius = settings.radius
    invalid.cells = {}
    for i, location in ipairs(settings.cells) do invalid.cells[i] = location end
    invalid.cells[9] = invalid.cells[1]
    assert(not pcall(Grid.new, invalid, 1280, 360))

    local machine = Machine.new()
    local preparation = Preparation.new(machine, 1280, 720)
    local deployment = Deployment.new(machine, 1280, 720)
    machine:register("mission_preparation", preparation)
    machine:register("mission_deployment", deployment)
    machine:change("mission_preparation")
    preparation:update(0.5)
    local audio, deployPlays = preparation.audio, 0
    assert(audio.sources.deploy and #audio.diagnostics == 0)
    local actualPlay = audio.play
    audio.play = function(self, id)
        if id == "deploy" then deployPlays = deployPlays + 1 end
        return actualPlay(self, id)
    end
    local button = preparation.buttons[1]
    local x, y = button.x + 2, button.y + 2
    preparation:mousepressed(x, y, 1)
    preparation:mousereleased(nil, nil, 1)
    assert(machine.current == preparation)
    preparation:mousepressed(x, y, 1)
    preparation:focus(false)
    preparation:mousereleased(x, y, 1)
    assert(machine.current == preparation)
    local package, parallax, jacl, captain, accents = preparation.package, preparation.parallax,
        preparation.jaclPreview, preparation.captainPanel, preparation.accents
    local originalLoad = love.filesystem.load
    local selectedAgent = preparation.agents.byId[package.agentIds[1]]
    local originalFate = selectedAgent.fate
    selectedAgent.fate = { "unknown_test_tile" }
    assert(not preparation:deploy())
    assert(machine.current == preparation and preparation.package == package
        and preparation.parallax == parallax and not deployment.fatePool)
    assert(preparation.deployError:find("unknown_test_tile", 1, true))
    selectedAgent.fate = originalFate
    love.filesystem.load = function(path)
        if path == "data/deployment_board.lua" then return function() return {} end end
        return originalLoad(path)
    end
    assert(not preparation:deploy())
    love.filesystem.load = originalLoad
    assert(machine.current == preparation and preparation.package == package
        and preparation.parallax == parallax and preparation.entranceTime == 0.5)
    local originalPool = preparation.biome.loc_pool
    preparation.biome.loc_pool = { "unknown_test_location" }
    assert(not preparation:deploy())
    assert(machine.current == preparation and preparation.parallax == parallax)
    preparation.biome.loc_pool = originalPool
    local elapsed, position = jacl.elapsed, jacl.x
    assert(deployPlays == 0)
    preparation:mousepressed(x, y, 1)
    preparation:mousereleased(x, y, 1)
    assert(machine.current == deployment and #deployment.grid.cells == 9)
    assert(#deployment.fatePool.entries == 20)
    assert(deployment.audio == audio and audio.sources.deploy and deployPlays == 1)
    assert(not preparation.buttons and not preparation.agentRoster and not preparation.audio)
    assert(not preparation.parallax and not preparation.accents and button.base)
    assert(deployment.scene.parallax == parallax and deployment.scene.jaclPreview == jacl
        and deployment.scene.captainPanel == captain and deployment.scene.accents == accents)
    assert(deployment.scene.entranceTime == 0.5 and jacl.elapsed == elapsed and jacl.x == position)
    assert(deployment.package ~= package and deployment.package.agentIds ~= package.agentIds)
    assert(deployment.package.biomeId == package.biomeId
        and table.concat(deployment.package.agentIds) == table.concat(package.agentIds))
    local roster = deployment.roster
    assert(roster.width == 166 and roster.height == 108 and #roster.diagnostics == 0)
    assert(roster.x >= 0 and roster.x + roster.width <= deployment.grid.bounds.x - 32)
    assert(roster.y == 126 and roster.x + roster.width <= 1280)
    for i, entry in ipairs(roster.entries) do
        assert(entry.id == package.agentIds[i] and entry.image and entry.scale == 1)
        assert(entry.x == roster.x + ((i - 1) % 3) * 58)
        assert(entry.y == roster.y + math.floor((i - 1) / 3) * 58)
    end
    local Roster = require("src.ui.deployment_roster")
    local fallback = Roster.new({ "missing_test", "apex", "b6", "mam", "wick", "tomorrow" },
        deployment.grid.bounds, 1280, 360)
    assert(#fallback.diagnostics == 1 and not fallback.entries[1].image and fallback.entries[2].image)
    fallback:draw()
    fallback:release()
    local originalNewImage = love.graphics.newImage
    local wide = love.image.newImageData(100, 25)
    love.graphics.newImage = function() return originalNewImage(wide) end
    local fitOk, fitted = pcall(Roster.new, package.agentIds, deployment.grid.bounds, 1280, 360)
    love.graphics.newImage = originalNewImage
    wide:release()
    assert(fitOk, fitted)
    assert(fitted.entries[1].scale == 0.5 and fitted.entries[1].drawX == fitted.x
        and fitted.entries[1].drawY == fitted.y + 18.75)
    fitted:release()
    local assignments, art = deployment.assignments, deployment.art
    local assignedCount, eligible, assignedIds = 0, {}, {}
    for _, id in ipairs(originalPool) do eligible[id] = true end
    eligible["loc_" .. package.jaclId] = true
    assert(assignments.center == "loc_" .. package.jaclId)
    for _, id in pairs(assignments) do
        assert(eligible[id] and not assignedIds[id])
        assignedIds[id] = true
        assignedCount = assignedCount + 1
    end
    assert(assignedCount == 1 + math.min(8, #originalPool))
    machine:dispatch("mousereleased", x, y, 1)
    machine:dispatch("mousepressed", x, y, 1)
    machine:dispatch("update", 2)
    assert(deployPlays == 1 and not button.base and not deployment.transition)
    assert(deployment.assignments == assignments)
    assert(jacl.elapsed > elapsed and deployment.scene.entranceTime == 2.5)
    local canvas = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setScissor(0, 0, 1280, 720)
    deployment:draw()
    local sx, sy, sw, sh = love.graphics.getScissor()
    assert(sx == 0 and sy == 0 and sw == 1280 and sh == 720)
    love.graphics.setScissor()
    love.graphics.setCanvas()
    local pixels = canvas:newImageData()
    write("deployment_board.png", pixels:encode("png"):getString())
    pixels:release()
    canvas:release()
    machine:change("mission_preparation")
    assert(not deployment.audio and next(audio.sources) == nil)
    assert(not deployment.scene and not deployment.grid and not jacl.image and not accents.heading)
    assert(next(art.images) == nil and next(art.meshes) == nil and not deployment.art)
    assert(not deployment.roster)
    assert(not deployment.fatePool)
    for _, entry in ipairs(roster.entries) do assert(not entry.image) end
    assert(preparation.package ~= package)
    preparation:exit()
    require("tests.deployment_transition")(write)
    require("tests.agent_deployment")(write)
    require("tests.mission_action")(write)
    require("tests.agent_action")(write)
end
