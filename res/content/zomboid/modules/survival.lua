local clock = require "zomboid:clock"
local inv = require "zomboid:inv"

local survival = {
    states = {},
    INFECTION_HOURS = 30.0,
    WATER_SHUTOFF_DAY = 5,
    POWER_SHUTOFF_DAY = 4,
}

local HUNGER_RATE = 4.0
local THIRST_RATE = 6.0
local ENERGY_RATE = 3.2
local STARVE_DAMAGE = 6.0
local DEHYDRATE_DAMAGE = 10.0
local REGEN = 3.0
local SPRINT_STAMINA = 9.0
local STAMINA_REGEN = 7.0

local WOUNDS = {
    scratch = {title = "царапина", bleed = 0.08, stops = 1.0, heals = 6.0, infection = 0.07},
    laceration = {title = "рваная рана", bleed = 0.18, stops = 3.0, heals = 12.0, infection = 0.25},
    bite = {title = "укус", bleed = 0.3, stops = nil, heals = 24.0, infection = 1.0},
}
survival.WOUNDS = WOUNDS

local CAUSES = {
    zombies = "Растерзан зомби",
    bleeding = "Истёк кровью",
    starvation = "Умер от голода",
    dehydration = "Умер от жажды",
    infection = "Обратился в зомби",
    sickness = "Умер от болезни",
}
survival.CAUSES = CAUSES

local function new_state()
    return {
        health = 100, hunger = 85, thirst = 85, energy = 90, stamina = 100,
        sickness = 0, pain = 0, wounds = {}, infection = nil, wound_infection = false,
        kills = 0, born = clock.hours, dead = false, messages = {}, hurt = 0,
        sleeping = false, sprinting = false, crouching = false,
    }
end

function survival.get(pid)
    local state = survival.states[pid]
    if state == nil then
        state = new_state()
        state.fresh = true
        survival.states[pid] = state
    end
    return state
end

function survival.notify(pid, text, color)
    local state = survival.get(pid)
    table.insert(state.messages, {text = text, color = color or "#e8e0d0", time = time.uptime()})
    while #state.messages > 6 do
        table.remove(state.messages, 1)
    end
    events.emit("zomboid:message", pid, text)
end

local function clamp(v)
    return math.max(0, math.min(100, v))
end

function survival.max_health(state)
    if state.infection then
        return 100 - 80 * math.min(1, state.infection / survival.INFECTION_HOURS)
    end
    return 100
end

function survival.bleeding_count(state)
    local n = 0
    for _, w in ipairs(state.wounds) do
        if w.bleeding then n = n + 1 end
    end
    return n
end

function survival.days_alive(state)
    return (clock.hours - state.born) / 24
end

function survival.add_wound(pid, kind)
    local state = survival.get(pid)
    local def = WOUNDS[kind]
    table.insert(state.wounds, {kind = kind, bleeding = true, bandaged = false, dirty = false, time = clock.hours})
    if state.infection == nil and math.random() < def.infection then
        state.infection = 0.0
    end
    survival.notify(pid, "Получена рана: " .. def.title, "#ff7060")
end

function survival.damage(pid, amount, cause)
    local state = survival.get(pid)
    if state.dead then
        return
    end
    state.health = state.health - amount
    state.hurt = time.uptime()
    state.last_cause = cause or state.last_cause
    if state.health <= 0 then
        survival.kill(pid, cause or "zombies")
    end
end

-- Zombie attack against the player.
function survival.zombie_hit(pid, night)
    local state = survival.get(pid)
    if state.dead then
        return
    end
    local amount = math.random(7, 13) * (night and 1.3 or 1.0)
    local r = math.random()
    local bite_chance = night and 0.28 or 0.18
    if r < bite_chance then
        survival.add_wound(pid, "bite")
    elseif r < 0.55 then
        survival.add_wound(pid, "laceration")
    elseif r < 0.85 then
        survival.add_wound(pid, "scratch")
    end
    if state.sleeping then
        state.sleeping = false
    end
    survival.damage(pid, amount, "zombies")
    if vc.is_client() then
        local x, y, z = player.get_pos(pid)
        audio.play_sound("player/hurt", x, y, z, 1.0, 0.9 + math.random() * 0.2)
    end
end

