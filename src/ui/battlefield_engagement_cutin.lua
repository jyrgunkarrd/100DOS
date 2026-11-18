local Stack = require("src.ui.army_stack_layout")
local Base = require("src.ui.attack_cutin")
local Cutin = {}
Cutin.__index = Cutin
local function clamp(x) return math.max(0, math.min(1, x)) end
local function ease(x) return 1 - (1 - clamp(x)) ^ 3 end
function Cutin.new(base, session)
    local view = require("data.battlefield_engagement_view")
    for _, key in ipairs({ "width", "height", "panelWidth", "padding", "stackTop", "stackHeight",
        "offsetX", "offsetY", "liftDistance", "liftHeight", "liftDuration", "destructionDuration",
        "casualtyHold", "casualtyStagger", "maxCascadeDuration", "protectionDuration", "settleDuration", "resultHold" }) do
        assert(type(view[key]) == "number" and view[key] > 0 and view[key] < math.huge, "Invalid engagement " .. key)
    end
    assert(view.width > view.panelWidth * 2 and view.stackTop + view.stackHeight < view.height,
        "Invalid engagement bounds")
    local settings = {}
    for key, value in pairs(base.settings) do settings[key] = value end
    settings.width, settings.height, settings.panelWidth = view.width, view.height, view.panelWidth
    return setmetatable({ settings = settings, view = view, session = session,
        portraits = require("src.ui.force_portraits").new(session) }, Cutin)
