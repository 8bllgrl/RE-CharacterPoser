-- File: reframework/autorun/CharacterPoser/EMV_GameObject.lua
local EMV_GameObject = {}
local EMV_IO = require("CharacterPoser/EMV_IO")
local EMV_Utils = require("CharacterPoser/EMV_Utils")

-- The core GameObject class
EMV_GameObject.class = {}
EMV_GameObject.class.__index = EMV_GameObject.class

-- Removed find_child_json_path, as filenames now match object names.

function EMV_GameObject.class.new(xform)
    local self = setmetatable({}, EMV_GameObject.class)
    self.xform = xform or nil -- Made xform optional
    self.name = "NewObject"
    return self
end

function EMV_GameObject.class.imgui_xform(self)
    imgui.text("Transform UI for " .. self.name)
end

function EMV_GameObject.class.imgui_poser(self)
    imgui.text("Posing UI for " .. self.name)
end

function EMV_GameObject.class.update(self)
    -- This update function can be used to perform per-frame logic on the object
end

-- 'parent_file_path' is the full path of the JSON file that triggered this creation.
function EMV_GameObject.class.create_from_json(json_data, parent_xform, spawn_position, parent_file_path)
    
    -- Check if json_data is empty (e.g., if JSON failed to load/parse)
    if not json_data or next(json_data) == nil then
        EMV_Utils.logv("Error: JSON data is empty or invalid for path: " .. tostring(parent_file_path))
        return nil
    end

    -- LOGGING ADDED: Log the contents of the JSON data
    EMV_Utils.logv("--- Loading JSON for: " .. tostring(parent_file_path) .. " ---")
    if json.log then
        EMV_Utils.logv(json.log(json_data))
    else
        -- Fallback log if a json.log function is not available globally
        EMV_Utils.logv(tostring(json_data))
    end
    
    -- Get the main game object name from the JSON
    local obj_name = next(json_data)
    local obj_data = json_data[obj_name]
    local components_list = obj_data["__components_order"]
    local children_list = obj_data["__children"]

    -- FIX: Replicating the robust GameObject creation logic from init.lua
    local create_method = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)")
    local new_gameobj = create_method:call(nil, obj_name)
    
    if new_gameobj then
        new_gameobj = new_gameobj:add_ref() -- Add a reference to keep it alive
        new_gameobj:call(".ctor") -- Call the object's constructor
    else
        EMV_Utils.logv("Error: Failed to create GameObject: " .. obj_name)
        return nil
    end
    
    local new_xform = new_gameobj:call("get_Transform")

    -- Set initial position if provided
    if spawn_position then
        new_xform:call("set_Position", spawn_position)
    end

    -- Set the parent if one exists
    if parent_xform then
        new_xform:call("set_Parent", parent_xform)
    end

    -- Create components
    for _, comp_name in ipairs(components_list) do
        local comp_typedef = sdk.find_type_definition(comp_name)
        if comp_typedef then
            local new_component = new_gameobj:call("createComponent(System.Type)", comp_typedef:get_runtime_type())
            if new_component then
                new_component:call(".ctor")
                -- TODO: Load component-specific data from JSON
            end
        end
    end

    local new_obj = EMV_GameObject.class.new(new_xform)
    new_obj.name = obj_name

    -- Recursively create children
    if children_list then
        -- FIX 1: Normalize all forward slashes to backslashes, as requested.
        local normalized_path = parent_file_path:gsub("/", "\\")
        
        -- FIX 2: Find the parent directory using the backslash pattern.
        -- This looks for the longest string ending in a backslash.
        -- The pattern '(.+\\)' matches 'CharacterPoser\chara\' from 'CharacterPoser\chara\merchant.json'
        local parent_dir = normalized_path:match("(.+\\)") or ""
        
        for _, child_name in ipairs(children_list) do
            -- Construct the child component's file path using the deduced directory
            local child_file_path = parent_dir .. child_name .. ".json"
            
            -- DIAGNOSTIC LOGGING: Check the path being attempted
            EMV_Utils.logv("Attempting to load child file: " .. child_file_path)

            local child_json_data = EMV_IO.load_file(child_file_path)
            if child_json_data and next(child_json_data) then
                -- Pass the current child's file path for its own potential children
                EMV_GameObject.class.create_from_json(child_json_data, new_xform, nil, child_file_path)
            else
                 EMV_Utils.logv("Warning: Child file not loaded or is empty at: " .. child_file_path)
            end
        end
    end

    return new_obj
end

return EMV_GameObject
