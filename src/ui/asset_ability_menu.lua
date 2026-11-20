local Abilities = require("src.sys.asset_abilities")
local Menu = {}
Menu.__index = Menu

function Menu.open(state, card, zone, cardX, cardY, cardWidth)
    local rows = {}
    for _, ability in ipairs(Abilities.options(state.session, card, zone)) do
        if ability.effect ~= "test_bonus" then
            local args = { instanceId = card.instanceId, abilityId = ability.id, zone = zone }
            local valid, reason = Abilities.evaluate(state.session, state.activeAgentId, args)
            rows[#rows + 1] = { args = args, ability = ability, reason = not valid and reason }
        end
    end
    if #rows == 0 then return end
    state:focus(false)
    local rowHeight = 22
    local width = math.min(88, cardWidth)
    local height = #rows * rowHeight
    return setmetatable({ rows = rows, width = width, height = height, rowHeight = rowHeight,
        x = cardX + math.floor((cardWidth - width) / 2), y = cardY - height }, Menu)
end

function Menu:hit(x, y)
    if x >= self.x and x < self.x + self.width then
        return self.rows[math.floor((y - self.y) / self.rowHeight) + 1]
    end
end

function Menu:release(state, x, y, button)
    local row = self:hit(x, y)
    if button ~= 1 or not row then state.assetMenu = nil; return end
    if row ~= self.pressed or row.reason then return end
    local ok, result = state:performAction("asset_ability", row.args)
    if not ok then row.reason = result; return end
    state.assetMenu = nil
    state.hand.cards = state.session.agentCards.byAgent[state.activeAgentId].hand
    state.hand:layout()
    if row.ability.effect == "explore" then state.exploration:revealed(result) end
    if state.session.audio then state.session.audio:playOverlapping("selection") end
end

function Menu:draw(font)
    local g, colors = love.graphics, require("data.talent_test_view")
    g.push("all")
    g.setFont(font)
    for i, row in ipairs(self.rows) do
        local y = self.y + (i - 1) * self.rowHeight
        g.setColor(colors.background)
        g.rectangle("fill", self.x, y, self.width, self.rowHeight)
        g.setColor(row.reason and colors.muted or colors.accent)
        g.rectangle("line", self.x + 0.5, y + 0.5, self.width - 1, self.rowHeight - 1)
        g.setColor(row.reason and colors.muted or colors.text)
        g.printf(row.ability.id:upper(), self.x, y + math.floor((self.rowHeight - font:getHeight()) / 2),
            self.width, "center")
    end
    g.pop()
end
return Menu
