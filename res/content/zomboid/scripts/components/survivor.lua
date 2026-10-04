local body = entity.rigidbody
local tsf = entity.transform
local mob = entity:require_component("core:mob")

local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local inv = require "zomboid:inv"
local skills = require "zomboid:skills"
local combat = require "zomboid:combat"
local firearms = require "zomboid:firearms"
local gear = require "zomboid:gear"
local vitals = require "zomboid:vitals"
local heat = require "zomboid:heat"

local BASE_SPEED = 27.0
local tick = 0
local fall_top
local last_pos

local function sense(pid, state, pos)
    local x, y, z = math.floor(pos[1]), math.floor(pos[2]), math.floor(pos[3])
    state.indoors = false
    for dy = 2, 16 do
        if block.get(x, y + dy, z) > 0 then
            state.indoors = true
            break
        end
    end
    state.in_water = block.name(block.get(x, y, z)) == "base:water"
    state.heat = heat.near(x, y, z, 3)
    state.load = gear.load(pid, state)
end

local function track_fall(pid, state, pos)
    local teleported = last_pos and math.abs(pos[2] - last_pos[2]) + math.abs(pos[1] - last_pos[1])
        + math.abs(pos[3] - last_pos[3]) > 3
    last_pos = pos
    if teleported then
        fall_top = nil
    elseif not body:is_grounded() then
        if fall_top then
            fall_top = math.max(fall_top, pos[2])
        end
    elseif fall_top == nil then
        fall_top = -math.huge
    else
        local height = fall_top - pos[2]
        fall_top = -math.huge
        if height > 0 and not state.in_water then
            local damage, broke = vitals.fall(state, height)
            if broke then
                survival.notify(pid, "Вы сломали ногу! Нужна шина", "#ff5040")
            end
            if damage > 0 then
                survival.damage(pid, damage, "fall")
                local x, y, z = unpack(pos)
                audio.play_sound("player/hurt", x, y, z, 1.0, 0.8)
            end
        end
    end
end

function on_update(tps)
    local pid = entity:get_player()
    if pid == nil or pid < 0 then
        return
    end
    local state = survival.get(pid)
    if state.dead then
        local vel = body:get_vel()
        body:set_vel({0, math.min(vel[2], 0), 0})
        return
    end
    local pos = tsf:get_pos()
    local vel = body:get_vel()
    local speed = math.sqrt(vel[1] * vel[1] + vel[3] * vel[3])
    state.crouching = body:is_crouching()
    state.sprinting = speed > 3.4 and body:is_grounded()
    state.moving = speed > 0.8
    track_fall(pid, state, pos)

    local itemid = inv.held(pid)
    local emission = itemid ~= 0 and item.emission(itemid)
    state.light = type(emission) == "table" and (emission[1] or 0) > 0

    mob.set_movement_speed(BASE_SPEED * survival.speed_factor(state) * (combat.is_grabbed(state) and 0.3 or 1))
    firearms.update(pid)
    mob.set_run_speed_mul(survival.can_sprint(state) and 1.5 or 1.0)

    tick = tick + 1
    if tick % 10 == 0 then
        sense(pid, state, pos)
        if speed > 0.8 and not state.crouching then
            zombies.noise(pos, (state.sprinting and 11 or 4.5) * skills.mul(pid, "noise"), pid)
        end
    end
end
