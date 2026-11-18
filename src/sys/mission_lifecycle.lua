local Lifecycle = {}
local function loadData(path)
    local chunk, message = love.filesystem.load(path)
    assert(chunk, message)
    return chunk()
end

-- Build detached mission models. Publishing them is the successful Ready commit.
function Lifecycle.prepare(source)
    if source.agentCards then
        assert(source.agentStatus, "Started mission requires agent status")
        return nil
    end
    require("src.ui.silencer_activity").validate()
    local ids = source.package.agentIds
    local agents = require("data.agents.index").refresh()
    local status = require("src.sys.agent_status").new(ids, agents, loadData("data/agent_status_defaults.lua"))
    local cards = require("src.sys.agent_cards").new(ids, agents,
        require("data.cards.index").refresh(), loadData("data/card_system_defaults.lua"))
    for _, id in ipairs(ids) do
        cards:commitHand(id, cards:prepareDrawTo(id, cards.rules[id].startingHandSize))
    end
    local prepared = { agentCards = cards, agentStatus = status,
        doomClock = require("src.sys.doom_clock").new(loadData("data/doom_clock_rules.lua")) }
    if source.locationDecks then
        local biome = assert(require("data.biomes.index").refresh().byId[source.package.biomeId], "Unknown hunt biome")
        local hunt = require("src.sys.mission_hunt").prepareInitial(source, biome, require("data.loc_cards.index").refresh())
        for key, value in pairs(hunt) do prepared[key] = value end
        prepared.silencers = require("src.sys.silencer_activity").new(
            require("src.sys.silencer_catalogue").load(biome), prepared.locationDecks.pool)
    end
    return prepared
end

function Lifecycle.commit(session, prepared)
    if not prepared then return end
    assert(not session.agentCards and not session.agentStatus, "Mission already initialized")
    session.agentCards, session.agentStatus = prepared.agentCards, prepared.agentStatus
    session.jaclSecurity = 0
    session.silencers = prepared.silencers
    if session.silencers and session.scene then
        session.scene.silencerView = require("src.ui.silencer_activity").new(session.silencers, session.scene.jaclPreview)
    end
    session.doomClock = prepared.doomClock
    session.doomEntranceTime = 0
    if prepared.missionHunt then
        session.missionHunt, session.huntPresentation = prepared.missionHunt, prepared.huntPresentation
        session.locationCardPool, session.locationDecks = prepared.locationCardPool, prepared.locationDecks
    end
    require("src.sys.mission_deck_effects").bind(session)
    if session.scene then session.scene.phaseFeedbackView = require("src.ui.phase_end_feedback").new(session) end
end
return Lifecycle
