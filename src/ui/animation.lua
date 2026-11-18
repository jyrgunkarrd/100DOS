local Animation = {}

function Animation.progress(time, start, duration)
    if time < start then return 0 end
    if duration <= 0 then return 1 end
    return math.min(1, math.max(0, (time - start) / duration))
end

function Animation.easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

function Animation.easeInQuad(t)
    return t * t
end

function Animation.lerp(first, last, t)
    return first + (last - first) * t
end

return Animation
