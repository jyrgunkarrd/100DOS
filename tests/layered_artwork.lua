return function(write)
    local Resolver = require("src.sys.artwork_resolver")
    local Assets = require("src.sys.artwork_assets")
    local Artwork = require("src.ui.layered_artwork")
    local inherited = Resolver.resolve({}, "the_cut")
    assert(inherited.background == "assets/images/biomes/the_cut/portrait_bg.png")
    assert(inherited.foreground == "assets/images/biomes/the_cut/portrait_fg.png")
    local mixed = Resolver.resolve({ card_bg = "thief_bg", card_fg = "none" }, "the_cut")
    assert(mixed.background == "assets/images/biomes/thief_bg.png" and mixed.foreground == nil)
    mixed = Resolver.resolve({ card_bg = "none" }, "roswell_shallows")
    assert(mixed.background == nil and mixed.foreground == "assets/images/biomes/roswell_shallows/portrait_fg.png")
    assert(Resolver.resolve({ card_fg = "nil" }, "the_cut").foreground == "assets/images/biomes/nil.png")
    for _, bad in ipairs({ false, 2, {}, "", "../escape", "file.png" }) do
        assert(not pcall(Resolver.resolve, { id = "bad", card_bg = bad }, "the_cut"))
    end
    local door = require("data.loc_cards.barriers.security_door")
    local disabled = Resolver.resolve(door, "the_cut")
    assert(not disabled.background and not disabled.foreground)

    -- Shared ownership, failed-load deduplication, and final-owner cleanup.
    local original, loads, releases = love.graphics.newImage, 0, 0
    love.graphics.newImage = function(path)
        loads = loads + 1
        if path == "missing" then error("missing image") end
        return { setFilter = function() end, release = function() releases = releases + 1 end }
    end
    local a, b = Assets.new(), Assets.new()
    local ok, failure = pcall(function()
        local image = a:load("shared")
        assert(a:load("shared") == image and b:load("shared") == image and loads == 1)
        assert(not a:load("missing") and not a:load("missing") and loads == 2 and #a.diagnostics == 1)
        assert(not b:load("missing") and loads == 2)
        a:release(); a:release()
        assert(releases == 0)
        b:release()
        assert(releases == 1)
        a:load("shared")
        assert(loads == 3)
    end)
    a:release(); b:release(); love.graphics.newImage = original
    assert(ok, failure)

    -- Pixel evidence for order, transparency, transformed clipping, and state restoration.
    local g = love.graphics
    local function image(color, first, last)
        local data = love.image.newImageData(4, 4)
        for x = first, last do for y = 0, 3 do data:setPixel(x, y, unpack(color)) end end
        local result = g.newImage(data); data:release(); result:setFilter("nearest", "nearest")
        return result
    end
    local bg, subject, fg = image({1,0,0,1},0,3), image({0,1,0,1},1,2), image({0,0,1,1},2,2)
    local canvas = g.newCanvas(12, 8)
    g.push("all"); g.setCanvas(canvas); g.clear(0,0,0,1); g.origin()
    g.translate(2,2); g.setScissor(2,2,3,4)
    Artwork.draw({ background = bg, foreground = fg }, 0,0,4,4, function()
        g.setColor(1,1,1,1); g.draw(subject)
    end)
    local sx, sy, sw, sh = g.getScissor()
    assert(sx == 2 and sy == 2 and sw == 3 and sh == 4)
    g.pop()
    local pixels = canvas:newImageData()
    local r, green, blue = pixels:getPixel(2,3); assert(r > .99 and green < .01 and blue < .01)
    r, green, blue = pixels:getPixel(3,3); assert(green > .99 and r < .01)
    r, green, blue = pixels:getPixel(4,3); assert(blue > .99 and green < .01)
    r, green, blue = pixels:getPixel(5,3); assert(r == 0 and green == 0 and blue == 0)
    pixels:release(); canvas:release()

    -- Neither larger nor smaller artwork slots resize decorations. The
    -- composition expands around native layers, retaining the caller's clip.
    local fitted = g.newCanvas(16, 8)
    g.push("all"); g.setCanvas(fitted); g.origin(); g.setScissor(); g.clear(0,0,0,1)
    Artwork.draw({ background = bg, foreground = fg }, 0,0,8,8, function() end)
    Artwork.draw({ background = bg, foreground = fg }, 10,0,2,8, function() end)
    g.pop()
    pixels = fitted:newImageData()
    local function pixel(x, y, red, blue)
        local r, green, b = pixels:getPixel(x,y)
        assert(r == red and green == 0 and b == blue, "Unexpected layer fit at " .. x .. "," .. y)
    end
    pixel(2,1,0,0); pixel(1,2,0,0); pixel(2,2,1,0)
    pixel(4,2,0,1); pixel(5,5,1,0); pixel(6,5,0,0); pixel(2,6,0,0)
    pixel(9,1,0,0); pixel(9,2,1,0); pixel(11,2,0,1)
    pixel(12,5,1,0); pixel(13,5,0,0); pixel(9,6,0,0)
    pixels:release(); fitted:release(); bg:release(); subject:release(); fg:release()

    -- Real preview integration: inherited agent art, custom card art, and disabled location layers.
    local Preview = require("src.ui.card_preview")
    local Theme = require("data.preparation_theme")
    local fonts = { heading = g.newFont(Theme.headingFont, Theme.headingSize), small = g.newFont(Theme.smallFont, Theme.smallSize) }
    local views = {}
    local function preview(def, id, settings, normalize)
        local view = Preview.new({ byId = { [id] = def } }, {{ cardId = id }}, settings, fonts,
            { bounds = { x = 0, width = 304 } }, 720, normalize, "the_cut")
        views[#views + 1] = view
        view.x = (#views - 1) * 304 + 8; view:show(id)
        return view
    end
    local settings = require("data.agent_preview_view")
    local agent = preview(require("data.agents.wick"), "wick", settings,
        function(d) return require("src.sys.agent_display").normalize(d, settings) end)
    local card = preview(require("data.cards.shadow.catburglar"), "catburglar", require("data.card_preview_view"))
    local location = preview(door, "security_door", require("data.location_card_preview_view"), require("src.sys.location_card_display").normalize)
    assert(agent.artwork.wick.background and agent.artwork.wick.foreground)
    assert(card.artwork.catburglar.background and card.artwork.catburglar.foreground)
    assert(not location.artwork.security_door.background and not location.artwork.security_door.foreground)
    local screen = g.newCanvas(912,720)
    g.push("all"); g.setCanvas(screen); g.origin(); g.setScissor(); g.clear(.06,.06,.06,1)
    for _, view in ipairs(views) do view:draw() end
    g.pop()
    local rendered = screen:newImageData()
    write("layered_artwork.png", rendered:encode("png"):getString())
    rendered:release(); screen:release()
    for _, view in ipairs(views) do view:release() end
    fonts.heading:release(); fonts.small:release()
end
