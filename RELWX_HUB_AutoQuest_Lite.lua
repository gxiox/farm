-- RELWX HUB UI

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = (function()
    local real = game:GetService("TweenService")
    local looping, liteOn = {}, true
    local proxy = {}
    proxy.Create = function(_, inst, info, goal)
        local t = real:Create(inst, info, goal)
        if info.RepeatCount ~= -1 then
            return t
        end
        looping[#looping + 1] = t
        return setmetatable({
            Play = function()
                if not liteOn then
                    t:Play()
                end
            end,
        }, {
            __index = function(_, k)
                local v = t[k]
                if type(v) == "function" then
                    return function(_, ...)
                        return v(t, ...)
                    end
                end
                return v
            end,
        })
    end
    proxy.SetLite = function(on)
        liteOn = on and true or false
        for _, t in ipairs(looping) do
            pcall(function()
                if liteOn then
                    t:Pause()
                else
                    t:Play()
                end
            end)
        end
    end
    return setmetatable(proxy, {
        __index = function(_, k)
            local v = real[k]
            if type(v) == "function" then
                return function(_, ...)
                    return v(real, ...)
                end
            end
            return v
        end,
    })
end)()
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local UI_FONT = "Montserrat"
local function E(name)
    local ok, v = pcall(function()
        return Enum.Font[name]
    end)
    return ok and v or Enum.Font.Gotham
end
local FontFamilies = {
    Montserrat = { R = E("Montserrat"), M = E("MontserratMedium"), B = E("MontserratBold") },
    BuilderSans = { R = E("BuilderSans"), M = E("BuilderSansMedium"), B = E("BuilderSansBold") },
    Gotham = { R = Enum.Font.Gotham, M = Enum.Font.GothamMedium, B = Enum.Font.GothamBold },
}
local FNT = FontFamilies[UI_FONT] or FontFamilies.Gotham

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SOUND_ON = "rbxasset://sounds/switch.wav"
local SOUND_OFF = "rbxasset://sounds/button.wav"
local SOUND_FALLBACK = "rbxasset://sounds/electronicpingshort.wav"

--==================================================
-- CONFIG  (Auto Save / Auto Load)
--==================================================

local CONFIG_FILE = "RELWX_HUB_Config.json"

local Defaults = {
    UIAccentColor = "#A78BFA",
    UIBackgroundColor = "#08080F",
    UIButtonColor = "#1E1B33",
    FloatingButtonColor = "#0C0B16",
    FloatingBorderColor = "#C4B5FD",
    FloatingGlowColor = "#8B5CF6",
    AutoFarmEnabled = false,
    AutoQuestEnabled = false,
    AutoClaimQuest = true,
    AutoMobByLevel = true,
    MobOver = 5,
    QuestCycleSec = 30,
    LiteMode = true,
    AutoGearEnabled = false,
    AutoCardEnabled = false,
    AutoRunEnabled = false,
    AutoReviveEnabled = false,
    AutoDodgeEnabled = false,
    TargetMonster = "",
    SoundEnabled = true,
    StatsVisible = true,
    UIScalePercent = 100,
    LastTab = "Home",
    WindowVisible = true,
    Maximized = false,
    CollapsedSections = "",
    WindowX = 0.5,
    WindowY = 0.5,
    FloatX = 0.04,
    FloatY = 0.25,
    StatsX = 0.5,
    StatsY = 0.045,
}

local Config = {}
for k, v in pairs(Defaults) do
    Config[k] = v
end

local LoadedFromFile = false

local function LoadConfig()
    if not (isfile and readfile) then
        return
    end
    local ok, exists = pcall(isfile, CONFIG_FILE)
    if not (ok and exists) then
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(Defaults) do
                if type(data[k]) == type(v) then
                    Config[k] = data[k]
                end
            end
            LoadedFromFile = true
        end
    end)
end

LoadConfig()
for _, k in ipairs({ "WindowX", "WindowY" }) do
    Config[k] = math.clamp(Config[k], 0.05, 0.95)
end
for _, k in ipairs({ "FloatX", "FloatY", "StatsX", "StatsY" }) do
    Config[k] = math.clamp(Config[k], 0.02, 0.98)
end
Config.UIScalePercent = math.clamp(Config.UIScalePercent, 60, 120)
TweenService.SetLite(Config.LiteMode)

local SaveHooks = {}
local SaveToken = 0

local function Fire(state)
    for _, h in ipairs(SaveHooks) do
        pcall(h, state)
    end
end

local function WriteNow()
    if not writefile then
        return "unsupported"
    end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
    return ok and "saved" or "failed"
end

local function SaveConfig(instant)
    SaveToken = SaveToken + 1
    local token = SaveToken
    Fire("saving")
    local function commit()
        if token ~= SaveToken then
            return
        end
        local result = WriteNow()
        Fire(result)
        if result == "saved" then
            task.delay(1.8, function()
                if token == SaveToken then
                    Fire("idle")
                end
            end)
        end
    end
    if instant then
        commit()
    else
        task.delay(0.3, commit)
    end
end

local function SetConfig(key, value)
    if Config[key] == value then
        return
    end
    Config[key] = value
    SaveConfig()
end


local function RGB(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function Lum(c)
    return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function Hex(key, fallback)
    local ok, c = pcall(Color3.fromHex, Config[key])
    return ok and c or fallback
end

local Theme = {}

local function ComputeTheme()
    local bg = Hex("UIBackgroundColor", RGB(8, 8, 8))
    local dark = Lum(bg) < 0.5
    local to = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    Theme.Bg = bg
    Theme.Surface = bg:Lerp(to, 0.05)
    Theme.Surface2 = bg:Lerp(to, 0.095)
    Theme.Stroke = bg:Lerp(to, 0.17)
    Theme.Text = dark and RGB(244, 244, 244) or RGB(20, 20, 20)
    Theme.Sub = Theme.Text:Lerp(bg, 0.16)
    Theme.Muted = Theme.Text:Lerp(bg, 0.38)
    Theme.Accent = Hex("UIAccentColor", RGB(190, 190, 190))
    Theme.OnAccent = Lum(Theme.Accent) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    Theme.Button = Hex("UIButtonColor", RGB(36, 36, 36))
    local h, s, v = Theme.Accent:ToHSV()
    if s < 0.12 then
        Theme.Accent2 = Theme.Accent:Lerp(Color3.fromRGB(96, 104, 128), 0.6)
    else
        Theme.Accent2 = Color3.fromHSV((h + 0.12) % 1, s, math.max(v, 0.6))
    end
end

ComputeTheme()

local ThemeHooks = {}

local function OnTheme(fn)
    ThemeHooks[#ThemeHooks + 1] = fn
    pcall(fn)
end

local function Bind(obj, prop, key)
    OnTheme(function()
        obj[prop] = Theme[key]
    end)
end

local function ApplyTheme()
    ComputeTheme()
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

--==================================================
-- HELPERS
--==================================================

local Orders = setmetatable({}, { __mode = "k" })
local function Next(parent)
    Orders[parent] = (Orders[parent] or 0) + 1
    return Orders[parent]
end

local function New(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function List(parent, padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function Text(parent, text, size, font, color, align)
    local l = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text or "",
        TextSize = size or 13,
        Font = font or FNT.R,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if type(color) == "string" then
        Bind(l, "TextColor3", color)
    elseif color then
        l.TextColor3 = color
    end
    return l
end

local function Tween(obj, t, props, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function Apply(obj, animate, props)
    if animate then
        Tween(obj, 0.16, props)
    else
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
end

local function Panel(parent, size, class)
    local f = New(class or "Frame", { BorderSizePixel = 0, LayoutOrder = Next(parent) }, parent)
    if class == "TextButton" then
        f.Text = ""
        f.AutoButtonColor = false
    end
    if size then
        f.Size = size
    end
    Bind(f, "BackgroundColor3", "Surface")
    f.BackgroundTransparency = 0.05
    Corner(f, 16)
    Bind(Stroke(f, Theme.Stroke, 1, 0.4), "Color", "Stroke")
    New("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.76, 0.76, 0.76)),
        Rotation = 90,
    }, f)
    local hi = New("Frame", {
        Size = UDim2.new(1, -28, 0, 1),
        Position = UDim2.fromOffset(14, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, f)
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hi)
    return f
end

local function HoverRow(btn)
    local st = btn:FindFirstChildOfClass("UIStroke")
    local sheen, edge
    if not btn:FindFirstChildOfClass("UIListLayout") and not btn:FindFirstChildOfClass("UIGridLayout") then
        btn.ClipsDescendants = true
        sheen = New("Frame", {
            Name = "Sheen",
            Size = UDim2.new(0, 70, 1, 0),
            Position = UDim2.new(-0.3, 0, 0, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 4,
        }, btn)
        New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.9),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, sheen)
        edge = New("Frame", {
            Size = UDim2.new(0, 3, 0, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
            ZIndex = 4,
        }, btn)
        Bind(edge, "BackgroundColor3", "Accent")
    end
    btn.MouseEnter:Connect(function()
        if sheen then
            sheen.Position = UDim2.new(-0.3, 0, 0, 0)
            Tween(sheen, 0.6, { Position = UDim2.new(1.1, 0, 0, 0) }, Enum.EasingStyle.Quad)
            Tween(edge, 0.2, { Size = UDim2.new(0, 3, 0.6, 0), BackgroundTransparency = 0.05 })
        end
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface2 })
        if st then
            Tween(st, 0.12, { Transparency = 0.05 })
        end
    end)
    local sc
    if btn:IsA("GuiButton") then
        sc = New("UIScale", { Scale = 1 }, btn)
        btn.MouseButton1Down:Connect(function()
            Tween(sc, 0.08, { Scale = 0.982 })
            pcall(function()
                if btn:FindFirstChildOfClass("UIListLayout") then
                    return
                end
                local m = UIS:GetMouseLocation()
                local ap, asz = btn.AbsolutePosition, btn.AbsoluteSize
                if asz.X < 1 or asz.Y < 1 then
                    return
                end
                btn.ClipsDescendants = true
                local r = New("Frame", {
                    Size = UDim2.fromOffset(0, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale((m.X - ap.X) / asz.X, (m.Y - ap.Y) / asz.Y),
                    BackgroundColor3 = Theme.Accent,
                    BackgroundTransparency = 0.7,
                    BorderSizePixel = 0,
                    ZIndex = 5,
                }, btn)
                Corner(r, 200)
                Tween(r, 0.55, { Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
                task.delay(0.6, function()
                    r:Destroy()
                end)
            end)
        end)
        btn.MouseButton1Up:Connect(function()
            Tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
    end
    btn.MouseLeave:Connect(function()
        if edge then
            Tween(edge, 0.2, { Size = UDim2.new(0, 3, 0, 0), BackgroundTransparency = 1 })
        end
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface })
        if st then
            Tween(st, 0.12, { Transparency = 0.4 })
        end
        if sc then
            Tween(sc, 0.12, { Scale = 1 })
        end
    end)
end

local function AccentGrad(parent, rotation)
    local g = New("UIGradient", { Rotation = rotation or 0 }, parent)
    OnTheme(function()
        g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    end)
    return g
end

local function Tint(parent)
    local t = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, parent)
    Corner(t, 12)
    local g = AccentGrad(t, 25)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 1),
    })
    return t
end

local function IsPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function Icon(parent, kind, x, y)
    local box = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(x, y),
        BackgroundTransparency = 1,
    }, parent)
    local parts = {}
    local function rect(px, py, w, h, r, rot)
        local f = New("Frame", {
            Size = UDim2.fromOffset(w, h),
            Position = UDim2.fromOffset(px, py),
            BorderSizePixel = 0,
            Rotation = rot or 0,
        }, box)
        Corner(f, r or 1)
        parts[#parts + 1] = { f = f }
        return f
    end
    if kind == "grid" then
        rect(1, 1, 7, 7, 2)
        rect(10, 1, 7, 7, 2)
        rect(1, 10, 7, 7, 2)
        rect(10, 10, 7, 7, 2)
    elseif kind == "sliders" then
        rect(1, 2, 16, 2, 1)
        rect(1, 8, 11, 2, 1)
        rect(1, 14, 14, 2, 1)
    elseif kind == "close" then
        rect(1, 8, 16, 2, 1, 45)
        rect(1, 8, 16, 2, 1, -45)
    elseif kind == "max" then
        local r = New("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(3, 3),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 3)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
    else -- ring (settings)
        local r = New("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 8)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
        rect(7, 7, 4, 4, 2)
    end
    return function(c)
        for _, p in ipairs(parts) do
            if p.stroke then
                p.stroke.Color = c
            else
                p.f.BackgroundColor3 = c
            end
        end
    end
end

--==================================================
-- ROOT GUI
--==================================================

pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do
        if v.Name == "RELWX_UI" or v.Name == "RELWX_Floating" or v.Name == "RELWX_Stats"
            or v.Name == "TwoSki_RideAPet_Floating" then
            v:Destroy()
        end
    end
end)

local Screen = New("ScreenGui", {
    Name = "RELWX_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local Conns = {}
local function Track(c)
    Conns[#Conns + 1] = c
    return c
end
Screen.Destroying:Connect(function()
    for _, c in ipairs(Conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
end)

local BW, BH = 740, 580
local SW = 172

local function ViewSize()
    local s = Screen.AbsoluteSize
    if s.X > 0 and s.Y > 0 then
        return s
    end
    return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

local function TargetScale()
    local v = ViewSize()
    local fit = math.min(v.X * 0.97 / BW, v.Y * 0.95 / BH)
    local base = math.min(fit * (Config.Maximized and 1 or 0.92), Config.Maximized and 1.4 or 1.1)
    local s = base * (Config.UIScalePercent / 100)
    return math.clamp(s, 0.3, math.max(0.3, fit))
end

local Main = New("CanvasGroup", {
    Name = "Main",
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.WindowX, Config.WindowY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.04,
    GroupTransparency = 1,
    Active = true,
    Visible = false,
}, Screen)
Bind(Main, "BackgroundColor3", "Bg")
Corner(Main, 26)
Main.BackgroundTransparency = 1
Main.Active = false
do
    local d = New("CanvasGroup", {
        Name = "Deco",
        Size = UDim2.new(1, -100, 1, -84),
        Position = UDim2.fromOffset(88, 72),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.03,
    }, Main)
    Bind(d, "BackgroundColor3", "Bg")
    Corner(d, 22)
    local g = New("Frame", {
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, d)
    local gg = AccentGrad(g, 90)
    gg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.58),
        NumberSequenceKeypoint.new(1, 1),
    })
    local v = New("Frame", {
        Size = UDim2.new(1, 0, 0, 90),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
    }, d)
    New("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0.55),
        }),
    }, v)

    local function Glow(key, sz, x0, y0, x1, y1, dur)
        local c = New("Frame", {
            Size = UDim2.fromOffset(sz, sz),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x0, y0),
            BackgroundTransparency = 1,
        }, d)
        for i = 0, 7 do
            local k = sz * (1 - i * 0.11)
            local l = New("Frame", {
                Size = UDim2.fromOffset(k, k),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundTransparency = 0.965,
                BorderSizePixel = 0,
            }, c)
            Corner(l, k)
            Bind(l, "BackgroundColor3", key)
        end
        TweenService:Create(
            c,
            TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.fromScale(x1, y1) }
        ):Play()
    end
    Glow("Accent", 440, 0.08, 0.1, 0.35, 0.3, 10)
    Glow("Accent2", 480, 0.95, 0.95, 0.68, 0.72, 12)
    Glow("Accent", 320, 0.92, 0.12, 0.74, 0.4, 9)

    local comets = {}
    for i = 1, 2 do
        local c = New("Frame", {
            Size = UDim2.fromOffset(7, 7),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 8,
        }, d)
        Corner(c, 4)
        local cs = Stroke(c, Theme.Accent, 5, 0.55)
        Bind(cs, "Color", (i == 1) and "Accent" or "Accent2")
        comets[i] = c
    end
    local cacc = 0
    Track(RunService.RenderStepped:Connect(function()
        if Config.LiteMode or not Main.Visible then
            return
        end
        local sz = d.AbsoluteSize
        local wx, wy = math.max(sz.X, 1), math.max(sz.Y, 1)
        local total = 2 * (wx + wy)
        for i, c in ipairs(comets) do
            local dist = (os.clock() * 260 + (i - 1) * total / 2) % total
            if dist < wx then
                c.Position = UDim2.new(dist / wx, 0, 0, 3)
            elseif dist < wx + wy then
                c.Position = UDim2.new(1, -3, (dist - wx) / wy, 0)
            elseif dist < 2 * wx + wy then
                c.Position = UDim2.new(1 - (dist - wx - wy) / wx, 0, 1, -3)
            else
                c.Position = UDim2.new(0, 3, 1 - (dist - 2 * wx - wy) / wy, 0)
            end
        end
    end))

    local wm = New("TextLabel", {
        Size = UDim2.fromOffset(420, 110),
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -14, 1, -4),
        BackgroundTransparency = 1,
        Text = "RELWX",
        Font = FNT.B,
        TextSize = 96,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 0.86,
    }, d)
    Bind(wm, "TextColor3", "Accent")

    local rf = New("Frame", {
        Size = UDim2.new(0.35, 0, 2, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.15, 0.5),
        Rotation = 18,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, d)
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.9),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, rf)
    TweenService:Create(
        rf,
        TweenInfo.new(11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Position = UDim2.fromScale(0.9, 0.5) }
    ):Play()

    local inner = New("Frame", {
        Size = UDim2.new(1, -10, 1, -10),
        Position = UDim2.fromOffset(5, 5),
        BackgroundTransparency = 1,
    }, d)
    Corner(inner, 18)
    Stroke(inner, Color3.new(1, 1, 1), 1, 0.92)
