local Difficulty = require("src.ui.test_difficulty")
local Tests = require("src.sys.talent_tests")
local Values = require("src.sys.talent_values")
local Passives = require("src.sys.force_passives")
local BattlefieldRules = require("data.battlefield_rules")
local BattlefieldAction = require("src.sys.battlefield_action")
local Action = require("src.sys.talent_test_action")
local Reserve = require("src.sys.fate_reserve")
local Tile = require("src.ui.fate_tile")
local EngagementPreview = require("src.ui.engagement_effect_preview")
local Panel = {}
Panel.__index = Panel
local function inside(x, y, b)
    return x and y and x >= b.x and y >= b.y and x < b.x + b.width and y < b.y + b.height
end
function Panel.new(session, agentId, width, preview, portrait, equipment)
    local c = require("data.talent_test_view")
    return setmetatable({ session = session, agentId = agentId, settings = c,
        preview = preview, portrait = portrait, equipment = equipment, images = {}, x = (width - c.width) / 2, y = c.top, width = c.width, height = c.height, engagementEffectHeight = 0, selected = {}, first = 1 }, Panel)
end
-- Cache mini-portrait artwork independently of the full-art preview images.
function Panel:loadImage(path)
    if self.images[path] == nil then
        local ok, image = pcall(love.graphics.newImage, path, { mipmaps = false })
        self.images[path] = ok and image or false
        if ok then
            image:setFilter("nearest", "nearest")
        else print("[Talent test panel] Cannot load artwork: " .. path) end
    end
    return self.images[path]
end
function Panel:open(card)
    self.battlefieldArgs, self.locationArgs = nil, nil
    self:layoutEngagementEffect()
    self.bonusSelected, self.reserveFirst = {}, 1
    self.card, self.selected, self.test, self.error, self.first = card, {}, nil, nil, 1
    self.definition = self.session.locationDecks.pool.byId[card.cardId]
    self.exhaustOptions = require("src.sys.asset_abilities").exhaustOptions(self.session, self.agentId, self.definition)
    self.exhaustSelected = {}
    self.tests = Tests.resolve(self.definition)
    local locationArt = require("data.location_exploration_view")
    local agentArt = require("data.deployment_roster_defaults")
    self.locationImage = self:loadImage(locationArt.directory .. "/" .. card.cardId .. locationArt.suffix)
    self.agentImage = self:loadImage(agentArt.directory .. "/" .. self.agentId .. agentArt.suffix)
end
function Panel:openBattlefield(args)
    local cell = self.session.agentDeployment.placements[self.agentId]
    local id = self.session.assignments[cell]
    self.locationArgs = nil
    self.bonusSelected, self.reserveFirst = {}, 1
    self.exhaustOptions, self.exhaustSelected = {}, {}
    self.battlefieldArgs = args
    if self.engagementPreview then self.engagementPreview:clear() end
    self:layoutEngagementEffect(self:engagementProjection())
    self.card, self.selected, self.test, self.error, self.first = {}, {}, nil, nil, 1
    local location = self.session.locations.byId[id]
    local target = args.targetCell and self.session.locations.byId[self.session.assignments[args.targetCell]]
    local title = args.clash and self.settings.labels.clash or args.battlefieldKind:upper()
    self.definition = { name = title .. " - " .. (target and target.name or location.name) }
    self.tests = require("src.sys.battlefield_tests").resolve(location, args.battlefieldKind, args.clash and args.clash.difficulty)
    for _, test in ipairs(self.tests) do
        if self.preview then self:loadImage(self.preview.settings.talentDirectory .. "/" .. test.talent .. ".png") end
    end
    self.locationImage = self:loadImage("assets/images/locations/" .. id .. ".png")
    local art = require("data.deployment_roster_defaults")
    self.agentImage = self:loadImage(art.directory .. "/" .. self.agentId .. art.suffix)
