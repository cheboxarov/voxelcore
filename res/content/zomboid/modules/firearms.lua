local inv = require "zomboid:inv"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local barricade = require "zomboid:barricade"
local skills = require "zomboid:skills"
local combat = require "zomboid:combat"

local firearms = {}

local next_shot = {}
local reloading = {}

local function sound(name, pos, volume)
    if vc.is_client() then
        audio.play_sound(name, pos[1], pos[2], pos[3], volume or 1.0, 0.92 + math.random() * 0.16)
    end
end

function firearms.gun(itemid)
    local props = itemid ~= 0 and item.properties[itemid]
    return props and props["zomboid:gun"]
end

function firearms.loaded(invid, slot)
    return inventory.get_data(invid, slot, "ammo") or 0
end

function firearms.is_reloading(pid)
    return reloading[pid] ~= nil
end

local function scatter(dir, spread)
    local out
    repeat
        out = {math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1}
    until vec3.length(out) <= 1
    return vec3.normalize(vec3.add(dir, vec3.mul(out, spread)))
end

local function spread_of(pid, gun)
    local state = survival.get(pid)
    local vx, _, vz = player.get_vel(pid)
    local spread = gun.spread * skills.mul(pid, "gun_spread")
    if state.sprinting then
        spread = spread * 2.5
    elseif vx * vx + vz * vz > 1 then
        spread = spread * 1.8
    end
    if state.crouching then
        spread = spread * 0.6
    end
    return spread
end

local function hit_zombie(hit, eye, gun, pid)
    local e = entities.get(hit.entity)
    local z = e and e:get_component("zomboid:zombie")
    if z == nil or z.is_dead() then
        return false
    end
    local zp = z.get_pos()
    local dist = vec3.distance(eye, hit.endpoint)
    local damage = gun.damage * (1 - 0.5 * math.min(1, dist / gun.range))
    if z.get_kind() ~= "crawler" and hit.endpoint[2] > zp[2] + 0.5 * e.transform:get_size()[2] then
        damage = damage * 2.5
    end
    z.take_hit(damage, gun.knockback, eye, pid)
    return true
end

function firearms.fire(pid)
    local state = survival.get(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local gun = firearms.gun(itemid)
    local now = time.uptime()
    if gun == nil or state.dead or state.sleeping or reloading[pid] or (next_shot[pid] or 0) > now then
        return false
    end
    local x, y, z = player.get_pos(pid)
    local ppos = {x, y, z}
    local loaded = firearms.loaded(invid, slot)
    next_shot[pid] = now + gun.cooldown
    if loaded <= 0 then
        sound("player/dry_fire", ppos, 0.7)
        survival.notify(pid, "Пусто. R - перезарядить", "#ff9050")
        return false
    end
    inventory.set_data(invid, slot, "ammo", loaded - 1)
    local eye = {x, y + 0.7, z}
    local dir = player.get_dir(pid)
    local spread = spread_of(pid, gun)
    local ignore = player.get_entity(pid)
    local hits = 0
    for _ = 1, gun.pellets or 1 do
        local hit = entities.raycast(eye, scatter(dir, spread), gun.range, ignore)
        if hit and hit.entity then
            if hit_zombie(hit, eye, gun, pid) then
                hits = hits + 1
            end
        elseif hit and hit.block and hit.block > 0 and block.has_tag(hit.block, "zomboid:glass") then
            local p = hit.iendpoint
            barricade.bash(p[1], p[2], p[3], 100)
        end
    end
    if hits > 0 then
        skills.add_xp(pid, "aiming", 3 * hits)
    end
    zombies.noise(ppos, gun.noise, pid, 8)
    sound(gun.sound, ppos)
    if vc.is_client() then
        gfx.particles.emit(vec3.add(eye, vec3.mul(dir, 0.8)), 6, {
            lifetime = 0.08, spawn_interval = 0.0001, explosion = {0.5, 0.5, 0.5},
            texture = "blocks:z_shirt_police", size = {0.06, 0.06, 0.06}, lighting = false,
        })
    end
    if hits > 0 then
        combat.xp(pid, "aiming", 4 * hits)
    end
    return true, hits
end

function firearms.reload(pid)
    local state = survival.get(pid)
    local itemid, _, invid, slot = inv.held(pid)
    local gun = firearms.gun(itemid)
    if gun == nil or state.dead or reloading[pid] then
        return false
    end
    if firearms.loaded(invid, slot) >= gun.mag then
        survival.notify(pid, "Оружие уже заряжено")
        return false
    end
    if inv.count(invid, gun.ammo) == 0 then
        survival.notify(pid, "Нет патронов: " .. item.caption(item.index(gun.ammo)), "#ff9050")
        return false
    end
    reloading[pid] = {done = time.uptime() + gun.reload, itemid = itemid, slot = slot}
    sound("player/reload", {player.get_pos(pid)}, 0.8)
    return true
end

function firearms.update(pid)
    local r = reloading[pid]
    if r == nil or time.uptime() < r.done then
        return
    end
    reloading[pid] = nil
    local itemid, _, invid, slot = inv.held(pid)
    if itemid ~= r.itemid or slot ~= r.slot then
        return
    end
    local gun = firearms.gun(itemid)
    local loaded = firearms.loaded(invid, slot)
    local n = math.min(gun.mag - loaded, inv.count(invid, gun.ammo))
    inv.take(invid, gun.ammo, n)
    inventory.set_data(invid, slot, "ammo", loaded + n)
end

return firearms
