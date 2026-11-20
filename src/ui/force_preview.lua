local Display = require("src.sys.card_display")
local Placement = require("src.ui.preview_placement")
local Preview = require("src.ui.card_preview")
local Settings = require("data.force_preview_view")

local ForcePreview = {}
ForcePreview.__index = ForcePreview

function ForcePreview.new(session, bottom)
    local fonts = session.scene.accents
    local height = bottom and bottom - Settings.placementGap + Settings.bottomMargin or fonts.height
    local view = Preview.new(session.armies.catalogue, {}, Settings, fonts, session.grid, height)
    local function normalize(definition)
        local display = Display.normalize(definition)
        display.type = definition.strength:upper()
        display.stats = { { key = "strength", value = session.armies.rules.strength[definition.strength] } }
        return display
    end
    return setmetatable({ session = session, view = view, normalize = normalize }, ForcePreview)
end

function ForcePreview:show(id, target)
    local view, session = self.view, self.session
    if not id then view:show(nil); return end
    view:prepareCard(id, session.armies.catalogue.byId[id], self.normalize, session.package.biomeId)
    local screen = session.scene.accents
    local panel = { y = Settings.top, width = Settings.width, height = view.layouts[id].height }
    local position = Placement.choose(screen.width, screen.height, panel, target, nil, nil,
        Settings.placementMargin, Settings.placementGap)
    if not position then view:show(nil); return end
    local changed = view.cardId ~= id
    view.x, view.y = position.x, position.y
    view:show(id)
    if changed and session.audio then session.audio:playOverlapping("cardView") end
end

function ForcePreview:wheel(delta)
    if not self.view.cardId or not love.keyboard.isDown("lshift", "rshift") then return false end
    self.view:wheelmoved(delta)
    return true
end

function ForcePreview:draw() self.view:draw() end
function ForcePreview:release() self.view:release() end
return ForcePreview
