return function(t)
    t.identity = "100-days-of-sin-palette-tool"
    t.window.title = "100 Days of Sin - Palette Builder"
    t.window.width = 1000
    t.window.height = 740
    t.window.minwidth = 800
    t.window.minheight = 480
    t.window.resizable = true
    t.window.highdpi = true
    t.modules.audio = false
    t.modules.physics = false
    t.console = true
    for _, argument in ipairs(arg or {}) do
        if argument == "--export" or argument == "--help" then
            t.window.visible = false
        end
    end
end
