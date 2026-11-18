-- Displayed roles stay distinct; shared behavior is defined here, never by ID prefixes.
local Traits = {}
local roles = { CHAMPION = true, COMPANY = true, BODYGUARD = true }
function Traits.hunt(card) return card and roles[card.card_type] == true end
function Traits.enemy(card) return card and (card.card_type == "ENEMY" or card.card_type == "SILENCER" or Traits.hunt(card)) end
function Traits.entersOnMill(card) return Traits.hunt(card) or (card and card.card_type == "SABOTAGE") end
return Traits
