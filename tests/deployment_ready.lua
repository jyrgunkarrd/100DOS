return function()
    local Ready = require("src.ui.deployment_ready")
    local Model = require("src.sys.agent_deployment")
    local c = require("data.deployment_ready")
    local ready = Ready.new()
    assert(#ready.diagnostics == 0 and ready.width == 178 and ready.height == 42)
    assert(ready.images["false"] and ready.images["true"])
    assert(ready.images["false"]:getFilter() == "nearest")
    local font = love.graphics.newFont(12)
    local prompt = { x = 907, y = 168, textWidth = 267, height = 24, font = font }
    local x, y = ready:layout(prompt)
    assert(x % 1 == 0 and y % 1 == 0 and y == 208)
    assert(math.abs((x + ready.width / 2) - (prompt.x + prompt.textWidth / 2)) <= 0.5)
    assert(ready:alpha(1, 2) == 0 and ready:alpha(2, 2) == 0)
    assert(ready:alpha(2.075, 2) > 0 and ready:alpha(2.075, 2) < 1)
    assert(ready:alpha(3, 2) == 1)
    local actualDraw, calls = love.graphics.draw, {}
    love.graphics.draw = function(image, dx, dy, angle, sx, sy)
        calls[#calls + 1] = image
        assert(dx == x and dy == y and sx == 2 and sy == 2)
    end
    local ok, message = pcall(function()
        ready:draw(prompt, false, 1, 2)
        assert(#calls == 0)
        ready:draw(prompt, false, 3, 2)
        ready:draw(prompt, true, 3, 2)
        assert(calls[1] == ready.images["false"] and calls[2] == ready.images["true"])
    end)
    love.graphics.draw = actualDraw
    assert(ok, message)
    local missingSettings = {}
    for key, value in pairs(c) do missingSettings[key] = value end
    missingSettings.falsePath, missingSettings.truePath = "missing_false.png", "missing_true.png"
    local missing = Ready.new(missingSettings)
    assert(#missing.diagnostics == 2 and missing.width == ready.width)
    missing:draw(prompt, false, 3, 2)
    missing:draw(prompt, true, 3, 2)
    missing:release(); ready:release(); font:release()
    assert(next(ready.images) == nil)
    local model = Model.new({ "a", "b", "c", "d", "e", "f" }, { center = "location" })
    for i, id in ipairs(model.agentIds) do
        assert(model:assign(id, "center"))
        assert(model:allAssigned() == (i == 6))
    end
    assert(model:assign("a", nil) and not model:allAssigned())
    model.placements.a = "invalid"
    assert(not model:allAssigned())
end
