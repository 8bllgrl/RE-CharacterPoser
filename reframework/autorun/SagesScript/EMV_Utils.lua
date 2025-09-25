-- File: EMV_Utils.lua
local EMV_Utils = {}

-- Basic logging function to print values, based on logv from init.lua
function EMV_Utils.logv(value)
    local output_string = tostring(value)
    log.info(output_string)
    return output_string
end

-- Function to merge two tables. Useful for combining settings or data.
function EMV_Utils.merge_tables(table_a, table_b, no_overwrite)
    table_a = table_a or {}
    table_b = table_b or {}
    if no_overwrite then
        for key_b, value_b in pairs(table_b) do
            if table_a[key_b] == nil then
                table_a[key_b] = value_b
            end
        end
    else
        for key_b, value_b in pairs(table_b) do table_a[key_b] = value_b end
    end
    return table_a
end

return EMV_Utils