end
function Panel:openLocation(kind)
    self:openBattlefield({ battlefieldKind = "maneuver" })
    self.battlefieldArgs = nil
    self.locationArgs = { locationKind = kind }
    self.definition.name = require("data.location_actions").actions[kind].label
    self.tests = require("src.sys.location_actions").tests(kind)
    if self.preview then self:loadImage(self.preview.settings.talentDirectory .. "/" .. self.tests[1].talent .. ".png") end
end
function Panel:evaluate()
    local action = self.locationArgs and require("src.sys.location_actions") or self.battlefieldArgs and BattlefieldAction or Action
    return action.evaluate(self.session, self.agentId, self:args())
end
function Panel:engagementProjection(evaluation)
    if evaluation then return evaluation.engagementProjection end
    local args = self.battlefieldArgs
    if args and args.battlefieldKind == "engage" then
        return BattlefieldAction.previewEngagement(self.session, self.agentId, args.clash)
    end
end
function Panel:layoutEngagementEffect(projection)
    self.engagementEffectHeight = projection and self.settings.engagementEffectHeight or 0
    self.height = self.settings.height + self.engagementEffectHeight
    if not projection and self.engagementPreview then self.engagementPreview:clear() end
end
function Panel:close()
    self.card, self.pressed, self.pointerX, self.pointerY, self.battlefieldArgs = nil, nil, nil, nil, nil
    self:layoutEngagementEffect()
end
function Panel:update(dt)
    if self.engagementPreview then self.engagementPreview:update(dt) end
end
function Panel:release()
    self:close()
    if self.engagementPreview then self.engagementPreview:release(); self.engagementPreview = nil end
    for _, image in pairs(self.images) do if image then image:release() end end
    self.images, self.locationImage, self.agentImage = {}, nil, nil
end
function Panel:pointermoved(x, y) self.pointerX, self.pointerY = x, y end
function Panel:columns()
    local left = self.x + self.settings.testInset
    local width = self.width - self.settings.testInset - 14
    return math.floor(left + width / 4), math.floor(left + width * 3 / 4)
end
function Panel:bonusCounts()
    local counts = {}
    for _, entry in ipairs(Reserve.entries(self.session.fatePool)) do
        if self.bonusSelected and self.bonusSelected[entry] then counts[entry.tileId] = (counts[entry.tileId] or 0) + 1 end
    end
    return counts
end
function Panel:bonusCost()
    if not self.card or not self.test then return end
    local counts = self:bonusCounts()
    if not next(counts) then return end
    local commitment = Reserve.evaluate(self.session.fatePool, counts)
    return commitment and commitment.cost
