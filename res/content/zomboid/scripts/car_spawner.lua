local cars = require "zomboid:cars"

function on_block_present(x, y, z)
    if not world.is_open() then
        return
    end
    block.set(x, y, z, 0, 0)
    cars.spawn(x, y, z)
end
