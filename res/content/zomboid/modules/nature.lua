local town = require "zomboid:town"

local nature = {
    SEA_LEVEL = town.SEA_LEVEL,
    RIVER_X = 50,
    RIVER_BED = 34.5,
    MEANDER = 44,
    HEIGHTS_BPD = 2,
    BIOMES_BPD = 4,
    FLAT_RAMP = 112,
    PAD_RAMP = 40,
}

local G = town.GROUND
local CHUNK = 16

-- {name, {open, weight}, {wet, weight}, {rock, weight}}; must match biomes.toml
nature.BIOMES = {
    {"town", {3, 1}, {0, 10}, {0, 10}},
    {"river", {0, 5}, {3, 1}, {0, 10}},
    {"meadow", {0.55, 1}, {-0.1, 2}, {-0.3, 2}},
    {"forest", {-0.3, 1}, {-0.3, 1.2}, {0, 2}},
    {"birch", {-0.25, 1}, {0.3, 1}, {-0.2, 2}},
    {"swamp", {-0.1, 2}, {0.75, 0.6}, {-0.5, 1}},
    {"hills", {0, 2}, {0, 2}, {0.65, 0.5}},
}

local function clamp01(m)
    m:max(0)
    m:min(1)
    return m
end

local function copy(m)
    local c = Heightmap(m.width, m.height)
    c:add(m)
    return c
end

-- no per-point setter in Heightmap: an exact 0..n-1 ramp comes from a 2-point noise map stretched linearly
local function ramp(n, vertical)
    local m = vertical and Heightmap(1, 2) or Heightmap(2, 1)
    m.noiseSeed = 7
    m:noise({0, 0}, 0.37)
    local a, b = m:at(0, 0), vertical and m:at(0, 1) or m:at(1, 0)
    assert(math.abs(b - a) > 1e-3, "nature: degenerate ramp")
    m:sub(a)
    m:mul((n - 1) / (b - a))
    if vertical then
        m:resize(1, 2 * (n - 1), "linear")
        m:crop(0, 0, 1, n)
    else
        m:resize(2 * (n - 1), 1, "linear")
        m:crop(0, 0, n, 1)
    end
    return m
end

local ramps = {}

local function coords(x, y, w, h, bpd)
    local key = w * 4096 + h
    local r = ramps[key]
    if r == nil then
        local rx, rz = ramp(w, false), ramp(h, true)
        rx:resize(w, h, "linear")
        rz:resize(w, h, "linear")
        assert(math.abs(rx:at(w - 1, h - 1) - (w - 1)) < 1e-3 and math.abs(rz:at(w - 1, h - 1) - (h - 1)) < 1e-3,
            "nature: bad coordinate ramp")
        r = {rx, rz}
        ramps[key] = r
    end
    local X, Z = Heightmap(w, h), Heightmap(w, h)
    X:add(r[1])
    X:add(x)
    X:mul(bpd)
    Z:add(r[2])
    Z:add(y)
    Z:mul(bpd)
    return X, Z
end

-- scale is in 1/blocks; FastNoiseLite multiplies coordinates by its default frequency 0.01
local function noise(x, y, w, h, bpd, seed, scale, octaves)
    local m = Heightmap(w, h)
    m.noiseSeed = seed
    m:noise({x, y}, scale * bpd * 100, octaves or 1)
    return m
end

local function meander(az)
    return math.min(1, math.max(0, (az - town.FLAT_EXTENT) / 100))
end

function nature.river_x(wz)
    local k = meander(math.abs(wz))
    if k == 0 then
        return nature.RIVER_X
    end
    return nature.RIVER_X + nature.MEANDER * k * (math.sin(wz / 97 + 1.3) + 0.35 * math.sin(wz / 41 + 0.4))
end

function nature.river_dist(wx, wz)
    return math.abs(wx - nature.river_x(wz))
end

