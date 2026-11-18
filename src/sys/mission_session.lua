local Backdrop = require("src.ui.mission_backdrop")
local Session = {}
local fields = { "package", "grid", "assignments", "agentDeployment", "agentView", "armies", "armyView", "locations",
    "scene", "roster", "art", "audio", "agentCards", "agentStatus", "agentAssets", "missionFooter",
    "locationCardPool", "locationDecks", "fatePool", "activeAgentId", "actionRevision", "attackFeedback", "talentFeedback",
    "pendingEndTurn", "pendingManeuver", "missionHunt", "missionOutcome", "pendingHuntEscape", "huntPresentation",
    "silencers", "jaclSecurity", "doomClock", "doomWarning", "doomPresentation", "doomGloryTime", "doomEntranceTime", "phaseTransition", "phaseFeedback", "reinforcementFeedback", "lastDoomMill" }

-- Move ownership; the departing state must not release the continuing mission.
function Session.take(source)
    local session = {}
    for _, key in ipairs(fields) do session[key], source[key] = source[key], nil end
    return session
end

function Session.release(session)
    if session.locationDecks then session.locationDecks.onChanged = nil end
    if session.scene then Backdrop.release(session.scene) end
    for _, key in ipairs({ "roster", "art", "audio", "armyView", "missionFooter" }) do
        if session[key] then session[key]:release() end
    end
    for _, key in ipairs(fields) do session[key] = nil end
end

return Session