end

local function Aurora(key, rot)
    local f = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, Main:FindFirstChild("Deco"))
    Bind(f, "BackgroundColor3", key)
    Corner(f, 18)
    New("UIGradient", {
        Rotation = rot,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.82),
            NumberSequenceKeypoint.new(0.55, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, f)
end
Aurora("Accent", 35)
Aurora("Accent2", 215)

do
    local function Orb(key, sz, x0, y0, x1, y1, dur, tr)
        local o = New("Frame", {
            Size = UDim2.fromOffset(sz, sz),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(x0, y0),
            BorderSizePixel = 0,
            BackgroundTransparency = tr,
        }, Main:FindFirstChild("Deco"))
        Corner(o, sz // 2)
        Bind(o, "BackgroundColor3", key)
        New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Rotation = 90,
        }, o)
        TweenService:Create(
            o,
            TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.fromScale(x1, y1) }
        ):Play()
    end
    Orb("Accent", 320, 0.15, 0.2, 0.45, 0.45, 9, 0.82)
    Orb("Accent2", 360, 0.9, 0.85, 0.55, 0.55, 11, 0.84)
    Orb("Accent", 220, 0.8, 0.1, 0.65, 0.35, 8, 0.88)

    task.spawn(function()
        while Screen.Parent do
            task.wait(1.2 + math.random() * 2.5)
            if not Config.LiteMode and Main.Visible and Main.GroupTransparency < 0.5 then
                pcall(function()
                    local st = New("Frame", {
                        Size = UDim2.fromOffset(110, 2),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(math.random() * 0.6, -0.05),
                        Rotation = 28,
                        BorderSizePixel = 0,
                        BackgroundColor3 = Theme.Accent,
                        ZIndex = 2,
                    }, Main:FindFirstChild("Deco"))
                    New("UIGradient", {
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(1, 0.1),
                        }),
                    }, st)
                    local x1 = st.Position.X.Scale + 0.45
                    Tween(st, 0.9, { Position = UDim2.fromScale(x1, 1.1), BackgroundTransparency = 0.6 }, Enum.EasingStyle.Quad)
                    task.delay(1, function()
                        st:Destroy()
                    end)
                end)
            end
        end
    end)

    local acc = 0
    Track(RunService.RenderStepped:Connect(function(dt)
        acc = acc + dt
        if acc < 0.04 or Config.LiteMode or not Main.Visible then
            return
        end
        acc = 0
        local m = UIS:GetMouseLocation()
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        if m.X < ap.X or m.Y < ap.Y or m.X > ap.X + asz.X or m.Y > ap.Y + asz.Y then
            return
        end
        if UIS:GetLastInputType() ~= Enum.UserInputType.MouseMovement then
            return
        end
        local d = New("Frame", {
            Size = UDim2.fromOffset(5, 5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(m.X + math.random(-4, 4), m.Y + math.random(-4, 4)),
            BorderSizePixel = 0,
            BackgroundColor3 = (math.random() < 0.5) and Theme.Accent or Theme.Accent2,
            BackgroundTransparency = 0.3,
            ZIndex = 40,
        }, Screen)
        Corner(d, 3)
        Tween(d, 0.5, {
            Size = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(m.X + math.random(-14, 14), m.Y + math.random(6, 22)),
        }, Enum.EasingStyle.Quad)
        task.delay(0.55, function()
            d:Destroy()
        end)
    end))

    for i = 1, 11 do
        local v = New("Frame", {
            Size = UDim2.new(0, 1, 1, 0),
            Position = UDim2.fromScale(i / 12, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.975,
            BorderSizePixel = 0,
        }, Main:FindFirstChild("Deco"))
        New("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, v)
    end
    for i = 1, 7 do
        local h = New("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.fromScale(0, i / 8),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.975,
            BorderSizePixel = 0,
        }, Main:FindFirstChild("Deco"))
        New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, h)
    end

    local scan = New("Frame", {
        Size = UDim2.new(1, 0, 0, 70),
        Position = UDim2.new(0, 0, 0, -80),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    }, Main:FindFirstChild("Deco"))
    New("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.94),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, scan)
    TweenService:Create(
        scan,
        TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 5),
        { Position = UDim2.new(0, 0, 1, 10) }
    ):Play()
end

local Dust = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main:FindFirstChild("Deco"))
for i = 1, 16 do
    local sz = math.random(2, 4)
    local x = math.random()
    local p = New("Frame", {
        Size = UDim2.fromOffset(sz, sz),
        Position = UDim2.fromScale(x, 1.05),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.55 + math.random() * 0.3,
    }, Dust)
    Corner(p, 2)
    Bind(p, "BackgroundColor3", (i % 2 == 0) and "Accent" or "Accent2")
    local dur = 9 + math.random() * 9
    TweenService:Create(
        p,
        TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, math.random() * 5),
        { Position = UDim2.fromScale(math.clamp(x + (math.random() - 0.5) * 0.15, 0, 1), -0.05) }
    ):Play()
end

local MainStroke = Stroke(Main, Color3.new(1, 1, 1), 1.5, 1)
local MainGrad = New("UIGradient", { Rotation = 0 }, MainStroke)
OnTheme(function()
    local h, sat = Theme.Accent:ToHSV()
    sat = math.max(sat, 0.6)
    MainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.25, Color3.fromHSV((h + 0.1) % 1, sat, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.25) % 1, sat, 1)),
        ColorSequenceKeypoint.new(0.75, Color3.fromHSV((h + 0.1) % 1, sat, 1)),
        ColorSequenceKeypoint.new(1, Theme.Accent),
    })
end)
TweenService:Create(
    MainGrad,
    TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()
local MainScale = New("UIScale", { Scale = TargetScale() }, Main)
do
    local gs = Stroke(Main:FindFirstChild("Deco"), Theme.Accent, 14, 0.8)
    Bind(gs, "Color", "Accent")
    TweenService:Create(
        gs,
        TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.96 }
    ):Play()
end

local Shadow = New("Frame", {
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 0,
    Visible = false,
}, Screen)
local ShadowScale = New("UIScale", { Scale = 1 }, Shadow)
local ShadowLayers = {}
for i, g in ipairs({ 8, 20, 36, 56 }) do
    local l = New("Frame", {
        Size = UDim2.new(1, g * 2, 1, g * 2),
        Position = UDim2.fromOffset(-g, -g + 10),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, Shadow)
    Corner(l, 18 + g)
    ShadowLayers[i] = { f = l, base = 0.82 + i * 0.03 }
end
local ShadowGlow = New("Frame", {
    Size = UDim2.new(1, 40, 1, 40),
    Position = UDim2.fromOffset(-20, -20),
    BorderSizePixel = 0,
}, Shadow)
Corner(ShadowGlow, 38)
Bind(ShadowGlow, "BackgroundColor3", "Accent")
ShadowLayers[#ShadowLayers + 1] = { f = ShadowGlow, base = 0.95 }

Track(RunService.RenderStepped:Connect(function()
    local vis = Main.Visible
    Shadow.Visible = false
    if not vis then
        return
    end
    Shadow.Position = Main.Position
    Shadow.Size = Main.Size
    ShadowScale.Scale = MainScale.Scale
    local a = Main.GroupTransparency
    for _, l in ipairs(ShadowLayers) do
        l.f.BackgroundTransparency = 1 - (1 - l.base) * (1 - a)
    end
end))

local TopGlow = New("Frame", {
    Size = UDim2.new(0.8, 0, 0, 1),
    Position = UDim2.fromScale(0.1, 0),
    BorderSizePixel = 0,
}, Main)
Bind(TopGlow, "BackgroundColor3", "Accent")
TopGlow.Visible = false
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, TopGlow)

local Opening = false

local function ApplyScale(animate)
    if Opening then
        return
    end
    if animate and Main.Visible then
        Tween(MainScale, 0.25, { Scale = TargetScale() }, Enum.EasingStyle.Quint)
    else
        MainScale.Scale = TargetScale()
    end
end

Track(Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    ApplyScale(false)
end))

local function PlayToggleSound(on, big)
    if not Config.SoundEnabled then
        return
    end
    pcall(function()
        local function play(id, vol, speed)
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol
            s.PlaybackSpeed = speed
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 2.5)
            return s
        end
        local speed = (on and 1.18 or 0.86) * (big and 0.85 or 1)
        local s = play(on and SOUND_ON or SOUND_OFF, big and 0.7 or 0.6, speed)
        task.delay(0.35, function()
            if s.Parent and s.TimeLength == 0 then
                play(SOUND_FALLBACK, 0.55, on and 1.35 or 0.85)
            end
        end)
    end)
end

local function FloatCenter()
    local s = Screen.AbsoluteSize
    return s.X * Config.FloatX, s.Y * Config.FloatY
end

local function FxRing(cx, cy, size, thick, dur, color)
    local r = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
    }, Screen)
    Corner(r, 9999)
    local st = Stroke(r, color or Theme.Accent, thick, 0.05)
    Tween(r, dur, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quint)
    Tween(st, dur, { Transparency = 1, Thickness = 0.5 }, Enum.EasingStyle.Quad)
    Debris:AddItem(r, dur + 0.15)
end

local function FxSparks(cx, cy, spread, count, dist)
    for i = 1, count do
        local ang = math.random() * math.pi * 2
        local d = dist * (0.45 + math.random() * 0.8)
        local sz = math.random(3, 6)
        local px = cx + (math.random() - 0.5) * spread
        local col = (i % 3 == 0) and Color3.new(1, 1, 1) or ((i % 2 == 0) and Theme.Accent or Theme.Accent2)
        local p = New("Frame", {
            Size = UDim2.fromOffset(sz, sz),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(px, cy),
            BorderSizePixel = 0,
            BackgroundColor3 = col,
            ZIndex = 61,
        }, Screen)
        Corner(p, 3)
        local dur = 0.45 + math.random() * 0.45
        Tween(p, dur, {
            Position = UDim2.fromOffset(px + math.cos(ang) * d, cy + math.sin(ang) * d * 0.85),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(1, 1),
        }, Enum.EasingStyle.Quint)
        Debris:AddItem(p, dur + 0.15)
    end
end

local function FxBeam(cx, cy, w)
    local b = New("Frame", {
        Size = UDim2.fromOffset(w, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 62,
    }, Screen)
    New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        }),
    }, b)
    Stroke(b, Theme.Accent, 5, 0.65)
    Debris:AddItem(b, 2)
    return b
end

local AnimToken = 0

local function PlayOpen()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    local t = TargetScale()
    local fx, fy = FloatCenter()

    MainStroke.Thickness = 1.5
    Main.Size = UDim2.fromOffset(BW, BH)
    Main.Position = UDim2.fromOffset(fx, fy)
    Main.GroupTransparency = 1
    MainScale.Scale = t * 0.12
    Main.Visible = true

    PlayToggleSound(true, true)
    FxRing(fx, fy, 120, 3, 0.55)
    FxSparks(fx, fy, 6, 12, 60)
    pcall(function()
        local fl = New("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.9,
            BorderSizePixel = 0,
            ZIndex = 58,
        }, Screen)
        Tween(fl, 0.6, { BackgroundTransparency = 1 })
        task.delay(0.65, function()
            fl:Destroy()
        end)
        for i = 1, 3 do
            task.delay(i * 0.1, function()
                FxRing(fx, fy, 80 + i * 70, 2, 0.6, (i % 2 == 0) and Theme.Accent2 or Theme.Accent)
            end)
        end
    end)

    Tween(Main, 0.3, { GroupTransparency = 0 })
    Tween(Main, 0.6, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    Tween(MainScale, 0.65, { Scale = t }, Enum.EasingStyle.Back)

    task.delay(0.5, function()
        if token ~= AnimToken then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        FxRing(ap.X + asz.X / 2, ap.Y + asz.Y / 2, math.max(asz.X, asz.Y) * 1.05, 2, 0.7, Theme.Accent2)
        FxRing(ap.X + asz.X / 2, ap.Y + asz.Y / 2, math.max(asz.X, asz.Y) * 1.35, 1, 0.9, Theme.Accent)
        FxSparks(ap.X + asz.X / 2, ap.Y + asz.Y / 2, math.max(asz.X, asz.Y) * 0.5, 22, 120)
    end)
    task.delay(0.68, function()
        if token == AnimToken then
            Opening = false
        end
    end)
end

local function PlayClose()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    PlayToggleSound(false, true)

    local s0 = MainScale.Scale
    local function alive()
        return token == AnimToken
    end

    Tween(MainScale, 0.14, { Scale = s0 * 1.03 }, Enum.EasingStyle.Sine)
    Tween(MainStroke, 0.3, { Thickness = 3.5 }, Enum.EasingStyle.Sine)

    task.delay(0.14, function()
        if not alive() then
            return
        end
        Tween(Main, 0.36, { GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Tween(MainScale, 0.36, { Scale = s0 * 0.97 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    end)

    task.delay(0.5, function()
        if not alive() then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        local cx, cy = ap.X + asz.X / 2, ap.Y + asz.Y / 2
        local w = math.max(asz.X, 40)

        Main.Visible = false
        Main.Size = UDim2.fromOffset(BW, BH)
        Main.Position = UDim2.fromScale(Config.WindowX, Config.WindowY)
        MainScale.Scale = s0
        MainStroke.Thickness = 1.5

        local beam = FxBeam(cx, cy, w)
        FxRing(cx, cy, w * 0.75, 3, 0.6)
        FxRing(cx, cy, w * 0.45, 2, 0.5, Theme.Accent2)
        FxSparks(cx, cy, w, 28, 150 * math.max(s0, 0.6))
        FxSparks(cx, cy, w * 0.6, 24, 230 * math.max(s0, 0.6))
        FxRing(cx, cy, w * 1.1, 1, 0.8, Theme.Accent)
        pcall(function()
            local fl = New("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.86,
                BorderSizePixel = 0,
                ZIndex = 58,
            }, Screen)
            Tween(fl, 0.55, { BackgroundTransparency = 1 })
            task.delay(0.6, function()
                fl:Destroy()
            end)
            for i = 1, 4 do
                task.delay(i * 0.08, function()
                    FxRing(cx, cy, w * (0.4 + i * 0.35), 2, 0.7, (i % 2 == 0) and Theme.Accent2 or Theme.Accent)
                end)
            end
        end)
        Tween(beam, 0.26, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        task.delay(0.28, function()
            local fx, fy = FloatCenter()
            Tween(beam, 0.36, {
                Position = UDim2.fromOffset(fx, fy),
                Size = UDim2.fromOffset(8, 8),
            }, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
            task.delay(0.36, function()
                beam:Destroy()
                FxRing(fx, fy, 100, 3, 0.55)
                FxSparks(fx, fy, 6, 12, 50)
                if alive() then
                    Opening = false
                end
            end)
        end)
    end)
end

local function SetWindow(visible)
    SetConfig("WindowVisible", visible)
    if visible then
        PlayOpen()
    else
        PlayClose()
    end
end

local function SavePosition(target, kx, ky)
    local s = Screen.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then
        return
    end
    local c = target.AbsolutePosition + target.AbsoluteSize / 2
    local fx = math.clamp(c.X / s.X, 0.02, 0.98)
    local fy = math.clamp(c.Y / s.Y, 0.02, 0.98)
    target.Position = UDim2.fromScale(fx, fy)
    SetConfig(kx, math.floor(fx * 10000) / 10000)
    SetConfig(ky, math.floor(fy * 10000) / 10000)
end

local function MakeDraggable(handle, target, kx, ky, onClick)
    local dragging, dragInput, startPos, startCenter, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            moved = false
            dragInput = input
            startPos = input.Position
            startCenter = target.AbsolutePosition + target.AbsoluteSize / 2
        end
    end)

    Track(UIS.InputChanged:Connect(function(input)
        if not dragging or not IsMove(input) then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        local d = input.Position - startPos
        if d.Magnitude > 8 then
            moved = true
        end
        if moved then
            local s = Screen.AbsoluteSize
            target.Position = UDim2.fromOffset(
                math.clamp(startCenter.X + d.X, 0, s.X),
                math.clamp(startCenter.Y + d.Y, 0, s.Y)
            )
        end
    end))

    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
                return
            end
            dragging = false
            if moved then
                SavePosition(target, kx, ky)
            elseif onClick then
                onClick()
            end
        end
    end))
end

local ActiveToast
local function Toast(text, on)
    if ActiveToast then
        ActiveToast:Destroy()
        ActiveToast = nil
    end
    local t = New("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 48),
        BorderSizePixel = 0,
        Text = text,
        TextSize = 12,
        Font = FNT.M,
        BackgroundColor3 = Theme.Surface2,
        TextColor3 = Theme.Text,
        ZIndex = 300,
    }, Screen)
    Corner(t, 19)
    Stroke(t, Theme.Accent, 1, 0.55)
    Pad(t, 38, 18, 0, 0)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, -24, 0.5, -4),
        BorderSizePixel = 0,
        BackgroundColor3 = (on == true) and RGB(70, 200, 120) or (on == false and Theme.Muted or Theme.Accent),
    }, t)
    Corner(dot, 4)
    ActiveToast = t
    local bar = New("Frame", {
        Size = UDim2.new(1, -24, 0, 2),
        Position = UDim2.new(0, 12, 1, -3),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.2,
    }, t)
    Corner(bar, 1)
    Tween(bar, 1.7, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    Tween(t, 0.35, { Position = UDim2.new(0.5, 0, 1, -26) }, Enum.EasingStyle.Back)
    task.delay(1.7, function()
        if ActiveToast == t then
            Tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, 48) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function()
                t:Destroy()
                if ActiveToast == t then
                    ActiveToast = nil
                end
            end)
        end
    end)