end
function Cutin:sweepPose(age, duration) return Base.sweepPose(self, age, duration) end
function Cutin:bindRecord(record)
    local c = self.view
    self.record, self.layouts, self.casualties, self.timelines = record, {}, {}, {}
    local finish = 0
    for _, side in ipairs({ "enemy", "allied" }) do
        local result = record.sides[side]
        local timeline = {}
        timeline.stagger = math.min(c.casualtyStagger, c.maxCascadeDuration / math.max(1, #result.removed - 1))
        timeline.casualtyStart = self.settings.impactDuration + (result.absorbed > 0 and c.protectionDuration or 0)
        timeline.casualtyEnd = timeline.casualtyStart + (#result.removed > 0
            and ((#result.removed - 1) * timeline.stagger + c.liftDuration + c.casualtyHold + c.destructionDuration) or 0)
        self.timelines[side] = timeline
        for i, unit in ipairs(result.removed) do
            self.casualties[unit.id] = timeline.casualtyStart + (i - 1) * timeline.stagger
        end
        finish = math.max(finish, timeline.casualtyEnd
            + (result.defeated and self.settings.defeatSweepDuration or c.settleDuration))
        local direction = side == "enemy" and 1 or -1
        local function build(snapshot)
            return Stack.build(snapshot[side].forces, function(id) return self.portraits:dimensions(id) end,
                c.panelWidth - c.padding * 2 - c.liftDistance, c.stackHeight, direction, c)
        end
        local slots, byId = build(record.armiesBefore)
        local _, after = build(record.armiesAfter)
        self.layouts[side] = { slots = slots, byId = byId, after = after, direction = direction }
    end
    return finish + c.resultHold
end
function Cutin:pose(feedback)
    local c, t = self.settings, feedback.settings
    local age = feedback.elapsed - t.hitTime
    local enter = ease(feedback.elapsed / c.enterDuration)
    local exit = clamp((feedback.elapsed - t.stepDuration + c.exitDuration) / c.exitDuration)
    return { alpha = enter * (1 - exit), age = age, hit = age >= 0,
        offset = c.reducedMotion and 0 or c.slideDistance * (1 - enter + exit),
        impact = age >= 0 and clamp(1 - age / c.impactDuration) or 0 }
end
function Cutin:casualtyPose(id, age)
    local start = self.casualties[id]
    if not start then return end
    local c = self.view
    local elapsed = age - start
    if elapsed < 0 then return end
    return { lift = ease(elapsed / c.liftDuration),
        destruction = clamp((elapsed - c.liftDuration - c.casualtyHold) / c.destructionDuration) }
end
function Cutin:draw(feedback, width, height, font)
    local r, c, s, g = self.record, self.view, self.settings, love.graphics
    local p = self:pose(feedback)
    local reduced = s.reducedMotion
    g.push("all"); g.setFont(font)
    g.setColor(0, 0, 0, s.dimAlpha * p.alpha); g.rectangle("fill", 0, 0, width, height)
    -- Native portrait pixels within the game's fixed virtual canvas.
    g.translate(math.floor((width - c.width) / 2), math.floor((height - c.height) / 2))
    local function color(tint, alpha) g.setColor(tint[1], tint[2], tint[3], (tint[4] or 1) * alpha) end
    local function label(text, x, y, w, tint, alpha)
        color(tint, alpha or p.alpha)
        g.printf(text, x, y, w, "center")
    end
    local panelX = {}
    for _, side in ipairs({ "enemy", "allied" }) do
        local layout = self.layouts[side]
        local direction = layout.direction
        local result, timeline = r.sides[side], self.timelines[side]
        local receiving = result.damage > 0
        local tint = side == "enemy" and s.enemyColor or s.agentColor
        local shake = receiving and not reduced and math.sin(p.age * 90) * s.shakeDistance * p.impact or 0
        local x = (side == "enemy" and 0 or c.width - c.panelWidth) - direction * p.offset + shake
        panelX[side] = x
        local defeat = receiving and result.defeated and p.age >= timeline.casualtyEnd
            and self:sweepPose(p.age - timeline.casualtyEnd, s.defeatSweepDuration) or nil
        local alpha = p.alpha * (defeat and defeat.contentAlpha or 1)
        color(s.background, alpha); g.rectangle("fill", x, 0, c.panelWidth, c.height)
        color(tint, p.alpha * (defeat and defeat.frameAlpha or 1))
        g.rectangle("fill", x, 0, c.panelWidth, 2); g.rectangle("fill", x, c.height - 2, c.panelWidth, 2)
        if side == "allied" and r.battlefieldKind == "bombard" then
            local jacl = self.session.scene and self.session.scene.jaclPreview
            label("JACL", x, 16, c.panelWidth, tint, alpha)
            label(jacl and jacl.name or "BOMBARDMENT", x, 36, c.panelWidth, feedback.settings.textColor, alpha)
            if jacl and jacl.image then
                g.setColor(1, 1, 1, alpha)
                g.draw(jacl.image, math.floor(x + (c.panelWidth - jacl.image:getWidth()) / 2),
                    math.floor((c.height - jacl.image:getHeight()) / 2), 0, -1, 1, jacl.image:getWidth(), 0)
            end
            label("FIRE SUPPORT", x, c.height - 37, c.panelWidth, tint, alpha)
        else
            label(c.labels[side], x, 16, c.panelWidth, tint, alpha)
            local complete = p.age >= timeline.casualtyEnd
            local army = (complete and r.armiesAfter or r.armiesBefore)[side]
            label(#army.forces .. " FORCES  /  STRENGTH " .. army.value, x, 36, c.panelWidth, feedback.settings.textColor, alpha)
            if side == "allied" then
                local protection = (p.age >= s.impactDuration and r.armiesAfter or r.armiesBefore).protection
                label(c.labels.protection .. " " .. protection, x, 56, c.panelWidth, tint, alpha)
            end
            local settle = reduced and 1 or ease((p.age - timeline.casualtyEnd) / c.settleDuration)
            local function card(slot, casualty)
                local unit, w, h = slot.unit, slot.width, slot.height
                local sx, sy = slot.x, slot.y
                local nextSlot = layout.after[unit.id]
                if p.age >= timeline.casualtyEnd and nextSlot then
                    sx, sy = sx + (nextSlot.x - sx) * settle, sy + (nextSlot.y - sy) * settle
                end
                local destruction = casualty and casualty.destruction or 0
                if destruction >= 1 then return end
                local lift = casualty and casualty.lift or 0
                if not reduced then sx, sy = sx + direction * c.liftDistance * lift, sy - c.liftHeight * lift end
                local cx = x + c.padding + (direction == -1 and c.liftDistance or 0) + sx
                local cy = c.stackTop + sy
                local opacity = alpha * (1 - destruction)
                g.push("all")
                g.translate(math.floor(cx), math.floor(cy + h / 2))
                local collapse = reduced and 1 or math.max(0.01, 1 - destruction * destruction)
                g.scale(1, collapse); g.translate(0, -h / 2)
                color(s.background, opacity); g.rectangle("fill", 0, 0, w, h)
                self.portraits:draw(unit.forceId, 0, 0, nil, { 1, 1, 1, opacity })
                color(unit.elite and c.eliteColor or tint, opacity)
                g.rectangle("line", 0, 0, w, h)
                if unit.elite then
                    color(s.background, opacity); g.rectangle("fill", 1, 1, 46, 14)
                    label(c.labels.elite, 1, 2, 46, c.eliteColor, opacity)
                end
                if destruction > 0 then
                    g.setColor(1, 0.9, 0.75, opacity * 0.65 * (1 - clamp(destruction * 4)))
                    g.rectangle("fill", 0, 0, w, h)
                end
                g.pop()
            end
            for _, slot in ipairs(layout.slots) do
                if not (receiving and self:casualtyPose(slot.unit.id, p.age)) then card(slot) end
            end
            -- Draw casualties above all survivors, in the actual rules removal order.
            local caption
            if receiving then
                for _, unit in ipairs(result.removed) do
                    local casualty = self:casualtyPose(unit.id, p.age)
                    if casualty and casualty.destruction < 1 then
                        local slot = layout.byId[unit.id]
                        card(slot, casualty); caption = slot.unit.name .. " - " .. c.labels.eliminated
                    end
                end
            end
            local front = layout.slots[#layout.slots]
            if complete then
                front = nil
                for _, slot in ipairs(layout.slots) do if layout.after[slot.unit.id] then front = slot end end
            end
            label(caption or (front and front.unit.name or ""), x + 10, c.height - 37, c.panelWidth - 20,
                feedback.settings.textColor, alpha)
            if p.hit then
                local text = result.damage .. " " .. c.labels.damage .. " / " .. #result.removed .. " " .. c.labels.lost
                if side == "allied" then text = text .. " / " .. result.absorbed .. " " .. c.labels.absorbed end
                label(text, x + 5, c.height - 18, c.panelWidth - 10, tint, p.alpha)
            end
            if receiving and p.impact > 0 then
                g.setColor(1, 1, 1, p.alpha * p.impact * (reduced and 0.08 or 0.22))
                g.rectangle("fill", x + 2, 2, c.panelWidth - 4, c.height - 4)
            end
            if receiving and result.absorbed > 0 and p.age >= 0 and p.age < timeline.casualtyStart then
                color(s.agentColor, p.alpha * (1 - p.age / timeline.casualtyStart))
                g.setLineWidth(3); g.rectangle("line", x + 5, 5, c.panelWidth - 10, c.height - 10); g.setLineWidth(1)
                label("ABSORBED " .. result.absorbed, x, c.height - 58, c.panelWidth, s.agentColor)
            end
            if defeat then
                color(s.enemyColor, alpha * 0.18); g.rectangle("fill", x + 2, 2, c.panelWidth - 4, c.height - 4)
                if not reduced and defeat.sweep < 1 then
                    color(s.enemyColor, alpha)
                    g.rectangle("fill", x + 2, 2 + (c.height - 4) * (1 - defeat.sweep), c.panelWidth - 4, 2)
                end
            end
        end
    end
    label((r.clash and c.labels.clash or c.labels[r.battlefieldKind] or c.labels.engage) .. "  /  " .. r.name, 0, -108, c.width, feedback.settings.textColor)
    label("VS", c.panelWidth, c.height / 2, c.width - c.panelWidth * 2, feedback.settings.textColor)
    if p.impact > 0 and not reduced then
        for _, side in ipairs({ "enemy", "allied" }) do
            if r.sides[side].damage > 0 then
                local target, source = panelX[side], panelX[side == "enemy" and "allied" or "enemy"]
                g.setColor(1, 0.8, 0.65, p.alpha * p.impact)
                g.polygon("fill", source + c.panelWidth / 2, c.height * 0.6,
                    target + c.panelWidth * 0.4, c.height * 0.25, target + c.panelWidth * 0.6, c.height * 0.35)
            end
        end
    end
    label(r.test.label .. " " .. r.difficulty, 0, c.height + 12, c.width, feedback.settings.textColor)
    if p.hit then
        local calculation = r.special and (r.success and "AUTO SUCCESS" or "AUTO FAILURE")
            or r.base .. " + " .. r.committed .. " " .. (r.modifier >= 0 and "+" or "-") .. " "
                .. math.abs(r.modifier) .. " = " .. r.total .. " vs " .. r.difficulty
        label(calculation, 0, c.height + 30, c.width, feedback.settings.textColor)
        local outcome = (r.success and "SUCCESS" or "FAILURE") .. " - " .. r.summary
        local defeated = {}
        for _, side in ipairs({ "enemy", "allied" }) do
            if r.sides[side].defeated and p.age >= self.timelines[side].casualtyEnd then defeated[#defeated + 1] = side end
        end
        if #defeated == 2 then outcome = outcome .. " - " .. c.labels.bothDefeated
        elseif #defeated == 1 then outcome = outcome .. " - " .. c.labels[defeated[1]] .. " " .. c.labels.defeated end
        label(outcome, 0, c.height + 50, c.width, r.success and s.agentColor or s.enemyColor)
    end
    g.pop()
end
function Cutin:clear() self.record, self.layouts, self.casualties, self.timelines = nil, nil, nil, nil end
function Cutin:release() self:clear(); self.portraits:release() end
return Cutin
