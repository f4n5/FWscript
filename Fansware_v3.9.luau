--==============================================================
-- Fanware | Best script (fixed v3.9 — free timed config + ads unlock)
-- Discord: https://discord.gg/g9UAV8xC2p
--==============================================================
-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--==============================================================
-- FREE TIMED CONFIG
-- tag in export: [time: 12h]  (h hours / m minutes)
-- default free window 12h → then config dies, all toggles off
-- next free window after 5h cooldown + 5 ads
--==============================================================
local FREE_DEFAULT_SECONDS = 12 * 3600
local FREE_COOLDOWN_SECONDS = 5 * 3600
local FREE_ADS_REQUIRED = 5
local FREE_STATE_FILE = "Fanware_FreeState.txt"

local FreeConfig = {
    Active = false,
    ExpiresAt = 0,          -- os.time()
    CooldownUntil = 0,      -- os.time()
    AdsWatched = 0,
    DurationSeconds = FREE_DEFAULT_SECONDS,
    SourceTag = nil,        -- raw [time: ...] if present
}

local function ParseTimeTag(raw)
    if type(raw) ~= "string" then return nil end
    local num, unit = raw:match("%[time:%s*(%d+)%s*([hHmM])%s*%]")
    if not num then return nil end
    num = tonumber(num)
    if not num or num <= 0 then return nil end
    unit = unit:lower()
    if unit == "h" then
        return num * 3600, string.format("[time: %dh]", num)
    end
    return num * 60, string.format("[time: %dm]", num)
end

local function StripTimeTag(raw)
    if type(raw) ~= "string" then return raw end
    return (raw:gsub("%[time:%s*%d+%s*[hHmM]%s*%]", ""))
end

local function LoadFreeState()
    pcall(function()
        if not (isfile and readfile) then return end
        if not isfile(FREE_STATE_FILE) then return end
        local body = readfile(FREE_STATE_FILE)
        local ok, t = pcall(function()
            return loadstring("return " .. body)()
        end)
        if ok and type(t) == "table" then
            FreeConfig.ExpiresAt = tonumber(t.ExpiresAt) or 0
            FreeConfig.CooldownUntil = tonumber(t.CooldownUntil) or 0
            FreeConfig.AdsWatched = tonumber(t.AdsWatched) or 0
            FreeConfig.DurationSeconds = tonumber(t.DurationSeconds) or FREE_DEFAULT_SECONDS
            FreeConfig.Active = FreeConfig.ExpiresAt > os.time()
        end
    end)
end

local function SaveFreeState()
    pcall(function()
        if not writefile then return end
        local s = string.format(
            "{ExpiresAt=%d,CooldownUntil=%d,AdsWatched=%d,DurationSeconds=%d}",
            FreeConfig.ExpiresAt or 0,
            FreeConfig.CooldownUntil or 0,
            FreeConfig.AdsWatched or 0,
            FreeConfig.DurationSeconds or FREE_DEFAULT_SECONDS
        )
        writefile(FREE_STATE_FILE, s)
    end)
end

local function NotifyFree(msg, color)
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "FanwareFreeNotify"
        g.ResetOnSpawn = false
        g.Parent = CoreGui
        local f = Instance.new("TextLabel")
        f.Size = UDim2.new(0, 360, 0, 44)
        f.Position = UDim2.new(0.5, -180, 0.12, 0)
        f.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        f.TextColor3 = color or Color3.fromRGB(180, 220, 255)
        f.Font = Enum.Font.GothamMedium
        f.TextSize = 13
        f.Text = "  " .. tostring(msg)
        f.Parent = g
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(70, 90, 140)
        s.Thickness = 1
        s.Parent = f
        task.delay(3.2, function() g:Destroy() end)
    end)
end

local function FormatRemain(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then
        return string.format("%dh %dm", h, m)
    end
    if m > 0 then
        return string.format("%dm %ds", m, s)
    end
    return string.format("%ds", s)
end

-- forward decl — filled after Features exists
local DeactivateAllFeatures
local RefreshFreeStatusLabel

local function StartFreeWindow(durationSeconds, tag)
    durationSeconds = durationSeconds or FREE_DEFAULT_SECONDS
    FreeConfig.DurationSeconds = durationSeconds
    FreeConfig.ExpiresAt = os.time() + durationSeconds
    FreeConfig.CooldownUntil = 0
    FreeConfig.AdsWatched = 0
    FreeConfig.Active = true
    FreeConfig.SourceTag = tag
    SaveFreeState()
    NotifyFree("Free config active — " .. FormatRemain(durationSeconds) .. " left", Color3.fromRGB(140, 255, 180))
    if RefreshFreeStatusLabel then RefreshFreeStatusLabel() end
end

local function ExpireFreeConfig(reason)
    if not FreeConfig.Active and FreeConfig.ExpiresAt <= os.time() then
        -- already dead
    end
    FreeConfig.Active = false
    FreeConfig.ExpiresAt = 0
    FreeConfig.CooldownUntil = os.time() + FREE_COOLDOWN_SECONDS
    FreeConfig.AdsWatched = 0
    SaveFreeState()
    if DeactivateAllFeatures then
        DeactivateAllFeatures()
    end
    NotifyFree(reason or "Free config expired — all features off", Color3.fromRGB(255, 160, 120))
    if RefreshFreeStatusLabel then RefreshFreeStatusLabel() end
end

local function CanStartNewFreeWindow()
    local now = os.time()
    if FreeConfig.Active and FreeConfig.ExpiresAt > now then
        return false, "already active (" .. FormatRemain(FreeConfig.ExpiresAt - now) .. " left)"
    end
    if FreeConfig.CooldownUntil > now then
        return false, "cooldown " .. FormatRemain(FreeConfig.CooldownUntil - now)
    end
    if FreeConfig.AdsWatched < FREE_ADS_REQUIRED then
        return false, string.format("need %d/%d ads", FreeConfig.AdsWatched, FREE_ADS_REQUIRED)
    end
    return true, nil
end

local function WatchOneAd()
    local now = os.time()
    if FreeConfig.Active and FreeConfig.ExpiresAt > now then
        NotifyFree("window still active — ads not needed", Color3.fromRGB(200, 200, 120))
        return
    end
    if FreeConfig.CooldownUntil > now then
        NotifyFree("cooldown " .. FormatRemain(FreeConfig.CooldownUntil - now) .. " — wait first", Color3.fromRGB(255, 180, 120))
        return
    end
    -- simulated ad gate (placeholder player)
    local done = Instance.new("BindableEvent")
    local g = Instance.new("ScreenGui")
    g.Name = "FanwareAd"
    g.ResetOnSpawn = false
    g.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 180)
    frame.Position = UDim2.new(0.5, -170, 0.5, -90)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    frame.Parent = g
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Watch Ad (" .. (FreeConfig.AdsWatched + 1) .. "/" .. FREE_ADS_REQUIRED .. ")"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -20, 0, 50)
    body.Position = UDim2.new(0, 10, 0, 44)
    body.BackgroundTransparency = 1
    body.Text = "Simulated ad. Stand by 4s then claim.\n(Replace with real ad SDK later)"
    body.TextColor3 = Color3.fromRGB(180, 180, 195)
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Parent = frame
    local claim = Instance.new("TextButton")
    claim.Size = UDim2.new(1, -20, 0, 36)
    claim.Position = UDim2.new(0, 10, 1, -48)
    claim.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    claim.Text = "Wait..."
    claim.TextColor3 = Color3.fromRGB(160, 160, 170)
    claim.Font = Enum.Font.GothamMedium
    claim.TextSize = 13
    claim.AutoButtonColor = false
    claim.Parent = frame
    Instance.new("UICorner", claim).CornerRadius = UDim.new(0, 6)
    local unlocked = false
    task.delay(4, function()
        if not claim.Parent then return end
        unlocked = true
        claim.BackgroundColor3 = Color3.fromRGB(50, 120, 70)
        claim.TextColor3 = Color3.fromRGB(255, 255, 255)
        claim.Text = "Claim reward"
        claim.AutoButtonColor = true
    end)
    claim.MouseButton1Click:Connect(function()
        if not unlocked then return end
        FreeConfig.AdsWatched = math.min(FREE_ADS_REQUIRED, (FreeConfig.AdsWatched or 0) + 1)
        SaveFreeState()
        g:Destroy()
        if FreeConfig.AdsWatched >= FREE_ADS_REQUIRED then
            NotifyFree("ads done — free window ready", Color3.fromRGB(140, 255, 180))
        else
            NotifyFree(string.format("ad %d/%d claimed", FreeConfig.AdsWatched, FREE_ADS_REQUIRED), Color3.fromRGB(180, 220, 255))
        end
        if RefreshFreeStatusLabel then RefreshFreeStatusLabel() end
        done:Fire()
    end)
    return done.Event
end

LoadFreeState()
-- if leftover expired window, force clean + start cooldown if not set
do
    local now = os.time()
    if FreeConfig.ExpiresAt > 0 and FreeConfig.ExpiresAt <= now then
        FreeConfig.Active = false
        if FreeConfig.CooldownUntil < now then
            -- already past cooldown; leave ads progress as-is so user can finish ads
        end
        FreeConfig.ExpiresAt = 0
        SaveFreeState()
    elseif FreeConfig.ExpiresAt > now then
        FreeConfig.Active = true
    end
end

-- tick: kill features the moment free window ends
task.spawn(function()
    while true do
        task.wait(1)
        if FreeConfig.Active then
            local left = FreeConfig.ExpiresAt - os.time()
            if left <= 0 then
                ExpireFreeConfig("Free config time up — features disabled")
            elseif RefreshFreeStatusLabel then
                -- light refresh every ~15s
                if left % 15 == 0 then
                    RefreshFreeStatusLabel()
                end
            end
        end
    end
end)

--==============================================================
-- CLEANUP OLD INSTANCES
--==============================================================
pcall(function()
    if CoreGui:FindFirstChild("FanwareUI") then
        CoreGui.FanwareUI:Destroy()
    end
    if CoreGui:FindFirstChild("FanwareNotify") then
        CoreGui.FanwareNotify:Destroy()
    end
    if CoreGui:FindFirstChild("FanwareLoading") then
        CoreGui.FanwareLoading:Destroy()
    end
end)

--==============================================================
-- MAIN GUI
--==============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FanwareUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = CoreGui

--==============================================================
-- UTILITIES
--==============================================================
local function new(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local function corner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or Color3.fromRGB(60, 60, 70),
        Thickness = thickness or 1,
        Parent = parent
    })
end

--==============================================================
-- 1. WELCOME NOTIFICATION
--==============================================================
local NotifyGui = new("ScreenGui", {
    Name = "FanwareNotify",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Parent = CoreGui
})

local notify = new("Frame", {
    Parent = NotifyGui,
    Size = UDim2.new(0, 300, 0, 70),
    Position = UDim2.new(1, 320, 1, -100),
    BackgroundColor3 = Color3.fromRGB(20, 20, 26),
    BorderSizePixel = 0,
})
corner(notify, 10)
stroke(notify, Color3.fromRGB(90, 90, 110), 1)

new("TextLabel", {
    Parent = notify,
    Size = UDim2.new(1, -20, 1, -20),
    Position = UDim2.new(0, 10, 0, 10),
    BackgroundTransparency = 1,
    Text = "Welcome " .. LocalPlayer.Name .. " to ware scripts",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamMedium,
    TextSize = 15,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
})

TweenService:Create(notify, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {
    Position = UDim2.new(1, -320, 1, -100)
}):Play()

task.wait(3)
TweenService:Create(notify, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {
    Position = UDim2.new(1, 320, 1, -100)
}):Play()
task.wait(0.5)
NotifyGui:Destroy()

--==============================================================
-- 2. LOADING SCREEN
--==============================================================
local LoadGui = new("ScreenGui", {
    Name = "FanwareLoading",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    Parent = CoreGui
})

local loadFrame = new("Frame", {
    Parent = LoadGui,
    Size = UDim2.new(0, 260, 0, 120),
    Position = UDim2.new(0.5, -130, 0.5, -60),
    BackgroundColor3 = Color3.fromRGB(18, 18, 24),
    BorderSizePixel = 0,
})
corner(loadFrame, 12)
stroke(loadFrame, Color3.fromRGB(90, 90, 110), 1)

local spinner = new("Frame", {
    Parent = loadFrame,
    Size = UDim2.new(0, 34, 0, 34),
    Position = UDim2.new(0.5, -17, 0, 18),
    BackgroundColor3 = Color3.fromRGB(60, 130, 255),
    BorderSizePixel = 0,
})
corner(spinner, 17)

new("TextLabel", {
    Parent = loadFrame,
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 68),
    BackgroundTransparency = 1,
    Text = "Loading script, please wait...",
    TextColor3 = Color3.fromRGB(230, 230, 235),
    Font = Enum.Font.Gotham,
    TextSize = 14,
})

local spinning = true
task.spawn(function()
    while spinning do
        spinner.Rotation = spinner.Rotation + 6
        task.wait(0.02)
    end
end)

task.wait(2)
spinning = false
LoadGui:Destroy()

--==============================================================
-- 3. MAIN MENU
--==============================================================
local main = new("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 520, 0, 360),
    Position = UDim2.new(0.5, -260, 0.5, -180),
    BackgroundColor3 = Color3.fromRGB(18, 18, 24),
    BorderSizePixel = 0,
    Active = true,
    Visible = true,
    ZIndex = 1,
})
corner(main, 12)
stroke(main, Color3.fromRGB(90, 90, 110), 1)