end

--==================================================
-- SAVE STATUS PILL
--==================================================

local SaveStates = {
    idle = { "Auto Save", nil },
    saving = { "กำลังบันทึก...", RGB(240, 190, 60) },
    saved = { "บันทึกแล้ว", RGB(70, 200, 120) },
    failed = { "บันทึกไม่ได้", RGB(235, 75, 90) },
    unsupported = { "ไม่รองรับไฟล์", RGB(235, 75, 90) },
}

local function StatusPill(parent, width)
    local pill = New("Frame", { Size = UDim2.fromOffset(width or 108, 26), BorderSizePixel = 0 }, parent)
    Bind(pill, "BackgroundColor3", "Surface2")
    Corner(pill, 13)
    Bind(Stroke(pill, Theme.Stroke, 1, 0.3), "Color", "Stroke")

    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, 11, 0.5, -4),
        BorderSizePixel = 0,
    }, pill)
    Corner(dot, 4)

    local label = Text(pill, "", 10, FNT.M, "Sub")
    label.Position = UDim2.fromOffset(26, 0)
    label.Size = UDim2.new(1, -30, 1, 0)

    local current = "idle"
    local function render()
        local s = SaveStates[current]
        label.Text = s[1]
        dot.BackgroundColor3 = s[2] or Theme.Accent
    end
    OnTheme(render)

    SaveHooks[#SaveHooks + 1] = function(state)
        current = state
        render()
    end
    return pill
end


local StatsGui = New("ScreenGui", {
    Name = "RELWX_Stats",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
    Enabled = Config.StatsVisible,
}, PlayerGui)

local StatsBox = New("Frame", {
    Size = UDim2.fromOffset(152, 30),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.StatsX, Config.StatsY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.1,
    Active = true,
}, StatsGui)
Bind(StatsBox, "BackgroundColor3", "Surface")
Corner(StatsBox, 15)
Bind(Stroke(StatsBox, Theme.Stroke, 1, 0.2), "Color", "Stroke")

local FpsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
FpsLabel.RichText = true
FpsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local MsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
MsLabel.RichText = true
MsLabel.Position = UDim2.new(0.5, 1, 0, 0)
MsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local StatsDivider = New("Frame", {
    Size = UDim2.fromOffset(1, 14),
    Position = UDim2.new(0.5, 0, 0.5, -7),
    BorderSizePixel = 0,
}, StatsBox)
Bind(StatsDivider, "BackgroundColor3", "Stroke")

MakeDraggable(StatsBox, StatsBox, "StatsX", "StatsY")

local Metrics = { fps = 60, ping = 0 }

do
    local frames, acc = 0, 0
    Track(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        acc = acc + dt
        if acc >= 0.5 then
            Metrics.fps = math.floor(frames / acc + 0.5)
            frames, acc = 0, 0
        end
    end))
end

local function GetPing()
    local ok, v = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(v) == "number") and math.floor(v + 0.5) or 0
end

local function Level(value, good, mid, higherIsBetter)
    local g, m, b = RGB(70, 200, 120), RGB(240, 190, 60), RGB(235, 75, 90)
    if higherIsBetter then
        return value >= good and g or (value >= mid and m or b)
    end
    return value <= good and g or (value <= mid and m or b)
end

local function RefreshStats()
    Metrics.ping = GetPing()
    local fc = Level(Metrics.fps, 50, 30, true)
    local mc = Level(Metrics.ping, 80, 160, false)
    local muted = "#" .. Theme.Muted:ToHex()
    FpsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">FPS</font>',
        fc:ToHex(), Metrics.fps, muted
    )
    MsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">MS</font>',
        mc:ToHex(), Metrics.ping, muted
    )
end

--==================================================
-- TOP BAR
--==================================================

local Top = New("Frame", {
    Size = UDim2.new(1, -56, 0, 56),
    Position = UDim2.fromOffset(28, 8),
    BorderSizePixel = 0,
}, Main)
Bind(Top, "BackgroundColor3", "Bg")
Top.BackgroundTransparency = 0.03
do
    local tint = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, Top)
    Corner(tint, 28)
    Bind(tint, "BackgroundColor3", "Accent")
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.86),
            NumberSequenceKeypoint.new(0.5, 0.95),
            NumberSequenceKeypoint.new(1, 0.86),
        }),
    }, tint)
end
Corner(Top, 28)
do
    local ts = Stroke(Top, Color3.new(1, 1, 1), 1.5, 0.2)
    local tg = New("UIGradient", { Rotation = 0 }, ts)
    OnTheme(function()
        tg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Stroke),
            ColorSequenceKeypoint.new(0.5, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Stroke),
        })
    end)
    TweenService:Create(
        tg,
        TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
        { Rotation = 360 }
    ):Play()
end

local TopLine = New("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 1, -1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Top)
do
    local g = AccentGrad(TopLine, 0)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0.95),
    })
end

Top.ClipsDescendants = true
local Shine = New("Frame", {
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(-0.3, 0, 0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, Top)
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.93),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, Shine)
TweenService:Create(
    Shine,
    TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 4),
    { Position = UDim2.new(1.1, 0, 0, 0) }
):Play()

local Badge = New("Frame", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.fromOffset(16, 13),
    BorderSizePixel = 0,
}, Top)
Badge.BackgroundColor3 = Color3.new(1, 1, 1)
AccentGrad(Badge, 45)
Corner(Badge, 10)
Bind(Stroke(Badge, Theme.Accent, 1.5, 0.65), "Color", "Accent")
local BadgeText = Text(Badge, "RX", 13, FNT.B, nil, Enum.TextXAlignment.Center)
BadgeText.Size = UDim2.fromScale(1, 1)
Bind(BadgeText, "TextColor3", "OnAccent")

do
    Badge.ClipsDescendants = true
    local gl = New("Frame", {
        Size = UDim2.fromOffset(12, 60),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, -20, 0.5, 0),
        Rotation = 25,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, Badge)
    TweenService:Create(
        gl,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.5),
        { Position = UDim2.new(1, 20, 0.5, 0) }
    ):Play()
end

local Brand = Text(Top, "", 15, FNT.B, "Text")
Brand.RichText = true
OnTheme(function()
    Brand.Text = 'RELWX <font color="#' .. Theme.Accent:ToHex() .. '">HUB</font>'
end)
Brand.Position = UDim2.fromOffset(60, 10)
Brand.Size = UDim2.new(1, -270, 0, 22)

local BrandSub = Text(Top, tostring(game.Name or ""), 10, FNT.R, "Muted")
BrandSub.Position = UDim2.fromOffset(60, 31)
BrandSub.Size = UDim2.new(1, -270, 0, 16)

local function WindowButton(kind, xOffset, danger)
    local b = New("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, xOffset, 0.5, -16),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, Top)
    Corner(b, 10)
    Bind(b, "BackgroundColor3", "Surface2")
    local paint = Icon(b, kind, 7, 7)
    OnTheme(function()
        paint(Theme.Sub)
    end)
    b.MouseEnter:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = danger and RGB(200, 70, 80) or Theme.Button })
        paint(danger and RGB(255, 255, 255) or Theme.Text)
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = Theme.Surface2 })
        paint(Theme.Sub)
    end)
    return b
end

local MaxBtn = WindowButton("max", -86, false)
local CloseBtn = WindowButton("close", -48, true)
CloseBtn.MouseButton1Click:Connect(function()
    SetWindow(false)
end)

do
    local pill = New("Frame", {
        Size = UDim2.fromOffset(112, 26),
        Position = UDim2.new(1, -208, 0.5, -13),
        BorderSizePixel = 0,
    }, Top)
    Bind(pill, "BackgroundColor3", "Surface2")
    Corner(pill, 13)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(11, 10),
        BorderSizePixel = 0,
    }, pill)
    Corner(dot, 3)
    Bind(dot, "BackgroundColor3", "Accent")
    TweenService:Create(
        dot,
        TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.8 }
    ):Play()
    local clk = Text(pill, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Left)
    clk.Position = UDim2.fromOffset(24, 0)
    clk.Size = UDim2.new(1, -28, 1, 0)
    local frames, fps = 0, 60
    Track(RunService.Heartbeat:Connect(function()
        frames = frames + 1
    end))
    task.spawn(function()
        while Screen.Parent do
            fps = frames * 2
            frames = 0
            clk.Text = os.date("%H:%M:%S") .. "  " .. tostring(fps)
            task.wait(0.5)
        end
    end)
end

MakeDraggable(Top, Main, "WindowX", "WindowY")

MaxBtn.MouseButton1Click:Connect(function()
    SetConfig("Maximized", not Config.Maximized)
    SetConfig("WindowX", 0.5)
    SetConfig("WindowY", 0.5)
    Tween(Main, 0.3, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
end)


local Rail = New("Frame", {
    Size = UDim2.new(0, 64, 1, -84),
    Position = UDim2.fromOffset(12, 72),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 10,
}, Main)
Bind(Rail, "BackgroundColor3", "Bg")
Rail.BackgroundTransparency = 0.03
do
    local tint = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, Rail)
    Corner(tint, 26)
    Bind(tint, "BackgroundColor3", "Accent")
    New("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.86),
            NumberSequenceKeypoint.new(1, 0.95),
        }),
    }, tint)
end
Corner(Rail, 26)
Bind(Stroke(Rail, Theme.Stroke, 1, 0.4), "Color", "Stroke")

local CatList = New("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -80),
    Position = UDim2.fromOffset(8, 10),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageTransparency = 0.3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Rail)
Bind(CatList, "ScrollBarImageColor3", "Accent")
List(CatList, 4)
Pad(CatList, 0, 4, 1, 1)

local UserBox = New("Frame", {
    Size = UDim2.new(1, -16, 0, 52),
    Position = UDim2.new(0, 8, 1, -60),
    BorderSizePixel = 0,
}, Rail)
Bind(UserBox, "BackgroundColor3", "Surface2")
Corner(UserBox, 12)

local Avatar = New("ImageLabel", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(0, 9, 0.5, -17),
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=60&h=60",
}, UserBox)
Corner(Avatar, 17)
Bind(Avatar, "BackgroundColor3", "Button")
Bind(Stroke(Avatar, Theme.Accent, 1.5, 0.2), "Color", "Accent")
Bind(Stroke(UserBox, Theme.Stroke, 1, 0.5), "Color", "Stroke")
local Online = New("Frame", {
    Size = UDim2.fromOffset(10, 10),
    Position = UDim2.new(0, 36, 0.5, 7),
    BorderSizePixel = 0,
    BackgroundColor3 = RGB(70, 200, 120),
    ZIndex = 3,
}, UserBox)
Corner(Online, 5)
Bind(Stroke(Online, Theme.Surface2, 2, 0), "Color", "Surface2")

local UName = Text(UserBox, LocalPlayer.DisplayName, 12, FNT.B, "Text")
UName.Position = UDim2.fromOffset(52, 9)
UName.Size = UDim2.new(1, -58, 0, 18)
local UTag = Text(UserBox, "@" .. LocalPlayer.Name, 10, FNT.R, "Muted")
UTag.Position = UDim2.fromOffset(52, 27)
UTag.Size = UDim2.new(1, -58, 0, 14)

local Pages = {}
local TabList = {}

local function CatGroup(name)
    local l = Text(CatList, name, 10, FNT.B, "Muted")
    l.Size = UDim2.new(1, 0, 0, 26)
    l.LayoutOrder = Next(CatList)
    Pad(l, 10, 0, 6, 0)
    return l
end

local CurrentTab = nil
local function SelectTab(id)
    if not Pages[id] then
        id = "Home"
    end
    SetConfig("LastTab", id)
    local changed = id ~= CurrentTab
    CurrentTab = id
    for pid, page in pairs(Pages) do
        page.Visible = (pid == id)
    end
    if changed then
        local p = Pages[id]
        p.Position = UDim2.fromOffset(0, 16)
        Tween(p, 0.32, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
        pcall(function()
            local n = 0
            for _, child in ipairs(p:GetChildren()) do
                local sh = child:FindFirstChild("Sheen")
                if sh then
                    n = n + 1
                    task.delay(n * 0.06, function()
                        sh.Position = UDim2.new(-0.3, 0, 0, 0)
                        Tween(sh, 0.7, { Position = UDim2.new(1.1, 0, 0, 0) }, Enum.EasingStyle.Quad)
                    end)
                end
            end
        end)
        pcall(function()
            local sw = New("Frame", {
                Size = UDim2.new(0, 0, 0, 2),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 20,
            }, p.Parent)
            Tween(sw, 0.5, { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
            task.delay(0.55, function()
                sw:Destroy()
            end)
        end)
    end
    for _, t in ipairs(TabList) do
        t.active = (t.id == id)
        t.paint()
    end
end

local function Category(name, id, iconKind)
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(CatList),
    }, CatList)
    Corner(b, 16)
    local bst = Stroke(b, Theme.Accent, 1, 1)

    local ind = New("Frame", {
        Size = UDim2.fromOffset(3, 8),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, b)
    Corner(ind, 2)

    local setIcon = Icon(b, iconKind, 16, 12)

    local lbl = Text(b, name, 13, FNT.M)
    lbl.Position = UDim2.fromOffset(44, 0)
    lbl.Size = UDim2.new(1, -48, 1, 0)
    lbl.TextColor3 = Theme.Sub

    local tab = { id = id, active = false, hover = false }
    function tab.paint()
        Tween(b, 0.15, {
            BackgroundColor3 = tab.active and Theme.Accent or Theme.Button,
            BackgroundTransparency = tab.active and 0 or (tab.hover and 0.5 or 1),
        })
        Tween(bst, 0.15, { Color = Theme.Accent, Transparency = tab.active and 0.55 or 1 })
        Tween(lbl, 0.15, { TextColor3 = tab.active and Theme.OnAccent or Theme.Sub })
        Tween(ind, 0.15, {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            Size = tab.active and UDim2.fromOffset(3, 22) or UDim2.fromOffset(3, 8),
        })
        setIcon(tab.active and Theme.OnAccent or Theme.Sub)
    end
    TabList[#TabList + 1] = tab
    OnTheme(tab.paint)

    b.MouseEnter:Connect(function()
        tab.hover = true
        tab.paint()
    end)
    b.MouseLeave:Connect(function()
        tab.hover = false
        tab.paint()
    end)
    b.MouseButton1Click:Connect(function()
        SelectTab(id)
    end)
    return b
end

--==================================================
-- PAGES
--==================================================

local Body = New("Frame", {
    Size = UDim2.new(1, -100, 1, -84),
    Position = UDim2.fromOffset(88, 72),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, Main)
Bind(Body, "BackgroundColor3", "Bg")
Corner(Body, 22)
do
    local d = Main:FindFirstChild("Deco")
    local ds = Stroke(d, Color3.new(1, 1, 1), 1.5, 0.1)
    local dg = New("UIGradient", { Rotation = 0 }, ds)
    OnTheme(function()
        local h, sat = Theme.Accent:ToHSV()
        sat = math.max(sat, 0.6)
        dg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(0.25, Color3.fromHSV((h + 0.1) % 1, sat, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.25) % 1, sat, 1)),
            ColorSequenceKeypoint.new(0.75, Color3.fromHSV((h + 0.1) % 1, sat, 1)),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        })
    end)
    TweenService:Create(
        dg,
        TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
        { Rotation = 360 }
    ):Play()
end
New("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 8),
}, Body)

