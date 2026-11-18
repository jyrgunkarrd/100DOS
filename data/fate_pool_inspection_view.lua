local Style = require("data.agent_inspection_view")
return {
    shortcut = "f", title = "FATE POOL",
    button = { height = 24, captainGap = 4 },
    width = 690, height = 500, padding = 18, listWidth = 330,
    listTop = 80, gap = 16, rowHeight = 32, sourceRowHeight = 18,
    sourceLabels = { transport = "TRANSPORT", agent = "AGENT", captain = "CAPTAIN", jacl = "JACL", sabotage = "SABOTAGE" },
    background = Style.background, shade = Style.shade,
    row = Style.row, highlight = Style.highlight,
    accent = Style.accent, text = Style.text, muted = Style.muted,
}
