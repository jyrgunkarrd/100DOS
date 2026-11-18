local Engagement = require("src.sys.location_engagement")
local Entry = {}
-- Used by both draws and mills. Remote reveals remain unengaged.
function Entry.prepare(session, cell, staged, agentId)
    if agentId and session.agentDeployment.placements[agentId] == cell then
        Engagement.prepare(session, cell, staged, agentId, require("data.location_engagement_rules"))
    end
end
function Entry.committed(session, cell, card)
    require("src.sys.mission_hunt").enter(session, cell, card)
end
return Entry
