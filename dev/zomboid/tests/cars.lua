-- Cars: parked by houses and at the gas station, keys in loot, driving, fuel, running zombies over, siphoning
app.config_packs({"zomboid"})
app.new_world("zcars", "7171", "zomboid:town")
app.set_setting("chunks.load-distance", 5)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local cars = require "zomboid:cars"
local inv = require "zomboid:inv"
local G = town.GROUND

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

zombies.enabled = false
local pid = player.create("survivor")
local gp = town.find("gas_station")
local sx, sz = town.car_spot(gp)
check(sx, "gas station has a car spot")
survival.get(pid).fresh = nil
player.set_pos(pid, sx + 0.5, G + 2, sz + 4.5)
app.sleep_until(function()
    return block.get(sx + 12, G, sz + 12) ~= -1 and block.get(sx - 12, G, sz - 12) ~= -1
end, 20000)
app.sleep(3)
local state = survival.get(pid)
local invid, slot = player.get_inventory(pid)

local function car_near(x, z)
    for _, uid in ipairs(entities.get_all_in_radius({x + 0.5, G + 1, z + 0.5}, 3)) do
        local e = entities.get(uid)
        local c = e and e:get_component("zomboid:car")
        if c then return uid, c end
    end
end

-- the spawner turned into a parked car
local uid, car = car_near(sx, sz)
check(uid, "car parked at the gas station")
check(block.name(block.get(sx, G + 1, sz)) == "core:air", "spawner removed")
check(car.data.id == cars.id_at(sx, sz), "car id " .. tostring(car.data.id))
-- a spawner replaced before its present event spawns nothing
block.set(sx + 6, G + 1, sz, block.index("zomboid:car_spawner"), 0)
block.set(sx + 6, G + 1, sz, 0, 0)
app.sleep(0.5)
check(car_near(sx + 6, sz) == nil, "car from a removed spawner")
log(string.format("car %s: %.1f l, color %s", car.data.id, car.data.fuel, car.data.color))

-- locked without a key; keys come from containers of the same building
check(not cars.enter(pid, uid), "locked")
local box = inventory.create(12)
local found
for _ = 1, 60 do
    if cars.add_key(box, "shelf", gp.x0 + 3, gp.z0 + 4) then found = true break end
end
check(found, "key generated")
local kslot = inventory.find_by_item(box, item.index("zomboid:car_key"))
check(inventory.get_data(box, kslot, "car") == car.data.id, "key matches the car")
check(not cars.add_key(box, "medicine_cabinet", gp.x0 + 3, gp.z0 + 4), "no keys in medicine cabinets")
local pslot = inventory.size(invid) - 1
inventory.set(invid, pslot, item.index("zomboid:car_key"), 1)
inventory.set_data(invid, pslot, "car", inventory.get_data(box, kslot, "car"))
inventory.remove(box)
check(cars.has_key(pid, car.data.id), "player has the key")

-- refuel from a can, siphon back
car.data.fuel = 2
inventory.set(invid, slot, item.index("zomboid:gas_can"), 1)
inventory.set_data(invid, slot, "uses", 10)
cars.use(pid, uid)
check(math.abs(car.data.fuel - 12) < 0.01, "refueled: " .. car.data.fuel)
check(item.name(inventory.get(invid, slot)) == "zomboid:gas_can_empty", "can poured")
cars.use(pid, uid)
check(item.name(inventory.get(invid, slot)) == "zomboid:gas_can" and inventory.get_uses(invid, slot) == 10, "siphoned")
check(math.abs(car.data.fuel - 2) < 0.01, "tank drained")
car.data.fuel = 20
inventory.set(invid, slot, 0, 0)

-- drive: enter, throttle, the car moves, burns fuel and carries the driver
local cpos = car.get_pos()
player.set_pos(pid, cpos[1], cpos[2] + 0.3, cpos[3] + 2.6)
app.tick()
check(cars.toggle(pid), "entered with F")
check(car.driver == pid and cars.car_of(pid) ~= nil, "driver set")
-- move the car onto the straight main street along z = 2 and point it east
local road_z = 2
for x = 105, 170 do
    check(town.column(x, road_z) == "road", "road at " .. x)
