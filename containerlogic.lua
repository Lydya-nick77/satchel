local containerlogic = {}

containerlogic.container_names = {
    [0] = 'Inventory',
    [1] = 'Safe',
    [2] = 'Storage',
    [3] = 'Temporary',
    [4] = 'Locker',
    [5] = 'Satchel',
    [6] = 'Sack',
    [7] = 'Case',
    [8] = 'Wardrobe1',
    [9] = 'Safe2',
    [10] = 'Wardrobe2',
    [11] = 'Wardrobe3',
    [12] = 'Wardrobe4',
    [13] = 'Wardrobe5',
    [14] = 'Wardrobe6',
    [15] = 'Wardrobe7',
    [16] = 'Wardrobe8',
}

containerlogic.tab_order = { 0, 1, 9, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16 }

local canonical_containers = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }

function containerlogic.normalize_include_containers(value)
    local existing = {}
    if type(value) == 'table' then
        for _, v in ipairs(value) do
            local id = tonumber(v)
            if id then
                existing[id] = true
            end
        end
    end

    local normalized = T{}
    for _, id in ipairs(canonical_containers) do
        if existing[id] or value == nil then
            normalized:append(id)
        end
    end

    if #normalized < #canonical_containers then
        normalized = T{}
        for _, id in ipairs(canonical_containers) do
            normalized:append(id)
        end
    end

    return normalized
end

function containerlogic.build_slot_data(satchel)
    local all_slots = T{}
    local slots_by_container = {}
    local stats = {
        all = { used = 0, total = 0 },
    }

    local inv = AshitaCore:GetMemoryManager():GetInventory()
    if not inv then
        return all_slots, slots_by_container, stats
    end

    for _, container_id in ipairs(satchel.settings.include_containers) do
        slots_by_container[container_id] = T{}
        local max_slots = inv:GetContainerCountMax(container_id) or 0
        local used_slots = tonumber(inv:GetContainerCount(container_id) or 0) or 0
        stats[container_id] = { used = used_slots, total = max_slots }
        stats.all.total = stats.all.total + max_slots
        stats.all.used = stats.all.used + used_slots

        for memory_slot_index = 1, max_slots do
            local entry = {
                container_id = container_id,
                slot_index = memory_slot_index - 1,
                id = 0,
                count = 0,
            }

            local ok, item = pcall(function()
                return inv:GetContainerItem(container_id, memory_slot_index)
            end)

            if ok and item and item.Id and item.Id > 0 and item.Id ~= 65535 then
                entry.id = tonumber(item.Id) or 0
                entry.count = tonumber(item.Count) or 1
            end

            if satchel.settings.show_empty_slots or entry.id > 0 then
                all_slots:append(entry)
                slots_by_container[container_id]:append(entry)
            end
        end
    end

    return all_slots, slots_by_container, stats
end

function containerlogic.format_tab_label(container_id)
    return containerlogic.container_names[container_id] or ('Bag ' .. tostring(container_id))
end

function containerlogic.is_tab_available(container_id, stats)
    local s = stats[container_id]
    if not s then
        return false
    end

    return (s.used or 0) > 0
end

return containerlogic
