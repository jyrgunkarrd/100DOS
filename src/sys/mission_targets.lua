local Hunt = require("src.sys.mission_hunt")
local Targets = {}

-- A public objective roster, deliberately excluding locations and hidden deck zones.
-- Resolve instances afresh: escape replaces the champion table and damage need not
-- change the hunt revision. The UI never owns a second copy of combat health.
function Targets.read(session)
    local entries, diagnostics = {}, {}
    local hunt = session.missionHunt
    if not hunt then return entries, diagnostics end
    local definitions = session.locationDecks.pool.byId
    local champion = assert(definitions[hunt.championId], "Missing target champion definition")
    local ids = { hunt.championInstanceId }
    for _, id in ipairs(hunt.companyIds) do ids[#ids + 1] = id end
    for i, id in ipairs(ids) do
        local card = Hunt.find(session, id)
        local cardId = card and card.cardId or (i == 1 and hunt.championId or champion.company[i - 1])
        local definition = assert(definitions[cardId], "Missing target definition: " .. tostring(cardId))
        local health = card and card.health
        if health == nil then diagnostics[#diagnostics + 1] = "Target instance unavailable: " .. id end
        if not (hunt.routedCompanies or {})[id] then
            entries[#entries + 1] = {
                instanceId = id, cardId = cardId, name = definition.name,
                champion = i == 1, health = health, maxHealth = definition.health,
                eliminated = health ~= nil and health <= 0,
            }
        end
    end
    return entries, diagnostics
end

return Targets
