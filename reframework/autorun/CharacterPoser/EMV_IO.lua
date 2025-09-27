-- File: EMV_IO.lua
local EMV_IO = {}

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

-- Hardcoded paths list (simulating discovery without file system traversal)
local KNOWN_JSON_FILES = {
    "CharacterPoser\\chara\\merchant.json",
}

-- New function to get all JSON files.
function EMV_IO.get_all_character_jsons()
    local json_files = {
        names = {},
        paths = {},
        indexes = {},
    }

    for i, full_path in ipairs(KNOWN_JSON_FILES) do
        -- Extract the path relative to the 'chara/' directory for the UI name
        local name = full_path:match("chara\\(.+)")
        
        if name then
            table.insert(json_files.names, name)
            json_files.paths[name] = full_path
            json_files.indexes[name] = #json_files.names
        end
    end
    
    table.sort(json_files.names)
    
    -- Rebuild indexes after sort
    for i, name in ipairs(json_files.names) do
        json_files.indexes[name] = i
    end

    return json_files
end

-- Deprecated/No-op functions replacing the old folder-based logic
function EMV_IO.get_character_folders()
    return {} -- Return empty table
end

function EMV_IO.get_json_files(folder_name)
    -- This is the new entry point for getting all files
    return EMV_IO.get_all_character_jsons()
end

return EMV_IO