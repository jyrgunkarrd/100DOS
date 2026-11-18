local Catalogue = {}

-- Return a fresh { ids, byId, paths } snapshot on every call.
-- The optional filesystem implements LÖVE's getInfo, getDirectoryItems, and load.
-- Definitions return tables with nonempty string IDs; index.lua files are skipped
-- at every level so nested index wrappers are never treated as definitions.
function Catalogue.refresh(root, label, filesystem)
    local fs = filesystem or love.filesystem
    label = label or "Definition"
    root = root:gsub("/+$", "")
    local rootInfo = fs.getInfo(root)
    assert(rootInfo and rootInfo.type == "directory",
        label .. " directory does not exist: " .. root)

    local result = { ids = {}, byId = {}, paths = {} }

    local function scan(directory)
        local entries = fs.getDirectoryItems(directory)
        table.sort(entries)

        for _, entry in ipairs(entries) do
            local path = directory .. "/" .. entry
            local info = fs.getInfo(path)

            if info and info.type == "directory" then
                scan(path)
            elseif info and info.type == "file" and entry:match("%.lua$")
                and entry ~= "index.lua" then
                local chunk, loadError = fs.load(path)
                assert(chunk, "Cannot load " .. label .. " " .. path
                    .. ": " .. tostring(loadError))
                local ok, definition = pcall(chunk)
                assert(ok, "Cannot execute " .. label .. " " .. path
                    .. ": " .. tostring(definition))
                assert(type(definition) == "table",
                    label .. " must return a table: " .. path)

                local id = definition.id
                assert(type(id) == "string" and id:match("%S"),
                    label .. " must have a nonempty string ID: " .. path)
                assert(not result.byId[id], "Duplicate " .. label .. " ID '"
                    .. id .. "' in " .. tostring(result.paths[id]) .. " and " .. path)

                result.ids[#result.ids + 1] = id
                result.byId[id] = definition
                result.paths[id] = path
            end
        end
    end

    scan(root)
    table.sort(result.ids)
    return result
end

return Catalogue
