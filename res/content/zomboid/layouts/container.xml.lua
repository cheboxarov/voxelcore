local spoilage = require "zomboid:spoilage"
local power = require "zomboid:power"

share_func = require("core:inventory_utils").share_default_func

local cold = false
local generator = false

function on_slot_update(invid)
    spoilage.check(invid, cold, generator)
end

function on_open(invid, x, y, z)
    cold = x ~= nil and block.has_tag(block.get(x, y, z), "zomboid:cold")
    generator = cold and not power.grid_on() and power.generator_near(x, y, z)
    spoilage.check(invid, cold, generator)
end
