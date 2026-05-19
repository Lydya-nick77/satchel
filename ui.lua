local imgui = require('imgui')

local ui = {}

-- Ashita 4.3 adjusted BeginChild overloads; try multiple signatures for compatibility.
local function begin_child_compat(id, size, border, flags)
    local ok, began = pcall(imgui.BeginChild, id, size, border, flags)
    if ok then
        return began
    end

    ok, began = pcall(imgui.BeginChild, id, size, flags)
    if ok then
        return began
    end

    ok, began = pcall(imgui.BeginChild, id, size)
    if ok then
        return began
    end

    return false
end

function ui.render_left_tab_column(available_tabs, current_tab, format_tab_label)
    if current_tab == nil and #available_tabs > 0 then
        current_tab = available_tabs[1]
    end

    local selected_color = { 0.32, 0.26, 0.12, 1.0 }
    local hover_color = { 0.24, 0.20, 0.12, 1.0 }
    local idle_color = { 0.10, 0.10, 0.10, 1.0 }
    local text_selected = { 1.0, 0.90, 0.60, 1.0 }
    local text_idle = { 0.82, 0.82, 0.82, 1.0 }

    imgui.PushStyleColor(ImGuiCol_Button, idle_color)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover_color)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, selected_color)
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4.0)

    for i, container_id in ipairs(available_tabs) do
        local is_selected = (container_id == current_tab)
        local label = format_tab_label(container_id)

        if is_selected then
            imgui.PushStyleColor(ImGuiCol_Button, selected_color)
            imgui.PushStyleColor(ImGuiCol_Text, text_selected)
        else
            imgui.PushStyleColor(ImGuiCol_Text, text_idle)
        end

        if imgui.Button(label .. ('##satchel_tab_%d'):format(container_id), { 110, 0 }) then
            current_tab = container_id
        end

        if is_selected then
            imgui.PopStyleColor(2)
        else
            imgui.PopStyleColor(1)
        end

        if i < #available_tabs then
            imgui.Dummy({ 0, 2 })
        end
    end

    imgui.PopStyleVar(1)
    imgui.PopStyleColor(3)

    return current_tab
end

local function draw_slot(slot, index, key_prefix, ctx)
    local slot_size = ctx.settings.slot_size
    local icon_padding = 2
    local icon_size = math.max(20, slot_size - (icon_padding * 2))
    local child_flags = bit.bor(ImGuiWindowFlags_NoScrollbar or 0, ImGuiWindowFlags_NoScrollWithMouse or 0)

    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.11, 0.11, 0.10, 0.95 })
    imgui.PushStyleColor(ImGuiCol_Border, ctx.get_slot_border_color(slot))
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 })

    local began = begin_child_compat(('##satchel_slot_%s_%d'):format(tostring(key_prefix or 'all'), index), { slot_size, slot_size }, true, child_flags)
    if began then
        if slot.id and slot.id > 0 then
            local tex = ctx.load_item_icon(slot.id)
            if tex then
                imgui.SetCursorPos({ icon_padding, icon_padding })
                imgui.Image(ctx.tex_ptr(tex), { icon_size, icon_size }, { 0, 0 }, { 1, 1 }, { 1, 1, 1, 1 }, { 0, 0, 0, 0 })
            else
                imgui.SetCursorPos({ 4, 8 })
                imgui.TextColored({ 0.9, 0.82, 0.50, 1.0 }, '?')
            end

            if slot.count and slot.count > 1 then
                local qty_text = tostring(slot.count)
                local text_w, text_h = imgui.CalcTextSize(qty_text)
                text_w = tonumber(text_w) or 0
                text_h = tonumber(text_h) or 0
                local x = math.max(2, slot_size - text_w - 3)
                local y = math.max(2, slot_size - text_h - 2)
                imgui.SetCursorPos({ x, y })
                imgui.TextColored({ 0.99, 0.95, 0.75, 1.0 }, qty_text)
            end
        end
    end
    imgui.EndChild()

    imgui.PopStyleVar(1)
    imgui.PopStyleColor(2)

    if imgui.IsItemHovered() and slot.id and slot.id > 0 then
        ctx.render_item_detail_tooltip(slot)
    end
end

function ui.render_slot_grid(slots, key_prefix, stat, ctx)
    local packed = {}
    local empties = {}

    for _, slot in ipairs(slots or {}) do
        if slot and slot.id and slot.id > 0 then
            table.insert(packed, slot)
        else
            table.insert(empties, slot)
        end
    end

    table.sort(packed, function(a, b)
        local a_primary, a_secondary = ctx.get_item_sort_key(a.id)
        local b_primary, b_secondary = ctx.get_item_sort_key(b.id)

        if a_primary ~= b_primary then
            return a_primary < b_primary
        end

        if a_secondary ~= b_secondary then
            return a_secondary < b_secondary
        end

        local an = (ctx.get_item_name(a.id) or ''):lower()
        local bn = (ctx.get_item_name(b.id) or ''):lower()
        if an == bn then
            if a.id ~= b.id then
                return (a.id or 0) < (b.id or 0)
            end
            return (a.slot_index or 0) < (b.slot_index or 0)
        end
        return an < bn
    end)

    if ctx.settings.show_empty_slots then
        for _, slot in ipairs(empties) do
            table.insert(packed, slot)
        end
    end

    local columns = math.max(4, tonumber(ctx.settings.columns) or 10)
    local total_slots = #packed
    local shown_slots = math.max(1, total_slots)
    local used_columns = math.max(1, math.min(columns, shown_slots))
    local row_count = math.max(1, math.ceil(shown_slots / columns))
    local cell_gap = 2
    local slot_size = ctx.settings.slot_size or ctx.default_slot_size
    local grid_width = (used_columns * slot_size) + ((used_columns - 1) * cell_gap)
    local grid_height = (row_count * slot_size) + ((row_count - 1) * cell_gap)

    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { cell_gap, cell_gap })
    begin_child_compat(('##satchel_grid_%s'):format(tostring(key_prefix)), { grid_width, grid_height }, false, 0)
    for i = 1, total_slots do
        local slot = packed[i]

        draw_slot(slot, i, tostring(key_prefix), ctx)

        if i % columns ~= 0 then
            imgui.SameLine(0, cell_gap)
        end
    end

    if total_slots == 0 then
        imgui.TextColored({ 0.75, 0.75, 0.75, 1.0 }, 'No slots to display.')
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)

    local used = (stat and stat.used) or 0
    local total = (stat and stat.total) or 0
    imgui.TextColored({ 0.78, 0.78, 0.78, 1.0 }, ('Used: %d / %d'):format(used, total))
end

return ui
