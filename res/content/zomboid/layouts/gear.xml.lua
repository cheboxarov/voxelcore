local survival = require "zomboid:survival"
local gear = require "zomboid:gear"
local spoilage = require "zomboid:spoilage"
local inv = require "zomboid:inv"

local pack
local ticking = false

local function current()
    local pid = hud.get_player()
    return survival.get(pid), pid
end

local function refresh()
    local state = current()
    local ginv = gear.inventory(state)
    for slot = 0, #gear.SLOTS - 1 do
        local itemid = inventory.get(ginv, slot)
        local text = gear.TITLES[gear.SLOTS[slot + 1]] .. "\n" .. (itemid ~= 0 and item.caption(itemid) or "-")
        document["slot_" .. slot].text = text
    end
    document.info.text = string.format(
        "[#d0d0d0]Тепло одежды: %.1f, влагозащита %d%%\nТемпература тела: %.1f°C\nГруз: %.1f / %.0f кг%s",
        gear.warmth(state), math.floor(gear.waterproof(state) * 100), state.temp,
        state.load, gear.capacity(state), state.load > gear.capacity(state) and " [#e0a060](перегруз)" or "")
end

local function close_pack()
    if pack then
        document.packbox:clear()
        inventory.remove(pack)
        pack = nil
    end
end

local function open_pack()
    close_pack()
    local state = current()
    pack = gear.open_pack(state)
    if pack == nil then
        document.pack_title.text = "Рюкзак не надет"
        return
    end
    document.pack_title.text = string.format("%s (%d мест)", item.caption((gear.worn(state, "back"))), inventory.size(pack))
    document.packbox:add(string.format(
        "<inventory id='packinv' color='#1c1a16e0'><slots-grid cols='4' count='%d' sharefunc='pack_share' updatefunc='pack_update'/></inventory>",
        inventory.size(pack)))
    document.packinv.inventory = pack
end

function gear_update(invid, slot)
    local state, pid = current()
    local itemid, count = inventory.get(invid, slot)
    if itemid ~= 0 and not gear.fits(itemid, slot) then
        inventory.move(invid, slot, player.get_inventory(pid))
        itemid, count = inventory.get(invid, slot)
        if itemid ~= 0 then
            inv.drop(pid, itemid, count, inventory.get_all_data(invid, slot))
            inventory.set(invid, slot, 0, 0)
        end
        survival.notify(pid, "Эту вещь сюда не надеть")
    end
    if gear.SLOTS[slot + 1] == "back" then
        open_pack()
    end
    state.load = gear.load(pid, state)
    refresh()
end

function unequip(invid, slot)
    inventory.move(invid, slot, player.get_inventory(hud.get_player()))
end

function pack_update(invid)
    local state, pid = current()
    spoilage.check(invid, false)
    gear.sync_pack(state, invid, pid)
    state.load = gear.load(pid, state)
    refresh()
end

function pack_share(invid, slot)
    inventory.move(invid, slot, player.get_inventory(hud.get_player()))
end

function on_open()
    document.gear.inventory = gear.inventory(current())
    open_pack()
    refresh()
    if not ticking then
        ticking = true
        document.root:setInterval(500, refresh)
    end
end

function on_close()
    if pack then
        local state, pid = current()
        gear.sync_pack(state, pack, pid)
    end
    close_pack()
end
