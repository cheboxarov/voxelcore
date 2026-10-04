local character = require "zomboid:character"
local traits = require "zomboid:traits"
local skills = require "zomboid:skills"

local prof_id = "unemployed"
local chosen = {}

local function prof_info(prof)
    local lines = {prof.text}
    for _, skill in ipairs(skills.LIST) do
        if prof.skills[skill] then
            table.insert(lines, string.format("[#90e090]%s +%d", skills.TITLES[skill], prof.skills[skill]))
        end
    end
    for _, entry in ipairs(prof.items) do
        table.insert(lines, string.format("[#c0c0c0]%s x%d", item.caption(item.index(entry[1])), entry[2]))
    end
    if prof.points > 0 then
        table.insert(lines, string.format("[#ffe0a0]Очки на черты: +%d", prof.points))
    end
    return table.concat(lines, "\n")
end

local function refresh()
    local list = document.professions
    list:clear()
    for i, prof in ipairs(character.PROFESSIONS) do
        list:add(string.format(
            "<button onclick='pick(%d)' padding='5' text-align='left' size='250,28' color='%s'>%s</button>",
            i, prof.id == prof_id and "#4a6a3ae0" or "#202020c0", prof.title))
    end
    document.prof_info.text = prof_info(character.profession(prof_id))

    list = document.traits
    list:clear()
    for i, def in ipairs(traits.LIST) do
        local on = table.has(chosen, def.id)
        local color = on and (def.cost > 0 and "#3a6a3ae0" or "#7a3030e0") or "#202020c0"
        list:add(string.format(
            "<button onclick='toggle(%d)' padding='4' text-align='left' size='480,24' color='%s'>%s (%s%d)</button>",
            i, color, def.title, def.cost > 0 and "-" or "+", math.abs(def.cost)))
        list:add(string.format("<label color='#909090' size='480,16' margin='8,0,0,2'>%s</label>", def.text))
    end

    local points, err = character.balance(prof_id, chosen)
    if err then
        document.points.text = "[#ff7060]" .. err
    else
        document.points.text = "Свободные очки: [#ffe0a0]" .. points
    end
    document.start.enabled = err == nil
end

function pick(index)
    prof_id = character.PROFESSIONS[index].id
    refresh()
end

function toggle(index)
    local id = traits.LIST[index].id
    if table.has(chosen, id) then
        table.remove(chosen, table.index(chosen, id))
    else
        table.insert(chosen, id)
    end
    refresh()
end

function start()
    local ok, err = character.apply(hud.get_player(), prof_id, chosen)
    if not ok then
        document.points.text = "[#ff7060]" .. err
        return
    end
    hud.close("zomboid:character")
end

function on_open()
    prof_id = "unemployed"
    chosen = {}
    world.set_day_time_speed(0)
    refresh()
end
