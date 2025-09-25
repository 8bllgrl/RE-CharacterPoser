-- File: EMV_IO.lua
local EMV_IO = {}

-- Define the base path for character data, relative to this script's location
local BASE_PATH = "../data/CharacterPoser/chara/"

-- Assuming a global json library is available from REFramework
function EMV_IO.load_file(filepath)
    local success, data = pcall(json.load_file, filepath)
    if success then
        return data
    else
        return {}
    end
end

function EMV_IO.dump_file(filepath, data)
    local success = pcall(json.dump_file, filepath, data)
    return success
end

function EMV_IO.save_settings(settings)
    EMV_IO.dump_file("CharacterPoser_Settings.json", settings)
end

-- New function to find all subdirectories in the given path.
function EMV_IO.get_character_folders()
    local folders = fs.glob(BASE_PATH .. "/*") or {}
    local folder_names = {}
    for _, path in ipairs(folders) do
        local name = path:match("^.*/([^/]+)$")
        if name then
            table.insert(folder_names, name)
        end
    end
    return folder_names
end

-- Modified function to get JSON files from a specific folder.
function EMV_IO.get_json_files(folder_name)
    if not folder_name then return nil end
    local path_glob = BASE_PATH .. folder_name .. "/*.json"
    local files = fs.glob(path_glob) or {}
    local file_data = {
        names = {},
        paths = {},
        indexes = {},
    }
    for i, file_path in ipairs(files) do
        local name = file_path:match("[/]([%w%-]+)%.json$")
        if name then
            table.insert(file_data.names, name)
            file_data.paths[name] = file_path
            file_data.indexes[name] = i
        end
    end
    return file_data
end

return EMV_IO