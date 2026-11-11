--// HYD3 AUTO LOADER: downloads the 361 frames + audio into workspace/hyd3 (only what is missing), then plays the video
--// EDIT THIS LINE ONLY: your GitHub username and repo name, like "ExampleUser/hyd" (the repo must be public)
local DL_REPO     = "YOURNAME/YOURREPO"
local DL_BRANCH   = "main"
-- it tries the main folder of the repo first, then a folder called hyd3, so both upload layouts work
local DL_BASES = {
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/",
    "https://raw.githubusercontent.com/" .. DL_REPO .. "/" .. DL_BRANCH .. "/hyd3/",
}
local DL_FOLDER   = "hyd3"
local DL_FRAMES   = 361
local DL_THREADS  = 8      -- downloads at the same time (lower it to 4 if GitHub rate-limits you)

do
    local Players = game:GetService("Players")

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

    local missing = {}
    for _, name in ipairs(names) do
        if not haveFile(DL_FOLDER .. "/" .. name) then table.insert(missing, name) end
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
end

--// CONFIG (already set for your video: 361 single frames, 1024x576 each, 30 FPS)
local FOLDER       = "hyd3/"    -- workspace folder that holds 001.jpg ... 361.jpg and audio.mp3
local FRAME_COUNT  = 361
local FPS          = 30
local LOOP         = false
local AUDIO        = true       -- plays audio.mp3 and keeps the video in sync with it
local RING         = 40         -- frames kept in memory at once
local AHEAD        = 30         -- frames loaded ahead of the playhead (30 frames = 1 second)

--// CINEMATIC EFFECTS (light beams from the top + dust falling down)
local FX_ENABLED       = true
local FX_BEAMS         = 5                              -- number of light beams
local FX_BEAM_STRENGTH = 1                              -- 0 = invisible, 1 = normal, 2 = strong
local FX_BEAM_COLOR    = Color3.fromRGB(190, 215, 255)  -- light colour
local FX_PARTICLES     = 45                             -- number of falling particles
local FX_DUST_COLOR    = Color3.fromRGB(255, 235, 210)  -- particle colour

--// COLOUR GRADE (roblox cannot colour-correct a GUI image, so this is done with overlays)
local GRADE_ENABLED  = true
local GRADE_TINT     = 1      -- 0 = off, 1 = subtle teal/orange tint, 2 = stronger
local GRADE_VIGNETTE = 1      -- 0 = off, 1 = normal dark edges, 2 = strong

--// SERVICES
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local function frameName(i)
    return FOLDER .. string.format("%03d.jpg", i)
end

--// GUI (full screen)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SheetPlayerHYD3")
if old then old:Destroy() end

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

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(50, 50)
close.Position = UDim2.new(1, -50, 0, 0)
close.Text = "X"
close.TextSize = 24
close.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
close.TextColor3 = Color3.new(1, 1, 1)
close.ZIndex = 10
close.Parent = bg

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

--// CINEMATIC EFFECTS
local fxConn
if FX_ENABLED then
    local rng = Random.new()

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

    -- soft glow at the very top (where the light comes from)
    local haze = Instance.new("Frame")
    haze.Size = UDim2.fromScale(1, 0.4)
    haze.BackgroundColor3 = FX_BEAM_COLOR
    haze.BorderSizePixel = 0
    haze.ZIndex = 5
    haze.Parent = fx
    local hg = Instance.new("UIGradient")
    hg.Rotation = 90
    hg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, tr(0.25)),
        NumberSequenceKeypoint.new(1, 1),
    })
    hg.Parent = haze

    -- light beams: 3 stacked layers per beam (wide + faint, narrow + bright) for soft edges
    local LAYERS = {
        {width = 1.00, alpha = 0.06},
        {width = 0.55, alpha = 0.10},
        {width = 0.22, alpha = 0.16},
    }
    local beams = {}
    for i = 1, FX_BEAMS do
        local w = rng:NextInteger(70, 190)
        local holder = Instance.new("Frame")
        holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.fromScale((i - 0.5) / FX_BEAMS + rng:NextNumber(-0.05, 0.05), 0.72)
        holder.Size = UDim2.new(0, w, 1.6, 0)
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Rotation = rng:NextNumber(10, 22)
        holder.ZIndex = 5
        holder.Parent = fx

        local layerFrames = {}
        for _, L in ipairs(LAYERS) do
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale(0.5, 0.5)
            f.Size = UDim2.new(L.width, 0, 1, 0)
            f.BackgroundColor3 = FX_BEAM_COLOR
            f.BorderSizePixel = 0
            f.ZIndex = 5
            f.Parent = holder
            local g = Instance.new("UIGradient")
            g.Rotation = 90
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, tr(L.alpha)),
                NumberSequenceKeypoint.new(0.55, tr(L.alpha * 0.35)),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = f
            table.insert(layerFrames, f)
        end

        beams[i] = {
            holder = holder,
            layers = layerFrames,
            baseRot = holder.Rotation,
            phase = rng:NextNumber(0, math.pi * 2),
            speed = rng:NextNumber(0.2, 0.5),
        }
    end

    -- falling particles
    local parts = {}
    local function resetParticle(p, anywhere)
        local size = rng:NextInteger(2, 5)
        p.frame.Size = UDim2.fromOffset(size, size)
        p.x = rng:NextNumber(0, 1)
        p.y = anywhere and rng:NextNumber(0, 1) or rng:NextNumber(-0.1, 0)
        p.speed = rng:NextNumber(0.04, 0.13)   -- screen heights per second
        p.drift = rng:NextNumber(0.005, 0.02)
        p.phase = rng:NextNumber(0, math.pi * 2)
        p.base = rng:NextNumber(0.25, 0.7)
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
            b.holder.Rotation = b.baseRot + math.sin(t * b.speed + b.phase) * 3
            local pulse = 0.15 * (1 + math.sin(t * b.speed * 1.7 + b.phase))
            for _, f in ipairs(b.layers) do
                f.BackgroundTransparency = pulse
            end
        end
        for _, p in ipairs(parts) do
            p.y += p.speed * dt
            if p.y > 1.05 then resetParticle(p, false) end
            local x = p.x + math.sin(t * 0.8 + p.phase) * p.drift
            p.frame.Position = UDim2.fromScale(x, p.y)
            -- fade in at the top, fade out at the bottom
            local fade = math.clamp(p.y / 0.1, 0, 1) * math.clamp((1 - p.y) / 0.15, 0, 1)
            p.frame.BackgroundTransparency = 1 - (1 - p.base) * fade
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
    if n < 1 or n > FRAME_COUNT then return end
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
