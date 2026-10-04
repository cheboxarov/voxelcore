local cars = require "zomboid:cars"

function on_block_present(x, y, z)
    if not world.is_open() or block.name(block.get(x, y, z)) ~= "zomboid:car_spawner" then
        return
    end
    block.set(x, y, z, 0, 0)
    cars.spawn(x, y, z)
end
