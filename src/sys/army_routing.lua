local Rules = require("data.army_routing_rules")
local Hunt = require("src.sys.mission_hunt")
local Routing = {}

function Routing.available(s, id, cell)
    if require("src.sys.mission_outcome").finished(s) then return false end
    if s.pendingEndTurn or s.pendingManeuver or s.phaseTransition or s.phaseFeedback
        or s.pendingHuntEscape or s.attackFeedback or s.talentFeedback or s.reinforcementFeedback then return false end
    local hunt, armies = s.missionHunt, s.armies
    if not hunt or not armies then return false end
    if (hunt.routedCompanies or {})[id] then return false end
    local company = false
    for _, candidate in ipairs(hunt.companyIds) do if candidate == id then company = true; break end end
    local card = company and Hunt.find(s, id)
    if not card or not card.health or card.health > 0 then return false end
    if cell == nil then return true end
    local pair = armies.byCell[cell]
    return cell ~= armies.jaclCellId and s.assignments[cell] ~= nil and pair ~= nil
        and not pair.routedBy and (Rules.allowEmptyArmy or #pair.enemy.forces > 0)
end

function Routing.prepare(s, id, cell)
    assert(Rules.usesPerCompany == 1, "Routing supports one use per Company")
    if not cell or not Routing.available(s, id, cell) then return end
    local armies, decks, hunt = s.armies, s.locationDecks, s.missionHunt
    local pair, revision = armies.byCell[cell], armies.revision
    local count = #pair.enemy.forces
    local rate = Rules.millPerEliminatedForce and require("data.battlefield_rules").cardsMilledPerEnemyEliminated or 0
    local mill = decks:prepareMill(cell, count * rate)
    for i, card in ipairs(mill.entered) do
        local entry = { card = card, inPlay = mill.inPlay }
        require("src.sys.location_card_entry").prepare(s, cell, entry, s.activeAgentId)
        mill.entered[i] = entry.card
    end
    local receipt = require("src.sys.milling_receipt").new(decks, cell, mill, "routing", count)
    local plan = { receipt = receipt }
    function plan:commit()
        if self.committed or s.armies ~= armies or armies.revision ~= revision or s.locationDecks ~= decks
            or s.missionHunt ~= hunt or not Routing.available(s, id, cell)
            or not decks:canCommitMill(cell, mill) then return false end
        pair.enemy.forces, pair.clashes, pair.routedBy = {}, {}, id
        hunt.routedCompanies = hunt.routedCompanies or {}
        hunt.routedCompanies[id] = cell
        hunt.revision = (hunt.revision or 0) + 1
        require("src.sys.battlefield_state").touch(armies, cell)
        assert(decks:commitMill(cell, mill))
        for _, card in ipairs(mill.entered) do require("src.sys.location_card_entry").committed(s, cell, card) end
        decks.byCell[cell].lastMilling = receipt
        self.committed = true
        return true
    end
    return plan
end
return Routing
