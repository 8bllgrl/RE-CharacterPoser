-- File: reframework/autorun/SagesScript/EMV_UI_Helpers.lua
local EMV_UI_Helpers = {}
local EMV_Utils = require("CharacterPoser/EMV_Utils")

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

function EMV_UI_Helpers.draw_gizmo_ui(gizmo_matrix)
    local state = _G.CharacterPoser_State
    imgui.text("Gizmo Controls")
    imgui.same_line()
    if imgui.button("Reset Gizmo") then
        gizmo_matrix = Matrix4x4f.identity()
    end
    
    imgui.same_line()
    if imgui.button("Move to Camera") and _G.last_camera_matrix then
        local cam_pos, _, _ = EMV_Utils.mat4_to_trs(_G.last_camera_matrix)
        local new_pos = cam_pos + _G.last_camera_matrix[2]:to_vec3() * 2.0
        gizmo_matrix = EMV_Utils.trs_to_mat4(new_pos, Quaternion.identity(), Vector3f.new(1, 1, 1))
    end

    local pos, rot, scale = EMV_Utils.mat4_to_trs(gizmo_matrix)
    
    local changed_pos, new_pos = imgui.drag_float3("Position", pos, 0.01, -10000.0, 10000.0)
    if changed_pos then
        gizmo_matrix = EMV_Utils.trs_to_mat4(new_pos, rot, scale)
    end
    
    imgui.text("Operation:")
    imgui.same_line()
    local changed_translate, new_translate = imgui.checkbox("Translate", state.gizmo_translate_enabled)
    if changed_translate then
        state.gizmo_translate_enabled = new_translate
    end
    
    imgui.same_line()
    local changed_rotate, new_rotate = imgui.checkbox("Rotate", state.gizmo_rotate_enabled)
    if changed_rotate then
        state.gizmo_rotate_enabled = new_rotate
    end
    
    local combined_operation = 0
    if state.gizmo_translate_enabled then
        combined_operation = combined_operation + imgui.ImGuizmoOperation.TRANSLATE
    end
    if state.gizmo_rotate_enabled then
        combined_operation = combined_operation + imgui.ImGuizmoOperation.ROTATE
    end
    
    local changed, new_matrix = EMV_UI_Helpers.draw_gizmo(gizmo_matrix, combined_operation, imgui.ImGuizmoMode.WORLD)
    if changed then
        return new_matrix
    end
    return gizmo_matrix
end

return EMV_UI_Helpers