local topBar = new("Frame", {
    Parent = main,
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Color3.fromRGB(24, 24, 32),
    BorderSizePixel = 0,
    ZIndex = 2,
})
corner(topBar, 12)

new("Frame", {
    Parent = topBar,
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Color3.fromRGB(24, 24, 32),
    BorderSizePixel = 0,
    ZIndex = 2,
})

new("TextLabel", {
    Parent = topBar,
    Size = UDim2.new(1, -20, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "Fanware  •  ware scripts",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
})

new("TextLabel", {
    Parent = topBar,
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(1, -130, 0, 0),
    BackgroundTransparency = 1,
    Text = "RShift menu | P aim | Q ultra",
    TextColor3 = Color3.fromRGB(140, 140, 155),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 3,
})

local tabBar = new("Frame", {
    Parent = main,
    Size = UDim2.new(0, 130, 1, -60),
    Position = UDim2.new(0, 10, 0, 50),
    BackgroundTransparency = 1,
    ZIndex = 2,
})

local content = new("Frame", {
    Parent = main,
    Size = UDim2.new(1, -160, 1, -60),
    Position = UDim2.new(0, 150, 0, 50),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    BorderSizePixel = 0,
    ZIndex = 2,
})
corner(content, 8)
stroke(content, Color3.fromRGB(45, 45, 55), 1)

--==============================================================
-- TAB SYSTEM
--==============================================================
local tabs = {}
local activeTab = nil
local tabNames = {"Combat", "Players", "Misc.", "Coils", "Skins", "Presets", "Settings"}

local function createPage(name)
    local page = new("ScrollingFrame", {
        Parent = content,
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(90, 90, 110),
        Visible = false,
        ZIndex = 3,
    })
    new("UIListLayout", {
        Parent = page,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    return page
end

local function selectTab(name)
    for n, data in pairs(tabs) do
        data.button.BackgroundColor3 = (n == name)
            and Color3.fromRGB(50, 90, 200)
            or Color3.fromRGB(28, 28, 36)
        data.page.Visible = (n == name)
    end
    activeTab = name
end

new("UIListLayout", {
    Parent = tabBar,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

for i, name in ipairs(tabNames) do
    local btn = new("TextButton", {
        Parent = tabBar,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        AutoButtonColor = false,
        LayoutOrder = i,
        ZIndex = 3,
    })
    corner(btn, 8)
    local page = createPage(name)
    tabs[name] = {button = btn, page = page}
    btn.MouseButton1Click:Connect(function()
        selectTab(name)
    end)
end
selectTab("Combat")

--==============================================================
-- UI ELEMENT HELPERS
--==============================================================
local yOffset = {}

local function addRow(page, height)
    yOffset[page] = (yOffset[page] or 0) + (height or 30) + 6
    page.CanvasSize = UDim2.new(0, 0, 0, yOffset[page])
end

local function makeToggle(page, label, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(holder, 6)
    addRow(page, 30)

    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })

    local state = default or false
    local track = new("Frame", {
        Parent = holder,
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = state and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70),
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    corner(track, 10)

    local knob = new("Frame", {
        Parent = track,
        Size = UDim2.new(0, 16, 0, 16),
        Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(knob, 8)

    local click = new("TextButton", {
        Parent = holder,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
    })

    click.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        if callback then callback(state) end
    end)

    return {
        Set = function(v)
            state = v
            track.BackgroundColor3 = v and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(60, 60, 70)
            knob.Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end,
        Get = function() return state end
    }
end

local activeDropdownList = nil

local function makeDropdown(page, label, options, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(holder, 6)
    addRow(page, 30)

    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })

    local selected = default or options[1]
    local btn = new("TextButton", {
        Parent = holder,
        Size = UDim2.new(0, 120, 0, 22),
        Position = UDim2.new(1, -130, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        BorderSizePixel = 0,
        Text = selected,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 4,
    })
    corner(btn, 6)

    local open = false
    local function closeMenu()
        if activeDropdownList then
            activeDropdownList:Destroy()
            activeDropdownList = nil
        end
        open = false
    end

    btn.MouseButton1Click:Connect(function()
        if open then
            closeMenu()
        else
            if activeDropdownList then activeDropdownList:Destroy() end
            open = true
            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            local list = new("Frame", {
                Parent = ScreenGui,
                Size = UDim2.new(0, absSize.X, 0, #options * 24),
                Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 2),
                BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                BorderSizePixel = 0,
                ZIndex = 100,
            })
            corner(list, 6)
            stroke(list, Color3.fromRGB(70, 70, 85), 1)
            new("UIListLayout", {
                Parent = list,
                SortOrder = Enum.SortOrder.LayoutOrder,
            })
            for _, opt in ipairs(options) do
                local ob = new("TextButton", {
                    Parent = list,
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                    BorderSizePixel = 0,
                    Text = opt,
                    TextColor3 = Color3.fromRGB(220, 220, 225),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    ZIndex = 101,
                })
                ob.MouseButton1Click:Connect(function()
                    selected = opt
                    btn.Text = opt
                    if callback then callback(opt) end
                    closeMenu()
                end)
            end
            activeDropdownList = list
        end
    end)

    return {
        Get = function() return selected end,
        Set = function(v) selected = v btn.Text = v if callback then callback(v) end end
    }
end

local function makeSlider(page, label, min, max, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(holder, 6)
    addRow(page, 44)

    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.6, 0, 0, 18),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })

    local val = default or min
    local valLabel = new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.4, -10, 0, 18),
        Position = UDim2.new(0.6, 0, 0, 4),
        BackgroundTransparency = 1,
        Text = tostring(val),
        TextColor3 = Color3.fromRGB(140, 180, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
    })

    local bar = new("Frame", {
        Parent = holder,
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 1, -14),
        BackgroundColor3 = Color3.fromRGB(45, 45, 55),
        BorderSizePixel = 0,
        ZIndex = 4,
    })
    corner(bar, 3)

    local fill = new("Frame", {
        Parent = bar,
        Size = UDim2.new((val - min) / math.max(max - min, 1), 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(50, 90, 200),
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(fill, 3)

    local function applyVal(v, fire)
        val = math.clamp(tonumber(v) or min, min, max)
        local rel = (val - min) / math.max(max - min, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        -- pretty print floats
        if math.abs(val - math.floor(val)) > 0.0001 then
            valLabel.Text = string.format("%.3f", val)
        else
            valLabel.Text = tostring(math.floor(val + 0.5))
        end
        if fire and callback then callback(val) end
    end

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            local raw = min + (max - min) * rel
            -- integer if range looks int
            if (max - min) >= 5 and min == math.floor(min) and max == math.floor(max) then
                applyVal(math.floor(raw + 0.5), true)
            else
                applyVal(raw, true)
            end
        end
    end)

    return {
        Get = function() return val end,
        Set = function(v) applyVal(v, false) end
    }
end

local function makeKeybind(page, label, default, callback)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(holder, 6)
    addRow(page, 30)

    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })

    local key = default
    local waiting = false
    local btn = new("TextButton", {
        Parent = holder,
        Size = UDim2.new(0, 90, 0, 22),
        Position = UDim2.new(1, -100, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(40, 40, 50),
        BorderSizePixel = 0,
        Text = key or "[None]",
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ZIndex = 4,
    })
    corner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        waiting = true
        btn.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if waiting and not gp then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                key = input.KeyCode.Name
                btn.Text = key
                waiting = false
                if callback then callback(key) end
            end
        end
    end)

    return {
        Get = function() return key end
    }
end

local function makeButton(page, label, callback)
    local btn = new("TextButton", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(40, 40, 52),
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = Color3.fromRGB(230, 230, 235),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        AutoButtonColor = true,
        ZIndex = 3,
    })
    corner(btn, 6)
    addRow(page, 32)
    btn.MouseButton1Click:Connect(callback)
    return btn
end


local function makeSection(page, title)
    local holder = new("Frame", {
        Parent = page,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(20, 20, 28),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(holder, 6)
    addRow(page, 26)
    new("TextLabel", {
        Parent = holder,
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = string.upper(title),
        TextColor3 = Color3.fromRGB(140, 170, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
end

local UIRefs = {} -- name -> {Set=fn, Get=fn, Kind="toggle"|"slider"|"dropdown"}
local function registerUI(name, ref, kind)
    if ref then
        UIRefs[name] = {ref = ref, kind = kind or "toggle"}
    end
    return ref
end

local function SyncUIFromFeatures()
    for name, entry in pairs(UIRefs) do
        local ref = entry.ref
        local v = Features[name]
        if v ~= nil then
            if entry.kind == "toggle" and ref.Set then
                ref.Set(v and true or false)
            elseif entry.kind == "slider" and ref.Set then
                ref.Set(v)
            elseif entry.kind == "dropdown" and ref.Set then
                ref.Set(tostring(v))
            end
        end
    end
end

--==============================================================
-- FEATURES
--==============================================================
local Features = {
    Aimbot = false,
    AimbotTarget = "Head",
    AimbotSmoothness = 5,
    AimbotFOV = 350,
    AimbotMaxDist = 800,
    AimbotWallCheck = true,
    AimbotTeamCheck = true,

    TriggerBot = false,
    TriggerBotDelay = 0.05,
    TriggerBotAcquire = 0.12,
    TriggerBotWallCheck = true,
    TriggerBotTeamCheck = true,

    DeathLock = false,
    DeathLockTarget = "Head",
    DeathLockWallCheck = true,
    DeathLockTeamCheck = true,
    DeathLockUltra = false,
    DeathLockUltraTarget = "Mixed",
    DeathLockUltraWallCheck = true,
    DeathLockUltraTeamCheck = true,
    AimbotStickiness = 5,

    AutoShoot = false,
    AutoShootDelay = 0.07,
    AutoShootAcquire = 0.15,
    AutoShootTeamCheck = true,

    ESP = false,
    Boxes = false,
    Skeleton = false,
    Tracers = false,
    ShowLife = false,
    ShowNames = false,
    TracerColor = Color3.fromRGB(255, 255, 255),
    BoxColor = Color3.fromRGB(255, 255, 255),

    -- Rage (new)
    TPBehind = false,
    TPUp = false,
    InstaBackstab = false,

    SpeedHack = false,
    SpeedPower = 60,

    Noclip = false,

    Fly = false,
    FlySpeed = 50,
    SpinBot = false,
    SpinSpeed = 15,
    JoinPlayer = false,
    JoinUsername = "",
    NotifyRivals = true,
    AutoSaveConfig = false,
    AutoExecute = false,

    NoMeleeCooldown = false,
    NoScopeCooldown = false,

    -- Visual / client
    CustomLighting = "Off", -- Off | Grey | Anime | Clear
    StretchRes = 1, -- 1-10 (viewport stretch of game world)
    DeviceMode = "PC", -- PC | Touch | VR | Control  (overhead icon only)

    -- Rage
    Tornado = false,

    -- Presets (client feel)
    PresetADS = 1,
    PresetFOV = 90,
    PresetSens = 0.5,

    -- Skin changer
    SkinChanger = false,
    SkinMaps = {}, -- [weaponName] = skinName
}

-- bool toggles that free-expire must kill (leave numbers/strings alone)
local FEATURE_BOOL_KEYS = {
    "Aimbot","TriggerBot","DeathLock","DeathLockUltra","AutoShoot",
    "ESP","Boxes","Skeleton","Tracers","ShowLife","ShowNames",
    "TPBehind","TPUp","InstaBackstab",
    "SpeedHack","Noclip","Fly","SpinBot","JoinPlayer",
    "NoMeleeCooldown","NoScopeCooldown",
    "Tornado","SkinChanger",
}

DeactivateAllFeatures = function()
    for _, k in ipairs(FEATURE_BOOL_KEYS) do
        Features[k] = false
    end
    -- hard-stop movement side-effects
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.CanCollide = true
                end
            end
        end
    end)
end

-- free timed configs only run while Active; untagged imports run unlimited
local FreeWindowRequired = false  -- set true once a [time:] config is applied this session

local function FreeWindowOK()
    if not FreeWindowRequired then return true end
    if FreeConfig.Active and FreeConfig.ExpiresAt > os.time() then
        return true
    end
    return false
end



--==============================================================
-- CLIENT VISUAL HELPERS
--==============================================================
local Lighting = game:GetService("Lighting")
local lightingBackup = nil

local function ApplyCustomLighting(mode)
    mode = mode or Features.CustomLighting or "Off"
    pcall(function()
        if not lightingBackup then
            lightingBackup = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                FogColor = Lighting.FogColor,
                ColorShift_Top = Lighting.ColorShift_Top,
                ColorShift_Bottom = Lighting.ColorShift_Bottom,
            }
        end
        for _, ch in ipairs(Lighting:GetChildren()) do
            if ch.Name == "FanwareSky" or ch.Name == "FanwareCC" or ch.Name == "FanwareBloom" then
                ch:Destroy()
            end
        end
        if mode == "Off" then
            if lightingBackup then
                for k, v in pairs(lightingBackup) do
                    pcall(function() Lighting[k] = v end)
                end
            end
            return
        end
        local sky = Instance.new("Sky")
        sky.Name = "FanwareSky"
        if mode == "Grey" then
            sky.SkyboxBk = "rbxassetid://591058823"
            sky.SkyboxDn = "rbxassetid://591059876"
            sky.SkyboxFt = "rbxassetid://591058104"
            sky.SkyboxLf = "rbxassetid://591057861"
            sky.SkyboxRt = "rbxassetid://591057625"
            sky.SkyboxUp = "rbxassetid://591059642"
            Lighting.Ambient = Color3.fromRGB(120, 120, 125)
            Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 115)
            Lighting.Brightness = 1.15
            Lighting.FogEnd = 2200
            Lighting.FogColor = Color3.fromRGB(140, 140, 145)
            Lighting.ColorShift_Top = Color3.fromRGB(160, 160, 165)
            Lighting.ColorShift_Bottom = Color3.fromRGB(90, 90, 95)
        elseif mode == "Anime" then
            sky.SkyboxBk = "rbxassetid://159454299"
            sky.SkyboxDn = "rbxassetid://159454296"
            sky.SkyboxFt = "rbxassetid://159454293"
            sky.SkyboxLf = "rbxassetid://159454286"
            sky.SkyboxRt = "rbxassetid://159454300"
            sky.SkyboxUp = "rbxassetid://159454288"
            Lighting.Ambient = Color3.fromRGB(180, 160, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(170, 150, 190)
            Lighting.Brightness = 2.1
            Lighting.FogEnd = 6000
            Lighting.ColorShift_Top = Color3.fromRGB(255, 180, 220)
            Lighting.ColorShift_Bottom = Color3.fromRGB(120, 140, 255)
            local cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "FanwareCC"
            cc.Saturation = 0.35
            cc.Contrast = 0.12
            cc.TintColor = Color3.fromRGB(255, 230, 250)
            cc.Parent = Lighting
        elseif mode == "Clear" then
            sky.SkyboxBk = "rbxassetid://6444884337"
            sky.SkyboxDn = "rbxassetid://6444884785"
            sky.SkyboxFt = "rbxassetid://6444884337"
            sky.SkyboxLf = "rbxassetid://6444884337"
            sky.SkyboxRt = "rbxassetid://6444884337"
            sky.SkyboxUp = "rbxassetid://6412503613"
            Lighting.Ambient = Color3.fromRGB(200, 210, 220)
            Lighting.OutdoorAmbient = Color3.fromRGB(190, 200, 210)
            Lighting.Brightness = 2.5
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Bottom = Color3.fromRGB(200, 210, 230)
        end
        sky.Parent = Lighting
    end)
end
-- backward alias
local ApplyCustomSky = ApplyCustomLighting

-- Stretch Res: true stretched-res simulation via camera CFrame matrix (Y scale)
-- level 1 = off (identity), 10 = strongest vertical compress (wider feel like 4:3 stretched)
local stretchConn = nil
local stretchMatrix = CFrame.new()
local function stretchScaleFromLevel(level)
    level = math.clamp(tonumber(level) or 1, 1, 10)
    if level <= 1 then return 1 end
    -- map 2..10 -> ~0.92 .. 0.45 (lower Y = more stretch)
    local t = (level - 1) / 9
    return 1 - t * 0.55
end
local function ApplyStretchRes(level)
    level = math.clamp(tonumber(level) or 1, 1, 10)
    Features.StretchRes = level
    local yScale = stretchScaleFromLevel(level)
    if yScale >= 0.999 then
        stretchMatrix = CFrame.new()
        if stretchConn then
            stretchConn:Disconnect()
            stretchConn = nil
        end
        return
    end
    stretchMatrix = CFrame.new(0, 0, 0, 1, 0, 0, 0, yScale, 0, 0, 0, 1)
    if not stretchConn then
        stretchConn = RunService.RenderStepped:Connect(function()
            if (Features.StretchRes or 1) <= 1 then return end
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * stretchMatrix
            end
        end)
    end
end

-- Device icon spoof (overhead icon only — does not change input)
local DEVICE_ICON = {
    PC = "rbxassetid://12240888456",
    Touch = "rbxassetid://12240871627",
    Control = "rbxassetid://12240876390",
    VR = "rbxassetid://6031097225", -- headset-ish fallback
}
local deviceBillboard = nil
local function ClearDeviceIcon()
    if deviceBillboard then
        pcall(function() deviceBillboard:Destroy() end)
        deviceBillboard = nil
    end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if head then
            local old = head:FindFirstChild("FanwareDeviceIcon")
            if old then old:Destroy() end
        end
        -- also scrub common game overhead device ImageLabels we can reach client-side
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local n = string.lower(d.Name)
                if n:find("device") or n:find("platform") or n:find("input") then
                    -- leave game ones; only force ours below
                end
            end
        end
    end)
end

local function ApplyDeviceMode(mode)
    mode = mode or Features.DeviceMode or "PC"
    Features.DeviceMode = mode
    ClearDeviceIcon()
    pcall(function()
        LocalPlayer:SetAttribute("FanwareDevice", mode)
        local char = LocalPlayer.Character
        if not char then return end
        local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 2)
        if not head then return end
        local bb = Instance.new("BillboardGui")
        bb.Name = "FanwareDeviceIcon"
        bb.Size = UDim2.new(0, 28, 0, 28)
        bb.StudsOffset = Vector3.new(1.4, 2.2, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 120
        bb.Parent = head
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(1, 0, 1, 0)
        img.Image = DEVICE_ICON[mode] or DEVICE_ICON.PC
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = bb
        deviceBillboard = bb

        -- try patch existing game device icons on our character (client visible)
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local n = string.lower(d.Name)
                if n:find("device") or n:find("platform") or n == "icon" or n:find("mobile") or n:find("console") or n:find("pc") then
                    pcall(function() d.Image = DEVICE_ICON[mode] or DEVICE_ICON.PC end)
                end
            end
        end
        -- PlayerGui overhead clones sometimes live under PlayerGui
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, d in ipairs(pg:GetDescendants()) do
                if (d:IsA("ImageLabel") or d:IsA("ImageButton")) then
                    local n = string.lower(d.Name)
                    if n:find("device") or n:find("platform") then
                        pcall(function() d.Image = DEVICE_ICON[mode] or DEVICE_ICON.PC end)
                    end
                end
            end
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.defer(function()
        if Features.DeviceMode and Features.DeviceMode ~= "" then
            ApplyDeviceMode(Features.DeviceMode)
        end
    end)
end)

local function ApplyPresets()
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            if (Features.StretchRes or 1) <= 1 then
                cam.FieldOfView = math.clamp(tonumber(Features.PresetFOV) or 90, 50, 120)
            else
                ApplyStretchRes(Features.StretchRes)
            end
        end
        local ug = UserSettings():GetService("UserGameSettings")
        if ug then
            pcall(function() ug.MouseSensitivity = math.clamp(tonumber(Features.PresetSens) or 0.5, 0.001, 100) end)
        end
        LocalPlayer:SetAttribute("FanwareADS", math.clamp(tonumber(Features.PresetADS) or 1, 0.001, 100))
        LocalPlayer:SetAttribute("FanwareSens", math.clamp(tonumber(Features.PresetSens) or 0.5, 0.001, 100))
        LocalPlayer:SetAttribute("FanwareFOV", math.clamp(tonumber(Features.PresetFOV) or 90, 80, 180))
    end)
end

--==================== SKIN CHANGER (by category) ====================
local SkinState = { applied = {}, backups = {}, animMaps = {}, soundMaps = {} }

-- Base weapons per slot (Rivals loadout categories)
local WEAPON_CATS = {
    Primary = {
        "Assault Rifle", "Burst Rifle", "Paintball Gun", "Shotgun", "Bow",
        "Crossbow", "RPG", "Sniper", "Minigun", "Flamethrower", "Energy Rifle",
        "Distortion", "Grenade Launcher", "Gunblade", "Freeze Ray", "Wildcat",
    },
    Secondary = {
        "Handgun", "Uzi", "Flare Gun", "Daggers", "Slingshot", "Exogun",
        "Revolver", "Shorty", "Energy Pistols", "Spray", "Warper",
    },
    Melee = {
        "Knife", "Katana", "Scythe", "Fists", "Battle Axe", "Chainsaw",
        "Riot Shield", "Trowel",
    },
    Utility = {
        "Flashbang", "Grenade", "Molotov", "Medkit", "Jump Pad", "Satchel",
    },
}

-- Skin name -> base weapon (curated from public Rivals skin lists)
local SKIN_TO_WEAPON = {
    -- Primary
    ["AK-47"]="Assault Rifle", ["AUG"]="Assault Rifle", ["Tommy Gun"]="Assault Rifle",
    ["Gingerbread AUG"]="Assault Rifle", ["Boneclaw Rifle"]="Assault Rifle", ["AKEY-47"]="Assault Rifle",
    ["Electro Burst"]="Burst Rifle", ["Aqua Burst"]="Burst Rifle", ["Pixel Burst"]="Burst Rifle",
    ["Spectral Burst"]="Burst Rifle", ["Pine Burst"]="Burst Rifle",
    ["Slime Gun"]="Paintball Gun", ["Boba Gun"]="Paintball Gun", ["Snowball Gun"]="Paintball Gun", ["Brain Gun"]="Paintball Gun",
    ["Balloon Shotgun"]="Shotgun", ["Hyper Shotgun"]="Shotgun", ["Wrapped Shotgun"]="Shotgun", ["Broomstick"]="Shotgun",
    ["Compound Bow"]="Bow", ["Bat Bow"]="Bow",
    ["Pixel Crossbow"]="Crossbow", ["Frostbite Crossbow"]="Crossbow", ["Campfire Crossbow"]="Crossbow", ["Crossbone"]="Crossbow",
    ["Nuke Launcher"]="RPG",
    ["Pixel Sniper"]="Sniper", ["Hyper Sniper"]="Sniper", ["Keyper"]="Sniper", ["Gingerbread Sniper"]="Sniper", ["Eyething Sniper"]="Sniper",
    ["Lasergun 3000"]="Minigun",
    ["Pixel Flamethrower"]="Flamethrower",
    ["Hacker Rifle"]="Energy Rifle",
    ["Plasma Distortion"]="Distortion", ["Cyber Distortion"]="Distortion",
    ["Swashbuckler"]="Grenade Launcher",
    ["Hyper Gunblade"]="Gunblade",
    ["Temporal Ray"]="Freeze Ray",
    -- Secondary
    ["Blaster"]="Handgun", ["Hand Gun"]="Handgun", ["Gumball Handgun"]="Handgun", ["Pumpkin Handgun"]="Handgun",
    ["Gingerbread Handgun"]="Handgun", ["Pixel Handgun"]="Handgun", ["Glorious Handgun"]="Handgun",
    ["Water Uzi"]="Uzi", ["Electro Uzi"]="Uzi", ["Money Gun"]="Uzi", ["Demon Uzi"]="Uzi", ["Pine Uzi"]="Uzi", ["Keyzi"]="Uzi", ["Glorious Uzi"]="Uzi",
    ["Firework Gun"]="Flare Gun", ["Dynamite Gun"]="Flare Gun", ["Banana Flare"]="Flare Gun", ["Vexed Flare Gun"]="Flare Gun",
    ["Wrapped Flare Gun"]="Flare Gun", ["Glorious Flare Gun"]="Flare Gun",
    ["Aces"]="Daggers", ["Paper Planes"]="Daggers", ["Shurikens"]="Daggers", ["Cookies"]="Daggers", ["Crystal Daggers"]="Daggers", ["Glorious Daggers"]="Daggers",
    ["Stick"]="Slingshot", ["Goal Post"]="Slingshot", ["Harp"]="Slingshot", ["Boneshot"]="Slingshot", ["Reindeer Slingshot"]="Slingshot", ["Glorious Slingshot"]="Slingshot",
    ["Singularity"]="Exogun", ["Ray Gun"]="Exogun", ["Repulsor"]="Exogun", ["Exogourd"]="Exogun", ["Midnight Festive Exogun"]="Exogun", ["Wondergun"]="Exogun", ["Glorious Exogun"]="Exogun",
    ["Desert Eagle"]="Revolver", ["Sheriff"]="Revolver", ["Peppergun"]="Revolver", ["Boneclaw Revolver"]="Revolver", ["Peppermint Sheriff"]="Revolver", ["Keyvolver"]="Revolver", ["Glorious Revolver"]="Revolver",
    ["Not So Shorty"]="Shorty", ["Lovely Shorty"]="Shorty", ["Balloon Shorty"]="Shorty", ["Demon Shorty"]="Shorty", ["Wrapped Shorty"]="Shorty", ["Too Shorty"]="Shorty", ["Glorious Shorty"]="Shorty",
    ["Hacker Pistols"]="Energy Pistols", ["Void Pistols"]="Energy Pistols", ["Hydro Pistols"]="Energy Pistols", ["2025 Energy Pistols"]="Energy Pistols", ["Apex Pistols"]="Energy Pistols", ["Glorious Energy Pistols"]="Energy Pistols",
    ["Lovely Spray"]="Spray", ["Nailgun"]="Spray", ["Spray Bottle"]="Spray", ["Pine Spray"]="Spray", ["Glorious Spray"]="Spray",
    ["Electropunk Warper"]="Warper", ["Glorious Warper"]="Warper",
    -- Melee
    ["The Shred"]="Battle Axe", ["Ban Axe"]="Battle Axe", ["Cerulean Axe"]="Battle Axe", ["Nordic Axe"]="Battle Axe", ["Glorious Battle Axe"]="Battle Axe",
    ["Blobsaw"]="Chainsaw", ["Handsaws"]="Chainsaw", ["Mega Drill"]="Chainsaw", ["Buzzsaw"]="Chainsaw", ["Festive Buzzsaw"]="Chainsaw", ["Glorious Chainsaw"]="Chainsaw",
    ["Boxing Gloves"]="Fists", ["Brass Knuckles"]="Fists", ["Fists Of Hurt"]="Fists", ["Pumpkin Claws"]="Fists", ["Festive Fists"]="Fists", ["Glorious Fists"]="Fists",
    ["Saber"]="Katana", ["Lightning Bolt"]="Katana", ["Stellar Katana"]="Katana", ["Devil's Trident"]="Katana", ["2025 Katana"]="Katana", ["Pixel Katana"]="Katana", ["Keytana"]="Katana", ["Arch Katana"]="Katana", ["Glorious Katana"]="Katana",
    ["Chancla"]="Knife", ["Karambit"]="Knife", ["Balisong"]="Knife", ["Machete"]="Knife", ["Candy Cane"]="Knife", ["Glorious Knife"]="Knife",
    ["Door"]="Riot Shield", ["Energy Shield"]="Riot Shield", ["Masterpiece"]="Riot Shield", ["Sled"]="Riot Shield", ["Glorious Riot Shield"]="Riot Shield",
    ["Scythe of Death"]="Scythe", ["Anchor"]="Scythe", ["Sakura Scythe"]="Scythe", ["Bat Scythe"]="Scythe", ["Cryo Scythe"]="Scythe", ["Keythe"]="Scythe", ["Glorious Scythe"]="Scythe",
    -- Utility
    ["Disco Ball"]="Flashbang", ["Camera"]="Flashbang", ["Lightbulb"]="Flashbang", ["Skullbang"]="Flashbang",
    ["Whoopee Cushion"]="Grenade",
    ["Coffee"]="Molotov",
    ["Sandwich"]="Medkit",
    ["Trampoline"]="Jump Pad",
    ["Advanced Satchel"]="Satchel",
}

local function BuildSkinsForWeapon(weaponName)
    local list = {"(Default)"}
    for skin, base in pairs(SKIN_TO_WEAPON) do
        if base == weaponName then
            table.insert(list, skin)
        end
    end
    table.sort(list, function(a, b)
        if a == "(Default)" then return true end
        if b == "(Default)" then return false end
        return a < b
    end)
    return list
end

local function FindViewModelRoot()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if not ps then return nil end
    local assets = ps:FindFirstChild("Assets")
    if not assets then return nil end
    return assets:FindFirstChild("ViewModels")
end

local function ListSkinFolders()
    local vm = FindViewModelRoot()
    local folders = {}
    if not vm then return folders end
    for _, ch in ipairs(vm:GetChildren()) do
        if ch:IsA("Folder") or ch:IsA("Model") then
            local n = ch.Name
            if n:lower():find("skin") or n:lower():find("case") or n == "Other" then
                table.insert(folders, ch)
            end
        end
    end
    return folders
end

local function FindSkinModel(skinName)
    if not skinName or skinName == "" or skinName == "(Default)" then return nil end
    for _, folder in ipairs(ListSkinFolders()) do
        local m = folder:FindFirstChild(skinName)
        if m then return m end
        for _, d in ipairs(folder:GetDescendants()) do
            if d.Name == skinName and (d:IsA("Model") or d:IsA("Folder")) then
                return d
            end
        end
    end
    return nil
end

local function FindWeaponViewModel(weaponName)
    local vm = FindViewModelRoot()
    if not vm then return nil end
    local weapons = vm:FindFirstChild("Weapons")
    if weapons then
        local w = weapons:FindFirstChild(weaponName)
        if w then return w end
        -- fuzzy
        for _, ch in ipairs(weapons:GetChildren()) do
            if string.lower(ch.Name) == string.lower(weaponName) then return ch end
        end
    end
    for _, d in ipairs(vm:GetDescendants()) do
        if d.Name == weaponName and d.Parent and d.Parent.Name == "Weapons" then
            return d
        end
    end
    return nil
end

-- Build AnimationId remap: default weapon anims -> skin anims (by matching Animation.Name under both models)
local function BuildAnimMap(weaponModel, skinModel)
    local map = {}
    if not (weaponModel and skinModel) then return map end
    local function collect(root)
        local byName = {}
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("Animation") and d.AnimationId and d.AnimationId ~= "" then
                local key = d.Name
                byName[key] = byName[key] or {}
                table.insert(byName[key], d.AnimationId)
            end
        end
        return byName
    end
    local base = collect(weaponModel)
    local skin = collect(skinModel)
    for name, ids in pairs(base) do
        local skinIds = skin[name]
        if skinIds and #skinIds > 0 then
            for _, oldId in ipairs(ids) do
                map[oldId] = skinIds[1]
            end
        end
    end
    -- also map by order if names differ but counts match under AnimationController
    return map
end

local function CollectSkinSounds(skinModel)
    local sounds = {}
    if not skinModel then return sounds end
    for _, d in ipairs(skinModel:GetDescendants()) do
        if d:IsA("Sound") and d.SoundId and d.SoundId ~= "" then
            table.insert(sounds, {
                name = d.Name,
                id = d.SoundId,
                volume = d.Volume,
                playbackSpeed = d.PlaybackSpeed,
            })
        end
    end
    return sounds
end

local function ApplySkinToWeapon(weaponName, skinName)
    if not Features.SkinChanger then return false end
    if not weaponName or weaponName == "" then return false end
    Features.SkinMaps = Features.SkinMaps or {}
    Features.SkinMaps[weaponName] = skinName
    if skinName == "(Default)" or not skinName then
        SkinState.animMaps = SkinState.animMaps or {}
        SkinState.animMaps[weaponName] = nil
        SkinState.soundMaps = SkinState.soundMaps or {}
        SkinState.soundMaps[weaponName] = nil
        -- restore backup mesh if we have it
        local weapon = FindWeaponViewModel(weaponName)
        local bag = SkinState.backups and SkinState.backups[weaponName]
        if weapon and bag then
            pcall(function()
                weapon:ClearAllChildren()
                for _, ch in ipairs(bag:GetChildren()) do
                    ch:Clone().Parent = weapon
                end
            end)
        end
        return true
    end
    local skin = FindSkinModel(skinName)
    local weapon = FindWeaponViewModel(weaponName)
    if not (skin and weapon) then
        print("[Fanware] Skin path missing:", weaponName, "->", skinName)
        return false
    end
    local ok = pcall(function()
        if not SkinState.backups[weaponName] then
            local bag = Instance.new("Folder")
            bag.Name = "Backup_" .. weaponName
            for _, ch in ipairs(weapon:GetChildren()) do
                ch:Clone().Parent = bag
            end
            SkinState.backups[weaponName] = bag
        end
        -- keep a pre-clear snapshot for anim id harvesting
        local preAnimMap = BuildAnimMap(weapon, skin)
        weapon:ClearAllChildren()
        for _, ch in ipairs(skin:GetChildren()) do
            ch:Clone().Parent = weapon
        end
        -- also copy Animation objects that lived deeper on skin
        for _, d in ipairs(skin:GetDescendants()) do
            if d:IsA("Animation") then
                -- already cloned with tree; ok
            end
        end
        SkinState.applied[weaponName] = skinName
        SkinState.animMaps = SkinState.animMaps or {}
        SkinState.animMaps[weaponName] = preAnimMap
        SkinState.soundMaps = SkinState.soundMaps or {}
        SkinState.soundMaps[weaponName] = CollectSkinSounds(skin)
        -- rebuild combined active maps
        RebuildActiveSkinRuntime()
    end)
    return ok
end

local activeAnimMap = {} -- AnimationId -> replacement AnimationId
local activeSoundByName = {} -- Sound.Name -> {id, volume, playbackSpeed}
local animHooked = false
local soundHooked = false
local loadedSkinTracks = {}

function RebuildActiveSkinRuntime()
    activeAnimMap = {}
    activeSoundByName = {}
    SkinState.animMaps = SkinState.animMaps or {}
    SkinState.soundMaps = SkinState.soundMaps or {}
    for _, amap in pairs(SkinState.animMaps) do
        if type(amap) == "table" then
            for oldId, newId in pairs(amap) do
                activeAnimMap[oldId] = newId
            end
        end
    end
    for _, slist in pairs(SkinState.soundMaps) do
        if type(slist) == "table" then
            for _, s in ipairs(slist) do
                if s.name and s.id then
                    activeSoundByName[s.name] = s
                end
            end
        end
    end
    EnsureSkinRuntimeHooks()
end

local function GetFPAnimator()
    local fp = workspace:FindFirstChild("ViewModels")
    fp = fp and fp:FindFirstChild("FirstPerson")
    if not fp then return nil end
    for _, vm in ipairs(fp:GetChildren()) do
        if typeof(vm.Name) == "string" and vm.Name:find(LocalPlayer.Name, 1, true) then
            local ac = vm:FindFirstChildOfClass("AnimationController") or vm:FindFirstChild("AnimationController", true)
            if ac then
                local an = ac:FindFirstChildOfClass("Animator") or ac:FindFirstChild("Animator", true)
                if an then return an, vm end
            end
        end
    end
    return nil
end

function EnsureSkinRuntimeHooks()
    if not animHooked then
        animHooked = true
        task.spawn(function()
            while true do
                local animator = GetFPAnimator()
                if animator and not animator:GetAttribute("FanwareAnimHook") then
                    animator:SetAttribute("FanwareAnimHook", true)
                    animator.AnimationPlayed:Connect(function(track)
                        if not Features.SkinChanger then return end
                        local anim = track and track.Animation
                        if not anim then return end
                        local cur = anim.AnimationId
                        local rep = activeAnimMap[cur]
                        if not rep then return end
                        pcall(function()
                            track:Stop(0)
                            if loadedSkinTracks[rep] and loadedSkinTracks[rep].IsPlaying then
                                return
                            end
                            local a = Instance.new("Animation")
                            a.AnimationId = rep
                            local nt = animator:LoadAnimation(a)
                            loadedSkinTracks[rep] = nt
                            nt:Play()
                            nt.Stopped:Connect(function()
                                if loadedSkinTracks[rep] == nt then
                                    loadedSkinTracks[rep] = nil
                                end
                            end)
                        end)
                    end)
                end
                task.wait(1)
            end
        end)
    end
    if not soundHooked then
        soundHooked = true
        -- rewrite SoundIds on viewmodel / character tools when skin sounds exist
        task.spawn(function()
            while true do
                if Features.SkinChanger and next(activeSoundByName) ~= nil then
                    pcall(function()
                        local roots = {}
                        local fp = workspace:FindFirstChild("ViewModels")
                        if fp and fp:FindFirstChild("FirstPerson") then
                            table.insert(roots, fp.FirstPerson)
                        end
                        local vmRoot = FindViewModelRoot()
                        if vmRoot then table.insert(roots, vmRoot) end
                        local char = LocalPlayer.Character
                        if char then table.insert(roots, char) end
                        for _, root in ipairs(roots) do
                            for _, d in ipairs(root:GetDescendants()) do
                                if d:IsA("Sound") then
                                    local info = activeSoundByName[d.Name]
                                    if info and d.SoundId ~= info.id then
                                        d.SoundId = info.id
                                        if info.volume then d.Volume = info.volume end
                                        if info.playbackSpeed then d.PlaybackSpeed = info.playbackSpeed end
                                    end
                                end
                            end
                        end
                    end)
                end
                task.wait(0.75)
            end
        end)
    end
end

local function ApplyAllMappedSkins()
    if not Features.SkinChanger then return end
    Features.SkinMaps = Features.SkinMaps or {}
    for weapon, skin in pairs(Features.SkinMaps) do
        ApplySkinToWeapon(weapon, skin)
    end
    RebuildActiveSkinRuntime()
end

local function ApplySkinChanger()
    ApplyAllMappedSkins()
end


local aimbotAllowedTime = tick() + 5
LocalPlayer.CharacterAdded:Connect(function()
    aimbotAllowedTime = tick() + 5
end)

local function InLobbyOrSafe()
    local char = LocalPlayer.Character
    if not char then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not root then return true end
    if tick() < aimbotAllowedTime then return true end
    return false
end

-- Remote discovery
-- Multi-remote discovery (Rivals uses several shot pipelines)
local FireRemotes = {}
local function RegisterRemote(rem)
    if not rem then return end
    if not (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) then return end
    for _, r in ipairs(FireRemotes) do
        if r == rem then return end
    end
    table.insert(FireRemotes, rem)
    print("[Fanware] Fire remote:", rem:GetFullName())
end

local function FindFireRemotes()
    local nameHints = {
        "fire","shoot","shot","bullet","projectile","gun","weapon",
        "hit","damage","replicate","cast","ammo","ray","checkfire","fireserver"
    }
    local function nameLooksGood(n)
        n = string.lower(n)
        for _, h in ipairs(nameHints) do
            if n:find(h, 1, true) then return true end
        end
        return false
    end
    -- common folders first
    for _, folderName in ipairs({"ShooterRemotes","Remotes","WeaponRemotes","Events","GunRemotes","Combat","Weapons","Network"}) do
        local folder = ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetDescendants()) do
                if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and nameLooksGood(child.Name) then
                    RegisterRemote(child)
                end
            end
        end
    end
    -- full RS scan
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and nameLooksGood(obj.Name) then
            RegisterRemote(obj)
        end
    end
    -- also watch for late-created remotes
    ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and nameLooksGood(obj.Name) then
            RegisterRemote(obj)
        end
    end)
