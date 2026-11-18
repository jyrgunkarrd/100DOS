local Defaults = require("data.artwork_defaults")
local Resolver = {}

-- Pure resolution: absent fields inherit; the literal string "none" disables.
function Resolver.resolve(definition, biomeId, settings)
    local c = settings or Defaults
    definition = definition or {}
    assert(biomeId == nil or (type(biomeId) == "string" and biomeId:match("^[%w_-]+$")),
        "Invalid artwork biome ID")
    local function layer(field, filename)
        local value = definition[field]
        if value == nil then
            return biomeId and (c.biomeDirectory .. "/" .. biomeId .. "/" .. filename) or nil
        end
        assert(type(value) == "string" and value:match("^[%w_-]+$"),
            "Invalid artwork " .. field .. " for " .. tostring(definition.id or definition.name or "unknown definition"))
        if value == "none" then return nil end
        return c.overrideDirectory .. "/" .. value .. ".png"
    end
    return { background = layer("card_bg", c.background), foreground = layer("card_fg", c.foreground) }
end

function Resolver.cardPath(definition, id, directory, suffix)
    if directory == "assets/images/loc_cards" and definition and definition.card_type == "SILENCER" then directory = "assets/images/silencers" end
    return directory .. "/" .. id .. (suffix or ".png")
end
return Resolver
