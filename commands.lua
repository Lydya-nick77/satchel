local commands = {}

function commands.create(ctx)
    local addon = ctx.addon
    local chat = ctx.chat
    local settings = ctx.settings
    local satchel = ctx.satchel
    local default_settings = ctx.default_settings
    local normalize_include_containers = ctx.normalize_include_containers

    local M = {}

    local function print_help(is_error)
        if is_error then
            print(chat.header(addon.name):append(chat.error('Invalid command syntax.')))
        end

        print(chat.header(addon.name):append(chat.message('Commands:')))
        print(chat.header(addon.name):append(chat.message('/satchel - Open satchel window')))
        print(chat.header(addon.name):append(chat.message('/satchel config - Open configuration window')))
    end

    local function clamp_slot_size(v)
        return math.max(24, math.min(96, tonumber(v) or default_settings.slot_size))
    end

    function M.apply_settings(s)
        if s ~= nil then
            satchel.settings = s
        end

        satchel.item_sort_keys = {}

        satchel.settings.include_containers = normalize_include_containers(satchel.settings.include_containers)
        satchel.settings.columns = math.max(4, math.min(18, tonumber(satchel.settings.columns) or 10))
        satchel.settings.rows = math.max(4, math.min(16, tonumber(satchel.settings.rows) or 10))
        satchel.settings.slot_size = clamp_slot_size(satchel.settings.slot_size)

        satchel.visible[1] = satchel.settings.visible == true
        settings.save()
    end

    function M.handle_command(e)
        local args = e.command:args()
        if #args == 0 or args[1]:lower() ~= '/satchel' then
            return
        end

        e.blocked = true

        if #args == 1 then
            satchel.visible[1] = true
            satchel.settings.visible = satchel.visible[1]
            settings.save()
            return
        end

        local cmd = args[2] and args[2]:lower() or ''

        if cmd == 'config' then
            satchel.config_visible[1] = true
            return
        end

        print_help(true)
    end

    return M
end

return commands