end
FindFireRemotes()
if #FireRemotes == 0 then
    warn("[Fanware] No Fire remotes found yet — will keep watching")
end
local FireRemote = FireRemotes[1] -- legacy single ref for older calls

local function GetCharacter(player)
    return player and player.Character
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(character)
    local hum = GetHumanoid(character)
    return hum ~= nil and hum.Health > 0
end

local function GetRoot(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end

local function GetPart(character, targetType)
    if not character then return nil end
    if targetType == "Head" then
        return character:FindFirstChild("Head") or GetRoot(character)
    elseif targetType == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or GetRoot(character)
    else
        return GetRoot(character)
    end
end

-- Rivals-friendly team check
-- Uses Team instance, TeamColor, and Neutral. If either side has no team, treat as enemy (FFA / unassigned).
local function IsEnemy(player)
    if not player or player == LocalPlayer then return false end
    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team
    -- both have teams → compare instances
    if myTeam and theirTeam then
        if myTeam == theirTeam then return false end
        return true
    end
    -- TeamColor fallback (Rivals often keys on color)
    local myColor = LocalPlayer.TeamColor
    local theirColor = player.TeamColor
    if myColor and theirColor and myTeam and theirTeam then
        if myColor == theirColor then return false end
    end
    -- Neutral / no team → targetable in FFA style modes
    if LocalPlayer.Neutral or player.Neutral then
        return true
    end
    if not myTeam or not theirTeam then
        return true
    end
    return true
end

local function IsAnyPlayer(player)
    return player ~= nil and player ~= LocalPlayer
end

-- Wallcheck with larger tolerance (more studs / ignore tiny hits)
local function HasWallBetween(fromPos, toPos, ignoreList)
    local direction = toPos - fromPos
    local distance = direction.Magnitude
    if distance < 1 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {LocalPlayer.Character}
    params.IgnoreWater = true
    -- cast slightly short so we don't count the target surface itself
    local result = Workspace:Raycast(fromPos, direction.Unit * (distance - 1.5), params)
    if not result then return false end
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if hitModel and Players:GetPlayerFromCharacter(hitModel) then
        return false
    end
    -- ignore thin / non-collidable junk
    if result.Instance.CanCollide == false or result.Instance.Transparency >= 0.9 then
        return false
    end
    return true
end

local function IsVisible(part, fromCamera)
    if not part then return false end
    local origin
    if fromCamera then
        origin = Camera.CFrame.Position
    else
        local r = GetRoot(LocalPlayer.Character)
        origin = r and r.Position
    end
    if not origin then return false end
    local ignore = {LocalPlayer.Character}
    local targetChar = part:FindFirstAncestorOfClass("Model")
    if targetChar then table.insert(ignore, targetChar) end
    return not HasWallBetween(origin, part.Position, ignore)
end

-- Closest target — teamCheck=true => enemies only; false => all others
local function GetClosestTarget(targetType, maxFOV, maxDist, wallCheck, useCameraOrigin, teamCheck)
    local mousePos = UserInputService:GetMouseLocation()
    local closestPlayer, closestPart = nil, nil
    local shortestDist = maxFOV or math.huge
    local myRoot = GetRoot(LocalPlayer.Character)
    local origin = (useCameraOrigin and Camera.CFrame.Position) or (myRoot and myRoot.Position)

    for _, player in ipairs(Players:GetPlayers()) do
        local valid
        if teamCheck then
            valid = IsEnemy(player)
        else
            valid = IsAnyPlayer(player)
        end
        if valid then
            local char = GetCharacter(player)
            if char and IsAlive(char) then
                local part = GetPart(char, targetType)
                if part then
                    local dist3d = origin and (part.Position - origin).Magnitude or 0
                    if not maxDist or dist3d <= maxDist then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen and screenPos.Z > 0 then
                            local dist2d = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist2d < shortestDist then
                                if not wallCheck or IsVisible(part, useCameraOrigin) then
                                    shortestDist = dist2d
                                    closestPlayer = player
                                    closestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer, closestPart
end

-- pure 3D closest (for TP / shoot through walls)
local function GetClosestPlayer3D(ignoreTeam, maxDist)
    local myRoot = GetRoot(LocalPlayer.Character)
    if not myRoot then return nil, nil end
    local closest, closestRoot, best = nil, nil, maxDist or 9999
    for _, player in ipairs(Players:GetPlayers()) do
        local valid = ignoreTeam and IsAnyPlayer(player) or IsEnemy(player)
        if valid then
            local char = GetCharacter(player)
            if char and IsAlive(char) then
                local root = GetRoot(char)
                if root then
                    local d = (root.Position - myRoot.Position).Magnitude
                    if d < best then
                        best = d
                        closest = player
                        closestRoot = root
                    end
                end
            end
        end
    end
    return closest, closestRoot
end

-- Drawing ESP
local DrawingESP = {}
local function CreateDrawingESP(player)
    if player == LocalPlayer or DrawingESP[player] then return end
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1.5
    box.Filled = false
    box.Color = Features.BoxColor

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1.5
    tracer.Color = Features.TracerColor

    local infoText = Drawing.new("Text")
    infoText.Visible = false
    infoText.Center = true
    infoText.Outline = true
    infoText.OutlineColor = Color3.fromRGB(0, 0, 0)
    infoText.Size = 13
    infoText.Color = Color3.fromRGB(255, 255, 255)

    local skeletonLines = {
        HeadToTorso = Drawing.new("Line"),
        TorsoToLeftArm = Drawing.new("Line"),
        TorsoToRightArm = Drawing.new("Line"),
        TorsoToLeftLeg = Drawing.new("Line"),
        TorsoToRightLeg = Drawing.new("Line")
    }
    for _, line in pairs(skeletonLines) do
        line.Visible = false
        line.Thickness = 1.5
        line.Color = Features.BoxColor
    end
    DrawingESP[player] = {Box = box, Tracer = tracer, Text = infoText, Skeleton = skeletonLines}
end

local function RemoveDrawingESP(player)
    local data = DrawingESP[player]
    if data then
        if data.Box then data.Box:Remove() end
        if data.Tracer then data.Tracer:Remove() end
        if data.Text then data.Text:Remove() end
        for _, line in pairs(data.Skeleton) do line:Remove() end
        DrawingESP[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    CreateDrawingESP(p)
    p.CharacterAdded:Connect(function() task.wait(1) CreateDrawingESP(p) end)
end
Players.PlayerAdded:Connect(function(p)
    CreateDrawingESP(p)
    p.CharacterAdded:Connect(function() task.wait(1) CreateDrawingESP(p) end)
end)
Players.PlayerRemoving:Connect(RemoveDrawingESP)

local function FireAt(part, originOverride)
    if not part then return end
    local pos = part.Position
    local cf = part.CFrame
    local origin = originOverride
    if not origin then
        local r = GetRoot(LocalPlayer.Character)
        origin = r and r.Position or Camera.CFrame.Position
    end
    local dir = (pos - origin)
    if dir.Magnitude < 0.01 then dir = Camera.CFrame.LookVector else dir = dir.Unit end

    local function tryFire(rem)
        if not rem then return end
        -- common Rivals / FPS arg patterns
        pcall(function() rem:FireServer(pos) end)
        pcall(function() rem:FireServer(pos, part) end)
        pcall(function() rem:FireServer(part) end)
        pcall(function() rem:FireServer(cf) end)
        pcall(function() rem:FireServer(origin, pos) end)
        pcall(function() rem:FireServer(origin, dir) end)
        pcall(function() rem:FireServer(origin, dir * 500) end)
        pcall(function() rem:FireServer({Position = pos, Part = part, Origin = origin, Direction = dir}) end)
        pcall(function() rem:FireServer({pos, part, origin, dir}) end)
        pcall(function() rem:FireServer(pos.X, pos.Y, pos.Z) end)
    end

    if #FireRemotes > 0 then
        for _, rem in ipairs(FireRemotes) do
            tryFire(rem)
        end
    elseif FireRemote then
        tryFire(FireRemote)
    end
end


local function DoClick()
    pcall(function() if mouse1click then mouse1click() end end)
    pcall(function()
        if mouse1press then
            mouse1press()
            task.wait(0.02)
            mouse1release()
        end
    end)
    -- also try mouse2 for scoped weapons
    pcall(function()
        if mouse2press then
            -- don't force scope spam
        end
    end)
end

-- Main Loop
local triggerCooldown = false
local autoShootCooldown = false
local flyBodyVelocity, flyBodyGyro
local lastTPBehind, lastTPUp = 0, 0
local triggerAcquirePlayer, triggerAcquireAt = nil, 0
local autoAcquirePlayer, autoAcquireAt = nil, 0

RunService.RenderStepped:Connect(function()
    local menuOpen = main.Visible
    local safe = InLobbyOrSafe()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and GetRoot(myChar)

    -- 1. Aimbot (stickiness 1-10 = how hard it sticks to the part)
    if Features.Aimbot and FreeWindowOK() and not menuOpen and not safe then
        local _, targetPart = GetClosestTarget(
            Features.AimbotTarget,
            Features.AimbotFOV,
            Features.AimbotMaxDist,
            Features.AimbotWallCheck,
            true,
            Features.AimbotTeamCheck ~= false
        )
        if targetPart and mousemoverel then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos
                local smooth = math.clamp(Features.AimbotSmoothness, 1, 20)
                -- stickiness: 1 = soft, 10 = almost snap (divides smooth)
                local stick = math.clamp(Features.AimbotStickiness or 5, 1, 10)
                local factor = smooth / (stick * 0.85)
                if factor < 0.35 then factor = 0.35 end
                mousemoverel(delta.X / factor, delta.Y / factor)
            end
        end
    end

    -- 2. Death Lock
    if Features.DeathLock and FreeWindowOK() and not menuOpen and not safe then
        local _, targetPart = GetClosestTarget(
            Features.DeathLockTarget,
            500,
            900,
            Features.DeathLockWallCheck,
            true,
            Features.DeathLockTeamCheck ~= false
        )
        if targetPart and mousemoverel then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos
                mousemoverel(delta.X, delta.Y)
            end
        end
    end

    -- 2b. Death Lock ULTRA — cursor only (no camera force)
    if Features.DeathLockUltra and FreeWindowOK() and not menuOpen and not safe then
        local tgtMode = Features.DeathLockUltraTarget or "Mixed"
        local partType = tgtMode
        if tgtMode == "Mixed" then
            partType = (math.floor(tick() * 4) % 2 == 0) and "Head" or "Torso"
        end
        local _, targetPart = GetClosestTarget(
            partType,
            900,
            1500,
            Features.DeathLockUltraWallCheck,
            true,
            Features.DeathLockUltraTeamCheck ~= false
        )
        if targetPart and mousemoverel then
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen and screenPos.Z > 0 then
                local mousePos = UserInputService:GetMouseLocation()
                local dx = screenPos.X - mousePos.X
                local dy = screenPos.Y - mousePos.Y
                -- sticky cursor lock
                if math.abs(dx) > 0.35 or math.abs(dy) > 0.35 then
                    mousemoverel(dx, dy)
                end
            end
        end
    end

    -- 4. TriggerBot (acquire delay before first shot on a target)
    if Features.TriggerBot and FreeWindowOK() and not menuOpen and not safe and not triggerCooldown then
        local viewport = Camera.ViewportSize
        local ray = Camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
        local shot = false
        if result then
            local char = result.Instance:FindFirstAncestorOfClass("Model")
            local player = char and Players:GetPlayerFromCharacter(char)
            local teamOk = true
            if Features.TriggerBotTeamCheck ~= false then
                teamOk = player and IsEnemy(player)
            else
                teamOk = player and player ~= LocalPlayer
            end
            if teamOk and char and IsAlive(char) then
                if not Features.TriggerBotWallCheck or IsVisible(result.Instance, true) then
                    if triggerAcquirePlayer ~= player then
                        triggerAcquirePlayer = player
                        triggerAcquireAt = tick()
                    end
                    local waitT = Features.TriggerBotAcquire or 0.12
                    if (tick() - triggerAcquireAt) >= waitT then
                        triggerCooldown = true
                        shot = true
                        DoClick()
                        FireAt(result.Instance)
                        task.delay(Features.TriggerBotDelay, function()
                            triggerCooldown = false
                        end)
                    end
                end
            end
        end
        if not shot and not result then
            triggerAcquirePlayer = nil
        end
    end

    -- 5. AutoShoot (acquire delay so you can actually aim first)
    if Features.AutoShoot and FreeWindowOK() and not menuOpen and not safe and not autoShootCooldown then
        local plr, part = GetClosestTarget(
            Features.AimbotTarget or "Head",
            Features.AimbotFOV or 350,
            900,
            Features.AimbotWallCheck,
            true,
            Features.AutoShootTeamCheck ~= false
        )
        if part and plr then
            if autoAcquirePlayer ~= plr then
                autoAcquirePlayer = plr
                autoAcquireAt = tick()
            end
            local waitT = Features.AutoShootAcquire or 0.15
            if (tick() - autoAcquireAt) >= waitT then
                autoShootCooldown = true
                DoClick()
                FireAt(part)
                task.delay(Features.AutoShootDelay, function()
                    autoShootCooldown = false
                end)
            end
        else
            autoAcquirePlayer = nil
        end
    end

    -- 6. ESP
    for player, data in pairs(DrawingESP) do
        local char = GetCharacter(player)
        local valid = Features.ESP and FreeWindowOK() and char and IsAlive(char) and IsEnemy(player)

        if not valid then
            data.Box.Visible = false
            data.Tracer.Visible = false
            data.Text.Visible = false
            for _, line in pairs(data.Skeleton) do line.Visible = false end
        else
            local root = GetRoot(char)
            local head = GetPart(char, "Head")
            if root and head then
                local rootPos, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
                local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if rootOnScreen then
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2

                    if Features.Boxes then
                        data.Box.Size = Vector2.new(width, height)
                        data.Box.Position = Vector2.new(rootPos.X - width / 2, headPos.Y)
                        data.Box.Color = Features.BoxColor
                        data.Box.Visible = true
                    else
                        data.Box.Visible = false
                    end

                    if Features.ShowNames or Features.ShowLife then
                        local displayText = ""
                        if Features.ShowNames then displayText = player.Name end
                        if Features.ShowLife then
                            local hum = GetHumanoid(char)
                            if hum then
                                if displayText ~= "" then displayText = displayText .. " | " end
                                displayText = displayText .. math.floor(hum.Health) .. " HP"
                            end
                        end
                        data.Text.Text = displayText
                        data.Text.Position = Vector2.new(rootPos.X, headPos.Y - 16)
                        data.Text.Visible = true
                    else
                        data.Text.Visible = false
                    end

                    if Features.Tracers then
                        data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        data.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                        data.Tracer.Color = Features.TracerColor
                        data.Tracer.Visible = true
                    else
                        data.Tracer.Visible = false
                    end

                    if Features.Skeleton then
                        local leftArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
                        local rightArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
                        local leftLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")
                        local rightLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
                        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                        if torso and leftArm and rightArm and leftLeg and rightLeg then
                            local tPos = Camera:WorldToViewportPoint(torso.Position)
                            local hPos = Camera:WorldToViewportPoint(head.Position)
                            local laPos = Camera:WorldToViewportPoint(leftArm.Position)
                            local raPos = Camera:WorldToViewportPoint(rightArm.Position)
                            local llPos = Camera:WorldToViewportPoint(leftLeg.Position)
                            local rlPos = Camera:WorldToViewportPoint(rightLeg.Position)
                            data.Skeleton.HeadToTorso.From = Vector2.new(hPos.X, hPos.Y)
                            data.Skeleton.HeadToTorso.To = Vector2.new(tPos.X, tPos.Y)
                            data.Skeleton.HeadToTorso.Visible = true
                            data.Skeleton.TorsoToLeftArm.From = Vector2.new(tPos.X, tPos.Y)
                            data.Skeleton.TorsoToLeftArm.To = Vector2.new(laPos.X, laPos.Y)
                            data.Skeleton.TorsoToLeftArm.Visible = true
                            data.Skeleton.TorsoToRightArm.From = Vector2.new(tPos.X, tPos.Y)
                            data.Skeleton.TorsoToRightArm.To = Vector2.new(raPos.X, raPos.Y)
                            data.Skeleton.TorsoToRightArm.Visible = true
                            data.Skeleton.TorsoToLeftLeg.From = Vector2.new(tPos.X, tPos.Y)
                            data.Skeleton.TorsoToLeftLeg.To = Vector2.new(llPos.X, llPos.Y)
                            data.Skeleton.TorsoToLeftLeg.Visible = true
                            data.Skeleton.TorsoToRightLeg.From = Vector2.new(tPos.X, tPos.Y)
                            data.Skeleton.TorsoToRightLeg.To = Vector2.new(rlPos.X, rlPos.Y)
                            data.Skeleton.TorsoToRightLeg.Visible = true
                        else
                            for _, line in pairs(data.Skeleton) do line.Visible = false end
                        end
                    else
                        for _, line in pairs(data.Skeleton) do line.Visible = false end
                    end
                else
                    data.Box.Visible = false
                    data.Tracer.Visible = false
                    data.Text.Visible = false
                    for _, line in pairs(data.Skeleton) do line.Visible = false end
                end
            end
        end
    end

    -- 7. TP Behind (closest, ignore team)
    if Features.TPBehind and FreeWindowOK() and myRoot and not safe then
        if tick() - lastTPBehind > 0.15 then
            local _, targetRoot = GetClosestPlayer3D(true, 2000)
            if targetRoot then
                local behind = targetRoot.CFrame * CFrame.new(0, 0, 3.5)
                myRoot.CFrame = behind
                lastTPBehind = tick()
            end
        end
    end

    -- 8. TP Up (closest, ignore team) — snap once then settle, not continuous fly
    if Features.TPUp and FreeWindowOK() and myRoot and not safe then
        if tick() - lastTPUp > 0.45 then
            local _, targetRoot = GetClosestPlayer3D(true, 2000)
            if targetRoot then
                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 5, 0)
                pcall(function()
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end)
                lastTPUp = tick()
            end
        end
    end

    -- 10. Insta Backstab
    if Features.InstaBackstab and FreeWindowOK() and myRoot and not menuOpen and not safe then
        for _, player in ipairs(Players:GetPlayers()) do
            if IsEnemy(player) then
                local char = GetCharacter(player)
                if char and IsAlive(char) then
                    local root = GetRoot(char)
                    if root and (root.Position - myRoot.Position).Magnitude < 14 then
                        FireAt(root)
                    end
                end
            end
        end
    end

    -- 11. Speed Hack (power 40-100)
    if Features.SpeedHack and FreeWindowOK() and myRoot and myChar then
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            local power = math.clamp(Features.SpeedPower or 60, 50, 200)
            local boost = hum.MoveDirection * power
            local ok = pcall(function()
                local cur = myRoot.AssemblyLinearVelocity
                myRoot.AssemblyLinearVelocity = Vector3.new(boost.X, cur.Y, boost.Z)
            end)
            if not ok then
                pcall(function()
                    local cur = myRoot.Velocity
                    myRoot.Velocity = Vector3.new(boost.X, cur.Y, boost.Z)
                end)
            end
        end
    end

    -- 11b. Noclip
    if Features.Noclip and FreeWindowOK() and myChar then
        for _, part in ipairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    -- 12. Fly
    if Features.Fly and FreeWindowOK() and myRoot then
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyVelocity.Parent = myRoot
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBodyGyro.Parent = myRoot
        end
        flyBodyGyro.CFrame = Camera.CFrame
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        if moveDir.Magnitude > 0.1 then
            flyBodyVelocity.Velocity = moveDir.Unit * Features.FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.zero
        end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    end

    -- 13. SpinBot — character yaw (visible to others). First-person camera stays independent.
    if Features.SpinBot and FreeWindowOK() and myRoot then
        local spin = myRoot:FindFirstChild("FanwareSpin")
        if not spin then
            spin = Instance.new("BodyAngularVelocity")
            spin.Name = "FanwareSpin"
            spin.MaxTorque = Vector3.new(0, math.huge, 0)
            spin.P = 99999
            spin.Parent = myRoot
        end
        local spd = (Features.SpinSpeed or 15) * 3
        spin.AngularVelocity = Vector3.new(0, spd, 0)
        -- also force CFrame yaw so it registers even if physics fights it
        myRoot.CFrame = myRoot.CFrame * CFrame.Angles(0, math.rad(Features.SpinSpeed or 15), 0)
    else
        if myRoot then
            local spin = myRoot:FindFirstChild("FanwareSpin")
            if spin then spin:Destroy() end
        end
    end

    -- 13b. Tornado — orbit above nearest enemy + fire
    if Features.Tornado and FreeWindowOK() and myRoot and not menuOpen and not safe then
        local _, tgtRoot = GetClosestPlayer3D(false, 500)
        if tgtRoot then
            local angle = tick() * 8
            local orbit = Vector3.new(math.cos(angle) * 6, 10 + math.sin(tick() * 3) * 1.5, math.sin(angle) * 6)
            myRoot.CFrame = CFrame.new(tgtRoot.Position + orbit, tgtRoot.Position)
            pcall(function()
                myRoot.AssemblyLinearVelocity = Vector3.zero
            end)
            FireAt(tgtRoot)
        end
    end

    -- 14. Coils — no melee / scope cooldown (client-side attribute + remote spam safe)
    if FreeWindowOK() and (Features.NoMeleeCooldown or Features.NoScopeCooldown) then
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                if Features.NoMeleeCooldown then
                    pcall(function()
                        tool:SetAttribute("Cooldown", 0)
                        tool:SetAttribute("MeleeCooldown", 0)
                        tool:SetAttribute("SwingCooldown", 0)
                    end)
                    for _, v in ipairs(tool:GetDescendants()) do
                        if v:IsA("NumberValue") or v:IsA("IntValue") then
                            local n = string.lower(v.Name)
                            if n:find("cooldown") or n:find("cd") or n:find("delay") then
                                v.Value = 0
                            end
                        end
                    end
                end
                if Features.NoScopeCooldown then
                    pcall(function()
                        tool:SetAttribute("ScopeCooldown", 0)
                        tool:SetAttribute("AdsCooldown", 0)
                        tool:SetAttribute("AimCooldown", 0)
                    end)
                    for _, v in ipairs(tool:GetDescendants()) do
                        if v:IsA("NumberValue") or v:IsA("IntValue") then
                            local n = string.lower(v.Name)
                            if n:find("scope") or n:find("ads") or n:find("aimcd") then
                                v.Value = 0
                            end
                        end
                    end
                end
            end
        end
    end
end)

--==============================================================
-- COMBAT TAB
--==============================================================
local combat = tabs["Combat"].page

makeToggle(combat, "Aimbot", false, function(v) Features.Aimbot = v end)
makeDropdown(combat, "Aimbot Target", {"Head", "Torso", "Nearest"}, "Head", function(v) Features.AimbotTarget = v end)
makeSlider(combat, "Aimbot Smoothness", 1, 20, 5, function(v) Features.AimbotSmoothness = v end)
makeSlider(combat, "Aimbot Stickiness", 1, 10, 5, function(v) Features.AimbotStickiness = v end)
makeSlider(combat, "Aimbot FOV", 50, 700, 350, function(v) Features.AimbotFOV = v end)
makeSlider(combat, "Aimbot Max Dist", 100, 1500, 800, function(v) Features.AimbotMaxDist = v end)
makeToggle(combat, "Aimbot WallCheck", true, function(v) Features.AimbotWallCheck = v end)
makeToggle(combat, "Aimbot TeamCheck", true, function(v) Features.AimbotTeamCheck = v end)

makeToggle(combat, "TriggerBot", false, function(v) Features.TriggerBot = v end)
makeSlider(combat, "Trigger Delay (ms)", 20, 200, 50, function(v) Features.TriggerBotDelay = v / 1000 end)
makeSlider(combat, "Trigger Acquire (ms)", 0, 400, 120, function(v) Features.TriggerBotAcquire = v / 1000 end)
makeToggle(combat, "Trigger WallCheck", true, function(v) Features.TriggerBotWallCheck = v end)
makeToggle(combat, "Trigger TeamCheck", true, function(v) Features.TriggerBotTeamCheck = v end)

makeToggle(combat, "Death Lock", false, function(v) Features.DeathLock = v end)
makeDropdown(combat, "Death Lock Target", {"Head", "Torso", "Nearest"}, "Head", function(v) Features.DeathLockTarget = v end)
makeToggle(combat, "DeathLock WallCheck", true, function(v) Features.DeathLockWallCheck = v end)
makeToggle(combat, "DeathLock TeamCheck", true, function(v) Features.DeathLockTeamCheck = v end)

makeToggle(combat, "Death Lock ULTRA", false, function(v) Features.DeathLockUltra = v end)
makeDropdown(combat, "ULTRA Target", {"Head", "Torso", "Mixed"}, "Mixed", function(v) Features.DeathLockUltraTarget = v end)
makeToggle(combat, "ULTRA WallCheck", true, function(v) Features.DeathLockUltraWallCheck = v end)
makeToggle(combat, "ULTRA TeamCheck", true, function(v) Features.DeathLockUltraTeamCheck = v end)

makeToggle(combat, "Auto Shoot", false, function(v) Features.AutoShoot = v end)
makeSlider(combat, "AutoShoot Delay (ms)", 30, 200, 70, function(v) Features.AutoShootDelay = v / 1000 end)
makeSlider(combat, "AutoShoot Acquire (ms)", 0, 500, 150, function(v) Features.AutoShootAcquire = v / 1000 end)
makeToggle(combat, "AutoShoot TeamCheck", true, function(v) Features.AutoShootTeamCheck = v end)

--==============================================================
-- PLAYERS TAB
--==============================================================
local playersTab = tabs["Players"].page

local function parseColor(name)
    if name == "Red" then return Color3.fromRGB(255, 70, 70)
    elseif name == "Green" then return Color3.fromRGB(70, 255, 70)
    elseif name == "Blue" then return Color3.fromRGB(70, 130, 255)
    elseif name == "Purple" then return Color3.fromRGB(180, 70, 255)
    elseif name == "Yellow" then return Color3.fromRGB(255, 230, 70)
    else return Color3.fromRGB(255, 255, 255) end
end

makeToggle(playersTab, "ESP", false, function(v) Features.ESP = v end)
makeToggle(playersTab, "  └ Boxes", false, function(v) Features.Boxes = v end)
makeToggle(playersTab, "  └ Skeleton", false, function(v) Features.Skeleton = v end)
makeToggle(playersTab, "  └ Tracers", false, function(v) Features.Tracers = v end)
makeToggle(playersTab, "Show Life", false, function(v) Features.ShowLife = v end)
makeToggle(playersTab, "Show Names", false, function(v) Features.ShowNames = v end)
makeDropdown(playersTab, "Tracer Color", {"White", "Red", "Green", "Blue", "Purple", "Yellow"}, "White", function(v)
    Features.TracerColor = parseColor(v)
end)
makeDropdown(playersTab, "Box Color", {"White", "Red", "Green", "Blue", "Purple", "Yellow"}, "White", function(v)
    Features.BoxColor = parseColor(v)
end)

--==============================================================
-- MISC TAB (rage)
--==============================================================
local misc = tabs["Misc."].page

makeSection(misc, "Rage")
registerUI("TPBehind", makeToggle(misc, "TP Behind", false, function(v) Features.TPBehind = v end), "toggle")
registerUI("TPUp", makeToggle(misc, "TP Up", false, function(v) Features.TPUp = v end), "toggle")
registerUI("InstaBackstab", makeToggle(misc, "Insta Backstab", false, function(v) Features.InstaBackstab = v end), "toggle")
registerUI("Tornado", makeToggle(misc, "Tornado", false, function(v) Features.Tornado = v end), "toggle")

makeSection(misc, "Movement")
registerUI("SpeedHack", makeToggle(misc, "Speed Hack", false, function(v) Features.SpeedHack = v end), "toggle")
registerUI("SpeedPower", makeSlider(misc, "  └ Speed Power", 50, 200, 60, function(v) Features.SpeedPower = v end), "slider")
registerUI("Noclip", makeToggle(misc, "Noclip", false, function(v) Features.Noclip = v end), "toggle")
registerUI("Fly", makeToggle(misc, "Fly", false, function(v) Features.Fly = v end), "toggle")
registerUI("FlySpeed", makeSlider(misc, "  └ Fly Speed", 1, 150, 50, function(v) Features.FlySpeed = v end), "slider")
registerUI("SpinBot", makeToggle(misc, "SpinBot", false, function(v) Features.SpinBot = v end), "toggle")
registerUI("SpinSpeed", makeSlider(misc, "  └ Spin Speed", 5, 40, 15, function(v) Features.SpinSpeed = v end), "slider")

makeSection(misc, "Visual World")
registerUI("CustomLighting", makeDropdown(misc, "Custom Lighting", {"Off", "Grey", "Anime", "Clear"}, "Off", function(v)
    Features.CustomLighting = v
    ApplyCustomLighting(v)
end), "dropdown")
registerUI("StretchRes", makeSlider(misc, "Stretch Res", 1, 10, 1, function(v)
    Features.StretchRes = v
    ApplyStretchRes(v)
end), "slider")
registerUI("DeviceMode", makeDropdown(misc, "Device Icon", {"PC", "Touch", "VR", "Control"}, "PC", function(v)
    Features.DeviceMode = v
    ApplyDeviceMode(v)
end), "dropdown")


-- Join player: toggle reveals username box + go button
local joinPanel = new("Frame", {
    Parent = misc,
    Size = UDim2.new(1, 0, 0, 72),
    BackgroundColor3 = Color3.fromRGB(24, 24, 32),
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 3,
})
corner(joinPanel, 8)
stroke(joinPanel, Color3.fromRGB(50, 50, 65), 1)

local joinBox = new("TextBox", {
    Parent = joinPanel,
    Size = UDim2.new(1, -16, 0, 28),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundColor3 = Color3.fromRGB(34, 34, 44),
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "username (no @)",
    PlaceholderColor3 = Color3.fromRGB(120, 120, 140),
    TextColor3 = Color3.fromRGB(235, 235, 245),
    Font = Enum.Font.Gotham,
    TextSize = 13,
    ClearTextOnFocus = false,
    ZIndex = 4,
})
corner(joinBox, 6)

local joinGo = new("TextButton", {
    Parent = joinPanel,
    Size = UDim2.new(1, -16, 0, 26),
    Position = UDim2.new(0, 8, 0, 40),
    BackgroundColor3 = Color3.fromRGB(59, 108, 255),
    BorderSizePixel = 0,
    Text = "Join server",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    AutoButtonColor = true,
    ZIndex = 4,
})
corner(joinGo, 6)

local function doJoinUsername(name)
    name = tostring(name or ""):gsub("^@", ""):gsub("%s+", "")
    if name == "" then
        print("[Fanware] Join: enter a username first")
        return
    end
    Features.JoinUsername = name
    local placeId = game.PlaceId
    local ok, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(name)
    end)
    if not ok or type(userId) ~= "number" then
        print("[Fanware] Join failed: invalid username @" .. name)
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.UserId == userId then
            print("[Fanware] @" .. name .. " is already in this server")
            return
        end
    end
    local jobId = nil
    pcall(function()
        if typeof(getgenv) == "function" and getgenv().getplayerjobid then
            jobId = getgenv().getplayerjobid(userId)
        end
    end)
    if jobId and type(jobId) == "string" and #jobId > 0 then
        local okT, errT = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
        end)
        print(okT and ("[Fanware] Joining @" .. name) or ("[Fanware] Teleport failed: " .. tostring(errT)))
        return
    end
    local okF, errF = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
    print(okF
        and ("[Fanware] Server hop for @" .. name .. " (jobid helper not found — same place only)")
        or ("[Fanware] Join failed: " .. tostring(errF)))
