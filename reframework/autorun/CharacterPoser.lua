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
    json_files = {},
    selected_json_name = nil,
    gizmo_matrix = Matrix4x4f.identity(),
    gizmo_translate_enabled = true,
    gizmo_rotate_enabled = true,
    gizmo_scale_enabled = true,
}

-- Custom deferred call function to execute commands. This replaces the reliance on init.lua's loop.
local function execute_deferred_command(cmd)
    local success, err
    local obj = cmd.obj -- The object (component or GO) to call the function on

    if cmd.lua_func then
        -- Execute a wrapped Lua function
        success, err = pcall(cmd.lua_func)
    elseif cmd.func then
        -- Execute a native method call
        if cmd.args then
            success, err = pcall(obj.call, obj, cmd.func, cmd.args)
        else
            success, err = pcall(obj.call, obj, cmd.func)
        end
    end
    
    if not success then
        EMV_Utils.logv("Failed to execute deferred command: " .. tostring(err) .. " on " .. tostring(obj))
        return false -- Command failed.
    end
    return true
end

local function initialize_script()
    local state = _G.CharacterPoser_State
    local loaded_settings = EMV_IO.load_file("CharacterPoser_Settings.json")
    state.settings = EMV_Utils.merge_tables(state.settings, loaded_settings)
    
    -- Fetch all character files directly
    state.json_files = EMV_IO.get_json_files() 
    if state.json_files and #state.json_files.names > 0 then
        state.selected_json_name = state.json_files.names[1]
    end
    
    state.is_initialized = true
end

re.on_script_reset(function()
    _G.CharacterPoser_State.is_initialized = false
    -- Also reset the custom queue on reset
    _G.CharacterPoser_DeferredQueue = {} 
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
    -- 1. Process local object updates
    for _, obj in ipairs(_G.CharacterPoser_State.collection) do
        obj:update()
    end

    -- 2. Process the script's custom deferred queue (DECOUPLED EXECUTION)
    local queue = _G.CharacterPoser_DeferredQueue
    if queue and next(queue) then
        local objects_to_remove = {}
        for gameobj, commands in pairs(queue) do
            
            -- Execute commands from the start, removing as we go.
            for i = #commands, 1, -1 do
                local cmd = commands[i]
                -- Execute the command, passing the managed object key from the queue as the target
                if execute_deferred_command(cmd) then
                    -- Command succeeded, remove it from the list
                    table.remove(commands, i)
                else
                    -- Command failed (Access Violation/Error), stop processing this object's queue for this frame
                    break 
                end
            end

            -- Check if the command list for this object is now empty
            if #commands == 0 then
                table.insert(objects_to_remove, gameobj)
            end
        end

        -- Clean up object entries from the main queue
        for _, gameobj in ipairs(objects_to_remove) do
            queue[gameobj] = nil
        end
    end
end)