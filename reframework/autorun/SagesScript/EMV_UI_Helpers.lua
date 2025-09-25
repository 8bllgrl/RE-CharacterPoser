-- File: EMV_UI_Helpers.lua
local EMV_UI_Helpers = {}

function EMV_UI_Helpers.my_custom_button(label)
    if imgui.button(label) then
        return true
    end
    return false
end

return EMV_UI_Helpers