end

joinBox.FocusLost:Connect(function()
    Features.JoinUsername = tostring(joinBox.Text or ""):gsub("^@", ""):gsub("%s+", "")
end)
joinGo.MouseButton1Click:Connect(function()
    doJoinUsername(joinBox.Text)
end)

-- Toggle first in list order, then reveal panel under it
makeSection(misc, "Join")
registerUI("JoinPlayer", makeToggle(misc, "Join Player", false, function(v)
    Features.JoinPlayer = v
    joinPanel.Visible = v
    if v then
        joinPanel.Parent = nil
        joinPanel.Parent = misc
        addRow(misc, 72)
        if Features.JoinUsername and Features.JoinUsername ~= "" then
            joinBox.Text = Features.JoinUsername
        end
        joinBox:CaptureFocus()
    else
        yOffset[misc] = math.max(0, (yOffset[misc] or 0) - 78)
        misc.CanvasSize = UDim2.new(0, 0, 0, yOffset[misc])
    end
end), "toggle")

--==============================================================
-- COILS TAB
--==============================================================
local coils = tabs["Coils"].page
makeToggle(coils, "No Melee Cooldown", false, function(v) Features.NoMeleeCooldown = v end)
makeToggle(coils, "No Scope Cooldown", false, function(v) Features.NoScopeCooldown = v end)
new("TextLabel", {
    Parent = coils,
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundTransparency = 1,
    Text = "Client-side cooldown strip.\nWorks when tools expose cooldown values/attributes.",
    TextColor3 = Color3.fromRGB(150, 150, 165),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
})
addRow(coils, 50)



