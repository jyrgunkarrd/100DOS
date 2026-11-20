return setmetatable({
    artDirectory = require("data.battlefield_view").directory,
    artPath = require("src.sys.artwork_resolver").forcePath,
    centerArtwork = true,
    statLabels = { strength = "STRENGTH" },
    placementMargin = 12,
    placementGap = 12,
}, { __index = require("data.card_preview_view") })