-- Advances survival stats by game hours dh and real seconds dt.
function survival.update(pid, dh, dt)
    local state = survival.get(pid)
    if state.dead then
        return
    end
    local mul = state.sprinting and 1.6 or 1.0
    state.hunger = clamp(state.hunger - HUNGER_RATE * dh * mul)
    state.thirst = clamp(state.thirst - THIRST_RATE * dh * mul)
    if state.sleeping then
        state.energy = clamp(state.energy + 12.5 * dh)
    else
        state.energy = clamp(state.energy - ENERGY_RATE * dh * mul)
    end
    state.pain = math.max(0, state.pain - dh)

    if state.sprinting then
        state.stamina = clamp(state.stamina - SPRINT_STAMINA * dt)
    else
        local regen = STAMINA_REGEN * (state.energy < 20 and 0.4 or 1.0)
        state.stamina = clamp(state.stamina + regen * dt)
    end

    local damage = {}
    local function hurt(cause, amount)
        if amount > 0 then
            damage[cause] = (damage[cause] or 0) + amount
        end
    end
    if state.hunger <= 0 then hurt("starvation", STARVE_DAMAGE * dh) end
    if state.thirst <= 0 then hurt("dehydration", DEHYDRATE_DAMAGE * dh) end

    local bleeding = 0
    for i = #state.wounds, 1, -1 do
        local w = state.wounds[i]
        local def = WOUNDS[w.kind]
        local age = clock.hours - w.time
        if w.bleeding then
            if def.stops and age > def.stops then
                w.bleeding = false
            else
                bleeding = bleeding + def.bleed
            end
        end
        if w.bandaged and age > def.heals then
            table.remove(state.wounds, i)
            survival.notify(pid, "Рана зажила: " .. def.title, "#90e090")
        elseif not w.bandaged and not w.bleeding and age > def.heals * 1.5 then
            table.remove(state.wounds, i)
        end
    end
    hurt("bleeding", bleeding * dt)

    if state.wound_infection then
        hurt("sickness", 1.5 * dh)
        state.sickness = clamp(state.sickness + 2 * dh)
    end
    if state.sickness > 40 then
        hurt("sickness", 2.0 * dh)
    end
    if state.sickness > 70 and math.random() < 0.15 * dh then
        state.hunger = clamp(state.hunger - 10)
        state.thirst = clamp(state.thirst - 12)
        survival.notify(pid, "Вас стошнило", "#c0d060")
    end
    state.sickness = clamp(state.sickness - 6 * dh)

    if state.infection then
        local before = state.infection
        state.infection = state.infection + dh
        local stage = survival.INFECTION_HOURS
        if before < stage * 0.25 and state.infection >= stage * 0.25 then
            survival.notify(pid, "Вас знобит. Лихорадка...", "#ff9050")
        elseif before < stage * 0.7 and state.infection >= stage * 0.7 then
            survival.notify(pid, "Кожа посерела. Инфекция берёт своё", "#ff5040")
        end
        if state.infection >= stage then
            survival.kill(pid, "infection")
            return
        end
    end

    local total, worst, worst_amount = 0, nil, 0
    for cause, amount in pairs(damage) do
        total = total + amount
        if amount > worst_amount then
            worst, worst_amount = cause, amount
        end
    end
    if total > 0 then
        state.health = state.health - total
        state.last_cause = worst
    elseif state.hunger > 35 and state.thirst > 35 and state.sickness < 30 then
        state.health = state.health + REGEN * dh * (state.sleeping and 3 or 1)
    end
    state.health = math.min(state.health, survival.max_health(state))
    if state.health <= 0 then
        survival.kill(pid, state.last_cause or "bleeding")
    end
end

-- Movement modifiers derived from the state.
function survival.speed_factor(state)
    local f = 1.0
    if state.energy < 20 then f = f * 0.8 end
    if state.health < 30 and state.pain <= 0 then f = f * 0.8 end
    if state.hunger <= 0 or state.thirst <= 0 then f = f * 0.85 end
    return f
end

function survival.can_sprint(state)
    return state.stamina > 12 and state.energy > 5
end

function survival.eat(pid, hunger, thirst, sickness)
    local state = survival.get(pid)
    state.hunger = clamp(state.hunger + (hunger or 0))
    state.thirst = clamp(state.thirst + (thirst or 0))
    if sickness and sickness > 0 then
        state.sickness = clamp(state.sickness + sickness)
    end
    if vc.is_client() then
        local x, y, z = player.get_pos(pid)
        audio.play_sound("player/eat", x, y, z, 0.8, 0.9 + math.random() * 0.2)
    end
end

