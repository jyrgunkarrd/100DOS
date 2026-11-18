return function(prefix)
    local Defaults = require(prefix .. "defaults")
    local Parser = require(prefix .. "parser")
    local Layout = require(prefix .. "layout")
    local Files = require(prefix .. "files")
    local Export = require(prefix .. "export")
    local utf8 = require("utf8")
    local palette, sourcePath, selected
    local columns, swatchSize = Defaults.columns, Defaults.swatchSize
    local output, status = "", "Drop a text palette here, or pass its path when launching."
    local outputFocused, outputSelected = false, false
    local scroll, buttons = 0, {}
    local font

    local function report(message)
        status = message
        print(message)
    end

    local function parseOptions(arguments)
        local options = {}
        local index = 1
        while index <= #arguments do
            local value = arguments[index]
            if value == "--help" then
                options.help = true
            elseif value == "--palette" then
                if arguments[index + 1] and arguments[index + 1]:sub(1, 2) ~= "--" then
                    index = index + 1
                    options.input = arguments[index]
                end
            elseif value == "--export" or value == "--columns" or value == "--swatch" then
                index = index + 1
                if not arguments[index] or arguments[index]:sub(1, 2) == "--" then
                    return options, "Missing value for " .. value
                end
                options[value:sub(3)] = arguments[index]
            elseif value:sub(1, 1) == "-" then
                return options, "Unknown option: " .. value
            elseif not options.input then
                options.input = value
            else
                return options, "Unexpected argument: " .. value
            end
            index = index + 1
        end
        for _, setting in ipairs({ { "columns", Defaults.maxColumns }, { "swatch", Defaults.maxSwatchSize } }) do
            local name, maximum = setting[1], setting[2]
            if options[name] then
                local number = tonumber(options[name])
                if not number or number ~= math.floor(number) or number < 1 or number > maximum then
                    return options, "--" .. name .. " must be an integer from 1 to " .. maximum .. "."
                end
                options[name] = number
            end
        end
        return options
    end

    local function loadFile(path)
        local absolute = Files.absolute(path)
        local text, message = Files.read(absolute)
        if not text then report(message); return false end
        local replacement, parseError = Parser.parse(text)
        if not replacement then report(parseError); return false end
        if absolute ~= sourcePath then output = Files.defaultOutput(absolute) end
        palette, sourcePath, selected = replacement, absolute, 1
        scroll = 0
        report(string.format("Loaded %d entries, %d unique colors, %d duplicates.",
            palette.entryCount, #palette.entries, palette.duplicateCount))
        return true
    end

    local function exportPalette()
        if not palette then report("Load a valid palette before exporting."); return false end
        local layout, message = Layout.create(#palette.entries, columns, swatchSize, Defaults.maxPixels)
        if not layout then report(message); return false end
        if not output:match("%S") then report("Enter an output filename."); return false end
        local path = Files.absolute(output)
        local ok, saved, failure = pcall(Export.save, palette, layout, path, sourcePath)
        if not ok then report("Export failed: " .. tostring(saved)); return false end
        if not saved then report(failure); return false end
        report(string.format("Saved %d x %d PNG with %d colors to %s",
            layout.width, layout.height, #palette.entries, path))
        return true
    end

    local function gridGeometry()
        local width, height = love.graphics.getDimensions()
        local cell = math.min(swatchSize, math.floor((width - 48) / columns))
        local availableHeight = height - 310
        local rows = palette and math.ceil(#palette.entries / columns) or 0
        local maxScroll = math.max(0, rows * cell - availableHeight)
        scroll = math.max(0, math.min(scroll, maxScroll))
        return cell, availableHeight
    end

    function love.load(arguments)
        local options, optionsError = parseOptions(arguments or {})
        local batch = options.export ~= nil
        if options.help then
            print('Palette Builder\n  love . --palette "colors.txt" [--columns 10] [--swatch 48]\n'
                .. '  love . --palette "colors.txt" --export "colors.png"\n'
                .. '  love tools/palette "colors.txt"\n'
                .. 'Paths resolve from the command working directory. Export replaces the destination PNG.')
            love.event.quit(0)
            return
        end
        if optionsError then
            report(optionsError)
            love.event.quit(1)
            return
        end
        columns = options.columns or columns
        swatchSize = options.swatch or swatchSize
        font = love.graphics.newFont(15)
        love.graphics.setFont(font)
        if options.input then
            if not loadFile(options.input) and batch then love.event.quit(1); return end
        end
        if options.export then
            output = options.export
            love.event.quit(exportPalette() and 0 or 1)
        end
    end

    local function copyColor()
        if palette and selected then
            love.system.setClipboardText(palette.entries[selected].hex)
            report("Copied " .. palette.entries[selected].hex)
        end
    end

    local function reload()
        if sourcePath then loadFile(sourcePath) else report("Drop a text file to load a palette.") end
    end

    local function button(label, x, y, width, action)
        local g = love.graphics
        local mouseX, mouseY = love.mouse.getPosition()
        local hovered = mouseX >= x and mouseX < x + width and mouseY >= y and mouseY < y + 32
        g.setColor(hovered and 0.26 or 0.19, hovered and 0.30 or 0.22, hovered and 0.34 or 0.26)
        g.rectangle("fill", x, y, width, 32, 4, 4)
        g.setColor(0.94, 0.95, 0.97)
        g.printf(label, x, y + 7, width, "center")
        buttons[#buttons + 1] = { x = x, y = y, width = width, action = action }
    end

    function love.draw()
        if not font then return end
        local g = love.graphics
        local width, height = g.getDimensions()
        g.clear(0.075, 0.085, 0.10)
        g.setColor(0.94, 0.95, 0.97)
        g.print("Palette Builder", 24, 18)
        g.setColor(0.65, 0.70, 0.75)
        local heading = sourcePath and (sourcePath:match("[^/]+$") .. "    " .. sourcePath)
            or "Drop a .txt file to begin"
        g.setScissor(24, 43, width - 48, 22)
        g.print(heading, 24, 43)
        g.setScissor()
        buttons = {}
        button("Reload", 24, 78, 80, reload)
        button("Copy hex", 112, 78, 90, copyColor)
        button("Export PNG", 210, 78, 112, exportPalette)
        g.setColor(0.8, 0.83, 0.87)
        g.print("Columns " .. columns, 344, 86)
        button("-", 445, 78, 32, function() columns = math.max(1, columns - 1) end)
        button("+", 483, 78, 32, function() columns = math.min(Defaults.maxColumns, columns + 1) end)
        g.setColor(0.8, 0.83, 0.87)
        g.print("Swatch " .. swatchSize .. " px", 536, 86)
        button("-", 654, 78, 32, function() swatchSize = math.max(1, swatchSize - 1) end)
        button("+", 692, 78, 32, function() swatchSize = math.min(Defaults.maxSwatchSize, swatchSize + 1) end)
        local cell, availableHeight = gridGeometry()
        if palette then
            local entry = palette.entries[selected]
            g.setColor(0.8, 0.83, 0.87)
            g.print(string.format("%d entries / %d unique / %d duplicates     Selected %s (line %d)",
                palette.entryCount, #palette.entries, palette.duplicateCount, entry.hex, entry.line), 24, 124)
            local layout, message = Layout.create(#palette.entries, columns, swatchSize, Defaults.maxPixels)
            g.setScissor(24, 150, width - 48, availableHeight)
            local rows = math.ceil(#palette.entries / columns)
            local firstRow = math.max(0, math.floor(scroll / cell))
            local lastRow = math.min(rows - 1, math.floor((scroll + availableHeight) / cell))
            local previewLayout = { columns = columns, count = #palette.entries }
            for row = firstRow, lastRow do
                for column = 0, columns - 1 do
                    local index = Layout.entryAt(previewLayout, column, row)
                    local color = palette.entries[index]
                    g.setColor(color.r / 255, color.g / 255, color.b / 255)
                    g.rectangle("fill", 24 + column * cell, 150 + row * cell - scroll, cell, cell)
                end
            end
            local column = (selected - 1) % columns
            local row = math.floor((selected - 1) / columns)
            g.setLineWidth(1)
            g.setColor(0, 0, 0)
            g.rectangle("line", 24 + column * cell + 0.5, 150 + row * cell - scroll + 0.5, cell - 1, cell - 1)
            g.setColor(1, 1, 1)
            if cell > 4 then
                g.rectangle("line", 24 + column * cell + 1.5, 150 + row * cell - scroll + 1.5, cell - 3, cell - 3)
            end
            g.setScissor()
            g.setColor(0.65, 0.70, 0.75)
            local details = layout and string.format("Export %d x %d px. Final row repeats the last color to fill empty cells.", layout.width, layout.height) or message
            g.print(details, 24, height - 146)
        end
        g.setColor(0.8, 0.83, 0.87)
        g.print("Output PNG (existing file will be replaced)", 24, height - 122)
        g.setColor(outputFocused and 0.20 or 0.13, 0.17, 0.21)
        g.rectangle("fill", 24, height - 98, width - 48, 30, 3, 3)
        g.setScissor(30, height - 96, width - 60, 26)
        if outputFocused and outputSelected then
            g.setColor(0.25, 0.42, 0.56)
            g.rectangle("fill", 30, height - 96, width - 60, 26)
        end
        g.setColor(0.94, 0.95, 0.97)
        local textWidth = font:getWidth(output)
        g.print(output .. (outputFocused and "|" or ""),
            30 - math.max(0, textWidth - (width - 76)), height - 92)
        g.setScissor()
        g.setColor(0.80, 0.85, 0.88)
        g.setScissor(24, height - 60, width - 48, 52)
        g.printf(status, 24, height - 60, width - 48)
        g.setScissor()
    end

    function love.mousepressed(x, y, mouseButton)
        if mouseButton ~= 1 then return end
        local width, height = love.graphics.getDimensions()
        outputFocused = x >= 24 and x < width - 24 and y >= height - 98 and y < height - 68
        outputSelected = false
        love.keyboard.setTextInput(outputFocused)
        for _, control in ipairs(buttons) do
            if x >= control.x and x < control.x + control.width and y >= control.y and y < control.y + 32 then
                control.action()
                return
            end
        end
        local cell, availableHeight = gridGeometry()
        if palette and x >= 24 and x < 24 + columns * cell and y >= 150 and y < 150 + availableHeight then
            local index = math.floor((y - 150 + scroll) / cell) * columns + math.floor((x - 24) / cell) + 1
            if index <= #palette.entries then selected = index end
        end
    end

    function love.wheelmoved(_, y)
        scroll = scroll - y * 48
        gridGeometry()
    end

    function love.filedropped(file)
        local path = file:getFilename()
        file:close()
        loadFile(path)
    end

    local function insertText(text)
        text = text:gsub("[%z\1-\31]", "")
        if outputSelected then output = "" end
        outputSelected = false
        output = output .. text
    end

    function love.textinput(text)
        if outputFocused then insertText(text) end
    end

    function love.keypressed(key)
        local control = love.keyboard.isDown("lctrl", "rctrl", "lgui", "rgui")
        if outputFocused then
            if control and key == "a" then outputSelected = true
            elseif control and key == "c" and outputSelected then love.system.setClipboardText(output)
            elseif control and key == "v" then insertText(love.system.getClipboardText())
            elseif key == "backspace" or key == "delete" then
                if outputSelected then output = ""
                elseif key == "backspace" then
                    local last = utf8.offset(output, -1)
                    if last then output = output:sub(1, last - 1) end
                end
                outputSelected = false
            elseif key == "return" or key == "escape" or key == "tab" then
                outputFocused, outputSelected = false, false
                love.keyboard.setTextInput(false)
            end
            return
        end
        if key == "r" then reload()
        elseif key == "e" then exportPalette()
        elseif control and key == "c" then copyColor()
        elseif key == "tab" then
            outputFocused, outputSelected = true, true
            love.keyboard.setTextInput(true)
        elseif key == "escape" then love.event.quit() end
    end
end
