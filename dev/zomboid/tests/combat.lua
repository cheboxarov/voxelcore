-- Zombie kinds, noise marks and district pull, world crowds and roamers, noise devices, firearms, stealth kills and shoves
app.config_packs({"zomboid"})
app.new_world("zcombat", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 5)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local noise = require "zomboid:noise"
local population = require "zomboid:population"
local firearms = require "zomboid:firearms"
local combat = require "zomboid:combat"
local weapons = require "zomboid:weapons"
local clock = require "zomboid:clock"
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
local ROAD_X = 2.5
local home = {ROAD_X, G + 1.95, -20.5}
player.set_pos(pid, home[1], home[2], home[3])
app.sleep_until(function()
    return block.get(2, G, -76) ~= -1 and block.get(2, G, 30) ~= -1 and block.get(60, G, -20) ~= -1
end, 10000)
app.sleep(1)
local state = survival.get(pid)
local invid, slot = player.get_inventory(pid)

local function reset_player()
    player.set_pos(pid, home[1], home[2], home[3])
    player.set_vel(pid, 0, 0, 0)
    state.health, state.stamina, state.wounds, state.infection = 100, 100, {}, nil
    state.grabbed_until = nil
end

local function clear_zombies()
    for _, e in pairs(entities.get_all()) do
        if e:def_name() == "zomboid:zombie" then
            e:despawn()
        end
    end
    app.tick()
    app.tick()
    check(zombies.count() == 0, "zombies cleared")
end

local function spawn_at(x, z, args)
    local y = zombies.find_ground(math.floor(x), math.floor(z))
    check(y, "ground at " .. x .. "," .. z)
    local e = zombies.spawn(math.floor(x), y, math.floor(z), args or {})
    return e, e:get_component("zomboid:zombie")
end

local function hold(name, count)
    inventory.set(invid, slot, item.index(name), count or 1)
end

-- kinds: hitbox, size, speed and health differ
local kinds = {}
for i, name in ipairs({"normal", "crawler", "fat", "sprinter"}) do
    local e, comp = spawn_at(ROAD_X, -40 - i * 4, {kind = name})
    kinds[name] = {e = e, comp = comp}
end
app.sleep(1)
for name, k in pairs(kinds) do
    local size = k.e.rigidbody:get_size()
    local scale = k.e.transform:get_size()
    local data = k.comp.SAVED_DATA
    log(string.format("%s: hp %d hitbox %.2f scale %.2f speed %.1f", name, data.max_health, size[2] * scale[2],
        scale[1], k.e:get_component("core:mob").get_movement_speed()))
    check(k.comp.get_kind() == name, "kind " .. name)
end
local function height(k) return kinds[k].e.rigidbody:get_size()[2] * kinds[k].e.transform:get_size()[2] end
check(height("crawler") < 0.7, "crawler is low")
check(kinds.fat.e.transform:get_size()[1] > 1.2, "fat is wide")
check(kinds.fat.comp.SAVED_DATA.max_health >= 170, "fat is a tank")
check(kinds.crawler.e:get_component("core:mob").get_movement_speed() < 10, "crawler is slow")
check(kinds.sprinter.comp.SAVED_DATA.shirt == "sport", "athlete shirt")
local crawler = kinds.crawler.comp
local cpos = crawler.get_pos()
check(cpos[2] - (G + 1) < 0.5, "crawler lies on the ground: " .. cpos[2])
clear_zombies()

-- a fat zombie breaks into a house faster than a normal one
local hp_ = town.plan(0, -1)
local ox, oz = hp_.x0, -32 + hp_.z0
local dx, dy = ox + hp_.door, G + 1
local door_id, door_state = block.get(dx, dy, oz), block.get_states(dx, dy, oz)
check(block.name(door_id) == "base:wooden_door", "front door")
local function break_in(kind)
    block.set(dx, dy, oz, door_id, door_state)
    player.set_pos(pid, ox + hp_.mid + 0.5, G + 1.95, oz + hp_.split + 0.5)
    local _, z = spawn_at(dx + 0.5, oz - 4.5, {kind = kind})
    for i = 1, 160 do
        z.hear({player.get_pos(pid)}, pid, 5)
        state.health = 100
        app.sleep(0.25)
        if z.get_pos()[3] > oz + 0.5 then
            clear_zombies()
            return i * 0.25
        end
    end
    clear_zombies()
    return math.huge
