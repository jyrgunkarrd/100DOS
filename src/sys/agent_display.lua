local Common = require("src.sys.card_display")
local Status = require("src.sys.agent_status")
local Values = require("src.sys.talent_values")
local Display = {}
function Display.normalize(definition, settings, session, id)
    local d = Common.normalize(definition)
    d.type, d.cost, d.slots, d.talents, d.tests = "AGENT", 0, 0, {}, {}
    local status = session and session.agentStatus and session.agentStatus.byAgent[id]
    for _, key in ipairs(settings.talentOrder) do
        local value, modifier = Values.effective(definition, key, status)
        d.tests[#d.tests + 1] = { type = key, value = value, modifier = modifier }
    end
    local defaults = require("data.agent_status_defaults")
    local l = settings.labels
    if status then
        local state = Status.isDefeatedState(status) and l.defeated
            or status.exhausted and l.exhausted or session.activeAgentId ~= id and l.ready or nil
        if state then table.insert(d.paragraphs, 1, { text = state }) end
        local engaged = require("src.sys.location_engagement").count(session, id)
        d.summary = { left = l.engaged .. " " .. engaged, leftColor = engaged > 0 and settings.engagedColor or nil,
            right = l.resources .. " " .. status.resources }
    else
        d.summary = { left = "", right = l.startingResources .. " " .. defaults.resources }
    end
    d.health = status and status.health or definition.health
    d.defiance = status and status.defiance or definition.defiance
    d.showStats = true
    local assets = session and session.agentAssets
    local slots = assets and assets.slots or require("data.agent_equipment_slots")
    d.assetSlots = {}
    for index = 1, #slots do
        local asset = assets and assets:at(id, index)
        d.assetSlots[index] = { index = index, cardId = asset and asset.card.cardId,
            start = asset and asset.start, size = asset and asset.size,
            continuation = asset and asset.start ~= index or false }
    end
    return d
end
return Display
