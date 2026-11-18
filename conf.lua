function love.conf(t)
    for _, argument in ipairs(arg or {}) do
        if argument == "--palette" then
            require("tools.palette.configure")(t)
            return
        end
    end

    t.identity = "100-days-of-sin"

    t.window.title = "100 Days of Sin"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 180
    t.window.highdpi = true
    t.window.vsync = 1
end
