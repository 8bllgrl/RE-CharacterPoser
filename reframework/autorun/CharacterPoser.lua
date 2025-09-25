-- File: reframework/autorun/CharacterPoser/CharacterPoser.lua

-- Import necessary modules
local EMV_Utils = require("CharacterPoser/EMV_Utils")
local EMV_IO = require("CharacterPoser/EMV_IO")
local EMV_Poser_UI = require("CharacterPoser/EMV_Poser_UI")

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
                EMV_IO.save_settings(settings)
            end
            imgui.tree_pop()
        end
    else
        local window_is_open = imgui.begin_window(window_title, true, 0)
        
        if window_is_open then
            EMV_Poser_UI.draw_poser_ui_content()
            imgui.end_window()
        else
            settings.detach_window = false
            EMV_IO.save_settings(settings)
        end
    end
end)

re.on_frame(function()
    for _, obj in ipairs(_G.CharacterPoser_State.collection) do
        obj:update()
    end
end)