do
    local expanded = false
    Track(RunService.RenderStepped:Connect(function()
        if not Main.Visible then
            return
        end
        local m = UIS:GetMouseLocation()
        local ap, asz = Rail.AbsolutePosition, Rail.AbsoluteSize
        local inside = m.X >= ap.X - 4 and m.X <= ap.X + asz.X + 4 and m.Y >= ap.Y and m.Y <= ap.Y + asz.Y
        if inside ~= expanded then
            expanded = inside
            local w = inside and SW or 64
            Tween(Rail, 0.3, { Size = UDim2.new(0, w, 1, -84) }, Enum.EasingStyle.Quint)
            Tween(Body, 0.3, {
                Position = UDim2.fromOffset(w + 24, 72),
                Size = UDim2.new(1, -(w + 36), 1, -84),
            }, Enum.EasingStyle.Quint)
            Tween(Main:FindFirstChild("Deco"), 0.3, {
                Position = UDim2.fromOffset(w + 24, 72),
                Size = UDim2.new(1, -(w + 36), 1, -84),
            }, Enum.EasingStyle.Quint)
        end
    end))
end

local function MakePage(id, title, subtitle)
    local page = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, Body)
    Bind(page, "ScrollBarImageColor3", "Stroke")
    List(page, 8)
    Pad(page, 0, 8, 0, 14)

    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    local t = Text(head, title, 22, FNT.B, "Text")
    t.Size = UDim2.new(1, 0, 0, 28)
    do
        local tgr = New("UIGradient", { Rotation = 0, Offset = Vector2.new(-1, 0) }, t)
        OnTheme(function()
            tgr.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.35, Theme.Accent),
                ColorSequenceKeypoint.new(0.65, Theme.Accent2),
                ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
            })
        end)
        TweenService:Create(
            tgr,
            TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Offset = Vector2.new(1, 0) }
        ):Play()
    end
    local s = Text(head, subtitle or "", 11, FNT.R, "Muted")
    s.Position = UDim2.fromOffset(0, 29)
    s.Size = UDim2.new(1, 0, 0, 18)
    local hb = New("Frame", {
        Size = UDim2.fromOffset(36, 3),
        Position = UDim2.fromOffset(0, 53),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, head)
    hb.Size = UDim2.new(1, 0, 0, 2)
    Corner(hb, 1)
    local hg = AccentGrad(hb, 0)
    hg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.35, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })

    Pages[id] = page
    return page
end

local Collapsed = {}
for id in string.gmatch(Config.CollapsedSections, "[^|]+") do
    Collapsed[id] = true
end
local function SaveCollapsed()
    local t = {}
    for id, v in pairs(Collapsed) do
        if v then
            t[#t + 1] = id
        end
    end
    table.sort(t)
    SetConfig("CollapsedSections", table.concat(t, "|"))
end

local SectionsByPage = {}
local CurrentSection = nil

local function Section(page, title)
    local hdr = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(page),
    }, page)

    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BorderSizePixel = 0,
    }, hdr)
    Corner(bar, 2)
    bar.BackgroundColor3 = Color3.new(1, 1, 1)
    AccentGrad(bar, 90)

    local hl = New("Frame", {
        Size = UDim2.new(1, -4, 0, 1),
        Position = UDim2.new(0, 2, 1, -1),
        BorderSizePixel = 0,
    }, hdr)
    Bind(hl, "BackgroundColor3", "Stroke")
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hl)

    local label = Text(hdr, title, 13, FNT.B, "Accent")
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -44, 1, 0)

    local chev = New("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        BackgroundTransparency = 1,
    }, hdr)
    local c1 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(1, 6), Rotation = 45, BorderSizePixel = 0,
    }, chev)
    local c2 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(6, 6), Rotation = -45, BorderSizePixel = 0,
    }, chev)
    Corner(c1, 1)
    Corner(c2, 1)
    OnTheme(function()
        c1.BackgroundColor3 = Theme.Muted
        c2.BackgroundColor3 = Theme.Muted
    end)

    local sec = { label = hdr, items = {}, collapsed = Collapsed[title] == true }
    function sec.refresh(animate)
        for _, it in ipairs(sec.items) do
            it.frame.Visible = it.matched and not sec.collapsed
        end
        local rot = sec.collapsed and -90 or 0
        if animate then
            Tween(chev, 0.18, { Rotation = rot })
        else
            chev.Rotation = rot
        end
    end
    sec.refresh(false)

    hdr.MouseButton1Click:Connect(function()
        sec.collapsed = not sec.collapsed
        Collapsed[title] = sec.collapsed
        SaveCollapsed()
        sec.refresh(true)
    end)

    CurrentSection = sec
    SectionsByPage[page] = SectionsByPage[page] or {}
    table.insert(SectionsByPage[page], sec)
    return sec
end

local function Register(row, search)
    local sec = CurrentSection
    if sec then
        table.insert(sec.items, { frame = row, search = string.lower(search or ""), matched = true })
        sec.refresh(false)
    end
end

local Refreshers = {}

--==================================================
-- COMPONENTS: Toggle / Slider / ColorRow
--==================================================

local FuncToggles = {}
local UpdateSummary = function() end

local function Toggle(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 64), "TextButton")
    HoverRow(row)
    Register(row, opts.title .. " " .. (opts.desc or ""))
    local rowStroke = row:FindFirstChildOfClass("UIStroke")

    local tint = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, row)
    Corner(tint, 16)
    local tg = AccentGrad(tint, 0)
    tg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.6, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })

    local title = Text(row, opts.title, 14, FNT.B, "Text")
    title.Position = UDim2.fromOffset(18, 11)
    title.Size = UDim2.new(1, -96, 0, 20)

    local desc = Text(row, opts.desc or "", 12, FNT.R, "Sub")
    desc.Position = UDim2.fromOffset(18, 33)
    desc.Size = UDim2.new(1, -96, 0, 18)

    local strip = New("Frame", {
        Size = UDim2.fromOffset(3, 26),
        Position = UDim2.new(0, 4, 0.5, -13),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(strip, 2)
    AccentGrad(strip, 90)

    local glow = New("Frame", {
        Size = UDim2.fromOffset(62, 40),
        Position = UDim2.new(1, -71, 0.5, -20),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(glow, 20)
    AccentGrad(glow, 0)

    local track = New("Frame", {
        Size = UDim2.fromOffset(48, 26),
        Position = UDim2.new(1, -64, 0.5, -13),
        BorderSizePixel = 0,
    }, row)
    Corner(track, 13)
    local tStroke = Stroke(track, Theme.Stroke, 1, 0.2)
    Bind(tStroke, "Color", "Stroke")

    local fill = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, track)
    Corner(fill, 13)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(3, 3),
        BorderSizePixel = 0,
    }, track)
    Corner(knob, 10)

    local state = Config[opts.key] == true

    if page == Pages["Functions"] then
        FuncToggles[#FuncToggles + 1] = function()
            return state
        end
    end

    local function render(animate)
        Apply(track, animate, { BackgroundColor3 = Theme.Button })
        Apply(fill, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(glow, animate, { BackgroundTransparency = state and 0.82 or 1 })
        Apply(tint, animate, { BackgroundTransparency = state and 0.86 or 1 })
        Apply(knob, animate, {
            Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Theme.OnAccent or Theme.Sub,
        })
        Apply(strip, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(tStroke, animate, { Color = state and Theme.Accent or Theme.Stroke })
        if rowStroke then
            Apply(rowStroke, animate, {
                Color = state and Theme.Accent or Theme.Stroke,
                Transparency = state and 0.55 or 0.4,
            })
        end
        UpdateSummary()
    end
    OnTheme(function()
        render(false)
    end)

    local function set(v, fire)
        state = v
        SetConfig(opts.key, v)
        render(true)
        if v and fire then
            pcall(function()
                local r = New("Frame", {
                    Size = UDim2.fromOffset(20, 20),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(1, -40, 0.5, 0),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                }, row)
                Corner(r, 100)
                local rs = Stroke(r, Theme.Accent, 2, 0.05)
                Tween(r, 0.6, { Size = UDim2.fromOffset(130, 130) }, Enum.EasingStyle.Quad)
                Tween(rs, 0.6, { Transparency = 1 }, Enum.EasingStyle.Quad)
                task.delay(0.65, function()
                    r:Destroy()
                end)
            end)
        end
        if fire then
            PlayToggleSound(v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    row.MouseButton1Click:Connect(function()
        set(not state, true)
    end)

    Refreshers[#Refreshers + 1] = function()
        state = Config[opts.key] == true
        render(false)
        if opts.callback then
            task.spawn(opts.callback, state)
        end
    end

    if opts.callback then
        task.defer(opts.callback, state)
    end

    return {
        Get = function()
            return state
        end,
        Set = function(v)
            set(v, true)
        end,
    }
end

local function Slider(page, opts)
    local min, max, step = opts.min, opts.max, opts.step or 1
    local row = Panel(page, UDim2.new(1, 0, 0, 78))
    Register(row, opts.title .. " " .. (opts.desc or ""))

    local title = Text(row, opts.title, 13, FNT.M, "Text")
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.new(1, -110, 0, 20)

    local desc = Text(row, opts.desc or "", 12, FNT.R, "Sub")
    desc.Position = UDim2.fromOffset(16, 31)
    desc.Size = UDim2.new(1, -110, 0, 16)

    local pill = New("Frame", {
        Size = UDim2.fromOffset(82, 22),
        Position = UDim2.new(1, -98, 0, 9),
        BorderSizePixel = 0,
    }, row)
    Corner(pill, 11)
    Bind(pill, "BackgroundColor3", "Surface2")
    Bind(Stroke(pill, Theme.Accent, 1, 0.6), "Color", "Accent")
    local val = Text(row, "", 12, FNT.B, "Accent", Enum.TextXAlignment.Center)
    val.Position = UDim2.new(1, -98, 0, 9)
    val.Size = UDim2.fromOffset(82, 22)

    local bar = New("Frame", {
        Size = UDim2.new(1, -32, 0, 6),
        Position = UDim2.fromOffset(16, 60),
        BorderSizePixel = 0,
    }, row)
    Corner(bar, 3)
    Bind(bar, "BackgroundColor3", "Button")

    local fill = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, bar)
    Corner(fill, 3)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BorderSizePixel = 0,
    }, bar)
    Corner(knob, 8)
    Bind(knob, "BackgroundColor3", "Text")
    Bind(Stroke(knob, Theme.Accent, 3, 0), "Color", "Accent")

    local hit = New("TextButton", {
        Size = UDim2.new(1, -32, 0, 30),
        Position = UDim2.fromOffset(16, 48),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local value = Config[opts.key]

    local function show()
        local a = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        val.Text = string.format("%g", value) .. (opts.suffix or "")
    end

    local function setValue(v, fire)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v == value and fire then
            return
        end
        value = v
        show()
        if fire then
            SetConfig(opts.key, v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end

    hit.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            page.ScrollingEnabled = false
            Tween(knob, 0.12, { Size = UDim2.fromOffset(21, 21) })
            fromX(input.Position.X)
        end
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if dragging and IsMove(input) then
            fromX(input.Position.X)
        end
    end))
    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            dragging = false
            page.ScrollingEnabled = true
            Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) })
        end
    end))

    value = math.clamp(value, min, max)
    show()

    Refreshers[#Refreshers + 1] = function()
        value = math.clamp(Config[opts.key], min, max)
        show()
        if opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    if opts.callback then
        task.defer(opts.callback, value)
    end
end

-- ============================================================
-- ============================================================
local PaletteColors = {
    "FFFFFF", "BEBEBE", "6B6B76", "2A2A33", "0E0E14", "000000", "8B5CF6", "6366F1",
    "3B82F6", "22D3EE", "10B981", "84CC16", "FACC15", "FB923C", "EF4444", "EC4899",
}

local ActiveOverlay, ActivePopup
local PaletteConns = {}

local function ClosePalette()
    for _, c in ipairs(PaletteConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    PaletteConns = {}
    if ActiveOverlay then
        ActiveOverlay:Destroy()
        ActiveOverlay = nil
    end
    if ActivePopup then
        ActivePopup:Destroy()
        ActivePopup = nil
    end
end

local themePending = false
local function QueueTheme()
    if themePending then
        return
    end
    themePending = true
    task.defer(function()
        themePending = false
        ApplyTheme()
    end)
end

local function OpenPalette(title, key, onPick)
    ClosePalette()

    ActiveOverlay = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 150,
    }, Screen)
    Tween(ActiveOverlay, 0.2, { BackgroundTransparency = 0.45 })
    ActiveOverlay.MouseButton1Click:Connect(ClosePalette)

    local PW, PH = 240, 304
    local pop = New("CanvasGroup", {
        Size = UDim2.fromOffset(PW, PH),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 160,
        Active = true,
    }, Screen)
    Corner(pop, 16)
    Stroke(pop, Theme.Accent, 1.5, 0.35)
    local vs = ViewSize()
    New("UIScale", { Scale = math.clamp((vs.Y - 24) / PH, 0.5, 1) }, pop)
    ActivePopup = pop
    Tween(pop, 0.2, { GroupTransparency = 0 })

    local okc, c0 = pcall(Color3.fromHex, Config[key])
    if not okc then
        c0 = Color3.new(1, 1, 1)
    end
    local H, S, V = c0:ToHSV()

    local ttl = Text(pop, title or "เลือกสี", 13, FNT.B, Theme.Text)
    ttl.Position = UDim2.fromOffset(14, 10)
    ttl.Size = UDim2.new(1, -130, 0, 20)

    local prev = New("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(PW - 82, 11),
        BorderSizePixel = 0,
    }, pop)
    Corner(prev, 6)
    Stroke(prev, Color3.new(1, 1, 1), 1, 0.75)

    local closeB = New("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(PW - 38, 8),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "×",
        TextSize = 18,
        Font = FNT.B,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
    }, pop)
    Corner(closeB, 8)
    closeB.MouseButton1Click:Connect(ClosePalette)

    local sv = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 124),
        Position = UDim2.fromOffset(14, 40),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromHSV(H, 1, 1),
    }, pop)
    Corner(sv, 10)
    local wf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, sv)
    Corner(wf, 10)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wf)
    local bf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, sv)
    Corner(bf, 10)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bf)
    local svCur = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, sv)
    Corner(svCur, 8)
    Stroke(svCur, Color3.new(1, 1, 1), 2.5, 0)
    local svHit = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, sv)

    local hue = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 14),
        Position = UDim2.fromOffset(14, 176),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, pop)
    Corner(hue, 7)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hue)
    local hueCur = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
    }, hue)
    Corner(hueCur, 9)
    Stroke(hueCur, Color3.new(1, 1, 1), 2.5, 0)
    local hueHit = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 12),
        Position = UDim2.fromOffset(0, -6),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, hue)

    local box = New("TextBox", {
        Size = UDim2.fromOffset(PW - 28, 30),
        Position = UDim2.fromOffset(14, 202),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "#RRGGBB",
        ClearTextOnFocus = false,
        TextSize = 12,
        Font = FNT.M,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
    }, pop)
    Corner(box, 9)
    Stroke(box, Theme.Stroke, 1, 0.3)

    local function render(fromBox)
        local c = Color3.fromHSV(H, S, V)
        sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        svCur.Position = UDim2.fromScale(S, 1 - V)
        hueCur.Position = UDim2.fromScale(H, 0.5)
        hueCur.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        prev.BackgroundColor3 = c
        if not fromBox then
            box.Text = "#" .. string.upper(c:ToHex())
        end
        return c
    end
    local function commit(fromBox)
        onPick(render(fromBox))
    end
    render(false)

    local function bindDrag(hit, onMove)
        local dragging, dInput = false, nil
        local off = Vector2.zero
        hit.InputBegan:Connect(function(input)
            if not IsPointer(input) then
                return
            end
            local p = Vector2.new(input.Position.X, input.Position.Y)
            local a, sz = hit.AbsolutePosition, hit.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local q = p + inset
            local inside = q.X >= a.X and q.X <= a.X + sz.X and q.Y >= a.Y and q.Y <= a.Y + sz.Y
            off = inside and inset or Vector2.zero
            dragging = true
            dInput = input
            onMove(p + off)
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputChanged:Connect(function(input)
            if dragging and IsMove(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                onMove(Vector2.new(input.Position.X, input.Position.Y) + off)
            end
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputEnded:Connect(function(input)
            if dragging and IsPointer(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                dragging = false
            end
        end)
    end

    bindDrag(svHit, function(pos)
        S = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        V = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        commit(false)
    end)
    bindDrag(hueHit, function(pos)
        H = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        commit(false)
    end)

    box.FocusLost:Connect(function()
        local h = string.match(box.Text, "^%s*#?(%x%x%x%x%x%x)%s*$")
        if h then
            H, S, V = Color3.fromHex(h):ToHSV()
            commit(false)
        else
            box.TextColor3 = RGB(235, 75, 90)
            task.delay(0.8, function()
                if box.Parent then
                    box.TextColor3 = Theme.Text
                    render(false)
                end
            end)
        end
    end)

    for i, hexv in ipairs(PaletteColors) do
        local c = Color3.fromHex(hexv)
        local sw = New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(14 + ((i - 1) % 8) * 27, 244 + math.floor((i - 1) / 8) * 28),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, pop)
        Corner(sw, 11)
        Stroke(sw, Color3.new(1, 1, 1), 1, 0.8)
        sw.MouseButton1Click:Connect(function()
            H, S, V = c:ToHSV()
            commit(false)
        end)
    end
end

local ColorRefreshers = {}

local function ColorRow(page, title, key)
    local row = Panel(page, UDim2.new(1, 0, 0, 50), "TextButton")
    HoverRow(row)
    Register(row, title)

    local t = Text(row, title, 12, FNT.M, "Text")
    t.Position = UDim2.fromOffset(18, 0)
    t.Size = UDim2.new(1, -176, 1, 0)

    local hexLabel = Text(row, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
    hexLabel.Position = UDim2.new(1, -152, 0, 0)
    hexLabel.Size = UDim2.fromOffset(84, 50)

    local swatch = New("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -60, 0.5, -12),
        BorderSizePixel = 0,
    }, row)
    Corner(swatch, 8)
    Stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)

    local function refresh()
        swatch.BackgroundColor3 = Hex(key, RGB(100, 100, 100))
        hexLabel.Text = string.upper(tostring(Config[key]))
    end
    refresh()
    Refreshers[#Refreshers + 1] = refresh
    ColorRefreshers[#ColorRefreshers + 1] = refresh

    row.MouseButton1Click:Connect(function()
        OpenPalette(title, key, function(c)
            SetConfig(key, "#" .. string.upper(c:ToHex()))
            refresh()
            QueueTheme()
        end)
    end)
end

local ThemePresets = {
    { "Graphite", "#C9CBD3", "#0A0A0C", "#232328" },
    { "Violet", "#8B5CF6", "#09090D", "#1C1C26" },
    { "Crimson", "#F43F5E", "#0B0708", "#26151A" },
    { "Cyber", "#22D3EE", "#06090C", "#122029" },
    { "Toxic", "#4ADE80", "#060A07", "#13211A" },
    { "Sunset", "#FB923C", "#0C0805", "#271A10" },
    { "Neon Violet", "#A78BFA", "#08080F", "#1E1B33" },
    { "Sakura", "#F9A8D4", "#0D0709", "#2A1620" },
    { "Ocean", "#38BDF8", "#050A10", "#102235" },
    { "Gold", "#FACC15", "#0B0A05", "#2A2410" },
    { "Aurora", "#2DD4BF", "#050B0B", "#102A2A" },
    { "Royal", "#6366F1", "#07071A", "#1A1C3D" },
    { "Matrix", "#00FF88", "#030A06", "#0C2418" },
    { "Blood Moon", "#EF4444", "#0A0404", "#2A1010" },
    { "Ice", "#BAE6FD", "#070B10", "#14202C" },
    { "Lavender", "#C4B5FD", "#0A0910", "#221E36" },
    { "Mint", "#6EE7B7", "#050B09", "#12281F" },
    { "Rose Gold", "#FDA4AF", "#0C0809", "#2C1A1D" },
}

local function ThemeGrid(page)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -7, 0, 56),
        CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    Register(holder, "ธีม theme preset สำเร็จรูป")

    for _, p in ipairs(ThemePresets) do
        local card = Panel(holder, nil, "TextButton")
        HoverRow(card)

        local function dot(hex, x)
            local d = New("Frame", {
                Size = UDim2.fromOffset(22, 22),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, x, 0.5, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHex(hex),
            }, card)
            Corner(d, 11)
            Stroke(d, Color3.new(1, 1, 1), 1, 0.8)
        end
        dot(p[3], 12)
        dot(p[4], 24)
        dot(p[2], 36)

        local n = Text(card, p[1], 12, FNT.M, "Text")
        n.Position = UDim2.fromOffset(68, 0)
        n.Size = UDim2.new(1, -74, 1, 0)

        card.MouseButton1Click:Connect(function()
            SetConfig("UIAccentColor", p[2])
            SetConfig("UIBackgroundColor", p[3])
            SetConfig("UIButtonColor", p[4])
            SetConfig("FloatingButtonColor", p[3])
            SetConfig("FloatingBorderColor", p[2])
            SetConfig("FloatingGlowColor", p[2])
            for _, fn in ipairs(ColorRefreshers) do
                pcall(fn)
            end
            QueueTheme()
            Toast("ใช้ธีม " .. p[1])
        end)
    end
end

local RefreshHome
do
--==================================================
-- HOME
--==================================================

local Home = MakePage("Home", "หน้าหลัก", "ภาพรวมและข้อมูลเซิร์ฟเวอร์")

local Hero = Panel(Home, UDim2.new(1, 0, 0, 84))
Tint(Hero)
local HeroSub = Text(Hero, "", 11, FNT.M, "Muted")
HeroSub.Position = UDim2.fromOffset(20, 14)
HeroSub.Size = UDim2.new(0.6, 0, 0, 16)
local HeroName = Text(Hero, LocalPlayer.DisplayName, 24, FNT.B, Color3.new(1, 1, 1))
HeroName.Position = UDim2.fromOffset(20, 32)
HeroName.Size = UDim2.new(0.6, 0, 0, 38)
AccentGrad(HeroName, 0)
local HeroClock = Text(Hero, "", 26, FNT.B, "Text", Enum.TextXAlignment.Right)
HeroClock.Position = UDim2.new(0.5, 0, 0, 16)
HeroClock.Size = UDim2.new(0.5, -20, 0, 34)
local HeroDate = Text(Hero, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
HeroDate.Position = UDim2.new(0.5, 0, 0, 52)
HeroDate.Size = UDim2.new(0.5, -20, 0, 16)

local MapImage = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"

local MapCard = Panel(Home, UDim2.new(1, 0, 0, 116))
MapCard.ClipsDescendants = true

local MapBG = New("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.86,
}, MapCard)
Corner(MapBG, 12)

local MapFade = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, MapCard)
Bind(MapFade, "BackgroundColor3", "Surface")
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.7),
    }),
}, MapFade)
Corner(MapFade, 12)
Tint(MapCard)

