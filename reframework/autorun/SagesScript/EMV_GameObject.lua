-- File: EMV_GameObject.lua
local EMV_GameObject = {}

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

return EMV_GameObject