--==============================================================
-- SKINS TAB
--==============================================================
do
    local skinsPage = tabs["Skins"].page
    makeSection(skinsPage, "Skin Changer")
    registerUI("SkinChanger", makeToggle(skinsPage, "Enabled", false, function(v)
        Features.SkinChanger = v
        if v then ApplyAllMappedSkins() end
    end), "toggle")

    local statusLbl = new("TextLabel", {
        Parent = skinsPage,
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "pick a weapon → choose a skin for that weapon",
        TextColor3 = Color3.fromRGB(150, 160, 180),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    })
    addRow(skinsPage, 22)

    local function openSkinPicker(weaponName)
        local skins = BuildSkinsForWeapon(weaponName)
        local g = Instance.new("ScreenGui")
        g.Name = "FanwareSkinPick"
        g.ResetOnSpawn = false
        g.Parent = CoreGui
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 320, 0, 360)
        frame.Position = UDim2.new(0.5, -160, 0.5, -180)
        frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        frame.BorderSizePixel = 0
        frame.Parent = g
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -16, 0, 28)
        title.Position = UDim2.new(0, 8, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = "Skin for  " .. weaponName
        title.TextColor3 = Color3.fromRGB(230, 230, 240)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -16, 1, -84)
        scroll.Position = UDim2.new(0, 8, 0, 40)
        scroll.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.CanvasSize = UDim2.new(0, 0, 0, #skins * 34)
        scroll.Parent = frame
        Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 4)
        lay.Parent = scroll
        local current = (Features.SkinMaps and Features.SkinMaps[weaponName]) or "(Default)"
        for _, skinName in ipairs(skins) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -8, 0, 30)
            b.BackgroundColor3 = (skinName == current) and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(34, 34, 44)
            b.BorderSizePixel = 0
            b.Text = "  " .. skinName
            b.TextColor3 = Color3.fromRGB(230, 230, 235)
            b.Font = Enum.Font.Gotham
            b.TextSize = 13
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.AutoButtonColor = true
            b.Parent = scroll
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.MouseButton1Click:Connect(function()
                Features.SkinMaps = Features.SkinMaps or {}
                Features.SkinMaps[weaponName] = skinName
                if Features.SkinChanger then
                    ApplySkinToWeapon(weaponName, skinName)
                end
                statusLbl.Text = weaponName .. "  →  " .. skinName
                g:Destroy()
            end)
        end
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(1, -16, 0, 30)
        close.Position = UDim2.new(0, 8, 1, -38)
        close.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        close.BorderSizePixel = 0
        close.Text = "Close"
        close.TextColor3 = Color3.fromRGB(230, 230, 235)
        close.Font = Enum.Font.GothamMedium
        close.TextSize = 13
        close.Parent = frame
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
        close.MouseButton1Click:Connect(function() g:Destroy() end)
    end

    local function makeWeaponList(page, catName, weapons)
        makeSection(page, catName)
        local holder = new("Frame", {
            Parent = page,
            Size = UDim2.new(1, 0, 0, 150),
            BackgroundColor3 = Color3.fromRGB(22, 22, 30),
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        corner(holder, 8)
        addRow(page, 150)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -8, 1, -8)
        scroll.Position = UDim2.new(0, 4, 0, 4)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.CanvasSize = UDim2.new(0, 0, 0, #weapons * 32)
        scroll.ZIndex = 4
        scroll.Parent = holder
        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 4)
        lay.Parent = scroll
        for _, wpn in ipairs(weapons) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, -6, 0, 28)
            row.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
            row.BorderSizePixel = 0
            local mapped = Features.SkinMaps and Features.SkinMaps[wpn]
            row.Text = "  " .. wpn .. (mapped and ("  ·  " .. mapped) or "")
            row.TextColor3 = Color3.fromRGB(225, 225, 235)
            row.Font = Enum.Font.Gotham
            row.TextSize = 12
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.AutoButtonColor = true
            row.ZIndex = 5
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
            row.MouseButton1Click:Connect(function()
                openSkinPicker(wpn)
                task.defer(function()
                    local mapped2 = Features.SkinMaps and Features.SkinMaps[wpn]
                    row.Text = "  " .. wpn .. (mapped2 and ("  ·  " .. mapped2) or "")
                end)
            end)
        end
    end

    makeWeaponList(skinsPage, "Primary", WEAPON_CATS.Primary)
    makeWeaponList(skinsPage, "Secondary", WEAPON_CATS.Secondary)
    makeWeaponList(skinsPage, "Melee", WEAPON_CATS.Melee)
    makeWeaponList(skinsPage, "Utility", WEAPON_CATS.Utility)

    makeButton(skinsPage, "Apply All Mapped Skins", function()
        ApplyAllMappedSkins()
        print("[Fanware] Applied skin map")
    end)
    new("TextLabel", {
        Parent = skinsPage,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        Text = "Client ViewModel swap. Only skins for the chosen weapon are listed.\nPaths: PlayerScripts.Assets.ViewModels",
        TextColor3 = Color3.fromRGB(140, 140, 155),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    })
    addRow(skinsPage, 48)
