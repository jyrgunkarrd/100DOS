local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
    return setmetatable({ states = {}, current = nil, currentName = nil }, StateMachine)
end

function StateMachine:register(name, state)
    assert(type(name) == "string", "State names must be strings")
    assert(type(state) == "table", "States must be tables")
    assert(not self.states[name], "State already registered: " .. name)
    self.states[name] = state
end

-- States may implement enter(previousName, ...), exit(nextName), and callbacks
-- such as update(dt), draw(), or keypressed(key, scancode, isrepeat).
-- Call machine:change("state_name", ...) to transition and pass entry arguments.
function StateMachine:change(name, ...)
    local nextState = assert(self.states[name], "Unknown state: " .. tostring(name))
    local previousName = self.currentName

    if self.current and self.current.exit then
        self.current:exit(name)
    end

    self.current = nextState
    self.currentName = name

    if nextState.enter then
        nextState:enter(previousName, ...)
    end
end

-- Callbacks are optional; states only need to implement what they use.
function StateMachine:dispatch(callback, ...)
    local state = self.current
    if state and state[callback] then
        return state[callback](state, ...)
    end
end

return StateMachine
