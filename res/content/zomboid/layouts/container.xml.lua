local spoilage = require "zomboid:spoilage"

share_func = require("core:inventory_utils").share_default_func

local cold = false

function on_slot_update(invid)
    spoilage.check(invid, cold)
end

function on_open(invid, x, y, z)
    cold = x ~= nil and block.has_tag(block.get(x, y, z), "zomboid:cold")
    spoilage.check(invid, cold)
end