local MapIcon = New("ImageLabel", {
    Size = UDim2.fromOffset(84, 84),
    Position = UDim2.fromOffset(16, 16),
    BorderSizePixel = 0,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
}, MapCard)
Corner(MapIcon, 16)
Bind(MapIcon, "BackgroundColor3", "Button")
Bind(Stroke(MapIcon, Theme.Stroke, 1.5, 0.1), "Color", "Stroke")

local MapName = Text(MapCard, tostring(game.Name or "Unknown"), 17, FNT.B, "Text")
MapName.Position = UDim2.fromOffset(112, 16)
MapName.Size = UDim2.new(1, -128, 0, 26)

local MapBy = Text(MapCard, "กำลังโหลดข้อมูลแมพ...", 11, FNT.R, "Muted")
MapBy.Position = UDim2.fromOffset(112, 43)
MapBy.Size = UDim2.new(1, -128, 0, 16)

local Chips = New("Frame", {
    Size = UDim2.new(1, -128, 0, 24),
    Position = UDim2.fromOffset(112, 72),
    BackgroundTransparency = 1,
}, MapCard)
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Chips)

local function Chip(text)
    local c = New("TextLabel", {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 10,
        Font = FNT.M,
        LayoutOrder = Next(Chips),
    }, Chips)
    Bind(c, "BackgroundColor3", "Surface2")
    Bind(c, "TextColor3", "Sub")
    Corner(c, 12)
    Pad(c, 10, 10, 0, 0)
    return c
end

local ChipPlace = Chip("ID " .. tostring(game.PlaceId))
local ChipPlayers = Chip("ผู้เล่น -/-")

task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then
            if info.Name and info.Name ~= "" then
                MapName.Text = tostring(info.Name)
                BrandSub.Text = tostring(info.Name)
            end
            if info.Creator and info.Creator.Name then
                MapBy.Text = "โดย " .. tostring(info.Creator.Name)
            else
                MapBy.Text = ""
            end
        end
    end)
end)

local function Stat(parent, label, size)
    local c = Panel(parent, size)
    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 18),
        Position = UDim2.fromOffset(0, 12),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, c)
    Corner(bar, 2)
    AccentGrad(bar, 90)
    local l = Text(c, label, 10, FNT.M, "Muted")
    l.Position = UDim2.fromOffset(16, 11)
    l.Size = UDim2.new(1, -30, 0, 14)
    local v = Text(c, "-", 14, FNT.B, "Text")
    v.Position = UDim2.fromOffset(16, 30)
    v.Size = UDim2.new(1, -30, 0, 22)
    return v
end

local Grid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = Next(Home),
}, Home)
New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 64),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Grid)

local StatPlayer = Stat(Grid, "ผู้เล่น")
local StatTime = Stat(Grid, "เวลาในเซิร์ฟ")
local StatFps = Stat(Grid, "FPS")
local StatPing = Stat(Grid, "Ping")

local PerfCard = Panel(Home, UDim2.new(1, 0, 0, 120))
Tint(PerfCard)
local PerfTitle = Text(PerfCard, "ประสิทธิภาพ (FPS)", 12, FNT.B, "Text")
PerfTitle.Position = UDim2.fromOffset(18, 12)
PerfTitle.Size = UDim2.new(0.5, 0, 0, 18)
local PerfAvg = Text(PerfCard, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Right)
PerfAvg.Position = UDim2.new(0.5, 0, 0, 12)
PerfAvg.Size = UDim2.new(0.5, -18, 0, 18)
local PerfBars = New("Frame", {
    Size = UDim2.new(1, -36, 0, 68),
    Position = UDim2.fromOffset(18, 40),
    BackgroundTransparency = 1,
}, PerfCard)