end
local t_normal, t_fat = break_in("normal"), break_in("fat")
log(string.format("break-in: normal %.1fs, fat %.1fs", t_normal, t_fat))
check(t_fat < t_normal, "fat zombie bashes through faster")
block.set(dx, dy, oz, door_id, door_state)

-- crawler grabs the legs and slows the player down
reset_player()
local _, grabber = spawn_at(ROAD_X, -24.5, {kind = "crawler"})
grabber.hear({player.get_pos(pid)}, pid, 4)
app.sleep_until(function() return combat.is_grabbed(state) end, 400)
check(combat.is_grabbed(state), "crawler grabbed the player")
check(state.health < 100, "crawler bit the player")
log(string.format("grabbed, health %.1f", state.health))
check(combat.push(pid) >= 0 and not combat.is_grabbed(state), "push breaks the grab")
clear_zombies()

-- noise marks: a loud mark attracts, a quiet distant one does not, audibility fades
reset_player()
player.set_pos(pid, ROAD_X, home[2], 25.5)
local _, far = spawn_at(ROAD_X, -60.5)
local _, near = spawn_at(ROAD_X, -36.5)
app.sleep(0.5)
local quiet = noise.emit({ROAD_X, G + 1, -20}, 10)
app.sleep(0.5)
check(far.mode ~= "investigate" and near.mode ~= "investigate", "quiet noise unheard")
check(noise.audibility(quiet, {ROAD_X, G + 1, -20}) > noise.audibility(quiet, {ROAD_X, G + 1, -20}, time.uptime() + 2.5),
    "noise fades")
noise.emit({ROAD_X, G + 1, -20}, 50, pid)
app.sleep(0.5)
log("after a loud noise: far " .. far.mode .. ", near " .. near.mode)
check(far.mode == "investigate" and near.mode == "investigate", "loud noise heard")
check(math.abs(far.goal[3] + 20) < 1, "zombie goes to the noise")
clear_zombies()

-- district pull: a loud mark brings more zombies from afar
local mark = noise.emit({ROAD_X, G + 1, -20}, 90, pid)
local pulled = population.pull(mark, {player.get_pos(pid)})
app.tick()
local heading = 0
for _, z in pairs(zombies.registry) do
    if z.mode == "investigate" then heading = heading + 1 end
end
log("pulled from the district: " .. pulled .. ", heading to the noise: " .. heading)
check(pulled >= 3 and heading == pulled, "district pull")
clear_zombies()

-- world population: a crowd stands at a house, roamers walk the streets
local cx, cz = 1, -1
check(town.plan(cx, cz), "house lot for a crowd")
local n = population.seed_cell(cx, cz)
app.tick()
check(population.seeded[cx .. ":" .. cz] == clock.day(), "cell marked as seeded")
local crowd, roamers = {}, {}
for _, z in pairs(zombies.registry) do
    local d = z.SAVED_DATA
    check(d.resident, "resident zombie")
    table.insert(d.anchor and crowd or roamers, z)
