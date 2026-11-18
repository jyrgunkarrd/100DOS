return function()
    local Generator = require("src.sys.deployment_generator")
    local Art = require("src.ui.location_art")
    local Grid = require("src.ui.hex_grid")
    local settings = require("data.deployment_board")
    local grid = Grid.new(settings, 1280, 360)
    local pool, catalogue = {}, { byId = {} }
    for i = 1, 12 do pool[i] = "location_" .. i; catalogue.byId[pool[i]] = { id = pool[i] } end
    local before = table.concat(pool, ",")
    local a = Generator.generate(pool, catalogue, grid.cells, love.math.newRandomGenerator(123))
    local b = Generator.generate(pool, catalogue, grid.cells, love.math.newRandomGenerator(123))
    local count, seen = 0, {}
    for cell, id in pairs(a) do
        assert(b[cell] == id and not seen[id]); seen[id] = true; count = count + 1
    end
    assert(count == 9 and table.concat(pool, ",") == before)
    assert(next(Generator.generate({}, catalogue, grid.cells)) == nil)
    local visited = {}
    for seed = 1, 100 do
        local single = Generator.generate({ pool[1] }, catalogue, grid.cells, love.math.newRandomGenerator(seed))
        local n = 0
        for cell, id in pairs(single) do assert(id == pool[1]); visited[cell] = true; n = n + 1 end
        assert(n == 1)
    end
    local n = 0
    for _ in pairs(visited) do n = n + 1 end
    assert(n == 9, "Single location should reach every board position")
    local noDraw = { random = function() error("Random draw before validation") end }
    for _, invalid in ipairs({ { "unknown" }, { pool[1], pool[1] }, { [2] = pool[1] } }) do
        local ok, message = pcall(Generator.generate, invalid, catalogue, grid.cells, noDraw)
        assert(not ok and not tostring(message):find("Random draw before validation", 1, true))
    end
    assert(not pcall(Generator.generate, nil, catalogue, grid.cells))

    local actual = Art.new({ center = "red_cathedral" }, grid.cells, settings.artwork)
    assert(actual.images.red_cathedral and #actual.diagnostics == 0)
    actual:release()
    assert(next(actual.images) == nil and next(actual.meshes) == nil)
    local missing = Art.new({ center = "missing_test_location" }, grid.cells, settings.artwork)
    assert(#missing.diagnostics == 1 and missing.assigned.center == "missing_test_location")
    missing:release()

    -- A wide magenta image exposes incorrect fitting, corner leaks, or distortion.
    local pixels = love.image.newImageData(200, 50)
    pixels:mapPixel(function() return 1, 0, 1, 1 end)
    local originalNew = love.graphics.newImage
    love.graphics.newImage = function() return originalNew(pixels) end
    local ok, art = pcall(Art.new, { center = "test" }, grid.cells, settings.artwork)
    love.graphics.newImage = originalNew
    pixels:release()
    assert(ok, art)
    local canvas = love.graphics.newCanvas(1280, 360)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    grid:draw(art)
    love.graphics.setCanvas()
    local output = canvas:newImageData()
    local r, g, b = output:getPixel(640, 180)
    assert(r > 0.99 and g < 0.01 and b > 0.99, "Artwork must fill the center")
    r, g, b = output:getPixel(640, 140)
    assert(r > 0.99 and b > 0.99, "Wide artwork must cover the hex height")
    r, g, b = output:getPixel(590, 138)
    assert(r < 0.1 and g < 0.1 and b < 0.1, "Artwork must not leak into clipped corners")
    output:release(); canvas:release(); art:release()
end
