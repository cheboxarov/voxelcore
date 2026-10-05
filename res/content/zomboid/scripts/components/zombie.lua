local tsf = entity.transform
local body = entity.rigidbody
local rig = entity.skeleton
local mob = entity:require_component("core:mob")
local pf = entity:require_component("core:pathfinding")

local clock = require "zomboid:clock"
local zombies = require "zomboid:zombies"
local survival = require "zomboid:survival"
local barricade = require "zomboid:barricade"
local weapons = require "zomboid:weapons"
local loot = require "zomboid:loot"
local sandbox = require "zomboid:sandbox"
local skills = require "zomboid:skills"
local noise = require "zomboid:noise"
local town = require "zomboid:town"
local population = require "zomboid:population"

local SHIRTS = {"red", "blue", "green", "gray", "white", "police", "plaid", "suit"}
local PANTS = {"jeans", "brown", "black"}
local HEADS = {"bald", "dark", "long", "gray", "blond"}

local uid = entity:get_uid()
local data = SAVED_DATA

if data.max_health == nil then
    local args = ARGS or {}
    data.kind = zombies.KINDS[args.kind] and args.kind or "normal"
    local hp = zombies.KINDS[data.kind].hp
    data.max_health = math.random(hp[1], hp[2]) + (args.horde and 15 or 0)
    data.health = data.max_health
    data.shirt = args.shirt or zombies.KINDS[data.kind].shirt or SHIRTS[math.random(#SHIRTS)]
    data.pants = zombies.KINDS[data.kind].pants or PANTS[math.random(#PANTS)]
    data.items = args.items
    data.name = args.name
    data.cell = args.cell
    data.anchor = args.anchor
    data.route = args.route
end
if data.kind == nil then
    data.kind = data.sprinter and "sprinter" or "normal"
    data.sprinter = nil
end
local LEDGES = {["base:ground"] = true, ["base:grass_block"] = true, ["base:sand"] = true, ["base:stone"] = true}
local kind = zombies.KINDS[data.kind]
local size = kind.size or {1, 1, 1}
if kind.size then
    tsf:set_size(kind.size)
end
if kind.hitbox then
    body:set_size(kind.hitbox)
end
mob.set_movement_speed(kind.speed)
mob.set_jump_force(8)

rig:set_texture("$shirt", "blocks:z_shirt_" .. data.shirt)
rig:set_texture("$pants", "blocks:z_pants_" .. data.pants)
data.head = data.head or HEADS[math.random(#HEADS)]
rig:set_texture("$head", "blocks:z_head_" .. data.head)

local bones = {
    body = rig:index("body"),
    leg_left = rig:index("leg_left"),
    leg_right = rig:index("leg_right"),
    arm_left = rig:index("arm_left"),
    arm_right = rig:index("arm_right"),
}

mode = "idle"
goal = nil
target_pid = nil

local dead = data.dead == true
local now = 0.0
local tick = math.random(0, 19)
local last_seen = -100
local goal_until = 0
local attack_ready = 0
local bash_ready = 0
local bash_target = nil
local stun_until = 0
local downed_until = 0
local heard_at = time.uptime()
local route_prev = nil
local last_pos = tsf:get_pos()
local stuck = 0
local sidestep_until = 0
local sidestep_dir = nil
local wander_at = math.random() * 8
local groan_at = math.random() * 10
local dead_at = nil
local anim_phase = math.random() * 6
local attack_anim = 0
local flash = 0
local move_dir = nil
local move_mul = 1.0
local use_path = false
local rail = nil

function get_pos()
    return tsf:get_pos()
end

function is_dead()
    return dead
end

local function horizontal_distance(a, b)
    local dx, dz = a[1] - b[1], a[3] - b[3]
    return math.sqrt(dx * dx + dz * dz)
end

local function groan(volume)
    if vc.is_client() then
        local p = tsf:get_pos()
        audio.play_sound("zombie/groan", p[1], p[2], p[3], volume or 0.8, 0.8 + math.random() * 0.4)
    end
end

function get_kind()
    return data.kind
end

function hear(pos, pid, dist)
    if dead or mode == "chase" then
        return
    end
    mode = "investigate"
    goal = {pos[1], pos[2], pos[3]}
    goal_until = now + 30
    if pid then
        target_pid = pid
    end
end

local function speed_multiplier()
    local m = (clock.is_night() and 1.3 or 1.0) * sandbox.get("zombie_speed")
    if mode == "chase" then
        m = m * kind.chase
    elseif mode == "investigate" then
        m = m * 0.85
    else
        m = m * 0.45
    end
    return m
end

local function can_see(pid, ppos, dist)
    local state = survival.get(pid)
    if state.dead or state.setup then
        return false
    end
    local night = clock.is_night()
    local sight = night and 11 or 22
    if state.crouching then
        sight = sight * 0.6 * skills.mul(pid, "sight")
    end
    if night and state.light then
        sight = 24
    end
    if dist > sight then
        return false
    end
    local pos = tsf:get_pos()
    if dist > (state.crouching and 1.2 or 2.5) then
        local facing = mob.get_dir()
        local to = vec3.normalize({ppos[1] - pos[1], 0, ppos[3] - pos[3]})
        if facing[1] * to[1] + facing[3] * to[3] < -0.25 then
            return false
        end
    end
    local eye = {pos[1], pos[2] + kind.half - 0.3, pos[3]}
    local target = {ppos[1], ppos[2] + 0.6, ppos[3]}
    local dir = vec3.normalize(vec3.sub(target, eye))
    local hit = block.raycast(eye, dir, dist)
    return hit == nil or hit.length >= dist - 0.4
end

local function next_crossing(pos, first)
    local node = town.crossing_near(pos[1], pos[3])
    if first then
        route_prev = nil
        return {node.x + 0.5, town.GROUND + 1, node.z + 0.5}
    end
    local options = {}
    for _, other in ipairs(node.links) do
        if other ~= route_prev then
            table.insert(options, other)
        end
    end
    local pick = #options > 0 and options[math.random(#options)] or node.links[1] or node
    route_prev = node
    return {pick.x + 0.5, town.GROUND + 1, pick.z + 0.5}
end

local function wander_goal(pos)
    if data.anchor then
        local a = data.anchor
        return {a[1] + math.random(-3, 3), a[2], a[3] + math.random(-3, 3)}
    end
    return {pos[1] + math.random(-8, 8), pos[2], pos[3] + math.random(-8, 8)}
end

local function think()
    local pos = tsf:get_pos()
    if mode ~= "chase" then
        local mark = noise.loudest(pos, heard_at)
        if mark then
            heard_at = mark.time
            if mark.pid or mode ~= "investigate" or horizontal_distance(pos, mark.pos) > 3 then
                hear(mark.pos, mark.pid, vec3.distance(pos, mark.pos))
            end
        end
    end
    local pid = player.get_nearest(pos)
    if pid then
        local ppos = {player.get_pos(pid)}
        local dist = vec3.distance(pos, ppos)
        if can_see(pid, ppos, dist) then
            if mode ~= "chase" then
                groan(1.0)
            end
            mode = "chase"
            target_pid = pid
            goal = ppos
            last_seen = now
        elseif mode == "chase" then
            if target_pid == pid and dist < 3 then
                goal = ppos
            elseif now - last_seen > 6 then
                mode = "investigate"
                goal_until = now + 15
            elseif target_pid == pid and math.abs(ppos[2] - pos[2]) > 2
                and town.building_at(math.floor(ppos[1]), math.floor(ppos[3])) then
                goal = ppos
            end
        end
    end
    if mode == "investigate" and (goal == nil or now > goal_until
        or (horizontal_distance(pos, goal) < 1.5 and math.abs(pos[2] - goal[2]) < 2)) then
        mode = "idle"
        goal = nil
        wander_at = now + 3 + math.random() * 6
    end
    if mode == "idle" and data.route then
        goal = next_crossing(pos, true)
        mode = "roam"
        goal_until = now + 60
    elseif mode == "roam" and (now > goal_until or horizontal_distance(pos, goal) < 2) then
        goal = next_crossing(pos)
        goal_until = now + 60
    elseif mode == "idle" and now > wander_at then
        goal = wander_goal(pos)
        mode = "wander"
        goal_until = now + 10
    elseif mode == "wander" and (now > goal_until or horizontal_distance(pos, goal) < 1.2) then
        mode = "idle"
        goal = nil
        wander_at = now + 4 + math.random() * 10
    end
end

local function try_attack()
    if mode ~= "chase" or target_pid == nil or now < attack_ready or now < stun_until then
        return
    end
    local pos = tsf:get_pos()
    local ppos = {player.get_pos(target_pid)}
    if horizontal_distance(pos, ppos) < 1.45 and math.abs(pos[2] - ppos[2]) < 1.6 then
        local state = survival.get(target_pid)
        if state.dead or state.setup then
            return
        end
        local night = clock.is_night()
        survival.zombie_hit(target_pid, night)
        if kind.grab then
            state.grabbed_until = clock.hours + 2 / 60
            survival.notify(target_pid, "Ползун вцепился вам в ногу!", "#ff9050")
        end
        attack_ready = now + (night and 1.1 or 1.5)
        attack_anim = 1
    end
end

local function front_cell(pos, dir, dy, reach)
    reach = reach or 0.8
    return math.floor(pos[1] + dir[1] * reach), math.floor(pos[2] - kind.half + dy), math.floor(pos[3] + dir[3] * reach)
end

local function ledge(x, y, z)
    return LEDGES[block.material(block.get(x, y, z))] and not block.is_solid_at(x, y + 1, z)
        and not block.is_solid_at(x, y + 2, z)
end

local function check_stuck(pos)
    local moved = horizontal_distance(pos, last_pos)
    last_pos = pos
    if move_dir == nil or moved > 0.3 then
        stuck = 0
        bash_target = nil
        return
    end
    stuck = stuck + 1
    for _, reach in ipairs({0.0, 0.45, 0.9}) do
        for dy = 0, 1 do
            local x, y, z = front_cell(pos, move_dir, dy, reach)
            local id = block.get(x, y, z)
            if barricade.is_bashable(id) then
                bash_target = {x, y, z}
                return
            end
        end
    end
    if stuck >= 2 and body:is_grounded() then
        local x, y, z = front_cell(pos, move_dir, 0)
        if ledge(x, y, z) then
            mob.jump()
        else
            local side = math.random() < 0.5 and 1 or -1
            sidestep_dir = {-move_dir[3] * side, 0, move_dir[1] * side}
            sidestep_until = now + 1.2
            pf.reset_route()
        end
    end
end

local function do_bash()
    if bash_target == nil or now < bash_ready or now < stun_until then
        return
    end
    local night = clock.is_night()
    bash_ready = now + (night and 1.1 or 1.4)
    goal_until = math.max(goal_until, now + 2)
    attack_anim = 1
    if barricade.bash(bash_target[1], bash_target[2], bash_target[3], (night and 7 or 5) * kind.bash) then
        bash_target = nil
        stuck = 0
    end
end

local function die(pid)
    dead = true
    data.dead = true
    dead_at = now
    mode = "dead"
    zombies.unregister(uid)
    if pid and pid >= 0 then
        local state = survival.get(pid)
        state.kills = (state.kills or 0) + 1
    end
    local util = require "base:util"
    local pos = tsf:get_pos()
    if data.items then
        for _, entry in ipairs(data.items) do
            util.drop(pos, item.index(entry[1]), entry[2], entry[3], 0.5)
        end
        data.items = nil
    elseif math.random() < 0.2 then
        local itemid, count = loot.zombie_drop()
        util.drop(pos, itemid, count, nil, 0.5)
    end
    entity:set_enabled("core:pathfinding", false)
    entity:set_enabled("core:mob", false)
    body:set_vel({0, 0, 0})
    body:set_selectable(false)
end

function take_hit(damage, knockback, from, pid)
    if dead then
        return
    end
    data.health = data.health - damage
    flash = 0.2
    local pos = tsf:get_pos()
    local dir = vec3.normalize({pos[1] - from[1], 0, pos[3] - from[3]})
    knockback = knockback * kind.knockback
    body:set_vel({dir[1] * knockback, 2.5, dir[3] * knockback})
    stun_until = now + 0.2 + knockback * 0.07
    if vc.is_client() then
        gfx.particles.emit({pos[1], pos[2] + 0.4, pos[3]}, 14, {
            lifetime = 0.6, spawn_interval = 0.0001, explosion = {2, 2, 2},
            texture = "blocks:z_gore", size = {0.07, 0.07, 0.07},
            spawn_shape = "ball", spawn_spread = {0.2, 0.2, 0.2}
        })
    end
    if pid and pid >= 0 then
        mode = "chase"
        target_pid = pid
        last_seen = now
        goal = {player.get_pos(pid)}
    end
    if data.health <= 0 then
        die(pid)
    end
end

function is_unaware_of(pid)
    if mode == "chase" or now < downed_until then
        return false
    end
    local pos = tsf:get_pos()
    local ppos = {player.get_pos(pid)}
    local to = vec3.normalize({ppos[1] - pos[1], 0, ppos[3] - pos[3]})
    local facing = mob.get_dir()
    return facing[1] * to[1] + facing[3] * to[3] < -0.2
end

function on_attacked(attacker, pid)
    if dead or pid == nil or pid < 0 then
        return
    end
    local pos = tsf:get_pos()
    local sneak = is_unaware_of(pid)
    local damage, knockback, armed = weapons.attack(pid, pos)
    if not damage then
        return
    end
    if sneak and armed then
        survival.notify(pid, "Тихое убийство", "#a0e0a0")
        skills.add_xp(pid, "sneaking", 15)
        damage = data.health + 1
    elseif sneak then
        damage = damage * 2
    end
    take_hit(damage, knockback, {player.get_pos(pid)}, pid)
end

function shove(from, pid)
    if dead then
        return false
    end
    local pos = tsf:get_pos()
    local dir = vec3.normalize({pos[1] - from[1], 0, pos[3] - from[3]})
    local force = kind.heavy and 2 or 6
    body:set_vel({dir[1] * force, 2.0, dir[3] * force})
    if kind.heavy or kind.grab then
        stun_until = now + 0.8
    else
        downed_until = now + 2.2
        stun_until = downed_until
    end
    attack_anim = 0
    if pid and pid >= 0 and mode ~= "chase" then
        mode = "chase"
        target_pid = pid
        last_seen = now
        goal = {player.get_pos(pid)}
    end
    return true
end

function is_downed()
    return now < downed_until
end

local function stairs_toward(pos, goal)
    local x, z = math.floor(pos[1]), math.floor(pos[3])
    local _, p = town.building_at(x, z)
    if p == nil then
        local _, gp = town.building_at(math.floor(goal[1]), math.floor(goal[3]))
        if gp == nil or gp.def.stair_path == nil then
            return nil
        end
        local dx, dz = town.to_world(gp, gp.door, 0)
        return {dx + 0.5, town.GROUND + 1, dz + 0.5}, math.abs(dx + 0.5 - pos[1]) + math.abs(dz + 0.5 - pos[3]) < 3
    end
    if p.def.stair_path == nil then
        return nil
    end
    local up = goal[2] > pos[2]
    local level = (pos[2] - kind.half - town.GROUND - 1) / 4
    local hx, hz = town.to_local(p, x, z)
    local nx, nz = p.def.stair_path(p, up and math.floor(level + 0.05) or math.ceil(level - 0.05) - 1, up, hx, hz)
    if nx then
        local wx, wz = town.to_world(p, nx, nz)
        rail = wx == x and {1, x + 0.5} or {3, z + 0.5}
        return {wx + 0.5, pos[2], wz + 0.5}, true
    end
end

function on_update(tps)
    now = now + 1 / tps
    if dead then
        if dead_at == nil then
            entity:despawn()
        elseif now - dead_at > 30 then
            entity:despawn()
        end
        return
    end
    tick = tick + 1
    if tick % 5 == 0 then
        think()
        try_attack()
        do_bash()
    end
    local pos = tsf:get_pos()
    if tick % 20 == 0 then
        check_stuck(pos)
    end
    if tick % 100 == 0 then
        local pid = player.get_nearest(pos)
        if pid == nil or vec3.distance(pos, {player.get_pos(pid)}) > zombies.DESPAWN_DISTANCE then
            if data.cell then
                population.seeded[data.cell] = nil
            end
            entity:despawn()
            return
        end
    end
    if now > groan_at then
        groan_at = now + 6 + math.random() * 12
        if math.random() < 0.4 then
            groan(0.6)
        end
    end

    local was_path = use_path
    move_dir = nil
    use_path = false
    rail = nil
    if now < stun_until or goal == nil or bash_target ~= nil then
        pf.set_target(nil)
        return
    end
    if now < sidestep_until and sidestep_dir then
        move_dir = sidestep_dir
        move_mul = 0.8
        return
    end
    local dist = horizontal_distance(pos, goal)
    local height = (pos[2] - kind.half - town.GROUND - 1) % 4
    local level = math.abs(goal[2] - pos[2]) < ((height < 0.3 or height > 3.7) and 1.2 or 0.4)
    local target, walk
    if not level then
        target, walk = stairs_toward(pos, goal)
    end
    if dist < 1.0 and target == nil then
        return
    end
    move_mul = speed_multiplier()
    if walk then
        move_mul = math.min(move_mul, 0.6)
        if stuck < 3 then
            goal_until = math.max(goal_until, now + 2)
        end
    end
    local route = pf.get_route()
    local direct = walk or target == nil and (dist < 7 or (mode == "chase" and now - last_seen < 0.5) or (route ~= nil and #route == 0))
    target = target or goal
    if direct then
        pf.set_target(nil)
        move_dir = vec3.normalize({target[1] - pos[1], 0, target[3] - pos[3]})
    else
        if not was_path then
            pf.reset_route()
        end
        pf.set_target({math.floor(target[1]), math.floor(target[2]), math.floor(target[3])})
        use_path = true
        move_dir = mob.get_dir()
    end
end

function on_physics_update(delta)
    if dead or move_dir == nil then
        return
    end
    if use_path then
        mob.follow_waypoints(pf)
    else
        mob.set_dir({move_dir[1], 0, move_dir[3]})
        mob.go({move_dir[1], move_dir[3]}, move_mul, false, false)
        if body:is_grounded() and body:get_vel()[2] <= 0 then
            local x, y, z = front_cell(tsf:get_pos(), move_dir, 0, 0.6)
            if ledge(x, y, z) then
                mob.jump()
                local vel = body:get_vel()
                body:set_vel({move_dir[1] * 3, vel[2], move_dir[3] * 3})
            end
        end
        if rail then
            local vel = body:get_vel()
            vel[rail[1]] = (rail[2] - tsf:get_pos()[rail[1]]) * 8
            body:set_vel(vel)
        end
    end
end

function on_render(delta)
    if flash > 0 then
        flash = flash - delta
        rig:set_color(flash > 0 and {1.0, 0.45, 0.45} or {1, 1, 1})
    end
    local lying = mat4.translate({0, -(kind.half - 0.18) / size[2], 0})
    if dead then
        rig:set_matrix(bones.body, mat4.mul(lying, mat4.rotate({1, 0, 0}, -90)))
        return
    end
    if now < downed_until then
        rig:set_matrix(bones.body, mat4.mul(lying, mat4.rotate({1, 0, 0}, 90)))
        return
    end
    local vel = body:get_vel()
    local speed = math.sqrt(vel[1] * vel[1] + vel[3] * vel[3])
    anim_phase = anim_phase + delta * (1.5 + speed * 4)
    if kind.grab then
        local crawl = math.sin(anim_phase) * math.min(1, speed / 0.6) * 30
        rig:set_matrix(bones.body, mat4.mul(lying, mat4.rotate({1, 0, 0}, -90)))
        rig:set_matrix(bones.arm_left, mat4.rotate({1, 0, 0}, 180 + crawl))
        rig:set_matrix(bones.arm_right, mat4.rotate({1, 0, 0}, 180 - crawl))
        rig:set_matrix(bones.leg_left, mat4.rotate({1, 0, 0}, crawl * 0.3))
        rig:set_matrix(bones.leg_right, mat4.rotate({1, 0, 0}, -crawl * 0.3))
        return
    end
    local swing = math.sin(anim_phase) * math.min(1, speed / 1.2) * 32
    rig:set_matrix(bones.leg_left, mat4.rotate({1, 0, 0}, swing))
    rig:set_matrix(bones.leg_right, mat4.rotate({1, 0, 0}, -swing))
    if attack_anim > 0 then
        attack_anim = math.max(0, attack_anim - delta * 3)
    end
    local reach = 80 + math.sin(attack_anim * math.pi) * 45
    local sway = math.sin(anim_phase * 0.5) * 6
    rig:set_matrix(bones.arm_left, mat4.rotate({1, 0, 0}, reach + sway))
    rig:set_matrix(bones.arm_right, mat4.rotate({1, 0, 0}, reach - sway))
    rig:set_matrix(bones.body, mat4.rotate({1, 0, 0}, -8 + math.sin(anim_phase) * 2))
end

function on_despawn()
    zombies.unregister(uid)
end

if dead then
    dead_at = nil
else
    zombies.register(uid, this)
end