end
log(string.format("seeded %d: crowd %d, roamers %d", n, #crowd, #roamers))
check(#crowd >= 2, "crowd at the house")
local _, roamer = spawn_at(34.5, -12.5, {route = true, resident = true})
app.tick()
local roam_start = roamer.get_pos()
app.sleep(12)
for _, z in ipairs(crowd) do
    local a = z.SAVED_DATA.anchor
    check(math.abs(z.get_pos()[1] - a[1]) < 7 and math.abs(z.get_pos()[3] - a[3]) < 7, "crowd keeps to its spot")
end
local rp = roamer.get_pos()
local lane = town.column(math.floor(rp[1]), math.floor(rp[3]))
log(string.format("roamer %s moved %.1f, on %s", roamer.mode, vec3.distance(rp, roam_start), lane))
check(roamer.mode == "roam" and vec3.distance(rp, roam_start) > 6, "roamer walks")
check(lane == "road" or lane == "sidewalk", "roamer keeps to the streets")
clear_zombies()
zombies.enabled = true
population.seeded = {}
for _ = 1, 40 do app.tick() end
zombies.enabled = false
local seeded = table.count_pairs(population.seeded)
log("cells seeded by the tick: " .. seeded .. ", zombies " .. zombies.count())
check(seeded > 0 and zombies.count() > 0, "tick seeds nearby cells")
clear_zombies()

-- noise devices: an alarm clock distracts zombies, then falls silent
reset_player()
local ax, ay, az = 2, G + 1, -40
block.set(ax, ay, az, block.index("zomboid:alarm_clock"), 0)
events.emit("zomboid:alarm_clock.placed", ax, ay, az, pid)
local ring_at = block.get_field(ax, ay, az, "ring_at")
check(ring_at and ring_at > clock.hours, "alarm armed")
local _, lured = spawn_at(ROAD_X, -62.5)
app.sleep(1)
check(lured.mode ~= "investigate", "silent before the timer")
block.set_field(ax, ay, az, "ring_at", clock.hours)
app.sleep_until(function() return lured.mode == "investigate" end, 100)
log("alarm: zombie " .. lured.mode .. " goal z " .. tostring(lured.goal and lured.goal[3]))
check(lured.mode == "investigate" and math.abs(lured.goal[3] - az - 0.5) < 1, "alarm lures zombies")
block.set_field(ax, ay, az, "ring_at", clock.hours - 1)
app.sleep(1.5)
check(block.get_field(ax, ay, az, "ring_at") == 0, "alarm stops")
block.set(ax, ay, az, 0, 0)
inventory.add(invid, item.index("zomboid:alarm_clock.item"), 1)
inventory.add(invid, item.index("zomboid:flashlight"), 1)
inventory.add(invid, item.index("zomboid:nails"), 2)
inventory.add(invid, item.index("zomboid:hammer"), 1)
local crafting = require "zomboid:crafting"
local siren_recipe
for i, r in ipairs(crafting.RECIPES) do
    if r.result[1] == "zomboid:siren.item" then siren_recipe = i end
end
check(crafting.craft(pid, siren_recipe), "siren crafted")
check(inv.count(invid, "zomboid:siren.item") == 1, "siren in inventory")
clear_zombies()

-- firearms: reload, shoot, empty magazine, the shot is heard far away
reset_player()
local dir = player.get_dir(pid)
local flat = vec3.normalize({dir[1], 0, dir[3]})
log(string.format("aim %.2f %.2f %.2f", dir[1], dir[2], dir[3]))
hold("zomboid:pistol")
check(not firearms.fire(pid), "unloaded pistol does not fire")
inventory.add(invid, item.index("zomboid:ammo_9mm"), 20)
check(firearms.reload(pid), "reload started")
app.sleep(2)
check(firearms.loaded(invid, slot) == 15 and inv.count(invid, "zomboid:ammo_9mm") == 5, "magazine loaded")
local tx, tz = home[1] + flat[1] * 7, home[3] + flat[3] * 7
local _, target = spawn_at(tx, tz)
local _, listener = spawn_at(ROAD_X, -82.5)
app.sleep(0.3)
target.SAVED_DATA.health = 1000
local hp0 = target.SAVED_DATA.health
local shots, hits = 0, 0
for _ = 1, 5 do
    local tp = target.get_pos()
    player.set_pos(pid, tp[1] - flat[1] * 7, home[2], tp[3] - flat[3] * 7)
    local ok, h = firearms.fire(pid)
    if ok then shots = shots + 1 hits = hits + (h or 0) end
    app.sleep(0.4)
    state.health = 100
end
log(string.format("pistol: %d shots, %d hits, zombie hp %d -> %d, rounds left %d", shots, hits, hp0,
    target.SAVED_DATA.health, firearms.loaded(invid, slot)))
check(shots == 5 and firearms.loaded(invid, slot) == 10, "rounds spent")
check(hits >= 3 and target.SAVED_DATA.health < hp0, "bullets hit")
check(listener.mode == "investigate" or listener.mode == "chase", "gunshot heard 60 blocks away")
check(weapons.attack(pid, target.get_pos()) == nil, "no melee with a gun")
hold("zomboid:shotgun")
inventory.set_data(invid, slot, "ammo", 2)
target.SAVED_DATA.health = 1000
local tp = target.get_pos()
player.set_pos(pid, tp[1] - flat[1] * 3, home[2], tp[3] - flat[3] * 3)
local _, pellets = firearms.fire(pid)
log("shotgun pellets hit: " .. tostring(pellets))
check(pellets and pellets >= 3, "shotgun spread hits")
clear_zombies()

-- stealth: a blow from behind kills an unaware zombie, an aware one survives
reset_player()
hold("zomboid:knife")
local e, victim = spawn_at(ROAD_X, -30.5)
app.tick()
local vp = victim.get_pos()
local facing = e:get_component("core:mob").get_dir()
player.set_pos(pid, vp[1] - facing[1] * 1.4, vp[2] + 0.1, vp[3] - facing[3] * 1.4)
entities.get(player.get_entity(pid)).rigidbody:set_crouching(true)
check(victim.is_unaware_of(pid), "zombie does not notice the sneaking player")
victim.on_attacked(player.get_entity(pid), pid)
check(victim.is_dead(), "silent kill from behind")
app.sleep(1)
local _, aware = spawn_at(ROAD_X, -30.5)
aware.hear({player.get_pos(pid)}, pid, 1)
aware.mode = "chase"
aware.SAVED_DATA.health = 60
local ap = aware.get_pos()
player.set_pos(pid, ap[1], ap[2] + 0.1, ap[3] + 1.4)
app.sleep(1)
aware.on_attacked(player.get_entity(pid), pid)
check(not aware.is_dead(), "aware zombie survives a knife hit")
entities.get(player.get_entity(pid)).rigidbody:set_crouching(false)
clear_zombies()

-- shove: knocks a zombie down without damage, costs stamina; a fat one stays on its feet
reset_player()
hold("zomboid:bat")
local px, py, pz = player.get_pos(pid)
local _, pushed = spawn_at(px + flat[1] * 1.3, pz + flat[3] * 1.3)
app.tick()
local hp = pushed.SAVED_DATA.health
state.stamina = 100
check(combat.push(pid) == 1, "one zombie shoved")
check(pushed.is_downed(), "zombie knocked down")
check(pushed.SAVED_DATA.health == hp, "shove deals no damage")
check(state.stamina == 100 - combat.PUSH_STAMINA, "shove costs stamina")
app.sleep(3)
check(not pushed.is_downed(), "zombie gets up")
clear_zombies()
reset_player()
local _, tank = spawn_at(px + flat[1] * 1.3, pz + flat[3] * 1.3, {kind = "fat"})
app.tick()
app.sleep(1)
check(combat.push(pid) == 1 and not tank.is_downed(), "fat zombie is not knocked down")
clear_zombies()

-- kinds and seeded cells survive a save
reset_player()
spawn_at(ROAD_X, -27.5, {kind = "fat"})
population.seeded = {["1:-1"] = clock.day()}
app.tick()
app.save_world()
app.close_world(true)
app.open_world("zcombat")
zombies = require "zomboid:zombies"
zombies.enabled = false
app.sleep_until(function() return zombies.count() > 0 end, 2000)
local restored
for _, e in pairs(entities.get_all()) do
    if e:def_name() == "zomboid:zombie" then
        restored = e
    end
end
check(restored and restored:get_component("zomboid:zombie").get_kind() == "fat", "fat zombie restored")
check(restored.transform:get_size()[1] > 1.2, "fat size restored")
check(require("zomboid:population").seeded["1:-1"] ~= nil, "seeded cells restored")

app.close_world(false)
app.delete_world("zcombat")
