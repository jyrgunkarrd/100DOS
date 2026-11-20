local Assets = require("src.sys.artwork_assets")
local Resolver = require("src.sys.artwork_resolver")
local Artwork = require("src.ui.layered_artwork")
local Portraits = {}
Portraits.__index = Portraits
function Portraits.new(session)
    return setmetatable({ session = session, assets = Assets.new(), entries = {} }, Portraits)
end
function Portraits:entry(id)
    local definition = self.session.armies.catalogue.byId[id]
    local entry = self.entries[id]
    if not entry then
        entry = { image = self.assets:load(Resolver.forcePath(definition, id, require("data.battlefield_view").directory)),
            layers = self.assets:prepare(Resolver.resolve(definition, self.session.package.biomeId)) }
        self.entries[id] = entry
    end
    return entry
end
function Portraits:dimensions(id)
    local entry = self:entry(id)
    if entry.image then return entry.image:getDimensions() end
    return 176, 176
end
function Portraits:draw(id, x, y, size, tint)
    local entry = self:entry(id)
    local width, height = size, size
    if not size then width, height = self:dimensions(id) end
    local g = love.graphics
    Artwork.draw(entry.layers, x, y, width, height, function()
        g.setColor(tint or { 1, 1, 1, 1 })
        if entry.image then
            local w, h = entry.image:getDimensions()
            local scale = size and math.min(size / w, size / h) or 1
            g.draw(entry.image, math.floor(x + (width - w * scale) / 2), math.floor(y + (height - h * scale) / 2), 0, scale, scale)
        else g.printf("?", x, y + height / 2 - 4, width, "center") end
    end, tint)
end
function Portraits:release() self.assets:release(); self.entries = {} end
return Portraits