local PERF_N = 36
local PerfBar, PerfHist = {}, {}
for i = 1, PERF_N do
    local b = New("Frame", {
        Size = UDim2.new(1 / PERF_N, -2, 0, 2),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new((i - 1) / PERF_N, 1, 1, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, PerfBars)
    Corner(b, 2)
    PerfBar[i] = b
    PerfHist[i] = 0
end

local function PerfUpdate()
    table.remove(PerfHist, 1)
    PerfHist[#PerfHist + 1] = Metrics.fps
    local peak, sum, cnt = 60, 0, 0
    for _, v in ipairs(PerfHist) do
        if v > peak then
            peak = v
        end
        if v > 0 then
            sum = sum + v
            cnt = cnt + 1
        end
    end
    for i, v in ipairs(PerfHist) do
        local b = PerfBar[i]
        b.Size = UDim2.new(1 / PERF_N, -2, math.clamp(v / peak, 0.04, 1), 0)
        b.BackgroundColor3 = Level(v, 50, 30, true)
        b.BackgroundTransparency = v == 0 and 1 or 0.08
    end
    PerfAvg.Text = "เฉลี่ย " .. tostring(cnt > 0 and math.floor(sum / cnt + 0.5) or 0) .. " FPS"
end

local sessionStart = os.time()

function RefreshHome()
    local hr = tonumber(os.date("%H")) or 12
    HeroSub.Text = (hr >= 5 and hr < 12 and "อรุณสวัสดิ์")
        or (hr >= 12 and hr < 17 and "สวัสดีตอนบ่าย")
        or (hr >= 17 and hr < 21 and "สวัสดีตอนเย็น")
        or "ราตรีสวัสดิ์"
    HeroClock.Text = os.date("%H:%M")
    HeroDate.Text = os.date("%d / %m / %Y")
    local sec = math.max(0, os.time() - sessionStart)
    StatPlayer.Text = LocalPlayer.DisplayName
    StatTime.Text = string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
    StatFps.Text = tostring(Metrics.fps)
    StatFps.TextColor3 = Level(Metrics.fps, 50, 30, true)
    StatPing.Text = tostring(Metrics.ping) .. " ms"
    StatPing.TextColor3 = Level(Metrics.ping, 80, 160, false)
    ChipPlayers.Text = string.format("ผู้เล่น %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
    PerfUpdate()
end

task.spawn(function()
    while Screen.Parent do
        RefreshStats()
        RefreshHome()
        task.wait(0.5)
    end
end)

end -- /Home scope
--==================================================
-- FUNCTIONS
--==================================================

local Functions = MakePage("Functions", "ฟังก์ชัน", "เปิด / ปิดการใช้งานได้ทันที  •  เซฟอัตโนมัติ")

--==================================================
-- >>> ADD YOUR FUNCTIONS <<<
--   2) Toggle(Functions, { key="AutoFarm", title="...", desc="...", callback=function(v) ... end })
--   3) Slider(Functions, { key="Speed", title="...", desc="...", min=0, max=100, step=1, callback=function(v) end })
--==================================================

--==================================================
-- RELWX x AUTO FARM  (เควสตามเลเวล / เลือกมอนตามเลเวล / Gear / Card / Revive)
-- เวอร์ชันลดแลค: แคชค่าที่ใช้บ่อย, สแกน GUI แบบจำกัดความถี่, ไม่สแกน workspace ถ้าไม่ได้เปิดหลบวง
-- ห่อด้วย pcall + ฟังก์ชันแยก เพื่อไม่ให้ชนลิมิต local 200 ตัวของไฟล์หลัก
--==================================================
do
    local okFarm, errFarm = pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local Remotes = RS:FindFirstChild("Remotes")
        local Shared = RS:FindFirstChild("Shared")
        local LP = Players.LocalPlayer
        local clock = os.clock

        local function R(name)
            return Remotes and Remotes:FindFirstChild(name)
        end
        local function send(name, ...)
            local r = R(name)
            if not r then
                return false
            end
            local args = table.pack(...)
            return (pcall(function()
                r:FireServer(table.unpack(args, 1, args.n))
            end))
        end
        local function log(...)
            print("[RELWX]", ...)
        end

        ------------------------------------------------------------
        -- Remote spy: จำ args ที่เกมส่งจริงตอนเรากดเอง (ใช้เป็นแม่แบบ)
        -- ไม่จับของที่สคริปต์เราเองยิง (checkcaller) และเช็คเงื่อนไขถูกๆ ก่อนเสมอ
        ------------------------------------------------------------
        local Learned = {}
        local LearnedQuest = {} -- action(ตัวพิมพ์เล็ก) -> args  เช่น accept / claim
        if hookmetamethod and getnamecallmethod and Remotes then
            pcall(function()
                local old
                local function hook(self, ...)
                    if getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and self.Parent == Remotes
                        and not (checkcaller and checkcaller()) then
                        local n = self.Name
                        if n == "QuestAction" or n == "SetBotSettings" or n == "RespawnChoice" or n == "BotState" then
                            local a = table.pack(...)
                            if n == "QuestAction" then
                                if type(a[1]) == "string" then
                                    LearnedQuest[string.lower(a[1])] = a
                                end
                            elseif not (n == "BotState" and a[1] == false) then
                                Learned[n] = a
                            end
                        end
                    end
                    return old(self, ...)
                end
                old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(hook) or hook)
            end)
        end

        ------------------------------------------------------------
        -- Helpers
        ------------------------------------------------------------
        local function pick(t, keys)
            if type(t) ~= "table" then
                return nil
            end
            for _, k in ipairs(keys) do
                if t[k] ~= nil then
                    return t[k]
                end
            end
        end

        local function press(btn)
            if not btn then
                return false
            end
            local done = false
            if getconnections then
                for _, sig in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }) do
                    pcall(function()
                        for _, c in ipairs(getconnections(btn[sig])) do
                            c:Fire()
                            done = true
                        end
                    end)
                end
            end
            if not done and firesignal then
                pcall(function()
                    firesignal(btn.Activated)
                    done = true
                end)
            end
            return done
        end

        -- อ่านข้อความทั้งก้อน (ลึก) ใช้เฉพาะงานที่ทำไม่บ่อย
        local function textOf(obj)
            local s = ""
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                s = obj.Text
            end
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    s = s .. " " .. d.Text
                end
            end
            return string.lower(s)
        end

        -- อ่านข้อความแบบตื้น (ตัวปุ่ม + ลูก 2 ชั้น) ใช้ตอนสแกนหาปุ่ม จะได้ไม่หนัก
        local function btnText(obj)
            local s = ""
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                s = obj.Text
            end
            for _, c in ipairs(obj:GetChildren()) do
                if c:IsA("TextLabel") or c:IsA("TextButton") then
                    s = s .. " " .. c.Text
                elseif c:IsA("Frame") then
                    for _, g in ipairs(c:GetChildren()) do
                        if g:IsA("TextLabel") or g:IsA("TextButton") then
                            s = s .. " " .. g.Text
                        end
                    end
                end
            end
            return string.lower(s)
        end

        local function gui(name)
            local pg = LP:FindFirstChild("PlayerGui")
            return pg and pg:FindFirstChild(name)
        end

        local function loadModule(name)
            local m = Shared and Shared:FindFirstChild(name)
            if not m then
                return nil
            end
            local ok, v = pcall(require, m)
            return ok and v or nil
        end

        local function isBossName(s)
            s = string.lower(s or "")
            return s:find("boss", 1, true) ~= nil or s:find("บอส", 1, true) ~= nil
        end

        ------------------------------------------------------------
        -- อ่านเลเวลตัวเรา (แคชแหล่งที่เจอ ไม่สแกนซ้ำทุกรอบ)
        ------------------------------------------------------------
        local LEVEL_KEYS = { "Level", "BaseLevel", "Lv", "level", "lv" }
        local levelSrc = nil
        local lastSlowScan, lastDeepScan = -100, -100

        local function readSrc()
            local s = levelSrc
            if not s then
                return nil
            end
            local o = s.obj
            if not (o and o.Parent) then
                levelSrc = nil
                return nil
            end
            if s.kind == "value" then
                return tonumber(o.Value)
            end
            local n = o.Text:match("[Ll][Vv]%.?%s*(%d+)") or o.Text:match("[Ll]evel%s*(%d+)")
            return n and tonumber(n) or nil
        end

        local function getLevel()
            for _, k in ipairs(LEVEL_KEYS) do
                local a = LP:GetAttribute(k)
                if type(a) == "number" then
                    return a
                end
            end
            local ch = LP.Character
            if ch then
                local a = ch:GetAttribute("Level")
                if type(a) == "number" then
                    return a
                end
            end
            local v = readSrc()
            if v then
                return v
            end
            if clock() - lastSlowScan < 15 then
                return nil
            end
            lastSlowScan = clock()

            local ls = LP:FindFirstChild("leaderstats")
            if ls then
                for _, c in ipairs(ls:GetChildren()) do
                    local ln = string.lower(c.Name)
                    if c:IsA("ValueBase") and (ln:find("lv", 1, true) or ln:find("level", 1, true)) and tonumber(c.Value) then
                        levelSrc = { kind = "value", obj = c }
                        return tonumber(c.Value)
                    end
                end
            end
            for _, top in ipairs(LP:GetChildren()) do
                if top.Name ~= "PlayerGui" then
                    for _, d in ipairs(top:GetDescendants()) do
                        if (d.Name == "Level" or d.Name == "Lv") and (d:IsA("IntValue") or d:IsA("NumberValue")) then
                            levelSrc = { kind = "value", obj = d }
                            return d.Value
                        end
                    end
                end
            end
            local hud = gui("LumiHud")
            if hud then
                for _, d in ipairs(hud:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        local n = d.Text:match("[Ll][Vv]%.?%s*(%d+)")
                        if n then
                            levelSrc = { kind = "label", obj = d }
                            return tonumber(n)
                        end
                    end
                end
            end
            -- สแกนทั้ง PlayerGui = หนัก ทำไม่เกินนาทีละครั้ง
            if clock() - lastDeepScan >= 60 then
                lastDeepScan = clock()
                local pg = LP:FindFirstChild("PlayerGui")
                if pg then
                    local cnt = 0
                    for _, d in ipairs(pg:GetDescendants()) do
                        cnt = cnt + 1
                        if cnt % 500 == 0 then
                            task.wait()
                        end
                        if d:IsA("TextLabel") and d.Visible then
                            local n = d.Text:match("^%s*[Ll][Vv]%.?%s*(%d+)%s*$") or d.Text:match("^%s*[Ll]evel%s*(%d+)%s*$")
                            if n then
                                levelSrc = { kind = "label", obj = d }
                                return tonumber(n)
                            end
                        end
                    end
                end
            end
            return nil
        end

        ------------------------------------------------------------
        -- Monster list (จาก MonsterData)
        ------------------------------------------------------------
        local MonsterOptions, MonsterById, MonsterByKey, MobList = {}, {}, {}, {}
        local function buildMonsters()
            local md = loadModule("MonsterData")
            if type(md) ~= "table" then
                return
            end
            local src = md
            if type(md.Monsters) == "table" then
                src = md.Monsters
            elseif type(md.List) == "table" then
                src = md.List
            end
            local list = {}
            for key, e in pairs(src) do
                if type(e) == "table" then
                    local name = pick(e, { "Name", "name", "DisplayName", "displayName" })
                    local lv = pick(e, { "Level", "level", "Lv", "lv", "MinLevel" })
                    if type(lv) == "table" then
                        lv = lv[1] or lv.Min
                    end
                    if type(name) ~= "string" then
                        name = type(key) == "string" and key or nil
                    end
                    if name and tonumber(lv) then
                        local id = type(key) == "string" and key or (pick(e, { "Id", "id", "Key" }) or name)
                        id = tostring(id)
                        local boss = pick(e, { "IsBoss", "isBoss", "Boss" }) == true or isBossName(id) or isBossName(name)
                        list[#list + 1] = { id = id, name = name, lv = tonumber(lv), boss = boss }
                    end
                end
            end
            table.sort(list, function(a, b)
                if a.lv == b.lv then
                    return a.name < b.name
                end
                return a.lv < b.lv
            end)
            for _, m in ipairs(list) do
                local label = string.format("Lv.%d  %s", m.lv, m.name)
                m.label = label
                MonsterOptions[#MonsterOptions + 1] = label
                MonsterById[label] = m
                MonsterByKey[string.lower(m.id)] = m
                MonsterByKey[string.lower(m.name)] = m
                if not m.boss then
                    MobList[#MobList + 1] = m -- เรียงเลเวลน้อย -> มาก, ไม่รวมบอส
                end
            end
        end
        buildMonsters()
        if #MonsterOptions == 0 then
            MonsterOptions = { "(อ่านรายชื่อมอนไม่ได้)" }
            log("อ่าน MonsterData ไม่ได้ — โครงสร้างต่างจากที่คาด")
        end

        local NONE_LABEL = "None (ไม่เลือก)"

        -- แก้แม่แบบ SetBotSettings ที่เรียนรู้จากเกม: เปลี่ยนรายการมอนที่เลือกเป็น id ที่ต้องการ (nil = ไม่เลือกเลย)
        local function patchBotSettings(chosenId)
            local tpl = Learned.SetBotSettings
            if not tpl then
                return false
            end
            local ids = {}
            for _, m in pairs(MonsterById) do
                ids[m.id] = true
            end
            local changed = false
            local function walk(t)
                local isArr, allIds, n = true, true, 0
                for k, v in pairs(t) do
                    n = n + 1
                    if type(k) ~= "number" then
                        isArr = false
                    end
                    if not (type(v) == "string" and ids[v]) then
                        allIds = false
                    end
                end
                if n > 0 and isArr and allIds then
                    for k in pairs(t) do
                        t[k] = nil
                    end
                    if chosenId then
                        t[1] = chosenId
                    end
                    changed = true
                    return
                end
                local keyed = false
                for k, v in pairs(t) do
                    if type(k) == "string" and ids[k] and type(v) ~= "table" then
                        keyed = true
                    end
                end
                if keyed then
                    for k, v in pairs(t) do
                        if type(k) == "string" and ids[k] and type(v) ~= "table" then
                            if type(v) == "boolean" then
                                t[k] = (k == chosenId)
                            elseif type(v) == "number" then
                                t[k] = (k == chosenId) and 1 or 0
                            end
                        end
                    end
                    changed = true
                    return
                end
                for _, v in pairs(t) do
                    if type(v) == "table" then
                        walk(v)
                    end
                end
            end
            local function copy(v)
                if type(v) ~= "table" then
                    return v
                end
                local r = {}
                for k, x in pairs(v) do
                    r[k] = copy(x)
                end
                return r
            end
            local args = table.pack(table.unpack(tpl, 1, tpl.n))
            for i = 1, args.n do
                if type(args[i]) == "table" then
                    args[i] = copy(args[i])
                    walk(args[i])
                end
            end
            if not changed then
                return false
            end
            return send("SetBotSettings", table.unpack(args, 1, args.n))
        end

        local function findIn(root, name)
            for _, d in ipairs(root:GetDescendants()) do
                if d.Name == name then
                    return d
                end
            end
        end

        local function applyMonster(label)
            local none = (label == nil or label == "" or label == NONE_LABEL)
            local m = (not none) and MonsterById[label] or nil
            if not none and not m then
                return false
            end

            local bot = gui("LumiBot")
            if bot then
                local clear = findIn(bot, "TickNone")
                local grid = findIn(bot, "MonsterGrid")
                if clear then
                    press(clear)
                    if none then
                        log("ไม่เลือกมอน (ล้างรายการ)")
                        return true
                    end
                end
                if grid and m then
                    task.wait(0.15)
                    local needle = string.lower(m.name)
                    local idl = string.lower(m.id)
                    for _, c in ipairs(grid:GetDescendants()) do
                        if c:IsA("GuiButton") then
                            if string.lower(c.Name):find(idl, 1, true) or textOf(c):find(needle, 1, true) then
                                if press(c) then
                                    log("เลือกมอน:", label)
                                    return true
                                end
                            end
                        end
                    end
                end
            end

            -- ทางสำรอง: ยิง SetBotSettings จากแม่แบบที่เกมส่งเอง
            if patchBotSettings(m and m.id or nil) then
                log(none and "ไม่เลือกมอน (remote)" or ("เลือกมอน (remote): " .. label))
                return true
            end

            log("เลือกมอนไม่สำเร็จ — เปิดเมนูบอทของเกมค้างไว้ 1 ครั้ง (หรือกดเลือกมอนเองสัก 1 ครั้ง) แล้วลองใหม่")
            return false
        end

        ------------------------------------------------------------
        -- Auto Farm: กดปุ่มออโต้ของเกมเอง (ไม่บิน/ไม่วาปไปตี)
        ------------------------------------------------------------
        local autoCache = {}
        local function farmIcons()
            local a = gui("LumiAuto")
            if not a then
                autoCache = {}
                return nil
            end
            local c = autoCache
            if not (c.root == a and c.icon and c.icon.Parent) then
                c.root = a
                c.icon = a:FindFirstChild("PixelSwordsOff", true) or a:FindFirstChild("PixelSwordsOn", true)
                c.off = a:FindFirstChild("PixelSwordsOff", true)
                c.btn = nil
            end
            return a, c
        end

        local function farmLooksOff()
            local a, c = farmIcons()
            local off = c and c.off
            if off and off:IsA("GuiObject") then
                local ok, r = pcall(function()
                    return off.Visible and off.ImageTransparency < 1
                end)
                if ok then
                    return r
                end
            end
            return nil
        end

        local function farmButton()
            local a, c = farmIcons()
            if not a then
                return nil
            end
            if c.btn and c.btn.Parent then
                return c.btn
            end
            local p = c.icon
            while p and p ~= a do
                if p:IsA("GuiButton") then
                    c.btn = p
                    return p
                end
                p = p.Parent
            end
            for _, d in ipairs(a:GetDescendants()) do
                if d:IsA("GuiButton") then
                    c.btn = d
                    return d
                end
            end
            return nil
        end

        local lastFarmFire = 0
        local function ensureFarm()
            local state = farmLooksOff()
            if state == false then
                return
            end
            if clock() - lastFarmFire < (state and 3 or 10) then
                return
            end
            lastFarmFire = clock()
            -- 1) กดปุ่มของเกมจริงก่อน (เซิร์ฟเวอร์รับค่าแบบที่เกมส่งเอง)
            if press(farmButton()) then
                log("กดปุ่มออโต้ของเกม")
                return
            end
            -- 2) ไม่เจอปุ่ม -> ยิง remote ด้วย args ที่เรียนรู้จากเกม (ถ้ามี)
            local tpl = Learned.BotState
            if tpl then
                send("BotState", table.unpack(tpl, 1, tpl.n))
            else
                send("BotState", true)
            end
            log("ยิง BotState", tpl and "(args จากเกม)" or "(true)")
        end

        ------------------------------------------------------------
        -- ระบบเควส (อ่าน QuestData ครั้งเดียวแล้วแคช)
        ------------------------------------------------------------
        local QuestList = nil
        local lastQBuild = -100

        local function levelOf(q)
            local direct = pick(q, { "MinLevel", "minLevel", "ReqLevel", "reqLevel", "RequiredLevel", "Level", "level", "Lv", "lv" })
            if type(direct) == "table" then
                direct = direct[1] or direct.Min
            end
            if tonumber(direct) then
                return tonumber(direct)
            end
            for k, v in pairs(q) do
                if type(k) == "string" then
                    local lk = string.lower(k)
                    if (lk:find("lv", 1, true) or lk:find("level", 1, true)) and tonumber(v) then
                        return tonumber(v)
                    end
                end
            end
            return nil
        end

        -- แปลงค่าใดๆ ในเควสให้เป็นมอน (ถ้ามอนนั้นอยู่ใน MonsterData)
        local function resolveMob(v, depth)
            if depth > 3 or v == nil then
                return nil
            end
            if type(v) == "string" then
                return MonsterByKey[string.lower(v)]
            end
            if type(v) == "table" then
                local direct = pick(v, { "Id", "id", "Monster", "Mob", "Name", "Target", "MonsterId", "MobId" })
                if direct ~= nil then
                    local m = resolveMob(direct, depth + 1)
                    if m then
                        return m
                    end
                end
                for _, x in ipairs(v) do
                    local m = resolveMob(x, depth + 1)
                    if m then
                        return m
                    end
                end
            end
            return nil
        end

        local MOB_KEYS = {
            "Monster", "MonsterId", "Mob", "MobId", "Target", "TargetId", "TargetMonster",
            "Enemy", "EnemyId", "Npc", "NpcId", "Kill", "KillTarget",
            "Objectives", "Objective", "Goals", "Goal", "Tasks", "Requirements",
        }
        local function questMob(q)
            for _, k in ipairs(MOB_KEYS) do
                if q[k] ~= nil then
                    local m = resolveMob(q[k], 0)
                    if m then
                        return m
                    end
                end
            end
            return nil
        end

        local function buildQuests()
            local qd = loadModule("QuestData")
            if type(qd) ~= "table" then
                return nil
            end
            local src = type(qd.Quests) == "table" and qd.Quests or qd
            local list, seen = {}, {}
            local function walk(t, depth)
                for key, q in pairs(t) do
                    if type(q) == "table" then
                        local need = levelOf(q)
                        if need then
                            local id = pick(q, { "Id", "id", "QuestId", "questId" })
                            if id == nil then
                                id = key
                            end
                            id = tostring(id)
                            if not seen[id] then
                                seen[id] = true
                                list[#list + 1] = { id = id, need = need, mob = questMob(q) }
                            end
                        elseif depth < 2 then
                            walk(q, depth + 1)
                        end
                    end
                end
            end
            walk(src, 1)
            table.sort(list, function(a, b)
                if a.need == b.need then
                    return a.id < b.id
                end
                return a.need < b.need
            end)
            return list
        end

        -- เควสที่เหมาะกับเลเวลมากที่สุด (need สูงสุดที่ไม่เกินเลเวลเรา)
        local function bestQuest(lv)
            if not QuestList then
                if clock() - lastQBuild < 30 then
                    return nil
                end
                lastQBuild = clock()
                local built = buildQuests()
                if not built or #built == 0 then
                    return nil
                end
                QuestList = built
                local withMob = 0
                for _, q in ipairs(built) do
                    if q.mob then
                        withMob = withMob + 1
                    end
                end
                log(string.format("QuestData: พบเควส %d รายการ (ระบุมอนได้ %d)", #built, withMob))
            end
            for i = #QuestList, 1, -1 do
                if QuestList[i].need <= lv then
                    local j = i
                    while j > 1 and QuestList[j - 1].need == QuestList[i].need do
                        j = j - 1
                    end
                    return QuestList[j]
                end
            end
            return nil
        end

        ------------------------------------------------------------
        -- หาปุ่มใน GUI (จำกัดความถี่ + ข้าม GUI ที่ไม่เกี่ยว + พักเฟรมระหว่างสแกน)
        ------------------------------------------------------------
        local function isShown(obj)
            local p = obj
            local pg = LP:FindFirstChild("PlayerGui")
            while p and p ~= pg do
                if p:IsA("GuiObject") and not p.Visible then
                    return false
                end
                if p:IsA("ScreenGui") and not p.Enabled then
                    return false
                end
                p = p.Parent
            end
            return p == pg and pg ~= nil
        end

        local SKIP_WORDS = { "trade", "party", "friend", "invite", "chat", "shop", "relwx" }
        local function skipGui(name)
            local ln = string.lower(name)
            for _, w in ipairs(SKIP_WORDS) do
                if ln:find(w, 1, true) then
                    return true
                end
            end
            return false
        end

        local function scanGui(g, patterns)
            local n = 0
            for _, d in ipairs(g:GetDescendants()) do
                n = n + 1
                if n % 600 == 0 then
                    task.wait()
                end
                if d:IsA("GuiButton") then
                    local t = btnText(d)
                    if t ~= "" then
                        for _, pat in ipairs(patterns) do
                            if t:find(pat, 1, true) and isShown(d) then
                                return d
                            end
                        end
                    end
                end
            end
            return nil
        end

        local function findButton(patterns)
            local pg = LP:FindFirstChild("PlayerGui")
            if not pg then
                return nil
            end
            local others = {}
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Enabled and not skipGui(g.Name) then
                    if string.lower(g.Name):find("quest", 1, true) then
                        local b = scanGui(g, patterns)
                        if b then
                            return b
                        end
                    else
                        others[#others + 1] = g
                    end
                end
            end
            for _, g in ipairs(others) do
                local b = scanGui(g, patterns)
                if b then
                    return b
                end
            end
            return nil
        end

        local ACCEPT_PATTERNS = { "accept", "รับเควส", "รับภารกิจ" }
        local CLAIM_PATTERNS = { "claim", "turn in", "รับรางวัล", "ส่งเควส", "ส่งภารกิจ" }
        local GUIDE_PATTERNS = { "guide me", "guideme", "guild me", "guide", "นำทาง", "พาไป", "ไปเควส" }

        local function pressAccept()
            local b = findButton(ACCEPT_PATTERNS)
            if b and press(b) then
                log("กดปุ่มรับเควส")
                return true
            end
            return false
        end

        -- Guide Me = BindableEvent "HuntQuest" ใต้ LocalPlayer, ยิง "toggle" (สลับเปิด/ปิด)
        -- จึงยิงแค่ครั้งเดียวหลังเปลี่ยนเควสใหม่ ไม่ยิงซ้ำ (ไม่งั้นจะสลับปิด)
        local function guideQuest()
            local ev = LP:FindFirstChild("HuntQuest")
            if ev and ev:IsA("BindableEvent") then
                local ok = pcall(function()
                    ev:Fire("toggle")
                end)
                if ok then
                    log("Guide Me: HuntQuest toggle")
                    return
                end
            end
            local b = findButton(GUIDE_PATTERNS)
            if b and press(b) then
                log("กด Guide Me (ปุ่ม)")
            end
        end

        ------------------------------------------------------------
        -- Auto Quest: เปลี่ยนเควสตามเลเวล + ส่ง/รับเควสต่อเนื่อง
        ------------------------------------------------------------
        local QS = { id = nil, mob = nil, claimT = 0, busy = false, noLvLog = 0, noQLog = 0 }

        local function claimQuest()
            -- 1) ปุ่มส่ง/รับรางวัลที่มองเห็นอยู่ในเกม
            local b = findButton(CLAIM_PATTERNS)
            if b and press(b) then
                log("กดปุ่มส่ง/รับรางวัลเควส")
                return true
            end
            -- 2) ยิง remote: ใช้คำสั่งที่เกมเคยส่งจริง (ถ้ากดส่งเควสเองมาก่อน) ไม่งั้นลองรูปแบบทั่วไป
            local id = QS.id
            if not id then
                return false
            end
            local action = "claim"
            for _, k in ipairs({ "claim", "turnin", "complete", "submit", "finish" }) do
                local tpl = LearnedQuest[k]
                if tpl and type(tpl[1]) == "string" then
                    action = tpl[1]
                    break
                end
            end
            send("QuestAction", action, id)
            return true
        end

        local function doQuest(force)
            if QS.busy then
                return
            end
            QS.busy = true
            local ok, err = pcall(function()
                local lv = getLevel()
                if not lv then
                    if clock() - QS.noLvLog > 10 then
                        QS.noLvLog = clock()
                        log("อ่านเลเวลตัวละครไม่ได้ — ยังไม่รับเควส")
                    end
                    return
                end
                local q = bestQuest(lv)
                if not q then
                    if clock() - QS.noQLog > 20 then
                        QS.noQLog = clock()
                        log("หาเควสที่ตรงกับเลเวล", lv, "ไม่เจอใน QuestData")
                    end
                    return
                end
                QS.mob = q.mob
                local changed = (q.id ~= QS.id) or force == true
                local now = clock()
                local cycle = false

                if Config.AutoClaimQuest then
                    if changed and QS.id then
                        -- เปลี่ยนเควสใหม่: ส่งของเก่าก่อน
                        claimQuest()
                        QS.claimT = clock()
                        task.wait(0.8)
                    elseif not changed and now - QS.claimT >= (Config.QuestCycleSec or 30) then
                        QS.claimT = now
                        if claimQuest() then
                            task.wait(1)
                            cycle = true
                        end
                    end
                end

                if changed or cycle then
                    -- รูปแบบจริงของเกม: QuestAction:FireServer("accept", "r05")
                    send("QuestAction", "accept", q.id)
                    QS.id = q.id
                    log(string.format("รับเควสตามเลเวล %d -> %s (ต้องการ Lv.%s)%s", lv, q.id, tostring(q.need),
                        q.mob and (" มอน: " .. q.mob.name) or ""))
                    pressAccept()
                    if changed then
                        task.delay(1.2, guideQuest)
                    end
                end
            end)
            QS.busy = false
            if not ok then
                log("doQuest error:", tostring(err))
            end
        end

        ------------------------------------------------------------
        -- เลือกมอนตามเลเวลอัตโนมัติ (ใช้มอนของเควสก่อน ถ้าไม่มีใช้ตามเลเวล)
        ------------------------------------------------------------
        local RefreshTarget = nil
        local lastMobLabel, lastMobTry = nil, -100

        local function pickMobAuto(lv)
            local qm = Config.AutoQuestEnabled and QS.mob or nil
            if qm and not qm.boss then
                return qm
            end
            local over = tonumber(Config.MobOver) or 0
            for i = #MobList, 1, -1 do
                if MobList[i].lv <= lv + over then
                    return MobList[i]
                end
            end
            return MobList[1]
        end

        local function autoMob(force)
            if not Config.AutoMobByLevel or #MobList == 0 then
                return
            end
            local lv = getLevel()
            if not lv then
                return
            end
            local m = pickMobAuto(lv)
            if not m then
                return
            end
            if m.label == lastMobLabel and force ~= true then
                return
            end
            if force ~= true and clock() - lastMobTry < 20 then
                return
            end
            lastMobTry = clock()
            SetConfig("TargetMonster", m.label)
            if RefreshTarget then
                RefreshTarget()
            end
            log(string.format("เลือกมอนตามเลเวล %d -> %s", lv, m.label))
            if applyMonster(m.label) then
                lastMobLabel = m.label
            end
        end

        ------------------------------------------------------------
        -- Auto Revive (เกิดฟรี)
        ------------------------------------------------------------
        local function tryRevive()
            local g = gui("LumiRespawn")
            local visible = false
            if g then
                local f = g:FindFirstChild("Frame")
                visible = g.Enabled and f and f.Visible
            end
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            local dead = hum and hum.Health <= 0
            if not (visible or dead) then
                return
            end
            if visible then
                for _, b in ipairs(g:GetDescendants()) do
                    if b:IsA("TextButton") then
                        local t = textOf(b)
                        if t:find("ฟรี") or t:find("free") then
                            if press(b) then
                                return
                            end
                        end
                    end
                end
            end
            if Learned.RespawnChoice then
                send("RespawnChoice", table.unpack(Learned.RespawnChoice, 1, Learned.RespawnChoice.n))
            else
                send("RespawnChoice", "free")
            end
        end

        ------------------------------------------------------------
        -- Dropdown component
        ------------------------------------------------------------
        local function Dropdown(page, opts)
            local row = Panel(page, UDim2.new(1, 0, 0, 64), "TextButton")
            HoverRow(row)
            Register(row, opts.title .. " " .. (opts.desc or ""))

            local title = Text(row, opts.title, 14, FNT.B, "Text")
            title.Position = UDim2.fromOffset(18, 11)
            title.Size = UDim2.new(1, -190, 0, 20)
            local desc = Text(row, opts.desc or "", 12, FNT.R, "Sub")
            desc.Position = UDim2.fromOffset(18, 33)
            desc.Size = UDim2.new(1, -190, 0, 18)

            local pill = New("Frame", {
                Size = UDim2.fromOffset(160, 32),
                Position = UDim2.new(1, -174, 0.5, -16),
                BorderSizePixel = 0,
            }, row)
            Corner(pill, 10)
            Bind(pill, "BackgroundColor3", "Surface2")
            Bind(Stroke(pill, Theme.Accent, 1, 0.6), "Color", "Accent")
            local val = Text(pill, "", 12, FNT.B, "Accent", Enum.TextXAlignment.Center)
            val.Size = UDim2.new(1, -24, 1, 0)
            val.Position = UDim2.fromOffset(6, 0)
            local arrow = Text(pill, "v", 11, FNT.B, "Muted", Enum.TextXAlignment.Center)
            arrow.Size = UDim2.fromOffset(18, 32)
            arrow.Position = UDim2.new(1, -20, 0, 0)

            local listPanel = Panel(page, UDim2.new(1, 0, 0, 190))
            listPanel.Visible = false
            local sf = New("ScrollingFrame", {
                Size = UDim2.new(1, -16, 1, -16),
                Position = UDim2.fromOffset(8, 8),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
            }, listPanel)
            Bind(sf, "ScrollBarImageColor3", "Stroke")
            List(sf, 4)

            local current = Config[opts.key]
            local function show()
                val.Text = (current ~= "" and current) or opts.placeholder or "เลือก..."
            end

            for i, label in ipairs(opts.options) do
                local it = New("TextButton", {
                    Size = UDim2.new(1, -6, 0, 30),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "  " .. label,
                    TextSize = 12,
                    Font = FNT.M,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = i,
                }, sf)
                Corner(it, 8)
                OnTheme(function()
                    it.BackgroundColor3 = Theme.Surface2
                    it.TextColor3 = Theme.Text
                end)
                it.MouseButton1Click:Connect(function()
                    current = label
                    SetConfig(opts.key, label)
                    show()
                    listPanel.Visible = false
                    PlayToggleSound(true)
                    if opts.callback then
                        task.spawn(opts.callback, label)
                    end
                end)
            end

            row.MouseButton1Click:Connect(function()
                listPanel.Visible = not listPanel.Visible
            end)
            row:GetPropertyChangedSignal("Visible"):Connect(function()
                if not row.Visible then
                    listPanel.Visible = false
                end
            end)

            show()
            local function refresh()
                current = Config[opts.key]
                show()
            end
            Refreshers[#Refreshers + 1] = refresh
            return refresh
        end

        ------------------------------------------------------------
        -- Auto Dodge: เดินเข้าวงเขียว (safe zone) ตอนบอสตี — วงแดงไม่สน
        -- ติดตาม workspace เฉพาะตอนเปิดสวิตช์นี้เท่านั้น (เดิมสแกนทั้งแมพตลอดเวลา = แลคหลัก)
        ------------------------------------------------------------
        local Candidates, Bosses, candN = {}, {}, 0
        local dodgeConns, dodgeScanId = nil, 0
        local CAND_MAX = 400

        local function nameHint(s)
            s = string.lower(s or "")
            for _, w in ipairs({ "safe", "zone", "circle", "ring", "telegraph", "indicator", "aoe", "warning", "danger" }) do
                if s:find(w, 1, true) then
                    return true
                end
            end
            return false
        end

        local function trackInstance(d)
            if d:IsA("BasePart") then
                if candN >= CAND_MAX or Candidates[d] then
                    return
                end
                if LP.Character and d:IsDescendantOf(LP.Character) then
                    return
                end
                local s = d.Size
                local hint = nameHint(d.Name) or nameHint(d.Parent and d.Parent.Name)
                local flat = (not d.CanCollide) and math.min(s.X, s.Y, s.Z) <= 2.5
                local cyl = (not d.CanCollide) and d:IsA("Part") and d.Shape == Enum.PartType.Cylinder
                if (hint or flat or cyl) and math.max(s.X, s.Y, s.Z) < 150 then
                    Candidates[d] = true
                    candN = candN + 1
                end
            elseif d:IsA("Humanoid") then
                local m = d.Parent
                if m and m ~= LP.Character and (isBossName(m.Name) or isBossName(d.Name)
                    or m:GetAttribute("IsBoss") == true or m:GetAttribute("Boss") == true) then
                    Bosses[d] = true
                end
            end
        end

        local function startDodge()
            if dodgeConns then
                return
            end
            dodgeConns = {
                workspace.DescendantAdded:Connect(function(d)
                    pcall(trackInstance, d)
                end),
                workspace.DescendantRemoving:Connect(function(d)
                    if Candidates[d] then
                        Candidates[d] = nil
                        candN = candN - 1
                    end
                    Bosses[d] = nil
                end),
            }
            dodgeScanId = dodgeScanId + 1
            local myId = dodgeScanId
            task.spawn(function()
                local n = 0
                for _, d in ipairs(workspace:GetDescendants()) do
                    if dodgeScanId ~= myId then
                        return
                    end
                    pcall(trackInstance, d)
                    n = n + 1
                    if n % 300 == 0 then
                        task.wait()
                    end
                end
            end)
        end

        local function stopDodge()
            if not dodgeConns then
                return
            end
            for _, c in ipairs(dodgeConns) do
                pcall(function()
                    c:Disconnect()
                end)
            end
            dodgeConns = nil
            dodgeScanId = dodgeScanId + 1
            Candidates, Bosses, candN = {}, {}, 0
        end

        local function isGreen(c)
            return c.G > 0.45 and c.G > c.R * 1.35 and c.G > c.B * 1.25
        end

        local function partIsGreen(p)
            if isGreen(p.Color) then
                return true
            end
            for _, ch in ipairs(p:GetChildren()) do
                if (ch:IsA("Decal") or ch:IsA("Texture")) and ch.Transparency < 0.95 and isGreen(ch.Color3) then
                    return true
                end
            end
            return false
        end

        local function bossNear(pos)
            for h in pairs(Bosses) do
                local m = h.Parent
                local root = m and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                if root and h.Health > 0 and (root.Position - pos).Magnitude < 250 then
                    return true
                end
            end
            return false
        end

        local function nearestGreenZone(pos)
            local best, bestD
            local boss = bossNear(pos)
            for p in pairs(Candidates) do
                if p.Parent and p.Transparency < 0.98 then
                    local d = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
                    if d < 120 and (boss or nameHint(p.Name)) and (not bestD or d < bestD) and partIsGreen(p) then
                        best, bestD = p, d
                    end
                end
            end
            return best
        end

        local dodgeLogged = false
        local function dodgeStep()
            if candN == 0 then
                return
            end
            local ch = LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum) or hum.Health <= 0 then
                return
            end
            local z = nearestGreenZone(hrp.Position)
            if not z then
                return
            end
            local s = z.Size
            local radius = math.max(s.X, s.Y, s.Z) / 2
            local c = z.Position
            local dx, dz = c.X - hrp.Position.X, c.Z - hrp.Position.Z
            local dist = math.sqrt(dx * dx + dz * dz)
            if not dodgeLogged then
                dodgeLogged = true
                log(string.format("เจอวงเขียว: %s (รัศมี ~%.0f) ระยะ %.0f", z:GetFullName(), radius, dist))
            end
            if dist > radius * 0.55 then
                hum:MoveTo(Vector3.new(c.X, hrp.Position.Y, c.Z))
            end
        end

        task.spawn(function()
            while Screen.Parent do
                task.wait(0.25)
                if Config.AutoDodgeEnabled then
                    startDodge()
                    pcall(dodgeStep)
                else
                    stopDodge()
                    dodgeLogged = false
                end
            end
            stopDodge()
        end)

        ------------------------------------------------------------
        -- UI
        ------------------------------------------------------------
        Section(Functions, "ออโต้ฟาม")

        Toggle(Functions, {
            key = "AutoFarmEnabled",
            title = "ออโต้ฟาม (ระบบของเกม)",
            desc = "กดปุ่มออโต้ของเกมให้เอง • ไม่บินไม่วาป • ถ้าปิดอยู่จะเปิดให้",
            callback = function(v)
                if v then
                    lastFarmFire = 0
                    ensureFarm()
                    if Config.AutoMobByLevel then
                        task.delay(1, function()
                            autoMob(true)
                        end)
                    else
                        local tm = Config.TargetMonster
                        if tm ~= "" and MonsterById[tm] then
                            task.delay(1, function()
                                applyMonster(tm)
                            end)
                        end
                    end
                else
                    send("BotState", false)
                end
            end,
        })

        Section(Functions, "เควส / ฟามตามเลเวล")

        Toggle(Functions, {
            key = "AutoQuestEnabled",
            title = "เปลี่ยนเควสตามเลเวล",
            desc = "เลเวลขึ้นแล้วรับเควสที่เหมาะสมให้เอง + กด Guide Me",
            callback = function(v)
                if v then
                    task.defer(doQuest, true)
                end
            end,
        })

        Toggle(Functions, {
            key = "AutoClaimQuest",
            title = "ส่ง/รับเควสต่อเนื่อง",
            desc = "ส่งเควสเมื่อเสร็จ แล้วรับเควสถัดไปให้เอง (กดส่งเควสเองสัก 1 ครั้งเพื่อให้จำรูปแบบ)",
        })

        Toggle(Functions, {
            key = "AutoMobByLevel",
            title = "เลือกมอนตามเลเวลอัตโนมัติ",
            desc = "ใช้มอนของเควสก่อน ถ้าไม่มีใช้มอนเลเวลสูงสุดที่ตีไหว",
            callback = function(v)
                if v then
                    task.defer(autoMob, true)
                end
            end,
        })

        Slider(Functions, {
            key = "MobOver",
            title = "ยอมตีมอนสูงกว่าเลเวลเรา",
            desc = "มอนเลเวลเกินเราได้กี่เลเวล (ใช้กับเลือกมอนตามเลเวล)",
            min = 0,
            max = 30,
            step = 1,
            suffix = "",
            callback = function()
                lastMobLabel = nil
            end,
        })

        Slider(Functions, {
            key = "QuestCycleSec",
            title = "ส่ง/รับเควสซ้ำทุกกี่วินาที",
            desc = "ยิ่งน้อยยิ่งถี่ (ค่ามากช่วยลดแลค)",
            min = 10,
            max = 120,
            step = 5,
            suffix = "s",
        })

        RefreshTarget = Dropdown(Functions, {
            key = "TargetMonster",
            title = "เลือกมอนที่จะตี (เอง)",
            desc = "ถ้าเปิดเลือกมอนตามเลเวล ระบบจะเปลี่ยนให้เอง",
            placeholder = "เลือกมอน...",
            options = (function()
                local o = { NONE_LABEL }
                for _, l in ipairs(MonsterOptions) do
                    o[#o + 1] = l
                end
                return o
            end)(),
            callback = function(label)
                lastMobLabel = label
                applyMonster(label)
            end,
        })

        Section(Functions, "ออโต้ช่วยเหลือ")

        Toggle(Functions, {
            key = "AutoGearEnabled",
            title = "ใส่เกียร์ดีที่สุด",
            desc = "กดใส่ @best ให้เป็นระยะ",
        })
        Toggle(Functions, {
            key = "AutoCardEnabled",
            title = "ใส่การ์ดดีที่สุด",
            desc = "กดใส่การ์ดออโต้ให้เป็นระยะ",
        })
        Toggle(Functions, {
            key = "AutoRunEnabled",
            title = "ออโต้วิ่ง",
            desc = "ถ้าตัวละครหยุดนิ่งตอนฟามอยู่ จะสั่งวิ่ง/เปิดบอทใหม่",
        })
        Toggle(Functions, {
            key = "AutoDodgeEnabled",
            title = "หลบเข้าวงเขียวตอนตีบอส",
            desc = "เดินเข้าวงเขียวอัตโนมัติ • วงแดงไม่ต้องหลบ • (เปิดแล้วจะมีสแกนแมพเล็กน้อย)",
        })
        Toggle(Functions, {
            key = "AutoReviveEnabled",
            title = "เกิดใหม่ฟรีอัตโนมัติ",
            desc = "ตายแล้วกดเกิดฟรี และเปิดฟามต่อให้",
        })

        ------------------------------------------------------------
        -- Main loop (รอบเดียว แยกความถี่ของแต่ละงาน)
        ------------------------------------------------------------
        local lastGear, lastCard, lastPos, idleSince = 0, 0, nil, nil
        local tFarm, tQuest, tMob = 0, 0, 0
        task.spawn(function()
            while Screen.Parent do
                task.wait(1)
                local now = clock()
                pcall(function()
                    if Config.AutoReviveEnabled then
                        tryRevive()
                    end
                    if Config.AutoFarmEnabled and now - tFarm >= 2 then
                        tFarm = now
                        ensureFarm()
                    end
                    if Config.AutoQuestEnabled and now - tQuest >= 4 then
                        tQuest = now
                        task.spawn(doQuest, false)
                    end
                    if Config.AutoFarmEnabled and Config.AutoMobByLevel and now - tMob >= 5 then
                        tMob = now
                        task.spawn(autoMob, false)
                    end
                    if Config.AutoGearEnabled and now - lastGear > 30 then
                        lastGear = now
                        send("EquipItem", "@best")
                    end
                    if Config.AutoCardEnabled and now - lastCard > 30 then
                        lastCard = now
                        send("CardAction", "auto")
                    end
                    if Config.AutoRunEnabled then
                        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            if lastPos and (hrp.Position - lastPos).Magnitude < 0.5 then
                                idleSince = idleSince or now
                                if now - idleSince > 6 then
                                    idleSince = now
                                    send("Dash")
                                    send("BotState", true)
                                end
                            else
                                idleSince = nil
                            end
                            lastPos = hrp.Position
                        end
                    end
                end)
            end
        end)
    end)
    if not okFarm then
        warn("[RELWX] AutoFarm module error: " .. tostring(errFarm))
    end
end

--==================================================
-- SETTINGS
--==================================================

local Settings = MakePage("Settings", "ตั้งค่า", "ปรับแต่งหน้าตา RELWX  •  เปลี่ยนแล้วเซฟทันที")

Section(Settings, "ระบบ")

Toggle(Settings, {
    key = "LiteMode",
    title = "โหมดลดแลค",
    desc = "ปิดแอนิเมชัน/เอฟเฟกต์ตกแต่งของ UI (ดาวตก, ละอองเมาส์, วงโคจร ฯลฯ)",
    callback = function(v)
        TweenService.SetLite(v)
    end,
})

Toggle(Settings, {
    key = "SoundEnabled",
    title = "เสียงตอนเปิด/ปิดฟังก์ชัน",
    desc = "เล่นเสียงสั้นๆ เมื่อกดสวิตช์",
})

Toggle(Settings, {
    key = "StatsVisible",
    title = "แสดง FPS / MS",
    desc = "กล่องเล็กลากย้ายตำแหน่งได้",
    callback = function(v)
        StatsGui.Enabled = v
    end,
})

Slider(Settings, {
    key = "UIScalePercent",
    title = "ขนาดหน้าต่าง",
    desc = "ปรับเพิ่มจากขนาดอัตโนมัติตามหน้าจอ",
    min = 60,
    max = 120,
    step = 5,
    suffix = "%",
    callback = function()
        ApplyScale(true)
    end,
})

Section(Settings, "ธีมสำเร็จรูป")
ThemeGrid(Settings)

Section(Settings, "ธีม UI")
ColorRow(Settings, "สีหลัก UI", "UIAccentColor")
ColorRow(Settings, "สีพื้นหลัง UI", "UIBackgroundColor")
ColorRow(Settings, "สีปุ่ม UI", "UIButtonColor")

Section(Settings, "ปุ่มลอย RX")
ColorRow(Settings, "สีปุ่ม RX", "FloatingButtonColor")
ColorRow(Settings, "สีขอบ RX", "FloatingBorderColor")
ColorRow(Settings, "สี Glow RX", "FloatingGlowColor")

Section(Settings, "Config")

local CfgCard = Panel(Settings, UDim2.new(1, 0, 0, 64))
local CfgTitle = Text(CfgCard, "บันทึกอัตโนมัติ", 13, FNT.M, "Text")
CfgTitle.Position = UDim2.fromOffset(16, 11)
CfgTitle.Size = UDim2.new(1, -140, 0, 20)
local CfgDesc = Text(
    CfgCard,
    writefile and CONFIG_FILE or "executor นี้ไม่รองรับการเขียนไฟล์",
    10,
    FNT.R,
    "Muted"
)
CfgDesc.Position = UDim2.fromOffset(16, 33)
CfgDesc.Size = UDim2.new(1, -140, 0, 18)
local CfgPill = StatusPill(CfgCard, 108)
CfgPill.AnchorPoint = Vector2.new(1, 0.5)
CfgPill.Position = UDim2.new(1, -14, 0.5, 0)

local ResetRow = Panel(Settings, UDim2.new(1, 0, 0, 50), "TextButton")
HoverRow(ResetRow)
local ResetLabel = Text(ResetRow, "รีเซ็ตการตั้งค่าทั้งหมด", 12, FNT.M, RGB(235, 90, 100))
ResetLabel.Position = UDim2.fromOffset(16, 0)
ResetLabel.Size = UDim2.new(1, -32, 1, 0)

local FloatApplyPosition

local resetArmed = false
ResetRow.MouseButton1Click:Connect(function()
    if not resetArmed then
        resetArmed = true
        ResetLabel.Text = "กดอีกครั้งเพื่อยืนยันการรีเซ็ต"
        task.delay(3, function()
            resetArmed = false
            ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"
        end)
        return
    end
    resetArmed = false
    ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"

    for k, v in pairs(Defaults) do
        Config[k] = v
    end
    Collapsed = {}
    for _, secs in pairs(SectionsByPage) do
        for _, sec in ipairs(secs) do
            sec.collapsed = false
            sec.refresh(true)
        end
    end
    ApplyTheme()
    for _, fn in ipairs(Refreshers) do
        pcall(fn)
    end
    Tween(Main, 0.3, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
    if FloatApplyPosition then
        FloatApplyPosition()
    end
    StatsBox.Position = UDim2.fromScale(Config.StatsX, Config.StatsY)
    StatsGui.Enabled = Config.StatsVisible
    SelectTab(Config.LastTab)
    SaveConfig(true)
    Toast("รีเซ็ตการตั้งค่าแล้ว")
end)

--==================================================
-- SIDEBAR CATEGORIES
--==================================================

CatGroup("เมนูหลัก")
Category("หน้าหลัก", "Home", "grid")
Category("ฟังก์ชัน", "Functions", "sliders")
CatGroup("ระบบ")
Category("ตั้งค่า", "Settings", "ring")

--==================================================
-- FLOATING RX BUTTON
--==================================================

local ToggleGui = New("ScreenGui", {
    Name = "RELWX_Floating",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
}, PlayerGui)

local Float = New("Frame", {
    Size = UDim2.fromOffset(48, 48),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.FloatX, Config.FloatY),
    BackgroundTransparency = 1,
    Active = true,
}, ToggleGui)

local Glow = New("Frame", {
    Size = UDim2.new(1, 8, 1, 8),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
}, Float)
Corner(Glow, 15)
local GlowStroke = Stroke(Glow, RGB(145, 145, 145), 3, 0.2)

local RX = New("TextButton", {
    Size = UDim2.fromScale(1, 1),
    Text = "RX",
    TextSize = 15,
    Font = FNT.B,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
}, Float)
Corner(RX, 13)
local RXStroke = Stroke(RX, RGB(255, 255, 255), 2, 0.05)
local RXGrad = New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0),
    }),
}, RXStroke)
TweenService:Create(
    RXGrad,
    TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()

OnTheme(function()
    local bg = Hex("FloatingButtonColor", RGB(18, 18, 18))
    RX.BackgroundColor3 = bg
    RX.TextColor3 = Lum(bg) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    RXStroke.Color = Hex("FloatingBorderColor", RGB(255, 255, 255))
    GlowStroke.Color = Hex("FloatingGlowColor", RGB(145, 145, 145))
end)

TweenService:Create(
    GlowStroke,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.65 }
):Play()

