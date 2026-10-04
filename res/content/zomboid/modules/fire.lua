local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local weather = require "zomboid:weather"
local zombies = require "zomboid:zombies"
local inv = require "zomboid:inv"

local fire = {
    MAX = 160,
    SPREAD_CHANCE = 0.07,
    SPREAD_RADIUS = 16,
    BURN_SECONDS = {20, 40},
    UNATTENDED_RADIUS = 10,
    UNATTENDED_CHANCE = 0.05,
    fires = {},
    count = 0,
    hot = {},
}

survival.CAUSES.fire = "Сгорел заживо"

local FLAMMABLE_MATERIALS = {["base:wood"] = true, ["base:carpet"] = true, ["base:grass"] = true}
local NEIGHBORS = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}

local function key(x, y, z)
    return x .. ":" .. y .. ":" .. z
end

function fire.is_flammable(id)
    if id <= 0 or block.has_tag(id, "zomboid:fire") or block.has_tag(id, "zomboid:heat") then
        return false
    end
    return FLAMMABLE_MATERIALS[block.material(id)] or block.has_tag(id, "zomboid:flammable")
end

function fire.burn(x, y, z, origin)
    if fire.count >= fire.MAX then
        return false
    end
    if not fire.is_flammable(block.get(x, y, z)) then
        return false
    end
    if block.is_segment(x, y, z) then
        x, y, z = block.seek_origin(x, y, z)
    end
    block.set(x, y, z, block.index("zomboid:fire"), 0)
    fire.track(x, y, z, origin)
    return true
end

function fire.track(x, y, z, origin)
    local k = key(x, y, z)
    if fire.fires[k] or block.name(block.get(x, y, z)) ~= "zomboid:fire" then
        return
    end
    fire.count = fire.count + 1
    fire.fires[k] = {age = 0, life = math.random(fire.BURN_SECONDS[1], fire.BURN_SECONDS[2]), origin = origin or {x, y, z}}
end

function fire.untrack(x, y, z)
    local k = key(x, y, z)
    if fire.fires[k] then
        fire.fires[k] = nil
        fire.count = fire.count - 1
    end
end

function fire.extinguish(x, y, z)
    if block.name(block.get(x, y, z)) == "zomboid:fire" then
        block.set(x, y, z, 0, 0)
        return true
    end
    return false
end

local function hurt_nearby(x, y, z)
    local center = {x + 0.5, y + 0.5, z + 0.5}
    for _, pid in ipairs(player.get_all_in_radius(center, 1.3)) do
        local state = survival.get(pid)
        if not state.dead then
            survival.damage(pid, 4, "fire")
            if math.random() < 0.3 then
                survival.notify(pid, "Вы горите!", "#ff6030")
            end
        end
    end
    for _, zombie in pairs(zombies.registry) do
        local zpos = zombie.get_pos()
        if vec3.distance(zpos, center) < 1.3 and not zombie.is_dead() then
            zombie.take_hit(6, 0, {zpos[1] + 1, zpos[2], zpos[3]})
        end
    end
end

function fire.update(x, y, z, tps)
    if block.name(block.get(x, y, z)) ~= "zomboid:fire" then
        fire.untrack(x, y, z)
        return
    end
    fire.track(x, y, z)
    local entry = fire.fires[key(x, y, z)]
    entry.age = entry.age + 1 / tps
    if weather.raining and weather.sky_open(x, y, z) and math.random() < 0.3 then
        block.set(x, y, z, 0, 0)
        return
    end
    hurt_nearby(x, y, z)
    if vc.is_client() and math.random() < 0.2 then
        audio.play_sound("world/fire", x + 0.5, y + 0.5, z + 0.5, 0.7, 0.8 + math.random() * 0.4)
    end
    local fuel = false
    local o = entry.origin
    for _, d in ipairs(NEIGHBORS) do
        local nx, ny, nz = x + d[1], y + d[2], z + d[3]
        if fire.is_flammable(block.get(nx, ny, nz)) then
            fuel = true
            if math.random() < fire.SPREAD_CHANCE
                and (nx - o[1]) ^ 2 + (ny - o[2]) ^ 2 + (nz - o[3]) ^ 2 <= fire.SPREAD_RADIUS ^ 2 then
                fire.burn(nx, ny, nz, o)
            end
        end
    end
    if entry.age >= entry.life or (not fuel and entry.age >= entry.life * 0.4) then
        block.set(x, y, z, 0, 0)
    end
end

function fire.heat(x, y, z, hours)
    fire.hot[key(x, y, z)] = clock.hours + hours
end

function fire.unattended(x, y, z)
    local k = key(x, y, z)
    local until_hours = fire.hot[k]
    if until_hours and until_hours < clock.hours then
        fire.hot[k], until_hours = nil, nil
    end
    if until_hours == nil and block.name(block.get(x, y, z)) ~= "zomboid:campfire" then
        return false
    end
    local center = {x + 0.5, y + 0.5, z + 0.5}
    if #player.get_all_in_radius(center, fire.UNATTENDED_RADIUS) > 0 or math.random() > fire.UNATTENDED_CHANCE then
        return false
    end
    for dx = -1, 1 do
        for dz = -1, 1 do
            for dy = 0, 1 do
                if fire.is_flammable(block.get(x + dx, y + dy, z + dz)) and fire.burn(x + dx, y + dy, z + dz) then
                    local pid = player.get_nearest(center)
                    if pid then
                        survival.notify(pid, "Где-то начался пожар!", "#ff6030")
                    end
                    return true
                end
            end
        end
    end
    return false
end

function fire.douse(pid, x, y, z)
    local itemid, _, invid, slot = inv.held(pid)
    local name = item.name(itemid)
    if name ~= "zomboid:water_bottle" and name ~= "zomboid:dirty_water_bottle" then
        survival.notify(pid, "Огонь тушат водой: возьмите бутылку с водой", "#ff9050")
        return false
    end
    local put_out = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            for dz = -1, 1 do
                if fire.extinguish(x + dx, y + dy, z + dz) then
                    put_out = put_out + 1
                end
            end
        end
    end
    if inventory.get_uses(invid, slot) <= 1 then
        inventory.set(invid, slot, item.index("zomboid:empty_bottle"), 1)
    else
        inventory.use(invid, slot)
    end
    survival.notify(pid, "Потушено очагов: " .. put_out, "#90c0ff")
    return true
end

return fire
