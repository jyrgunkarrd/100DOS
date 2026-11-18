local Parser = {}

function Parser.parse(text)
    text = text:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local palette = { entries = {}, entryCount = 0, duplicateCount = 0 }
    local seen, errors = {}, {}
    local lineNumber = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        local value = line:match("^%s*(.-)%s*$")
        if value ~= "" and value:sub(1, 2) ~= "//" then
            local hex = value:gsub("^#", ""):upper()
            if #hex ~= 6 or not hex:match("^%x+$") then
                errors[#errors + 1] = "Line " .. lineNumber .. ": expected #RRGGBB or RRGGBB."
            else
                palette.entryCount = palette.entryCount + 1
                if seen[hex] then
                    palette.duplicateCount = palette.duplicateCount + 1
                else
                    seen[hex] = true
                    palette.entries[#palette.entries + 1] = {
                        hex = "#" .. hex,
                        r = tonumber(hex:sub(1, 2), 16),
                        g = tonumber(hex:sub(3, 4), 16),
                        b = tonumber(hex:sub(5, 6), 16),
                        line = lineNumber,
                    }
                end
            end
        end
    end
    if #errors > 0 then return nil, table.concat(errors, "\n") end
    if #palette.entries == 0 then return nil, "The file contains no colors." end
    return palette
end

return Parser
