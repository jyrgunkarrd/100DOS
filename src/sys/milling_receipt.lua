local Receipt = {}
function Receipt.new(decks, cell, mill, source, eliminated)
    local before, after, concealed = decks:publicMillCounts(cell, mill)
    local cards = {}
    for i, card in ipairs(mill.cards) do
        cards[i] = { instanceId = card.instanceId, cardId = card.cardId, name = card.name,
            destination = card.destination, source = source }
    end
    return { source = source, cards = cards, requested = mill.requested, actual = mill.actual,
        before = before, after = after, concealed = concealed, eliminated = eliminated or 0,
        cell = cell, locationId = mill.locationId, locationName = mill.locationName }
end
-- Merge only consecutive results; retain each card's cause for later review.
function Receipt.append(total, receipt)
    if not total then
        total = {}
        for key, value in pairs(receipt) do total[key] = value end
        total.cards = {}
        total.actual, total.requested = 0, 0
    end
    for _, card in ipairs(receipt.cards) do total.cards[#total.cards + 1] = card end
    total.actual, total.requested = total.actual + receipt.actual, total.requested + receipt.requested
    total.after = receipt.after
    return total
end
return Receipt
