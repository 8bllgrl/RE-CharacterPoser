-- File: reframework/autorun/CharacterPoser/CharacterPoser.lua

-- Import necessary modules
local EMV_Utils = require("CharacterPoser/EMV_Utils")
local EMV_UI_Helpers = require("CharacterPoser/EMV_UI_Helpers")
local EMV_GameObject = require("CharacterPoser/EMV_GameObject")
local EMV_IO = require("CharacterPoser/EMV_IO")

-- Define global state and settings
_G.CharacterPoser_State = _G.CharacterPoser_State or {
    is_initialized = false, 
    settings = {
        detach_window = false,
        last_selected_object = nil,
    },
    collection = {}, 
    character_folders = {}, 
    selected_character_folder = nil,
    json_files = {},
    selected_json_name = nil,
    gizmo_matrix = Matrix4x4f.identity(),
    gizmo_translate_enabled = true,
    gizmo_rotate_enabled = true,
    gizmo_scale_enabled = true,
}
-- Function to save settings to file
local function save_settings()
    EMV_IO.dump_file("CharacterPoser_Settings.json", _G.CharacterPoser_State.settings)
end

local function draw_gizmo_ui(gizmo_matrix)
    local state = _G.CharacterPoser_State
    imgui.text("Gizmo Controls")
    imgui.same_line()
    if imgui.button("Reset Gizmo") then
        gizmo_matrix = Matrix4x4f.identity()
    end
    
    -- "Move to Camera" with corrected rotation behavior.
    imgui.same_line()
    if imgui.button("Move to Camera") and _G.last_camera_matrix then
        local cam_pos, _, _ = EMV_Utils.mat4_to_trs(_G.last_camera_matrix)
        
        -- Apply a small offset along the camera's forward vector to prevent spawning inside the camera.
        local new_pos = cam_pos + _G.last_camera_matrix[2]:to_vec3() * 2.0
        
        -- Reset rotation to the identity quaternion, effectively a 0 rotation.
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
    
    -- The scale toggle has been removed.

    local combined_operation = 0
    if state.gizmo_translate_enabled then
        combined_operation = combined_operation + imgui.ImGuizmoOperation.TRANSLATE
    end
    if state.gizmo_rotate_enabled then
        combined_operation = combined_operation + imgui.ImGuizmoOperation.ROTATE
    end
    -- The scale operation is no longer included here.
    
    local changed, new_matrix = EMV_UI_Helpers.draw_gizmo(gizmo_matrix, combined_operation, imgui.ImGuizmoMode.WORLD)
    if changed then
        return new_matrix
    end
    return gizmo_matrix
end

local function draw_poser_ui_content()
    local state = _G.CharacterPoser_State
    
    -- Dropdown for character folders
    if #state.character_folders > 0 then
        local current_folder_index = EMV_Utils.find_index(state.character_folders, state.selected_character_folder) or 1
        local changed, new_index = imgui.combo("Select Folder", current_folder_index, state.character_folders)
        if changed then
            state.selected_character_folder = state.character_folders[new_index]
            state.json_files = EMV_IO.get_json_files(state.selected_character_folder)
            state.selected_json_name = state.json_files.names[1]
        end
    end

    -- Dropdown for JSON files
    if state.json_files and state.json_files.names and #state.json_files.names > 0 then
        local current_item_index = state.json_files.indexes[state.selected_json_name] or 1
        local changed, new_index = imgui.combo("Select Character File", current_item_index, state.json_files.names)
        if changed then
            state.selected_json_name = state.json_files.names[new_index]
        end
        
        imgui.same_line()
        if imgui.button("Create!") then
            if state.selected_json_name and state.selected_character_folder then
                local file_path = state.json_files.paths[state.selected_json_name]
                local json_data = EMV_IO.load_file(file_path)
                local created_object = EMV_GameObject.class.create_from_json(json_data, nil, state.gizmo_matrix[3]:to_vec3(), state.selected_character_folder)
                if created_object then
                    table.insert(state.collection, created_object)
                end
            end
        end
    else
        imgui.text("No JSON character files found in the selected folder.")
    end
    
    state.gizmo_matrix = draw_gizmo_ui(state.gizmo_matrix)

    if #state.collection > 0 then
        if imgui.tree_node("Managed Objects") then
            for _, obj in ipairs(state.collection) do
                if imgui.tree_node(obj.name) then
                    obj:imgui_xform()
                    imgui.tree_pop()
                end
            end
            imgui.tree_pop()
        end
    end
end

local function initialize_script()
    local state = _G.CharacterPoser_State
    local loaded_settings = EMV_IO.load_file("CharacterPoser_Settings.json")
    state.settings = EMV_Utils.merge_tables(state.settings, loaded_settings)
    
    state.character_folders = EMV_IO.get_character_folders()
    if #state.character_folders > 0 then
        state.selected_character_folder = state.character_folders[1]
        state.json_files = EMV_IO.get_json_files(state.selected_character_folder)
        if state.json_files and #state.json_files.names > 0 then
            state.selected_json_name = state.json_files.names[1]
        end
    end
    
    state.is_initialized = true
end

re.on_script_reset(function()
    _G.CharacterPoser_State.is_initialized = false
    initialize_script()
end)

re.on_draw_ui(function()
    if not _G.CharacterPoser_State.is_initialized then
        initialize_script()
    end

    local settings = _G.CharacterPoser_State.settings
    local window_title = "Character Poser"

    if not settings.detach_window then
        if imgui.tree_node(window_title) then
            local changed, state = imgui.checkbox("Detach Window", settings.detach_window)
            if changed then
                settings.detach_window = state
                save_settings()
            end
            imgui.tree_pop()
        end
    else
        local window_is_open = imgui.begin_window(window_title, true, 0)
        
        if window_is_open then
            draw_poser_ui_content()
            imgui.end_window()
        else
            settings.detach_window = false
            save_settings()
        end
    end
end)

re.on_frame(function()
    for _, obj in ipairs(_G.CharacterPoser_State.collection) do
        obj:update()
    end
end)