-- Medical treatment: returns true if the item was used.
function survival.treat(pid, kind)
    local state = survival.get(pid)
    if kind == "bandage" or kind == "rag" then
        for _, w in ipairs(state.wounds) do
            if not w.bandaged then
                w.bandaged = true
                w.bleeding = false
                if kind == "rag" and not w.disinfected and math.random() < 0.3 then
                    state.wound_infection = true
                end
                survival.notify(pid, "Вы перевязали рану: " .. WOUNDS[w.kind].title, "#90e090")
                return true
            end
        end
        survival.notify(pid, "Нет ран, которые нужно перевязать")
        return false
    elseif kind == "disinfectant" then
        local used = false
        for _, w in ipairs(state.wounds) do
            if not w.disinfected then
                w.disinfected = true
                used = true
            end
        end
        if state.wound_infection then
            state.wound_infection = false
            used = true
        end
        survival.notify(pid, used and "Раны обработаны" or "Нечего обрабатывать", used and "#90e090" or nil)
        return used
    elseif kind == "painkillers" then
        state.pain = 6
        survival.notify(pid, "Боль притупилась", "#90e090")
        return true
    elseif kind == "antibiotics" then
        state.wound_infection = false
        state.sickness = clamp(state.sickness - 50)
        survival.notify(pid, state.infection and "Антибиотики не помогают от этой заразы..." or "Вам стало лучше",
            state.infection and "#ff9050" or "#90e090")
        return true
    end
    return false
end

-- Sleep for up to 8 hours. Returns slept hours.
function survival.sleep(pid)
    local state = survival.get(pid)
    if state.energy > 70 then
        survival.notify(pid, "Вы не хотите спать")
        return 0
    end
    if survival.bleeding_count(state) > 0 then
        survival.notify(pid, "Сначала остановите кровотечение", "#ff7060")
        return 0
    end
    local hours = math.min(8, (100 - state.energy) / 12.5)
    state.sleeping = true
    local step = 0.25
    local slept = 0
    while slept < hours and state.sleeping and not state.dead do
        survival.update(pid, step, step * 60)
        slept = slept + step
    end
    state.sleeping = false
    state.stamina = 100
    clock.skip(slept)
    survival.notify(pid, string.format("Вы проспали %.1f ч. Сейчас %s", slept, clock.format()))
    return slept
end

function survival.kill(pid, cause)
    local state = survival.get(pid)
    if state.dead then
        return
    end
    state.health = 0
    state.dead = true
    state.sleeping = false
    state.death = {
        cause = cause,
        hours = clock.hours - state.born,
        kills = state.kills,
        day = clock.day(),
        infected = state.infection ~= nil,
    }
    local x, y, z = player.get_pos(pid)
    local invid = player.get_inventory(pid)
    local items = {}
    for slot = 0, inventory.size(invid) - 1 do
        local id, count = inventory.get(invid, slot)
        if id ~= 0 then
            table.insert(items, {item.name(id), count, inventory.get_all_data(invid, slot)})
        end
    end
    inv.clear(invid)
    events.emit("zomboid:player_died", pid, {x, y, z}, items, state.death.infected)
end

local STARTER_KIT = {
    {"zomboid:water_bottle", 1},
    {"zomboid:chips", 1},
    {"zomboid:rag", 2},
    {"zomboid:matches", 1},
}

function survival.new_character(pid, pos)
    local state = new_state()
    survival.states[pid] = state
    local invid = player.get_inventory(pid)
    inv.clear(invid)
    for _, entry in ipairs(STARTER_KIT) do
        inventory.add(invid, item.index(entry[1]), entry[2])
    end
    if pos then
        player.set_pos(pid, pos[1], pos[2], pos[3])
        player.set_vel(pid, 0, 0, 0)
        player.set_spawnpoint(pid, pos[1], pos[2], pos[3])
    end
    survival.notify(pid, "День " .. clock.day() .. ", " .. clock.format() .. ". Вы ещё живы.", "#ffe0a0")
    events.emit("zomboid:new_character", pid)
    return state
end

function survival.serialize()
    local players = {}
    for pid, state in pairs(survival.states) do
        local copy = table.copy(state)
        copy.messages = nil
        copy.fresh = nil
        copy.hurt = nil
        copy.sprinting = nil
        players[tostring(pid)] = copy
    end
    return players
end

function survival.deserialize(players)
    survival.states = {}
    for key, state in pairs(players or {}) do
        state.messages = {}
        state.hurt = 0
        state.wounds = state.wounds or {}
        survival.states[tonumber(key)] = state
    end
end

return survival
