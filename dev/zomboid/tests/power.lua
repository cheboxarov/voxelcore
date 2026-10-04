-- Power: house lamps, grid shutoff, fridges and stoves, gasoline generator, fuel pumps
app.config_packs({"zomboid"})
app.new_world("zpower", "4242", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local power = require "zomboid:power"
local inv = require "zomboid:inv"
local spoilage = require "zomboid:spoilage"
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
local spawn = town.spawn_point(1)
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep_until(function()
    return block.get(math.floor(spawn[1]) + 16, G, math.floor(spawn[3]) + 16) ~= -1
        and block.get(math.floor(spawn[1]) - 16, G, math.floor(spawn[3]) - 16) ~= -1
end, 8000)
app.sleep(1)
local state = survival.get(pid)
local invid, slot = player.get_inventory(pid)

local function hold(name, count, uses)
    inventory.set(invid, slot, item.index(name), count or 1)
    if uses then
        inventory.set_data(invid, slot, "uses", uses)
    end
end

local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local p = town.plan(cx, cz)
local ox, oz = p.x0, p.z0
local lx, ly, lz = ox + p.mid, G + 3, oz + math.floor(p.split / 2)

-- day 1: the living room lamp is lit
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp", "lamp on day 1: " .. block.name(block.get(lx, ly, lz)))
check(table.count_pairs(power.lamps) >= 3, "lamps tracked: " .. table.count_pairs(power.lamps))
check(power.has_power(lx, ly, lz), "grid on")

local fx, fy, fz = ox + p.mid - 1, G + 1, oz + p.d - 2
local finv = inventory.get_block(fx, fy, fz)
local bread = item.index("zomboid:bread")
local function fresh_bread()
    inventory.set(finv, 0, bread, 1)
    inventory.set_data(finv, 0, "born", clock.hours)
    inventory.set_data(finv, 0, "cold", nil)
    spoilage.check(finv, true)
end

-- shutoff: lamps go dark, the stove stops working
clock.reset(24 * (require("zomboid:sandbox").get("power_shutoff_day") - 1) + 9)
app.sleep(3)
check(not power.grid_on(), "grid off")
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp_off", "lamp off: " .. block.name(block.get(lx, ly, lz)))
fresh_bread()
clock.reset(clock.hours + 10)
spoilage.check(finv, true, false)
check(spoilage.age(finv, 0) > 9.9, "dead fridge does not chill")
local sx, sy, sz = ox + 3, G + 1, oz + p.d - 2
if block.name(block.get(sx, sy, sz)) == "zomboid:stove" then
    hold("zomboid:dirty_water_bottle")
    events.emit("zomboid:stove.interact", sx, sy, sz, pid)
    check(item.name(inventory.get(invid, slot)) == "zomboid:dirty_water_bottle", "stove dead without power")
end

-- generator: needs fuel, powers the house, burns gasoline, makes noise
local gx, gy, gz = ox + p.mid, G + 1, oz + 2
block.set(gx, gy, gz, block.index("zomboid:generator"), 0)
app.tick()
hold("zomboid:bat")
events.emit("zomboid:generator.interact", gx, gy, gz, pid)
check(not power.is_running(gx, gy, gz), "no start without fuel")
hold("zomboid:gas_can", 1, 10)
events.emit("zomboid:generator.interact", gx, gy, gz, pid)
check(block.get_field(gx, gy, gz, "fuel") == 10, "fuel poured: " .. tostring(block.get_field(gx, gy, gz, "fuel")))
check(item.name(inventory.get(invid, slot)) == "zomboid:gas_can_empty", "can emptied")
hold("zomboid:bat")
events.emit("zomboid:generator.interact", gx, gy, gz, pid)
check(power.is_running(gx, gy, gz), "generator running")
check(power.has_power(lx, ly, lz), "generator powers the house")
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp", "lamp back on")
check(not power.has_power(gx + 40, gy, gz), "far away still dark")
check(power.generator_near(fx, fy, fz), "fridge on generator power")
fresh_bread()
clock.reset(clock.hours + 2)
spoilage.check(finv, true, true)
log(string.format("fridge on generator: 2h aged the bread by %.2fh", spoilage.age(finv, 0)))
check(spoilage.age(finv, 0) < 1, "generator keeps the fridge cold")
local z = zombies.spawn(gx + 15, G + 1, gz, {})
local zc = z:get_component("zomboid:zombie")
clock.reset(clock.hours + 2)
app.sleep(3)
local left = block.get_field(gx, gy, gz, "fuel")
log(string.format("generator fuel after 4h: %.2f, zombie mode %s", left, zc.mode))
check(left < 9 and left > 7, "fuel burned")
check(zc.mode == "investigate" or zc.mode == "chase", "zombie hears the generator")
z:despawn()
clock.reset(clock.hours + 30)
app.sleep(3)
check(not power.is_running(gx, gy, gz), "generator stops when empty")
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp_off", "lamp off again")

-- the gas station pump works only with power
local gp = town.find("gas_station")
check(gp and gp.kind == "gas_station", "gas station cell")
local px, py, pz = gp.x0 + 2, G + 1, gp.z0 - 4
player.set_pos(pid, px + 0.5, G + 2, pz - 2)
app.sleep_until(function() return block.get(px, py, pz) ~= -1 end, 6000)
app.sleep(1)
check(block.name(block.get(px, py, pz)) == "zomboid:fuel_pump", "pump: " .. block.name(block.get(px, py, pz)))
hold("zomboid:gas_can_empty")
events.emit("zomboid:fuel_pump.interact", px, py, pz, pid)
check(item.name(inventory.get(invid, slot)) == "zomboid:gas_can_empty", "dead pump")
block.set(px + 2, py, pz, block.index("zomboid:generator"), 0)
block.set_field(px + 2, py, pz, "fuel", 5)
power.set_running(px + 2, py, pz, true)
events.emit("zomboid:fuel_pump.interact", px, py, pz, pid)
check(item.name(inventory.get(invid, slot)) == "zomboid:gas_can", "pump filled the can")
check(inventory.get_uses(invid, slot) == 10, "full can")

-- a running generator in an unloaded chunk catches up on fuel when the chunk loads again
app.sleep(2)
local fuel0 = block.get_field(px + 2, py, pz, "fuel")
player.set_pos(pid, px + 400.5, G + 30, pz)
app.sleep_until(function() return block.get(px + 2, py, pz) == -1 end, 6000)
app.sleep(0.5)
check(power.generators[(px + 2) .. ":" .. py .. ":" .. pz] == nil, "unloaded generator untracked")
clock.reset(clock.hours + 6)
player.set_pos(pid, px + 0.5, G + 2, pz - 2)
app.sleep_until(function() return block.get(px + 2, py, pz) ~= -1 end, 6000)
app.sleep(3)
local caught = block.get_field(px + 2, py, pz, "fuel")
log(string.format("generator away for 6h: %.2f -> %.2f l", fuel0, caught))
check(math.abs(fuel0 - 6 * power.LITERS_PER_HOUR - caught) < 0.3, "fuel burned while unloaded")
check(power.is_running(px + 2, py, pz), "still running")

app.close_world(false)
app.delete_world("zpower")
