local Config = require("data.fate_pool_inspection_view")
local Display = require("src.sys.fate_pool_display")
local Reserve = require("src.sys.fate_reserve")
local Assets = require("src.sys.artwork_assets")
local Tile = require("src.ui.fate_tile")
local Inspect = {}

local function inside(box, x, y)
    return x and y and x >= box.x and x < box.x + box.width and y >= box.y and y < box.y + box.height
end

function Inspect.buttonBounds(state)
    local scene = (state.session or state).scene
    local captain = scene.captainPanel
    local c = Config.button
    return { x = captain:entrancePose(scene.entranceTime).x, y = captain.y + captain.height + c.captainGap,
        width = captain.width, height = c.height }
end

local function available(state)
    local session = state.session or state
    if not session.fatePool or state.agentInspectionPanel or state.battlefieldInspectionCell then return false end
    if state.inputReady and not state:inputReady() then return false end
    if state.handReadyAt and state.elapsed < state.handReadyAt then return false end
    local drag = state.drag
    return not (drag and (drag.pending or drag.card or drag.active))
        and not (state.resolving and state:resolving())
        and not (state.maneuver and state.maneuver.flight)
        and not (state.exploration and state.exploration:busy())
end

local function open(state)
    local c = Config
    local session = state.session or state
    local pool = session.fatePool
    local main = Display.pool(pool)
    local model = { rows = Reserve.rows(pool), total = main.total, bonusTotal = #Reserve.entries(pool) }
    for _, row in ipairs(main.rows) do model.rows[#model.rows + 1] = row end
    local x, y = math.floor((state.width - c.width) / 2), math.floor((state.height - c.height) / 2)
    local bodyY, bodyHeight = y + c.listTop, c.height - c.listTop - c.padding
    local detailX = x + c.padding + c.listWidth + c.gap
    state:focus(false, true)
    state.fatePoolInspection = {
        x = x, y = y, width = c.width, height = c.height, model = model, selected = 1,
        first = 1, sourceFirst = 1, capacity = math.floor((bodyHeight - 14) / c.rowHeight),
        assets = Assets.new(), close = { x = x + c.width - c.padding - 28, y = y + c.padding, width = 28, height = 26 },
        list = { x = x + c.padding, y = bodyY, width = c.listWidth, height = bodyHeight },
        detail = { x = detailX, y = bodyY, width = x + c.width - c.padding - detailX, height = bodyHeight },
    }
end

function Inspect.release(state)
    local panel = state.fatePoolInspection
    if panel then panel.assets:release(); state.fatePoolInspection = nil end
    state.fatePoolPressed, state.fatePoolHovered = nil, nil
end

function Inspect.focus(state, focused)
    if focused then return end
    state.fatePoolPressed, state.fatePoolHovered = nil, nil
    local panel = state.fatePoolInspection
    if panel then panel.pressed, panel.hovered, panel.pointerX, panel.pointerY = nil, nil, nil, nil end
end

local function hit(panel, x, y)
    if not inside(panel, x, y) or inside(panel.close, x, y) then return "close" end
    if inside(panel.list, x, y) then
        local offset = math.floor((y - panel.list.y) / Config.rowHeight)
        local index = panel.first + offset
        if offset < panel.capacity and panel.model.rows[index] then return index end
    end
end

function Inspect.pointermoved(state, x, y)
    local panel = state.fatePoolInspection
    if panel then
        panel.pointerX, panel.pointerY = x, y
        panel.hovered = x and y and hit(panel, x, y)
        return true
    end
    state.fatePoolHovered = available(state) and inside(Inspect.buttonBounds(state), x, y)
    return false
end

function Inspect.mousepressed(state, x, y, button)
    local panel = state.fatePoolInspection
    if panel then
        if button == 2 then Inspect.release(state)
        elseif button == 1 then panel.pressed = hit(panel, x, y) end
        return true
    end
    if button == 1 and available(state) and inside(Inspect.buttonBounds(state), x, y) then
        state.fatePoolPressed = true
        return true
    end
    return false
end

function Inspect.mousereleased(state, x, y, button)
    local panel = state.fatePoolInspection
    if panel then
        if button == 1 then
            local target, pressed = hit(panel, x, y), panel.pressed
            panel.pressed = nil
            if target and target == pressed then
                if target == "close" then Inspect.release(state)
                else panel.selected, panel.sourceFirst, panel.sourceCapacity = target, 1, nil end
            end
        end
        return true
    end
    if button == 1 and state.fatePoolPressed then
        state.fatePoolPressed = nil
        if available(state) and inside(Inspect.buttonBounds(state), x, y) then open(state) end
        return true
    end
    return false
end

function Inspect.keypressed(state, key, isrepeat)
    if state.fatePoolInspection then
        if key == "escape" or (key == Config.shortcut and not isrepeat) then Inspect.release(state) end
        return true
    end
    if key ~= Config.shortcut then return false end
    if not isrepeat and available(state) then open(state) end
    return true
end

function Inspect.wheel(state, delta)
    local panel = state.fatePoolInspection
    if not panel then return false end
    if delta == 0 then return true end
    local step = math.max(1, math.floor(math.abs(delta))) * (delta > 0 and -1 or 1)
    if inside(panel.detail, panel.pointerX, panel.pointerY) then
        local row = panel.model.rows[panel.selected]
        if row and row.contributors and panel.sourceCapacity then
            local maximum = math.max(1, #row.contributors - panel.sourceCapacity + 1)
            panel.sourceFirst = math.max(1, math.min(maximum, panel.sourceFirst + step))
        end
    else
        local maximum = math.max(1, #panel.model.rows - panel.capacity + 1)
        panel.first = math.max(1, math.min(maximum, panel.first + step))
        panel.hovered = panel.pointerX and hit(panel, panel.pointerX, panel.pointerY)
    end
    return true
end

local function centered(font, value, box)
    local g = love.graphics
    g.setFont(font)
    g.printf(value, box.x, math.floor(box.y + (box.height - font:getHeight()) / 2), box.width, "center")
end

local function rowText(font, name, quantity, x, y, width)
    local g = love.graphics
    g.setFont(font)
    name = name:gsub("%s+", " ")
    local count = "x" .. quantity
    local scale = math.min(1, (width - font:getWidth(count) - 12) / math.max(1, font:getWidth(name)))
    g.print(name, x, y, 0, scale, scale)
    g.printf(count, x, y, width, "right")
end

local function drawPanel(state, panel, fonts)
    local g, c, list, detail = love.graphics, Config, panel.list, panel.detail
    g.setColor(c.shade); g.rectangle("fill", 0, 0, state.width, state.height)
    g.setColor(c.background); g.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    g.setColor(c.accent); g.rectangle("line", panel.x + 0.5, panel.y + 0.5, panel.width - 1, panel.height - 1)
    g.setFont(fonts.heading); g.setColor(c.text); g.print(c.title, list.x, panel.y + c.padding)
    g.setFont(fonts.small); g.setColor(c.muted)
    g.print(panel.model.total .. " POOL TILES  /  " .. panel.model.bonusTotal .. " BONUS AVAILABLE",
        list.x, panel.y + c.padding + 23)
    g.setColor(panel.hovered == "close" and c.highlight or c.row)
    g.rectangle("fill", panel.close.x, panel.close.y, panel.close.width, panel.close.height)
    g.setColor(c.text); centered(fonts.heading, "X", panel.close)
    g.setFont(fonts.small); g.setColor(c.muted); g.print("TILE TYPES", list.x, list.y - 16)
    local rows = panel.model.rows
    if #rows == 0 then g.print("NO TILES AVAILABLE", list.x, list.y + 10) end
    local last = math.min(#rows, panel.first + panel.capacity - 1)
    for i = panel.first, last do
        local row, y = rows[i], list.y + (i - panel.first) * c.rowHeight
        g.setColor((panel.selected == i or panel.hovered == i) and c.highlight or c.row)
        g.rectangle("fill", list.x, y, list.width, c.rowHeight - 3)
        g.setColor(row.bonus and c.accent or c.text)
        local name = row.bonus and ("BONUS / " .. row.name) or row.name
        rowText(fonts.heading, name, row.quantity, list.x + 10, y + 8, list.width - 20)
    end
    if #rows > panel.capacity then
        g.setFont(fonts.small); g.setColor(c.muted)
        g.printf(panel.first .. "-" .. last .. " / " .. #rows,
            list.x, list.y + panel.capacity * c.rowHeight + 3, list.width, "right")
    end
    local row = rows[panel.selected]
    if not row then return end
    local total = row.bonus and panel.model.bonusTotal or panel.model.total
    local tileType = row.bonus and " BONUS TILES" or " POOL TILES"
    local top = Tile.drawDetails(row, panel.assets, fonts, detail, c, row.quantity .. " OF " .. total .. tileType) + 10
    g.setFont(fonts.small); g.setColor(c.muted)
    if row.bonus then
        local cost = Tile.costText(row.extraCost)
        local instructions = "COMMIT BEFORE A TEST.\nSPENT ON SUCCESS OR FAILURE.\nNOT DRAWN FROM THE FATE POOL."
        if cost then instructions = "COST PER TILE  " .. cost .. "\n\n" .. instructions end
        g.printf(instructions, detail.x + 10, top, detail.width - 20, "left")
        return
    end
    g.print("CONTRIBUTORS", detail.x + 10, top)
    local sources, start = row.contributors or {}, top + 18
    panel.sourceCapacity = math.max(1, math.floor((detail.y + detail.height - start - 12) / c.sourceRowHeight))
    local sourceLast = math.min(#sources, panel.sourceFirst + panel.sourceCapacity - 1)
    if #sources == 0 then g.print("CONTRIBUTOR DETAILS UNAVAILABLE", detail.x + 10, start) end
    for i = panel.sourceFirst, sourceLast do
        local source, y = sources[i], start + (i - panel.sourceFirst) * c.sourceRowHeight
        g.setColor(c.text)
        rowText(fonts.small, c.sourceLabels[source.kind] .. "  /  " .. source.name, source.quantity,
            detail.x + 10, y, detail.width - 20)
    end
    if #sources > panel.sourceCapacity then
        g.setFont(fonts.small); g.setColor(c.muted)
        g.printf(panel.sourceFirst .. "-" .. sourceLast .. " / " .. #sources,
            detail.x + 10, start + panel.sourceCapacity * c.sourceRowHeight, detail.width - 20, "right")
    end
end

function Inspect.drawButton(state)
    local session = state.session or state
    if not session.fatePool then return end
    local g, c, fonts = love.graphics, Config, session.scene.accents
    local box, enabled = Inspect.buttonBounds(state), available(state)
    g.push("all")
    g.setColor(enabled and state.fatePoolHovered and c.highlight or c.background)
    g.rectangle("fill", box.x, box.y, box.width, box.height)
    g.setColor(enabled and c.accent or c.muted)
    g.rectangle("line", box.x + 0.5, box.y + 0.5, box.width - 1, box.height - 1)
    g.setColor(enabled and c.text or c.muted)
    centered(fonts.small, c.title, box)
    g.pop()
end

function Inspect.draw(state)
    local panel = state.fatePoolInspection
    if not panel then return end
    local g = love.graphics
    g.push("all")
    drawPanel(state, panel, (state.session or state).scene.accents)
    g.pop()
end

return Inspect
