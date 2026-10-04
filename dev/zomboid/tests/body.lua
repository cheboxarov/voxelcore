-- Body systems: fridge, temperature, clothing, backpack and weight, mood, fractures, medicine, cooking
app.config_packs({"zomboid"})
app.new_world("zbody", "777", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local crafting = require "zomboid:crafting"
local loot = require "zomboid:loot"
local inv = require "zomboid:inv"
local gear = require "zomboid:gear"
local vitals = require "zomboid:vitals"
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
local invid, hslot = player.get_inventory(pid)

local function hold(name, count)
    inventory.set(invid, hslot, item.index(name), count or 1)
end

local function held_name()
    return item.name((inventory.get(invid, hslot)))
end

local function recipe(title)
    for i, r in ipairs(crafting.RECIPES) do
        if r.title == title then return i end
    end
    error("no recipe " .. title)
end

local function reset()
    state.health, state.hunger, state.thirst, state.energy, state.stamina = 100, 100, 100, 100, 100
    state.temp, state.temp_stage, state.wet, state.boredom, state.unhappiness = 36.6, 0, 0, 0, 0
    state.wounds, state.wound_infection, state.infection, state.fracture, state.sickness = {}, false, nil, nil, 0
end

local function find_outdoors()
    for r = 3, 30 do
        for _, d in ipairs({{r, 0}, {-r, 0}, {0, r}, {0, -r}}) do
            local x, z = math.floor(spawn[1]) + d[1], math.floor(spawn[3]) + d[2]
            local y = zombies.find_ground(x, z)
            local open = y ~= nil
            for dy = 0, 18 do
                if open and block.get(x, y + dy, z) ~= 0 then open = false end
            end
            if open then return x, y, z end
        end
    end
end

-- a <slot> also registers on* attributes as UI actions compiled as statements, so slot callbacks belong on slots-grid
for _, path in ipairs(file.list("zomboid:layouts")) do
    if path:sub(-4) == ".xml" then
        for tag in file.read(path):gmatch("<slot%s[^>]*>") do
            check(not tag:find("%son%a+="), path .. ": " .. tag)
        end
    end
end

-- starter clothes are worn
local ginv = gear.inventory(state)
check(item.name(inventory.get(ginv, 1)) == "zomboid:tshirt", "starter t-shirt")
check(item.name(inventory.get(ginv, 3)) == "zomboid:jeans", "starter jeans")
check(gear.warmth(state) == 4, "starter warmth " .. gear.warmth(state))

-- 1. fridge: food keeps much longer while the power is on, then spoils as usual
clock.reset(clock.START_HOUR)
local p = town.plan(0, 0)
local fx, fy, fz = p.x0 + p.mid - 1, G + 1, p.z0 + p.d - 2
check(block.name(block.get(fx, fy, fz)) == "zomboid:fridge", "fridge")
check(block.has_tag(block.get(fx, fy, fz), "zomboid:cold"), "fridge is cold")
local finv = inventory.get_block(fx, fy, fz)
inv.clear(finv)
local cinv = inventory.create(4)
local meat = item.index("zomboid:raw_meat")
inventory.set(finv, 0, meat, 1)
inventory.set(cinv, 0, meat, 1)
spoilage.check(finv, true)
spoilage.check(cinv, false)
clock.reset(clock.START_HOUR + 48)
spoilage.check(finv, true)
spoilage.check(cinv, false)
log(string.format("after 48h: fridge meat %.2f, crate meat %.2f", spoilage.ratio(finv, 0), spoilage.ratio(cinv, 0)))
check(inventory.get(cinv, 0) == item.index("zomboid:rotten_food") or spoilage.ratio(cinv, 0) >= 1, "warm meat spoiled")
check(inventory.get(finv, 0) == meat and spoilage.ratio(finv, 0) < 0.25, "fridge meat fresh")
-- taking it out keeps the saved freshness
inventory.move(finv, 0, cinv, 1)
spoilage.check(cinv, false)
check(inventory.get_data(cinv, 1, "cold") == nil, "cold mark cleared")
check(spoilage.ratio(cinv, 1) < 0.25, "freshness kept after taking out")
-- no power: the fridge is just a box
inventory.move(cinv, 1, finv, 0)
spoilage.check(finv, true)
clock.reset(24 * (require("zomboid:sandbox").get("power_shutoff_day") - 1) + 80)
spoilage.check(finv, true)
check(inventory.get(finv, 0) == item.index("zomboid:rotten_food"), "rots after the power cut")
-- generated fridge loot is chilled since the outbreak
inv.clear(finv)
clock.reset(clock.START_HOUR + 40)
for _ = 1, 20 do
    loot.fill(finv, "fridge", fx, fz, clock.START_HOUR)
end
local chilled = 0
for s = 0, inventory.size(finv) - 1 do
    if inventory.get_data(finv, s, "cold") then chilled = chilled + 1 end
end
check(chilled > 0, "fridge loot chilled: " .. chilled)
inv.clear(finv)
inventory.remove(cinv)

-- 2. temperature: night outdoors chills, fire warms, clothes heat up in the sun, rain soaks
reset()
local ox, oy, oz = find_outdoors()
check(ox, "outdoor spot")
player.set_pos(pid, ox + 0.5, oy + 0.9, oz + 0.5)
app.sleep(1)
check(state.indoors == false, "outdoors sensed")
clock.reset(24 + 2)
for _ = 1, 40 do survival.update(pid, 0.25, 0) end
log(string.format("night outside 10h: %.2f C, stage %d, health %.0f", state.temp, state.temp_stage, state.health))
check(state.temp < 35.5 and state.temp_stage <= -1, "cold at night")
state.temp = 34.0
local hp = state.health
survival.update(pid, 1, 0)
check(state.health < hp and state.last_cause == "cold", "hypothermia hurts")
-- a campfire next to the player
block.set(ox + 1, oy, oz, block.index("zomboid:campfire"), 0)
app.sleep(1)
check(state.heat, "campfire heat sensed")
local cold_temp = state.temp
for _ = 1, 8 do survival.update(pid, 0.25, 0) end
check(state.temp > cold_temp + 0.5, "campfire warms: " .. state.temp)
block.set(ox + 1, oy, oz, 0, 0)
app.sleep(1)
check(not state.heat, "fire removed")
-- full winter gear in the afternoon sun
reset()
clock.reset(24 + 15)
for _, name in ipairs({"zomboid:knit_hat", "zomboid:sweater", "zomboid:leather_jacket"}) do
    hold(name)
    events.emit(name .. ".use", pid)
end
check(gear.warmth(state) > 13, "dressed warm: " .. gear.warmth(state))
for _ = 1, 12 do survival.update(pid, 0.25, 0) end
log(string.format("afternoon in winter clothes 3h: %.2f C", state.temp))
check(state.temp > 37.5 and state.temp_stage >= 1, "overheating")
-- rain soaks through a jacket, a raincoat keeps you dry
reset()
vitals.rain = 1.0
for _ = 1, 4 do survival.update(pid, 0.25, 0) end
local wet_jacket = state.wet
state.wet = 0
hold("zomboid:raincoat")
events.emit("zomboid:raincoat.use", pid)
check(item.name(inventory.get(ginv, 2)) == "zomboid:raincoat", "raincoat on")
check(held_name() == "zomboid:leather_jacket", "jacket swapped back to the hand")
for _ = 1, 4 do survival.update(pid, 0.25, 0) end
log(string.format("1h in rain: wet %.0f in a jacket, %.0f in a raincoat", wet_jacket, state.wet))
check(wet_jacket > 50 and state.wet < wet_jacket / 3, "raincoat protects from rain")
vitals.rain = 0.0
hold("zomboid:leather_jacket")
events.emit("zomboid:leather_jacket.use", pid)

-- 3. clothing protects from wounds, gets dirty and torn, washes off
player.set_pos(pid, spawn[1], spawn[2], spawn[3])
app.sleep(1)
reset()
local blocked, got = 0, 0
local torn = false
math.randomseed(5)
for _ = 1, 300 do
    local before = #state.wounds
    survival.add_wound(pid, "scratch", true)
    if #state.wounds > before then got = got + 1 else blocked = blocked + 1 end
    if inventory.get(ginv, 2) == 0 then torn = true break end
end
log(string.format("scratches through clothes: %d wounds, %d blocked, jacket torn: %s", got, blocked, tostring(torn)))
check(blocked > 0, "clothes block some wounds")
check(torn, "jacket wears out")
check(gear.dirt(ginv, 1) > 0, "clothes get bloody")
local sweater_dirt = gear.dirt(ginv, 1)
inventory.set(invid, hslot, 0, 0)
inventory.move(ginv, 1, invid, hslot)
check(held_name() == "zomboid:sweater", "sweater in hand")
local cx, cz = town.cell_at(math.floor(spawn[1]), math.floor(spawn[3]))
local hp_ = town.plan(cx, cz)
local hx, hz = hp_.x0, hp_.z0
local sx, sy, sz = hx + 2, G + 1, hz + hp_.d - 2
check(block.name(block.get(sx, sy, sz)) == "zomboid:sink", "sink")
clock.reset(clock.START_HOUR)
events.emit("zomboid:sink.interact", sx, sy, sz, pid)
check(sweater_dirt > 0 and inventory.get_data(invid, hslot, "dirt") == 0, "sweater washed")
reset()
-- bites go through bare skin
gear.take_all(state)
for _ = 1, 5 do survival.add_wound(pid, "bite", true) end
check(#state.wounds == 5, "no clothes, no protection")
reset()
gear.dress(state)
ginv = gear.inventory(state)

-- 4. backpack and weight
inv.clear(invid)
hold("zomboid:school_bag")
events.emit("zomboid:school_bag.use", pid)
check(item.name(inventory.get(ginv, 5)) == "zomboid:school_bag", "backpack worn")
local view = gear.open_pack(state)
check(inventory.size(view) == 12, "12 backpack slots")
inventory.set(view, 0, item.index("zomboid:plank"), 10)
inventory.set(view, 1, item.index("zomboid:hiking_bag"), 1)
gear.sync_pack(state, view, pid)
check(inv.count(invid, "zomboid:hiking_bag") == 1, "no bag inside a bag")
local contents = inventory.get_data(ginv, 5, "contents")
check(contents and #contents == 1 and contents[1][2] == 10, "contents stored in the bag")
inventory.remove(view)
view = gear.open_pack(state)
check(inv.count(view, "zomboid:plank") == 10, "backpack reopens with contents")
-- with no room in the inventory a bag put into the pack is dropped, never stored inside
for slot = 0, inventory.size(invid) - 1 do
    inventory.set(invid, slot, item.index("zomboid:hiking_bag"), 1)
end
inventory.set(view, 1, item.index("zomboid:hiking_bag"), 1)
gear.sync_pack(state, view, pid)
for _, e in ipairs(inventory.get_data(ginv, 5, "contents")) do
    check(not item.properties[item.index(e[1])]["zomboid:slots"], "no bag inside a bag with a full inventory")
end
check(inventory.get(view, 1) == 0, "bag left the pack view")
inv.clear(invid)
inventory.remove(view)
local load = gear.load(pid, state)
log(string.format("load with 10 planks in the bag: %.1f kg", load))
check(load < 10, "backpack reduces carried weight")
inventory.add(invid, item.index("zomboid:plank"), 12)
state.load = gear.load(pid, state)
check(state.load > gear.capacity(state) * 1.5, "overloaded: " .. state.load)
check(survival.speed_factor(state) < 0.6, "overload slows")
check(not survival.can_sprint(state), "no sprinting overloaded")
state.traits = {"strong"}
check(gear.capacity(state) == gear.CAPACITY * 1.25, "strong characters carry more")
state.traits = nil
state.moving = true
state.stamina = 100
survival.update(pid, 0.001, 1.0)
check(state.stamina < 100, "walking overloaded drains stamina")
inv.clear(invid)
state.load = gear.load(pid, state)
check(survival.speed_factor(state) == 1.0, "normal speed unloaded")
-- dying drops worn clothes and the bag with its contents
local dropped
events.on("zomboid:player_died", function(_, _, items) dropped = items end)
survival.kill(pid, "zombies")
local names = {}
for _, e in ipairs(dropped or {}) do names[e[1]] = e end
check(names["zomboid:jeans"] and names["zomboid:school_bag"], "clothes dropped on death")
check(names["zomboid:school_bag"][3].contents[1][2] == 10, "bag keeps contents")
local old_gear = state.gear_inv
state = survival.new_character(pid, spawn)
check(old_gear == nil or not pcall(inventory.size, old_gear), "previous gear inventory freed")
old_gear = gear.inventory(state)
state = survival.new_character(pid, spawn)
check(not pcall(inventory.size, old_gear), "gear inventory of a replaced character freed")
app.sleep(1)
check(state.indoors, "indoors at the spawn")
ginv = gear.inventory(state)
check(inventory.get(ginv, 1) ~= 0, "new character dressed")

-- 5. boredom and unhappiness
reset()
inv.clear(invid)
for _ = 1, 24 do
    state.hunger, state.thirst, state.energy = 100, 100, 100
    survival.update(pid, 1, 0)
end
log(string.format("a day of idling indoors: boredom %.0f, unhappiness %.0f", state.boredom, state.unhappiness))
check(state.boredom > 50, "boredom grows")
check(state.unhappiness > 0, "boredom turns into unhappiness")
state.unhappiness = 90
check(vitals.stamina_mul(state) < 0.6 and not vitals.can_regen(state), "depression hurts")
local b0 = state.boredom
hold("zomboid:novel")
events.emit("zomboid:novel.use", pid)
check(state.boredom < b0 and state.unhappiness < 90, "reading helps")
check(inventory.get_uses(invid, hslot) == 3, "a chapter read")
local u0 = state.unhappiness
hold("zomboid:cigarettes")
events.emit("zomboid:cigarettes.use", pid)
check(state.unhappiness == u0, "no matches, no smoke")
inventory.set(invid, hslot + 1, item.index("zomboid:matches"), 1)
events.emit("zomboid:cigarettes.use", pid)
check(state.unhappiness < u0, "a cigarette calms")
u0 = state.unhappiness
state.hunger = 50
hold("zomboid:chocolate")
events.emit("zomboid:chocolate.use", pid)
check(state.unhappiness < u0, "tasty food cheers up")

-- 6. fracture from a fall, splint
reset()
inv.clear(invid)
player.set_pos(pid, ox + 0.5, oy + 0.9, oz + 0.5)
app.sleep(1)
local ty = oy + 9
block.set(ox, ty, oz, block.index("base:stone"), 0)
player.set_pos(pid, ox + 0.5, ty + 1.95, oz + 0.5)
app.sleep(1.5)
local _, py = player.get_pos(pid)
check(py > ty + 0.5, "standing on the pillar: " .. py)
block.set(ox, ty, oz, 0, 0)
app.sleep(3)
log(string.format("fell %d blocks: health %.0f, fracture %s", ty - oy, state.health, tostring(state.fracture ~= nil)))
check(state.health < 100, "fall damage")
check(state.fracture, "broken leg")
check(survival.speed_factor(state) < 0.6, "limping")
check(not survival.can_sprint(state), "cannot run on a broken leg")
inventory.add(invid, item.index("zomboid:plank"), 1)
inventory.add(invid, item.index("zomboid:rag"), 1)
check(crafting.craft(pid, recipe("Палки (2 шт.)")), "sticks")
check(crafting.craft(pid, recipe("Шина")), "splint crafted")
local splint_slot = inventory.find_by_item(invid, item.index("zomboid:splint"))
player.set_selected_slot(pid, splint_slot)
hslot = splint_slot
events.emit("zomboid:splint.use", pid)
check(state.fracture.splinted, "splint applied")
check(require("zomboid:skills").xp(pid, "first_aid") > 0, "splinting gives first aid xp")
check(inv.count(invid, "zomboid:splint") == 0, "splint used")
check(survival.speed_factor(state) > 0.7, "walks better with a splint")
for _ = 1, 40 do
    state.hunger, state.thirst, state.energy = 100, 100, 100
    clock.reset(clock.hours + 1)
    survival.update(pid, 1, 0)
end
check(state.fracture == nil, "fracture healed")
state.health = 100

-- 7. medicine: sterile vs dirty dressings, changing dressings, boiling
reset()
inv.clear(invid)
math.randomseed(11)
for _ = 1, 20 do
    state.wounds, state.wound_infection = {}, false
    table.insert(state.wounds, {kind = "laceration", bleeding = true, bandaged = false, time = clock.hours})
    hold("zomboid:bandage")
    events.emit("zomboid:bandage.use", pid)
    check(not state.wound_infection, "sterile bandage never infects")
end
local infected = 0
for _ = 1, 40 do
    state.wounds, state.wound_infection = {}, false
    table.insert(state.wounds, {kind = "laceration", bleeding = true, bandaged = false, time = clock.hours})
    hold("zomboid:dirty_rag")
    events.emit("zomboid:dirty_rag.use", pid)
    if state.wound_infection then infected = infected + 1 end
end
check(infected > 5, "dirty rags infect: " .. infected)
reset()
inv.clear(invid)
table.insert(state.wounds, {kind = "laceration", bleeding = true, bandaged = false, time = clock.hours})
hold("zomboid:bandage", 2)
events.emit("zomboid:bandage.use", pid)
state.wounds[1].dressed = clock.hours - 13
events.emit("zomboid:bandage.use", pid)
check(inv.count(invid, "zomboid:dirty_bandage") == 1, "old dressing removed dirty")
check(clock.hours - state.wounds[1].dressed < 1, "fresh dressing")
state.wounds[1].time = clock.hours - 20
survival.update(pid, 0.01, 0)
check(#state.wounds == 0 and inv.count(invid, "zomboid:dirty_bandage") == 2, "healed wound leaves a dirty bandage")
-- boiling needs a pot, water and a fire
inventory.add(invid, item.index("zomboid:cooking_pot"), 1)
inventory.add(invid, item.index("zomboid:water_bottle"), 1)
local boil = recipe("Прокипятить грязный бинт")
check(not crafting.craft(pid, boil), "no fire, no boiling")
local px, pyy, pz = player.get_pos(pid)
local fireX, fireY, fireZ = math.floor(px) + 1, math.floor(pyy - 0.85), math.floor(pz)
block.set(fireX, fireY, fireZ, block.index("zomboid:campfire"), 0)
check(crafting.craft(pid, boil), "boiled a bandage")
check(inv.count(invid, "zomboid:bandage") == 1 and inv.count(invid, "zomboid:dirty_bandage") == 1, "bandage sterile again")
local wslot = inventory.find_by_item(invid, item.index("zomboid:water_bottle"))
check(inventory.get_uses(invid, wslot) == 3, "a sip of water used")

-- 8. cooking: multi-ingredient dishes are more filling and keep longer
inventory.add(invid, item.index("zomboid:raw_meat"), 2)
inventory.add(invid, item.index("zomboid:potato"), 2)
inventory.add(invid, item.index("zomboid:carrot"), 2)
inventory.add(invid, item.index("zomboid:frying_pan"), 1)
check(crafting.craft(pid, recipe("Жареное мясо")), "fried meat")
check(crafting.craft(pid, recipe("Овощной суп")), "soup")
check(crafting.craft(pid, recipe("Рагу с мясом")), "stew")
check(inv.count(invid, "zomboid:cooked_meat") == 1 and inv.count(invid, "zomboid:soup") == 1
    and inv.count(invid, "zomboid:stew") == 1, "dishes cooked")
check(require("zomboid:skills").xp(pid, "cooking") > 0, "cooking gives cooking xp")
local P = function(name, key) return item.properties[item.index(name)][key] end
check(P("zomboid:stew", "zomboid:hunger") > P("zomboid:raw_meat", "zomboid:hunger") + P("zomboid:potato", "zomboid:hunger")
    + P("zomboid:carrot", "zomboid:hunger"), "stew is more filling than its ingredients")
check(P("zomboid:cooked_meat", "zomboid:spoil-days") > P("zomboid:raw_meat", "zomboid:spoil-days"), "cooked meat keeps longer")
block.set(fireX, fireY, fireZ, 0, 0)
check(not crafting.can_craft(invid, crafting.RECIPES[recipe("Жареное мясо")], pid), "fire is gone")
local sickness = state.sickness
state.hunger = 30
hold("zomboid:stew")
events.emit("zomboid:stew.use", pid)
check(state.hunger > 95 and state.sickness == sickness, "stew eaten")

-- 9. clothes and the bag survive save and load
-- a naked character stays naked after a reload, a character from a save before clothing gets dressed
gear.take_all(state)
gear.inventory(state)
survival.deserialize(json.parse(json.tostring(survival.serialize())))
state = survival.get(pid)
check(gear.warmth(state) == 0, "naked stays naked after reload")
local legacy = survival.serialize()
legacy[tostring(pid)].temp, legacy[tostring(pid)].gear = nil, nil
survival.deserialize(json.parse(json.tostring(legacy)))
state = survival.get(pid)
check(gear.warmth(state) == 4, "old save gets starter clothes")
reset()
inv.clear(invid)
gear.take_all(state)
gear.dress(state)
ginv = gear.inventory(state)
inventory.set(ginv, 5, item.index("zomboid:hiking_bag"), 1, {contents = {{"zomboid:canned_beans", 3}}})
inventory.set_data(ginv, 1, "dirt", 55)
app.save_world()
app.close_world(true)
app.open_world("zbody")
survival = require "zomboid:survival"
gear = require "zomboid:gear"
require("zomboid:zombies").enabled = false
app.sleep(0.5)
state = survival.get(pid)
ginv = gear.inventory(state)
check(item.name(inventory.get(ginv, 5)) == "zomboid:hiking_bag", "bag restored")
check(inventory.get_data(ginv, 5, "contents")[1][2] == 3, "bag contents restored")
check(inventory.get_data(ginv, 1, "dirt") == 55, "dirt restored")
check(state.temp and state.boredom, "body state restored")

app.close_world(false)
app.delete_world("zbody")
