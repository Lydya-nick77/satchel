local breader = require('bitreader')

local function create_item_logic(ctx)
    local satchel = ctx.satchel
    local imgui = ctx.imgui

    local job_abbr = {
        [1] = 'WAR',
        [2] = 'MNK',
        [3] = 'WHM',
        [4] = 'BLM',
        [5] = 'RDM',
        [6] = 'THF',
        [7] = 'PLD',
        [8] = 'DRK',
        [9] = 'BST',
        [10] = 'BRD',
        [11] = 'RNG',
        [12] = 'SAM',
        [13] = 'NIN',
        [14] = 'DRG',
        [15] = 'SMN',
        [16] = 'BLU',
        [17] = 'COR',
        [18] = 'PUP',
        [19] = 'DNC',
        [20] = 'SCH',
        [21] = 'GEO',
        [22] = 'RUN',
    }

    local element_colors = {
        Fire      = {1.00, 0.35, 0.12, 1.0},
        Ice       = {0.50, 0.90, 1.00, 1.0},
        Wind      = {0.30, 0.92, 0.35, 1.0},
        Earth     = {0.78, 0.58, 0.22, 1.0},
        Lightning = {1.00, 0.95, 0.25, 1.0},
        Water     = {0.25, 0.55, 1.00, 1.0},
        Light     = {1.00, 1.00, 0.85, 1.0},
        Dark      = {0.70, 0.22, 0.90, 1.0},
    }
    local element_list_ordered = {'Lightning', 'Water', 'Light', 'Dark', 'Fire', 'Ice', 'Wind', 'Earth'}

    local armor_slot_masks = {
        head = 0x0010,
        body = 0x0020,
        hands = 0x0040,
        legs = 0x0080,
        feet = 0x0100,
        neck = 0x0200,
        waist = 0x0400,
        ear = bit.bor(0x0800, 0x1000),
        ring = bit.bor(0x2000, 0x4000),
        back = 0x8000,
    }

    local weapon_slot_masks = {
        main = 0x0001,
        sub = 0x0002,
        range = 0x0004,
        ammo = 0x0008,
    }

    local M = {}

    local function trim_text(value)
        if type(value) ~= 'string' then
            return ''
        end
        return value:match('^%s*(.-)%s*$') or ''
    end

    function M.clear_caches()
        satchel.names = {}
        satchel.item_types = {}
        satchel.item_sort_keys = {}
    end

    function M.get_item_name(item_id)
        if not item_id or item_id <= 0 then
            return 'Empty'
        end

        local cached = satchel.names[item_id]
        if cached then
            return cached
        end

        local ok, item = pcall(function()
            return AshitaCore:GetResourceManager():GetItemById(item_id)
        end)

        local name = ('Item #%d'):format(item_id)
        if ok and item and item.Name and item.Name[1] and item.Name[1] ~= '' then
            name = item.Name[1]
        end

        satchel.names[item_id] = name
        return name
    end

    function M.get_item_type(item_id)
        if not item_id or item_id <= 0 then
            return 0
        end

        local cached = satchel.item_types[item_id]
        if cached ~= nil then
            return cached
        end

        local kind = 0
        local ok, item = pcall(function()
            return AshitaCore:GetResourceManager():GetItemById(item_id)
        end)
        if ok and item and item.Type then
            kind = tonumber(item.Type) or 0
        end

        satchel.item_types[item_id] = kind
        return kind
    end

    function M.get_item_resource(item_id)
        if not item_id or item_id <= 0 then
            return nil
        end

        local ok, item = pcall(function()
            return AshitaCore:GetResourceManager():GetItemById(item_id)
        end)
        if ok and item then
            return item
        end
        return nil
    end

    local function get_armor_slot_rank(item)
        if not item then
            return 99
        end

        local slots = tonumber(item.Slots) or 0
        if slots <= 0 then
            return 99
        end

        if bit.band(slots, armor_slot_masks.head) ~= 0 then return 1 end
        if bit.band(slots, armor_slot_masks.body) ~= 0 then return 2 end
        if bit.band(slots, armor_slot_masks.hands) ~= 0 then return 3 end
        if bit.band(slots, armor_slot_masks.legs) ~= 0 then return 4 end
        if bit.band(slots, armor_slot_masks.feet) ~= 0 then return 5 end
        if bit.band(slots, armor_slot_masks.neck) ~= 0 then return 6 end
        if bit.band(slots, armor_slot_masks.waist) ~= 0 then return 7 end
        if bit.band(slots, armor_slot_masks.back) ~= 0 then return 8 end
        if bit.band(slots, armor_slot_masks.ear) ~= 0 then return 9 end
        if bit.band(slots, armor_slot_masks.ring) ~= 0 then return 10 end
        return 99
    end

    local function get_weapon_slot_rank(item)
        if not item then
            return 99
        end

        local slots = tonumber(item.Slots) or 0
        if slots <= 0 then
            return 99
        end

        if bit.band(slots, weapon_slot_masks.main) ~= 0 then return 1 end
        if bit.band(slots, weapon_slot_masks.sub) ~= 0 then return 2 end
        if bit.band(slots, weapon_slot_masks.range) ~= 0 then return 3 end
        if bit.band(slots, weapon_slot_masks.ammo) ~= 0 then return 4 end
        return 99
    end

    local function get_crystal_subrank(item_name)
        local name = (item_name or ''):lower()
        if name:find('cluster', 1, true) then
            return 2
        end
        if name:find(' crystal', 1, true) then
            return 1
        end
        return 3
    end

    local function get_element_rank_from_name(name)
        if type(name) ~= 'string' then
            return 99
        end
        local lowered = name:lower()

        if lowered:find('fire', 1, true) then return 1 end
        if lowered:find('ice', 1, true) then return 2 end
        if lowered:find('wind', 1, true) then return 3 end
        if lowered:find('earth', 1, true) then return 4 end
        if lowered:find('lightning', 1, true) then return 5 end
        if lowered:find('water', 1, true) then return 6 end
        if lowered:find('light', 1, true) then return 7 end
        if lowered:find('dark', 1, true) then return 8 end
        return 99
    end

    function M.get_item_sort_key(item_id)
        if not item_id or item_id <= 0 then
            return 99, 99
        end

        local cached = satchel.item_sort_keys[item_id]
        if cached then
            return cached.primary, cached.secondary
        end

        local item_type = M.get_item_type(item_id)
        local item = M.get_item_resource(item_id)
        local item_name = M.get_item_name(item_id)
        local crystal_rank = get_crystal_subrank(item_name)
        local primary = 5
        local secondary = 99

        if crystal_rank <= 2 then
            primary = 1
            local element_rank = get_element_rank_from_name(item_name)
            secondary = (crystal_rank * 100) + element_rank
        elseif item_type == 7 then
            primary = 2
        elseif item_type == 4 then
            primary = 3
            secondary = get_weapon_slot_rank(item)
        elseif item_type == 5 then
            primary = 4
            secondary = get_armor_slot_rank(item)
        end

        satchel.item_sort_keys[item_id] = { primary = primary, secondary = secondary }
        return primary, secondary
    end

    local function read_number_field(item, field_name)
        local ok, value = pcall(function()
            return item[field_name]
        end)
        if not ok then
            return nil
        end
        local n = tonumber(value)
        if n and n > 0 then
            return n
        end
        return nil
    end

    local function format_duration(seconds)
        local total = math.max(0, math.floor(tonumber(seconds) or 0))
        local hours = math.floor(total / 3600)
        local minutes = math.floor((total % 3600) / 60)
        local secs = total % 60

        if hours > 0 then
            return ('%d:%02d:%02d'):format(hours, minutes, secs)
        end
        return ('%d:%02d'):format(minutes, secs)
    end

    local function get_inventory_item(slot)
        if not slot or slot.container_id == nil or slot.slot_index == nil then
            return nil
        end

        local inv = AshitaCore:GetMemoryManager():GetInventory()
        if not inv then
            return nil
        end

        local ok, item = pcall(function()
            return inv:GetContainerItem(slot.container_id, (slot.slot_index or 0) + 1)
        end)
        if ok and item and item.Id and tonumber(item.Id) == tonumber(slot.id) then
            return item
        end
        return nil
    end

    local function get_enchantment_info(slot, item, resource)
        if not resource or not item then
            return nil
        end

        local max_charges = tonumber(resource.MaxCharges) or 0
        local equip_delay = tonumber(resource.CastDelay) or 0
        local reuse_delay = tonumber(resource.RecastDelay) or 0
        if max_charges <= 0 and equip_delay <= 0 and reuse_delay <= 0 then
            return nil
        end

        local info = {
            max_charges = max_charges,
            equip_delay = equip_delay,
            reuse_delay = reuse_delay,
            remaining_charges = nil,
        }

        local inv_item = get_inventory_item(slot)
        if inv_item and inv_item.Extra then
            local ok, reader = pcall(function()
                return breader:new(T{}, inv_item.Extra)
            end)
            if ok and reader and reader:read(8) == 1 then
                info.remaining_charges = reader:read(8)
                if info.max_charges == 255 then
                    info.remaining_charges = 255
                end
            end
        end

        return info
    end

    local function get_equip_jobs_text(item)
        if not item then
            return ''
        end

        local mask = nil
        local mask_fields = { 'Jobs', 'JobMask', 'EquipJobs', 'JobsMask' }
        for _, field_name in ipairs(mask_fields) do
            local n = read_number_field(item, field_name)
            if n then
                mask = n
                break
            end
        end

        if not mask then
            local probes = {
                function() return item.Jobs and item.Jobs[1] end,
                function() return item.Jobs and item.Jobs[0] end,
                function() return item.EquipJobs and item.EquipJobs[1] end,
                function() return item.EquipJobs and item.EquipJobs[0] end,
            }
            for _, probe in ipairs(probes) do
                local ok, val = pcall(probe)
                if ok then
                    local n = tonumber(val)
                    if n and n > 0 then
                        mask = n
                        break
                    end
                end
            end
        end

        if not mask then
            return ''
        end

        local jobs = {}
        for i = 1, 22 do
            local bitval = bit.lshift(1, i)
            if bit.band(mask, bitval) ~= 0 then
                local abbr = job_abbr[i]
                if abbr then
                    table.insert(jobs, abbr)
                end
            end
        end

        if #jobs == 0 then
            return ''
        end

        if #jobs == 22 then
            return 'All Jobs'
        end

        return table.concat(jobs, ' ')
    end

    local function normalize_description_text(value)
        if type(value) ~= 'string' then
            return ''
        end

        local text = value
        text = text:gsub('\r\n', '\n')
        text = text:gsub('\r', '\n')

        text = text:gsub('\239\191\189', '?')
        text = text:gsub('\239\188\133', '%%')
        local element_icon_names = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' }
        text = text:gsub('\239(.)', function(b)
            local b_byte = b:byte(1)
            if b_byte >= 31 and b_byte <= 38 then
                return element_icon_names[b_byte - 30] .. ' '
            end
            return ''
        end)

        text = text:gsub('\30.', '')
        text = text:gsub('\31.', '')
        text = text:gsub('[%z\1-\8\11\12\14-\31]', ' ')
        text = text:gsub('\194\160', ' ')

        text = text:gsub('[ \t]+', ' ')
        text = text:gsub(' *\n *', '\n')

        return trim_text(text)
    end

    local function fix_known_element_placeholders(text)
        if type(text) ~= 'string' or text == '' then
            return text
        end
        local element_order = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' }
        local idx = 1
        text = text:gsub('[%?％]%s*([%+%-]?%d+)(%%?)', function(amount, pct)
            if idx > #element_order then return '?' .. amount .. (pct or '') end
            local n = tonumber(amount)
            if not n then return '?' .. amount .. (pct or '') end
            local elem = element_order[idx]
            idx = idx + 1
            local sign = (n >= 0) and '+' or ''
            return ('%s %s%d%s'):format(elem, sign, n, pct or '')
        end)
        return text
    end

    local function get_item_description_text(item, item_id)
        local resources = AshitaCore:GetResourceManager()
        if resources and item_id and item_id > 0 then
            local ok_string, value = pcall(function()
                return resources:GetString('items.descriptions', item_id)
            end)
            if ok_string and type(value) == 'string' then
                local cleaned = normalize_description_text(value)
                cleaned = fix_known_element_placeholders(cleaned)
                if cleaned ~= '' and not cleaned:find('userdata', 1, true) then
                    return cleaned
                end
            end
        end

        if not item then
            return ''
        end

        local candidates = {
            function() return item.Description and item.Description[1] end,
            function() return item.Description and item.Description[0] end,
            function() return item.Description and item.Description[2] end,
            function() return item.Description and item.Description:get() end,
            function() return item.Description and tostring(item.Description) end,
        }

        for _, getter in ipairs(candidates) do
            local ok, val = pcall(getter)
            if ok and type(val) == 'string' then
                local cleaned = normalize_description_text(val)
                cleaned = fix_known_element_placeholders(cleaned)
                if cleaned ~= '' and not cleaned:find('userdata', 1, true) then
                    return cleaned
                end
            end
        end

        return ''
    end

    local function render_desc_with_elements(text)
        local gray = {0.88, 0.88, 0.88, 1.0}
        local lines = {}
        local s = 1
        while true do
            local nl = text:find('\n', s, true)
            if nl then
                table.insert(lines, text:sub(s, nl - 1))
                s = nl + 1
            else
                table.insert(lines, text:sub(s))
                break
            end
        end

        for _, line in ipairs(lines) do
            if line == '' then
                imgui.Spacing()
            else
                local tokens = {}
                local pos = 1
                while pos <= #line do
                    local best_s, best_e, best_elem = nil, nil, nil
                    for _, elem in ipairs(element_list_ordered) do
                        local es, ee = line:find(elem, pos, true)
                        if es and (not best_s or es < best_s) then
                            best_s, best_e, best_elem = es, ee, elem
                        end
                    end
                    if best_s then
                        if best_s > pos then
                            table.insert(tokens, {kind = 'text', value = line:sub(pos, best_s - 1)})
                        end
                        table.insert(tokens, {kind = 'elem', value = best_elem})
                        pos = best_e + 1
                    else
                        table.insert(tokens, {kind = 'text', value = line:sub(pos)})
                        break
                    end
                end
                for ti, token in ipairs(tokens) do
                    if ti > 1 then imgui.SameLine(0, 0) end
                    if token.kind == 'elem' then
                        imgui.TextColored(element_colors[token.value], token.value)
                    else
                        imgui.TextColored(gray, (token.value:gsub('%%', '%%%%')))
                    end
                end
            end
        end
    end

    function M.render_item_detail_tooltip(slot)
        local item = M.get_item_resource(slot.id)
        local item_name = M.get_item_name(slot.id)
        local item_type = M.get_item_type(slot.id)
        local enchant_info = get_enchantment_info(slot, item, item)

        imgui.BeginTooltip()
        imgui.TextColored({ 1.0, 0.9, 0.55, 1.0 }, item_name)

        if item_type == 7 then
            local desc = get_item_description_text(item, slot.id)
            if desc ~= '' then
                imgui.Separator()
                render_desc_with_elements(desc)
            end
        elseif item_type == 4 or item_type == 5 then
            local dmg = item and read_number_field(item, 'Damage') or nil
            local def = item and read_number_field(item, 'Defense') or nil
            local delay = item and read_number_field(item, 'Delay') or nil
            local level = item and read_number_field(item, 'Level') or nil
            local jobs = get_equip_jobs_text(item)

            local has_stat = false
            if dmg then
                imgui.Text(('DMG: %d'):format(dmg))
                has_stat = true
            end
            if def then
                imgui.Text(('DEF: %d'):format(def))
                has_stat = true
            end
            if delay then
                imgui.Text(('Delay: %d'):format(delay))
                has_stat = true
            end
            if level then
                imgui.Text(('Lv: %d'):format(level))
                has_stat = true
            end
            if jobs ~= '' then
                imgui.TextWrapped(('Jobs: %s'):format(jobs))
                has_stat = true
            end
            if enchant_info then
                if enchant_info.max_charges > 0 and enchant_info.max_charges ~= 255 then
                    local remaining = tonumber(enchant_info.remaining_charges)
                    if remaining ~= nil then
                        imgui.Text(('Uses: %d/%d'):format(remaining, enchant_info.max_charges))
                    else
                        imgui.Text(('Uses: %d'):format(enchant_info.max_charges))
                    end
                    has_stat = true
                end
                if enchant_info.equip_delay > 0 then
                    imgui.Text(('Equip Delay: %s'):format(format_duration(enchant_info.equip_delay)))
                    has_stat = true
                end
                if enchant_info.reuse_delay > 0 then
                    imgui.Text(('Reuse Delay: %s'):format(format_duration(enchant_info.reuse_delay)))
                    has_stat = true
                end
            end

            local desc = get_item_description_text(item, slot.id)
            if desc ~= '' then
                imgui.Separator()
                render_desc_with_elements(desc)
            elseif not has_stat then
                imgui.TextColored({ 0.72, 0.72, 0.72, 1.0 }, 'No additional stats found.')
            end
        else
            local desc = get_item_description_text(item, slot.id)
            if desc ~= '' then
                imgui.Separator()
                render_desc_with_elements(desc)
            end
        end

        imgui.EndTooltip()
    end

    function M.get_slot_border_color(slot)
        if not slot.id or slot.id <= 0 then
            return { 0.28, 0.28, 0.28, 0.80 }
        end

        local item_type = M.get_item_type(slot.id)
        if item_type == 4 or item_type == 5 then
            return { 0.35, 0.63, 0.95, 1.0 }
        end
        if item_type == 7 then
            return { 0.58, 0.86, 0.50, 1.0 }
        end

        return { 0.72, 0.60, 0.35, 1.0 }
    end

    return M
end

return {
    create = create_item_logic,
}
