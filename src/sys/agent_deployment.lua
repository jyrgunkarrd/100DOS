local Deployment = {}
Deployment.__index = Deployment

function Deployment.new(agentIds, locations)
    local self = setmetatable({ agentIds = {}, known = {}, eligible = {}, placements = {} }, Deployment)
    for i, id in ipairs(agentIds) do
        assert(type(id) == "string" and not self.known[id], "Invalid or duplicate deployment agent")
        self.agentIds[i], self.known[id] = id, true
    end
    for cellId, locationId in pairs(locations) do
        if locationId then self.eligible[cellId] = true end
    end
    return self
end

function Deployment:assign(agentId, cellId)
    if not self.known[agentId] or (cellId ~= nil and not self.eligible[cellId]) then return false end
    self.placements[agentId] = cellId
    return true
end

function Deployment:occupants(cellId)
    local ids = {}
    for _, id in ipairs(self.agentIds) do
        if self.placements[id] == cellId then ids[#ids + 1] = id end
    end
    return ids
end

function Deployment:allAssigned()
    if #self.agentIds == 0 then return false end
    for _, id in ipairs(self.agentIds) do
        local cellId = self.placements[id]
        if not cellId or not self.eligible[cellId] then return false end
    end
    return true
end

return Deployment
