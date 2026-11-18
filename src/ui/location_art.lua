local Art = {}
Art.__index = Art

function Art.new(assignments, cells, settings)
    assert(type(settings) == "table" and type(settings.directory) == "string",
        "Location artwork requires a directory")
    assert(settings.filter == "nearest" or settings.filter == "linear", "Invalid location artwork filter")
    local self = setmetatable({ images = {}, meshes = {}, assigned = {}, diagnostics = {} }, Art)
    local ok, failure = pcall(function()
        for _, cell in ipairs(cells) do
            local id = assignments[cell.id]
            if id then
                self.assigned[cell.id] = id
                if self.images[id] == nil then
                    local path = settings.directory .. "/" .. id .. ".png"
                    local loaded, image = pcall(love.graphics.newImage, path)
                    self.images[id] = loaded and image or false
                    if loaded then image:setFilter(settings.filter, settings.filter)
                    else self.diagnostics[#self.diagnostics + 1] = "Cannot load location image: " .. path end
                end
                local image = self.images[id]
                if image then
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    for i = 1, #cell.vertices, 2 do
                        minX, maxX = math.min(minX, cell.vertices[i]), math.max(maxX, cell.vertices[i])
                        minY, maxY = math.min(minY, cell.vertices[i + 1]), math.max(maxY, cell.vertices[i + 1])
                    end
                    local iw, ih = image:getDimensions()
                    local scale = math.max((maxX - minX) / iw, (maxY - minY) / ih)
                    local w, h = iw * scale, ih * scale
                    local left, top = cell.x - w / 2, cell.y - h / 2
                    local vertices = {}
                    for i = 1, #cell.vertices, 2 do
                        local x, y = cell.vertices[i], cell.vertices[i + 1]
                        vertices[#vertices + 1] = { x, y, (x - left) / w, (y - top) / h }
                    end
                    -- A textured hex mesh clips precisely without a stencil buffer.
                    local mesh = love.graphics.newMesh(vertices, "fan", "static")
                    self.meshes[cell.id] = mesh
                    mesh:setTexture(image)
                end
            end
        end
    end)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Art:draw(cell)
    local g = love.graphics
    if self.meshes[cell.id] then
        g.setColor(1, 1, 1, 1)
        g.draw(self.meshes[cell.id])
    elseif self.assigned[cell.id] then
        -- An understated marker distinguishes missing artwork from an empty cell.
        g.setColor(0.34, 0.39, 0.39, 1)
        g.line(cell.x - 6, cell.y - 6, cell.x + 6, cell.y + 6)
        g.line(cell.x - 6, cell.y + 6, cell.x + 6, cell.y - 6)
    end
end

function Art:release()
    for _, mesh in pairs(self.meshes) do mesh:release() end
    for _, image in pairs(self.images) do if image then image:release() end end
    self.meshes, self.images, self.assigned = {}, {}, {}
end

return Art
