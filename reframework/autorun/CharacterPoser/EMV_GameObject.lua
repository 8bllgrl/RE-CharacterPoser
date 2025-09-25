-- File: reframework/autorun/CharacterPoser/EMV_GameObject.lua
local EMV_GameObject = {}
local EMV_IO = require("CharacterPoser/EMV_IO")
local EMV_Utils = require("CharacterPoser/EMV_Utils")

-- The core GameObject class
EMV_GameObject.class = {}
EMV_GameObject.class.__index = EMV_GameObject.class

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

function EMV_GameObject.class.create_from_json(json_data, parent_xform, spawn_position, character_folder)
    -- Get the main game object name from the JSON
    local obj_name = next(json_data)
    local obj_data = json_data[obj_name]
    local components_list = obj_data["__components_order"]
    local children_list = obj_data["__children"]

    local new_gameobj = sdk.call_native_func(nil, "via.GameObject", "create(System.String)", obj_name)
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
        for _, child_name in ipairs(children_list) do
            local child_json_data = EMV_IO.load_file("reframework/data/CharacterPoser/chara/" .. character_folder .. "/" .. child_name .. ".json")
            if child_json_data and next(child_json_data) then
                EMV_GameObject.class.create_from_json(child_json_data, new_xform, nil, character_folder)
            end
        end
    end

    return new_obj
end

return EMV_GameObject