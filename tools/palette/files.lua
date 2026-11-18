local Files = {}

function Files.absolute(path)
    path = path:gsub("\\", "/")
    if not path:match("^%a:/") and path:sub(1, 1) ~= "/" then
        path = love.filesystem.getWorkingDirectory():gsub("\\", "/") .. "/" .. path
    end
    local prefix = path:match("^%a:") or (path:sub(1, 2) == "//" and "/" or "")
    local parts = {}
    for part in path:sub(#prefix + 1):gmatch("[^/]+") do
        if part == ".." then
            table.remove(parts)
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return prefix .. "/" .. table.concat(parts, "/")
end

function Files.read(path)
    local file, message = io.open(path, "rb")
    if not file then return nil, "Cannot open input: " .. tostring(message) end
    local contents, readError = file:read("*a")
    file:close()
    if not contents then return nil, "Cannot read input: " .. tostring(readError) end
    return contents
end

function Files.defaultOutput(path)
    return (path:gsub("%.[^./\\]+$", "")) .. ".png"
end

return Files