end
function Panel:args()
    local ids = {}
    for _, card in ipairs(self.session.agentCards.byAgent[self.agentId].hand) do
        if self.selected[card.instanceId] then ids[#ids + 1] = card.instanceId end
    end
    local args = { bonusCounts = self:bonusCounts(), instanceId = self.card.instanceId, testId = self.test and self.test.id, committedIds = ids }
    args.exhaustIds = {}
    for _, option in ipairs(self.exhaustOptions or {}) do
        local id = option.asset.instanceId
        if self.exhaustSelected[id] then args.exhaustIds[#args.exhaustIds + 1] = id end
    end
    for key, value in pairs(self.battlefieldArgs or {}) do args[key] = value end
    for key,value in pairs(self.locationArgs or {}) do args[key] = value end
    return args
end
function Panel:contribution(card)
    if not self.test then return 0 end
    return Values.sum(self.session.agentCards.definitions.byId[card.cardId].talents or {}, self.test.talent)
end
function Panel:reserveBounds()
    return { x = self.x + 14, y = self.y + self.settings.reserveTop + self.engagementEffectHeight,
        width = self.width - 28, height = self.settings.reserveTileHeight }
end
function Panel:reserveTiles()
    local entries = Reserve.entries(self.session.fatePool)
    local box, c = self:reserveBounds(), self.settings
    local step = c.reserveTileWidth + c.reserveGap
    local capacity = math.max(1, math.floor((box.width + c.reserveGap) / step))
    self.reserveFirst = math.max(1,math.min(self.reserveFirst or 1,math.max(1,#entries-capacity+1)))
    local tiles = {}
    for i = self.reserveFirst,math.min(#entries,self.reserveFirst+capacity-1) do
        tiles[#tiles+1] = { entry = entries[i], index = i, x = box.x+(i-self.reserveFirst)*step,
            y = box.y, width = c.reserveTileWidth, height = box.height }
    end
    return tiles,capacity,#entries
end
function Panel:buttons()
    local result = {}
    for i = self.first, math.min(#self.tests, self.first + self.settings.rows - 1) do
        result[#result + 1] = { id = i, x = self.x + self.settings.testInset, y = self.y + self.settings.rowsTop + (i - self.first) * self.settings.rowHeight,
            width = self.width - self.settings.testInset - 14, height = self.settings.rowHeight - 4 }
    end
    local clash = self.battlefieldArgs and self.battlefieldArgs.clash
    if not clash then
        result[#result + 1] = { id = "cancel", x = self.x + 14, y = self.y + self.height - 42, width = 30, height = 30 }
    end
    local inset = clash and 14 or 56
    result[#result + 1] = { id = "confirm", x = self.x + inset, y = self.y + self.height - 42, width = self.width - inset - 14, height = 30 }
    return result
end
function Panel:rowContains(x, y, button)
    if type(button.id) ~= "number" then return inside(x, y, button) end
    return inside(x, y, { x = self.x + 14, y = button.y, width = self.width - 28, height = button.height })
end
function Panel:hit(x, y, hand)
    if self.test then
        for _,tile in ipairs(self:reserveTiles()) do
            if inside(x,y,tile) then return "bonus:" .. tile.index, { bonusEntry = tile.entry } end
        end
    end
    for _, button in ipairs(self:buttons()) do if self:rowContains(x, y, button) then return tostring(button.id), button.id end end
    if self.test and self.equipment then
        for _, option in ipairs(self.exhaustOptions or {}) do
            local left, top, width, height = self.equipment:bounds(option.asset.start, option.asset.size)
            if x and y and x >= left and x < left + width and y >= top and y < top + height then
                return "asset:" .. option.asset.instanceId, option
            end
        end
    end
    local entry = hand:hover(x, y)
    if entry and y < entry.y + hand.settings.height and self:contribution(entry.card) > 0 then
        return "card:" .. entry.card.instanceId, entry.card
    end
end
function Panel:press(x, y, hand) self.pressed = self:hit(x, y, hand) end
function Panel:releasePointer(x, y, hand)
    local key, value = self:hit(x, y, hand)
    local pressed = self.pressed
    self.pressed = nil
    if not key or key ~= pressed then return end
    if type(value) == "table" and value.bonusEntry then
        self.bonusSelected[value.bonusEntry] = not self.bonusSelected[value.bonusEntry]
        self.error = nil
    elseif type(value) == "table" and value.asset then
        if self.test then
            local id = value.asset.instanceId
            self.exhaustSelected[id] = not self.exhaustSelected[id]
        end
    elseif type(value) == "table" then self.selected[value.instanceId] = not self.selected[value.instanceId]
    elseif type(value) == "number" then self.test, self.selected, self.error = self.tests[value], {}, nil
    elseif value == "cancel" then self:close()
    elseif value == "confirm" and self.test then
        local evaluation, reason = self:evaluate()
        if evaluation then
            if self.session.audio then self.session.audio:playOverlapping("selection") end
            return self:args()
        end
        self.error = reason
        return
    else
        return
    end
    if self.session.audio then self.session.audio:playOverlapping("selection") end
end
function Panel:wheel(x, y, delta)
    local preview = self.engagementPreview and self.engagementPreview.card
    if preview and preview:wheel(delta) then return true end
    if not inside(x, y, self) then return false end
    if inside(x,y,self:reserveBounds()) then
        local _,capacity,total = self:reserveTiles()
        self.reserveFirst = math.floor(math.max(1,math.min(math.max(1,total-capacity+1),self.reserveFirst-delta)))
        self.pressed = nil
        return true
    end
    self.first = math.max(1, math.min(math.max(1, #self.tests - self.settings.rows + 1), self.first - delta))
    self.first = math.floor(self.first)
    return true
end
function Panel:draw(hand, font, heading)
    if not self.card then return end
    local g, c = love.graphics, self.settings
    local evaluation, reason
    if self.test then evaluation, reason = self:evaluate() end
    local projection = self:engagementProjection(evaluation)
    self:layoutEngagementEffect(projection)
    local offset = self.engagementEffectHeight
    g.push("all"); g.setFont(font)
    g.setColor(c.background); g.rectangle("fill", self.x, self.y, self.width, self.height)
    g.setColor(c.accent); g.rectangle("line", self.x, self.y, self.width, self.height)
    g.setFont(heading or font)
    g.setColor(c.text); g.printf(self.definition.name, self.x + 14, self.y + 10, self.width - 28, "left")
    g.setFont(font)
    g.setColor(c.muted); g.print(c.labels.choose:upper(), self.x + 14, self.y + 40)
    if #self.tests > c.rows then
        g.print("SCROLL " .. self.first .. "-" .. math.min(#self.tests, self.first + c.rows - 1) .. "/" .. #self.tests, self.x + 14, self.y + 56)
    end
    local locationColumn, agentColumn = self:columns()
    local agent = self.session.agentCards.agents.byId[self.agentId]
    local status = self.session.agentStatus.byAgent[self.agentId]
    local forceBonus = 0
    local kind = self.battlefieldArgs and self.battlefieldArgs.battlefieldKind
    if projection then
        forceBonus = projection.effect.forceBonusAfter
    elseif kind and BattlefieldRules.actions[kind] then
        forceBonus = Passives.battlefieldBonus(self.session.armies, self.session.agentDeployment.placements[self.agentId], kind)
    end
    local function drawValue(column, value, number, color, y)
        local width = font:getWidth(tostring(value))
        g.setColor(color)
        g.print(number, column - math.floor(width / 2) + width - font:getWidth(number), y)
    end
    local function imageInBox(image, x, y, size, fallback)
        if image then
            local scale = math.min(size / image:getWidth(), size / image:getHeight())
            g.setColor(1, 1, 1, 1)
            g.draw(image, math.floor(x + (size - image:getWidth() * scale) / 2),
                math.floor(y + (size - image:getHeight() * scale) / 2), 0, scale, scale)
        else
            g.setColor(c.muted)
            g.printf(fallback, x, y + math.floor((size - font:getHeight()) / 2), size, "center")
        end
    end
    local preview = self.preview
    local locationImage, agentImage = self.locationImage, self.agentImage
    for i, column in ipairs({ locationColumn, agentColumn }) do
        local image
        if i == 1 then image = locationImage else image = agentImage end
        local fitLocation = (self.battlefieldArgs or self.locationArgs) and i == 1
        local width = not fitLocation and image and image:getWidth() or c.portraitSize
        local height = not fitLocation and image and image:getHeight() or c.portraitSize
        local x = math.floor(column - width / 2)
        local y = math.floor(self.y + c.portraitTop + (c.portraitSize - height) / 2)
        if fitLocation then
            imageInBox(image, x, y, c.portraitSize, "FIELD")
        elseif image then
            g.setColor(1, 1, 1, 1)
            g.draw(image, x, y) -- Native pixels: no rescaling of either mini portrait.
        else
            imageInBox(nil, x, y, c.portraitSize, i == 1 and "CARD" or "AGENT")
        end
        g.setColor(c.muted); g.rectangle("line", x, y, width, height)
    end
    for _, button in ipairs(self:buttons()) do
        local test = type(button.id) == "number" and self.tests[button.id]
        local enabled = button.id ~= "confirm" or evaluation ~= nil
        local selected = test and test == self.test
        local hovered = self:rowContains(self.pointerX, self.pointerY, button)
        if selected or hovered then
            g.setColor(c.accent[1], c.accent[2], c.accent[3], selected and c.selectedAlpha or c.hoverAlpha)
            g.rectangle("fill", button.x, button.y, button.width, button.height)
        end
        g.setColor(selected and c.accent or hovered and c.text or c.muted)
        g.rectangle("line", button.x, button.y, button.width, button.height)
        if test then
            g.setFont(font)
            local iconPath = preview and preview.settings.talentDirectory .. "/" .. test.talent .. ".png"
            local icon = iconPath and (preview.images[iconPath] or self.images[iconPath])
            imageInBox(icon, self.x + 14, button.y + math.floor((button.height - c.iconSize) / 2), c.iconSize, "?")
            local labelY = button.y + math.floor((button.height - font:getHeight()) / 2)
            g.setColor(c.text)
            if self.battlefieldArgs or self.locationArgs then
                g.print(test.talent:upper(), self.x + 14 + c.iconSize + c.iconGap, labelY)
            elseif test.kind ~= "interact" then
                g.print("(" .. test.kind:upper() .. ")", self.x + 14 + c.iconSize + c.iconGap, labelY)
            end
            local number, color = Difficulty.format(test, test.value, c.text)
            drawValue(locationColumn, test.value, number, color, labelY)
            local base, modifier = Values.effective(agent, test.talent, status)
            local strength = selected and evaluation and (evaluation.base + evaluation.bonus) or (base + forceBonus)
            number, color = Difficulty.strength(strength, base - modifier, c.text)
            drawValue(agentColumn, strength, number, color, labelY)
        else
            g.setFont(heading or font)
            g.setColor(button.id == "cancel" and c.cancelColor or enabled and c.text or c.muted)
            local labelY = button.y + math.floor((button.height - g.getFont():getHeight()) / 2)
            local offset = button.id == "cancel" and c.cancelGlyphOffset
            g.printf(c.labels[button.id], button.x + 6 + (offset and offset.x or 0), labelY + (offset and offset.y or 0), button.width - 12, "center")
        end
    end
    g.setFont(font)
    if projection then
        self.engagementPreview = self.engagementPreview or EngagementPreview.new(self.session)
        g.push("all")
        self.engagementPreview:draw(self, projection.effect)
        g.pop()
    end
    if #self.tests == 0 then g.print(c.labels.empty:upper(), self.x + 14, self.y + c.rowsTop) end
    if self.test then
        g.setColor(c.text)
        if evaluation then
            local summary = self.test.talent:upper() .. " " .. evaluation.base .. " + CARDS " .. (evaluation.cardBonus or evaluation.bonus) .. " + BONUS " .. (evaluation.reserveBonus or 0)
                .. ((evaluation.assetBonus or 0) > 0 and " + ASSET " .. evaluation.assetBonus or "")
                .. Difficulty.forceTerms(evaluation)
                .. " = "
            local total = evaluation.base + evaluation.bonus
            local _, strengthColor = Difficulty.strength(total, Values.sum(agent.talents or {}, self.test.talent), c.text)
            local line = Difficulty.line(" VS ", self.test, self.test.value, c.text, " (BEFORE FATE)")
            local summaryLine = { c.text, summary, strengthColor, tostring(total), unpack(line) }
            g.setColor(1, 1, 1, 1)
            g.printf(summaryLine,
                self.x + 14, self.y + c.summaryTop + offset, self.width - 28, "center")
        end
        local cost = Tile.costText(self:bonusCost())
        g.setColor(cost and c.accent or c.muted)
        g.printf(cost and ("BONUS COST  " .. cost) or c.labels.commit:upper(),
            self.x + 14, self.y + c.commitTop + offset, self.width - 28, "center")
        local function highlight(x, y, w, h, amount, selected, verb)
            if amount <= 0 then
                g.setColor(0, 0, 0, 0.5)
                g.rectangle("fill", x, y, w, h)
                return
            end
            if selected then
                g.setColor(c.accent[1], c.accent[2], c.accent[3], c.selectedAlpha)
                g.rectangle("fill", x, y, w, h)
            end
            g.setColor(c.accent)
            g.rectangle("line", x, y, w, h)
            local label = (selected and "ADDED" or verb) .. " +" .. amount
            if font:getWidth(label) + 4 > w then label = (selected and "[+] " or "+") .. amount end
            local badge = font:getWidth(label) + 4
            g.setColor(c.background)
            g.rectangle("fill", x + w - badge, y, badge, math.min(h, font:getHeight() + 4))
            g.setColor(c.accent)
            g.print(label, x + w - badge + 2, y + 2)
        end
        for _, entry in ipairs(hand.entries) do
            local amount = self:contribution(entry.card)
            local selected = self.selected[entry.card.instanceId]
            local height = math.min(hand.settings.height, hand.step > 0 and hand.step or hand.settings.height)
            highlight(entry.x, entry.y, hand.width, height, amount, selected, "COMMIT")
        end
        if self.equipment then
            for _, option in ipairs(self.exhaustOptions or {}) do
                local asset = option.asset
                local x, y, w, h = self.equipment:bounds(asset.start, asset.size)
                highlight(x, y, w, h, option.amount, self.exhaustSelected[asset.instanceId], "EXHAUST")
            end
        end
    end
    local tiles,capacity,total = self:reserveTiles()
    local hoverName
    for _,tile in ipairs(tiles) do
        local definition = self.session.fatePool.definitions[tile.entry.tileId]
        local selected = self.bonusSelected and self.bonusSelected[tile.entry]
        local hovered = inside(self.pointerX,self.pointerY,tile)
        if hovered then
            local cost = Tile.costText(definition.extra_cost)
            hoverName = (definition.name or tile.entry.tileId) .. (cost and (" / COST  " .. cost) or "")
        end
        if selected then
            g.setColor(c.accent[1],c.accent[2],c.accent[3],c.selectedAlpha)
            g.rectangle("fill",tile.x,tile.y,tile.width,tile.height)
        end
        g.setColor(selected and c.accent or hovered and c.text or c.muted)
        if selected or hovered then g.rectangle("line",tile.x+0.5,tile.y+0.5,tile.width-1,tile.height-1) end
        g.printf(string.format("%+g",require("src.sys.fate_tile_definition").modifier(definition)),
            tile.x,tile.y+1,tile.width,"center")
        local art = definition.img and self:loadImage(c.fateDirectory .. "/" .. tile.entry.tileId .. ".png")
        imageInBox(art,tile.x+math.floor((tile.width-c.fateIconSize)/2),tile.y+c.reserveValueHeight,c.fateIconSize,
            (definition.name or tile.entry.tileId):sub(1,3):upper())
        if not self.test then
            g.setColor(0,0,0,0.45); g.rectangle("fill",tile.x,tile.y,tile.width,tile.height)
        end
    end
    g.setColor(c.accent)
    local reserveText = total == 0 and "BONUS RESERVE: EMPTY" or "BONUS RESERVE / CLICK TILES TO COMMIT"
    if hoverName then reserveText = hoverName .. " / CLICK TO TOGGLE" end
    if total > capacity then reserveText = reserveText .. " / SCROLL " .. self.reserveFirst .. "-" .. (self.reserveFirst+#tiles-1) .. "/" .. total end
    g.printf(reserveText,self.x+14,self.y+263+offset,self.width-28,"center")
    if self.error or reason then g.setColor(c.failure); g.printf((self.error or reason):upper(), self.x + 14, self.y + c.errorTop + offset, self.width - 28, "center") end
    g.pop()
    local effectCard = self.engagementPreview and self.engagementPreview.card
    if effectCard then effectCard:draw() end
end
return Panel
