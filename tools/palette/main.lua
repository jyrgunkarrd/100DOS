local prefix = love.filesystem.getInfo("tools/palette/app.lua") and "tools.palette." or ""
require(prefix .. "app")(prefix)
