local power = require "zomboid:power"

function on_block_present(x, y, z)
    power.track_generator(x, y, z)
end

function on_block_removed(x, y, z)
    power.untrack_generator(x, y, z)
    power.refresh_lamps()
end

function on_interact(x, y, z, pid)
    power.interact_generator(pid, x, y, z)
    return true
end
