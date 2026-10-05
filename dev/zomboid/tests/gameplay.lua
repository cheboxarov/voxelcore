-- Survival loop: character setup, stats, loot, zombie AI, combat, barricades, death and save
app.config_packs({"zomboid"})
app.new_world("zplay", "4242", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 4)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local loot = require "zomboid:loot"
local barricade = require "zomboid:barricade"
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
    return block.get(math.floor(spawn[1]) + 12, G, math.floor(spawn[3]) + 12) ~= -1
        and block.get(math.floor(spawn[1]) - 12, G, math.floor(spawn[3]) - 12) ~= -1
end, 6000)
app.sleep(1)

-- new character inside the spawn house with a starter kit
local state = survival.get(pid)
state.setup = nil
check(not state.fresh, "character initialized")
local invid = player.get_inventory(pid)
check(inv.count(invid, "zomboid:water_bottle") == 1, "starter water")
check(not player.is_infinite_items(pid), "survival inventory")
local px, py, pz = player.get_pos(pid)
log(string.format("spawned at %.1f %.1f %.1f", px, py, pz))
check(math.abs(px - spawn[1]) < 1.5 and math.abs(pz - spawn[3]) < 1.5, "spawn position")
check(py > G and py < G + 3, "standing on the house floor: " .. py)

-- clock and needs
local hunger0, thirst0 = state.hunger, state.thirst
survival.update(pid, 5, 0)
check(state.hunger < hunger0 and state.thirst < thirst0, "needs decay")
log(string.format("after 5h: hunger %.1f thirst %.1f energy %.1f", state.hunger, state.thirst, state.energy))
check(clock.day() == 1, "first day")

-- loot in the spawn house fridge
local p = town.plan(town.cell_at(math.floor(spawn[1]), math.floor(spawn[3])))
local fx, fy, fz = p.x0 + p.mid - 1, G + 1, p.z0 + p.d - 2
check(block.name(block.get(fx, fy, fz)) == "zomboid:fridge", "fridge")
local finv = inventory.get_block(fx, fy, fz)
local added = loot.fill(finv, "fridge", fx, fz, clock.START_HOUR)
log("fridge items: " .. added)
check(added > 0, "fridge loot")

-- wounds, bleeding and bandaging
survival.add_wound(pid, "laceration")
check(survival.bleeding_count(state) == 1, "bleeding")
local hp = state.health
survival.update(pid, 0.01, 5)
check(state.health < hp, "blood loss")
check(survival.treat(pid, "bandage"), "bandaged")
check(survival.bleeding_count(state) == 0, "bleeding stopped")
state.health = 100
state.infection = nil

-- zombie notices the player and attacks
local ex, ez = math.floor(px), math.floor(pz) - 8
local zx, zy, zz
for dz = 0, 4 do
    local y = zombies.find_ground(ex, ez - dz)
    if y and town.building_at(ex, ez - dz) == nil then
        zx, zy, zz = ex, y, ez - dz
        break
    end
end
-- open the front door path by standing outside the house
local door = {p.x0 + p.door + 0.5, G + 1.95, p.z0 - 2.5}
player.set_pos(pid, door[1], door[2], door[3])
app.sleep(0.5)
zx, zz = math.floor(door[1]), math.floor(door[3]) - 9
zy = zombies.find_ground(zx, zz)
check(zy ~= nil, "zombie ground")
local z = zombies.spawn(zx, zy, zz, {})
check(z ~= nil, "zombie spawned")
local comp = z:get_component("zomboid:zombie")
check(comp ~= nil, "zombie component")
check(zombies.count() == 1, "registry")
local d0 = vec3.distance(comp.get_pos(), {player.get_pos(pid)})
comp.hear({player.get_pos(pid)}, pid, d0)
app.sleep(5)
local d1 = vec3.distance(comp.get_pos(), {player.get_pos(pid)})
log(string.format("zombie distance %.1f -> %.1f, mode %s", d0, d1, comp.mode))
check(d1 < d0 - 2, "zombie approaches")
local health_before = state.health
app.sleep_until(function() return state.health < health_before end, 400)
log(string.format("player hit: health %.1f, wounds %d", state.health, #state.wounds))

-- combat: bat until the zombie dies
local bat = item.index("zomboid:bat")
local _, slot = player.get_inventory(pid)
inventory.set(invid, slot, bat, 1)
local hits = 0
while not comp.is_dead() and hits < 20 do
    local zp = comp.get_pos()
    player.set_pos(pid, zp[1], zp[2], zp[3] + 1.2)
    comp.on_attacked(player.get_entity(pid), pid)
    hits = hits + 1
    app.sleep(1.0)
end
log("zombie killed with " .. hits .. " swings, kills " .. state.kills)
check(comp.is_dead(), "zombie dead")
check(state.kills == 1, "kill counted")
check(zombies.count() == 0, "dead zombie unregistered")
check(inventory.get_uses(invid, slot) < item.uses(bat), "bat durability spent")

-- barricades: nail planks to a window, then let a zombie break them
local wx, wy, wz
for x = p.x0 + 1, p.x0 + p.w - 2 do
    if block.name(block.get(x, G + 1, p.z0)) == "zomboid:window" then
        wx, wy, wz = x, G + 1, p.z0
        break
    end
end
check(wx ~= nil, "front window")
inventory.add(invid, item.index("zomboid:plank"), 4)
inventory.add(invid, item.index("zomboid:nails"), 8)
check(barricade.add(pid, wx, wy, wz), "first plank")
check(barricade.add(pid, wx, wy, wz), "second plank")
check(block.name(block.get(wx, wy, wz)) == "zomboid:barricade", "barricade block")
check(block.get_variant(wx, wy, wz) == 1, "two planks")
check(block.get_field(wx, wy, wz, "hp") == 50, "barricade hp")
local broken = false
for _ = 1, 20 do
    if barricade.bash(wx, wy, wz, 5) then broken = true break end
end
check(broken, "zombies break barricades")
check(block.name(block.get(wx, wy, wz)) == "zomboid:window_broken", "window left broken")
block.set(wx, wy, wz, block.index("zomboid:bld_stained_glass"), 0)
local planks = inv.count(invid, "zomboid:plank")
check(barricade.add(pid, wx, wy, wz), "stained glass plank")
check(block.name(block.get(wx, wy, wz)) == "zomboid:barricade", "stained glass barricaded")
check(inv.count(invid, "zomboid:plank") == planks - 1, "stained glass barricade takes a plank")

-- infected death: the body rises with the inventory
state.infection = 1
inventory.add(invid, item.index("zomboid:chocolate"), 2)
survival.kill(pid, "infection")
check(state.dead, "dead")
check(inv.count(invid, "zomboid:chocolate") == 0, "inventory dropped")
app.tick()
check(zombies.count() == 1, "player zombie spawned")
log("death cause: " .. state.death.cause .. ", hours " .. string.format("%.2f", state.death.hours))

-- new character and persistence
local fresh = survival.new_character(pid, town.spawn_point(3))
check(not fresh.dead and fresh.health == 100, "respawned")
local hours = clock.hours
app.save_world()
app.close_world(true)
app.open_world("zplay")
survival = require "zomboid:survival"
clock = require "zomboid:clock"
require("zomboid:zombies").enabled = false
app.sleep(0.5)
check(math.abs(clock.hours - hours) < 0.2, "clock restored")
check(survival.get(pid).kills == 0 and not survival.get(pid).dead, "state restored")
app.close_world(false)
app.delete_world("zplay")
