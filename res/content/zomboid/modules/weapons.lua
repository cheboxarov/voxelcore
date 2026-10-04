local inv = require "zomboid:inv"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local skills = require "zomboid:skills"
local traits = require "zomboid:traits"

local weapons = {}

local FISTS = {damage = 7, knockback = 2.5, cooldown = 0.6, range = 1.9, stamina = 4, crit = 0.05}

local next_attack = {}

function weapons.stats(itemid)
    local props = item.properties[itemid]
    if itemid == 0 or props == nil or props["zomboid:damage"] == nil then
        return FISTS, false
    end
    return {
        damage = props["zomboid:damage"],
        knockback = props["zomboid:knockback"] or 3,
        cooldown = props["zomboid:cooldown"] or 1,
        range = props["zomboid:range"] or 2.2,
        stamina = props["zomboid:stamina"] or 8,
        crit = item.name(itemid) == "zomboid:knife" and 0.25 or 0.1,
    }, true
end

function weapons.attack(pid, target_pos)
    local state = survival.get(pid)
    if state.dead or state.sleeping then
        return nil
    end
    local now = time.uptime()
    if (next_attack[pid] or 0) > now then
        return nil
    end
    local itemid, _, invid, slot = inv.held(pid)
    if itemid ~= 0 and item.properties[itemid]["zomboid:gun"] then
        return nil
    end
    local stats, is_weapon = weapons.stats(itemid)
    local ppos = {player.get_pos(pid)}
    if vec3.distance(ppos, target_pos) > stats.range + 0.6 then
        return nil
    end
    next_attack[pid] = now + stats.cooldown
    local damage = stats.damage * (0.85 + math.random() * 0.3) * skills.mul(pid, "melee_damage")
    local stamina = stats.stamina * skills.mul(pid, "melee_stamina")
    if zombies.count_near(ppos, 6) >= 3 then
        damage = damage * traits.mul(state, "panic_damage")
        stamina = stamina * traits.mul(state, "panic_stamina")
    end
    if state.stamina < 10 then
        damage = damage * 0.5
    end
    if math.random() < stats.crit then
        damage = damage * 2
    end
    state.stamina = math.max(0, state.stamina - stamina)
    skills.add_xp(pid, "melee", is_weapon and 4 or 3)
    if is_weapon then
        inventory.use(invid, slot)
        if inventory.get(invid, slot) == 0 then
            survival.notify(pid, "Оружие сломалось!", "#ff9050")
        end
    end
    zombies.noise(ppos, state.crouching and 3 or 7, pid)
    if vc.is_client() then
        audio.play_sound("player/hit", target_pos[1], target_pos[2], target_pos[3], 1.0, 0.85 + math.random() * 0.3)
    end
    return damage, stats.knockback * skills.mul(pid, "knockback"), is_weapon
end

return weapons
