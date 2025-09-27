-- File: reframework/autorun/CharacterPoser/EMV_Poser_UI.lua
local EMV_Poser_UI = {}
local EMV_Utils = require("CharacterPoser/EMV_Utils")
local EMV_IO = require("CharacterPoser/EMV_IO")
local EMV_GameObject = require("CharacterPoser/EMV_GameObject")
local EMV_UI_Helpers = require("CharacterPoser/EMV_UI_Helpers")

function EMV_Poser_UI.draw_poser_ui_content()
    local state = _G.CharacterPoser_State
    
    -- Dropdown for character folders - REMOVED

    -- Dropdown for JSON files
    if state.json_files and state.json_files.names and #state.json_files.names > 0 then
        local current_item_index = state.json_files.indexes[state.selected_json_name] or 1
        local changed, new_index = imgui.combo("Select Character File", current_item_index, state.json_files.names)
        if changed then
            state.selected_json_name = state.json_files.names[new_index]
        end
        
        imgui.same_line()
        if imgui.button("Create!") then
            if state.selected_json_name then
                local file_path = state.json_files.paths[state.selected_json_name]
                local json_data = EMV_IO.load_file(file_path)
                -- Pass the full file_path instead of the folder/character_folder name
                local created_object = EMV_GameObject.class.create_from_json(json_data, nil, state.gizmo_matrix[3]:to_vec3(), file_path)
                if created_object then
                    table.insert(state.collection, created_object)
                end
            end
        end
    else
        imgui.text("No JSON character files found.")
    end
    
    state.gizmo_matrix = EMV_UI_Helpers.draw_gizmo_ui(state.gizmo_matrix)

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

return EMV_Poser_UI