local function fields(x, y, w, h, bpd, seed)
    local X, Z = coords(x, y, w, h, bpd)
    local k = copy(Z)
    k:abs()
    k:sub(town.FLAT_EXTENT)
    k:mul(1 / 100)
    clamp01(k)
    local s1, s2 = copy(Z), copy(Z)
    s1:mul(1 / 97)
    s1:add(1.3)
    s1:sin()
    s2:mul(1 / 41)
    s2:add(0.4)
    s2:sin()
    s2:mul(0.35)
    s1:add(s2)
    s1:mul(k)
    s1:mul(nature.MEANDER)
    s1:add(nature.RIVER_X)
    local river = copy(X)
    river:sub(s1)
    river:abs()
    local cheb, az = copy(X), copy(Z)
    cheb:abs()
    az:abs()
    cheb:max(az)
    return {
        X = X, Z = Z, river = river, cheb = cheb,
        open = noise(x, y, w, h, bpd, seed + 11, 1 / 170, 2),
        wet = noise(x, y, w, h, bpd, seed + 12, 1 / 210, 2),
        rock = noise(x, y, w, h, bpd, seed + 13, 1 / 190, 2),
    }
end

-- 1 inside lot pads (flat ground at GROUND), fading to 0 over PAD_RAMP
local function pad_mask(f, x, y, w, h, bpd)
    local pads = nature.pads and nature.pads(x * bpd, y * bpd, (x + w) * bpd, (y + h) * bpd, nature.PAD_RAMP)
    if pads == nil or #pads == 0 then
        return nil
    end
    local mask = Heightmap(w, h)
    for _, p in ipairs(pads) do
        local dx, dz = copy(f.X), copy(f.Z)
        dx:sub(p[1])
        dx:abs()
        dx:sub(p[3])
        dz:sub(p[2])
        dz:abs()
        dz:sub(p[4])
        dx:max(dz)
        dx:mul(-1 / nature.PAD_RAMP)
        dx:add(1)
        mask:max(clamp01(dx))
    end
    return mask
end

function nature.heightmap(x, y, w, h, bpd, seed)
    local f = fields(x, y, w, h, bpd, seed)
    local amp = copy(f.cheb)
    amp:sub(town.FLAT_EXTENT)
    amp:mul(1 / nature.FLAT_RAMP)
    clamp01(amp)
    local pads = pad_mask(f, x, y, w, h, bpd)
    if pads then
        pads:mul(-1)
        pads:add(1)
        amp:mul(pads)
    end
    local wild = copy(amp)
    local near_river = copy(f.river)
    near_river:sub(12)
    near_river:mul(1 / 40)
    amp:mul(clamp01(near_river))

    local hill = copy(f.rock)
    hill:sub(0.2)
    hill:mul(3)
    clamp01(hill)
    local flat = copy(hill)
    flat:mul(-1)
    flat:add(1)

    local m = noise(x, y, w, h, bpd, seed, 1 / 64, 3)
    m:mul(3.5)
    m:add(2.5)
    local ridge = noise(x, y, w, h, bpd, seed + 5, 1 / 36, 2)
    ridge:abs()
    ridge:mul(-10)
    ridge:add(12)
    ridge:mul(hill)
    m:add(ridge)
    m:mul(amp)
    m:add(G + 0.5)

    local lake = noise(x, y, w, h, bpd, seed + 6, 1 / 150)
    lake:sub(0.72)
    lake:mul(7)
    clamp01(lake)
    lake:mul(amp)
    m:mixin(33.5, lake)

    local swamp = copy(f.wet)
    swamp:sub(0.35)
    swamp:mul(4)
    clamp01(swamp)
    swamp:mul(flat)
    swamp:mul(amp)
    local puddles = noise(x, y, w, h, bpd, seed + 7, 1 / 9)
    puddles:mul(1.4)
    puddles:add(38.3)
    m:mixin(puddles, swamp)

    local stream = noise(x, y, w, h, bpd, seed + 8, 1 / 140)
    stream:abs()
    stream:mul(-1 / 0.06)
    stream:add(1)
    clamp01(stream)
    stream:mul(flat)
    stream:mul(wild)
    stream:mul(0.9)
    m:mixin(36.5, stream)

    local river = copy(f.river)
    river:mul(-1 / 2.5)
    river:add(9.5 / 2.5)
    m:mixin(nature.RIVER_BED, clamp01(river))

    m:mul(1 / 256)
    return m
