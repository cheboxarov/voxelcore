local clock = require "zomboid:clock"
local survival = require "zomboid:survival"
local zombies = require "zomboid:zombies"
local town = require "zomboid:town"
local inv = require "zomboid:inv"

local SAVE_FILE = "state.json"
local STRICT_RULES = {
    "allow-content-access", "allow-flight", "allow-noclip", "allow-cheat-movement",
    "allow-debug-cheats", "allow-fast-interaction",
}

local tick = 0
local spoil_check_at = 0
local breaking = {}

local function save_path()
    return pack.data_file(PACK_ID, SAVE_FILE)
end

local function load_state()
    local path = save_path()
    if not file.exists(path) then
        return false
    end
    local data = json.parse(file.read(path))
    clock.reset(data.hours)
    zombies.horde_day = data.horde_day or 0
    survival.deserialize(data.players)
    return true
end

local function save_state()
    file.write(save_path(), json.tostring({
        hours = clock.hours,
        horde_day = zombies.horde_day,
        players = survival.serialize(),
    }, true))
end

local function enforce_survival_mode(pid)
    player.set_infinite_items(pid, false)
    player.set_instant_destruction(pid, false)
    player.set_flight(pid, false)
    player.set_noclip(pid, false)
end

local function check_spoilage(pid)
    local invid = player.get_inventory(pid)
    local rotten = item.index("zomboid:rotten_food")
    for slot = 0, inventory.size(invid) - 1 do
        local itemid = inventory.get(invid, slot)
        local props = itemid ~= 0 and item.properties[itemid]
        local days = props and props["zomboid:spoil-days"]
        if days then
            local born = inventory.get_data(invid, slot, "born")
            if born == nil then
                inventory.set_data(invid, slot, "born", clock.hours)
                born = clock.hours
            end
            local ratio = (clock.hours - born) / 24 / days
            if ratio > 1.5 then
                local _, count = inventory.get(invid, slot)
                inventory.set(invid, slot, rotten, count)
            elseif ratio > 1.0 then
                inventory.set_description(invid, slot, "Несвежее. Может вызвать отравление")
            elseif ratio > 0.6 then
                inventory.set_description(invid, slot, "Скоро испортится")
            else
                inventory.set_description(invid, slot, "Свежее")
            end
        end
    end
end

function on_world_open()
    for _, name in ipairs(STRICT_RULES) do
        rules.set(name, false)
    end
    if not load_state() then
        clock.reset(clock.START_HOUR)
    end
    events.on("zomboid:player_died", function(pid, pos, items, infected)
        if infected then
            local x, y, z = math.floor(pos[1]), math.floor(pos[2] - 0.9), math.floor(pos[3])
            zombies.spawn(x, y, z, {items = items, name = player.get_name(pid), shirt = "white"})
        else
            local util = require "base:util"
            for _, entry in ipairs(items) do
                util.drop(pos, item.index(entry[1]), entry[2], entry[3], 1.0)
            end
        end
    end)
end

function on_world_save()
    save_state()
end

function on_world_tick()
    tick = tick + 1
    local dh = clock.tick()
    local players = player.get_all()
    for _, pid in ipairs(players) do
        local state = survival.get(pid)
        if state.fresh then
            state.fresh = nil
            enforce_survival_mode(pid)
            survival.new_character(pid, town.spawn_point(1))
        end
        if tick % 20 == 0 then
            enforce_survival_mode(pid)
        end
        survival.update(pid, dh, 1 / 20)
    end
    if clock.hours >= spoil_check_at then
        spoil_check_at = clock.hours + 0.25
        for _, pid in ipairs(players) do
            check_spoilage(pid)
        end
    end
    zombies.tick(survival)
end

local function break_multiplier(blockid, itemid)
    local props = itemid ~= 0 and item.properties[itemid] or nil
    if props == nil then
        return 1.0
    end
    local material = block.material(blockid)
    if props["zomboid:chop"] and (material == "base:wood" or material == "base:grass") then
        return props["zomboid:chop"]
    end
    if props["zomboid:pry"] and block.has_tag(blockid, "zomboid:barricade") then
        return 3.0
    end
    return 1.3
end

function on_block_breaking(blockid, x, y, z, pid)
    if pid == nil or pid < 0 then
        return
    end
    local state = survival.get(pid)
    if state.dead then
        return
    end
    local itemid = inv.held(pid)
    local durability = block.properties[blockid]["base:durability"] or 5.0
    local key = x .. ":" .. y .. ":" .. z
    local now = time.uptime()
    local entry = breaking[pid]
    if entry == nil or entry.key ~= key or now - entry.time > 1.0 then
        entry = {key = key, progress = 0}
        breaking[pid] = entry
    end
    entry.time = now
    entry.progress = entry.progress + 0.16 * break_multiplier(blockid, itemid)
    if entry.progress < durability then
        return
    end
    breaking[pid] = nil
    if block.has_tag(blockid, "zomboid:glass") then
        block.set(x, y, z, block.index("zomboid:window_broken"), 0)
        audio.play_sound("world/glass_break", x + 0.5, y + 0.5, z + 0.5, 1.0, 1.0)
        zombies.noise({x, y, z}, 18, pid)
        if itemid == 0 and math.random() < 0.5 then
            survival.add_wound(pid, "scratch")
        end
        return
    end
    local util = require "base:util"
    local drops = util.block_loot(blockid)
    if block.is_segment(x, y, z) then
        x, y, z = block.seek_origin(x, y, z)
    end
    if block.has_tag(blockid, "zomboid:container") then
        local invid = inventory.get_block(x, y, z)
        for slot = 0, invid ~= 0 and inventory.size(invid) - 1 or -1 do
            local id, count = inventory.get(invid, slot)
            if id ~= 0 then
                table.insert(drops, {item = id, count = count, data = inventory.get_all_data(invid, slot)})
            end
        end
    end
    block.destruct(x, y, z, pid)
    for _, drop in ipairs(drops) do
        if drop.item and drop.item ~= 0 and drop.count > 0 then
            util.drop({x + 0.5, y + 0.5, z + 0.5}, drop.item, drop.count, drop.data, 0.3)
        end
    end
end
