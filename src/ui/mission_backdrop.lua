local Backdrop = {}
local resources = { "reinforcementView", "phaseFeedbackView", "silencerView", "parallax", "jaclPreview", "captainPanel", "accents" }

function Backdrop.escalate(scene)
    return scene.parallax:activateDoom()
end

function Backdrop.update(scene, dt)
    scene.entranceTime = scene.entranceTime + math.max(0, dt)
    scene.accents:update(dt)
    scene.parallax:update(dt)
    scene.jaclPreview:update(dt)
    if scene.silencerView then scene.silencerView:update(dt) end
end

function Backdrop.draw(scene)
    scene.parallax:draw()
    scene.jaclPreview:draw()
    if scene.silencerView then scene.silencerView:draw() end
    scene.captainPanel:draw(scene.entranceTime)
end

-- Move ownership before preparation exits, preserving animation and assets.
function Backdrop.take(source)
    local scene = { biome = source.biome, entranceTime = source.entranceTime }
    for _, key in ipairs(resources) do
        scene[key], source[key] = source[key], nil
    end
    return scene
end

function Backdrop.release(scene)
    for _, key in ipairs(resources) do
        if scene[key] then scene[key]:release(); scene[key] = nil end
    end
end

return Backdrop
