-- File: EMV_IO.lua
local EMV_IO = {}

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

return EMV_IO