local farming = require "zomboid:farming"

function on_use_on_block(x, y, z, pid)
    return farming.dig(pid, x, y, z)
end
