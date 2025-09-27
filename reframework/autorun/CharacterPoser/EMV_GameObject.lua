-- File: reframework/autorun/CharacterPoser/EMV_GameObject.lua
local EMV_GameObject = {}
local EMV_IO = require("CharacterPoser/EMV_IO")
local EMV_Utils = require("CharacterPoser/EMV_Utils")

-- The core GameObject class
EMV_GameObject.class = {}
EMV_GameObject.class.__index = EMV_GameObject.class

function EMV_GameObject.class.new(xform)
    local self = setmetatable({}, EMV_GameObject.class)
    self.xform = xform or nil 
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

local function get_comp_typedef_name(comp_typedef)
    return comp_typedef and comp_typedef:get_name()
end

-- CRITICALLY REVISED: This function *returns* the necessary deferred command(s), 
-- it does not modify the global deferred queue.
local function get_component_commands(new_component, prop_key, final_value, comp_type_name)
    local commands = {}
    local obj = new_component 
    
    -- Check if the final value is a managed object representing a ResourceHolder
    local is_resource = EMV_Utils.is_valid_obj(final_value) and final_value.get_type_definition and final_value:get_type_definition():get_name():find("ResourceHolder")
    
    local setter_name = "set_" .. prop_key:gsub("^_", "")

    -- Handle the special 'setMesh' case
    if prop_key == "Mesh" and comp_type_name == "Mesh" then
        setter_name = "setMesh"
    end

    if is_resource then
        -- CRITICAL FIX: Wrap ALL resource setters in lua_func blocks for maximum stability.
        table.insert(commands, { lua_func = function() obj:call(setter_name, final_value) end, obj=obj })
    else
        -- Try Setter (preferred in init.lua pattern)
        if pcall(obj.call, obj, setter_name, final_value) then
            table.insert(commands, { func = setter_name, args = final_value, obj = obj })
        else
            -- Fallback to Field (via lua_func)
            table.insert(commands, { lua_func = function() pcall(obj.set_field, obj, prop_key, final_value) end, obj = obj })
        end
    end
    return commands
end


-- 'parent_file_path' is the full path of the JSON file that triggered this creation.
function EMV_GameObject.class.create_from_json(json_data, parent_xform, spawn_position, parent_file_path)
    
    if not json_data or next(json_data) == nil then
        EMV_Utils.logv("Error: JSON data is empty or invalid for path: " .. tostring(parent_file_path))
        return nil
    end

    EMV_Utils.logv("--- Loading JSON for: " .. tostring(parent_file_path) .. " ---")
    
    -- FIX: Use the local utility function to print structured JSON content
    if EMV_Utils.json_to_string then
        EMV_Utils.logv(EMV_Utils.json_to_string(json_data))
    else
        -- Fallback if json_to_string isn't available for some reason
        EMV_Utils.logv(tostring(json_data))
    end
    
    local obj_name = next(json_data)
    local obj_data = json_data[obj_name]
    local components_list = obj_data["__components_order"]
    local children_list = obj_data["__children"]

    -- Native GO creation and immediate constructor call
    local create_method = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)")
    local new_gameobj = create_method:call(nil, obj_name)
    
    if new_gameobj then
        new_gameobj = new_gameobj:add_ref() 
        new_gameobj:call(".ctor") -- CRITICAL: Immediate constructor call for GO
    else
        EMV_Utils.logv("Error: Failed to create GameObject: " .. obj_name)
        return nil
    end
    
    local new_xform = new_gameobj:call("get_Transform")

    if spawn_position then new_xform:call("set_Position", spawn_position) end
    if parent_xform then new_xform:call("set_Parent", parent_xform) end
    
    local components_to_process = {}

    -- 1. Create components and call their constructors immediately
    for _, comp_name in ipairs(components_list) do
        local comp_typedef = sdk.find_type_definition(comp_name)
        if comp_typedef then
            local comp_type_name = get_comp_typedef_name(comp_typedef)
            local new_component = (comp_type_name == "Transform") and new_xform or new_gameobj:call("createComponent(System.Type)", comp_typedef:get_runtime_type())
            
            if new_component then
                -- CRITICAL FIX: IMMEDIATELY call the component's constructor
                if comp_type_name ~= "Transform" then
                    new_component:call(".ctor")
                end
                
                local comp_data = obj_data[comp_type_name]
                
                if comp_data then
                    local deferred_comp_props = { component = new_component, data = {}, type_name = comp_type_name }
                    
                    for prop_key, prop_value in pairs(comp_data) do
                        if prop_key ~= "__typedef" and prop_key ~= "__address" and prop_key ~= "__gameobj_name" then
                            local final_value = prop_value
                            local is_string = type(prop_value) == "string"

                            -- Handle Resources/Vectors conversion logic here...
                            if is_string and prop_value:find("res:") == 1 then
                                local parts = EMV_Utils.split(prop_value:sub(5), " ") 
                                local path = parts[1]
                                local type_name = parts[2]:gsub("Holder", "")
                                final_value = sdk.create_resource(type_name, path)
                            elseif is_string and prop_value:find("vec:") == 1 then
                                local parts = EMV_Utils.split(prop_value:sub(5), " ")
                                local p = { tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4]) }
                                final_value = (#parts == 4 and Vector4f.new(p[1], p[2], p[3], p[4])) or (#parts == 3 and Vector3f.new(p[1], p[2], p[3]))
                            end
                            
                            if final_value ~= nil then
                                deferred_comp_props.data[prop_key] = final_value
                            end
                        end
                    end
                    table.insert(components_to_process, deferred_comp_props)
                end
            end
        end
    end
    
    -- 2. Consolidate and sequence all deferred commands for this script's queue
    local final_commands = {}
    local resource_commands = {}

    for _, comp_props in ipairs(components_to_process) do
        for prop_key, final_value in pairs(comp_props.data) do
            local commands = get_component_commands(comp_props.component, prop_key, final_value, comp_props.type_name)
            
            for _, cmd in ipairs(commands) do
                -- Separate volatile resource commands to run last (all resource setters use lua_func)
                if cmd.lua_func then
                    table.insert(resource_commands, cmd)
                else
                    table.insert(final_commands, cmd)
                end
            end
        end
    end
    
    -- Add resource commands last to ensure maximum stability
    for _, cmd in ipairs(resource_commands) do
        table.insert(final_commands, cmd)
    end
    
    -- 3. Final single assignment to the CharacterPoser's local queue (decoupling from init.lua's processor)
    _G.CharacterPoser_DeferredQueue = _G.CharacterPoser_DeferredQueue or {}

    if #final_commands > 0 then
        -- This single assignment is the stable pattern, using new_gameobj as the unique key.
        _G.CharacterPoser_DeferredQueue[new_gameobj] = final_commands
    end
    
    -- Recursively create children
    if children_list then
        local normalized_path = parent_file_path:gsub("/", "\\")
        local parent_dir = normalized_path:match("(.+\\)") or ""
        
        for _, child_name in ipairs(children_list) do
            local child_file_path = parent_dir .. child_name .. ".json"
            EMV_Utils.logv("Attempting to load child file: " .. child_file_path)

            local child_json_data = EMV_IO.load_file(child_file_path)
            if child_json_data and next(child_json_data) then
                EMV_GameObject.class.create_from_json(child_json_data, new_xform, nil, child_file_path)
            else
                 EMV_Utils.logv("Warning: Child file not loaded or is empty at: " .. child_file_path)
            end
        end
    end

    return EMV_GameObject.class.new(new_xform)
end

return EMV_GameObject