return function(write)
    local machine = require("src.states.state_machine").new()
    for _, name in ipairs({ "mission_preparation", "mission_deployment", "mission_action", "agent_action" }) do
        machine:register(name, require("src.states." .. name).new(machine, 1280, 720))
    end
    machine:change("mission_preparation"); assert(machine.current:deploy())
    local deployment = machine.current; deployment:update(2)
    local ids = deployment.package.agentIds
    for _, id in ipairs(ids) do deployment.agentDeployment:assign(id, "center") end
    deployment.agentDeployment:assign(ids[1], "north"); deployment.agentDeployment:assign(ids[2], "south")
    deployment.agentView:refresh(); assert(deployment:beginAction())
    local mission = machine.current; mission:update(2)
    local s, inspected = mission.session, ids[1]
    local function click(state, x, y, button)
        state:pointermoved(x, y); state:mousepressed(x, y, button); state:mousereleased(x, y, button)
    end
    local function render(name)
        local canvas = love.graphics.newCanvas(1280, 720)
        love.graphics.setCanvas(canvas); love.graphics.clear(); machine.current:draw(); love.graphics.setCanvas()
        local pixels = canvas:newImageData(); write(name, pixels:encode("png"):getString()); pixels:release(); canvas:release()
    end
    -- Compare all gameplay data, including ordered piles, mutable cards and pending hunt state.
    local function encode(value)
        if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
        local keys = {}; for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local text = {}
        for _, key in ipairs(keys) do text[#text + 1] = encode(key) .. "=" .. encode(value[key]) end
        return "{" .. table.concat(text, ";") .. "}"
    end
    local function snapshot()
        local values = {}
        for _, key in ipairs({ "agentCards", "agentStatus", "agentAssets", "locationDecks", "locationCardPool",
            "armies", "fatePool", "missionHunt", "activeAgentId", "actionRevision", "pendingHuntEscape",
            "missionOutcome", "pendingEndTurn", "pendingManeuver", "talentFeedback", "attackFeedback" }) do
            values[key] = s[key] == nil and "<nil>" or s[key]
        end
        values.placements = s.agentDeployment.placements
        values.randomState = love.math.getRandomState()
        return encode(values)
    end
    -- Arrange several ordinary revealed cards with independent live health/engagement states.
    local deck = s.locationDecks.byCell.north
    local function reveal(cardId)
        for i, card in ipairs(deck.drawPile) do
            if card.cardId == cardId then
                table.remove(deck.drawPile, i); deck.drawPile[#deck.drawPile + 1] = card
                return s.locationDecks:draw("north")
            end
        end
        error("Missing inspection test card: " .. cardId)
    end
    local enemy = reveal("forgiven"); enemy.health, enemy.engagedAgentId = 1, ids[2]
    local exhausted = reveal("forgiven"); exhausted.exhausted = true
    for _ = 1, 4 do reveal("security_door") end
    s.agentAssets = require("src.sys.agent_assets").new(ids, require("data.agent_equipment_slots"))
    local equipped = table.remove(s.agentCards.byAgent[inspected].hand)
    local asset = { card = equipped, cardId = equipped.cardId, start = 2, size = 2, health = 1, defiance = 2 }
    local board = s.agentAssets.byAgent[inspected]
    board.placements = { asset }
    board.occupied[s.agentAssets.slots[2]], board.occupied[s.agentAssets.slots[3]] = asset, asset
    mission.selectedId, s.agentView.selected = ids[3], ids[3]
    local originalKeys = love.keyboard.isDown
    local shift = false
    love.keyboard.isDown = function(...) return shift or originalKeys(...) end
    local ok, failure = xpcall(function()
        for _, state in ipairs({ "ready", "exhausted", "defeated" }) do
            local status = s.agentStatus.byAgent[inspected]
            status.health, status.defiance, status.exhausted, status.defeated = 6, 5, state ~= "ready", state == "defeated"
            status.actionPoints = state == "ready" and 3 or 0
            if state == "defeated" then status.health = 0 end
            local before = snapshot()
            -- Map portraits take priority over the hex's force inspection, even when exhausted/defeated.
            local entry = s.agentView.byId[inspected]
            click(mission, entry.x + 8, entry.y + 8, 2)
            local view = assert(mission.agentInspectionPanel, mission.inspectionError)
            assert(view.readOnly and view.agentId == inspected and view.exploration.cell == "north")
            local _, targetLayout = s.missionFooter:prepare(s)
            local target = targetLayout.panels[2]
            mission:pointermoved(target.x + 2, target.y + target.height - 2)
            assert(s.missionFooter.previews.instanceId == s.missionHunt.companyIds[1])
            assert(not view.previews.source and snapshot() == before)
            if state == "ready" then render("target_hover_observation.png") end
            assert(not view.locationPreview.displays[s.missionHunt.championId], "Hidden champion must not become a preview target")
            assert(not mission.battlefieldInspectionCell and not s.activeAgentId)
            assert(#view.hand.cards == #s.agentCards.byAgent[inspected].hand and view.assets[1] == asset)
            assert(mission.selectedId == ids[3] and s.agentView.selected == ids[3])
            assert(not mission:beginAgentAction() and not mission:nextPhaseRefresh())
            -- Even direct panel input has no exploration action in inspection mode.
            assert(view.exploration.actionButtons == nil)
            click(mission, view.exploration.x + 4, view.exploration.y + 4, 1)
            render("agent_observation_" .. state .. ".png")
            view.exploration:showInstance(enemy.instanceId)
            local visible = view.exploration:visibleCards()[1]
            assert(visible.card == enemy and visible.card.health == 1 and visible.card.engagedAgentId == ids[2])
            mission:pointermoved(visible.x + 4, visible.y + 4)
            assert(view.previews.source == "location" and view.previews.instanceId == enemy.instanceId)
            assert(view.locationPreview.runtimeHealth == 1)
            render("agent_observation_encounter.png")
            click(mission, visible.x + 4, visible.y + 4, 1)
            assert(not mission.testPanel)
            mission:wheelmoved(0, -1)
            local first = view.exploration.first
            assert(first == math.min(2, view.exploration:lastPageStart()))
            local row = view.hand.entries[1]
            mission:pointermoved(row.x + 4, row.y + 4)
            assert(view.previews.source == "player_card" and view.previews.instanceId == row.card.instanceId)
            shift = true; mission:wheelmoved(0, -2); shift = false
            assert(view.previews.source == "player_card")
            -- Attempting to drag a hand card onto equipment cannot play it.
            mission:mousepressed(row.x + 4, row.y + 4, 1)
            mission:pointermoved(view.equipment.x + 4, view.equipment.y + 4)
            mission:mousereleased(view.equipment.x + 4, view.equipment.y + 4, 1)
            mission:pointermoved(select(1, view.equipment:bounds(2, 1)) + 3, view.equipment.y + 3)
            assert(view.previews.instanceId == equipped.instanceId)
            mission:keypressed("a"); mission:keypressed("f"); mission:update(1)
            assert(mission.agentInspectionPanel == view and not mission.fatePoolInspection)
            assert(snapshot() == before, "Inspection changed gameplay state: " .. state)
            if state == "ready" then click(mission, 0, 0, 2) else mission:keypressed("escape") end
            assert(not mission.agentInspectionPanel and not view.session and not view.previews)
            assert(snapshot() == before and mission.selectedId == ids[3] and s.agentView.selected == ids[3])
        end
        -- Roster portraits remain an entry point. A release from the opening click cannot close the view.
        for _, status in pairs(s.agentStatus.byAgent) do status.exhausted, status.actionPoints = true, 0 end
        local entry = s.roster.entries[1]
        mission:mousepressed(entry.x + 4, entry.y + 4, 2)
        local view = assert(mission.agentInspectionPanel)
        mission:mousereleased(entry.x + 4, entry.y + 4, 2)
        assert(mission.agentInspectionPanel == view)
        local before = snapshot()
        assert(not mission:nextPhaseRefresh() and snapshot() == before, "Inspection must block an otherwise eligible phase refresh")
        -- Focus loss cancels pressed detail controls, and no release reaches the overview.
        local b = view.detailsButton
        mission:mousepressed(b.x + 3, b.y + 3, 1); mission:focus(false)
        mission:mousereleased(b.x + 3, b.y + 3, 1)
        assert(not view.details and snapshot() == before)
        click(mission, b.x + 3, b.y + 3, 1)
        assert(view.details and view.details.model.live)
        render("agent_observation_details.png")
        click(mission, view.details.close.x + 3, view.details.close.y + 3, 1)
        assert(not view.details and mission.agentInspectionPanel == view)
        mission:keypressed("escape"); assert(snapshot() == before)
        -- A blank hex still opens ordinary force inspection.
        local cell
        for _, candidate in ipairs(s.grid.cells) do if candidate.id == "west" then cell = candidate end end
        click(mission, cell.x, cell.y, 2)
        assert(mission.battlefieldInspectionCell == "west" and not mission.agentInspectionPanel)
        click(mission, 0, 0, 2)
        -- A failure while preparing the independent views leaves the overview/session intact.
        local hand = require("src.ui.agent_hand")
        local original = hand.new
        hand.new = function() error("injected observation failure") end
        click(mission, entry.x + 4, entry.y + 4, 2)
        hand.new = original
        assert(not mission.agentInspectionPanel and mission.inspectionError:match("injected observation failure"))
        assert(snapshot() == before)
        -- Empty and crowded hands remain inspectable and scroll without reordering instances.
        local handState = s.agentCards.byAgent[inspected]
        local originalHand = handState.hand
        handState.hand = {}
        click(mission, entry.x + 4, entry.y + 4, 2)
        render("agent_observation_empty_hand.png"); mission:keypressed("escape")
        handState.hand = {}
        for i = 1, 50 do handState.hand[i] = { instanceId = "inspection_hand_" .. i, cardId = equipped.cardId } end
        before = snapshot()
        click(mission, entry.x + 4, entry.y + 4, 2); view = mission.agentInspectionPanel
        mission:pointermoved(view.hand.x + 4, view.hand.bottom - 4)
        mission:wheelmoved(0, -1)
        assert(view.hand.first > 1 and snapshot() == before)
        render("agent_observation_crowded.png"); mission:keypressed("escape")
        handState.hand = originalHand
        -- Inspecting another Agent during an active turn preserves that turn and its hand.
        for _, status in pairs(s.agentStatus.byAgent) do
            status.health, status.defiance, status.exhausted, status.defeated = 20, 20, false, false
            status.actionPoints = 3
        end
        mission.selectedId = ids[3]; assert(mission:beginAgentAction())
        local active = machine.current; active:update(2)
        before = snapshot()
        local mapEntry = s.agentView.byId[inspected]
        click(active, mapEntry.x + 4, mapEntry.y + 4, 2)
        view = assert(active.agentInspectionPanel, active.inspectionError)
        assert(view.agentId == inspected and s.activeAgentId == ids[3])
        assert(not active:performAction("gain_resource", {}) and not active:endTurn())
        render("agent_observation_other_agent.png")
        click(active, 0, 0, 2)
        assert(snapshot() == before and s.activeAgentId == ids[3] and machine.current == active)
        active:exit()
    end, debug.traceback)
    love.keyboard.isDown = originalKeys
    assert(ok, failure)
end
