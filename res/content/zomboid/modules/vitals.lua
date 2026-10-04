local clock = require "zomboid:clock"
local gear = require "zomboid:gear"

local vitals = {
    rain = 0.0,
    temp_offset = 0.0,
    NORMAL_TEMP = 36.6,
    DRESSING_DIRTY_HOURS = 12,
}

local COMFORT_LOW = 16
local COMFORT_HIGH = 28
local SPLINT_HEAL_HOURS = 36
local FRACTURE_HEAL_HOURS = 120

local TEMP_STAGES = {
    {below = 33.5, stage = -3, text = "Вы замерзаете насмерть!", color = "#80b0ff"},
    {below = 34.5, stage = -2, text = "Переохлаждение. Нужно согреться", color = "#80b0ff"},
    {below = 35.5, stage = -1, text = "Вам холодно", color = "#a0c8ff"},
    {below = 37.5, stage = 0},
    {below = 38.5, stage = 1, text = "Вам жарко", color = "#ffc070"},
    {below = 39.5, stage = 2, text = "Перегрев. Снимите тёплые вещи", color = "#ff9050"},
    {below = math.huge, stage = 3, text = "Тепловой удар!", color = "#ff6040"},
}

local function clamp(v, lo, hi)
    return math.max(lo or 0, math.min(hi or 100, v))
end

function vitals.defaults(state)
    state.temp = state.temp or vitals.NORMAL_TEMP
    state.wet = state.wet or 0
    state.boredom = state.boredom or 0
    state.unhappiness = state.unhappiness or 0
    state.load = state.load or 0
    state.temp_stage = state.temp_stage or 0
    state.wear_acc = state.wear_acc or 0
end

function vitals.air(hour)
    return 17 + 9 * math.sin((hour - 9) / 24 * 2 * math.pi) + vitals.temp_offset - 4 * vitals.rain
end

function vitals.felt(state)
    local air = vitals.air(clock.hour())
    if state.indoors then
        air = air + (20 - air) * 0.6
    end
    if state.heat then
        air = air + 14
    end
    local felt = air + gear.warmth(state) * (1 - 0.6 * state.wet / 100) - 0.12 * state.wet
    if state.sprinting then
        felt = felt + 6
    end
    return felt
end

local function update_temperature(pid, state, dh, hurt)
    local felt = vitals.felt(state)
    if felt < COMFORT_LOW then
        state.temp = state.temp - (COMFORT_LOW - felt) * 0.06 * dh
    elseif felt > COMFORT_HIGH then
        state.temp = state.temp + (felt - COMFORT_HIGH) * 0.08 * dh
    elseif state.temp < vitals.NORMAL_TEMP then
        state.temp = math.min(vitals.NORMAL_TEMP, state.temp + 0.8 * dh)
    else
        state.temp = math.max(vitals.NORMAL_TEMP, state.temp - 0.8 * dh)
    end
    state.temp = clamp(state.temp, 32, 42)

    local stage
    for _, s in ipairs(TEMP_STAGES) do
        if state.temp < s.below then
            stage = s
            break
        end
    end
    if stage.stage ~= state.temp_stage then
        if math.abs(stage.stage) > math.abs(state.temp_stage) then
            require("zomboid:survival").notify(pid, stage.text, stage.color)
        end
        state.temp_stage = stage.stage
    end

    if stage.stage <= -1 then
        state.hunger = clamp(state.hunger - 2 * dh)
    elseif stage.stage >= 1 then
        state.thirst = clamp(state.thirst - 4 * dh)
    end
    if stage.stage == -2 then hurt("cold", 2 * dh) end
    if stage.stage == -3 then hurt("cold", 6 * dh) end
    if stage.stage == 2 then
        hurt("heat", 2 * dh)
        state.energy = clamp(state.energy - 3 * dh)
    end
    if stage.stage == 3 then hurt("heat", 6 * dh) end
end

local function update_wetness(state, dh)
    if state.in_water then
        state.wet = 100
    elseif not state.indoors and vitals.rain > 0 then
        state.wet = clamp(state.wet + vitals.rain * 80 * (1 - gear.waterproof(state)) * dh)
    else
        state.wet = clamp(state.wet - (state.heat and 60 or 12) * dh)
    end
end

local function update_mood(state, dh)
    if state.sleeping then
        state.boredom = clamp(state.boredom - 2 * dh)
    else
        state.boredom = clamp(state.boredom + (state.indoors and 3 or 1.5) * dh - (state.sprinting and 6 or 0) * dh)
    end
    local kills = state.kills or 0
    if kills > (state.mood_kills or 0) then
        state.boredom = clamp(state.boredom - 4 * (kills - (state.mood_kills or 0)))
    end
    state.mood_kills = kills

    local grief = math.max(0, state.boredom - 50) * 0.06 + gear.dirty_count(state) * 0.4
    if state.hunger < 20 or state.thirst < 20 then grief = grief + 1.0 end
    if state.fracture or state.wound_infection or state.temp_stage ~= 0 then grief = grief + 1.0 end
    if state.infection and state.infection > 7 then grief = grief + 2.0 end
    if grief <= 0 and state.boredom < 30 then grief = -0.5 end
    state.unhappiness = clamp(state.unhappiness + grief * dh)
