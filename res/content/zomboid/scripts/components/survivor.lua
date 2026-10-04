local body = entity.rigidbody
local tsf = entity.transform
local mob = entity:require_component("core:mob")

local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local inv = require "zomboid:inv"
local skills = require "zomboid:skills"
local combat = require "zomboid:combat"
local firearms = require "zomboid:firearms"

local BASE_SPEED = 27.0
local tick = 0

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
    local vel = body:get_vel()
    local speed = math.sqrt(vel[1] * vel[1] + vel[3] * vel[3])
    state.crouching = body:is_crouching()
    state.sprinting = speed > 3.4 and body:is_grounded()
    state.moving = speed > 0.8

    local itemid = inv.held(pid)
    local emission = itemid ~= 0 and item.emission(itemid)
    state.light = type(emission) == "table" and (emission[1] or 0) > 0

    mob.set_movement_speed(BASE_SPEED * survival.speed_factor(state) * (combat.is_grabbed(state) and 0.3 or 1))
    firearms.update(pid)
    mob.set_run_speed_mul(survival.can_sprint(state) and 1.5 or 1.0)

    tick = tick + 1
    if tick % 10 == 0 and speed > 0.8 and not state.crouching then
        zombies.noise(tsf:get_pos(), (state.sprinting and 11 or 4.5) * skills.mul(pid, "noise"), pid)
    end
end
