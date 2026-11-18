local Targets = require("src.sys.mission_targets")
local Track = require("src.ui.target_track")
local Preview = require("src.ui.card_preview")
local Controller = require("src.ui.card_preview_controller")
local Placement = require("src.ui.preview_placement")
local Animation = require("src.ui.target_track_animation")
local RoutingUI = require("src.ui.army_routing_drag")
local Footer = {}
Footer.__index = Footer

function Footer.new(scene, session)
    Animation.validate(require("data.target_track_animation"))
    local track = Track.new(require("data.target_track_view"))
    local self = setmetatable({ scene = scene, track = track, routing = RoutingUI.new(), jacl = require("src.ui.jacl_panel").new() }, Footer)
    local ok, failure = pcall(self.prepare, self, session)
    if not ok then self:release(); error(failure, 0) end
    return self
end

function Footer:prepare(session)
    local entries, diagnostics = Targets.read(session)
    for _, message in ipairs(diagnostics) do self.track:report(message) end
    self.track:load(entries)
    local label = self.scene.accents:biomeLayout(self.scene.biome)
    assert(label or #entries == 0, "Target track requires deployment label layout")
    return entries, label and self.track:layout(entries, label)
end

function Footer:draw(session)
    self.jacl:draw(session)
    local entries, layout = self:prepare(session)
    self.scene.accents:draw(self.scene.biome)
    if layout then
        self.track:draw(entries, layout, Animation.sample(session.huntPresentation, entries, require("data.target_track_animation")))
    end
end

function Footer:clearHover()
    if self.scene.silencerView then self.scene.silencerView.hover:clear() end
    if self.jacl then self.jacl:clearHover() end
    self.hoveredId = nil
    if self.previews then self.previews:clear() end
end

-- Split adjacent gaps at their midpoint, just like Agent portrait inspection.
-- Keep real panel bounds for preview placement and the outer row edges exact.
function Footer:pointer(session, x, y)
    if self.scene.silencerView then self.scene.silencerView.hover:clear() end
    if not x or not y then self:clearHover(); return false end
    if self.jacl:pointer(session, x, y) then
        self.hoveredId = nil; if self.previews then self.previews:clear() end; return true
    end
    local entries, layout = self:prepare(session)
    for i, panel in ipairs(layout and layout.panels or {}) do
        local previous, following = layout.panels[i - 1], layout.panels[i + 1]
        local left = previous and (previous.x + previous.width + panel.x) / 2 or panel.x
        local right = following and (panel.x + panel.width + following.x) / 2 or panel.x + panel.width
        if x >= left and x < right and y >= panel.y and y < panel.y + panel.height then
            if not self.previews then
                local ok, view = pcall(Preview.new, session.locationDecks.pool, entries,
                    require("data.location_card_preview_view"), self.scene.accents,
                    session.grid or { bounds = { x = 0, width = self.scene.accents.width } },
                    self.scene.accents.height, require("src.sys.location_card_display").normalize, self.scene.biome.id)
                if not ok then self.track:report("Cannot create target preview: " .. tostring(view)); return false end
                self.previews = Controller.new(nil, view, session.audio)
            end
            self.hoveredId = entries[i].instanceId
            self.previews:show("location", entries[i])
            return true
        end
    end
    self:clearHover()
    return self.scene.silencerView and self.scene.silencerView.hover:pointer(x, y) or false
end

function Footer:drawPreview(session)
    self.jacl:drawPreview(session)
    if not self.hoveredId or not self.previews then return end
    local entries, layout = self:prepare(session)
    for i, entry in ipairs(entries) do
        if entry.instanceId == self.hoveredId then
            -- Refresh health even when combat replaces an instance without pointer motion.
            self.previews:show("location", entry)
            local view = self.previews.views.location
            local bounds = view.instanceLayout or view.layouts[entry.cardId]
            local accents, c = self.scene.accents, view.settings
            local grid = session.grid and session.grid.bounds
            local placement = Placement.choose(accents.width, accents.height,
                { width = c.width, height = bounds.height, y = c.top }, layout.panels[i],
                grid and grid.x + grid.width / 2, { accents:biomeLayout(self.scene.biome) }, 16, 8)
            if placement then view.x, view.y = placement.x, placement.y; self.previews:draw() end
            return
        end
    end
    self:clearHover()
end

function Footer:wheel(delta)
    if self.jacl.hover and self.jacl.preview then return self.jacl.preview:wheelmoved(delta) end
    return self.hoveredId ~= nil and self.previews and self.previews:wheelmoved(delta) or false
end

function Footer:release()
    self.routing:release()
    self:clearHover()
    if self.previews then self.previews:release(); self.previews = nil end
    self.track:release()
    if self.jacl then self.jacl:release() end
end

return Footer
