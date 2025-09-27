-- File: EMV_IO.lua
local EMV_IO = {}

-- Base path for character data (relative to reframework/data)
local BASE_PATH = "CharacterPoser/chara"

-- Load JSON safely
function EMV_IO.load_file(filepath)
    local ok, data = pcall(json.load_file, filepath)
    return ok and data or {}
end

-- Dump JSON safely
function EMV_IO.dump_file(filepath, data)
    local ok = pcall(json.dump_file, filepath, data)
    return ok
end

-- Save settings file
function EMV_IO.save_settings(settings)
    EMV_IO.dump_file("CharacterPoser_Settings.json", settings)
end

-- Get all character subfolders
function EMV_IO.get_character_folders()
    local folders = fs.glob(BASE_PATH .. "/*") or {}
    local folder_names = {}

    for _, path in ipairs(folders) do
        if not path:match("%.json$") then
            local sub_files = fs.glob(path .. "/*.json") or {}
            if #sub_files > 0 then
                local name = path:match("^.*/([^/]+)$") or path:match("^.+\\([^\\]+)$")
                if name then
                    table.insert(folder_names, name)
                end
            end
        end
    end

    log.info("[EMV_IO] Found " .. #folder_names .. " character folders.")
    return folder_names
end

-- Get JSON files within a given folder
function EMV_IO.get_json_files(folder_name)
    local path_glob = BASE_PATH .. "/" .. (folder_name or "*") .. "/*.json"
    local files = fs.glob(path_glob) or {}

    log.info("[EMV_IO] Found " .. #files .. " JSON files in: " .. path_glob)

    local file_data = { names = {}, paths = {}, indexes = {}, glob_path = path_glob }

    for i, file_path in ipairs(files) do
        local name = file_path:match("[/]([%w%-]+)%.json$") or file_path:match("[\\]([%w%-]+)%.json$")
        if name then
            table.insert(file_data.names, name)
            file_data.paths[name] = file_path
            file_data.indexes[name] = i
        end
    end

    return file_data
end

return EMV_IO
