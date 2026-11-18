local Controller = {}
Controller.__index = Controller
function Controller.new(playerCard, location, audio, agentName)
    return setmetatable({ views = { player_card = playerCard, location = location }, audio = audio, agentName = agentName }, Controller)
end
function Controller:show(source, instance, silent)
    if not instance then source = nil end
    local changed = source ~= self.source or (instance and self.cardId ~= instance.cardId)
    for key, view in pairs(self.views) do
        local engagementText
        if key == source and source == "location" and instance.engagedAgentId then
            local name = self.agentName and self.agentName(instance.engagedAgentId) or instance.engagedAgentId
            engagementText = (view.settings.engagementLabel or "ENGAGED WITH ") .. name
        end
        local runtimeHealth
        if key == source and source == "location" then
            runtimeHealth = instance.health
            if instance.exhausted then engagementText = "EXHAUSTED" end
        end
        view:show(key == source and instance.cardId or nil, engagementText, runtimeHealth)
    end
    if changed and source then
        self.views[source].scroll = 0
        if self.audio and not silent then self.audio:playOverlapping("cardView") end
    end
    self.source, self.instanceId, self.cardId = source, instance and instance.instanceId, instance and instance.cardId
end
function Controller:clear() self:show(nil, nil) end
function Controller:wheelmoved(y)
    if not self.source then return false end
    self.views[self.source]:wheelmoved(y)
    return true
end
function Controller:draw()
    if self.source then self.views[self.source]:draw() end
end
function Controller:release()
    for _, view in pairs(self.views) do view:release() end
    self.source, self.instanceId, self.cardId, self.audio, self.agentName = nil, nil, nil, nil, nil
end
return Controller
