local CardVfx = require("src.sys.card_outcome_vfx")
local VfxData = require("data.card_outcome_vfx")
local FateTile = require("src.ui.fate_tile")
local Feedback = {}
Feedback.__index = Feedback
-- Reveal the bottom-left triangle first, then sweep its diagonal edge right.
-- Pixel clipping works on both the window and canvases without a stencil buffer.
local wipeSource = [[
    extern vec2 wipeOrigin;
    extern vec2 wipeSize;
    extern number wipeProgress;
    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 pixel) {
        vec2 position = (pixel - wipeOrigin) / wipeSize;
        if (position.x + 1.0 - position.y > 2.0 * wipeProgress) discard;
        return Texel(texture, uv) * color;
    }
]]
function Feedback.new(cutin, preview, portrait, agentId, session)
    local c = require("data.talent_test_view")
    CardVfx.validate(VfxData, c.holdDuration)
    for _, key in ipairs({ "evadeDuration", "interactionDuration", "failureDuration" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid outcome " .. key)
    end
    assert(type(c.resultSoundDelay) == "number" and c.resultSoundDelay >= 0
        and c.resultSoundDelay < c.holdDuration, "Invalid test result sound delay")
    local style = {}
    for key, value in pairs(cutin.settings) do style[key] = value end
    style.enterDuration, style.exitDuration = c.enterDuration, c.exitDuration
    local timing = {}
    for key, value in pairs(require("data.attack_feedback_view")) do timing[key] = value end
    timing.hitTime = c.enterDuration + c.drawDuration
    timing.stepDuration = timing.hitTime + c.holdDuration + c.exitDuration
    timing.defeatHold = 0
    local shared = require("src.ui.attack_cutin").new(style, timing)
    shared:bind(preview, portrait, agentId)
    local sounds = { reveal = c.revealSound, success = c.successSound, failure = c.failureSound }
    sounds.armyCasualty = require("data.battlefield_engagement_view").casualtySound
    sounds.milling = require("data.location_milling_view").sound
    if session then
        local agent = session.agentCards.agents.byId[agentId]
        if agent.atk_sfx then sounds.strike = "assets/audio/sfx/atk/" .. agent.atk_sfx .. ".wav" end
        for id, definition in pairs(session.locationCardPool.byId) do
            if definition.defeat_sfx then sounds["defeat:" .. id] = "assets/audio/sfx/def/" .. definition.defeat_sfx .. ".wav" end
        end
    end
    local wipe = love.graphics.newShader(wipeSource)
    local audio = require("src.sys.audio_controller").new(sounds)
    local fateAssets = require("src.sys.artwork_assets").new()
    if session and session.audio then audio:setVolume(session.audio.volume) end
    return setmetatable({ settings = timing, view = c, cutin = shared, characterCutin = shared,
        session = session, elapsed = 0, talent = true, audio = audio, wipe = wipe, fateAssets = fateAssets }, Feedback)
end
function Feedback:start(record)
    self.cutin = self.characterCutin
    self.fateImage = record.fate and record.fate.img
        and self.fateAssets:load(self.view.fateDirectory .. "/" .. record.tileId .. ".png") or nil
    self.casualtySoundTime, self.casualtySounded = nil, false
    self.outcomeProfile, self.outcomeImage, self.millingStart = nil, nil, nil
    self.millingSounded = false
    self.scanStart = nil
    self.settings.hitTime = self.view.enterDuration + (record.test and self.view.drawDuration or 0)
    self.settings.stepDuration = self.settings.hitTime + self.view.holdDuration + self.view.exitDuration
    if record.armiesBefore then
        self.armyCutin = self.armyCutin or require("src.ui.battlefield_engagement_cutin").new(self.characterCutin, self.session)
        self.armyCutin.settings.reducedMotion = self.characterCutin.settings.reducedMotion
        self.cutin = self.armyCutin
        local combatDuration = self.armyCutin:bindRecord(record)
        for _, side in ipairs({ "enemy", "allied" }) do
            if #record.sides[side].removed > 0 then
                local time = self.settings.hitTime + self.armyCutin.timelines[side].casualtyStart
                    + self.armyCutin.view.liftDuration + self.armyCutin.view.casualtyHold
                self.casualtySoundTime = math.min(self.casualtySoundTime or time, time)
            end
        end
        self.settings.stepDuration = self.settings.hitTime + combatDuration + self.view.exitDuration
        if record.milling and record.milling.requested > 0 then
            self.millingView = self.millingView or require("src.ui.location_milling_feedback").new(self.session)
            self.millingStart = self.settings.hitTime + combatDuration
            self.settings.stepDuration = self.settings.stepDuration + self.millingView:bind(record.milling)
        end
        self.locationImage = nil
    elseif record.battlefield then
        self.battlefieldAssets = self.battlefieldAssets or require("src.sys.artwork_assets").new()
        self.locationImage = self.battlefieldAssets:load("assets/images/locations/" .. record.locationId .. ".png")
    else self.locationImage = nil end
    if record.scan then
        self.scanStart = self.settings.hitTime + self.view.holdDuration
        self.settings.stepDuration = self.settings.stepDuration + require("data.jacl_action_view").scanDuration
    end
    local profile, art = CardVfx.resolve(record, VfxData)
    if profile then
        self.outcomeProfile = profile
        self.battlefieldAssets = self.battlefieldAssets or require("src.sys.artwork_assets").new()
        self.outcomeImage = self.battlefieldAssets:load(art)
    end
    self.result, self.record, self.elapsed, self.sounded = record, { events = { record }, agentId = record.agentId }, 0, false
    self.resultSounded, self.revealSounded = false, false
end
function Feedback:busy() return self.record ~= nil end
function Feedback:current()
    if self.record then return self.result, 1, self.elapsed >= self.settings.hitTime end
end
function Feedback:update(dt)
    if not self.record then return false end
    self.elapsed = self.elapsed + math.max(0, dt)
    if self.result.test and self.elapsed >= self.view.enterDuration and not self.revealSounded then
        self.revealSounded = true
        self.audio:playOverlapping("reveal")
    end
    if self.result.test and self.elapsed >= self.settings.hitTime and not self.sounded then
        self.sounded = true
        if self.result.success and self.result.test.kind == "strike" then
            self.audio:playOverlapping("strike")
            if self.result.defeated then self.audio:playOverlapping("defeat:" .. self.result.cardId) end
        end
    end
    if self.result.test and self.elapsed >= self.settings.hitTime + self.view.resultSoundDelay and not self.resultSounded then
        self.resultSounded = true
        self.audio:playOverlapping(self.result.success and "success" or "failure")
    end
    if self.casualtySoundTime and self.elapsed >= self.casualtySoundTime and not self.casualtySounded then
        self.casualtySounded = true
        self.audio:playOverlapping("armyCasualty")
    end
    if self.millingStart and self.elapsed >= self.millingStart and not self.millingSounded then
        self.millingSounded = true
        self.audio:playOverlapping("milling")
    end
    self.audio:update()
    return self.elapsed >= self.settings.stepDuration
end
function Feedback:clear()
    self.casualtySoundTime, self.casualtySounded = nil, false
    self.result, self.record, self.fateImage = nil, nil, nil
    self.outcomeProfile, self.outcomeImage, self.locationImage = nil, nil, nil
    if self.armyCutin then self.armyCutin:clear() end
    if self.millingView then self.millingView:clear() end
    self.millingStart = nil
    self.millingSounded = false
    self.cutin = self.characterCutin
end
function Feedback:release()
    if self.armyCutin then self.armyCutin:release() end
    if self.millingView then self.millingView:release() end
    if self.battlefieldAssets then self.battlefieldAssets:release() end
    self:clear(); self.audio:release(); self.wipe:release()
    self.fateAssets:release()
end
-- Shared presentation values for the portraits and the fate tile. No game-state changes.
function Feedback:outcomePose()
    local r, c = self.result, self.view
    local age = self.elapsed - self.settings.hitTime
    local p = { artOffset = 0, trailAlpha = 0, brightness = 1, contentAlpha = 1,
        frameAlpha = 1, sweep = nil, failureFlash = 0, fateOffset = 0, linkAlpha = 0, linkGap = 0 }
    if not r or age < 0 then return p end
    local reduced = self.cutin.settings.reducedMotion
    if not r.success then
        local progress = math.min(1, age / c.failureDuration)
        p.failureFlash = 1 - progress
        p.fateOffset = reduced and 0 or math.sin(progress * math.pi * 4) * c.failureDistance * (1 - progress)
    elseif self.outcomeProfile then
        for key, value in pairs(require("src.ui.card_outcome_vfx").pose(age,
            self.outcomeProfile.duration, self.outcomeProfile)) do p[key] = value end
    elseif r.test.kind == "evade" then
        local progress = math.min(1, age / c.evadeDuration)
        p.evadeSweep = progress < 1 and progress or nil
        p.linkAlpha, p.linkGap = 1 - progress, reduced and 18 or 4 + progress * 40
    elseif r.test.kind ~= "strike" and not r.battlefield then
        for key, value in pairs(self.cutin:sweepPose(age, c.interactionDuration)) do p[key] = value end
    end
    return p
end
function Feedback:draw(width, height, font)
    if not self.record then return end
    if self.scanStart and self.elapsed >= self.scanStart then
        require("src.ui.jacl_panel").drawScan(self.session, self.result, self.elapsed - self.scanStart, self.session.scene.accents.small, self.characterCutin.settings.reducedMotion)
        return
    end
    if self.millingStart and self.elapsed >= self.millingStart then
        local alpha = math.min(1, math.max(0, (self.settings.stepDuration - self.elapsed) / self.view.exitDuration))
        self.millingView:draw(self.elapsed - self.millingStart, width, height, font,
            self.characterCutin.settings.reducedMotion, alpha)
        return
    end
    self.cutin:draw(self, width, height, font)
    if not self.result.test then return end
    local c, g, r = self.view, love.graphics, self.result
    local pose = self.cutin:pose(self)
    local outcome = self:outcomePose()
    if self.elapsed < c.enterDuration then return end
    local progress = math.min(1, (self.elapsed - c.enterDuration) / c.drawDuration)
    local revealed = self.elapsed >= self.settings.hitTime
    local reduced = self.cutin.settings.reducedMotion
    local scale = math.min(1, (width - 48) / self.cutin.settings.width, (height - 48) / (self.cutin.settings.height + c.tileHeight + c.tileGap))
    local y = (height - self.cutin.settings.height * scale) / 2 - (c.tileHeight + c.tileGap) * scale
    g.push("all"); g.setFont(font)
    g.translate(width / 2 + outcome.fateOffset * scale, y + c.tileHeight * scale / 2); g.scale(scale, scale)
    local color = (revealed or not reduced) and (r.success and c.accent or c.failure) or c.muted
    if revealed then
        local phase = reduced and 0 or ((self.elapsed - self.settings.hitTime) % c.haloDuration) / c.haloDuration
        local expansion = reduced and 3 or c.haloSpread * phase
        local alpha = pose.alpha * c.haloAlpha * (1 - phase) ^ 2
        -- Sharp-cornered rings radiate from the tile; the tile and text stay still.
        for _, stroke in ipairs({ { 8, 0.12 }, { 4, 0.25 }, { 1, 1 } }) do
            g.setLineWidth(stroke[1])
            g.setColor(color[1], color[2], color[3], alpha * stroke[2])
            g.rectangle("line", -c.tileWidth / 2 - expansion, -c.tileHeight / 2 - expansion,
                c.tileWidth + expansion * 2, c.tileHeight + expansion * 2)
        end
        g.setLineWidth(1)
    end
    if not revealed and not reduced then
        local left, top = g.transformPoint(-c.tileWidth / 2, -c.tileHeight / 2)
        local right, bottom = g.transformPoint(c.tileWidth / 2, c.tileHeight / 2)
        self.wipe:send("wipeOrigin", { left, top })
        self.wipe:send("wipeSize", { right - left, bottom - top })
        self.wipe:send("wipeProgress", progress)
        g.setShader(self.wipe)
    end
    g.setColor(c.background[1], c.background[2], c.background[3], pose.alpha)
    g.rectangle("fill", -c.tileWidth / 2, -c.tileHeight / 2, c.tileWidth, c.tileHeight)
    g.setColor(color[1], color[2], color[3], pose.alpha)
    g.rectangle("line", -c.tileWidth / 2, -c.tileHeight / 2, c.tileWidth, c.tileHeight)
    local showTile = revealed or not reduced
    FateTile.draw(showTile and r, showTile and self.fateImage, c, font, color, pose.alpha)
    g.pop()
end
return Feedback
