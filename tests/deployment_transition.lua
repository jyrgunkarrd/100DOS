return function(write)
    local Machine = require("src.states.state_machine")
    local Preparation = require("src.states.mission_preparation")
    local Deployment = require("src.states.mission_deployment")
    local settings = require("data.deployment_transition")
    local machine = Machine.new()
    local prep = Preparation.new(machine, 1280, 720)
    local deployed = Deployment.new(machine, 1280, 720)
    machine:register("mission_preparation", prep)
    machine:register("mission_deployment", deployed)
    machine:change("mission_preparation")
    prep:update(0.8)
    local soundCounts = { agentDeploy = 0, hexDeploy = 0 }
    local audio = prep.audio
    assert(audio.sources.agentDeploy and audio.sources.hexDeploy)
    local playOverlap = audio.playOverlapping
    audio.playOverlapping = function(self, id)
        soundCounts[id] = soundCounts[id] + 1
        return playOverlap(self, id)
    end
    local source, buttons = prep.agentRoster, prep.buttons
    local firstImage = source.entries[1].image
    local oldTime = prep.entranceTime
    local originalLoad = love.filesystem.load
    love.filesystem.load = function(path)
        if path == "data/deployment_transition.lua" then
            return function()
                local invalid = {}
                for k, v in pairs(settings) do invalid[k] = v end
                invalid.groups = { { "west", "west" } }
                return invalid
            end
        end
        return originalLoad(path)
    end
    assert(not prep:deploy())
    love.filesystem.load = originalLoad
    assert(machine.current == prep and prep.agentRoster == source and source.entries[1].image == firstImage
        and prep.entranceTime == oldTime and prep.buttons == buttons)
    assert(prep:deploy())
    assert(soundCounts.agentDeploy == 1 and soundCounts.hexDeploy == 0)
    local t = deployed.transition
    assert(t.sourceRoster == source and t.buttons == buttons and not prep.agentRoster and not prep.buttons)
    local expected = { "west", "southwest", "south", "southeast", "east", "northwest", "center", "northeast", "north" }
    for i, cell in ipairs(t.order) do
        assert(cell.id == expected[i] and not t:cellPose(cell).visible)
    end
    assert(t.drops.west.start == settings.agentDuration)
    assert(t.drops.northwest.start > t.drops.east.start + settings.dropDuration)
    assert(t.drops.north.start > t.drops.northeast.start + settings.dropDuration)
    local pose = t:agentPose(1)
    assert(pose.x == source.entries[1].x and pose.y == source:entrancePose(1, oldTime).y
        and pose.size == source.config.portraitSize and pose.blend == 0)
    local duration = t.duration
    local assignments = deployed.assignments
    -- Input during the sequence cannot reroll, replay, or replace deployment.
    machine:dispatch("mousepressed", buttons[2].x + 2, buttons[2].y + 2, 1)
    machine:dispatch("mousereleased", buttons[2].x + 2, buttons[2].y + 2, 1)
    assert(deployed.assignments == assignments and deployed.transition == t)
    local canvas = love.graphics.newCanvas(1280, 720)
    local previous = 0
    local samples = { 0, 0.06, 0.20, 0.35, 0.50, 0.72, 0.90, 1.01, 1.20 }
    for i, time in ipairs(samples) do
        deployed:update(time - previous)
        previous = time
        local landed = 0
        for _, drop in pairs(t.drops) do
            if deployed.elapsed >= drop.start + settings.dropDuration then landed = landed + 1 end
        end
        assert(soundCounts.agentDeploy == 1 and soundCounts.hexDeploy == landed)
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        love.graphics.setScissor(0, 0, 1280, 720)
        deployed:draw()
        local x, y, w, h = love.graphics.getScissor()
        assert(x == 0 and y == 0 and w == 1280 and h == 720)
        love.graphics.setScissor()
        love.graphics.setCanvas()
        local pixels = canvas:newImageData()
        write("deployment_transition_" .. i .. ".png", pixels:encode("png"):getString())
        pixels:release()
        if time <= duration then assert(deployed:promptAlpha() == 0) end
        if time >= settings.fadeDuration then assert(not buttons[1].base and not t.buttons) end
        if time >= settings.agentDuration then assert(not source.entries[1].image and not t.sourceRoster) end
        if time == 0.35 then
            local final = t:agentPose(1)
            assert(final.x == deployed.roster.entries[1].x and final.y == deployed.roster.entries[1].y
                and final.size == 50 and final.blend == 1)
        end
    end
    assert(not deployed.transition and duration < 1.21 and deployed.assignments == assignments)
    deployed:update(0.075)
    assert(deployed:promptAlpha() > 0 and deployed:promptAlpha() < 1)
    deployed:update(0.15)
    assert(deployed:promptAlpha() == 1 and soundCounts.hexDeploy == 9)
    canvas:release()

    -- An early Deploy starts from the current entrance pose, including offscreen agents.
    machine:change("mission_preparation")
    prep:update(0.1)
    local earlySource = prep.agentRoster
    local earlyY = earlySource:entrancePose(6, prep.entranceTime).y
    local earlyButtons = prep.buttons
    assert(prep:deploy())
    assert(deployed.transition:agentPose(6).y == earlyY and earlyY < 0)
    deployed:update(0.06)
    -- Mid-animation exit releases temporary and destination resources.
    local mini = deployed.roster
    machine:change("mission_preparation")
    assert(not earlySource.entries[1].image and not earlyButtons[1].base and not mini.entries[1].image)
    -- Missing portraits take the same path and a single long frame completes all phases.
    prep.agentRoster.entries[1].image:release()
    prep.agentRoster.entries[1].image = nil
    assert(prep:deploy())
    deployed.roster.entries[1].image:release()
    deployed.roster.entries[1].image = nil
    deployed:update(0.15)
    deployed:draw()
    deployed:update(10)
    assert(not deployed.transition and deployed:promptAlpha() == 1)
    local impacts = 0
    for _ in pairs(deployed.landedCells) do impacts = impacts + 1 end
    assert(impacts == 9)
    deployed:draw()
    deployed:exit()
end