end

--==============================================================
-- PRESETS TAB
--==============================================================
do
    local presets = tabs["Presets"].page
    makeSection(presets, "ADS")
    registerUI("PresetADS", makeSlider(presets, "ADS Scale", 0.001, 100, 1, function(v)
        Features.PresetADS = v
        ApplyPresets()
    end), "slider")

    makeSection(presets, "FOV")
    registerUI("PresetFOV", makeSlider(presets, "FOV", 80, 180, 90, function(v)
        Features.PresetFOV = v
        ApplyPresets()
    end), "slider")

    makeSection(presets, "Sensitivity")
    registerUI("PresetSens", makeSlider(presets, "Sens", 0.001, 100, 0.5, function(v)
        Features.PresetSens = v
        ApplyPresets()
    end), "slider")

    makeButton(presets, "Apply Presets", function()
        ApplyPresets()
        print("[Fanware] Presets applied")
    end)
end

--==============================================================
-- SETTINGS TAB
--==============================================================
local settings = tabs["Settings"].page

makeToggle(settings, "Notify when someone is cheating", true, function(v) Features.NotifyRivals = v end)
makeToggle(settings, "Auto save config", false, function(v) Features.AutoSaveConfig = v end)
makeToggle(settings, "Auto execute on rejoin", false, function(v) Features.AutoExecute = v end)

