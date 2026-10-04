local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local clock = require "zomboid:clock"
local skills = require "zomboid:skills"

local combat = {
    PUSH_STAMINA = 12,
    PUSH_RANGE = 2.2,
    PUSH_COOLDOWN = 0.9,
}

local next_push = {}

function combat.is_grabbed(state)
    return (state.grabbed_until or 0) > clock.hours
end

function combat.push(pid)
    local state = survival.get(pid)
    local now = time.uptime()
    if state.dead or state.sleeping or (next_push[pid] or 0) > now then
        return 0
    end
    if state.stamina < combat.PUSH_STAMINA * 0.5 then
        survival.notify(pid, "Нет сил толкаться", "#ff9050")
        return 0
    end
    next_push[pid] = now + combat.PUSH_COOLDOWN
    state.stamina = math.max(0, state.stamina - combat.PUSH_STAMINA)
    state.grabbed_until = nil
    local ppos = {player.get_pos(pid)}
    local look = player.get_dir(pid)
    local flat = vec3.normalize({look[1], 0, look[3]})
    local pushed = 0
    for _, z in pairs(zombies.registry) do
        local zp = z.get_pos()
        local to = {zp[1] - ppos[1], 0, zp[3] - ppos[3]}
        local dist = vec3.length(to)
        if dist <= combat.PUSH_RANGE and math.abs(zp[2] - ppos[2]) < 1.6
            and (dist < 0.6 or vec3.dot(vec3.normalize(to), flat) > 0.4) and z.shove(ppos, pid) then
            pushed = pushed + 1
        end
    end
    if pushed > 0 then
        skills.add_xp(pid, "melee", pushed)
    end
    zombies.noise(ppos, 4, pid)
    if vc.is_client() then
        audio.play_sound("player/swing", ppos[1], ppos[2], ppos[3], 0.8, 0.7)
    end
    return pushed
end

return combat
