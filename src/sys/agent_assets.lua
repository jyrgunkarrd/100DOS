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
function Assets:remove(id, placement)
    local board = self.byAgent[id]
    for index, item in ipairs(board.placements) do
        if item == placement then
            table.remove(board.placements, index)
            for i = item.start, item.start + item.size - 1 do board.occupied[self.slots[i]] = nil end
            return
        end
    end
end
function Assets:applyHarm(id, events, piles, definitions)
    for _, event in ipairs(events) do
        for _, hit in ipairs(event.assetHits) do
            local after = hit.asset
            local placement = self:at(id, after.start)
            local definition = definitions.byId[after.cardId]
            hit.name = definition.name or after.cardId
            placement.health, placement.defiance = after.health, after.defiance
            if hit.destroyed then
                self:remove(id, placement)
                piles.discardPile = piles.discardPile or {}
                table.insert(piles.discardPile, placement.card)
            end
        end
    end
end
return Assets
