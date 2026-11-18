local Index = {}

function Index.refresh(root, filesystem)
    root, filesystem = root or "data/army_lists", filesystem or love.filesystem
    local result = {}
    for _, side in ipairs({ "allied", "enemy" }) do
        local path = root .. "/" .. side .. "_army.lua"
        local chunk, message = filesystem.load(path)
        assert(chunk, message)
        local definitions = chunk()
        assert(type(definitions) == "table", "Army list must return a table: " .. path)
        local list = { ids = {}, byId = {} }
        for id, slots in pairs(definitions) do
            assert(type(id) == "string" and id:match("%S"), "Invalid army ID in " .. path)
            assert(type(slots) == "table" and #slots > 0, "Empty army: " .. id)
            for key, slot in pairs(slots) do
                assert(type(key) == "number" and key >= 1 and key <= #slots and key % 1 == 0,
                    "Army slots must be an array: " .. id)
                assert(type(slot) == "table" and (slot.str == "regular" or slot.str == "elite"), "Invalid army strength: " .. id)
                assert(type(slot.qty) == "number" and slot.qty > 0 and slot.qty < math.huge and slot.qty % 1 == 0,
                    "Invalid army quantity: " .. id)
            end
            list.ids[#list.ids + 1], list.byId[id] = id, slots
        end
        table.sort(list.ids)
        result[side] = list
    end
    return result
end

return Index