makeButton(settings, "Clear Settings", function()
    for _, k in ipairs(FEATURE_BOOL_KEYS) do
        Features[k] = false
    end
    Features.SpeedPower = 60
    Features.FlySpeed = 50
    Features.SpinSpeed = 15
    Features.CustomLighting = "Off"
    Features.StretchRes = 1
    Features.DeviceMode = "PC"
    Features.Tornado = false
    Features.PresetADS = 1
    Features.PresetFOV = 90
    Features.PresetSens = 0.5
    Features.SkinChanger = false
    Features.SkinMaps = {}
    pcall(ClearDeviceIcon)
    pcall(function() Features.StretchRes = 1 ApplyStretchRes(1) end)
    Features.JoinPlayer = false
    Features.JoinUsername = ""
    DeactivateAllFeatures()
    pcall(SyncUIFromFeatures)
    print("[Fanware] Settings cleared")
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Parent = CoreGui
        local f = Instance.new("TextLabel")
        f.Size = UDim2.new(0, 260, 0, 36)
        f.Position = UDim2.new(0.5, -130, 0.12, 0)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        f.TextColor3 = Color3.fromRGB(200, 220, 255)
        f.Font = Enum.Font.Gotham
        f.TextSize = 13
        f.Text = "Settings cleared"
        f.Parent = g
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        task.delay(1.8, function() g:Destroy() end)
    end)
