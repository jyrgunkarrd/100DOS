local Distribution = require("src.ui.hunt_distribution")
local Animation = {}
local function clamp(value) return math.max(0, math.min(1, value)) end

function Animation.validate(c)
    for _, key in ipairs({ "crossfadeDuration", "highlightDuration", "escapePulseDuration", "reducedFadeDuration" }) do
        assert(type(c[key]) == "number" and c[key] > 0 and c[key] < math.huge, "Invalid target animation " .. key)
    end
    assert(type(c.stagger) == "number" and c.stagger >= 0 and c.stagger < math.huge, "Invalid target animation stagger")
    assert(type(c.highlightStrength) == "number" and c.highlightStrength >= 0 and c.highlightStrength <= 1,
        "Invalid target animation highlight strength")
end

-- Derive presentation only from the existing hunt clock. No timers, RNG, or card destinations.
function Animation.sample(event, entries, c)
    local distribution, result = require("data.hunt_distribution_view"), {}
    local initial = event and event.kind == "initial"
    local start = distribution.gatherDuration + distribution.shuffleDuration
    local reduced = distribution.reducedMotion
    local fade = reduced and c.reducedFadeDuration or c.crossfadeDuration
    local stagger = reduced and 0 or c.stagger
    local tail = reduced and 0 or c.highlightDuration
    -- Fit even a customized longer reveal inside the existing distribution window.
    local length = fade + math.max(0, #entries - 1) * stagger + tail
    local scale = initial and math.min(1, math.max(0, Distribution.duration(event) - start) / length) or 1
    fade, stagger, tail = fade * scale, stagger * scale, tail * scale
    for i, entry in ipairs(entries) do
        local reveal, highlight = 1, 0
        if initial then
            local age = math.max(0, event.elapsed) - start - (i - 1) * stagger
            reveal = fade > 0 and clamp(age / fade) or (age >= 0 and 1 or 0)
            if not reduced and age >= fade and tail > 0 then highlight = 1 - clamp((age - fade) / tail) end
        elseif event and event.kind == "escape" and entry.champion and not entry.eliminated and not reduced then
            highlight = 1 - clamp(event.elapsed / c.escapePulseDuration)
        end
        result[i] = { reveal = reveal, backAlpha = 1 - reveal, highlight = highlight * c.highlightStrength }
    end
    return result
end

return Animation
