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

-- Helper to safely get the component type name
local function get_comp_typedef_name(comp_typedef)
    return comp_typedef and comp_typedef:get_name()
end

-- Helper to set properties on a component using deferred calls
local function defer_set_component_property(new_component, prop_key, final_value, comp_type_name)
    local success = false
    local obj = new_component -- The object to call the function on
    local deferred_args = {}

    local is_mesh_resource_prop = comp_type_name == "Mesh" and (prop_key == "Mesh" or prop_key == "_Material")

    if is_mesh_resource_prop then
        -- CRITICAL FIX: The only reliable way to set Mesh resources is via a lua_func block
        -- to achieve the "safest deferral timing" possible.
        if prop_key == "_Material" then
            local func = function()
                obj:call("set_Material", final_value)
            end
            table.insert(deferred_args, { lua_func = func })
            success = true
        elseif prop_key == "Mesh" then
            local func = function()
                obj:call("setMesh", final_value)
            end
            table.insert(deferred_args, { lua_func = func })
            success = true
        end
    end

    if not success then
        -- 1. Try setting as a field (e.g., '_JointMap')
        local try_field = pcall(obj.set_field, obj, prop_key, final_value)
        if try_field then
            -- Field setting was successful on the spot (no deferred call needed)
            success = true
        else
            -- 2. Try setting as a property via setter method (e.g., 'set_JointMap' for '_JointMap')
            local setter_name = "set_" .. prop_key:gsub("^_", "")
            local method_check = pcall(obj.call, obj, setter_name, final_value)

            if method_check then
                table.insert(deferred_args, { func = setter_name, args = final_value })
                success = true
            end
        end
    end

    -- If a deferred call was prepared, execute it (this requires EMV_Engine's deferred_calls table)
    if deferred_args[1] then
        -- This relies on EMV_Engine (init.lua) exposing its deferred_calls table globally
        _G.deferred_calls = _G.deferred_calls or {}
        local current_calls = _G.deferred_calls[obj] or {}
        
        -- Append the new deferred call arguments
        for _, call in ipairs(deferred_args) do
             table.insert(current_calls, call)
        end

        -- Normalize the queue format as init.lua's deferred_call system is sensitive.
        if #current_calls == 1 and not current_calls[1].args and not current_calls[1].lua_func then 
             _G.deferred_calls[obj] = current_calls[1]
        else
             _G.deferred_calls[obj] = current_calls
        end
        return true
    end
    
    return success
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
        -- CRITICAL: Immediately call the object's constructor. This is essential for native stability.
        new_gameobj:call(".ctor") 
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
    
    local components_to_process = {}

    -- Create components
    for _, comp_name in ipairs(components_list) do
        local comp_typedef = sdk.find_type_definition(comp_name)
        if comp_typedef then
            local comp_type_name = get_comp_typedef_name(comp_typedef)
            
            -- Look up existing component (Transform is created by default) or create a new one
            local new_component = (comp_type_name == "Transform") and new_xform or new_gameobj:call("createComponent(System.Type)", comp_typedef:get_runtime_type())
            
            if new_component then
                -- CRITICAL FIX: IMMEDIATELY call the component's constructor for stability.
                if comp_type_name ~= "Transform" then
                    new_component:call(".ctor")
                end
                
                local comp_data = obj_data[comp_type_name]
                
                if comp_data then
                    -- Prepare data for deferred setting
                    local deferred_comp_props = { component = new_component, data = {}, type_name = comp_type_name }
                    
                    for prop_key, prop_value in pairs(comp_data) do
                        -- Skip metadata fields
                        if prop_key ~= "__typedef" and prop_key ~= "__address" and prop_key ~= "__gameobj_name" then
                            
                            local final_value = prop_value
                            local is_string = type(prop_value) == "string"

                            -- 1. Handle ResourceHolder (res:path type)
                            if is_string and prop_value:find("res:") == 1 then
                                local parts = EMV_Utils.split(prop_value:sub(5), " ") -- Split path and type
                                local path = parts[1]
                                local type_name = parts[2]:gsub("Holder", "") -- e.g., via.render.MeshResource
                                final_value = sdk.create_resource(type_name, path)
                                
                            -- 2. Handle Vector (vec:x y z w)
                            elseif is_string and prop_value:find("vec:") == 1 then
                                local parts = EMV_Utils.split(prop_value:sub(5), " ")
                                local p = {}
                                for i, s in ipairs(parts) do p[i] = tonumber(s) end
                                
                                if #p == 4 then
                                    final_value = Vector4f.new(p[1], p[2], p[3], p[4])
                                elseif #p == 3 then
                                    final_value = Vector3f.new(p[1], p[2], p[3])
                                end
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
    
    -- ********** DEFERRED PROPERTY SETTING **********
    -- Queue the function that will set properties on the next frame.
    _G.deferred_calls = _G.deferred_calls or {}
    
    local property_setter_fn = function()
        for _, comp_props in ipairs(components_to_process) do
            -- Apply properties via the nested deferred logic.
            for prop_key, final_value in pairs(comp_props.data) do
                defer_set_component_property(
                    comp_props.component, 
                    prop_key, 
                    final_value, 
                    comp_props.type_name
                )
            end
        end
    end
    
    -- Queue the property setter function (which handles property assignment)
    if _G.deferred_calls[new_gameobj] then
        if type(_G.deferred_calls[new_gameobj]) ~= "table" then
             _G.deferred_calls[new_gameobj] = { _G.deferred_calls[new_gameobj] }
        end
        table.insert(_G.deferred_calls[new_gameobj], { lua_func = property_setter_fn })
    else
        _G.deferred_calls[new_gameobj] = { lua_func = property_setter_fn }
    end
    
    -- ***********************************************

    local new_obj = EMV_GameObject.class.new(new_xform)
    new_obj.name = obj_name

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

    return new_obj
end

return EMV_GameObject