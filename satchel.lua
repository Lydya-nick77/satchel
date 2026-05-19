addon.name      = 'satchel'
addon.author    = 'Lydya'
addon.version   = '0.2.2'
addon.desc      = 'Displays an inventory grid with item icons.'
addon.link      = 'https://ashitaxi.com/'

require('common')
local chat = require('chat')
local imgui = require('imgui')
local settings = require('settings')
local ui = dofile(addon.path .. 'ui.lua')
local itemlogic = dofile(addon.path .. 'itemlogic.lua')
local containerlogic = dofile(addon.path .. 'containerlogic.lua')
local commands = dofile(addon.path .. 'commands.lua')
local icons = dofile(addon.path .. 'icons.lua')

local default_settings = T{
    visible = true,
    columns = 10,
    rows = 10,
    slot_size = 40,
    show_empty_slots = true,
    include_containers = T{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
}

local satchel = T{
    settings = settings.load(default_settings),
    visible = { true },
    config_visible = { false },
    last_visible = true,
    active_tab = nil,
    resize_on_next_frame = false,
    icons = {},
    names = {},
    item_types = {},
    item_sort_keys = {},
}

local items = itemlogic.create({
    satchel = satchel,
    imgui = imgui,
})

local cmd = commands.create({
    addon = addon,
    chat = chat,
    settings = settings,
    satchel = satchel,
    default_settings = default_settings,
    normalize_include_containers = containerlogic.normalize_include_containers,
})

local tab_order = containerlogic.tab_order

local function render_left_tab_column(available_tabs)
    return ui.render_left_tab_column(available_tabs, satchel.active_tab, function(container_id)
        return containerlogic.format_tab_label(container_id)
    end)
end

local function apply_settings(s)
    cmd.apply_settings(s)
end

settings.register('settings', 'settings_update', apply_settings)
apply_settings(satchel.settings)

ashita.events.register('load', 'satchel_load', function()
    apply_settings(satchel.settings)
    satchel.visible[1] = satchel.settings.visible == true
    satchel.config_visible[1] = false
    satchel.last_visible = satchel.visible[1]
end)

ashita.events.register('unload', 'satchel_unload', function()
    satchel.icons = {}
    items.clear_caches()
    settings.save()
end)

ashita.events.register('command', 'satchel_command', function(e)
    cmd.handle_command(e)
end)

local function render_slot_grid(slots, key_prefix, stat)
    ui.render_slot_grid(slots, key_prefix, stat, {
        settings = satchel.settings,
        default_slot_size = default_settings.slot_size,
        get_item_sort_key = items.get_item_sort_key,
        get_item_name = items.get_item_name,
        load_item_icon = function(item_id)
            return icons.load_item_icon(satchel, item_id)
        end,
        tex_ptr = icons.tex_ptr,
        get_slot_border_color = items.get_slot_border_color,
        render_item_detail_tooltip = items.render_item_detail_tooltip,
    })
end

ashita.events.register('key', 'satchel_key', function(e)
    if not satchel.visible[1] and not satchel.config_visible[1] then
        return
    end

    if e.wparam ~= 0x1B then
        return
    end

    -- Only react on keydown, not keyup.
    local is_key_down = bit.band(e.lparam, 0x80000000) == 0
    if not is_key_down then
        return
    end

    local changed_visibility = false
    if satchel.visible[1] then
        satchel.visible[1] = false
        satchel.last_visible = false
        satchel.settings.visible = false
        changed_visibility = true
    end

    if satchel.config_visible[1] then
        satchel.config_visible[1] = false
    end

    if changed_visibility then
        settings.save()
    end
    e.blocked = true
end)

local function render_config_window()
    if not satchel.config_visible[1] then
        return
    end

    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.06, 0.06, 0.06, 0.98 })
    imgui.PushStyleColor(ImGuiCol_Border, { 0.74, 0.62, 0.35, 1.0 })
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.34, 0.23, 0.09, 1.0 })
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.45, 0.30, 0.10, 1.0 })
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6.0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 2.0)

    local began = imgui.Begin('Satchel Config', satchel.config_visible, ImGuiWindowFlags_AlwaysAutoResize or 0)
    if began then
        local columns = { satchel.settings.columns or default_settings.columns }
        if imgui.SliderInt('Columns', columns, 4, 18) then
            satchel.settings.columns = columns[1]
            settings.save()
        end

        local rows = { satchel.settings.rows or default_settings.rows }
        if imgui.SliderInt('Rows', rows, 4, 16) then
            satchel.settings.rows = rows[1]
            settings.save()
        end

        local slot_size = { satchel.settings.slot_size or default_settings.slot_size }
        if imgui.SliderInt('Cell Size', slot_size, 24, 96) then
            satchel.settings.slot_size = slot_size[1]
            settings.save()
        end

        local show_empty = { satchel.settings.show_empty_slots == true }
        if imgui.Checkbox('Show Empty Slots', show_empty) then
            satchel.settings.show_empty_slots = show_empty[1]
            settings.save()
        end

        imgui.Separator()
        imgui.Text('Reset all satchel settings to defaults:')
        if imgui.Button('Reset Settings') then
            settings.reset()
        end
    end
    imgui.End()

    imgui.PopStyleVar(2)
    imgui.PopStyleColor(4)