end

local function update_fracture(pid, state)
    local f = state.fracture
    if f == nil then
        return
    end
    local healed = f.splinted and clock.hours - f.splinted > SPLINT_HEAL_HOURS
        or clock.hours - f.time > FRACTURE_HEAL_HOURS
    if healed then
        state.fracture = nil
        require("zomboid:survival").notify(pid, "Перелом сросся", "#90e090")
    end
end

local function update_load(state, dt)
    local over = state.load / gear.capacity(state) - 1
    if over > 0 and state.moving then
        state.stamina = clamp(state.stamina - over * 18 * dt)
    end
end

local function wear_clothes(state, dh)
    state.wear_acc = state.wear_acc + dh
    if state.wear_acc < 0.25 then
        return
    end
    local hours = state.wear_acc
    state.wear_acc = 0
    gear.soil_all(state, hours * (0.6 + (state.wet > 50 and 1.5 or 0)))
end

function vitals.update(pid, state, dh, dt, hurt)
    update_wetness(state, dh)
    update_temperature(pid, state, dh, hurt)
    update_mood(state, dh)
    update_fracture(pid, state)
    update_load(state, dt)
    wear_clothes(state, dh)
end

function vitals.speed_factor(state)
    local f = 1.0
    if state.fracture then
        f = (state.fracture.splinted and 0.75 or 0.55) + (state.pain > 0 and 0.15 or 0)
    end
    local over = state.load / gear.capacity(state) - 1
    if over > 0 then
        f = f * math.max(0.45, 1 - over * 0.8)
    end
    if math.abs(state.temp_stage) >= 2 then f = f * 0.85 end
    if state.unhappiness > 80 then f = f * 0.9 end
    return f
end

function vitals.can_sprint(state)
    return state.fracture == nil and state.load <= gear.capacity(state) * 1.5
end

function vitals.stamina_mul(state)
    local f = 1.0
    if state.temp_stage <= -1 then f = f * 0.7 end
    if state.unhappiness > 80 then
        f = f * 0.5
    elseif state.unhappiness > 50 then
        f = f * 0.75
    end
    return f
end

function vitals.can_regen(state)
    return state.unhappiness <= 80 and math.abs(state.temp_stage) < 2
end

function vitals.cheer(state, amount)
    if amount >= 0 then
        state.boredom = clamp(state.boredom - amount)
        state.unhappiness = clamp(state.unhappiness - amount * 0.6)
    else
        state.unhappiness = clamp(state.unhappiness - amount)
    end
end

-- Landing after a fall: returns damage and whether a bone broke
function vitals.fall(state, height)
    if height < 4 then
        return 0, false
    end
    local broke = state.fracture == nil and math.random() < (height - 3) * 0.25
    if broke then
        state.fracture = {time = clock.hours}
    end
    return (height - 3) * 9, broke
end

function vitals.splint(state)
    if state.fracture == nil or state.fracture.splinted then
        return false
    end
    state.fracture.splinted = clock.hours
    return true
end

function vitals.status(state, lines)
    local dirty = 0
    for _, w in ipairs(state.wounds) do
        if w.bandaged and clock.hours - (w.dressed or w.time) > vitals.DRESSING_DIRTY_HOURS then
            dirty = dirty + 1
        end
    end
    if dirty > 0 then
        table.insert(lines, "[#c0a060]Грязные повязки: " .. dirty .. " (смените)")
    end
    if state.fracture then
        table.insert(lines, state.fracture.splinted and "[#d0d0d0]Перелом (наложена шина)" or "[#ff7060]Перелом! Нужна шина")
    end
    local stage = state.temp_stage
    if stage <= -2 then
        table.insert(lines, "[#80b0ff]Переохлаждение")
    elseif stage == -1 then
        table.insert(lines, "[#a0c8ff]Холодно")
    elseif stage >= 2 then
        table.insert(lines, "[#ff9050]Перегрев")
    elseif stage == 1 then
        table.insert(lines, "[#ffc070]Жарко")
    end
    if state.wet > 30 then
        table.insert(lines, "[#70a0e0]" .. (state.wet > 70 and "Промок до нитки" or "Мокрая одежда"))
    end
    if state.load > gear.capacity(state) then
        table.insert(lines, "[#e0a060]Перегруз")
    end
    if state.unhappiness > 80 then
        table.insert(lines, "[#9080c0]Депрессия")
    elseif state.unhappiness > 50 then
        table.insert(lines, "[#a090d0]Грусть")
    end
    if state.boredom > 60 then
        table.insert(lines, "[#b0a0a0]Скука")
    end
    table.insert(lines, string.format("[#c8c8c8]Тело %.1f°C, улица %d°C", state.temp, math.floor(vitals.air(clock.hour()) + 0.5)))
    table.insert(lines, string.format("[#c8c8c8]Груз %.1f / %.0f кг", state.load, gear.capacity(state)))
end

return vitals
