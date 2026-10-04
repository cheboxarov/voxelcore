local farming = require "zomboid:farming"

function on_block_tick(x, y, z)
    farming.update(x, y, z)
end

function on_interact(x, y, z, pid)
    farming.interact(pid, x, y, z)
    return true
end
