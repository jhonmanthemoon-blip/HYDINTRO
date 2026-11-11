--// HYD3 AUTO LOADER: downloads the 361 frames + audio into workspace/hyd3 (only what is missing), then plays the video
--// EDIT THIS LINE ONLY: your GitHub username and repo name, like "ExampleUser/hyd" (the repo must be public)
local DL_REPO     = "jhonmanthemoon-blip/HYDINTRO"
local DL_BRANCH   = "main"
-- it tries the main folder of the repo first, then a folder called hyd3, so both upload layouts work
local DL_BASES = {
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/",
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/hyd3/",
}
local DL_FOLDER   = "hyd3"
local DL_FRAMES   = 383
local DL_THREADS  = 8      -- downloads at the same time (lower it to 4 if GitHub rate-limits you)
-- frames 336-383 (HYD DUELS ending + hold loop) are built into this script and written to workspace/hyd3 once.
-- Bump DL_VERSION to force that write again; frames 1-335 + audio still download from GitHub.
local DL_UPDATE_FROM = 336
local DL_UPDATE_TO   = 383
local DL_VERSION     = "4"

do
    local Players = game:GetService("Players")

    -- (small version: frames 336-383 are downloaded from your GitHub repo, upload them there)
    local EMB = {
    }

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local LUT = {}
    for i = 1, 64 do LUT[B64:byte(i)] = i - 1 end
    local function b64decode(str)
        str = str:gsub("[^%w%+/]", "")
        local out, n = {}, 0
        local len = #str
        local full = len - (len % 4)
        for i = 1, full, 4 do
            local a, b, c, d = str:byte(i, i + 3)
            local v = LUT[a] * 262144 + LUT[b] * 4096 + LUT[c] * 64 + LUT[d]
            n += 1
            out[n] = string.char(math.floor(v / 65536), math.floor(v / 256) % 256, v % 256)
            if n % 40000 == 0 then task.wait() end
        end
        local rest = len - full
        if rest == 2 then
            local a, b = str:byte(full + 1, full + 2)
            local v = LUT[a] * 262144 + LUT[b] * 4096
            n += 1
            out[n] = string.char(math.floor(v / 65536))
        elseif rest == 3 then
            local a, b, c = str:byte(full + 1, full + 3)
            local v = LUT[a] * 262144 + LUT[b] * 4096 + LUT[c] * 64
            n += 1
            out[n] = string.char(math.floor(v / 65536), math.floor(v / 256) % 256)
        end
        return table.concat(out)
    end


    local function fetch(url)
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 0 then return body end
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            local ok2, res = pcall(req, {Url = url, Method = "GET"})
            if ok2 and res and res.StatusCode == 200 and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
        end
        return nil
    end

    -- reject "404: Not Found" pages and broken downloads
    local function valid(name, body)
        if #body < 200 then return false end
        if name:sub(-4) == ".jpg" then
            return body:byte(1) == 0xFF and body:byte(2) == 0xD8
        end
        return true
    end

    local function haveFile(path)
        if not isfile(path) then return false end
        local ok, data = pcall(readfile, path)
        return ok and type(data) == "string" and #data >= 200
    end

    if not isfolder(DL_FOLDER) then makefolder(DL_FOLDER) end

    local names = {"audio.mp3"}
    for i = 1, DL_FRAMES do
        table.insert(names, string.format("%03d.jpg", i))
    end

    local VERSION_FILE = DL_FOLDER .. "/version.txt"
    local oldVersion = ""
    if isfile(VERSION_FILE) then
        local okv, v = pcall(readfile, VERSION_FILE)
        if okv and type(v) == "string" then oldVersion = v end
    end
    local forceUpdate = (oldVersion ~= DL_VERSION)
    for num = 362, DL_UPDATE_TO do
        if not haveFile(DL_FOLDER .. "/" .. string.format("%03d.jpg", num)) then forceUpdate = true end
    end

    -- write the built-in new frames first (no internet needed for these)
    local embeddedOk = {}
    if forceUpdate then
        for num = DL_UPDATE_FROM, DL_UPDATE_TO do
            local data = EMB[num]
            if data then
                local okd, bytes = pcall(b64decode, data)
                if okd and type(bytes) == "string" and #bytes >= 200 and bytes:byte(1) == 0xFF and bytes:byte(2) == 0xD8 then
                    local okw = pcall(writefile, DL_FOLDER .. "/" .. string.format("%03d.jpg", num), bytes)
                    if okw then embeddedOk[num] = true end
                end
            end
        end
    end

    local missing = {}
    for _, name in ipairs(names) do
        local force = false
        if forceUpdate and name:sub(-4) == ".jpg" then
            local num = tonumber(name:sub(1, 3))
            force = num ~= nil and num >= DL_UPDATE_FROM and num <= DL_UPDATE_TO and not embeddedOk[num]
        end
        if force or not haveFile(DL_FOLDER .. "/" .. name) then table.insert(missing, name) end
    end

    if #missing > 0 then
        -- small progress screen
        local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
        local old = playerGui:FindFirstChild("HYD3Download")
        if old then old:Destroy() end
        local gui = Instance.new("ScreenGui")
        gui.Name = "HYD3Download"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999999
        gui.Parent = playerGui

        local bgf = Instance.new("Frame")
        bgf.Size = UDim2.fromScale(1, 1)
        bgf.BackgroundColor3 = Color3.new(0, 0, 0)
        bgf.BorderSizePixel = 0
        bgf.Parent = gui

        local label = Instance.new("TextLabel")
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Position = UDim2.fromScale(0.5, 0.45)
        label.Size = UDim2.fromOffset(500, 30)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 20
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "Downloading HYD video... 0 / " .. #missing
        label.Parent = bgf

        local track = Instance.new("Frame")
        track.AnchorPoint = Vector2.new(0.5, 0.5)
        track.Position = UDim2.fromScale(0.5, 0.52)
        track.Size = UDim2.fromOffset(360, 8)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        track.BorderSizePixel = 0
        track.Parent = bgf
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(0, 1)
        fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        fill.BorderSizePixel = 0
        fill.Parent = track

        local nextIndex, done, running = 0, 0, DL_THREADS
        local failed = {}

        local function worker()
            while true do
                nextIndex += 1
                local name = missing[nextIndex]
                if not name then return end
                local ok = false
                for attempt = 1, 3 do
                    for _, base in ipairs(DL_BASES) do
                        local body = fetch(base .. name)
                        if body and valid(name, body) then
                            writefile(DL_FOLDER .. "/" .. name, body)
                            ok = true
                            -- remember the base that worked so the next files try it first
                            if base ~= DL_BASES[1] then DL_BASES[1], DL_BASES[2] = DL_BASES[2], DL_BASES[1] end
                            break
                        end
                    end
                    if ok then break end
                    task.wait(0.3 * attempt)
                end
                if not ok then table.insert(failed, name) end
                done += 1
                label.Text = "Downloading HYD video... " .. done .. " / " .. #missing
                fill.Size = UDim2.fromScale(done / #missing, 1)
            end
        end

        for _ = 1, DL_THREADS do
            task.spawn(function()
                worker()
                running -= 1
            end)
        end
        while running > 0 do task.wait(0.1) end

        if #failed > 0 then
            warn("[HYD3] could not download: " .. table.concat(failed, ", ", 1, math.min(#failed, 10)) .. (#failed > 10 and " ..." or ""))
            warn("[HYD3] check DL_REPO and that your repo is public and has the files")
            label.TextColor3 = Color3.fromRGB(255, 90, 90)
            label.Text = "Download failed (" .. #failed .. " files) - see console"
            task.wait(5)
            gui:Destroy()
            return
        end
        gui:Destroy()
    end

    -- everything downloaded fine: remember the version so the updated frames are not downloaded again
    pcall(writefile, VERSION_FILE, DL_VERSION)
end

--// CONFIG (already set for your video: 361 single frames, 1024x576 each, 30 FPS)
local FOLDER       = "hyd3/"    -- workspace folder that holds 001.jpg ... 361.jpg and audio.mp3
local FRAME_COUNT  = 361
local FPS          = 30
local HOLD_SECONDS = 8          -- how long HYD DUELS + the PFP stay on screen after the video ends (0 = close right away)
local HOLD_FRAMES  = 22         -- frames 362-383 are a seamless loop used for the hold (do not change)
local LOOP         = false
local AUDIO        = true       -- plays audio.mp3 and keeps the video in sync with it
local RING         = 40         -- frames kept in memory at once
local AHEAD        = 30         -- frames loaded ahead of the playhead (30 frames = 1 second)

--// CINEMATIC EFFECTS (soft light shafts + smoke + dust)
local FX_ENABLED       = true
local FX_BEAMS         = 5                              -- number of light beams
local FX_BEAM_STRENGTH = 1                              -- 0 = invisible, 1 = normal, 2 = strong
local FX_BEAM_COLOR    = Color3.fromRGB(190, 215, 255)  -- light colour
local FX_PARTICLES     = 60                             -- number of floating dust particles
local FX_DUST_COLOR    = Color3.fromRGB(255, 235, 210)  -- particle colour
local FX_SMOKE         = true                           -- soft drifting smoke / fog
local FX_SMOKE_PUFFS   = 9                              -- how many smoke clouds
local FX_SMOKE_STRENGTH = 1                             -- 0 = invisible, 1 = normal, 2 = thick
local FX_SMOKE_COLOR   = Color3.fromRGB(165, 170, 200)  -- smoke colour

--// COLOUR GRADE (roblox cannot colour-correct a GUI image, so this is done with overlays)
local GRADE_ENABLED  = true
local GRADE_TINT     = 1      -- 0 = off, 1 = subtle teal/orange tint, 2 = stronger
local GRADE_VIGNETTE = 1      -- 0 = off, 1 = normal dark edges, 2 = strong
local BRIGHTNESS     = 1      -- 0 = off, 1 = a little brighter, 2 = brighter (keep it low, it lifts the blacks)

--// SERVICES
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local function frameName(i)
    return FOLDER .. string.format("%03d.jpg", i)
end

--// GUI (full screen)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SheetPlayerHYD3")
if old then old:Destroy() end

print("[HYD3] v4 running: simple SKIP button + soft light/smoke FX")
local gui = Instance.new("ScreenGui")
gui.Name = "SheetPlayerHYD3"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.Parent = gui

local FULL   = UDim2.fromScale(1, 1)
local HIDDEN = UDim2.fromOffset(4, 4)

local labels = {}
for i = 1, RING do
    local l = Instance.new("ImageLabel")
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    l.Position = UDim2.fromScale(0.5, 0.5)
    l.Size = HIDDEN
    l.ZIndex = 1
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.ScaleType = Enum.ScaleType.Fit
    l.Parent = bg
    labels[i] = l
end

--// BRIGHTNESS (soft white lift over the picture)
if BRIGHTNESS > 0 then
    local lift = Instance.new("Frame")
    lift.Name = "Brightness"
    lift.Size = UDim2.fromScale(1, 1)
    lift.BackgroundColor3 = Color3.new(1, 1, 1)
    lift.BackgroundTransparency = 1 - math.clamp(0.05 * BRIGHTNESS, 0, 0.2)
    lift.BorderSizePixel = 0
    lift.Active = false
    lift.ZIndex = 3
    lift.Parent = bg
end

--// SKIP BUTTON (top right): simple dark pill that says SKIP
local close = Instance.new("TextButton")
close.Name = "Skip"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -18, 0, 18)
close.Size = UDim2.fromOffset(96, 40)
close.AutoButtonColor = true
close.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
close.BackgroundTransparency = 0.15
close.BorderSizePixel = 0
close.Text = "SKIP"
close.Font = Enum.Font.GothamBold
close.TextSize = 17
close.TextColor3 = Color3.new(1, 1, 1)
close.ZIndex = 10
close.Parent = bg

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 20)
skipCorner.Parent = close

local skipStroke = Instance.new("UIStroke")
skipStroke.Thickness = 1.5
skipStroke.Transparency = 0.35
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
skipStroke.Color = Color3.new(1, 1, 1)
skipStroke.Parent = close

local skipConn -- (no animation on the button; stop() below still checks this)

--// COLOUR GRADE
if GRADE_ENABLED then
    local grade = Instance.new("Frame")
    grade.Name = "Grade"
    grade.Size = UDim2.fromScale(1, 1)
    grade.BackgroundTransparency = 1
    grade.BorderSizePixel = 0
    grade.Active = false
    grade.ZIndex = 4
    grade.Parent = bg

    -- teal (top) to warm orange (bottom) cinematic tint
    if GRADE_TINT > 0 then
        local tint = Instance.new("Frame")
        tint.Size = UDim2.fromScale(1, 1)
        tint.BackgroundColor3 = Color3.new(1, 1, 1)
        tint.BorderSizePixel = 0
        tint.ZIndex = 4
        tint.Parent = grade
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new(Color3.fromRGB(30, 110, 160), Color3.fromRGB(190, 100, 40))
        g.Transparency = NumberSequence.new(1 - math.clamp(0.07 * GRADE_TINT, 0, 0.3))
        g.Parent = tint
    end

    -- dark edges (vignette): four soft gradients, the corners get darker automatically
    if GRADE_VIGNETTE > 0 then
        local strength = math.clamp(0.5 * GRADE_VIGNETTE, 0, 0.9)
        local function edge(pos, size, rot)
            local f = Instance.new("Frame")
            f.Position = pos
            f.Size = size
            f.BackgroundColor3 = Color3.new(0, 0, 0)
            f.BorderSizePixel = 0
            f.ZIndex = 4
            f.Parent = grade
            local g = Instance.new("UIGradient")
            g.Rotation = rot
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1 - strength),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = f
        end
        edge(UDim2.fromScale(0, 0),    UDim2.fromScale(1, 0.3), 90)    -- top
        edge(UDim2.fromScale(0, 0.7),  UDim2.fromScale(1, 0.3), 270)   -- bottom
        edge(UDim2.fromScale(0, 0),    UDim2.fromScale(0.22, 1), 0)    -- left
        edge(UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180)  -- right
    end
end

--// CINEMATIC EFFECTS (soft light shafts, drifting smoke, floating dust)
local fxConn
if FX_ENABLED then
    local rng = Random.new()
    local cam = workspace.CurrentCamera
    local viewport = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
    local VW, VH = viewport.X, viewport.Y

    local fx = Instance.new("Frame")
    fx.Name = "FX"
    fx.Size = UDim2.fromScale(1, 1)
    fx.BackgroundTransparency = 1
    fx.BorderSizePixel = 0
    fx.ClipsDescendants = true
    fx.Active = false
    fx.ZIndex = 5
    fx.Parent = bg

    local function tr(alpha)
        return math.clamp(1 - alpha * FX_BEAM_STRENGTH, 0, 1)
    end

    -- very soft glow at the top where the light comes from
    do
        local haze = Instance.new("Frame")
        haze.Size = UDim2.fromScale(1, 0.55)
        haze.BackgroundColor3 = FX_BEAM_COLOR
        haze.BorderSizePixel = 0
        haze.ZIndex = 5
        haze.Parent = fx
        local hg = Instance.new("UIGradient")
        hg.Rotation = 90
        local kp = {}
        for k = 0, 10 do
            local x = k / 10
            kp[#kp + 1] = NumberSequenceKeypoint.new(x, tr(0.20 * (1 - x) ^ 2.2))
        end
        hg.Transparency = NumberSequence.new(kp)
        hg.Parent = haze
    end

    -- LIGHT SHAFTS: every beam is a few stacked layers with a smooth bell-shaped edge (no hard sides),
    -- layers get shorter so the beam fades out softly toward the bottom, and the light flickers slowly
    local function bellSequence(sharp)
        local kp = {}
        for k = 0, 12 do
            local x = k / 12
            local bell = math.exp(-(((x - 0.5) / sharp) ^ 2))
            if k == 0 or k == 12 then bell = 0 end
            kp[#kp + 1] = NumberSequenceKeypoint.new(x, 1 - bell)
        end
        return NumberSequence.new(kp)
    end
    local BELL_WIDE = bellSequence(0.26)
    local BELL_CORE = bellSequence(0.17)

    local LAYERS_PER_GROUP = 9
    local beams = {}
    local baseAngle = rng:NextNumber(12, 19)
    local LMAX = VH * 2.2
    for i = 1, FX_BEAMS do
        local bw = rng:NextNumber(120, 250) * (VW / 1280)
        local phi = baseAngle + (i - (FX_BEAMS + 1) / 2) * 2.4 + rng:NextNumber(-2.5, 2.5)
        local sx = (0.08 + 1.05 * (i - 0.5) / FX_BEAMS) * VW + rng:NextNumber(-0.04, 0.04) * VW
        local sy = -0.12 * VH
        local rad = math.rad(phi)
        local cx = sx + (LMAX / 2) * (-math.sin(rad))
        local cy = sy + (LMAX / 2) * math.cos(rad)

        local holder = Instance.new("Frame")
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.fromOffset(cx, cy)
        holder.Size = UDim2.fromOffset(bw * 2.6, LMAX)
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Rotation = phi
        holder.ZIndex = 5
        holder.Parent = fx

        local layers = {}
        local groups = {
            {width = bw * 2.2, bell = BELL_WIDE, total = 0.05, color = FX_BEAM_COLOR},
            {width = bw * 0.95, bell = BELL_CORE, total = 0.085, color = Color3.fromRGB(255, 244, 226):Lerp(FX_BEAM_COLOR, 0.35)},
        }
        for _, G in ipairs(groups) do
            for k = 1, LAYERS_PER_GROUP do
                local f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(0.5, 0)
                f.Position = UDim2.new(0.5, 0, 0, 0)
                f.Size = UDim2.fromOffset(G.width, VH * (0.45 + 1.75 * k / LAYERS_PER_GROUP))
                f.BackgroundColor3 = G.color
                f.BorderSizePixel = 0
                f.ZIndex = 5
                f.Parent = holder
                local g = Instance.new("UIGradient")
                g.Transparency = G.bell
                g.Parent = f
                table.insert(layers, {frame = f, a = G.total / LAYERS_PER_GROUP})
            end
        end

        beams[i] = {
            holder = holder,
            layers = layers,
            baseRot = phi,
            phase = rng:NextNumber(0, math.pi * 2),
            speed = rng:NextNumber(0.12, 0.35),
        }
    end

    -- SMOKE / FOG: soft blobs (stacked circles = smooth edge) that drift slowly, grow and fade in and out
    local RINGS = 7
    local puffs = {}
    local function respawn(p, first)
        p.life = rng:NextNumber(16, 28)
        p.age = first and rng:NextNumber(0, p.life) or 0
        p.w = rng:NextNumber(0.35, 0.75) * VW
        p.hr = rng:NextNumber(0.42, 0.6)
        p.x0 = rng:NextNumber(-0.1, 1.1) * VW
        p.y0 = rng:NextNumber(0.5, 1.0) * VH
        p.vx = rng:NextNumber(-0.012, 0.03) * VW
        p.vy = -rng:NextNumber(0.004, 0.02) * VH
        p.peak = rng:NextNumber(0.06, 0.12)
        p.grow = rng:NextNumber(0.25, 0.5)
        p.sway = rng:NextNumber(0.01, 0.03) * VW
        p.phase = rng:NextNumber(0, math.pi * 2)
    end
    if FX_SMOKE then
        for i = 1, FX_SMOKE_PUFFS do
            local holder = Instance.new("Frame")
            holder.AnchorPoint = Vector2.new(0.5, 0.5)
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.ZIndex = 5
            holder.Parent = fx
            local rings = {}
            for r = 1, RINGS do
                local f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(0.5, 0.5)
                f.Position = UDim2.fromScale(0.5, 0.5)
                local sc = 1 - (r - 1) * 0.12
                f.Size = UDim2.fromScale(sc, sc)
                f.BackgroundColor3 = FX_SMOKE_COLOR
                f.BackgroundTransparency = 1
                f.BorderSizePixel = 0
                f.ZIndex = 5
                f.Parent = holder
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(1, 0)
                c.Parent = f
                rings[r] = f
            end
            local p = {holder = holder, rings = rings}
            respawn(p, true)
            puffs[i] = p
        end
    end

    -- DUST: tiny motes at different depths (far = small + faint + slow, near = bigger + brighter), they twinkle
    local parts = {}
    local function resetParticle(p, anywhere)
        local d = rng:NextNumber(0, 1) ^ 1.6
        local size = 1.2 + d * 2.8
        p.frame.Size = UDim2.fromOffset(size, size)
        p.x = rng:NextNumber(0, 1)
        p.y = anywhere and rng:NextNumber(0, 1) or rng:NextNumber(-0.1, 0)
        p.speed = 0.012 + 0.05 * d            -- screen heights per second
        p.wind = rng:NextNumber(-0.012, 0.012) * (0.4 + d)
        p.drift = rng:NextNumber(0.004, 0.018)
        p.phase = rng:NextNumber(0, math.pi * 2)
        p.tw = rng:NextNumber(1.2, 3.5)
        p.base = 0.18 + 0.5 * d
    end
    for i = 1, FX_PARTICLES do
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = FX_DUST_COLOR
        f.BorderSizePixel = 0
        f.ZIndex = 6
        f.Parent = fx
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = f
        local p = {frame = f}
        resetParticle(p, true)
        parts[i] = p
    end

    local t = 0
    fxConn = RunService.Heartbeat:Connect(function(dt)
        t += dt

        for _, b in ipairs(beams) do
            -- slow, uneven flicker (two waves mixed) + tiny sway
            local I = 0.72 + 0.18 * math.sin(t * b.speed + b.phase) + 0.10 * math.sin(t * b.speed * 2.7 + b.phase * 1.9)
            b.holder.Rotation = b.baseRot + math.sin(t * b.speed * 0.6 + b.phase) * 1.2
            for _, L in ipairs(b.layers) do
                L.frame.BackgroundTransparency = math.clamp(1 - L.a * I * FX_BEAM_STRENGTH, 0, 1)
            end
        end

        for _, p in ipairs(puffs) do
            p.age += dt
            if p.age >= p.life then respawn(p, false) end
            local u = p.age / p.life
            local env = math.sin(math.pi * u) ^ 1.3
            local sc = 1 + p.grow * u
            p.holder.Size = UDim2.fromOffset(p.w * sc, p.w * p.hr * sc)
            p.holder.Position = UDim2.fromOffset(
                p.x0 + p.vx * p.age + math.sin(t * 0.15 + p.phase) * p.sway,
                p.y0 + p.vy * p.age
            )
            local ringAlpha = math.clamp(p.peak * env * FX_SMOKE_STRENGTH * 0.18, 0, 0.2)
            local tp = 1 - ringAlpha
            for _, f in ipairs(p.rings) do
                f.BackgroundTransparency = tp
            end
        end

        for _, p in ipairs(parts) do
            p.y += (p.speed + math.sin(t * 0.4 + p.phase) * 0.006) * dt
            p.x += p.wind * dt
            if p.y > 1.05 then resetParticle(p, false) end
            if p.x > 1.05 then p.x = -0.05 elseif p.x < -0.05 then p.x = 1.05 end
            local x = p.x + math.sin(t * 0.7 + p.phase) * p.drift
            p.frame.Position = UDim2.fromScale(x, p.y)
            local fade = math.clamp(p.y / 0.1, 0, 1) * math.clamp((1 - p.y) / 0.15, 0, 1)
            local tw = 0.7 + 0.3 * math.sin(t * p.tw + p.phase)
            p.frame.BackgroundTransparency = 1 - p.base * fade * tw
        end
    end)
end

--// FRAME LOADING
local slotFrame = {}
local slotTime  = {}

local function slotFor(n)
    return (n % RING) + 1
end

local function assign(n)
    if n < 1 or n > FRAME_COUNT + HOLD_FRAMES then return end
    local slot = slotFor(n)
    if slotFrame[slot] == n then return end
    if isfile then
        local okf, res = pcall(isfile, frameName(n))
        if okf and not res then
            warn("MISSING FILE (not in your executor workspace): " .. frameName(n))
        end
    end
    local ok, asset = pcall(getcustomasset, frameName(n))
    if ok and asset and asset ~= "" then
        labels[slot].Image = asset
    else
        warn("Failed to load " .. frameName(n) .. ": " .. tostring(asset))
    end
    slotFrame[slot] = n
    slotTime[slot] = os.clock()
end

-- a frame is only shown once it is really loaded (no black flashes)
local function isReady(slot)
    local l = labels[slot]
    return l.IsLoaded or l.ContentImageSize.X > 0 or (slotTime[slot] ~= nil and os.clock() - slotTime[slot] > 0.05)
end

local function reallyLoaded(slot)
    local l = labels[slot]
    return l.IsLoaded or l.ContentImageSize.X > 0
end

-- load the first frames before starting so playback never waits (max 3 seconds)
for n = 1, AHEAD + 1 do assign(n) end
local t0 = os.clock()
while os.clock() - t0 < 3 do
    local allReady = true
    for n = 1, math.min(15, FRAME_COUNT) do
        if not reallyLoaded(slotFor(n)) then allReady = false break end
    end
    if allReady then break end
    task.wait()
end

--// AUDIO
local sound
if AUDIO then
    local ok, asset = pcall(getcustomasset, FOLDER .. "audio.mp3")
    if ok and asset and asset ~= "" then
        sound = Instance.new("Sound")
        sound.SoundId = asset
        sound.Volume = 1
        sound.Parent = SoundService
        local t1 = os.clock()
        while not sound.IsLoaded and os.clock() - t1 < 2 do task.wait() end
        if sound.IsLoaded then
            sound:Play()
        else
            warn("audio.mp3 did not load, playing without sound")
            sound:Destroy()
            sound = nil
        end
    else
        warn("Could not load " .. FOLDER .. "audio.mp3")
    end
end

--// PLAYBACK
local frame = 0
local shownSlot
local conn

local function stop()
    if conn then conn:Disconnect() end
    if fxConn then fxConn:Disconnect() end
    if skipConn then skipConn:Disconnect() end
    if sound then sound:Stop() sound:Destroy() end
    gui:Destroy()
end
close.MouseButton1Click:Connect(stop)

conn = RunService.RenderStepped:Connect(function(dt)
    frame += math.min(dt, 0.1) * FPS

    -- the audio is the master clock, so picture and sound stay in sync
    if sound and sound.IsPlaying then
        local audioFrame = sound.TimePosition * FPS
        if math.abs(frame - audioFrame) > 3 then
            frame = audioFrame
        end
    end

    local f = math.floor(frame)
    if f >= FRAME_COUNT then
        if LOOP then
            frame, f = 0, 0
            if sound then sound.TimePosition = 0 end
        elseif HOLD_SECONDS > 0 then
            -- the video is over: keep HYD DUELS + the PFP on screen by looping the last animated frames
            local held = frame - FRAME_COUNT
            if held >= HOLD_SECONDS * FPS then
                stop()
                return
            end
            f = FRAME_COUNT + (math.floor(held) % HOLD_FRAMES)
        else
            stop()
            return
        end
    end

    local n = f + 1
    assign(n)
    local slot = slotFor(n)

    -- show the new frame first, then hide the old one (never an empty screen)
    if shownSlot ~= slot and isReady(slot) then
        labels[slot].ZIndex = 2
        labels[slot].Size = FULL
        if shownSlot then
            labels[shownSlot].Size = HIDDEN
            labels[shownSlot].ZIndex = 1
        end
        shownSlot = slot
    end

    -- keep the next frames loaded ahead of time
    for k = 1, AHEAD do
        assign(n + k)
    end
end)
