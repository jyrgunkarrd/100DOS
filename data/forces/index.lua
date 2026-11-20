local Catalogue = require("src.sys.definition_catalogue")
local Triggers = require("src.sys.force_triggers")
local Index = {}

function Index.refresh(root, filesystem)
    local catalogue = Catalogue.refresh(root or "data/forces", "Force", filesystem)
    for _, id in ipairs(catalogue.ids) do
        Triggers.validate(catalogue.byId[id], catalogue)
    end
    return catalogue
end

return Index
