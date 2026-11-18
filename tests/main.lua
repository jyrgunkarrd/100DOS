-- Run from the project directory: love . --test
local jaclOnly = false
for _, argument in ipairs(arg or {}) do if argument == "--jacl-only" then jaclOnly = true end end
local silencerOnly = false
for _, argument in ipairs(arg or {}) do if argument == "--silencer-only" then silencerOnly = true end end
local doomOnly = false
for _, argument in ipairs(arg or {}) do if argument == "--doom-only" then doomOnly = true end end
local root = love.filesystem.getSource()
local routingOnly = false
for _, argument in ipairs(arg or {}) do if argument == "--routing-only" then routingOnly = true end end
local function write(name, contents)
    local file = assert(io.open(root .. "/tests/" .. name, "wb"))
    file:write(contents)
    file:close()
end

function love.load()
    local ok, failure = xpcall(function()
        require("tests.army_routing")(write)
        if routingOnly then return end
        require("tests.card_column_layout")()
        require("tests.location_actions")(write)
        require("tests.clash_reinforcements")(write)
        require("tests.location_control_milling")(write)
        require("tests.phase_end_feedback")(write)
        if silencerOnly then require("tests.silencer_activity")(write); return end
        if not doomOnly and not jaclOnly then require("tests.silencer_activity")(write) end
        if not doomOnly then
            require("tests.jacl_actions")(write)
            require("tests.jacl_ui")(write)
        end
        if jaclOnly then return end
        require("tests.doom_clock")(write)
        if doomOnly then require("tests.talent_tests")(write); return end
        require("tests.target_track")(write)
        require("tests.mission_hunt")(write)
        require("tests.battlefield_comparison")(write)
        require("tests.battlefield")()
        require("tests.battlefield_ui")(write)
        require("tests.battlefield_clashes")(write)
        require("tests.mission_armies")(write)
        require("tests.layered_artwork")(write)
        require("tests.agent_basic_actions")(write)
        require("tests.fate_pool")()
        require("tests.attack_audio")()
        require("tests.talent_tests")(write)
        require("tests.location_cards")()
        require("tests.mission_locations")()
        require("tests.agent_inspection")(write)
        require("tests.agent_observation")(write)
        require("tests.attacks")(write)
        require("tests.location_engagement")()
        require("tests.location_exploration")(write)
        require("tests.location_card_preview")(write)
        local Resolver = require("src.sys.pool_resolver")
        local Generator = require("src.sys.preparation_generator")
        local Index = require("data.biomes.index")
        local Visuals = require("src.sys.biome_visual_catalogue")
        local View = require("src.ui.parallax_view")
        local State = require("src.states.mission_preparation")
        local JaclPreview = require("src.ui.jacl_preview")
        local jacls = require("data.jacls.index").refresh()
        local catalog = Index.refresh()
        local captains = require("data.captains.index").refresh()
        local agents = require("data.agents.index").refresh()
        local agentPool = { source = "agents", ids = "all", count = 6 }
        local catalogs = { biomes = catalog, jacl = jacls, captains = captains, agents = agents }
        local pools = { biome_pool = { source = "biomes", ids = "all" },
            jacl_pool = { source = "jacl", ids = "all" },
            captain_pool = { source = "captains", ids = "all" }, agent_pool = agentPool }
        assert(#catalog.ids == 2)
        local function rejects(callback)
            assert(not pcall(callback), "Expected invalid data to be rejected")
        end
        for _, ids in ipairs({ {}, { "unknown" }, { "the_cut", "the_cut" },
            { [1] = "the_cut", [3] = "roswell_shallows" } }) do
            rejects(function() Resolver.resolve({ source = "biomes", ids = ids }, catalogs) end)
        end
        rejects(function() Resolver.resolve({ source = "missing", ids = "all" }, catalogs) end)
        local first, second = love.math.newRandomGenerator(42), love.math.newRandomGenerator(42)
        local seen = {}
        for _ = 1, 100 do
            local a = Generator.generate(pools, catalogs, first)
            local b = Generator.generate(pools, catalogs, second)
            assert(a.biomeId == b.biomeId and a.jaclId == b.jaclId and a.captainId == b.captainId)
            seen[a.biomeId] = true
            seen[a.jaclId] = true
            seen[a.captainId] = true
            assert(#a.agentIds == 6 and table.concat(a.agentIds, ",") == table.concat(b.agentIds, ","))
            local unique = {}
            for _, id in ipairs(a.agentIds) do
                assert(agents.byId[id] and not unique[id])
                unique[id] = true
            end
        end
        assert(seen.the_cut and seen.roswell_shallows)
        assert(seen.mjolnir and seen.val and seen.saber and seen.saw)
        local restricted = Generator.generate({ biome_pool = { source = "biomes", ids = { "the_cut" } },
            jacl_pool = { source = "jacl", ids = { "val" } },
            captain_pool = { source = "captains", ids = { "saw" } }, agent_pool = agentPool }, catalogs)
        assert(restricted.biomeId == "the_cut" and restricted.jaclId == "val" and restricted.captainId == "saw")
        for _, ids in ipairs({ {}, { "unknown" }, { "val", "val" } }) do
            rejects(function()
                Generator.generate({ biome_pool = pools.biome_pool,
                    jacl_pool = { source = "jacl", ids = ids }, captain_pool = pools.captain_pool, agent_pool = agentPool }, catalogs,
                    { random = function() return 1 end })
            end)
        end
        local draws = 0
        rejects(function()
            Generator.generate({ biome_pool = pools.biome_pool,
                jacl_pool = { source = "jacl", ids = {} }, captain_pool = pools.captain_pool, agent_pool = agentPool }, catalogs,
                { random = function() draws = draws + 1; return 1 end })
        end)
        assert(draws == 0)
        local mockFs = {
            getInfo = function(path) return { type = path:match("%.png$") and "file" or "directory" } end,
            getDirectoryItems = function() return { "1.png", "10.png", "2.png" } end,
        }
        local numeric = Visuals.refresh("test", mockFs)
        assert(numeric.layers[1].number == 10 and numeric.layers[3].number == 1)
        assert(not numeric.background and #numeric.diagnostics == 1)
        local rect = { x = 0, y = 360, width = 1280, height = 360 }
        for _, id in ipairs(catalog.ids) do
            local visuals = Visuals.refresh(id)
            assert(visuals.background and #visuals.diagnostics == 0)
            local view = View.new(visuals, catalog.byId[id].parallax, rect)
            assert(view.layers[1].key == "bg" and view.layers[1].speed == 0)
            assert(view.layers[#view.layers].key == "1")
            view:update(1000.25)
            assert(view.layers[1].offset == 0)
            for _, layer in ipairs(view.layers) do
                assert(layer.offset >= 0 and layer.offset < layer.width)
            end
            local canvas = love.graphics.newCanvas(1280, 720)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(1, 0, 1, 1)
            love.graphics.setColor(0.2, 0.3, 0.4, 1)
            view:draw()
            local red = love.graphics.getColor()
            assert(math.abs(red - 0.2) < 0.001)
            assert(love.graphics.getScissor() == nil)
            love.graphics.setCanvas()
            local pixels = canvas:newImageData()
            local r, g, b = pixels:getPixel(0, 359)
            assert(r == 1 and g == 0 and b == 1, "Preview escaped its rectangle")
            write(id .. ".png", pixels:encode("png"):getString())
            pixels:release()
            canvas:release()
            view:release()
        end
        local missing = Visuals.refresh("missing_biome")
        local fallback = View.new(missing, nil, rect)
        assert(#fallback.layers == 0 and #fallback.diagnostics > 0)
        fallback:update(1)
        fallback:draw()
        fallback:release()
        local noBg = Visuals.refresh("the_cut")
        noBg.background = nil
        local right = View.new(noBg, { direction = "right", speeds = { ["1"] = 0 } }, rect)
        right:update(1)
        assert(right.layers[1].speed < 0 and right.layers[1].offset > 0)
        assert(right.layers[#right.layers].offset == 0)
        right:release()
        for _, id in ipairs(jacls.ids) do
            local preview = JaclPreview.new(jacls.byId[id], 1280, 720)
            assert(preview.image and #preview.diagnostics == 0)
            assert(preview.x + preview.width / 2 == 0 and preview.y == 720)
            local incremental = JaclPreview.new(jacls.byId[id], 1280, 720)
            preview:update(1)
            for _ = 1, 10 do incremental:update(0.1) end
            assert(math.abs(preview.x - incremental.x) < 0.00001)
            preview:update(100)
            assert(preview.x == 640 and preview.height == preview.image:getHeight() * preview.scale
                and preview.y - preview.height == 720 - preview.image:getHeight() * preview.scale)
            preview:update(100)
            assert(preview.x == 640)
            local scenery = View.new(Visuals.refresh("the_cut"), nil, rect)
            local canvas = love.graphics.newCanvas(1280, 720)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0.08, 0.10, 0.14, 1)
            scenery:draw()
            preview:draw()
            love.graphics.setCanvas()
            local pixels = canvas:newImageData()
            write("jacl_" .. id .. ".png", pixels:encode("png"):getString())
            pixels:release()
            canvas:release()
            scenery:release()
            preview:release()
            incremental:release()
            assert(preview.image == nil)
        end
        local missingJacl = JaclPreview.new({ id = "missing_jacl", name = "Missing JACL" }, 1280, 720)
        assert(not missingJacl.image and #missingJacl.diagnostics == 1)
        missingJacl:update(2)
        assert(missingJacl.x == 640)
        missingJacl:draw()
        missingJacl:release()
        local instant = JaclPreview.new({ id = "val", preparation = {
            entranceDuration = 0, scale = 2, bottomOffset = 10,
        } }, 1280, 720)
        assert(instant.x == 640 and instant.y == 710 and instant.width == instant.image:getWidth() * 2)
        instant:release()
        local linear = JaclPreview.new({ id = "val", preparation = { entranceEasing = "linear" } }, 1280, 720)
        linear:update(1)
        assert(linear.x == (linear.startX + linear.targetX) / 2)
        linear:release()
        local state = State.new({}, 1280, 720)
        local originalIds = table.concat(agents.ids, ",")
        local function agentPackage(pool, random)
            return Generator.generate({ biome_pool = pools.biome_pool, jacl_pool = pools.jacl_pool,
                captain_pool = pools.captain_pool, agent_pool = pool }, catalogs, random)
        end
        local subset = { "apex", "b6", "mam", "sam_max", "skin_thief", "snow_white" }
        local selected = agentPackage({ source = "agents", ids = subset, count = 6 })
        local allowed = {}
        for _, id in ipairs(subset) do allowed[id] = true end
        for _, id in ipairs(selected.agentIds) do assert(allowed[id]) end
        assert(table.concat(agents.ids, ",") == originalIds)
        assert(subset[1] == "apex" and subset[6] == "snow_white")
        for _, badPool in ipairs({
            { source = "agents", ids = { "apex" }, count = 6 },
            { source = "agents", ids = "all", count = 0 },
            { source = "agents", ids = "all", count = 1.5 },
            { source = "agents", ids = "all", count = 10 },
            { source = "agents", ids = { "unknown" }, count = 1 },
        }) do
            local agentDraws = 0
            rejects(function() agentPackage(badPool, {
                random = function() agentDraws = agentDraws + 1; return 1 end,
            }) end)
            assert(agentDraws == 0)
        end
        local AgentRoster = require("src.ui.agent_roster")
        local partition = { x = 0, y = 0, width = 1280, height = 360 }
        local roster = AgentRoster.new(subset, agents, partition)
        assert(#roster.diagnostics == 0, table.concat(roster.diagnostics, "; "))
        assert(roster.x == 52 and roster.width == 1176 and #roster.dividers == 5)
        assert(math.abs(roster.y + roster.height / 2 - 180) <= 0.5)
        local rosterCanvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(rosterCanvas)
        love.graphics.clear(1, 0, 1, 1)
        local previousFont = love.graphics.getFont()
        roster:draw()
        assert(love.graphics.getFont() == previousFont and love.graphics.getScissor() == nil)
        love.graphics.setCanvas()
        local rosterPixels = rosterCanvas:newImageData()
        local r, g, b = rosterPixels:getPixel(0, 0)
        assert(r == 0 and g == 0 and b == 0)
        r, g, b = rosterPixels:getPixel(0, 360)
        assert(r == 1 and g == 0 and b == 1)
        rosterPixels:release()
        rosterCanvas:release()
        roster:release()
        assert(not roster.font and not roster.entries[1].image)
        local missingRoster = AgentRoster.new({ "missing_agent" }, { byId = {
            missing_agent = { name = "Missing Agent" },
        } }, partition, { fontPath = "missing_font.ttf" })
        assert(#missingRoster.diagnostics == 2 and not missingRoster.entries[1].image)
        missingRoster:draw()
        missingRoster:release()
        local CaptainPanel = require("src.ui.captain_panel")
        for _, ids in ipairs({ {}, { "unknown" }, { "saw", "saw" } }) do
            local captainDraws = 0
            rejects(function()
                Generator.generate({ biome_pool = pools.biome_pool, jacl_pool = pools.jacl_pool,
                    captain_pool = { source = "captains", ids = ids }, agent_pool = agentPool }, catalogs,
                    { random = function() captainDraws = captainDraws + 1; return 1 end })
            end)
            assert(captainDraws == 0)
        end
        for _, id in ipairs(captains.ids) do
            local panel = CaptainPanel.new(captains.byId[id], { x = 0, y = 360 })
            assert(panel.panel and panel.portrait)
            assert(#panel.diagnostics == 0, table.concat(panel.diagnostics, "; "))
            assert(panel.x == 16 and panel.y == 376)
            assert(panel.portraitX + panel.portraitWidth / 2 == panel.x + panel.width / 2)
            assert(panel.portraitY + panel.portraitHeight / 2 == panel.y + panel.height / 2)
            assert(panel.nameY >= panel.y and panel.titleY + panel.titleHeight <= panel.y + panel.height)
            assert(panel.nameColor[1] == tonumber(captains.byId[id].name.color:sub(1, 2), 16) / 255)
            local canvas = love.graphics.newCanvas(1280, 720)
            local scenery = View.new(Visuals.refresh("the_cut"), nil, rect)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0.08, 0.10, 0.14, 1)
            scenery:draw()
            local oldFont = love.graphics.getFont()
            panel:draw()
            assert(love.graphics.getFont() == oldFont)
            love.graphics.setCanvas()
            local pixels = canvas:newImageData()
            write("captain_" .. id .. ".png", pixels:encode("png"):getString())
            pixels:release()
            canvas:release()
            scenery:release()
            panel:release()
            assert(panel.panel == nil and panel.portrait == nil and panel.nameFont == nil)
        end
        local fallbackSettings = {}
        for key, value in pairs(require("data.captain_panel_defaults")) do fallbackSettings[key] = value end
        fallbackSettings.panelPath = "missing_panel.png"
        fallbackSettings.nameFontPath = "missing_font.ttf"
        fallbackSettings.titleFontPath = "missing_font.ttf"
        local captainFallback = CaptainPanel.new({ id = "missing_captain",
            name = { text = "Missing", color = "bad" }, title = { text = "", color = "#ffffff" } },
            { x = 0, y = 360 }, fallbackSettings)
        assert(not captainFallback.panel and not captainFallback.portrait)
        assert(#captainFallback.diagnostics >= 5 and captainFallback.nameColor[1] == 1)
        captainFallback:draw()
        captainFallback:release()
        state:enter()
        local package = state.package
        assert(state.accents.heading and state.accents.small and #state.accents.diagnostics == 0)
        assert(state.agentRoster.smallFont and state.accents:pulseStrength() == 0)
        assert(state.entranceTime == 0)
        local captainStart = state.captainPanel:entrancePose(0)
        assert(captainStart.x == -state.captainPanel.width and not captainStart.portraitVisible)
        local captainLine = state.captainPanel:entrancePose(0.22)
        assert(captainLine.x == state.captainPanel.x and captainLine.lineAlpha == 1
            and captainLine.revealHeight == 1 and captainLine.text == 0)
        local captainOpening = state.captainPanel:entrancePose(0.36)
        assert(captainOpening.revealHeight > 1 and captainOpening.revealHeight < 128)
        local captainWipe = state.captainPanel:entrancePose(0.625)
        assert(captainWipe.revealHeight == 128 and captainWipe.text == 0.5)
        assert(state.captainPanel:entrancePose(10).text == 1)
        assert(state.agentRoster:entrancePose(1, 0).y == -176)
        assert(not state.agentRoster:entrancePose(1, 0.23).landed)
        assert(state.agentRoster:entrancePose(1, 0.24).landed)
        assert(not state.agentRoster:entrancePose(2, 0.24).landed)
        assert(state.agentRoster:entrancePose(6, 0.75).landed)
        assert(state.agentRoster:entrancePose(6, 10).y == state.agentRoster.y)
        local animationCanvas = love.graphics.newCanvas(1280, 720)
        for index, time in ipairs({ 0, 0.12, 0.22, 0.36, 0.625, 0.75 }) do
            state.entranceTime = time
            love.graphics.setCanvas(animationCanvas)
            love.graphics.clear()
            love.graphics.setScissor(0, 0, 1280, 720)
            state:draw()
            local sx, sy, sw, sh = love.graphics.getScissor()
            assert(sx == 0 and sy == 0 and sw == 1280 and sh == 720)
            love.graphics.setScissor()
            love.graphics.setCanvas()
            local pixels = animationCanvas:newImageData()
            write("entrance_" .. index .. ".png", pixels:encode("png"):getString())
            pixels:release()
        end
        animationCanvas:release()
        state.entranceTime = 0
        local deploy, reroll = state.buttons[1], state.buttons[2]
        assert(state.audio.sources.hover and #state.audio.diagnostics == 0)
        local hoverPlays, actualPlay = 0, state.audio.play
        state.audio.play = function(_, id) assert(id == "hover"); hoverPlays = hoverPlays + 1 end
        state:pointermoved(deploy.x + 1, deploy.y + 1)
        state:pointermoved(deploy.x + 2, deploy.y + 2)
        assert(hoverPlays == 1)
        state:pointermoved(nil, nil)
        assert(hoverPlays == 1)
        state:pointermoved(deploy.x + 1, deploy.y + 1)
        state:pointermoved(reroll.x + 1, reroll.y + 1)
        assert(hoverPlays == 3)
        state:pointermoved(nil, nil)
        state.audio.play = actualPlay
        local Audio = require("src.sys.audio_controller")
        local plays, stops, released, level = 0, 0, false, 1
        local source = {
            play = function() plays = plays + 1; return true end,
            stop = function() stops = stops + 1 end,
            release = function() released = true end,
            setVolume = function(_, volume) level = volume end,
        }
        local controller = Audio.new({ hover = "test.wav" }, {
            newSource = function(path, mode)
                assert(path == "test.wav" and mode == "static")
                return source
            end,
        })
        assert(controller:play("hover") and controller:play("hover"))
        assert(plays == 2 and stops == 2)
        controller:setVolume(0.5)
        assert(level == 0.5)
        controller:setVolume(0)
        assert(not controller:play("hover") and plays == 2)
        assert(not controller:play("missing"))
        controller:release()
        assert(released and next(controller.sources) == nil)
        local missingAudio = Audio.new({ missing = "missing.wav" }, {
            newSource = function() error("missing test sound") end,
        })
        assert(#missingAudio.diagnostics == 1 and not missingAudio:play("missing"))
        missingAudio:release()
        assert(deploy.x == 498 and reroll.x == 692 and #state.buttonDiagnostics == 0)
        assert(math.abs((deploy.y + deploy.height / 2) - (reroll.y + reroll.height / 2)) <= 0.5)
        assert(reroll.y % 1 == 0)
        assert(deploy.width == 178 and deploy.height == 42)
        assert(deploy.y == state.agentRoster.y + state.agentRoster.height + 16)
        assert(deploy.y + deploy.height < 344)
        state:pointermoved(deploy.x, deploy.y)
        assert(deploy.hovered and not reroll.hovered)
        state:pointermoved(deploy.x + deploy.width, deploy.y)
        assert(not deploy.hovered)
        state:pointermoved(reroll.x + 1, reroll.y + 1)
        assert(reroll.hovered and not deploy.hovered)
        state:pointermoved(nil, nil)
        assert(not deploy.hovered and not reroll.hovered)
        local ImageButton = require("src.ui.image_button")
        local missingHover = ImageButton.new({ id = "test", label = "Test", width = 89, height = 21,
            basePath = "assets/images/ui_elements/deploy_btn.png", hoverPath = "missing.png" })
        missingHover:updatePointer(1, 1)
        missingHover:draw()
        assert(missingHover.base and not missingHover.hover and #missingHover.diagnostics == 1)
        missingHover:release()
        local missingButton = ImageButton.new({ id = "test", label = "Test", width = 89, height = 21,
            basePath = "missing.png", hoverPath = "missing.png" })
        missingButton:draw()
        assert(missingButton.font and #missingButton.diagnostics == 2)
        missingButton:release()
        assert(captains.byId[package.captainId] and state.captainPanel)
        assert(jacls.byId[package.jaclId] and state.jaclPreview.x < 0)
        state:update(1)
        assert(state.entranceTime == 1)
        assert(state.package == package)
        state:draw()
        -- Render the integrated layout with all multiline names visible.
        state.agentRoster:release()
        state.agentRoster = AgentRoster.new(subset, agents, partition)
        local fullCanvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(fullCanvas)
        love.graphics.clear()
        state:draw()
        love.graphics.setCanvas()
        local fullPixels = fullCanvas:newImageData()
        write("agent_roster.png", fullPixels:encode("png"):getString())
        for _, button in ipairs(state.buttons) do
            state:pointermoved(button.x + 1, button.y + 1)
            love.graphics.setCanvas(fullCanvas)
            state:draw()
            love.graphics.setCanvas()
            local hoverPixels = fullCanvas:newImageData()
            write(button.id .. "_hover.png", hoverPixels:encode("png"):getString())
            hoverPixels:release()
        end
        fullPixels:release()
        fullCanvas:release()
        local oldAudio, oldButtons = state.audio, state.buttons
        assert(oldAudio.sources.roll and #oldAudio.diagnostics == 0)
        local rollPlays, playBeforeReroll = 0, oldAudio.play
        oldAudio.play = function(_, id) if id == "roll" then rollPlays = rollPlays + 1 end end
        local function click(button, mouseButton)
            state:mousepressed(button.x + 1, button.y + 1, mouseButton or 1)
            state:mousereleased(button.x + 1, button.y + 1, mouseButton or 1)
        end
        local beforeReroll, previousRoster, previousJacl = state.package, state.agentRoster, state.jaclPreview
        state:mousereleased(reroll.x + 1, reroll.y + 1, 1)
        click(deploy, 2)
        click(reroll, 2)
        state:mousepressed(reroll.x + 1, reroll.y + 1, 1)
        state:mousereleased(nil, nil, 1)
        state:mousereleased(reroll.x + 1, reroll.y + 1, 1)
        state:mousepressed(reroll.x + 1, reroll.y + 1, 1)
        state:focus(false)
        state:mousereleased(reroll.x + 1, reroll.y + 1, 1)
        assert(state.package == beforeReroll and rollPlays == 0)
        click(reroll)
        assert(state.package ~= beforeReroll and rollPlays == 1)
        assert(state.accents:pulseStrength() == 1)
        assert(state.audio == oldAudio and state.buttons == oldButtons)
        assert(not previousRoster.font and not previousJacl.image)
        assert(state.entranceTime == 0 and state.jaclPreview.elapsed == 0)
        assert(#state.package.agentIds == 6 and state.package.agentIds ~= beforeReroll.agentIds)
        assert(state.biomes.byId[state.package.biomeId] and state.jacls.byId[state.package.jaclId]
            and state.captains.byId[state.package.captainId])
        local rolledIds = {}
        for _, id in ipairs(state.package.agentIds) do assert(not rolledIds[id]); rolledIds[id] = true end
        local goodPackage, goodRoster = state.package, state.agentRoster
        state:update(0.5)
        assert(state.accents:pulseStrength() == 0)
        local originalLoad = love.filesystem.load
        love.filesystem.load = function(path)
            if path == "data/prep_pool.lua" then return function() return {} end end
            return originalLoad(path)
        end
        click(reroll)
        love.filesystem.load = originalLoad
        assert(state.package == goodPackage and state.agentRoster == goodRoster)
        assert(state.rerollError and state.entranceTime == 0.5 and rollPlays == 1)
        for _ = 1, 3 do click(reroll) end
        assert(rollPlays == 4 and not state.rerollError and state.entranceTime == 0)
        oldAudio.play = playBeforeReroll
        state:exit()
        assert(state.buttons == nil and deploy.base == nil and reroll.hover == nil)
        assert(state.audio == nil)
        assert(state.accents == nil)
        assert(state.parallax == nil and state.jaclPreview == nil and state.captainPanel == nil
            and state.agentRoster == nil)
        state:enter()
        assert(state.package ~= package)
        assert(state.entranceTime == 0)
        assert(state.jaclPreview.x + state.jaclPreview.width / 2 == 0)
        state:exit()
        require("tests.deployment")(write)
        -- Exercise the real main.lua pointer conversion at different window shapes.
        local savedCallbacks = {}
        for key, value in pairs(love) do if type(value) == "function" then savedCallbacks[key] = value end end
        local oldArg, originalNew = arg, State.new
        local liveState
        State.new = function(...)
            liveState = originalNew(...)
            return liveState
        end
        arg = {}
        assert(love.filesystem.load("main.lua"))()
        love.load()
        State.new, arg = originalNew, oldArg
        local originalPosition, originalFocus = love.mouse.getPosition, love.window.hasMouseFocus
        local mouseX, mouseY, focused = 0, 0, true
        love.mouse.getPosition = function() return mouseX, mouseY end
        love.window.hasMouseFocus = function() return focused end
        local liveButton = liveState.buttons[1]
        for _, window in ipairs({ { 1280, 720 }, { 1600, 900 }, { 1600, 720 }, { 1280, 1000 } }) do
            love.resize(window[1], window[2])
            local scale = math.min(window[1] / 1280, window[2] / 720)
            mouseX = (window[1] - 1280 * scale) / 2 + (liveButton.x + 2) * scale
            mouseY = (window[2] - 720 * scale) / 2 + (liveButton.y + 2) * scale
            love.update(0)
            assert(liveButton.hovered)
            local currentPackage = liveState.package
            love.mousepressed(mouseX, mouseY, 1, false, 1)
            love.mousereleased(-1, -1, 1, false, 1)
            assert(liveState.package == currentPackage)
            local liveReroll = liveState.buttons[2]
            local rx = (window[1] - 1280 * scale) / 2 + (liveReroll.x + 2) * scale
            local ry = (window[2] - 720 * scale) / 2 + (liveReroll.y + 2) * scale
            love.mousepressed(rx, ry, 1, false, 1)
            love.mousereleased(-1, -1, 1, false, 1)
            love.mousereleased(rx, ry, 1, false, 1)
            assert(liveState.package == currentPackage)
            love.mousepressed(rx, ry, 1, false, 1)
            love.focus(false)
            love.mousereleased(rx, ry, 1, false, 1)
            assert(liveState.package == currentPackage)
            love.focus(true)
            love.mousepressed(rx, ry, 1, false, 1)
            love.mousereleased(rx, ry, 1, false, 1)
            assert(liveState.package ~= currentPackage and liveState.entranceTime == 0)
        end
        focused = false
        love.update(0)
        assert(not liveButton.hovered)
        focused = true
        mouseX, mouseY = 1, 1 -- Outside the letterboxed canvas at 1280 x 1000.
        love.update(0)
        assert(not liveButton.hovered)
        -- Exercise actual window-to-game conversion for deployment dragging too.
        assert(liveState:deploy())
        local liveDeployment = liveState.stateMachine.current
        love.update(2)
        local entry = liveDeployment.roster.entries[1]
        local target
        for _, cell in ipairs(liveDeployment.grid.cells) do
            if liveDeployment.assignments[cell.id] then target = cell; break end
        end
        assert(target)
        for _, window in ipairs({ { 1280, 720 }, { 1600, 900 }, { 1600, 720 }, { 1280, 1000 } }) do
            love.resize(window[1], window[2])
            local scale = math.min(window[1] / 1280, window[2] / 720)
            local ox, oy = (window[1] - 1280 * scale) / 2, (window[2] - 720 * scale) / 2
            local function at(x, y) mouseX, mouseY = ox + x * scale, oy + y * scale end
            at(entry.x + 5, entry.y + 5)
            love.update(0)
            love.mousepressed(mouseX, mouseY, 1)
            at(target.x, target.y)
            love.update(0)
            love.mousereleased(mouseX, mouseY, 1)
            assert(liveDeployment.agentDeployment.placements[entry.id] == target.id)
            local placed = liveDeployment.agentView.byId[entry.id]
            at(placed.x + 5, placed.y + 5)
            love.update(0)
            love.mousepressed(mouseX, mouseY, 1)
            at(entry.x + 10, entry.y + 10)
            love.update(0)
            love.mousereleased(mouseX, mouseY, 1)
            assert(not liveDeployment.agentDeployment.placements[entry.id])
        end
        liveDeployment:exit()
        love.mouse.getPosition, love.window.hasMouseFocus = originalPosition, originalFocus
        liveState:exit()
        for key, value in pairs(savedCallbacks) do love[key] = value end
    end, debug.traceback)
    if routingOnly then
        write("routing_focused_results.txt", ok and "PASS: Army routing integration\n" or failure)
        love.event.quit(ok and 0 or 1)
        return
    end
    if silencerOnly then
        write("silencer_focused_results.txt", ok and "PASS: Silencer integration\n" or failure)
        love.event.quit(ok and 0 or 1)
        return
    end
    if jaclOnly then
        write("jacl_focused_results.txt", ok and "PASS: JACL rules and UI integration\n" or failure)
        love.event.quit(ok and 0 or 1)
        return
    end
    if doomOnly then
        write("doom_focused_results.txt", ok and "PASS: Doom track and talent-test integration\n" or failure)
        love.event.quit(ok and 0 or 1)
        return
    end
    write("results.txt", ok and "PASS: Target track native portraits, roster order, health, elimination, escape, footer layout and ownership; Doom clock, phase milling and JACL exhaustion; Layered artwork resolution, cache ownership and pixel rendering; Agent inspection previews, opportunity attacks and defeat, enemy engagement, location hover previews, location exploration, mixed-type counts, shared decks, packages, previews, audio, scaled pointer input, reroll commit/recovery/restart, click cancellation, deployment board and scene handoff, agent dragging and clusters, state lifecycle\n" or failure)
    love.event.quit(ok and 0 or 1)
end


