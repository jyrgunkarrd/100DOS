local Artwork = require("src.ui.layered_artwork")
local ArtworkResolver = require("src.sys.artwork_resolver")
local ArtworkAssets = require("src.sys.artwork_assets")
local AssetSlots = require("src.ui.preview_asset_slots")
local Display = require("src.sys.card_display")
local HealthDefiance = require("src.ui.health_defiance")
local SlotStyle = require("data.agent_equipment_view")
local FormattedText = require("src.ui.formatted_text")
local Preview = {}
Preview.__index = Preview

function Preview.new(definitions, cards, settings, fonts, grid, height, normalize, biomeId)
    for _, key in ipairs({ "width", "top", "bottomMargin", "padding", "gap", "artSize", "iconSize", "iconGap", "costPipWidth", "costPipGap", "scrollStep", "footerSlotSize", "footerSlotGap" }) do
        local v = settings[key]
        assert(type(v) == "number" and v >= 0 and v < math.huge and v % 1 == 0, "Invalid preview " .. key)
    end
    assert(settings.iconSize > 0 and settings.artSize > 0 and settings.costPipWidth > 0, "Invalid preview image size")
    assert(settings.footerSlotSize >= 5, "Preview slot icon is too small")
    for _, key in ipairs({ "backgroundColor", "frameColor", "textColor", "mutedColor", "healthColor", "defianceColor" }) do
        assert(type(settings[key]) == "table", "Missing preview " .. key)
        for i = 1, 4 do
            local v = settings[key][i]
            assert(type(v) == "number" and v >= 0 and v <= 1, "Invalid preview " .. key)
        end
    end
    for _, key in ipairs({ "artDirectory", "methodDirectory", "talentDirectory" }) do
        assert(type(settings[key]) == "string", "Invalid preview " .. key)
    end
    local self = setmetatable({ settings = settings, fonts = fonts, displays = {}, images = {}, artPaths = {},
        layouts = {}, diagnostics = {}, scroll = 0,
        x = math.floor(grid.bounds.x + grid.bounds.width / 2 - settings.width / 2),
        y = settings.top, maxHeight = height - settings.top - settings.bottomMargin }, Preview)
    assert(settings.width - 2 * settings.padding >= settings.artSize + settings.iconSize + settings.gap
        and self.maxHeight > 2 * settings.padding + 32, "Preview does not fit")
    self.artworkAssets = ArtworkAssets.new(self.diagnostics)
    self.artwork = {}
    local ok, failure = pcall(function()
        assert(type(settings.rulesFont) == "string" and type(settings.rulesFontSize) == "number"
            and settings.rulesFontSize > 0 and settings.rulesFontSize < math.huge, "Invalid preview rules font")
        self.rulesFont = love.graphics.newFont(settings.rulesFont, settings.rulesFontSize)
        self.rulesFont:setFilter("nearest", "nearest")
        for _, instance in ipairs(cards) do
            local id = instance.cardId
            self:prepareCard(id, definitions.byId[id], normalize, biomeId)
        end
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Preview:prepareCard(id, definition, normalize, biomeId)
    if self.displays[id] then return end
    local c = self.settings
    local d = (normalize or Display.normalize)(assert(definition, "Unknown preview card"))
    local path = (c.artPath or ArtworkResolver.cardPath)(definition, id, c.artDirectory)
    self.artwork[id] = self.artworkAssets:prepare(ArtworkResolver.resolve(definition, biomeId))
    self:load(path)
    for _, method in ipairs(d.methods) do self:load(c.methodDirectory .. "/" .. method .. ".png") end
    for _, talent in ipairs(d.talents) do self:load(c.talentDirectory .. "/" .. talent .. ".png") end
    for _, test in ipairs(d.tests or {}) do self:load(c.talentDirectory .. "/" .. test.type .. ".png") end
    self.artPaths[id], self.layouts[id], self.displays[id] = path, self:layout(d), d
end

function Preview:load(path)
    if self.images[path] ~= nil then return end
    local ok, image = pcall(love.graphics.newImage, path)
    self.images[path] = ok and image or false
    if ok then image:setFilter("nearest", "nearest")
    else self.diagnostics[#self.diagnostics + 1] = "Cannot load card preview image: " .. path end
end

local function textHeight(font, text, width)
    if text == "" then return 0 end
    local _, lines = font:getWrap(text, width)
    return math.ceil(font:getHeight() * (1 + (#lines - 1) * font:getLineHeight()))
end

function Preview:layout(d)
    local c, f = self.settings, self.fonts
    local w = c.width - 2 * c.padding
    local l = { width = w, headerY = c.padding }
    local naturalPips = d.cost > 0 and d.cost * c.costPipWidth + (d.cost - 1) * c.costPipGap or 0
    local pipScale = naturalPips > 0 and math.min(1, (w / 2) / naturalPips) or 1
    l.pipWidth, l.pipGap, l.pipsWidth = c.costPipWidth * pipScale, c.costPipGap * pipScale, naturalPips * pipScale
    l.nameWidth = w - (d.cost > 0 and l.pipsWidth + c.gap or 0)
    l.nameHeight = textHeight(f.heading, d.name, l.nameWidth)
    l.pipHeight = c.padding + l.nameHeight
    local y = l.pipHeight + c.gap
    local hasType = d.type and d.type ~= ""
    l.typeWidth = hasType and math.min(math.floor(w / 3), f.small:getWidth(d.type)) or 0
    local methodWidth = w - (hasType and l.typeWidth + c.gap or 0)
    l.methodsY, l.methodsPerRow = y, math.max(1, math.floor((methodWidth + c.iconGap) / (c.iconSize + c.iconGap)))
    local methodHeight = #d.methods > 0 and math.ceil(#d.methods / l.methodsPerRow) * (c.iconSize + c.iconGap) - c.iconGap or 0
    local typeHeight = hasType and textHeight(f.small, d.type, l.typeWidth) or 0
    if hasType then l.typeY = y + math.max(0, math.floor((math.min(methodHeight, c.iconSize) - typeHeight) / 2)) end
    local rowHeight = math.max(typeHeight, methodHeight)
    if rowHeight > 0 then y = y + rowHeight + c.gap end
    if d.engagementText then
        l.engagementY = y
        y = y + textHeight(f.small, d.engagementText, w) + c.gap
    end
    l.artY = y
    local artHeight = math.max(c.artSize, #d.talents * (c.iconSize + c.iconGap) - c.iconGap)
    if d.assetSlots then
        assert(not c.centerArtwork and #d.talents == 0, "Asset slots need the portrait sidebar")
        l.assetSlots = AssetSlots.layout(d.assetSlots, c.assetSlots, f.small)
        assert(l.assetSlots.width + c.assetSlots.portraitGap + c.artSize <= w, "Asset slots do not fit preview")
        artHeight = math.max(artHeight, l.assetSlots.height)
    end
    y = y + artHeight + c.gap
    if d.tests and #d.tests > 0 then
        assert(type(c.testHeading) == "string" and type(c.talentLabels) == "table", "Missing talent test presentation")
        l.testsY, l.testRows = y, {}
        y = y + textHeight(f.small, c.testHeading, w) + c.gap
        local columns, columnGap = c.testColumns or 1, c.testColumnGap or c.gap
        assert(columns >= 1 and columns % 1 == 0 and columnGap >= 0, "Invalid talent columns")
        local rows = math.ceil(#d.tests / columns)
        local columnWidth = (w - (columns - 1) * columnGap) / columns
        local valueFont = f[c.testValueFont or "heading"]
        assert(valueFont, "Invalid talent value font")
        local heights = {}
        for i, test in ipairs(d.tests) do
            local label = test.label or c.talentLabels[test.type] or test.type:gsub("_", " "):upper()
            local value = tostring(test.value)
            local valueColor
            if test.modifier and test.modifier ~= 0 then
                value = string.format("%+d  %s", test.modifier, value)
                valueColor = test.modifier > 0 and c.talentBonusColor or c.talentPenaltyColor
            end
            local valueWidth = valueFont:getWidth(value)
            local labelWidth = columnWidth - c.iconSize - c.gap * 2 - valueWidth
            assert(labelWidth > 0, "Talent test value does not fit preview")
            local rowIndex = (i - 1) % rows + 1
            local rowHeight = math.max(c.iconSize, textHeight(f.small, label, labelWidth), valueFont:getHeight())
            heights[rowIndex] = math.max(heights[rowIndex] or 0, rowHeight)
            l.testRows[i] = { x = math.floor((i - 1) / rows) * (columnWidth + columnGap),
                width = columnWidth, label = label, value = value, valueColor = valueColor, labelWidth = labelWidth, valueWidth = valueWidth }
        end
        local positions = {}
        for row = 1, rows do positions[row] = y; y = y + heights[row] + c.gap end
        for i, row in ipairs(l.testRows) do
            local rowIndex = (i - 1) % rows + 1
            row.y, row.height = positions[rowIndex], heights[rowIndex]
        end
    end
    l.tags = table.concat(d.tags, " / "):upper()
    if l.tags ~= "" then l.tagsY = y; y = y + textHeight(f.small, l.tags, w) + c.gap end
    if d.summary then
        l.summaryY = y
        y = y + f.small:getHeight() + c.gap
    end
    local paragraphs = {}
    l.coloredRules = {}
    for index, p in ipairs(d.paragraphs) do
        local plain, colored = FormattedText.parse(p.text, c.textColor)
        paragraphs[#paragraphs + 1] = plain
        if index > 1 then
            l.coloredRules[#l.coloredRules + 1] = c.textColor
            l.coloredRules[#l.coloredRules + 1] = "\n\n"
        end
        for _, segment in ipairs(colored) do l.coloredRules[#l.coloredRules + 1] = segment end
    end
    if #l.coloredRules == 0 then l.coloredRules = { c.textColor, "" } end
    l.rules = table.concat(paragraphs, "\n\n")
    l.rulesY, l.rulesHeight = y, textHeight(self.rulesFont, l.rules, w)
    if d.hint then
        l.rulesHintY = l.rulesHeight + (l.rulesHeight > 0 and c.gap or 0)
        l.rulesHeight = l.rulesHintY + textHeight(f.small, d.hint, w)
    end
    l.healthText, l.defianceText = tostring(d.health), tostring(d.defiance)
    l.hasStats = d.showStats or d.health > 0 or d.defiance > 0
    l.statsWidth = l.hasStats and HealthDefiance.width(f.heading, d.health, d.defiance) or 0
    l.footerHeight = math.max(d.slots > 0 and c.footerSlotSize or 0, l.hasStats and f.heading:getHeight() or 0)
    if d.stats then
        l.hasStats, l.statsWidth = #d.stats > 0, 0
        l.statRows = {}
        local statsY, previousGroup = 0, nil
        local groupGap = c.statGroupGap or 0
        assert(type(groupGap) == "number" and groupGap >= 0 and groupGap < math.huge,
            "Invalid preview statGroupGap")
        local pair = c.statPair
        local paired = {}
        local function statText(stat)
            local label = (c.statLabels and c.statLabels[stat.key]) or stat.key:upper()
            return label .. " " .. stat.value
        end
        for _, stat in ipairs(d.stats) do
            if pair and (stat.key == pair.left or stat.key == pair.right) then
                paired[stat.key] = stat
            else
                if previousGroup and stat.group and previousGroup ~= stat.group then statsY = statsY + groupGap end
                previousGroup = stat.group
                local value = statText(stat)
                l.statRows[#l.statRows + 1] = { text = value, key = stat.key, y = statsY, x = 0, width = w }
                statsY = statsY + textHeight(f.heading, value, w) + c.gap
            end
        end
        if next(paired) then
            if #l.statRows > 0 then statsY = statsY + groupGap end
            local columnWidth = (w - c.gap) / 2
            local rowHeight = 0
            for _, side in ipairs({ "left", "right" }) do
                local stat = paired[pair[side]]
                if stat then
                    local value = statText(stat)
                    rowHeight = math.max(rowHeight, textHeight(f.heading, value, columnWidth))
                    l.statRows[#l.statRows + 1] = { text = value, key = stat.key, y = statsY,
                        x = side == "left" and 0 or w - columnWidth, width = columnWidth, align = side }
                end
            end
            statsY = statsY + rowHeight + c.gap
        end
        l.footerHeight = #d.stats > 0 and statsY - c.gap or 0
    end
    l.rulesViewport = l.rulesHeight
    local footerGap = l.footerHeight > 0 and c.gap or 0
    local naturalHeight = y + l.rulesHeight + footerGap + l.footerHeight + c.padding
    l.height = math.min(self.maxHeight, naturalHeight)
    l.hintHeight = 0
    if naturalHeight > self.maxHeight then
        l.hintHeight = f.small:getHeight() + c.gap
        l.rulesViewport = self.maxHeight - y - footerGap - l.footerHeight - c.padding - l.hintHeight
        -- Extremely large headers/icon lists scroll as a whole rather than escaping the screen.
        if l.rulesViewport < self.rulesFont:getHeight() * 2 then
            l.wholeScroll = true
            l.rulesViewport = l.rulesHeight
            l.overflow = naturalHeight - (self.maxHeight - l.hintHeight)
        else l.overflow = l.rulesHeight - l.rulesViewport end
    end
    l.footerY = y + l.rulesViewport + footerGap
    return l
end

function Preview:show(cardId, engagementText, runtimeHealth, runtimeDefiance)
    if self.cardId ~= cardId or self.engagementText ~= engagementText or self.runtimeHealth ~= runtimeHealth or self.runtimeDefiance ~= runtimeDefiance then
        self.cardId, self.scroll, self.engagementText = cardId, 0, engagementText
        self.runtimeHealth, self.runtimeDefiance = runtimeHealth, runtimeDefiance
        self.instanceDisplay, self.instanceLayout = nil, nil
        if cardId and (engagementText or runtimeHealth ~= nil) then
            local display = {}
            for key, value in pairs(self.displays[cardId]) do display[key] = value end
            display.engagementText = engagementText
            if runtimeDefiance ~= nil then
                display.health, display.defiance = runtimeHealth, runtimeDefiance
            end
            if runtimeHealth ~= nil and display.stats then
                local stats = {}
                for i, stat in ipairs(display.stats) do
                    stats[i] = { key = stat.key, group = stat.group, value = stat.key == "health" and runtimeHealth or stat.value }
                end
                display.stats = stats
            end
            self.instanceDisplay, self.instanceLayout = display, self:layout(display)
        end
    end
end

function Preview:wheelmoved(y)
    local l = self.instanceLayout or (self.cardId and self.layouts[self.cardId])
    if l then self.scroll = math.max(0, math.min(l.overflow or 0, self.scroll - y * self.settings.scrollStep)) end
end

function Preview:drawImage(path, x, y, size)
    local g, image = love.graphics, self.images[path]
    if image then
        local scale = math.min(1, size / image:getWidth(), size / image:getHeight())
        g.setColor(1, 1, 1, 1)
        g.draw(image, math.floor(x + (size - image:getWidth() * scale) / 2),
            math.floor(y + (size - image:getHeight() * scale) / 2), 0, scale, scale)
    else
        g.setColor(self.settings.frameColor)
        g.rectangle("line", x + 0.5, y + 0.5, size - 1, size - 1)
        g.setFont(self.fonts.small)
        g.printf("?", x, y + math.floor((size - self.fonts.small:getHeight()) / 2), size, "center")
    end
end

function Preview:draw()
    local d = self.instanceDisplay or (self.cardId and self.displays[self.cardId])
    if not d then return end
    local g, c, f, l = love.graphics, self.settings, self.fonts, self.instanceLayout or self.layouts[self.cardId]
    g.push("all")
    g.setColor(c.frameColor); g.rectangle("fill", self.x, self.y, c.width, l.height)
    g.setColor(c.backgroundColor); g.rectangle("fill", self.x + 1, self.y + 1, c.width - 2, l.height - 2)
    g.push("all")
    g.intersectScissor(self.x + 1, self.y + 1, c.width - 2, l.height - 2 - l.hintHeight)
    local x, y = self.x + c.padding, self.y - (l.wholeScroll and self.scroll or 0)
    local function text(value, font, tx, ty, width, color)
        g.setFont(font); g.setColor(color or c.textColor); g.printf(value, tx, ty, width, "left")
    end
    text(d.name, f.heading, x, y + l.headerY, l.nameWidth)
    g.setColor(c.frameColor)
    for i = 1, d.cost do
        g.rectangle("fill", x + l.width - l.pipsWidth + (i - 1) * (l.pipWidth + l.pipGap), y, l.pipWidth, l.pipHeight)
    end
    if l.typeY then text(d.type, f.small, x, y + l.typeY, l.typeWidth, c.mutedColor) end
    for i, method in ipairs(d.methods) do
        local rowStart = math.floor((i - 1) / l.methodsPerRow) * l.methodsPerRow
        local rowCount = math.min(l.methodsPerRow, #d.methods - rowStart)
        local rowWidth = rowCount * c.iconSize + (rowCount - 1) * c.iconGap
        self:drawImage(c.methodDirectory .. "/" .. method .. ".png", x + l.width - rowWidth + ((i - 1) % l.methodsPerRow) * (c.iconSize + c.iconGap),
            y + l.methodsY + math.floor((i - 1) / l.methodsPerRow) * (c.iconSize + c.iconGap), c.iconSize)
    end
    if l.engagementY then
        text(d.engagementText, f.small, x, y + l.engagementY, l.width, c.engagementColor or c.textColor)
    end
    local artX = x
    for i, talent in ipairs(d.talents) do
        self:drawImage(c.talentDirectory .. "/" .. talent .. ".png", artX, y + l.artY + (i - 1) * (c.iconSize + c.iconGap), c.iconSize)
    end
    artX = c.centerArtwork and x + math.floor((l.width - c.artSize) / 2) or x + l.width - c.artSize
    Artwork.draw(self.artwork[self.cardId], artX, y + l.artY, c.artSize, c.artSize, function()
        self:drawImage(self.artPaths[self.cardId], artX, y + l.artY, c.artSize)
    end)
    if l.assetSlots then AssetSlots.draw(self, d.assetSlots, l.assetSlots, x, y + l.artY) end
    if l.testsY then
        text(c.testHeading, f.small, x, y + l.testsY, l.width, c.mutedColor)
        for i, test in ipairs(d.tests) do
            local row = l.testRows[i]
            local rowX, valueFont = x + row.x, f[c.testValueFont or "heading"]
            self:drawImage(c.talentDirectory .. "/" .. test.type .. ".png", rowX, y + row.y, c.iconSize)
            text(row.label, f.small, rowX + c.iconSize + c.gap, y + row.y + math.floor((row.height - textHeight(f.small, row.label, row.labelWidth)) / 2), row.labelWidth)
            text(row.value, valueFont, rowX + row.width - row.valueWidth, y + row.y + math.floor((row.height - valueFont:getHeight()) / 2), row.valueWidth, row.valueColor)
        end
    end
    if l.tagsY then text(l.tags, f.small, x, y + l.tagsY, l.width, c.mutedColor) end
    if l.summaryY then
        g.setFont(f.small); g.setColor(c.textColor)
        local left, right = d.summary.left, d.summary.right
        local totalWidth = f.small:getWidth(left) + f.small:getWidth(right) + c.gap
        local scale = math.min(1, l.width / math.max(1, totalWidth))
        g.setColor(d.summary.leftColor or c.textColor)
        g.print(left, x, y + l.summaryY, 0, scale, scale)
        g.setColor(c.textColor)
        g.print(right, x + l.width - f.small:getWidth(right) * scale, y + l.summaryY, 0, scale, scale)
    end
    g.push("all")
    g.intersectScissor(x, y + l.rulesY, l.width, l.rulesViewport)
    -- White avoids multiplying the tagged colors by the default text tint.
    text(l.coloredRules, self.rulesFont, x, y + l.rulesY - (l.wholeScroll and 0 or self.scroll), l.width, { 1, 1, 1, 1 })
    if d.hint then
        text(d.hint, f.small, x, y + l.rulesY + l.rulesHintY - (l.wholeScroll and 0 or self.scroll), l.width)
    end
    g.pop()
    if l.footerHeight > 0 then
        g.setColor(c.frameColor); g.rectangle("fill", x, y + l.footerY - math.floor(c.gap / 2), l.width, 1)
        -- Center the contents between the separator and the bottom padding edge.
        local footerY = y + l.footerY + math.floor((c.padding - math.floor(c.gap / 2)) / 2)
        -- Miniature versions of the asset row's frame, inset and solid block.
        g.push("all")
        local slotArea = math.max(0, l.width - l.statsWidth - (l.hasStats and c.gap or 0))
        g.intersectScissor(x + l.width - slotArea, footerY, slotArea, l.footerHeight)
        local slotsWidth = d.slots * c.footerSlotSize + math.max(0, d.slots - 1) * c.footerSlotGap
        for i = 1, d.slots do
            local sx = x + l.width - slotsWidth + (i - 1) * (c.footerSlotSize + c.footerSlotGap)
            local sy = footerY + math.floor((l.footerHeight - c.footerSlotSize) / 2)
            g.setColor(SlotStyle.frameColor)
            g.rectangle("fill", sx, sy, c.footerSlotSize, c.footerSlotSize)
            g.setColor(SlotStyle.backgroundColor)
            g.rectangle("fill", sx + 1, sy + 1, c.footerSlotSize - 2, c.footerSlotSize - 2)
            g.setColor(SlotStyle.frameColor)
            g.rectangle("fill", sx + 2, sy + 2, c.footerSlotSize - 4, c.footerSlotSize - 4)
        end
        g.pop()
        if d.stats then
            for _, stat in ipairs(l.statRows) do
                g.setFont(f.heading); g.setColor(c[stat.key .. "Color"] or c.textColor)
                g.printf(stat.text, x + stat.x, footerY + stat.y, stat.width, stat.align or "left")
            end
        elseif l.hasStats then
            local sx = x
            local sy = footerY + math.floor((l.footerHeight - f.heading:getHeight()) / 2)
            HealthDefiance.draw(f.heading, d.health, d.defiance, sx, sy, c)
        end
    end
    g.pop()
    if l.hintHeight > 0 then
        local hint = c.scrollHint or (l.wholeScroll and "SHIFT + WHEEL: SCROLL" or "SHIFT + WHEEL: RULES")
        text(hint, f.small, x, self.y + l.height - l.hintHeight, l.width, c.mutedColor)
    end
    g.pop()
end

function Preview:release()
    if self.artworkAssets then self.artworkAssets:release() end
    self.artwork = {}
    if self.rulesFont then self.rulesFont:release(); self.rulesFont = nil end
    for _, image in pairs(self.images) do if image then image:release() end end
    self.images, self.cardId = {}, nil
    self.instanceDisplay, self.instanceLayout, self.engagementText = nil, nil, nil
end
return Preview
