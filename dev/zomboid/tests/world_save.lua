-- World systems survive save and reload: generator and lamps, crops, rain barrel, car, weather, explored map
app.config_packs({"zomboid"})
app.new_world("zsave", "8181", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local clock = require "zomboid:clock"
local weather = require "zomboid:weather"
local power = require "zomboid:power"
local mapping = require "zomboid:mapping"
local sandbox = require "zomboid:sandbox"
local G = town.GROUND

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

require("zomboid:zombies").enabled = false
local pid = player.create("survivor")
local spawn = town.spawn_point(1)
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
local function wait_loaded()
    app.sleep_until(function()
        return block.get(math.floor(spawn[1]) + 16, G, math.floor(spawn[3]) + 16) ~= -1
            and block.get(math.floor(spawn[1]) - 16, G, math.floor(spawn[3]) - 16) ~= -1
    end, 8000)
    app.sleep(2)
end
wait_loaded()

local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local p = town.plan(cx, cz)
local ox, oz = p.x0, p.z0
local lx, ly, lz = ox + p.mid, G + 3, oz + math.floor(p.split / 2)
local gx, gy, gz = ox + p.mid, G + 1, oz + 2
local bx, by, bz = ox + p.w + 1, G + 1, oz - 1

-- after the shutoff, a running generator lights the house
clock.reset(24 * (sandbox.get("power_shutoff_day") - 1) + 10)
block.set(gx, gy, gz, block.index("zomboid:generator"), 0)
block.set_field(gx, gy, gz, "fuel", 9)
power.set_running(gx, gy, gz, true)
block.set(bx, by, bz, block.index("zomboid:rain_barrel"), 0)
block.set_field(bx, by, bz, "water", 17)
block.set(bx + 2, by, bz, block.index("zomboid:crop_potato"), 0)
block.set_field(bx + 2, by, bz, "growth", 30)
block.set_field(bx + 2, by, bz, "water", 60)
block.set_field(bx + 2, by, bz, "last", clock.hours)
local car = require("zomboid:cars").spawn(bx + 4, G + 1, bz - 3)
car:get_component("zomboid:car").data.fuel = 7.5
weather.set_raining(true)
local next_change = weather.next_change
app.sleep(3)
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp", "lamp lit by the generator")
check(mapping.is_explored(pid, spawn[1], spawn[3]), "explored before save")

app.save_world()
app.close_world(true)
app.open_world("zsave")
survival = require "zomboid:survival"
clock = require "zomboid:clock"
weather = require "zomboid:weather"
power = require "zomboid:power"
mapping = require "zomboid:mapping"
require("zomboid:zombies").enabled = false
wait_loaded()

check(not power.grid_on(), "still after the shutoff")
check(power.is_running(gx, gy, gz), "generator still running")
check(block.get_field(gx, gy, gz, "fuel") > 8, "generator fuel kept")
check(block.name(block.get(lx, ly, lz)) == "zomboid:lamp", "lamp lit after reload: " .. block.name(block.get(lx, ly, lz)))
check(math.abs(block.get_field(bx, by, bz, "water") - 17) < 1, "barrel water kept")
check(block.get_field(bx + 2, by, bz, "growth") >= 30, "crop growth kept")
check(weather.raining and math.abs(weather.next_change - next_change) < 0.01, "weather kept")
check(require("zomboid:vitals").rain == 1, "vitals rain restored")
check(mapping.is_explored(pid, spawn[1], spawn[3]), "explored map kept")
local found
for _, uid in ipairs(entities.get_all_in_radius({bx + 4.5, G + 1, bz - 2.5}, 4)) do
    local c = entities.get(uid):get_component("zomboid:car")
    if c then found = c end
end
check(found and math.abs(found.data.fuel - 7.5) < 0.01 and found.data.id == (bx + 4) .. ":" .. (bz - 3), "car kept")
log("world systems restored after reload")

app.close_world(false)
app.delete_world("zsave")
