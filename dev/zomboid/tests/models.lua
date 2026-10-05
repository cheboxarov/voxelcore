-- Models: zombie skins per kind, car body variants, item and block models with their textures
app.config_packs({"zomboid"})
app.new_world("zmodels", "5151", "zomboid:town")
app.set_setting("chunks.load-distance", 4)
app.set_setting("chunks.load-speed", 8)

local town = require "zomboid:town"
local zombies = require "zomboid:zombies"
local G = town.GROUND

local function log(...)
    print("[zomboid-test]", ...)
end

local function check(cond, msg)
    if not cond then
        error("check failed: " .. tostring(msg), 2)
    end
end

local function texture_exists(name)
    return file.exists("zomboid:textures/blocks/" .. name:gsub("^blocks:", "") .. ".png")
end

zombies.enabled = false
local pid = player.create("survivor")
require("zomboid:survival").get(pid).fresh = nil
local X, Z = 200, 200
player.set_pos(pid, X, G + 3, Z)
app.sleep_until(function() return block.get(X + 8, G, Z + 8) ~= -1 end, 20000)
for x = X - 8, X + 8 do for z = Z - 8, Z + 8 do
    block.set(x, G, z, block.index("zomboid:asphalt"))
    for y = G + 1, G + 4 do block.set(x, y, z, 0) end
end end

local src = file.read("zomboid:scripts/components/zombie.lua")
for _, list in ipairs({{"SHIRTS", "shirt"}, {"PANTS", "pants"}, {"HEADS", "head"}}) do
    local body = src:match("local " .. list[1] .. " = (%b{})")
    check(body, list[1] .. " list")
    local n = 0
    for name in body:gmatch('"([%w_]+)"') do
        check(texture_exists("z_" .. list[2] .. "_" .. name), list[2] .. " " .. name)
        n = n + 1
    end
    log(list[1], n)
end
local expect = {crawler = {pants = "torn"}, fat = {shirt = "tank"}, sprinter = {shirt = "sport", pants = "sport"}}
for kind, keys in pairs(expect) do
    for key, value in pairs(keys) do
        check(zombies.KINDS[kind][key] == value, kind .. " " .. key)
        check(texture_exists("z_" .. key .. "_" .. value), kind .. " " .. key .. " texture")
    end
end
local zombie_vcm = file.read("zomboid:models/zomboid_zombie.vcm")
for _, b in ipairs({"body", "head", "leg_left", "leg_right", "arm_left", "arm_right"}) do
    check(zombie_vcm:find("@bone name '" .. b .. "'", 1, true), "zombie bone " .. b)
end
for _, key in ipairs({"$shirt", "$pants", "$head"}) do
    check(zombie_vcm:find('"' .. key .. '"', 1, true), "zombie texture slot " .. key)
end
local vcms = file.list("zomboid:models")
check(#vcms >= 20, "model files " .. #vcms)
for _, name in ipairs(vcms) do
    local text = file.read(name)
    for tex in text:gmatch('texture "blocks:([%w_]+)"') do
        check(texture_exists(tex), name .. " uses missing " .. tex)
    end
    for u1, v1, u2, v2 in text:gmatch("region %(([%d.]+),([%d.]+),([%d.]+),([%d.]+)%)") do
        for _, v in ipairs({u1, v1, u2, v2}) do
            check(tonumber(v) >= 0 and tonumber(v) <= 1, name .. " region out of texture")
        end
    end
end
local car_src = file.read("zomboid:scripts/components/car.lua")
for color in car_src:match("local COLORS = (%b{})"):gmatch('"([%w_]+)"') do
    check(texture_exists("car_" .. color), "car color " .. color)
end

local bodies = {}
for i = 1, 12 do
    local e = entities.spawn("zomboid:car", {X - 6 + (i % 4) * 4 + 0.5, G + 1.8, Z - 6 + math.floor(i / 4) * 5 + 0.5})
    local car = e:get_component("zomboid:car")
    local body = car.data.body
    check(body == "sedan" or body == "pickup", "car body " .. tostring(body))
    bodies[body] = (bodies[body] or 0) + 1
    e:despawn()
end
log("bodies", bodies.sedan, bodies.pickup)
check(bodies.sedan and bodies.pickup, "both car bodies occur")
check(texture_exists("car_parts"), "car part textures")

for _, name in ipairs({"bat", "spiked_bat", "axe", "knife", "crowbar", "hammer", "frying_pan", "spear", "pistol",
                       "shotgun", "flashlight", "gas_can"}) do
    local model = item.model_name(item.index("zomboid:" .. name))
    check(model == "zomboid_item_" .. name, name .. " model " .. tostring(model))
    check(file.exists("zomboid:models/" .. model .. ".vcm"), model .. " file")
end
check(item.model_name(item.index("zomboid:gas_can_empty")) == "zomboid_item_gas_can", "empty can shares the model")

for _, name in ipairs({"generator", "rain_barrel", "fuel_pump", "alarm_clock", "siren", "campfire", "bed", "couch", "tv"}) do
    local id = block.index("zomboid:" .. name)
    check(block.get_model(id) == "custom", name .. " custom model")
    check(file.exists("zomboid:models/zomboid_block_" .. name .. ".vcm"), name .. " model file")
end
for _, paint in ipairs({"red", "blue", "white", "police", "army", "burnt"}) do
    check(file.exists("zomboid:models/zomboid_car_wreck_" .. paint .. ".vcm"), "wreck " .. paint)
end
local pump_box = block.get_hitbox(block.index("zomboid:fuel_pump"), 0)
check(pump_box[2][2] == 2, "fuel pump hitbox keeps both segments " .. pump_box[2][2])
local gen = block.index("zomboid:generator")
check(block.get_model(gen, 1) == "custom", "generator 'on' variant keeps the model")
log("models ok")
app.close_world(false)
