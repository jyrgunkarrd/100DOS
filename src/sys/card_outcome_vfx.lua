-- Resolve presentation from committed results; never mutate gameplay state.
local Vfx = {}
function Vfx.validate(data, holdDuration)
    for _, profile in pairs(data.profiles) do
        assert(type(profile.duration) == "number" and profile.duration > 0
            and profile.duration <= holdDuration, "Invalid card VFX duration")
        assert(type(profile.crossfadeStart) == "number" and type(profile.crossfadeEnd) == "number"
            and profile.crossfadeStart >= 0 and profile.crossfadeStart < profile.crossfadeEnd
            and profile.crossfadeEnd <= 0.5, "Card VFX crossfade must finish during scan")
        assert(profile.fit == "contain", "Invalid card VFX fitting")
    end
    for _, entry in pairs(data.battlefield) do
        assert(data.profiles[entry.profile] and type(entry.art) == "string" and entry.art ~= "",
            "Invalid battlefield VFX mapping")
    end
end
function Vfx.resolve(record, data)
    if not record or not record.success or not record.battlefield then return end
    local entry = data.battlefield[record.battlefieldKind]
    if entry then return data.profiles[entry.profile], entry.art end
end
return Vfx
