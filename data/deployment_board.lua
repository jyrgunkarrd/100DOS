local Theme = require("data.preparation_theme")

return {
    -- Flat-top axial coordinates: center, six neighbors, west/east tips.
    cells = {
        { id = "center", q = 0, r = 0 },
        { id = "north", q = 0, r = -1 },
        { id = "northeast", q = 1, r = -1 },
        { id = "southeast", q = 1, r = 0 },
        { id = "south", q = 0, r = 1 },
        { id = "southwest", q = -1, r = 1 },
        { id = "northwest", q = -1, r = 0 },
        { id = "west", q = -2, r = 1 },
        { id = "east", q = 2, r = -1 },
    },
    artwork = { directory = "assets/images/locations", filter = "nearest" },
    radius = 56, -- Center to corner, in canvas pixels.
    gap = 6, -- Distance between neighboring frame edges.
    padding = 24,
    lineWidth = 2,
    occupiedDimAlpha = 0.4, -- Subtle shading beneath agents on occupied tiles.
    frameColor = Theme.accent,
    fillColor = { 0.025, 0.045, 0.045, 1 },
}
