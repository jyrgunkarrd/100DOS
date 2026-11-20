local Model = require("src.sys.battlefield_comparison")
local Assets = require("src.sys.artwork_assets")
local View = {}
View.__index = View

function View.new(agents)
    return setmetatable({ agents = agents, assets = Assets.new(), settings = require("data.battlefield_comparison_view") }, View)
end
function View:build(session, agentId, eligible, pointerX, pointerY)
    local model = Model.build(session.assignments, session.locations, assert(self.agents.byId[agentId]),
        eligible, session.armies.jaclCellId)
    local cell = pointerX and pointerY and session.grid:hit(pointerX, pointerY)
    model.hoveredCell = cell and cell.id or nil
    return model
end
function View:testAlpha(model, entry, test)
    local c = self.settings
    if not entry.eligible then return c.unavailableAlpha end
    return test.band == "worst" and c.subduedAlpha or 1
end
function View.positionsHeld()
    return love.keyboard.isDown("lctrl", "rctrl")
end
-- Centers follow the hex interior: two above, one centered below.
function View:slots(count)
    local c = self.settings
    if count == 1 then return { { x = 0, y = c.singleTop } } end
    if count == 2 then return { { x = -c.pairOffset, y = c.singleTop }, { x = c.pairOffset, y = c.singleTop } } end
    return { { x = -c.pairOffset, y = c.top }, { x = c.pairOffset, y = c.top }, { x = 0, y = c.bottom } }
end
function View:draw(grid, model, font)
    local g, c = love.graphics, self.settings
    g.push("all"); g.setFont(font); g.setLineStyle("rough"); g.setLineWidth(1)
    for _, cell in ipairs(grid.cells) do
        local entry = model.byCell[cell.id]
        if entry then
            g.setColor(0, 0, 0, c.dimAlpha); g.polygon("fill", cell.vertices)
            local alpha = entry.eligible and 1 or c.unavailableAlpha
            if entry.baseline then
                local color = c.rankColors[entry.baseline.band]
                local vertices = {}
                for i = 1, #cell.vertices, 2 do
                    vertices[i] = cell.x + (cell.vertices[i] - cell.x) * c.hexInset
                    vertices[i + 1] = cell.y + (cell.vertices[i + 1] - cell.y) * c.hexInset
                end
                g.setColor(color[1], color[2], color[3], alpha)
                g.setLineWidth(c.hexLineWidth); g.polygon("line", vertices); g.setLineWidth(1)
            end
            if #entry.tests == 0 then
                g.setColor(c.textColor[1], c.textColor[2], c.textColor[3], alpha)
                g.printf(entry.jacl and c.jaclLabel or c.emptyLabel, cell.x - 40, cell.y - font:getHeight(), 80, "center")
            else
                local slots = self:slots(#entry.tests)
                assert(#entry.tests <= #slots, "Battlefield comparison supports at most three tests per location: " .. cell.id)
                -- Present the current one-to-three-test location format without shrinking icons.
                for i, test in ipairs(entry.tests) do
                    local slot = slots[i]
                    if slot then
                        local x, y = math.floor(cell.x + slot.x - c.iconSize / 2), math.floor(cell.y + slot.y)
                        local icon = self.assets:load(c.talentDirectory .. "/" .. test.talent .. ".png")
                        local testAlpha = self:testAlpha(model, entry, test)
                        g.setColor(1, 1, 1, testAlpha)
                        if icon then g.draw(icon, x, y)
                        else g.printf(test.talent:upper(), x - 4, y + 12, c.iconSize + 8, "center") end
                        local color = c.rankColors[test.band]
                        g.setColor(color[1], color[2], color[3], testAlpha)
                        g.setLineWidth(c.iconLineWidth)
                        g.rectangle("line", x + 0.5, y + 0.5, c.iconSize - 1, c.iconSize - 1)
                        g.setLineWidth(1)
                        local difficulty, score = tostring(test.difficulty), tostring(test.score)
                        local difficultyWidth = font:getWidth(difficulty)
                        local pairWidth = difficultyWidth + c.valuePairGap + font:getWidth(score)
                        local valueX = math.floor(x + (c.iconSize - pairWidth) / 2)
                        local valueY = y + c.iconSize + c.valueGap
                        g.setColor(1, 1, 1, testAlpha)
                        g.print(difficulty, valueX, valueY)
                        g.setColor(color[1], color[2], color[3], testAlpha)
                        g.print(score, valueX + difficultyWidth + c.valuePairGap, valueY)
                    end
                end
            end
        end
    end
    g.pop()
end
function View:release() self.assets:release() end
return View