end
entities.get(uid).transform:set_pos({105.5, G + 1.75, road_z + 0.5})
car.data.heading = 90
app.sleep(0.5)
local start = car.get_pos()
local fuel0 = car.data.fuel
car.control.throttle = 1
app.sleep(3)
car.control.throttle = 0
local pos = car.get_pos()
local moved = math.sqrt((pos[1] - start[1]) ^ 2 + (pos[3] - start[3]) ^ 2)
local ppos = {player.get_pos(pid)}
log(string.format("drove %.1f m, speed %.1f, fuel %.2f -> %.2f", moved, car.speed, fuel0, car.data.fuel))
check(moved > 8, "car moved")
check(car.data.fuel < fuel0, "fuel burned")
check(vec3.distance(ppos, pos) < 1.5, "driver rides inside")
check(cars.status(pid):find("км/ч"), "HUD status")
car.data.fuel, car.speed = 29.9, 15
check(utf8.length(cars.status(pid)) <= 27, "HUD status fits one line of the status box: " .. cars.status(pid))
car.data.fuel = fuel0

-- running over a zombie hurts it a lot
app.sleep(2)
pos = car.get_pos()
local z = zombies.spawn(math.floor(pos[1]) + 10, G + 1, road_z, {})
local zc = z:get_component("zomboid:zombie")
app.tick()
car.control.throttle = 1
app.sleep(2.5)
car.control.throttle = 0
log("zombie hit by the car: dead " .. tostring(zc.is_dead()))
check(zc.is_dead(), "zombie run over")

-- no fuel, no driving
car.data.fuel = 0
app.sleep(3)
local p1 = car.get_pos()
car.control.throttle = 1
app.sleep(1.5)
car.control.throttle = 0
local p2 = car.get_pos()
check(math.sqrt((p2[1] - p1[1]) ^ 2 + (p2[3] - p1[3]) ^ 2) < 1.5, "empty tank stops the car")

-- exit puts the player next to the car with physics back on, on the side free of walls
local cp = car.get_pos()
local feet = math.floor(cp[2] - 0.5)
local wx, wz = math.floor(cp[1]), math.floor(cp[3] - 1.8)
block.set(wx, feet, wz, block.index("base:stone"), 0)
block.set(wx, feet + 1, wz, block.index("base:stone"), 0)
check(cars.toggle(pid), "exited with F")
local ex, _, ez = player.get_pos(pid)
check(ez > cp[3] - 1, "stepped out away from the wall: " .. (ez - cp[3]))
check(block.is_replaceable_at(math.floor(ex), feet, math.floor(ez))
    and block.is_replaceable_at(math.floor(ex), feet + 1, math.floor(ez)), "not inside a wall")
check(car.driver == nil and cars.driving[pid] == nil, "no driver")
local e = entities.get(player.get_entity(pid))
check(e.rigidbody:is_enabled(), "player body enabled")
check(vec3.distance({player.get_pos(pid)}, car.get_pos()) > 1.2, "standing beside the car")

-- dying at the wheel frees the seat and the body
check(cars.toggle(pid), "back in the car")
survival.kill(pid, "zombies")
app.sleep(0.5)
check(cars.driving[pid] == nil and car.driver == nil, "dead driver left the car")
check(entities.get(player.get_entity(pid)).rigidbody:is_enabled(), "body enabled after death")

-- house car spots exist and get keys from their own house
local houses = 0
for _, c in ipairs(town.cells()) do
    local p = town.plan(c.cx, c.cz)
    if p and p.kind == "house" and p.car then houses = houses + 1 end
end
log("houses with a car: " .. houses)
check(houses > 3, "several houses have cars")

app.close_world(false)
app.delete_world("zcars")
