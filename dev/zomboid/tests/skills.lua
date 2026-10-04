-- Skills, books, professions, traits and sandbox settings
app.config_packs({"zomboid"})
app.new_world("zskills", "2024", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local inv = require "zomboid:inv"
local sandbox = require "zomboid:sandbox"
local skills = require "zomboid:skills"
local character = require "zomboid:character"
local weapons = require "zomboid:weapons"
local G = town.GROUND

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local function near(a, b)
    return math.abs(a - b) < 1e-6
end

zombies.enabled = false
check(not sandbox.configured, "fresh world is not configured")
check(sandbox.get("water_shutoff_day") == 5 and sandbox.get("zombie_density") == 1.0, "sandbox defaults")
check(not pcall(sandbox.get, "no_such_option"), "unknown option rejected")

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
check(state.setup, "new character waits for profession")

local function hold(name, count)
    inventory.set(invid, slot, item.index(name), count or 1)
end

-- trait validation
check(select(2, character.balance("police", {"strong"})), "not enough points")
check(select(2, character.balance("unemployed", {"strong", "weak"})), "opposite traits rejected")
check(select(2, character.balance("unemployed", {"strong", "strong"})), "duplicate rejected")
check(select(2, character.balance("unemployed", {"nope"})), "unknown trait rejected")
check(select(2, character.balance("pilot", {})), "unknown profession rejected")
check(character.balance("unemployed", {"strong", "fast_learner", "clumsy"}) == 1, "points balance")
check(not character.apply(pid, "doctor", {"strong"}), "apply refuses a negative balance")
check(state.setup and state.profession == nil, "nothing applied on refusal")

-- profession and traits
inv.clear(invid)
check(character.apply(pid, "carpenter", {"fast_learner", "handy", "slow_learner"}) == false, "opposites refused by apply")
check(character.apply(pid, "carpenter", {"handy", "clumsy", "short_sighted"}), "carpenter created")
check(not character.apply(pid, "police", {}), "apply runs once")
check(skills.level(pid, "carpentry") == 4 and skills.level(pid, "melee") == 1, "profession + trait levels")
check(inv.count(invid, "zomboid:hammer") == 1 and inv.count(invid, "zomboid:nails") == 12, "carpenter kit")
check(near(skills.mul(pid, "noise"), 1.5), "clumsy is louder: " .. skills.mul(pid, "noise"))
check(near(skills.mul(pid, "barricade_hp"), 1.4 * 1.15), "carpentry + handy barricade bonus")

-- XP curve and level-ups
skills.set_level(pid, "melee", 0)
skills.add_xp(pid, "melee", 74)
check(skills.level(pid, "melee") == 0, "below the first threshold")
skills.add_xp(pid, "melee", 1)
check(skills.level(pid, "melee") == 1, "level 1 at 75 xp")
skills.add_xp(pid, "melee", 100000)
check(skills.level(pid, "melee") == 10 and skills.progress(pid, "melee") == 1, "capped at 10")
skills.set_level(pid, "melee", 2)
check(near(skills.mul(pid, "melee_damage"), 1.12), "melee damage bonus")

-- books: reading takes time and multiplies XP inside the level window
skills.set_level(pid, "cooking", 0)
hold("zomboid:book_cooking_1")
events.emit("zomboid:book_cooking_1.use", pid)
check(state.reading, "started reading")
local steps = 0
while state.reading and steps < 400 do
    skills.update(pid, 0.01, 0.05)
    steps = steps + 1
end
log("book read in " .. steps * 0.01 .. " game hours")
check(not state.reading and state.books.cooking_1, "book finished")
check(inventory.get_data(invid, slot, "read") == 1, "progress stored in the book")
check(near(skills.add_xp(pid, "cooking", 10), 30), "x3 with volume 1")
events.emit("zomboid:book_cooking_1.use", pid)
check(not state.reading, "a read book is not read twice")
skills.set_level(pid, "cooking", 5)
check(near(skills.add_xp(pid, "cooking", 10), 10), "volume 1 does not help past its window")
hold("zomboid:book_melee_1")
events.emit("zomboid:book_melee_1.use", pid)
hold("zomboid:bat")
skills.update(pid, 0.01, 0.05)
check(not state.reading, "switching items interrupts reading")

-- XP through the existing actions
local function gained(skill, fn)
    local xp = skills.xp(pid, skill)
    fn()
    return skills.xp(pid, skill) - xp
end

local cx, cz = math.floor(spawn[1] / 32), math.floor(spawn[3] / 32)
local p = town.plan(cx, cz)
local ox, oz = cx * 32 + p.x0, cz * 32 + p.z0
local wx
for x = ox + 1, ox + p.w - 2 do
    if block.name(block.get(x, G + 1, oz)) == "zomboid:window" then wx = x break end
end
check(wx, "window")
inventory.add(invid, item.index("zomboid:plank"), 1)
check(gained("carpentry", function()
    hold("zomboid:hammer")
    events.emit("zomboid:hammer.useon", wx, G + 1, oz, pid, {0, 0, -1})
end) > 0, "barricading trains carpentry")
check(block.get_field(wx, G + 1, oz, "hp") == math.floor(25 * skills.mul(pid, "barricade_hp")), "stronger plank")

survival.add_wound(pid, "scratch")
state.health = 50
check(gained("first_aid", function()
    hold("zomboid:bandage")
    events.emit("zomboid:bandage.use", pid)
end) > 0, "bandaging trains first aid")
state.wounds, state.infection = {}, nil

local stx, sty, stz = ox + 3, G + 1, oz + p.d - 2
if block.name(block.get(stx, sty, stz)) == "zomboid:stove" then
    check(gained("cooking", function()
        hold("zomboid:dirty_water_bottle")
        events.emit("zomboid:stove.interact", stx, sty, stz, pid)
    end) > 0, "boiling water trains cooking")
end

local ppos = {player.get_pos(pid)}
local z = zombies.spawn(math.floor(ppos[1]) + 1, math.floor(ppos[2]), math.floor(ppos[3]), {})
check(gained("melee", function()
    hold("zomboid:bat")
    check(weapons.attack(pid, z:get_component("zomboid:zombie").get_pos()), "hit landed")
end) > 0, "hitting trains melee")
z:despawn()
app.tick()

state.crouching, state.moving = true, true
check(gained("sneaking", function()
    for _ = 1, 20 do skills.update(pid, 0, 0.05) end
end) > 0, "sneaking trains sneaking")
state.crouching, state.moving = false, false

-- traits change survival rates
local hunger_before = state.hunger
survival.update(pid, 1.0, 0.05)
local plain = hunger_before - state.hunger
state.traits = {"hearty_appetite"}
hunger_before = state.hunger
survival.update(pid, 1.0, 0.05)
check(near((hunger_before - state.hunger) / plain, 1.3), "hearty appetite")

-- sandbox settings drive the world and survive a reload
sandbox.save({zombie_density = 2.5, water_shutoff_day = 2, day_minutes = 48, hunger_rate = 1.5})
check(sandbox.configured and zombies.limit() == 85, "zombie cap follows density: " .. zombies.limit())
check(near(world.get_day_time_speed(), 0.5), "day length applied")
clock.reset(24 + 10)
local sx, sy, sz = ox + 2, G + 1, oz + p.d - 2
check(block.name(block.get(sx, sy, sz)) == "zomboid:sink", "sink")
hold("zomboid:empty_bottle")
events.emit("zomboid:sink.interact", sx, sy, sz, pid)
check(item.name((inventory.get(invid, slot))) == "zomboid:empty_bottle", "water off on day 2")

local carpentry = skills.xp(pid, "carpentry")
app.save_world()
app.close_world(true)
app.open_world("zskills")
sandbox = require "zomboid:sandbox"
survival = require "zomboid:survival"
skills = require "zomboid:skills"
require("zomboid:zombies").enabled = false
app.sleep(0.5)
check(sandbox.configured and sandbox.get("water_shutoff_day") == 2 and sandbox.get("zombie_density") == 2.5,
    "sandbox restored")
check(near(world.get_day_time_speed(), 0.5), "day length restored")
check(near(skills.xp(pid, "carpentry"), carpentry), "skills restored")
check(survival.get(pid).profession == "carpenter" and survival.get(pid).books.cooking_1, "character restored")
log("carpentry", skills.level(pid, "carpentry"), "melee", skills.level(pid, "melee"))
app.close_world(false)
app.delete_world("zskills")
