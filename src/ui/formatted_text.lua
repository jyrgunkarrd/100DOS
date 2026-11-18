local Colors = require("data.text_format_colors")
local Text = {}

-- Returns both visible text for measurement and LÖVE colored text for drawing.
-- Unknown or mismatched tags remain literal so authoring mistakes stay visible.
function Text.parse(source, defaultColor, colors)
    colors = colors or Colors
    local plain, colored, stack = {}, {}, {}
    local function append(value)
        if value == "" then return end
        plain[#plain + 1] = value
        colored[#colored + 1] = #stack > 0 and colors[stack[#stack]] or defaultColor
        colored[#colored + 1] = value
    end
    local cursor = 1
    while true do
        local first, last, closing, name = source:find("%[(/?)([%w_]+)%]", cursor)
        if not first then append(source:sub(cursor)); break end
        append(source:sub(cursor, first - 1))
        if colors[name] and closing == "" then
            stack[#stack + 1] = name
        elseif colors[name] and closing == "/" and stack[#stack] == name then
            table.remove(stack)
        else append(source:sub(first, last)) end
        cursor = last + 1
    end
    if #colored == 0 then colored = { defaultColor, "" } end
    return table.concat(plain), colored
end

return Text
