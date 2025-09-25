-- File: reframework/autorun/SagesScript/CharacterPoser.lua

-- Import necessary modules
local EMV_Utils = require("EMV_Utils")
local EMV_UI_Helpers = require("EMV_UI_Helpers")
local EMV_GameObject = require("EMV_GameObject")
local EMV_IO = require("EMV_IO")

-- Define global state and settings
_G.CharacterPoser_State = _G.CharacterPoser_State or {
    settings = {
        detach_window = false,
        last_selected_object = nil,
    },
    collection = {}, -- This will hold your custom GameObject instances
}

-- Function to save settings to file
local function save_settings()
    EMV_IO.dump_file("CharacterPoser_Settings.json", _G.CharacterPoser_State.settings)
end

-- Function containing the main UI content for the Character Poser tool
local function draw_poser_ui_content()
    -- UI content will go here
    imgui.text("Main UI panel.")
    if EMV_UI_Helpers.my_custom_button("Create Object") then
        local new_obj = EMV_GameObject.class.new(nil)
        table.insert(_G.CharacterPoser_State.collection, new_obj)
    end
    
    -- Loop through the collection of GameObjects and draw their UI
    if #_G.CharacterPoser_State.collection > 0 then
        if imgui.tree_node("Managed Objects") then
            for _, obj in ipairs(_G.CharacterPoser_State.collection) do
                if imgui.tree_node(obj.name) then
                    obj:imgui_xform()
                    imgui.tree_pop()
                end
            end
            imgui.tree_pop()
        end
    end
end

-- Load settings from a file on script start
re.on_script_reset(function()
    local loaded_settings = EMV_IO.load_file("CharacterPoser_Settings.json")
    _G.CharacterPoser_State.settings = EMV_Utils.merge_tables(_G.CharacterPoser_State.settings, loaded_settings)
end)

-- Main UI function
re.on_draw_ui(function()
    local settings = _G.CharacterPoser_State.settings
    local window_title = "Character Poser"

    -- When the window is NOT detached, it appears inside the main REFramework UI.
    -- This section only contains the toggle checkbox.
    if not settings.detach_window then
        if imgui.tree_node(window_title) then
            -- Detach checkbox
            local changed, state = imgui.checkbox("Detach Window", settings.detach_window)
            if changed then
                settings.detach_window = state
                save_settings()
            end
            imgui.tree_pop()
        end
    else
        -- When the window IS detached, it's a separate ImGui window.
        local window_is_open = imgui.begin_window(window_title, true, 0)
        
        if window_is_open then
            local changed, state = imgui.checkbox("Detach Window", settings.detach_window)
            if changed then
                settings.detach_window = state
                save_settings()
            end
            
            -- Call the function that draws all the tool's content
            draw_poser_ui_content()
            
            imgui.end_window()
        else
            -- If the window is closed by the user, we re-attach it by setting the state to false.
            settings.detach_window = false
            save_settings() -- Save the settings here.
        end
    end
end)

-- Main update loop
re.on_frame(function()
    -- Loop through the collection of GameObjects and update them
    for _, obj in ipairs(_G.CharacterPoser_State.collection) do
        obj:update()
    end
end)

-- Note: The re.on_script_unloaded hook is not a valid API call in REFramework Lua,
-- so we rely on saving settings when the window is closed or the detach state changes.