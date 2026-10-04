local tsf = entity.transform
local body = entity.rigidbody
local rig = entity.skeleton

local cars = require "zomboid:cars"
local town = require "zomboid:town"
local noise = require "zomboid:noise"
local zombies = require "zomboid:zombies"
local survival = require "zomboid:survival"

local COLORS = {"red", "blue", "white", "green", "black", "silver", "yellow"}
local MAX_SPEED = 15
local REVERSE_SPEED = 4
local ACCEL = 6
local BRAKE = 14
local TURN = 90
local LITERS_PER_METER = 1 / 250
local IDLE_LITERS_PER_SECOND = 1 / 600
local NOISE_RADIUS = 28

data = SAVED_DATA
if data.id == nil then
    local pos = tsf:get_pos()
    local x, z = math.floor(pos[1]), math.floor(pos[3])
    data.id = (ARGS or {}).id or tostring(entity:get_uid())
    data.fuel = math.floor(town.hash(x, z, 31) * 120) / 10
    data.heading = math.floor(town.hash(x, z, 32) * 4) * 90
    data.color = (ARGS or {}).color or COLORS[1 + math.floor(town.hash(x, z, 33) * #COLORS)]
end
if data.body == nil then
    local pos = tsf:get_pos()
    data.body = town.hash(math.floor(pos[1]), math.floor(pos[3]), 34) < 0.3 and "pickup" or "sedan"
end
rig:set_texture("$paint", "blocks:car_" .. data.color)
rig:set_visible(rig:index(data.body == "pickup" and "sedan" or "pickup"), false)

driver = nil
speed = 0
control = {throttle = 0, steer = 0}

local tick = 0
local empty_warned = false

function get_pos()
    return tsf:get_pos()
end

local function read_input()
    if not vc.is_client() or hud.get_player() ~= driver or hud.is_inventory_open() then
        return
    end
    control.throttle = (input.is_active("movement.forward") and 1 or 0) - (input.is_active("movement.back") and 1 or 0)
    control.steer = (input.is_active("movement.left") and 1 or 0) - (input.is_active("movement.right") and 1 or 0)
end

local function drive(delta)
    read_input()
    local throttle = data.fuel > 0 and control.throttle or 0
    if throttle > 0 then
        speed = speed < 0 and math.min(0, speed + BRAKE * delta) or math.min(MAX_SPEED, speed + ACCEL * delta)
    elseif throttle < 0 then
        speed = speed > 0 and math.max(0, speed - BRAKE * delta) or math.max(-REVERSE_SPEED, speed - ACCEL * delta)
    else
        speed = speed * math.max(0, 1 - 1.2 * delta)
        if math.abs(speed) < 0.1 then speed = 0 end
    end
    data.heading = (data.heading + control.steer * TURN * delta * math.max(-1, math.min(1, speed / 4))) % 360
    data.fuel = math.max(0, data.fuel - math.abs(speed) * delta * LITERS_PER_METER - IDLE_LITERS_PER_SECOND * delta)
    if data.fuel <= 0 and not empty_warned then
        empty_warned = true
        survival.notify(driver, "Бензин кончился. Залейте бак из канистры", "#ff9050")
    elseif data.fuel > 0 then
        empty_warned = false
    end
end

function on_physics_update(delta)
    local vel = body:get_vel()
    if driver ~= nil and survival.get(driver).dead then
        cars.exit(driver)
    end
    if driver ~= nil and not player.is_suspended(driver) then
        drive(delta)
        local h = math.rad(data.heading)
        local actual = math.sqrt(vel[1] ^ 2 + vel[3] ^ 2)
        if math.abs(speed) > 3 and actual < math.abs(speed) * 0.3 then
            speed = speed * 0.5
        end
        body:set_vel({math.sin(h) * speed, vel[2], math.cos(h) * speed})
        local pos = tsf:get_pos()
        player.set_pos(driver, pos[1], pos[2] - 0.3, pos[3])
        player.set_vel(driver, 0, 0, 0)
    else
        speed = 0
        body:set_vel({0, vel[2], 0})
    end
    tsf:set_rot(mat4.rotate({0, 1, 0}, data.heading))
end

local function ram()
    local pos = tsf:get_pos()
    local h = math.rad(data.heading)
    local front = {pos[1] + math.sin(h) * 1.4 * (speed > 0 and 1 or -1), pos[2], pos[3] + math.cos(h) * 1.4 * (speed > 0 and 1 or -1)}
    for _, z in pairs(zombies.registry) do
        local zpos = z.get_pos()
        if not z.is_dead() and vec3.distance(zpos, front) < 1.6 then
            z.take_hit(math.abs(speed) * 6, math.abs(speed) * 0.8, pos, driver)
            speed = speed * 0.7
        end
    end
end

function on_update(tps)
    if driver == nil then
        return
    end
    if math.abs(speed) > 2.5 then
        ram()
    end
    tick = tick + 1
    if tick % 20 == 0 then
        local pos = tsf:get_pos()
        noise.emit(pos, NOISE_RADIUS, driver, 2)
        if vc.is_client() then
            audio.play_sound("world/engine", pos[1], pos[2], pos[3], 0.6, 0.8 + math.abs(speed) / MAX_SPEED)
        end
    end
end

function on_used(pid)
    cars.use(pid, entity:get_uid())
end

function on_despawn()
    if driver ~= nil then
        cars.exit(driver)
    end
end
