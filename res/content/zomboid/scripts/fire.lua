local fire = require "zomboid:fire"

function on_block_present(x, y, z)
    fire.track(x, y, z)
end

function on_block_removed(x, y, z)
    fire.untrack(x, y, z)
end

function on_block_tick(x, y, z, tps)
    fire.update(x, y, z, tps)
end

function on_interact(x, y, z, pid)
    fire.douse(pid, x, y, z)
    return true
end
