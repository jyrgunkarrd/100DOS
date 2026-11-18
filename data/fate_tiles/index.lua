local Catalogue = require("src.sys.definition_catalogue")
local Definition = require("src.sys.fate_tile_definition")
local Index = {}

function Index.refresh(root, filesystem)
    local result = Catalogue.refresh(root or "data/fate_tiles", "Fate tile", filesystem)
    for _, id in ipairs(result.ids) do
        Definition.validate(result.byId[id], id)
    end
    return result
end

return Index
