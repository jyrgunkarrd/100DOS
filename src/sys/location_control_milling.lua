local Milling = {}
-- Evaluate at actual activation, never on selection or when rebuilding an active turn.
function Milling.prepare(session, agentId)
    local cell = session.agentDeployment and session.agentDeployment.placements[agentId]
    local armies, decks = session.armies, session.locationDecks
    if not cell or not armies or not decks or cell == require("src.sys.mission_deck_effects").jaclCell(session) then return end
    local pair = armies.byCell[cell]
    if not pair or not decks.byCell[cell] then return end
    local Value = require("src.sys.army_value")
    local allied = Value.calculate(pair.allied, armies.catalogue, armies.rules)
    local enemy = Value.calculate(pair.enemy, armies.catalogue, armies.rules)
    if allied < 1 or enemy ~= 0 then return end
    local count = require("data.battlefield_rules").controlledLocationStartMill
    assert(type(count) == "number" and count >= 0 and count < math.huge and count % 1 == 0, "Invalid controlled location milling")
    if count == 0 then return end
    local mill = decks:prepareMill(cell, count)
    for i, card in ipairs(mill.entered) do
        local entry = { card = card, inPlay = mill.inPlay }
        require("src.sys.location_card_entry").prepare(session, cell, entry, agentId)
        mill.entered[i] = entry.card
    end
    return { cell = cell, mill = mill,
        receipt = require("src.sys.milling_receipt").new(decks, cell, mill, "control") }
end
function Milling.commit(session, plan)
    if not plan then return end
    assert(session.locationDecks:commitMill(plan.cell, plan.mill))
    for _, card in ipairs(plan.mill.entered) do
        require("src.sys.location_card_entry").committed(session, plan.cell, card)
    end
    session.locationDecks.byCell[plan.cell].lastMilling = plan.receipt
    require("src.ui.phase_end_feedback").start(session, { { kind = "mill", record = plan.receipt } })
end
return Milling
