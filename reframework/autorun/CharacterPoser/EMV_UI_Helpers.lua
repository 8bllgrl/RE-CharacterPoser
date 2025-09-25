-- File: reframework/autorun/CharacterPoser/EMV_UI_Helpers.lua
local EMV_UI_Helpers = {}
local EMV_Utils = require("CharacterPoser/EMV_Utils")

function EMV_UI_Helpers.my_custom_button(label)
    if imgui.button(label) then
        return true
    end
    return false
end

function EMV_UI_Helpers.draw_gizmo(gizmo_matrix, operation, mode)
    local gizmo_id = 123456789
    local changed, new_matrix = draw.gizmo(gizmo_id, gizmo_matrix, operation, mode)
    if changed then
        return true, new_matrix
    end
    return false, gizmo_matrix
end

function EMV_UI_Helpers.draw_world_to_screen(pos)
    return draw.world_to_screen(pos)
end

function EMV_UI_Helpers.draw_gizmo_ui(gizmo_matrix)
    local state = _G.CharacterPoser_State
    local current_matrix = gizmo_matrix

    -- Gizmo controls
    imgui.text("Gizmo Controls")
    imgui.same_line()
    if imgui.button("Reset Gizmo") then
        -- Correctly re-assign the variable with a new matrix object
        current_matrix = Matrix4x4f.identity()
    end

    imgui.same_line()
    if imgui.button("Move to Camera") and _G.last_camera_matrix then
        local cam_pos, rot, scale = EMV_Utils.mat4_to_trs(_G.last_camera_matrix)
        local new_pos = cam_pos + _G.last_camera_matrix[2]:to_vec3() * 1.1
        -- Correctly re-assign the variable with a new matrix object
        current_matrix = EMV_Utils.trs_to_mat4(new_pos, rot, scale)
    end

    -- Operation checkboxes
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
    
    -- Draw the gizmo
    local gizmo_changed, new_matrix_from_gizmo = EMV_UI_Helpers.draw_gizmo(current_matrix, combined_operation, imgui.ImGuizmoMode.WORLD)
    current_matrix = gizmo_changed and new_matrix_from_gizmo or current_matrix

    -- TRS for UI floats
    local pos, rot, scale = EMV_Utils.mat4_to_trs(current_matrix)
    local changed_pos, new_pos = imgui.drag_float3("Position", pos, 0.01, -10000.0, 10000.0)
    if changed_pos then
        -- Correctly re-assign the variable with a new matrix object
        current_matrix = EMV_Utils.trs_to_mat4(new_pos, rot, scale)
    end
    
    -- Return the updated matrix for the caller to use
    return current_matrix
end

return EMV_UI_Helpers