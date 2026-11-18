local View = {}
function View.draw(session, width, height, font, heading)
    local c, g = require("data.hunt_distribution_view"), love.graphics
    local failure = session.missionOutcome.kind == "failure"
    g.push("all"); g.setColor(0.01, 0.025, 0.035, 0.95); g.rectangle("fill", 0, 0, width, height)
    g.setFont(heading or font or g.getFont()); g.setColor(failure and c.failure or c.secured)
    g.printf(failure and c.labels.failure or c.labels.victory, 0, height / 2 - 60, width, "center")
    g.setFont(font or g.getFont()); g.setColor(c.text)
    local name = session.missionHunt and session.missionHunt.championName or "Champion"
    g.printf(failure and c.labels.jaclExhausted or name .. " / " .. c.labels.defeated, 0, height / 2 - 20, width, "center")
    g.printf(c.labels.continue, 0, height / 2 + 28, width, "center"); g.pop()
end
return View