do
    local orbit = New("Frame", {
        Size = UDim2.fromOffset(64, 64),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1,
    }, Float)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, orbit)
    Corner(dot, 3)
    TweenService:Create(
        orbit,
        TweenInfo.new(2.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
        { Rotation = 360 }
    ):Play()
    task.spawn(function()
        while Float.Parent do
            task.wait(2.4)
            if Config.LiteMode then
                continue
            end
            pcall(function()
                local pr = New("Frame", {
                    Size = UDim2.fromOffset(48, 48),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    BackgroundTransparency = 1,
                }, Float)
                Corner(pr, 14)
                local ps = Stroke(pr, Theme.Accent, 2, 0.2)
                Tween(pr, 1.1, { Size = UDim2.fromOffset(120, 120) }, Enum.EasingStyle.Quad)
                Tween(ps, 1.1, { Transparency = 1 }, Enum.EasingStyle.Quad)
                task.delay(1.2, function()
                    pr:Destroy()
                end)
            end)
        end
    end)
    local fs = New("UIScale", { Scale = 1 }, Float)
    TweenService:Create(
        fs,
        TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Scale = 1.07 }
    ):Play()
end

FloatApplyPosition = function()
    Float.Position = UDim2.fromScale(Config.FloatX, Config.FloatY)
end

MakeDraggable(RX, Float, "FloatX", "FloatY", function()
    SetWindow(not Config.WindowVisible)
end)

--==================================================
-- START
--==================================================

SelectTab(Config.LastTab)
RefreshStats()
RefreshHome()

if Config.WindowVisible then
    PlayOpen()
end

if not LoadedFromFile then
    SaveConfig(true)
end

print("[RELWX] UI Loaded" .. (LoadedFromFile and " (Config loaded)" or " (new Config)"))
