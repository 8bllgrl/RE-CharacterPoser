-- File: CharacterPoser.lua

-- Define the global settings table
_G.CharacterPoser_Settings = _G.CharacterPoser_Settings or {
    detach_window = false,
    -- Add other settings here later
}

-- Main UI draw function
re.on_draw_ui(function()
    
    local window_title = "Character Poser"

    -- Check if the window should be detached.
    -- If it's not detached, draw the UI inside a collapsible tree node.
    if not _G.CharacterPoser_Settings.detach_window then
        if imgui.tree_node(window_title) then
            -- Checkbox to toggle detachment
            local changed, state = imgui.checkbox("Detach Window", _G.CharacterPoser_Settings.detach_window)
            if changed then
                _G.CharacterPoser_Settings.detach_window = state
            end

            -- Main content of your UI goes here.
            imgui.text("This is the main content of the Character Poser UI.")
            imgui.text("Add gizmos, object lists, and other controls here.")

            imgui.tree_pop()
        end
    else
        -- If the window is detached, create a separate window for it.
        -- If the user closes this window, imgui.begin_window will return false.
        local window_is_open, new_window_state = imgui.begin_window(window_title, true, 0)
        
        if window_is_open then
            -- Checkbox to re-attach the window
            local changed, state = imgui.checkbox("Detach Window", _G.CharacterPoser_Settings.detach_window)
            if changed then
                _G.CharacterPoser_Settings.detach_window = state
            end
            
            -- Main content of your UI goes here.
            imgui.text("This window is now detached!")
            imgui.text("You can drag it anywhere.")

            imgui.end_window()
        else
            -- If the window is closed, set the detachment state to false
            _G.CharacterPoser_Settings.detach_window = false
        end
    end
end)

-- You would also need to add other re.on_frame, re.on_application_entry, etc.
-- callbacks for your script's logic here.