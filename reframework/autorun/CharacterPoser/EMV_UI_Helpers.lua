-- File: reframework/autorun/SagesScript/EMV_UI_Helpers.lua
local EMV_UI_Helpers = {}

function EMV_UI_Helpers.my_custom_button(label)
    if imgui.button(label) then
        return true
    end
    return false
end

function EMV_UI_Helpers.draw_gizmo(transform, operation, mode)
    local changed, new_transform = draw.gizmo(transform, transform, operation, mode)
    if changed then
        return true, new_transform
    end
    return false
end

function EMV_UI_Helpers.draw_world_to_screen(pos)
    return draw.world_to_screen(pos)
end

return EMV_UI_Helpers