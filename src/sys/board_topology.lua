local Topology = {}
function Topology.adjacent(cells, from, to)
    local a, b
    for _, cell in ipairs(cells) do
        if cell.id == from then a = cell end
        if cell.id == to then b = cell end
    end
    if not a or not b then return false end
    local q, r = a.q - b.q, a.r - b.r
    return math.max(math.abs(q), math.abs(r), math.abs(q + r)) == 1
end
function Topology.locations(session, from)
    local result = {}
    for _, cell in ipairs(session.grid.cells) do
        if session.assignments[cell.id] and Topology.adjacent(session.grid.cells, from, cell.id) then
            result[#result + 1] = cell.id
        end
    end
    return result
end
return Topology
