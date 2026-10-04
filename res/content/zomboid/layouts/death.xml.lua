local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local town = require "zomboid:town"

local closing = false

function on_open()
    closing = false
    local pid = hud.get_player()
    local state = survival.get(pid)
    local death = state.death or {}
    document.cause.text = survival.CAUSES[death.cause] or "Причина неизвестна"
    local hours = death.hours or 0
    local lines = {
        string.format("Прожито: [#ffe0a0]%s", clock.duration(hours)),
        string.format("Дней выживания: [#ffe0a0]%d", math.floor(hours / 24)),
        string.format("Убито зомби: [#ffe0a0]%d", death.kills or 0),
        string.format("Погиб на %d-й день эпидемии", death.day or clock.day()),
    }
    if death.infected then
        table.insert(lines, "[#ff6040]Тело поднялось и теперь бродит среди мертвецов")
    end
    document.stats.text = table.concat(lines, "\n")
end

function new_character()
    local pid = hud.get_player()
    survival.new_character(pid, town.spawn_point(math.random(2, 12)))
    closing = true
    hud.close("zomboid:death")
end

function app_quit()
    closing = true
    app.close_world(true)
end

function on_close()
    if closing then
        return
    end
    local pid = hud.get_player()
    if survival.get(pid).dead then
        time.post_runnable(function()
            if not hud.is_inventory_open() then
                hud.show_overlay("zomboid:death", false)
            end
        end)
    end
end
