local town = require "zomboid:town"
local survival = require "zomboid:survival"
local fuel = require "zomboid:fuel"
local inv = require "zomboid:inv"

local cars = {
    TANK = 30,
    KEY_CHANCE = 0.35,
    driving = {},
}

local KEY_CONTAINERS = {wardrobe = true, kitchen_cabinet = true, shelf = true}

function cars.id_at(x, z)
    return x .. ":" .. z
end

function cars.spawn(x, y, z)
    return entities.spawn("zomboid:car", {x + 0.5, y + 0.72, z + 0.5}, {zomboid__car = {id = cars.id_at(x, z)}})
end

function cars.add_key(invid, container, x, z)
    if not KEY_CONTAINERS[container] or math.random() > cars.KEY_CHANCE then
        return false
    end
    local _, p = town.building_at(x, z)
    local sx, sz = town.car_spot(p)
    local slot = sx and inventory.find_by_item(invid, 0, 0, inventory.size(invid) - 1, 0)
    if slot == nil then
        return false
    end
    inventory.set(invid, slot, item.index("zomboid:car_key"), 1)
    inventory.set_data(invid, slot, "car", cars.id_at(sx, sz))
    inventory.set_description(invid, slot, "От машины у этого здания")
    return true
end

function cars.has_key(pid, id)
    local invid = player.get_inventory(pid)
    local key = item.index("zomboid:car_key")
    for slot = 0, inventory.size(invid) - 1 do
        if inventory.get(invid, slot) == key and inventory.get_data(invid, slot, "car") == id then
            return true
        end
    end
    return false
end

local function component(uid)
    local e = uid and entities.get(uid)
    return e and e:get_component("zomboid:car")
end

local function player_body(pid)
    local e = entities.get(player.get_entity(pid))
    return e and e.rigidbody
end

function cars.car_of(pid)
    return component(cars.driving[pid])
end

function cars.enter(pid, uid)
    local car = component(uid)
    if car == nil or car.driver ~= nil or cars.driving[pid] then
        return false
    end
    if not cars.has_key(pid, car.data.id) then
        survival.notify(pid, "Машина заперта. Нужен ключ от неё - поищите в доме рядом", "#ff9050")
        return false
    end
    player.set_vel(pid, 0, 0, 0)
    local body = player_body(pid)
    if body then
        body:set_enabled(false)
    end
    car.driver = pid
    cars.driving[pid] = uid
    survival.notify(pid, string.format("Вы сели за руль. Бензин: %.1f л. W/S - газ/тормоз, A/D - руль, F - выйти",
        car.data.fuel), "#e0c060")
    return true
end

function cars.exit(pid)
    local car = cars.car_of(pid)
    cars.driving[pid] = nil
    local body = player_body(pid)
    if body then
        body:set_enabled(true)
    end
    if car == nil then
        return false
    end
    car.driver = nil
    car.speed = 0
    local pos = car.get_pos()
    local h = math.rad(car.data.heading)
    local s, c = math.sin(h), math.cos(h)
    local feet = math.floor(pos[2] - 0.5)
    local x, y, z = pos[1], pos[2] + 1.6, pos[3]
    for _, d in ipairs({{c, -s, 1.8}, {-c, s, 1.8}, {-s, -c, 2.2}, {s, c, 2.2}}) do
        local dx, dz = pos[1] + d[1] * d[3], pos[3] + d[2] * d[3]
        if block.is_replaceable_at(math.floor(dx), feet, math.floor(dz))
            and block.is_replaceable_at(math.floor(dx), feet + 1, math.floor(dz)) then
            x, y, z = dx, pos[2] + 0.4, dz
            break
        end
    end
    player.set_pos(pid, x, y, z)
    player.set_vel(pid, 0, 0, 0)
    survival.notify(pid, "Вы вышли из машины")
    return true
end

function cars.use(pid, uid)
    local car = component(uid)
    if car == nil then
        return false
    end
    local liters = fuel.held_can(pid)
    if liters == nil then
        return cars.enter(pid, uid)
    end
    if liters > 0 then
        local poured = fuel.pour(pid, cars.TANK - car.data.fuel)
        car.data.fuel = car.data.fuel + poured
        survival.notify(pid, string.format("Залито %d л. В баке %.1f / %d л", poured, car.data.fuel, cars.TANK), "#e0c060")
    else
        local taken = fuel.fill(pid, car.data.fuel)
        car.data.fuel = car.data.fuel - taken
        survival.notify(pid, taken > 0 and string.format("Слито %d л бензина из бака", taken) or "Бак машины пуст")
    end
    return true
end

function cars.toggle(pid)
    if cars.driving[pid] then
        return cars.exit(pid)
    end
    local best, best_dist = nil, 3.5
    local ppos = {player.get_pos(pid)}
    for _, uid in ipairs(entities.get_all_in_radius(ppos, best_dist)) do
        local car = component(uid)
        if car and vec3.distance(car.get_pos(), ppos) < best_dist then
            best, best_dist = uid, vec3.distance(car.get_pos(), ppos)
        end
    end
    return best ~= nil and cars.enter(pid, best)
end

function cars.status(pid)
    local car = cars.car_of(pid)
    if car == nil then
        return nil
    end
    return string.format("Машина: %d км/ч, бензин %.1f л", math.floor(math.abs(car.speed) * 3.6), car.data.fuel)
end

return cars
