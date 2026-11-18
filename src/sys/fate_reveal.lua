local Draw = require("src.sys.fate_draw")
local Definition = require("src.sys.fate_tile_definition")
local Tests = require("src.sys.talent_tests")
local Clashes = require("src.sys.battlefield_clashes")
local Reveal = {}

-- Stage the result and its reveal effect after stale-action checks, before publication.
function Reveal.prepare(session, result, base, committed, difficulty, random)
    local tileId, tile, index = Draw.pick(session.fatePool, random)
    local outcome = Tests.calculate(base, committed, difficulty, tile)
    for key, entry in pairs(outcome) do result[key] = entry end
    result.tileId, result.tileIndex = tileId, index
    result.fate = Definition.display(tile)
    local effect = { session = session }
    if session.doomClock then effect.doom = require("src.sys.doom_clock").prepare(session.doomClock, "test", result) end
    -- JACL tests still resolve the tile and Doom effects, but cannot create Clashes.
    if tile.clash and result.cell ~= (session.armies and session.armies.jaclCellId) then
        local pair = assert(session.armies and session.armies.byCell[result.cell], "Missing clash location")
        if not pair.routedBy then effect.pair, effect.batch = pair, Clashes.prepareBatch(tileId, tile.clash) end
    end
    return effect
end

function Reveal.commit(effect)
    if not effect then return end
    if effect.doom then assert(require("src.sys.doom_clock").commit(effect.session, effect.doom)) end
    if effect.batch then Clashes.enqueue(effect.pair, effect.batch) end
end

return Reveal
