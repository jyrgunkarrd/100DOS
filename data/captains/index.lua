local Catalogue = require("src.sys.definition_catalogue")
local Index = {}

function Index.refresh(root, filesystem)
    return Catalogue.refresh(root or "data/captains", "Captain", filesystem)
end

return Index
