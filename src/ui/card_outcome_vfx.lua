local Vfx = {}
local function clamp(v) return math.max(0, math.min(1, v)) end
-- Shared encounter/defeat/Battlefield scan, content fade, then frame fade.
function Vfx.pose(age, duration, profile)
    local progress = clamp(age / duration)
    if progress >= 1 then return { sweep = 1, contentAlpha = 0, frameAlpha = 0, artMix = profile and 1 or 0 } end
    return { sweep = math.min(1, progress / 0.5),
        contentAlpha = 1 - clamp((progress - 0.5) / 0.3),
        frameAlpha = 1 - clamp((progress - 0.8) / 0.2),
        artMix = profile and clamp((progress - profile.crossfadeStart)
            / (profile.crossfadeEnd - profile.crossfadeStart)) or 0 }
end
function Vfx.drawScan(x, width, height, tint, alpha, treatment, reducedMotion)
    local g, fade = love.graphics, alpha * treatment.contentAlpha
    local function color(a) g.setColor(tint[1], tint[2], tint[3], tint[4] * a) end
    color(fade * 0.18)
    g.rectangle("fill", x + 2, 2, width - 4, height - 4)
    if not reducedMotion and treatment.sweep < 1 then
        local y = (height - 4) * (1 - treatment.sweep) + 2
        color(fade * 0.18)
        g.rectangle("fill", x + 2, math.max(2, y - 6), width - 4, math.min(8, height - 2 - y))
        color(fade); g.rectangle("fill", x + 2, y, width - 4, 2)
    end
end
-- Draw both subjects in the same logical rectangle; preserve full-image margins.
function Vfx.drawCrossfade(drawOriginal, replacement, mix, x, y, size, tint)
    mix = replacement and mix or 0
    drawOriginal({ tint[1], tint[2], tint[3], tint[4] * (1 - mix) })
    if replacement and mix > 0 then
        local iw, ih = replacement:getDimensions()
        local fit = math.min(size / iw, size / ih)
        love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] * mix)
        love.graphics.draw(replacement, x + (size - iw * fit) / 2, y + (size - ih * fit) / 2, 0, fit, fit)
    end
end
return Vfx
