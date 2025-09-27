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

local function get_component_commands(new_component, prop_key, final_value, comp_type_name)
    return
end


function EMV_GameObject.class.create_from_json(json_data, parent_xform, spawn_position, parent_file_path, recursion_depth)
    return
end

return EMV_GameObject