end

function nature.biome_params(x, y, w, h, bpd, seed)
    local f = fields(x, y, w, h, bpd, seed)
    local inside = copy(f.cheb)
    inside:mul(-1 / 8)
    inside:add((town.FLAT_EXTENT - 4) / 8)
    local near = copy(f.cheb)
    near:mul(-1 / 300)
    near:add(1 + town.FLAT_EXTENT / 300)
    clamp01(near)
    near:mul(0.35)
    f.open:add(near)
    f.open:mixin(3, clamp01(inside))
    local pads = pad_mask(f, x, y, w, h, bpd)
    if pads then
        f.open:mixin(0.7, pads)
    end
    local bank = copy(f.river)
    bank:mul(-1 / 2)
    bank:add(11 / 2)
    f.wet:mixin(3, clamp01(bank))
    return f.open, f.wet, f.rock
end

local function choose(a, b, c)
    local best, score = nil, math.huge
    for _, biome in ipairs(nature.BIOMES) do
        local s = math.abs((a - biome[2][1]) / biome[2][2]) + math.abs((b - biome[3][1]) / biome[3][2])
            + math.abs((c - biome[4][1]) / biome[4][2])
        if s < score then
            best, score = biome[1], s
        end
    end
    return best
end

local function upscale(m, bpd)
    m:resize(CHUNK + bpd, CHUNK + bpd, "linear")
    m:crop(0, 0, CHUNK, CHUNK)
    return m
end

-- biome names of a chunk exactly as the engine picks them, index lz * 16 + lx + 1
function nature.chunk_biomes(cx, cz, seed)
    local bpd = nature.BIOMES_BPD
    local n = CHUNK / bpd + 1
    local a, b, c = nature.biome_params(cx * CHUNK / bpd, cz * CHUNK / bpd, n, n, bpd, seed)
    upscale(a, bpd)
    upscale(b, bpd)
    upscale(c, bpd)
    local out = {}
    for lz = 0, CHUNK - 1 do
        for lx = 0, CHUNK - 1 do
            out[lz * CHUNK + lx + 1] = choose(a:at(lx, lz), b:at(lx, lz), c:at(lx, lz))
        end
    end
    return out
end

-- surface heights of a chunk exactly as the engine generates them
function nature.chunk_heights(cx, cz, seed)
    local bpd = nature.HEIGHTS_BPD
    local n = CHUNK / bpd + 1
    local m = nature.heightmap(cx * CHUNK / bpd, cz * CHUNK / bpd, n, n, bpd, seed)
    clamp01(m)
    upscale(m, bpd)
    local out = {}
    for lz = 0, CHUNK - 1 do
        for lx = 0, CHUNK - 1 do
            out[lz * CHUNK + lx + 1] = math.floor(m:at(lx, lz) * 256)
        end
    end
    return out
end

local cache = {}
local cached = 0

local function chunk(wx, wz)
    local cx, cz = math.floor(wx / CHUNK), math.floor(wz / CHUNK)
    local key = cx * 65536 + cz
    local c = cache[key]
    if c == nil then
        if cached >= 1024 then
            cache, cached = {}, 0
        end
        local seed = world.get_seed()
        c = {nature.chunk_heights(cx, cz, seed), nature.chunk_biomes(cx, cz, seed)}
        cache[key] = c
        cached = cached + 1
    end
    return c, (wz - cz * CHUNK) * CHUNK + (wx - cx * CHUNK) + 1
end

function nature.height(wx, wz)
    local c, i = chunk(wx, wz)
    return c[1][i]
end

function nature.biome(wx, wz)
    local c, i = chunk(wx, wz)
    return c[2][i]
end

function nature.water_at(wx, wz)
    return nature.height(wx, wz) < nature.SEA_LEVEL
end

return nature