end

ashita.events.register('d3d_present', 'satchel_present', function()
    render_config_window()

    if not satchel.visible[1] then
        return
    end

    local _, slots_by_container, stats = containerlogic.build_slot_data(satchel)

    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.05, 0.05, 0.05, 0.98 })
    imgui.PushStyleColor(ImGuiCol_Border, { 0.74, 0.62, 0.35, 1.0 })
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.34, 0.23, 0.09, 1.0 })
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.45, 0.30, 0.10, 1.0 })
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6.0)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 2.0)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4.0)
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 3.0)
    local pushed_style_vars = 4
    if ImGuiStyleVar_WindowTitleAlign ~= nil then
        imgui.PushStyleVar(ImGuiStyleVar_WindowTitleAlign, { 0.5, 0.5 })
        pushed_style_vars = pushed_style_vars + 1
    end

        local consume_resize = satchel.resize_on_next_frame == true
        local window_flags = bit.bor(ImGuiWindowFlags_NoCollapse or 0)
        if consume_resize then
            window_flags = bit.bor(window_flags, ImGuiWindowFlags_AlwaysAutoResize or 0)
    end
        satchel.resize_on_next_frame = false

    local began = imgui.Begin('Satchel', satchel.visible, window_flags)
    if began then
        satchel.settings.visible = satchel.visible[1]

        local available_tabs = T{}
        for _, container_id in ipairs(tab_order) do
            if containerlogic.is_tab_available(container_id, stats) then
                available_tabs:append(container_id)
            end
        end

        if #available_tabs == 0 then
            satchel.active_tab = nil
            imgui.TextColored({ 0.9, 0.72, 0.55, 1.0 }, 'No available inventory containers.')
        else
            local top_x, top_y = imgui.GetCursorPos()

            imgui.BeginGroup()
            local current_tab = render_left_tab_column(available_tabs)
            imgui.EndGroup()

            if current_tab ~= satchel.active_tab then
                satchel.active_tab = current_tab
                satchel.resize_on_next_frame = true
            end

            imgui.SameLine(0, 8)
            imgui.SetCursorPos({ top_x + 118, top_y })
            imgui.BeginGroup()
            local active_slots = slots_by_container[satchel.active_tab] or T{}
            local active_stats = stats[satchel.active_tab] or { used = 0, total = 0 }
            render_slot_grid(active_slots, tostring(satchel.active_tab or 0), active_stats)
            imgui.EndGroup()
        end
    end
    imgui.End()

    if satchel.visible[1] ~= satchel.last_visible then
        satchel.last_visible = satchel.visible[1]
        satchel.settings.visible = satchel.visible[1]
        settings.save()
    end

    imgui.PopStyleVar(pushed_style_vars)
    imgui.PopStyleColor(4)
end)

return satchel

