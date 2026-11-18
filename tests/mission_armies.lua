return function(write, headless)
    local Armies = require("src.sys.mission_armies")
    local forces = require("data.forces.index").refresh()
    local lists = require("data.army_lists.index").refresh()
    local rules = require("data.army_deployment_rules")
    local biomes = require("data.biomes.index").refresh()
    local captains = require("data.captains.index").refresh()
    local grid = require("src.ui.hex_grid").new(require("data.deployment_board"), 1280, 360)
    local assignments = {}
    for _, cell in ipairs(grid.cells) do assignments[cell.id] = "location_" .. cell.id end
    local function build(biome, captain, seed, armyLists)
        return Armies.build(assignments, "center", biome, captain, forces, armyLists or lists, rules,
            love.math.newRandomGenerator(seed))
    end
    local function rejects(fn, fragment)
        local ok, message = pcall(fn)
        assert(not ok and tostring(message):find(fragment, 1, true), tostring(message))
    end
    for _, biomeId in ipairs(biomes.ids) do
        for _, captainId in ipairs(captains.ids) do
            local biome, captain = biomes.byId[biomeId], captains.byId[captainId]
            local a, b = build(biome, captain, 123), build(biome, captain, 123)
            assert(not a.byCell.center)
            local seen, unitIds, count = { allied = {}, enemy = {} }, {}, 0
            for cellId, pair in pairs(a.byCell) do
                count = count + 1
                for _, side in ipairs({ "allied", "enemy" }) do
                    local army, other = pair[side], b.byCell[cellId][side]
                    assert(not seen[side][army.templateId])
                    seen[side][army.templateId] = true
                    assert(army.templateId == other.templateId)
                    local counts = { regular = 0, elite = 0 }
                    for _, slot in ipairs(lists[side].byId[army.templateId]) do counts[slot.str] = counts[slot.str] + slot.qty end
                    assert(army.counts.regular == counts.regular and army.counts.elite == counts.elite)
                    assert(army.value == counts.regular + 2 * counts.elite)
                    for i, unit in ipairs(army.forces) do
                        assert(not unitIds[unit.id]); unitIds[unit.id] = true
                        assert(unit.forceId == other.forces[i].forceId and forces.byId[unit.forceId].faction == side)
                        assert(unit ~= other.forces[i])
                    end
                end
            end
            assert(count == 8)
            local view
            if not headless then
            view = require("src.ui.location_armies").new(a, grid, require("data.army_deployment_view"))
            assert(#view.labels == 8)
            for _, label in ipairs(view.labels) do
                local cell
                for _, c in ipairs(grid.cells) do if c.id == label.cellId then cell = c end end
                if cell.id == "north" or cell.id == "northeast" or cell.id == "northwest" then
                    assert(label.y < cell.y)
                else assert(label.y > cell.y) end
            end
            local canvas = love.graphics.newCanvas(1280, 360)
            love.graphics.push("all"); love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 1); grid:draw(); view:draw()
            love.graphics.setCanvas(); love.graphics.pop()
            local data = canvas:newImageData()
            local encoded = data:encode("png")
            write("army_deployment.png", encoded:getString())
            encoded:release(); data:release(); canvas:release()
            end
            local source = { armies = a, armyView = view }
            local session = require("src.sys.mission_session").take(source)
            assert(session.armies == a and session.armyView == view and source.armies == nil and source.armyView == nil)
            require("src.sys.mission_session").release(session)
            if view then assert(view.font == nil) end
        end
    end
    local biome, captain = biomes.byId[biomes.ids[1]], captains.byId[captains.ids[1]]
    rejects(function() build({ id = "bad", allied_forces = { "missing" } }, captain, 1) end, "Unknown allied force")
    rejects(function() build({ id = "empty" }, { id = "empty" }, 1) end, "No allied")
    rejects(function() build(biome, captain, 1, { allied = { ids = {}, byId = {} } }) end, "Not enough distinct")
    local value = require("src.sys.army_value").calculate({ forces = {
        { forceId = "r" }, { forceId = "r" }, { forceId = "e" },
    } }, { byId = { r = { strength = "regular" }, e = { strength = "elite" } } }, rules)
    assert(value == 4)
    -- Over many deterministic seeds, reduced allied supreme weights reduce selection.
    local weighted, uniform = 0, 0
    local pools = require("src.sys.force_pool").build(biome, captain, forces)
    local generator = require("src.sys.army_generator")
    for seed = 1, 300 do
        for mode = 1, 2 do
            local config = mode == 1 and rules or { strength = rules.strength, weights = { allied = { normal = 1, supreme = 1 } } }
            local armies = generator.generate("allied", 8, lists.allied, pools.allied, forces, config, love.math.newRandomGenerator(seed))
            for _, army in ipairs(armies) do
                if army.templateId:match("^sup_") then
                    if mode == 1 then weighted = weighted + 1 else uniform = uniform + 1 end
                end
            end
        end
    end
    assert(weighted < uniform)
end
