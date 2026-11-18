local Defaults = require("data.artwork_defaults")
local Assets = {}
Assets.__index = Assets
local cache = {}

-- Each view borrows a path once. The last owner releases it, including across
-- overlapping reroll candidates and state handoffs. Failed loads are cached too.
function Assets.new(diagnostics)
    return setmetatable({ paths = {}, diagnostics = diagnostics or {} }, Assets)
end

function Assets:load(path)
    if not path then return nil end
    local entry = cache[path]
    if not self.paths[path] then
        if not entry then
            local ok, image = pcall(love.graphics.newImage, path)
            entry = { image = ok and image or false, owners = 0 }
            cache[path] = entry
            if ok then image:setFilter(Defaults.filter, Defaults.filter) end
        end
        entry.owners = entry.owners + 1
        self.paths[path] = true
        if not entry.image then
            self.diagnostics[#self.diagnostics + 1] = "Cannot load artwork layer: " .. path
        end
    end
    return entry.image or nil
end

function Assets:prepare(paths)
    return { background = self:load(paths.background), foreground = self:load(paths.foreground) }
end

function Assets:release()
    for path in pairs(self.paths) do
        local entry = cache[path]
        entry.owners = entry.owners - 1
        if entry.owners == 0 then
            if entry.image then entry.image:release() end
            cache[path] = nil
        end
    end
    self.paths = {}
end

return Assets
