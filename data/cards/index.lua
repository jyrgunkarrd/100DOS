local Catalogue = require("src.sys.definition_catalogue")
local Index = {}

function Index.refresh(root, filesystem)
    return Catalogue.refresh(root or "data/cards", "Card", filesystem)
end

return Index
