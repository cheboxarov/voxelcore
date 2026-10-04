-- Spawner, night hordes, crafting, water, food spoilage, sleep and block breaking
app.config_packs({"zomboid"})
app.new_world("zsys", "99", "zomboid:town")
app.set_setting("chunks.load-distance", 5)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local crafting = require "zomboid:crafting"
local water = require "zomboid:water"
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
local spawn = town.spawn_point(1)
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep_until(function()
    for _, d in ipairs({{-40, -40}, {40, 40}, {-40, 40}, {40, -40}}) do
        if block.get(math.floor(spawn[1]) + d[1], G, math.floor(spawn[3]) + d[2]) == -1 then
            return false
        end
    end
    return true
end, 10000)
app.sleep(1)
local state = survival.get(pid)
local invid = player.get_inventory(pid)

-- crafting
inventory.add(invid, item.index("zomboid:rag"), 2)
check(crafting.craft(pid, 1), "bandage crafted")
check(inv.count(invid, "zomboid:bandage") == 1, "bandage in inventory")
check(not crafting.craft(pid, 2), "no spiked bat without materials")
inventory.add(invid, item.index("zomboid:plank"), 4)
check(crafting.craft(pid, 5), "campfire crafted")
check(inv.count(invid, "zomboid:campfire.item") == 1, "campfire item")
check(inv.count(invid, "zomboid:plank") == 0, "planks used")

-- water: fill an empty bottle with raw water and boil it
local _, slot = player.get_inventory(pid)
inventory.set(invid, slot, item.index("zomboid:empty_bottle"), 1)
check(water.fill_held(pid, false), "filled")
local dirty = inv.count(invid, "zomboid:dirty_water_bottle")
check(dirty == 1, "dirty water bottle")
local dslot = inventory.find_by_item(invid, item.index("zomboid:dirty_water_bottle"))
player.set_selected_slot(pid, dslot)
check(water.purify_held(pid), "boiled")
check(inv.count(invid, "zomboid:water_bottle") >= 1, "clean water")

-- spoilage: an old loaf turns rotten in the inventory
local bread = item.index("zomboid:bread")
local bslot = inventory.find_by_item(invid, 0, 0, inventory.size(invid) - 1, 0)
inventory.set(invid, bslot, bread, 1)
inventory.set_data(invid, bslot, "born", clock.hours - 24 * 5)
app.sleep(16)
check(inventory.get(invid, bslot) == item.index("zomboid:rotten_food"), "bread rotted")

-- sleep is refused near zombies and skips time otherwise
state.energy = 30
local hours = clock.hours
check(survival.sleep(pid) > 0, "slept")
check(clock.hours - hours > 4, "time skipped: " .. (clock.hours - hours))
check(state.energy > 80, "rested")

-- spawner fills the area at night of day 2 and sends a horde
state.hunger, state.thirst, state.health = 100, 100, 100
clock.reset(24 + 21.9)
zombies.enabled = true
app.sleep(25)
local count = zombies.count()
log("zombies after 25s on night 2: " .. count .. ", horde day " .. zombies.horde_day)
check(zombies.horde_day == 2, "horde triggered")
check(count >= 8, "population grows")
check(count <= zombies.limit() + 12, "population capped")
local chasing = 0
for _, z in pairs(zombies.registry) do
    if z.mode == "chase" or z.mode == "investigate" then chasing = chasing + 1 end
end
log("zombies hunting the player: " .. chasing)
check(chasing > 0, "horde is coming")

-- the player stays alive for a few seconds in a sealed room? at least the game keeps running
local t0 = time.uptime()
app.sleep(10)
log(string.format("10s with %d zombies took %.1fs real time, health %.0f", zombies.count(), time.uptime() - t0, state.health))

-- block breaking takes several hits and drops loot
zombies.enabled = false
for uid in pairs(zombies.registry) do
    entities.get(uid):despawn()
end
app.tick()
local p = town.plan(0, 0)
local cx, cy, cz = p.x0 + 1, G + 1, p.z0 + 2
local crate_name = block.name(block.get(cx, cy, cz))
check(crate_name == "zomboid:crate", "crate " .. crate_name)
local id = block.get(cx, cy, cz)
local hits = 0
while block.get(cx, cy, cz) == id and hits < 200 do
    events.emit("zomboid:.blockbreaking", id, cx, cy, cz, pid)
    hits = hits + 1
end
log("crate broken after " .. hits .. " hits")
check(block.get(cx, cy, cz) == 0, "crate destroyed")
check(hits > 10, "breaking takes time")

app.close_world(false)
app.delete_world("zsys")
