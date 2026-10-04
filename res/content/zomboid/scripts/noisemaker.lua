local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local sandbox = require "zomboid:sandbox"

local function arm(x, y, z, pid)
    local id = block.get(x, y, z)
    local delay = block.properties[id]["zomboid:noise-delay"]
    block.set_field(x, y, z, "ring_at", clock.hours + delay / 60)
    if pid and pid >= 0 then
        survival.notify(pid, string.format("%s сработает через %d сек.", block.caption(id),
            math.floor(delay * sandbox.get("day_minutes") / 24 + 0.5)), "#e0d090")
    end
end

function on_placed(x, y, z, pid)
    arm(x, y, z, pid)
end

function on_interact(x, y, z, pid)
    arm(x, y, z, pid)
    return true
end

function on_block_tick(x, y, z, tps)
    local ring_at = block.get_field(x, y, z, "ring_at") or 0
    if ring_at <= 0 or clock.hours < ring_at then
        return
    end
    local id = block.get(x, y, z)
    local props = block.properties[id]
    if clock.hours > ring_at + props["zomboid:noise-time"] / 60 then
        block.set_field(x, y, z, "ring_at", 0)
        return
    end
    zombies.noise({x + 0.5, y + 0.5, z + 0.5}, props["zomboid:noise-radius"], nil, 2)
    if vc.is_client() then
        local name = block.name(id) == "zomboid:siren" and "world/siren" or "world/alarm"
        audio.play_sound(name, x + 0.5, y + 0.5, z + 0.5, 1.0, 1.0)
    end
end
