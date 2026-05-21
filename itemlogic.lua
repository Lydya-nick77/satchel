local breader = require('bitreader')
local time = nil
do
    local ok_time, time_lib = pcall(require, 'ffxi.time')
    if ok_time then
        time = time_lib
    end
end

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

    local equip_slot_priority = {
        { mask = weapon_slot_masks.main, name = 'main' },
        { mask = weapon_slot_masks.sub, name = 'sub' },
        { mask = weapon_slot_masks.range, name = 'range' },
        { mask = weapon_slot_masks.ammo, name = 'ammo' },
        { mask = armor_slot_masks.head, name = 'head' },
        { mask = armor_slot_masks.body, name = 'body' },
        { mask = armor_slot_masks.hands, name = 'hands' },
        { mask = armor_slot_masks.legs, name = 'legs' },
        { mask = armor_slot_masks.feet, name = 'feet' },
        { mask = armor_slot_masks.neck, name = 'neck' },
        { mask = armor_slot_masks.waist, name = 'waist' },
        { mask = 0x0800, name = 'ear1' },
        { mask = 0x1000, name = 'ear2' },
        { mask = 0x2000, name = 'ring1' },
        { mask = 0x4000, name = 'ring2' },
        { mask = armor_slot_masks.back, name = 'back' },
    }

    local function is_wardrobe_container(container_id)
        return container_id == 8
            or container_id == 10
            or container_id == 11
            or container_id == 12
            or container_id == 13
            or container_id == 14
            or container_id == 15
            or container_id == 16
    end

    local M = {}

    local function trim_text(value)
        if type(value) ~= 'string' then
            return ''
        end
        return value:match('^%s*(.-)%s*$') or ''
    end

    local function escape_command_text(value)
        return trim_text(value):gsub('"', '\\"')
    end

    local function get_primary_equip_slot_name(item)
        if not item then
            return nil
        end

        local slots = tonumber(item.Slots) or 0
        if slots <= 0 then
            return nil
        end

        for _, entry in ipairs(equip_slot_priority) do
            if bit.band(slots, entry.mask) ~= 0 then
                return entry.name
            end
        end

        return nil
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

    local function format_enchant_status(enchant_info)
        if not enchant_info then
            return nil
        end

        local remaining = tonumber(enchant_info.remaining_charges)
        local max_charges = tonumber(enchant_info.max_charges) or 0
        local equip_delay = tonumber(enchant_info.equip_delay) or 0
        local reuse_delay = tonumber(enchant_info.reuse_delay) or 0

        local uses_text = nil
        if max_charges > 0 and max_charges ~= 255 then
            if remaining ~= nil then
                uses_text = ('%d/%d'):format(remaining, max_charges)
            else
                uses_text = ('%d/%d'):format(max_charges, max_charges)
            end
        end

        if not uses_text and equip_delay <= 0 and reuse_delay <= 0 then
            return nil
        end

        local current_timer_text = format_duration(tonumber(enchant_info.use_delay) or 0)
        local reuse_text = format_duration(reuse_delay)
        local equip_text = format_duration(equip_delay)

        return ('<%s %s/[ %s, %s]>'):format(uses_text or '--/--', current_timer_text, reuse_text, equip_text)
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

    local function is_slot_in_bazaar(slot)
        if not slot or slot.container_id ~= 0 or not slot.id or slot.id <= 0 then
            return false
        end

        local inv_item = get_inventory_item(slot)
        if not inv_item then
            return false
        end

        return (tonumber(inv_item.Price) or 0) > 0
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
            use_delay = 0,
        }

        local inv_item = get_inventory_item(slot)
        if inv_item and inv_item.Extra then
            local ok, reader = pcall(function()
                return breader:new(T{}, inv_item.Extra)
            end)
            if ok and reader and reader:read(8) == 1 then
                info.remaining_charges = reader:read(8)
                local _flags = reader:read(16)
                local time_value1 = reader:read(32)
                local time_value2 = reader:read(32)

                if time and time.game_time_diff then
                    local use_delay = tonumber(time.game_time_diff(time_value1)) or 0
                    local equip_delay_current = tonumber(time.game_time_diff(time_value2)) or 0
                    local is_equipped = (tonumber(inv_item.Flags) == 5)

                    -- Only force cast-delay minimum when item is not equipped.
                    if (not is_equipped) and equip_delay_current < info.equip_delay then
                        equip_delay_current = info.equip_delay
                    end
                    if use_delay < equip_delay_current then
                        use_delay = equip_delay_current
                    end

                    if info.max_charges ~= 255 and info.remaining_charges == 0 then
                        use_delay = 0
                    end

                    info.use_delay = math.max(0, use_delay)
                end

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

    local function get_item_races_text(item)
        if not item then
            return ''
        end

        local mask = read_number_field(item, 'Races')
        if not mask then
            return ''
        end

        local race_masks = {
            hume_m = 0x0002,
            hume_f = 0x0004,
            elvaan_m = 0x0008,
            elvaan_f = 0x0010,
            tarutaru_m = 0x0020,
            tarutaru_f = 0x0040,
            hume = bit.bor(0x0002, 0x0004),
            elvaan = bit.bor(0x0008, 0x0010),
            tarutaru = bit.bor(0x0020, 0x0040),
            mithra = 0x0080,
            galka = 0x0100,
            male = 0x012A,
            female = 0x00D4,
            all = 0x01FE,
        }

        local male_symbol = 'M'
        local female_symbol = 'F'

        if bit.band(mask, race_masks.all) == race_masks.all then
            return 'All Races'
        end

        if bit.band(mask, race_masks.male) == race_masks.male and bit.band(mask, race_masks.female) == 0 then
            return ('All Races %s'):format(male_symbol)
        end

        if bit.band(mask, race_masks.female) == race_masks.female and bit.band(mask, race_masks.male) == 0 then
            return ('All Races %s'):format(female_symbol)
        end

        local names = {}

        local function append_race_with_gender(base_name, male_bit, female_bit)
            local has_m = bit.band(mask, male_bit) ~= 0
            local has_f = bit.band(mask, female_bit) ~= 0
            if has_m and has_f then
                table.insert(names, base_name)
            elseif has_m then
                table.insert(names, ('%s %s'):format(base_name, male_symbol))
            elseif has_f then
                table.insert(names, ('%s %s'):format(base_name, female_symbol))
            end
        end

        append_race_with_gender('Hume', race_masks.hume_m, race_masks.hume_f)
        append_race_with_gender('Elvaan', race_masks.elvaan_m, race_masks.elvaan_f)
        append_race_with_gender('Tarutaru', race_masks.tarutaru_m, race_masks.tarutaru_f)
        if bit.band(mask, race_masks.mithra) ~= 0 then table.insert(names, 'Mithra') end
        if bit.band(mask, race_masks.galka) ~= 0 then table.insert(names, 'Galka') end

        return table.concat(names, ' ')
    end

    local function get_item_flags_text(item)
        if not item then
            return ''
        end

        local ok, raw = pcall(function() return item.Flags end)
        local flags_val = (ok and tonumber(raw)) or 0
        local flags = {}

        if bit.band(flags_val, 0x8000) ~= 0 then table.insert(flags, 'RARE') end
        if bit.band(flags_val, 0x4000) ~= 0 then table.insert(flags, 'EX') end

        return table.concat(flags, ' ')
    end

    local function get_weapon_type_text(item)
        local skill = item and read_number_field(item, 'Skill') or nil
        if not skill then
            return 'Weapon'
        end

        local by_skill = {
            [1] = 'Hand-to-Hand',
            [2] = 'Dagger',
            [3] = 'Sword',
            [4] = 'Great Sword',
            [5] = 'Axe',
            [6] = 'Great Axe',
            [7] = 'Scythe',
            [8] = 'Polearm',
            [9] = 'Katana',
            [10] = 'Great Katana',
            [11] = 'Club',
            [12] = 'Staff',
            [25] = 'Archery',
            [26] = 'Marksmanship',
            [27] = 'Throwing',
        }

        return by_skill[skill] or 'Weapon'
    end

    local function get_armor_type_text(item)
        local slot = get_primary_equip_slot_name(item)
        if not slot then
            return 'Armor'
        end

        local by_slot = {
            head = 'Head',
            body = 'Body',
            hands = 'Hands',
            legs = 'Legs',
            feet = 'Feet',
            neck = 'Neck',
            waist = 'Waist',
            ear1 = 'Earring',
            ear2 = 'Earring',
            ring1 = 'Ring',
            ring2 = 'Ring',
            back = 'Back',
        }

        return by_slot[slot] or 'Armor'
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
        local is_bazaar_listed = is_slot_in_bazaar(slot)

        imgui.BeginTooltip()
        imgui.TextColored({ 1.0, 0.9, 0.55, 1.0 }, item_name)
        
        local flags_text = get_item_flags_text(item)
        if flags_text ~= '' then
            imgui.SameLine(0, 20)
            imgui.TextColored({ 1.0, 0.2, 0.2, 1.0 }, flags_text)
        end
        
        if is_bazaar_listed then
            imgui.TextColored({ 0.95, 0.32, 0.32, 1.0 }, 'Listed in Bazaar (cannot use/equip)')
        end

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
            local races = get_item_races_text(item)
            local family = (item_type == 4) and get_weapon_type_text(item) or get_armor_type_text(item)

            local has_stat = false

            if races ~= '' then
                imgui.Text(('(%s) %s'):format(family, races))
            else
                imgui.Text(('(%s)'):format(family))
            end

            if item_type == 4 then
                local combat_parts = {}
                if dmg then table.insert(combat_parts, ('DMG:%d'):format(dmg)) end
                if delay then table.insert(combat_parts, ('Delay:%d'):format(delay)) end
                if #combat_parts > 0 then
                    imgui.Text(table.concat(combat_parts, '  '))
                    has_stat = true
                end
            else
                if def then
                    imgui.Text(('DEF:%d'):format(def))
                    has_stat = true
                end
                if delay then
                    imgui.Text(('Delay:%d'):format(delay))
                    has_stat = true
                end
            end

            local desc = get_item_description_text(item, slot.id)
            if desc ~= '' then
                if item_type == 4 then
                    -- Strip the DMG/Delay line from weapon descriptions since those are already shown above
                    local filtered_lines = {}
                    for line in (desc .. '\n'):gmatch('([^\n]*)\n') do
                        if not line:match('DMG:%d') and not line:match('Delay:%d') then
                            table.insert(filtered_lines, line)
                        end
                    end
                    -- Remove leading/trailing empty lines
                    while #filtered_lines > 0 and filtered_lines[1] == '' do table.remove(filtered_lines, 1) end
                    while #filtered_lines > 0 and filtered_lines[#filtered_lines] == '' do table.remove(filtered_lines) end
                    desc = table.concat(filtered_lines, '\n')
                end
                if desc ~= '' then
                    render_desc_with_elements(desc)
                    has_stat = true
                end
            end

            local level_jobs_parts = {}
            if level then table.insert(level_jobs_parts, ('Lv.%d'):format(level)) end
            if jobs ~= '' then table.insert(level_jobs_parts, jobs) end
            if #level_jobs_parts > 0 then
                imgui.TextWrapped(table.concat(level_jobs_parts, '  '))
                has_stat = true
            end

            local enchant_status = format_enchant_status(enchant_info)
            if enchant_status then
                imgui.Text(enchant_status)
                has_stat = true
            end

            if not has_stat then
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

        if is_slot_in_bazaar(slot) then
            return { 0.92, 0.22, 0.22, 1.0 }
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

    function M.build_right_click_command(slot)
        if not slot or slot.container_id == nil or not slot.id or slot.id <= 0 then
            return nil
        end

        if is_slot_in_bazaar(slot) then
            return nil
        end

        local item_type = M.get_item_type(slot.id)
        local item_resource = M.get_item_resource(slot.id)
        local inv_item = get_inventory_item(slot)
        local item_name = escape_command_text(M.get_item_name(slot.id))
        if item_name == '' then
            return nil
        end

        if item_type == 7 then
            if slot.container_id == 0 then
                return ('/item "%s" <me>'):format(item_name)
            end
            return nil
        end

        if item_type == 4 or item_type == 5 then
            if slot.container_id == 0 or is_wardrobe_container(slot.container_id) then
                local enchant_info = get_enchantment_info(slot, item_resource, item_resource)
                local is_equipped = inv_item and (tonumber(inv_item.Flags) == 5)
                local is_ready_to_use = enchant_info and (tonumber(enchant_info.use_delay) or 0) <= 0

                if is_equipped and is_ready_to_use then
                    return ('/item "%s" <me>'):format(item_name)
                end

                local equip_slot = get_primary_equip_slot_name(item_resource)
                if equip_slot then
                    return ('/equip %s "%s"'):format(equip_slot, item_name)
                end
            end
        end

        return nil
    end

    return M
end

return {
    create = create_item_logic,
}
