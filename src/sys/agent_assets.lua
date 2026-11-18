local Assets = {}
Assets.__index = Assets
function Assets.new(ids, slots)
    local self = setmetatable({ slots = {}, byAgent = {} }, Assets)
    for i, slot in ipairs(slots) do self.slots[i] = slot.id end
    for _, id in ipairs(ids) do self.byAgent[id] = { placements = {}, occupied = {} } end
    return self
end
function Assets:fits(id, start, size)
    local board = self.byAgent[id]
    if not board or type(start) ~= "number" or start % 1 ~= 0 or start < 1
        or type(size) ~= "number" or size < 1 or size % 1 ~= 0 or start + size - 1 > #self.slots then return false end
    for i = start, start + size - 1 do if board.occupied[self.slots[i]] then return false end end
    return true
end
function Assets:findSpace(id, size)
    for start = 1, #self.slots do if self:fits(id, start, size) then return start end end
end
function Assets:at(id, index)
    local board = self.byAgent[id]
    return board and board.occupied[self.slots[index]]
end
return Assets
