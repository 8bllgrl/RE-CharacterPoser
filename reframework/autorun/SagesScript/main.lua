local dropdown_name = "Dropdown_Test"
local active_item = 1
local options = {"Option A", "Option B", "Option C"}

-- This function draws the UI and handles the dropdown logic
re.on_draw_ui(function()
    if imgui.tree_node(dropdown_name) then
        -- This combo box creates the dropdown menu
        local changed, new_item_index = imgui.combo("Select an Option", active_item, options)
        
        if changed then
            active_item = new_item_index
            re.msg("Selected item: " .. options[active_item])
        end

        imgui.tree_pop()
    end
end)