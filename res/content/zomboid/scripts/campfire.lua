local survival = require "zomboid:survival"
local water = require "zomboid:water"
local fire = require "zomboid:fire"

function on_interact(x, y, z, pid)
    if not water.purify_held(pid) then
        survival.notify(pid, "Костёр потрескивает. Можно прокипятить сырую воду")
    end
    return true
end

function on_block_tick(x, y, z)
    fire.unattended(x, y, z)
end