end)

local CONFIG_KEYS = {
    "Aimbot","AimbotTarget","AimbotSmoothness","AimbotFOV","AimbotMaxDist","AimbotWallCheck","AimbotTeamCheck","AimbotStickiness",
    "TriggerBot","TriggerBotDelay","TriggerBotAcquire","TriggerBotWallCheck","TriggerBotTeamCheck",
    "DeathLock","DeathLockTarget","DeathLockWallCheck","DeathLockTeamCheck",
    "DeathLockUltra","DeathLockUltraTarget","DeathLockUltraWallCheck","DeathLockUltraTeamCheck",
    "AutoShoot","AutoShootDelay","AutoShootAcquire","AutoShootTeamCheck",
    "ESP","Boxes","Skeleton","Tracers","ShowLife","ShowNames",
    "TPBehind","TPUp","InstaBackstab",
    "SpeedHack","SpeedPower","Noclip","Fly","FlySpeed","SpinBot","SpinSpeed",
    "JoinPlayer","JoinUsername",
    "NoMeleeCooldown","NoScopeCooldown","NotifyRivals","AutoSaveConfig","AutoExecute",
    "CustomLighting","StretchRes","DeviceMode","Tornado",
    "PresetADS","PresetFOV","PresetSens",
    "SkinChanger","SkinMaps",
}

local function BuildConfigTable()
    local t = {}
    for _, k in ipairs(CONFIG_KEYS) do
        local v = Features[k]
        if typeof(v) == "Color3" then
            t[k] = {v.R, v.G, v.B}
        else
            t[k] = v
        end
    end
    return t
end

local function ApplyConfigTable(t)
    if type(t) ~= "table" then return false end
    for _, k in ipairs(CONFIG_KEYS) do
        if t[k] ~= nil then
            Features[k] = t[k]
        end
    end
    task.defer(function()
        pcall(SyncUIFromFeatures)
    end)
    return true
end

local function SerializeConfig(t)
    local parts = {"{"}
    local function ser(v)
        if type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "boolean" or type(v) == "number" then
            return tostring(v)
        elseif type(v) == "table" then
            -- color3 array OR string map
            if v[1] ~= nil and v[2] ~= nil and v[3] ~= nil and v[4] == nil and type(v[1]) == "number" then
                return string.format("{%s,%s,%s}", tostring(v[1]), tostring(v[2]), tostring(v[3]))
            end
            local inner = {"{"}
            for ik, iv in pairs(v) do
                local ikey = type(ik) == "string" and string.format("[%q]", ik) or ("[" .. tostring(ik) .. "]")
                table.insert(inner, ikey .. "=" .. ser(iv) .. ",")
            end
            table.insert(inner, "}")
            return table.concat(inner)
        end
        return "nil"
    end
    for k, v in pairs(t) do
        table.insert(parts, string.format("[%q]", k) .. "=" .. ser(v) .. ",")
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

-- Free-config status label (updated by timer / ads)
local freeStatusLabel = new("TextLabel", {
    Parent = settings,
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.fromRGB(180, 200, 230),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
})
corner(freeStatusLabel, 6)
addRow(settings, 36)

RefreshFreeStatusLabel = function()
    local now = os.time()
    local txt
    if FreeConfig.Active and FreeConfig.ExpiresAt > now then
        txt = "  Free config ACTIVE — " .. FormatRemain(FreeConfig.ExpiresAt - now) .. " left"
        freeStatusLabel.TextColor3 = Color3.fromRGB(140, 255, 180)
    elseif FreeConfig.CooldownUntil > now then
        txt = "  Cooldown " .. FormatRemain(FreeConfig.CooldownUntil - now) .. "  ·  then " .. FREE_ADS_REQUIRED .. " ads"
        freeStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 120)
    else
        txt = string.format("  Ads %d/%d  ·  ready after ads  ·  window %s",
            FreeConfig.AdsWatched or 0,
            FREE_ADS_REQUIRED,
            FormatRemain(FreeConfig.DurationSeconds or FREE_DEFAULT_SECONDS)
        )
        freeStatusLabel.TextColor3 = Color3.fromRGB(180, 200, 230)
    end
    freeStatusLabel.Text = txt
end
RefreshFreeStatusLabel()

makeButton(settings, "Export Free Config [time: 12h]", function()
    -- default free export carries [time: 12h]; user can edit tag before sharing
    local tag = "[time: 12h]"
    local code = tag .. "--FANWARE_CFG--" .. SerializeConfig(BuildConfigTable()) .. "--END--"
    if setclipboard then
        pcall(function() setclipboard(code) end)
        print("[Fanware] Free config copied (tag " .. tag .. ")")
    else
        print("[Fanware] Free export:")
        print(code)
    end
    NotifyFree("Free config exported with " .. tag, Color3.fromRGB(180, 220, 255))
end)

makeButton(settings, "Export Setting (no timer)", function()
    local code = "--FANWARE_CFG--" .. SerializeConfig(BuildConfigTable()) .. "--END--"
    if setclipboard then
        pcall(function() setclipboard(code) end)
        print("[Fanware] Config copied to clipboard")
    else
        print("[Fanware] Export (copy this):")
        print(code)
    end
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "FanwareExport"
        g.Parent = CoreGui
        local f = Instance.new("TextLabel")
        f.Size = UDim2.new(0, 320, 0, 40)
        f.Position = UDim2.new(0.5, -160, 0.1, 0)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        f.TextColor3 = Color3.fromRGB(200, 230, 255)
        f.Font = Enum.Font.Gotham
        f.TextSize = 13
        f.Text = setclipboard and "Config copied to clipboard" or "Config printed to console"
        f.Parent = g
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        task.delay(2.5, function() g:Destroy() end)
    end)
end)

makeButton(settings, "Import Setting / Free Config", function()
    local box = Instance.new("ScreenGui")
    box.Name = "FanwareImport"
    box.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 180)
    frame.Position = UDim2.new(0.5, -210, 0.5, -90)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.Parent = box
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Paste Fanware config  ·  optional [time: 12h]"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -20, 0, 80)
    input.Position = UDim2.new(0, 10, 0, 36)
    input.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    input.TextColor3 = Color3.fromRGB(220, 220, 230)
    input.Font = Enum.Font.Code
    input.TextSize = 11
    input.Text = ""
    input.ClearTextOnFocus = false
    input.TextWrapped = true
    input.MultiLine = true
    input.Parent = frame
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)
    local apply = Instance.new("TextButton")
    apply.Size = UDim2.new(0.5, -14, 0, 32)
    apply.Position = UDim2.new(0, 10, 1, -42)
    apply.BackgroundColor3 = Color3.fromRGB(50, 90, 200)
    apply.Text = "Apply"
    apply.TextColor3 = Color3.fromRGB(255, 255, 255)
    apply.Font = Enum.Font.GothamMedium
    apply.TextSize = 13
    apply.Parent = frame
    Instance.new("UICorner", apply).CornerRadius = UDim.new(0, 6)
    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0.5, -14, 0, 32)
    cancel.Position = UDim2.new(0.5, 4, 1, -42)
    cancel.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    cancel.Text = "Cancel"
    cancel.TextColor3 = Color3.fromRGB(230, 230, 235)
    cancel.Font = Enum.Font.GothamMedium
    cancel.TextSize = 13
    cancel.Parent = frame
    Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 6)
    cancel.MouseButton1Click:Connect(function() box:Destroy() end)
    apply.MouseButton1Click:Connect(function()
        local raw = input.Text or ""
        local duration, tag = ParseTimeTag(raw)
        local cleaned = StripTimeTag(raw)
        local body = cleaned:match("%-%-FANWARE_CFG%-%-(.-)%-%-END%-%-") or cleaned
        body = body:gsub("^%s+", ""):gsub("%s+$", "")
        local ok, tbl = pcall(function()
            return loadstring("return " .. body)()
        end)
        if not (ok and ApplyConfigTable(tbl)) then
            warn("[Fanware] Import failed — bad code")
            box:Destroy()
            return
        end
        print("[Fanware] Config imported")
        if duration then
            FreeWindowRequired = true
            StartFreeWindow(duration, tag)
        else
            -- untagged = permanent (no free timer)
            FreeWindowRequired = false
        end
        pcall(function()
            ApplyCustomLighting(Features.CustomLighting)
            ApplyStretchRes(Features.StretchRes)
            ApplyDeviceMode(Features.DeviceMode)
            ApplyPresets()
            if Features.SkinChanger then ApplySkinChanger() end
            SyncUIFromFeatures()
        end)
        box:Destroy()
    end)
end)

makeButton(settings, "Watch Ad (free unlock)", function()
    WatchOneAd()
end)

makeButton(settings, "Start Free Window", function()
    local ok, why = CanStartNewFreeWindow()
    if not ok then
        NotifyFree("can't start: " .. tostring(why), Color3.fromRGB(255, 160, 120))
        return
    end
    StartFreeWindow(FreeConfig.DurationSeconds or FREE_DEFAULT_SECONDS, FreeConfig.SourceTag)
end)

-- cheat notify UI (bottom left)
local function NotifyCheater(name)
    if not Features.NotifyRivals then return end
    pcall(function()
        local g = Instance.new("ScreenGui")
        g.Name = "FanwareCheatNotify"
        g.ResetOnSpawn = false
        g.Parent = CoreGui
        local f = Instance.new("TextLabel")
        f.Size = UDim2.new(0, 340, 0, 44)
        f.Position = UDim2.new(0, 16, 1, -70)
        f.BackgroundColor3 = Color3.fromRGB(22, 18, 18)
        f.TextColor3 = Color3.fromRGB(255, 200, 120)
        f.Font = Enum.Font.GothamMedium
        f.TextSize = 14
        f.TextXAlignment = Enum.TextXAlignment.Left
        f.Text = "  " .. tostring(name) .. " is cheating in legos LOL"
        f.Parent = g
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(180, 80, 60)
        s.Thickness = 1
        s.Parent = f
        task.delay(4, function() g:Destroy() end)
    end)
end

-- simple heuristic: spin velocity / insane move speed flags (best-effort)
local flagged = {}
task.spawn(function()
    while task.wait(2.5) do
        if not Features.NotifyRivals then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not flagged[p] then
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    local spd = root.AssemblyLinearVelocity.Magnitude
                    if spd > 120 or hum.WalkSpeed > 40 then
                        flagged[p] = true
                        NotifyCheater(p.Name)
                    end
                end
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p) flagged[p] = nil end)

-- Auto save config to executor writefile if available
local function SaveConfigDisk()
    if not Features.AutoSaveConfig then return end
    pcall(function()
        if writefile then
            local code = "--FANWARE_CFG--" .. SerializeConfig(BuildConfigTable()) .. "--END--"
            writefile("Fanware_Config.txt", code)
        end
    end)
end

task.spawn(function()
    while task.wait(8) do
        SaveConfigDisk()
    end
end)

-- Auto execute: store loadstring path note (executor dependent)
if Features.AutoExecute then
    pcall(function()
        if writefile and readfile then
            -- keep a marker so user can queue on rejoin manually / via autoexec folder
            writefile("Fanware_AutoExec.txt", "Fansware_Fixed.luau v3.9")
        end
    end)
end


new("TextLabel", {
    Parent = settings,
    Size = UDim2.new(1, 0, 0, 70),
    BackgroundTransparency = 1,
    Text = "Supported executors: All\nJoin Discord: discord.gg/g9UAV8xC2p\nv3.9: free timed config [time: 12h] + 5 ads unlock",
    TextColor3 = Color3.fromRGB(150, 150, 165),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 999,
    ZIndex = 3,
})
addRow(settings, 70)

-- Credits
local creditsHolder = new("Frame", {
    Parent = settings,
    Size = UDim2.new(1, 0, 0, 88),
    BackgroundColor3 = Color3.fromRGB(22, 22, 30),
    BorderSizePixel = 0,
    ZIndex = 3,
})
corner(creditsHolder, 8)
stroke(creditsHolder, Color3.fromRGB(50, 50, 65), 1)
addRow(settings, 88)

new("TextLabel", {
    Parent = creditsHolder,
    Size = UDim2.new(1, -16, 0, 20),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundTransparency = 1,
    Text = "Credits",
    TextColor3 = Color3.fromRGB(138, 164, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
})
new("TextLabel", {
    Parent = creditsHolder,
    Size = UDim2.new(1, -16, 0, 52),
    Position = UDim2.new(0, 8, 0, 30),
    BackgroundTransparency = 1,
    Text = "Fansware by Fans\nDiscord: discord.gg/g9UAV8xC2p\nBuilt for Rivals · keyless",
    TextColor3 = Color3.fromRGB(190, 190, 205),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 4,
})

--==============================================================
-- RIGHT SHIFT TOGGLE
--==============================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        if activeDropdownList then
            activeDropdownList:Destroy()
            activeDropdownList = nil
        end
    elseif input.KeyCode == Enum.KeyCode.P then
        Features.Aimbot = not Features.Aimbot
        print("[Fanware] Aimbot:", Features.Aimbot and "ON" or "OFF")
    elseif input.KeyCode == Enum.KeyCode.Q then
        Features.DeathLockUltra = not Features.DeathLockUltra
        print("[Fanware] Death Lock ULTRA:", Features.DeathLockUltra and "ON" or "OFF")
    end
end)

--==============================================================
-- DRAG
--==============================================================
do
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            if activeDropdownList then
                activeDropdownList:Destroy()
                activeDropdownList = nil
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

print("[Fanware] v3.9 loaded — free timed config + ads unlock.")
