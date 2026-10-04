local survival = require "zomboid:survival"
local skills = require "zomboid:skills"
local traits = require "zomboid:traits"
local character = require "zomboid:character"
local sandbox = require "zomboid:sandbox"

local function percent(v)
    return string.format("%+d%%", math.floor(v * 100 + (v >= 0 and 0.5 or -0.5)))
end

local function refresh()
    local pid = hud.get_player()
    local state = survival.get(pid)
    local prof = character.profession(state.profession or "unemployed")
    local names = {}
    for _, id in ipairs(state.traits or {}) do
        local def = traits.find(id)
        table.insert(names, (def.cost > 0 and "[#90e090]" or "[#ff9070]") .. def.title)
    end
    document.who.text = "Профессия: [#ffe0a0]" .. prof.title .. "[#ffffff]\nЧерты: "
        .. (#names > 0 and table.concat(names, "[#ffffff], ") or "[#909090]нет")

    local list = document.skills
    list:clear()
    for _, skill in ipairs(skills.LIST) do
        local level = skills.level(pid, skill)
        local mult = skills.xp_mult(pid, skill)
        local title = string.format("%s - уровень %d/%d", skills.TITLES[skill], level, skills.MAX_LEVEL)
        if mult ~= 1 then
            title = title .. string.format("   опыт x%.1f", mult)
        end
        list:add(string.format("<label color='#e8e0d0' size='436,18'>%s</label>", title))
        list:add(string.format(
            "<container size='430,8' color='#2a2a2acc'><container size='%d,8' color='#d0a040'/></container>",
            math.floor(430 * skills.progress(pid, skill))))
        local effects = {}
        for _, def in pairs(skills.EFFECTS) do
            if def.skill == skill then
                table.insert(effects, def.title .. " " .. percent(def.per_level * level))
            end
        end
        table.sort(effects)
        list:add(string.format(
            "<label color='#909090' multiline='true' text-wrap='true' size='436,18' margin='0,0,0,2'>%s</label>",
            table.concat(effects, "; ")))
    end

    local world_lines = {}
    for _, opt in ipairs(sandbox.OPTIONS) do
        for _, v in ipairs(opt.values) do
            if v[1] == sandbox.get(opt.key) then
                table.insert(world_lines, opt.title .. ": " .. v[2])
            end
        end
    end
    list:add(string.format(
        "<label color='#808080' multiline='true' size='436,150' margin='0,4,0,0'>%s</label>",
        table.concat(world_lines, "\n")))
end

local ticking = false

function on_open()
    refresh()
    if not ticking then
        ticking = true
        document.root:setInterval(1000, refresh)
    end
end
