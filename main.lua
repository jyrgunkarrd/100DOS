-- The palette utility owns its callbacks and loads independently of game states.
for _, argument in ipairs(arg or {}) do
    if argument == "--palette" then
        require("tools.palette.main")
        return
    end
end

-- Run the integration checks with: love . --test
for _, argument in ipairs(arg or {}) do
    if argument == "--test" then
        require("tests.main")
        return
    end
end

-- All game drawing uses these fixed virtual dimensions.
local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 720

local StateMachine = require("src.states.state_machine")
local MissionPreparation = require("src.states.mission_preparation")
local MissionDeployment = require("src.states.mission_deployment")
local MissionAction = require("src.states.mission_action")
local AgentAction = require("src.states.agent_action")
local states = StateMachine.new()

local canvas
local scale = 1
local offsetX = 0
local offsetY = 0

local function updateViewport(width, height)
    scale = math.min(width / VIRTUAL_WIDTH, height / VIRTUAL_HEIGHT)
    offsetX = (width - VIRTUAL_WIDTH * scale) / 2
    offsetY = (height - VIRTUAL_HEIGHT * scale) / 2
end

-- Use this when adding mouse controls. Coordinates outside the game return nil.
local function windowToGame(x, y)
    if scale <= 0 then
        return nil, nil
    end

    x = (x - offsetX) / scale
    y = (y - offsetY) / scale

    if x < 0 or y < 0 or x >= VIRTUAL_WIDTH or y >= VIRTUAL_HEIGHT then
        return nil, nil
    end

    return x, y
end

function love.load()
    -- Keep the canvas resolution fixed even on high-DPI displays.
    canvas = love.graphics.newCanvas(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, {
        dpiscale = 1,
    })
    canvas:setFilter("linear", "linear")
    love.graphics.setBackgroundColor(0, 0, 0, 1)
    updateViewport(love.graphics.getDimensions())

    states:register("mission_preparation",
        MissionPreparation.new(states, VIRTUAL_WIDTH, VIRTUAL_HEIGHT))
    states:register("mission_deployment",
        MissionDeployment.new(states, VIRTUAL_WIDTH, VIRTUAL_HEIGHT))
    states:register("mission_action", MissionAction.new(states, VIRTUAL_WIDTH, VIRTUAL_HEIGHT))
    states:register("agent_action", AgentAction.new(states, VIRTUAL_WIDTH, VIRTUAL_HEIGHT))
    states:change("mission_preparation")
end

function love.resize(width, height)
    updateViewport(width, height)
end

function love.update(dt)
    local gameX, gameY
    if love.window.hasMouseFocus() then
        gameX, gameY = windowToGame(love.mouse.getPosition())
    end
    states:dispatch("pointermoved", gameX, gameY)
    states:dispatch("update", dt)
end

function love.keypressed(key, scancode, isrepeat)
    states:dispatch("keypressed", key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    states:dispatch("keyreleased", key, scancode)
end

function love.textinput(text)
    states:dispatch("textinput", text)
end

function love.mousepressed(x, y, button, istouch, presses)
    local gameX, gameY = windowToGame(x, y)
    if gameX then
        states:dispatch("mousepressed", gameX, gameY, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    local gameX, gameY = windowToGame(x, y)
    states:dispatch("mousereleased", gameX, gameY, button, istouch, presses)
end

function love.focus(focused)
    states:dispatch("focus", focused)
end

function love.mousefocus(focused)
    states:dispatch("focus", focused)
end

function love.wheelmoved(x, y)
    states:dispatch("wheelmoved", x, y)
end

local function drawGame()
    -- States draw using the fixed virtual canvas coordinates.
    love.graphics.clear(0.08, 0.10, 0.14, 1)
    states:dispatch("draw")
end

function love.draw()
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    drawGame()
    love.graphics.setCanvas()
    love.graphics.pop()

    -- Fit the canvas into the window, with black bars where needed.
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(canvas, offsetX, offsetY, 0, scale, scale)
    love.graphics.pop()
end
