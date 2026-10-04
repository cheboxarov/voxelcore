local power = require "zomboid:power"

function on_block_present(x, y, z)
    power.refresh_lamp(x, y, z)
end

function on_block_removed(x, y, z)
    power.untrack_lamp(x, y, z)
end
