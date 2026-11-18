local Catalogue = require("src.sys.definition_catalogue")
local Index = {}

function Index.refresh(root, filesystem)
    return Catalogue.refresh(root or "data/jacls", "Jacl", filesystem)
end

return Index
