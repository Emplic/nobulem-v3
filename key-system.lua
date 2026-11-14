repeat task.wait() until game:IsLoaded()

local PassedLoaderConfig = ...
local LoaderConfig =
    (type(PassedLoaderConfig) == "table" and PassedLoaderConfig)
    or (getgenv and getgenv().NobulemLoaderConfig)
    or (_G and _G.NobulemLoaderConfig)
    or (type(shared) == "table" and shared.NobulemLoaderConfig)
    or {}

local cloneref = cloneref or function(instance) return instance end
local function Service(name)
    local service = game:GetService(name)
    local ok, ref = pcall(cloneref, service)
    return ok and ref or service
end

local CoreGui = Service("CoreGui")
local HttpService = Service("HttpService")
local Players = Service("Players")
local TweenService = Service("TweenService")
local UserInputService = Service("UserInputService")
local RunService = Service("RunService")

local getgenv = getgenv or function() return shared end
local setclipboard = setclipboard or toclipboard or (syn and syn.write_clipboard) or nil
local getclipboard = getclipboard or (syn and syn.get_clipboard) or nil
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function() return CoreGui end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local PreviewMode = LoaderConfig.Preview == true

local GameName = tostring(LoaderConfig.GameName or "this game")
local RawScriptId = LoaderConfig.LuarmorScriptId and tostring(LoaderConfig.LuarmorScriptId) or ""

local InvalidScriptId = not PreviewMode and (#RawScriptId ~= 32 or not RawScriptId:match("^[0-9a-fA-F]+$"))

local config = {
    Title = "nobulem.wtf",
    Folder = "nobulem",
    KeyFile = "key.txt",
    LegacyFile = LoaderConfig.SaveFile or "nobulem_key.txt",
    LuarmorScriptId = RawScriptId,
    LuarmorSdkUrl = "https://sdkapi-public.luarmor.net/library.lua",
    Links = {
        [12] = {
            { Name = "Linkvertise", Url = LoaderConfig.Linkvertise12hUrl or LoaderConfig.LinkvertiseUrl or LoaderConfig.GetKeyUrl
                or "https://ads.luarmor.net/get_key?for=Linkvertise-WNOSNrUbmMHZ" },
            { Name = "Lootlabs", Url = (type(LoaderConfig.LootLabsUrl) == "string" and LoaderConfig.LootLabsUrl ~= "" and LoaderConfig.LootLabsUrl)
                or "https://ads.luarmor.net/get_key?for=Lootlabs-uWczMBbSTANN" },
        },
        [24] = {
            { Name = "Linkvertise", Url = LoaderConfig.Linkvertise24hUrl
                or "https://ads.luarmor.net/get_key?for=Linkvertise_2-KLYIoYnluHnT" },
        },
    },
    Logo = "rbxassetid://138831083704120",
    DiscordInvite = "https://discord.gg/mugcSRnpuG",
    BuyUrl = "https://nobulem.com/pricing/",
    ExecutorsUrl = "https://nobulem.com/executors",
    UnsupportedExecutors = { "solara", "velocity", "xeno" },
    LifetimePrice = "$19.99",
    WeeklyPrice = "$3.50",
    MinutesPerCheckpoint = 3,
    PreloadNudgeSeconds = 3.5,
    UpsellSeconds = 8,
    LifetimeThreshold = 3 * 86400,
    ShowPremiumPopup = LoaderConfig.ShowPremiumPopup ~= false,
}

local writefile = not PreviewMode and writefile or nil
local delfile = not PreviewMode and delfile or nil

local function EnsureFolder()
    if not (isfolder and makefolder) then return false end
    if isfolder(config.Folder) then return true end
    return (pcall(makefolder, config.Folder))
end

local function KeyPath()
    return config.Folder .. "/" .. config.KeyFile
end

local function StatsPath()
    return config.Folder .. "/usage.json"
end

local function ReadText(path)
    if not (isfile and readfile) then return nil end
    local okExists, exists = pcall(isfile, path)
    if not okExists or not exists then return nil end
    local ok, data = pcall(readfile, path)
    if ok and type(data) == "string" then return data end
    return nil
end

local function ReadKey(path)
    local data = ReadText(path)
    if not data then return nil end
    local cleaned = data:gsub("%s", "")
    return #cleaned > 0 and cleaned or nil
end

local function LegacyKeyPaths()
    local paths = {
        config.Folder .. "/key_" .. config.LuarmorScriptId .. ".txt",
        config.LegacyFile,
    }
    if listfiles and isfolder and isfolder(config.Folder) then
        local ok, files = pcall(listfiles, config.Folder)
        if ok and type(files) == "table" then
            for _, entry in files do
                if type(entry) == "string" then
                    local normalized = entry:gsub("\\", "/")
                    if normalized:match("/key_[^/]*%.txt$") then
                        table.insert(paths, normalized)
                    end
                end
            end
        end
    end
    return paths
end

local function SaveKey(key)
    if not writefile then return end
    if EnsureFolder() then
        pcall(writefile, KeyPath(), key)
    else
        pcall(writefile, config.LegacyFile, key)
    end
end

local function LoadSavedKey()
    if PreviewMode then return LoaderConfig.PreviewSavedKey end
    local key = ReadKey(KeyPath())
    if key then return key end
    for _, path in LegacyKeyPaths() do
        local legacy = ReadKey(path)
        if legacy then
            SaveKey(legacy)
            return legacy
        end
    end
    return nil
end

local function ForgetSavedKey()
    if not (isfile and delfile) then return end
    for _, path in { KeyPath(), table.unpack(LegacyKeyPaths()) } do
        if isfile(path) then pcall(delfile, path) end
    end
end

local Stats = { checkpoints = 0, lastKey = 0, keyId = "", keyFirstSeen = 0 }

do
    local raw = ReadText(StatsPath())
    local ok, decoded = pcall(function() return raw and HttpService:JSONDecode(raw) end)
    if ok and type(decoded) == "table" then
        Stats.checkpoints = tonumber(decoded.checkpoints) or 0
        Stats.lastKey = tonumber(decoded.lastKey) or 0
        Stats.keyId = tostring(decoded.keyId or "")
        Stats.keyFirstSeen = tonumber(decoded.keyFirstSeen) or 0
    end
end

local function SaveStats()
    if not writefile or not EnsureFolder() then return end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Stats)
    if ok then pcall(writefile, StatsPath(), encoded) end
end

local function HashKey(key)
    local total = 7
    for i = 1, #key do
        total = (total * 31 + key:byte(i)) % 2147483647
    end
    return tostring(total) .. "-" .. tostring(#key)
end

local function NoteKeyInUse(key)
    local id = HashKey(key)
    if Stats.keyId == id then return false end
    Stats.keyId = id
    Stats.keyFirstSeen = os.time()
    SaveStats()
    return true
end

local function CountCheckpoint()
    Stats.checkpoints += 1
    Stats.lastKey = os.time()
    SaveStats()
end

local function IsLifetimeKey(key, expiresAt, neverExpires)
    if neverExpires then return true end
    if expiresAt and expiresAt > os.time() then
        return expiresAt - os.time() > config.LifetimeThreshold
    end
    if Stats.keyId ~= HashKey(key) or Stats.keyFirstSeen <= 0 then return false end
    return os.time() - Stats.keyFirstSeen >= config.LifetimeThreshold
end

local function UsageLine()
    local count = Stats.checkpoints
    if count <= 0 then return "Lifetime members never see this screen." end
    if count == 1 then return "You've unlocked 1 free key on this device." end
    return ("You've unlocked %d free keys here - about %d minutes of links."):format(count, count * config.MinutesPerCheckpoint)
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days = seconds // 86400
    local hours = (seconds % 86400) // 3600
    local minutes = (seconds % 3600) // 60
    if days > 0 then return ("%dd %dh"):format(days, hours) end
    if hours > 0 then return ("%dh %dm"):format(hours, minutes) end
    return ("%dm"):format(math.max(1, minutes))
end

local function IsValidKeyFormat(key)
    return type(key) == "string" and #key == 32 and key:match("^%a+$") ~= nil
end

local function ExtractKey(text)
    text = tostring(text or "")
    for run in text:gmatch("%a+") do
        if #run == 32 then return run end
    end
    return (text:gsub("%s", ""))
end

local function SetKeyGlobals(key)
    _G.ScriptKey = key
    _G.script_key = key
    local env = getgenv()
    env.ScriptKey = key
    env.script_key = key
    env.Key = key
end

local function ClearKeyGlobals()
    SetKeyGlobals(nil)
end

local KeyMessages = {
    KEY_EXPIRED = { "This key has expired. Grab a fresh one above.", "dead" },
    KEY_BANNED = { "This key has been banned.", "dead" },
    KEY_HWID_LOCKED = { "This key is locked to another device. Reset your HWID in the Discord.", "rejected" },
    KEY_INCORRECT = { "Key not found - make sure you copied all of it.", "rejected" },
    KEY_INVALID = { "Key not found - make sure you copied all of it.", "rejected" },
    SCRIPT_ID_INCORRECT = { GameName .. " is not set up on Luarmor yet.", "error" },
    SCRIPT_ID_INVALID = { GameName .. " is not set up on Luarmor yet.", "error" },
    INVALID_EXECUTOR = { "Luarmor does not support your executor.", "error" },
}

local CachedSdk = nil
local function GetSdk()
    if CachedSdk then return CachedSdk end
    local source = game:HttpGet(config.LuarmorSdkUrl)
    local chunk, compileErr = loadstring(source)
    if not chunk then error("SDK compile: " .. tostring(compileErr), 0) end
    local sdk = chunk()
    if type(sdk) ~= "table" or type(sdk.check_key) ~= "function" then
        error("SDK returned an invalid value", 0)
    end
    sdk.script_id = config.LuarmorScriptId
    CachedSdk = sdk
    return sdk
end

local function CheckOnce(key)
    if PreviewMode then
        task.wait(0.9)
        if key == string.rep("A", 32) then
            return { ok = true, sdk = { load_script = function() end },
                expiresAt = os.time() + 11 * 3600 + 42 * 60 }
        end
        return { ok = false, kind = "rejected", message = KeyMessages.KEY_INCORRECT[1] }
    end

    local sdkOk, sdk = pcall(GetSdk)
    if not sdkOk then
        return { ok = false, kind = "transient", message = "Couldn't reach Luarmor. Check your connection and try again." }
    end
    local checkOk, result = pcall(sdk.check_key, key)
    if not checkOk or type(result) ~= "table" or result.code == nil then
        return { ok = false, kind = "transient", message = "Luarmor didn't answer properly. Try again in a moment." }
    end

    local code = tostring(result.code)
    if code == "KEY_VALID" then
        local data = type(result.data) == "table" and result.data or {}
        local expiresAt = tonumber(data.auth_expire)
        if expiresAt and expiresAt > 1e11 then expiresAt //= 1000 end
        local neverExpires = expiresAt ~= nil and expiresAt <= 0
        if neverExpires then expiresAt = nil end
        return { ok = true, sdk = sdk, expiresAt = expiresAt, neverExpires = neverExpires }
    end

    local known = KeyMessages[code]
    if known then
        return { ok = false, kind = known[2], message = known[1], code = code }
    end
    return {
        ok = false, kind = "transient", code = code,
        message = ("Luarmor couldn't verify right now (%s)."):format(tostring(result.message or code)),
    }
end

local function CheckKey(key)
    local result
    for attempt = 1, 3 do
        result = CheckOnce(key)
        if result.ok or result.kind ~= "transient" then break end
        if attempt < 3 then task.wait(1.25 * attempt) end
    end
    return result
end

local function GetExecutorName()
    if PreviewMode and type(LoaderConfig.PreviewExecutor) == "string" then return LoaderConfig.PreviewExecutor end
    local ok, name = pcall(function()
        if not identifyexecutor then return "Unknown" end
        local n = identifyexecutor()
        return type(n) == "table" and n[1] or n
    end)
    return ok and name and tostring(name) or "Unknown"
end

local function GetDeviceType()
    if IsMobile then return "Mobile" end
    if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return "Console" end
    return "PC"
end

local function GetHWID()
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    return ok and id and tostring(id) or tostring(LocalPlayer.UserId)
end

local GuiService = Service("GuiService")

local RGB = Color3.fromRGB
local Offset = UDim2.fromOffset
local Dim2 = UDim2.new
local floor, round = math.floor, math.round
local FULL = 99
local INTER = "rbxassetid://12187365364"

local Theme = {
    Background = RGB(16, 16, 18),
    Tab = RGB(12, 11, 14),
    Outline = RGB(44, 42, 52),
    Inline = RGB(24, 24, 29),
    Text = RGB(234, 232, 244),
    InactiveText = RGB(118, 114, 134),
    Accent = RGB(159, 109, 255),
    Element = RGB(24, 23, 31),
    Gradient = RGB(166, 164, 175),
    Shadow = RGB(0, 0, 0),
    HoveredElement = RGB(38, 36, 48),
    Success = RGB(112, 205, 132),
    Error = RGB(235, 104, 104),
    Warning = RGB(236, 190, 92),
}

local M = {
    Pad = 10, Gap = 6, SectionGap = 10,
    Radius = 3, CardRadius = 4, PillRadius = 5, FloatRadius = 6, WindowRadius = 6,
    TopBarH = 44, Row = 16, HeaderH = 24, InputH = 26, ButtonH = 28,
}

local COLUMN_W = 232
local WINDOW_W, WINDOW_H = COLUMN_W * 2 + M.Pad * 3, 400

local Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Smooth = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local Soft = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function Tween(instance, info, props)
    local tween = TweenService:Create(instance, info, props)
    tween:Play()
    return tween
end

local function FontOf(weight)
    return Font.new(INTER, weight or Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
end

local function Hex(color)
    return "#" .. color:ToHex()
end

local TextClasses = { TextLabel = true, TextButton = true, TextBox = true }

local function New(className, props, parent)
    local instance = Instance.new(className)
    if instance:IsA("GuiObject") then
        instance.BorderSizePixel = 0
        instance.BackgroundTransparency = 1
    end
    if className == "TextButton" then
        instance.AutoButtonColor = false
        instance.Text = ""
    end
    if TextClasses[className] then
        instance.FontFace = FontOf()
        instance.TextSize = 13
        instance.TextColor3 = Theme.Text
        instance.TextXAlignment = Enum.TextXAlignment.Left
        instance.TextYAlignment = Enum.TextYAlignment.Top
    end
    local radius, border
    for key, value in props or {} do
        if key == "Bg" then
            instance.BackgroundColor3 = Theme[value]
            if props.BackgroundTransparency == nil then instance.BackgroundTransparency = 0 end
        elseif key == "Fg" then
            instance.TextColor3 = Theme[value]
        elseif key == "Radius" then
            radius = value
        elseif key == "Border" then
            border = value
        elseif key == "Weight" then
            instance.FontFace = FontOf(value)
        else
            instance[key] = value
        end
    end
    if radius then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = radius >= FULL and UDim.new(0.5, 0) or UDim.new(0, radius)
        corner.Parent = instance
    end
    if border then
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Color = typeof(border) == "Color3" and border or Theme[border]
        stroke.Parent = instance
    end
    if parent then instance.Parent = parent end
    return instance
end

local function CapOffset(rowH, size)
    local capHeight = round(size * 0.7)
    return math.ceil((rowH - capHeight) / 2 - round(size * 0.16))
end

local function Text(parent, o)
    local size, rowH, x = o.TextSize or 12, o.RowH or M.Row, o.X or 0
    return New("TextLabel", {
        Fg = o.Fg or "Text",
        Text = o.Text or "",
        TextSize = size,
        Weight = o.Weight,
        TextTruncate = o.Truncate,
        RichText = o.Rich or false,
        TextXAlignment = o.Align or Enum.TextXAlignment.Left,
        ZIndex = o.ZIndex or 1,
        Position = Offset(x, (o.Y or 0) + CapOffset(rowH, size)),
        Size = o.W and Offset(o.W, rowH) or Dim2(1, -x - (o.Right or 0), 0, rowH),
    }, parent)
end

local function Gradient(instance)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Gradient)
    gradient.Parent = instance
    return gradient
end

local ShadowsAvailable = pcall(function() Instance.new("UIShadow"):Destroy() end)

local function AddShadow(instance)
    if not ShadowsAvailable then return end
    pcall(function()
        local shadow = Instance.new("UIShadow")
        shadow.BlurRadius = UDim.new(0, 10)
        shadow.Spread = Offset(0, 0)
        shadow.Transparency = 0.3
        shadow.Color = Theme.Shadow
        shadow.Parent = instance
    end)
end

local Icons = {
    cube = {
        { "f", 4, 1.1, 8, 13.8, 0, 0 }, { "f", 4, 1.1, 8, 13.8, 0, 60 }, { "f", 4, 1.1, 8, 13.8, 0, 120 },
        { "h", 7.5, 8, 1, 6.6, 0, 0 }, { "h", 4.6, 2.6, 1, 6.8, 0, 120 }, { "h", 10.4, 2.6, 1, 6.8, 0, 60 },
    },
    key = {
        { "f", 1, 8.5, 7, 7, FULL }, { "f", 6.2, 5, 9, 2.2, 0.6, -45 }, { "f", 11.2, 4.6, 3.4, 2, 0.4, 45 },
        { "h", 3.1, 10.6, 2.8, 2.8, FULL },
    },
    user = { { "f", 5, 1, 6, 6, FULL }, { "f", 2.5, 8.5, 11, 6.5, 3 } },
    check = { { "f", 2, 8.4, 6.2, 2, FULL, 45 }, { "f", 5.2, 6.8, 10, 2, FULL, -45 } },
    cross = { { "f", 1.5, 7, 13, 2, FULL, 45 }, { "f", 1.5, 7, 13, 2, FULL, -45 } },
    alert = { { "f", 1, 1, 14, 14, FULL }, { "h", 7, 3.6, 2, 6, FULL }, { "h", 7, 10.8, 2, 2, FULL } },
    info = { { "f", 1, 1, 14, 14, FULL }, { "h", 7, 6.6, 2, 6, FULL }, { "h", 7, 3.4, 2, 2, FULL } },
    gem = { { "f", 3.2, 3.2, 9.6, 9.6, 1.5, 45 }, { "h", 5.6, 5.6, 4.8, 4.8, 0.8, 45 } },
    file = {
        { "f", 3, 1, 10, 14, 1.5 }, { "h", 10.6, -0.8, 4.2, 4.2, 0, 45 }, { "h", 5.5, 7.5, 5, 1.1, 0 },
        { "h", 5.5, 10.3, 5, 1.1, 0 },
    },
    globe = {
        { "f", 1, 1, 14, 14, FULL }, { "h", 3, 3.2, 4.4, 3, FULL, -20 }, { "h", 8.2, 8, 4.6, 3.8, FULL, 20 },
        { "h", 9.8, 2.8, 2.6, 2, FULL }, { "h", 3.4, 9.6, 2.6, 2.6, FULL },
    },
    gear = {
        { "f", 6.5, 0.8, 3, 14.4, 0.6, 0 }, { "f", 6.5, 0.8, 3, 14.4, 0.6, 45 }, { "f", 6.5, 0.8, 3, 14.4, 0.6, 90 },
        { "f", 6.5, 0.8, 3, 14.4, 0.6, 135 }, { "f", 2.6, 2.6, 10.8, 10.8, FULL }, { "h", 5.6, 5.6, 4.8, 4.8, FULL },
    },
}

local LucideLib
do
    local env = getgenv and getgenv() or _G
    if type(env.NobulemLucide) == "table" then
        LucideLib = env.NobulemLucide
    else
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/notpoiu/lucide-roblox-direct/refs/heads/main/source.lua"))()
        end)
        if ok and type(lib) == "table" and type(lib.GetAsset) == "function" then
            LucideLib = lib
            env.NobulemLucide = lib
        end
    end
end

local LucideNames = {
    key = "key",
    check = "circle-check",
    cross = "x",
    alert = "triangle-alert",
    info = "info",
    gem = "gem",
    globe = "globe",
    user = "user",
    file = "file-text",
    gear = "settings",
    cube = "box",
    tick = "check",
}

Icons.tick = Icons.check

local function LucideData(name)
    if not LucideLib then return nil end
    local ok, data = pcall(LucideLib.GetAsset, LucideNames[name] or name)
    if ok and type(data) == "table" and data.Url then return data end
    return nil
end

local function MakeIcon(parent, name, size, color, hole, props)
    props = props or {}
    local root = New("Frame", {
        Name = "Icon",
        Size = Offset(size, size),
        Position = props.Position or Offset(0, 0),
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        ZIndex = props.ZIndex or 1,
    }, parent)
    local sprite = LucideData(name)
    if sprite then
        local image = New("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            Image = sprite.Url,
            ImageRectOffset = sprite.ImageRectOffset,
            ImageRectSize = sprite.ImageRectSize,
            ImageColor3 = color,
            ZIndex = props.ZIndex or 1,
        }, root)
        local lucideIcon = { Root = root }
        function lucideIcon.Set(newColor, _, instant)
            if instant then image.ImageColor3 = newColor else Tween(image, Fast, { ImageColor3 = newColor }) end
        end
        return lucideIcon
    end
    local fills, holes = {}, {}
    local scale = size / 16
    for _, part in Icons[name] or Icons.cube do
        local kind, x, y, w, h, radius, rotation = table.unpack(part, 1, 7)
        local frame = New("Frame", {
            Position = UDim2.fromScale(x / 16, y / 16),
            Size = UDim2.fromScale(w / 16, h / 16),
            Rotation = rotation or 0,
            BackgroundTransparency = 0,
            BackgroundColor3 = kind == "h" and hole or color,
            ZIndex = props.ZIndex or 1,
            Radius = radius and radius > 0 and (radius >= FULL and FULL or math.max(1, round(radius * scale))) or nil,
        }, root)
        table.insert(kind == "h" and holes or fills, frame)
    end
    local icon = { Root = root }
    function icon.Set(newColor, newHole, instant)
        for _, frame in fills do
            if instant then frame.BackgroundColor3 = newColor else Tween(frame, Fast, { BackgroundColor3 = newColor }) end
        end
        if newHole then
            for _, frame in holes do
                if instant then frame.BackgroundColor3 = newHole else Tween(frame, Fast, { BackgroundColor3 = newHole }) end
            end
        end
    end
    return icon
end

local function CaptureFade(root)
    local entries = {}
    local function add(instance, prop)
        local base = instance[prop]
        if base < 1 then table.insert(entries, { instance, prop, base }) end
    end
    local function visit(instance)
        if instance:IsA("GuiObject") then
            if instance ~= root and not instance.Visible then return end
            add(instance, "BackgroundTransparency")
            if TextClasses[instance.ClassName] then add(instance, "TextTransparency") end
            if instance:IsA("ImageLabel") then add(instance, "ImageTransparency") end
        elseif instance:IsA("UIStroke") or instance.ClassName == "UIShadow" then
            add(instance, "Transparency")
        end
        for _, child in instance:GetChildren() do visit(child) end
    end
    visit(root)
    return entries
end

local function Fade(root, show, info, done)
    local entries = CaptureFade(root)
    local driver = Instance.new("NumberValue")
    local function apply(alpha)
        for _, entry in entries do
            entry[1][entry[2]] = 1 - (1 - entry[3]) * alpha
        end
    end
    driver.Value = show and 0 or 1
    apply(driver.Value)
    if show then root.Visible = true end
    driver.Changed:Connect(apply)
    local tween = TweenService:Create(driver, info, { Value = show and 1 or 0 })
    tween.Completed:Connect(function()
        if not show then root.Visible = false end
        apply(1)
        driver:Destroy()
        if done then done() end
    end)
    tween:Play()
end

local function ParentGui(gui)
    local placed = pcall(function()
        pcall(protectgui, gui)
        gui.Parent = gethui()
    end)
    if not (placed and gui.Parent) then
        placed = pcall(function() gui.Parent = CoreGui end)
    end
    if not (placed and gui.Parent) then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge)
    end
end

for _, name in { "NobulemKeySystem", "NobulemKeyNotifications", "NobulemLoaderStatus", "ObsidianKeySystem", "ObsidianKeyNotification" } do
    local hiddenOk, hidden = pcall(gethui)
    for _, parent in { CoreGui, hiddenOk and hidden or nil } do
        pcall(function()
            local existing = parent:FindFirstChild(name)
            if existing then existing:Destroy() end
        end)
    end
end

local NotifyGui, NotifyArea = nil, nil
local NotifyStack = {}
local NotifyColors = { success = Theme.Success, error = Theme.Error, info = Theme.Accent, warning = Theme.Warning }
local NotifyIcons = { success = "check", error = "alert", info = "info", warning = "alert" }

local function EnsureNotifyGui()
    if NotifyGui and NotifyGui.Parent then return end
    NotifyGui = New("ScreenGui", {
        Name = "NobulemKeyNotifications",
        DisplayOrder = 1000,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ParentGui(NotifyGui)
    NotifyArea = New("Frame", { Name = "Notifications", Position = Offset(16, 16), Size = Offset(400, 600), ZIndex = 50 }, NotifyGui)
end

local function Restack()
    local count = #NotifyStack
    for index, item in NotifyStack do
        local y = (count - index) * 36
        if not item.Placed then
            item.Placed = true
            item.Frame.Position = Offset(-36, y)
        end
        Tween(item.Frame, Smooth, { Position = Offset(0, y) })
    end
end

local function PushNotification(text, kind, duration)
    EnsureNotifyGui()
    local frame = New("Frame", {
        Bg = "Background",
        Size = Offset(60, 28),
        Radius = M.FloatRadius,
        Border = "Outline",
        Visible = false,
        ZIndex = 50,
    }, NotifyArea)
    MakeIcon(frame, NotifyIcons[kind] or "check", 14, NotifyColors[kind] or Theme.Success, Theme.Background, { Position = Offset(8, 7), ZIndex = 50 })
    local label = Text(frame, { Text = text, TextSize = 12, X = 28, RowH = 28, W = 340, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 50 })
    local function fit()
        frame.Size = Offset(math.min(math.ceil(label.TextBounds.X), 340) + 38, 28)
    end
    label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
    fit()

    local entry = { Frame = frame }
    table.insert(NotifyStack, 1, entry)
    function entry.Dismiss()
        if entry.Gone then return end
        entry.Gone = true
        local index = table.find(NotifyStack, entry)
        if index then table.remove(NotifyStack, index) end
        Tween(frame, Smooth, { Position = Offset(-36, frame.Position.Y.Offset) })
        Fade(frame, false, Fast, function()
            frame:Destroy()
            if #NotifyStack == 0 then
                task.delay(0.5, function()
                    if #NotifyStack == 0 and NotifyGui then
                        NotifyGui:Destroy()
                        NotifyGui, NotifyArea = nil, nil
                    end
                end)
            end
        end)
        Restack()
    end
    Restack()
    Fade(frame, true, Smooth)
    if #NotifyStack > 6 then NotifyStack[#NotifyStack].Dismiss() end
    task.delay(duration or 4, entry.Dismiss)
    return entry
end

local function SplitLines(text, width)
    local lines = {}
    for paragraph in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            while #word > width do
                if line ~= "" then
                    table.insert(lines, line)
                    line = ""
                end
                table.insert(lines, word:sub(1, width))
                word = word:sub(width + 1)
            end
            if line ~= "" and #line + #word + 1 > width then
                table.insert(lines, line)
                line = word
            else
                line = line == "" and word or (line .. " " .. word)
            end
        end
        if line ~= "" then table.insert(lines, line) end
    end
    return lines
end

local function Notify(text, kind, duration)
    for _, line in SplitLines(text, 52) do
        pcall(PushNotification, line, kind or "info", duration)
    end
end

if InvalidScriptId then
    Notify(GameName .. " isn't set up on Luarmor yet, so no key can work here.", "error", 10)
    return
end

local function CopyText(value, message)
    if setclipboard and pcall(setclipboard, value) then
        Notify(message, "success", 4)
        return true
    end
    Notify("Your executor can't copy. Here it is: " .. value, "info", 12)
    return false
end

local function CopyCheckout()
    CopyText(config.BuyUrl, "Checkout link copied. Paste it in your browser.")
end

local Gui = nil

local function EnsureGui()
    if Gui and Gui.Parent then return Gui end
    Gui = New("ScreenGui", {
        Name = "NobulemKeySystem",
        DisplayOrder = 999,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ParentGui(Gui)
    return Gui
end

local function DestroyGui()
    if Gui then pcall(Gui.Destroy, Gui) end
    Gui = nil
end

local function IsClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function MousePos()
    local location = UserInputService:GetMouseLocation()
    if Gui then return location + Gui.AbsolutePosition end
    return location
end

local function Inside(frame, point)
    local position, size = frame.AbsolutePosition, frame.AbsoluteSize
    return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

local function IsShown(instance)
    local node = instance
    while node and node:IsA("GuiObject") do
        if not node.Visible then return false end
        node = node.Parent
    end
    return true
end

local Controls = {}

local function RegisterControl(instance)
    Controls[instance] = true
    instance.Destroying:Once(function() Controls[instance] = nil end)
end

local function OverControl(point)
    for control in Controls do
        if control.Parent and IsShown(control) and Inside(control, point) then return true end
    end
    return false
end

local function Button(parent, opts)
    local primary = opts.Primary == true
    local button = New("TextButton", {
        Bg = "Element",
        Size = opts.Size or Dim2(1, 0, 0, M.ButtonH),
        LayoutOrder = opts.Order or 0,
        Radius = M.Radius,
        Border = primary and "Accent" or "Outline",
    }, parent)
    Gradient(button)
    RegisterControl(button)
    local label = New("TextLabel", {
        Fg = primary and "Accent" or "Text",
        Text = opts.Text or "",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = Offset(6, CapOffset(M.ButtonH - 2, 13)),
        Size = Dim2(1, -12, 0, M.ButtonH - 2),
    }, button)

    local enabled, hovered, pressed = true, false, false
    local function Paint()
        local color = Theme.Element
        if enabled and pressed then
            color = Theme.Inline
        elseif enabled and hovered then
            color = Theme.HoveredElement
        end
        Tween(button, Fast, { BackgroundColor3 = color })
        Tween(label, Fast, { TextTransparency = enabled and 0 or 0.5 })
    end
    button.MouseEnter:Connect(function() hovered = true; Paint() end)
    button.MouseLeave:Connect(function() hovered, pressed = false, false; Paint() end)
    button.MouseButton1Down:Connect(function() pressed = true; Paint() end)
    button.MouseButton1Up:Connect(function() pressed = false; Paint() end)

    local controller = { Instance = button, Label = label }
    function controller.SetText(text) label.Text = text end
    function controller.SetEnabled(state)
        enabled = state
        Paint()
    end
    function controller.OnClick(callback)
        button.Activated:Connect(function()
            if enabled then callback() end
        end)
    end
    if opts.Callback then controller.OnClick(opts.Callback) end
    return controller
end

local function ButtonRow(parent, order)
    local row = New("Frame", {
        Size = Dim2(1, 0, 0, M.ButtonH),
        LayoutOrder = order,
    }, parent)
    local layout = New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        Padding = UDim.new(0, M.Gap),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    return row, layout
end

local function Row(parent, order, height)
    local row, layout = ButtonRow(parent, order)
    layout:Destroy()
    row.Size = Dim2(1, 0, 0, height or M.Row)
    return row
end

local function Paragraph(parent, order, text, color)
    return New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = Dim2(1, 0, 0, 0),
        LayoutOrder = order,
        Text = text,
        TextSize = 12,
        TextColor3 = color or Theme.InactiveText,
        TextWrapped = true,
        RichText = true,
        LineHeight = 1.1,
    }, parent)
end

local function MakeColumn(page, index)
    local column = New("Frame", {
        Position = Offset(M.Pad + (index - 1) * (COLUMN_W + M.Pad), 0),
        Size = Dim2(0, COLUMN_W, 1, 0),
    }, page)
    New("UIListLayout", { Padding = UDim.new(0, M.SectionGap), SortOrder = Enum.SortOrder.LayoutOrder }, column)
    return column
end

local SectionCount = 0

local function Section(column, name, icon)
    SectionCount += 1
    local root = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = Dim2(1, 0, 0, 0),
        LayoutOrder = SectionCount,
    }, column)
    local header = New("Frame", { Size = Dim2(1, 0, 0, M.HeaderH - 8) }, root)
    MakeIcon(header, icon, 16, Theme.InactiveText, Theme.Tab)
    Text(header, { Text = name, X = 27, Fg = "InactiveText", Right = 60, Truncate = Enum.TextTruncate.AtEnd })
    local aside = Text(header, { Text = "", Fg = "InactiveText", TextSize = 11, Align = Enum.TextXAlignment.Right })
    local card = New("Frame", {
        Bg = "Inline",
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = Offset(1, M.HeaderH + 1),
        Size = Dim2(1, -2, 0, 0),
        Radius = M.CardRadius,
        Border = "Outline",
    }, root)
    New("UIPadding", {
        PaddingTop = UDim.new(0, 9),
        PaddingBottom = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, M.Pad - 1),
        PaddingRight = UDim.new(0, M.Pad - 1),
    }, card)
    New("UIListLayout", { Padding = UDim.new(0, M.Gap), SortOrder = Enum.SortOrder.LayoutOrder }, card)
    local section = { Root = root, Card = card, Aside = aside, Count = 0 }
    function section.Order()
        section.Count += 1
        return section.Count
    end
    return section
end

local function InfoRow(section, name, value)
    local row = Row(section.Card, section.Order())
    Text(row, { Text = name, Fg = "Text", Right = 90, Truncate = Enum.TextTruncate.AtEnd })
    return Text(row, { Text = value, Fg = "InactiveText", TextSize = 12, X = 70, Align = Enum.TextXAlignment.Right, Truncate = Enum.TextTruncate.AtEnd })
end

local function CheckRow(section, text)
    local row = Row(section.Card, section.Order())
    MakeIcon(row, "tick", 12, Theme.Success, Theme.Inline, { Position = Offset(0, 2) })
    Text(row, { Text = text, X = 20, TextSize = 12, Truncate = Enum.TextTruncate.AtEnd })
end

local Window = nil
local State = { busy = false, accepted = false }

local OpenWindow

local function PublishKeyInfo(key, result)
    local env = getgenv()
    local info = { Lifetime = false, ExpiresAt = type(result) == "table" and result.expiresAt or nil }
    env.NobulemKeyInfo = info
    if info.ExpiresAt or type(result) ~= "table" or not result.neverExpires or PreviewMode then return info end
    task.spawn(function()
        for attempt = 1, 8 do
            task.wait(attempt == 1 and 3 or 8)
            if env.NobulemKeyInfo ~= info then return end
            local again = CheckOnce(key)
            if env.NobulemKeyInfo ~= info then return end
            if again.ok and again.expiresAt then
                info.ExpiresAt = again.expiresAt
                return
            end
            if again.ok and again.neverExpires and (info.Started or attempt >= 4) then
                info.Lifetime = true
                return
            end
        end
    end)
    return info
end

local function StartScript(key, sdk, result)
    SetKeyGlobals(key)
    local keyInfo = PublishKeyInfo(key, result)
    local function Run()
        DestroyGui()
        getgenv().NobulemKeySystemClosed = true
        task.wait()
        sdk.script_id = config.LuarmorScriptId
        local ok, err = pcall(sdk.load_script)
        keyInfo.Started = true
        if not ok then
            ClearKeyGlobals()
            getgenv().NobulemKeyInfo = nil
            State.accepted = false
            OpenWindow({ Prefill = key, Status = { "error", "The script failed to start (" .. tostring(err) .. "). Press Unlock to try again." } })
        end
    end
    if Window then
        Window.Close(Run)
    else
        Run()
    end
end

function OpenWindow(opts)
    opts = opts or {}
    if Window then Window.Destroy() end
    EnsureGui()
    getgenv().NobulemKeySystemClosed = false
    State.busy = false

    local connections = {}
    local function Track(connection)
        table.insert(connections, connection)
        return connection
    end

    local holder = New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = Offset(WINDOW_W, WINDOW_H),
        ZIndex = 10,
        Visible = false,
    }, Gui)
    local scale = New("UIScale", { Scale = 0.97 })
    local root = New("Frame", {
        Bg = "Background",
        Active = true,
        Size = Dim2(1, 0, 1, 0),
        Radius = M.WindowRadius,
        Border = "Outline",
    }, holder)
    AddShadow(root)

    local fit, moved, opening, closing = 1, false, true, false
    local function Fit()
        local size = Gui and Gui.AbsoluteSize
        if not size or size.X <= 0 then return end
        local inset = GuiService:GetGuiInset().Y
        fit = math.clamp(math.min((size.X - 24) / WINDOW_W, (size.Y - inset - 16) / WINDOW_H, 1), 0.5, 1)
        if not moved then
            holder.Position = Offset(floor(size.X / 2), floor((size.Y + (fit < 1 and inset or 0)) / 2))
        end
        if not opening and not closing then
            scale.Scale = fit
            scale.Parent = fit < 1 and holder or nil
        end
    end
    Fit()
    Track(Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit))

    local header = New("Frame", { Size = Dim2(1, 0, 0, M.TopBarH) }, root)
    New("ImageLabel", {
        Image = config.Logo,
        Position = Offset(M.Pad + 2, floor((M.TopBarH - 26) / 2)),
        Size = Offset(26, 26),
    }, header)
    local titleX = M.Pad + 2 + 26 + 8
    local title = Text(header, { Text = config.Title, TextSize = 16, Weight = Enum.FontWeight.Bold, X = titleX, RowH = M.TopBarH, W = 120 })
    Track(title:GetPropertyChangedSignal("TextBounds"):Connect(function()
        title.Size = Offset(math.ceil(title.TextBounds.X) + 1, M.TopBarH)
    end))
    title.Size = Offset(math.ceil(title.TextBounds.X) + 1, M.TopBarH)

    local closeSize = 26
    local closeButton = New("TextButton", {
        Bg = "Inline",
        AnchorPoint = Vector2.new(1, 0),
        Position = Dim2(1, -M.Pad, 0, floor((M.TopBarH - closeSize) / 2)),
        Size = Offset(closeSize, closeSize),
        Radius = M.PillRadius,
        Border = "Outline",
    }, header)
    RegisterControl(closeButton)
    local closeIcon = MakeIcon(closeButton, "cross", 10, Theme.InactiveText, Theme.Inline, { Position = Offset(8, 8) })
    closeButton.MouseEnter:Connect(function()
        Tween(closeButton, Fast, { BackgroundColor3 = Theme.HoveredElement })
        closeIcon.Set(Theme.Text, nil)
    end)
    closeButton.MouseLeave:Connect(function()
        Tween(closeButton, Fast, { BackgroundColor3 = Theme.Inline })
        closeIcon.Set(Theme.InactiveText, nil)
    end)

    Text(header, {
        Text = GameName,
        Fg = "InactiveText",
        TextSize = 12,
        X = titleX + 140,
        Right = M.Pad + closeSize + 10,
        RowH = M.TopBarH,
        Align = Enum.TextXAlignment.Right,
        Truncate = Enum.TextTruncate.AtEnd,
    })

    New("Frame", { Bg = "Outline", Position = Offset(0, M.TopBarH), Size = Dim2(1, 0, 0, 1) }, root)
    local content = New("Frame", {
        Bg = "Tab",
        Position = Offset(0, M.TopBarH + 1),
        Size = Dim2(1, 0, 1, -(M.TopBarH + 1)),
        Radius = M.WindowRadius,
    }, root)
    New("Frame", { Name = "CornerPatch", Bg = "Tab", Size = Dim2(1, 0, 0, 12) }, content)

    local function NewPage(visible)
        local page = New("Frame", {
            Position = Offset(0, M.Pad),
            Size = Dim2(1, 0, 1, -M.Pad * 2),
            Visible = visible,
        }, content)
        return page, { MakeColumn(page, 1), MakeColumn(page, 2) }
    end

    local mainPage, columns = NewPage(true)

    local layouts = {}
    local function Resize()
        local tallest = 0
        for _, layout in layouts do
            if layout.Parent and layout.Parent.Parent and layout.Parent.Parent.Visible then
                tallest = math.max(tallest, layout.AbsoluteContentSize.Y)
            end
        end
        local factor = holder.AbsoluteSize.Y > 0 and holder.Size.Y.Offset > 0 and holder.AbsoluteSize.Y / holder.Size.Y.Offset or 1
        local height = math.ceil(tallest / math.max(factor, 0.01))
        local target = M.TopBarH + 1 + M.Pad * 2 + height
        target += target % 2
        if target ~= WINDOW_H and height > 0 then
            WINDOW_H = target
            holder.Size = Offset(WINDOW_W, WINDOW_H)
            Fit()
        end
    end
    local function WatchColumns(list)
        for _, column in list do
            local layout = column:FindFirstChildOfClass("UIListLayout")
            table.insert(layouts, layout)
            Track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Resize))
        end
    end
    WatchColumns(columns)

    local getKey = Section(columns[1], "Get a key", "key")
    Paragraph(getKey.Card, getKey.Order(), "Pick a length, copy a link and open it in your browser. Your key shows up at the end.")

    local hours = 12
    local segment = New("Frame", {
        Bg = "Element",
        Size = Dim2(1, 0, 0, M.InputH),
        Radius = M.Radius,
        Border = "Outline",
        LayoutOrder = getKey.Order(),
    }, getKey.Card)
    Gradient(segment)
    local segmentIndicator = New("Frame", {
        Bg = "Inline",
        Position = Offset(2, 2),
        Size = Dim2(0.5, -4, 1, -4),
        Radius = M.Radius,
        Border = "Outline",
    }, segment)
    local segmentLabels = {}
    local providerHolder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = Dim2(1, 0, 0, 0),
        LayoutOrder = getKey.Order(),
    }, getKey.Card)
    New("UIListLayout", { Padding = UDim.new(0, M.Gap), SortOrder = Enum.SortOrder.LayoutOrder }, providerHolder)

    local SetStatus
    local providerButtons = {}

    local function RenderProviders()
        for _, existing in providerButtons do existing.Instance:Destroy() end
        table.clear(providerButtons)
        for index, provider in config.Links[hours] do
            local button = Button(providerHolder, { Text = "Copy " .. provider.Name .. " link", Order = index })
            button.OnClick(function()
                if type(provider.Url) ~= "string" or not provider.Url:match("^https://") then
                    Notify("This key link isn't set up yet.", "error")
                    return
                end
                CopyText(provider.Url, ("%s link copied. Open it in your browser."):format(provider.Name))
                SetStatus("info", ("Finish the %s steps, then paste your key below."):format(provider.Name))
            end)
            table.insert(providerButtons, button)
        end
        getKey.Aside.Text = ("%d hours"):format(hours)
    end

    local function SelectHours(value)
        hours = value
        Tween(segmentIndicator, Soft, { Position = value == 12 and Offset(2, 2) or Dim2(0.5, 2, 0, 2) })
        for option, label in segmentLabels do
            Tween(label, Fast, { TextColor3 = option == value and Theme.Text or Theme.InactiveText })
        end
        RenderProviders()
    end

    for index, value in { 12, 24 } do
        local option = New("TextButton", {
            Position = UDim2.fromScale((index - 1) * 0.5, 0),
            Size = UDim2.fromScale(0.5, 1),
            ZIndex = 2,
        }, segment)
        RegisterControl(option)
        segmentLabels[value] = New("TextLabel", {
            Fg = value == hours and "Text" or "InactiveText",
            Text = ("%d hours"):format(value),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = Offset(0, CapOffset(M.InputH - 2, 13)),
            Size = Dim2(1, 0, 0, M.InputH - 2),
            ZIndex = 2,
        }, option)
        option.Activated:Connect(function() SelectHours(value) end)
    end
    RenderProviders()

    local redeem = Section(columns[1], "Redeem", "check")
    local field = New("Frame", {
        Bg = "Element",
        Size = Dim2(1, 0, 0, M.InputH),
        Radius = M.Radius,
        Border = "Outline",
        LayoutOrder = redeem.Order(),
    }, redeem.Card)
    Gradient(field)
    local fieldStroke = field:FindFirstChildOfClass("UIStroke")
    local input = New("TextBox", {
        Fg = "Text",
        PlaceholderText = "Paste your key...",
        PlaceholderColor3 = Theme.InactiveText,
        Text = "",
        TextSize = 13,
        Position = Offset(7, CapOffset(M.InputH - 2, 13)),
        Size = Dim2(1, -14, 0, 18),
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, field)
    RegisterControl(input)

    local actionRow = ButtonRow(redeem.Card, redeem.Order())
    local paste = Button(actionRow, { Text = "Paste", Order = 1, Size = UDim2.fromScale(0, 1) })
    local unlock = Button(actionRow, { Text = "Unlock", Order = 2, Size = UDim2.fromScale(0, 1), Primary = true })
    local statusLabel = Paragraph(redeem.Card, redeem.Order(), "")

    local lifetime = Section(columns[2], "Lifetime", "gem")
    lifetime.Aside.Text = "skip the links"
    local priceRow = Row(lifetime.Card, lifetime.Order(), 24)
    Text(priceRow, {
        Text = ("%s <font size=\"12\" color=\"%s\">one time</font>"):format(config.LifetimePrice, Hex(Theme.InactiveText)),
        TextSize = 20,
        Weight = Enum.FontWeight.Bold,
        RowH = 24,
        Rich = true,
    })
    CheckRow(lifetime, "No keys or links, ever")
    CheckRow(lifetime, "Every current and future script")
    CheckRow(lifetime, "Priority updates and support")
    Paragraph(lifetime.Card, lifetime.Order(),
        ("Weekly plans start at <font color=\"%s\">%s</font>. %s"):format(Hex(Theme.Text), config.WeeklyPrice, UsageLine()))
    local buyRow = ButtonRow(lifetime.Card, lifetime.Order())
    Button(buyRow, { Text = "Checkout", Order = 1, Size = UDim2.fromScale(0, 1), Primary = true, Callback = CopyCheckout })
    Button(buyRow, {
        Text = "All plans",
        Order = 2,
        Size = UDim2.fromScale(0, 1),
        Callback = function() CopyText(config.BuyUrl, "Pricing link copied. Paste it in your browser.") end,
    })

    local support = Section(columns[2], "Support", "globe")
    InfoRow(support, "Executor", GetExecutorName() .. " / " .. GetDeviceType())
    local supportRow = ButtonRow(support.Card, support.Order())
    Button(supportRow, {
        Text = "Discord",
        Order = 1,
        Size = UDim2.fromScale(0, 1),
        Callback = function() CopyText(config.DiscordInvite, "Discord invite copied.") end,
    })
    Button(supportRow, {
        Text = "Copy HWID",
        Order = 2,
        Size = UDim2.fromScale(0, 1),
        Callback = function() CopyText(GetHWID(), "HWID copied. Send it to support for a key reset.") end,
    })

    local statusKind, statusKey = "idle", nil
    local focused = false
    local StatusColors = { idle = Theme.InactiveText, info = Theme.InactiveText, loading = Theme.Warning, success = Theme.Success, error = Theme.Error }

    local function PaintField()
        local color = Theme.Outline
        if statusKind == "error" or statusKind == "success" then
            color = StatusColors[statusKind]
        elseif focused then
            color = Theme.Accent
        end
        Tween(fieldStroke, Fast, { Color = color })
    end

    SetStatus = function(kind, text)
        statusKind = kind
        statusKey = ExtractKey(input.Text)
        statusLabel.Text = text
        Tween(statusLabel, Fast, { TextColor3 = StatusColors[kind] or Theme.InactiveText })
        PaintField()
    end

    local function UpdateCounter()
        local letters = select(2, ExtractKey(input.Text):gsub("%a", ""))
        local valid = IsValidKeyFormat(ExtractKey(input.Text))
        redeem.Aside.Text = ("%d / 32"):format(math.min(letters, 99))
        redeem.Aside.TextColor3 = valid and Theme.Success or (letters > 32 and Theme.Error or Theme.InactiveText)
    end

    local function SetBusy(busy)
        State.busy = busy
        unlock.SetEnabled(not busy)
        paste.SetEnabled(not busy)
        input.TextEditable = not busy
        unlock.SetText(busy and "Checking..." or "Unlock")
    end

    local function Shake()
        local base = holder.Position
        task.spawn(function()
            for _, offset in { 8, -7, 5, -3, 0 } do
                Tween(holder, TweenInfo.new(0.05), { Position = base + Offset(offset, 0) }).Completed:Wait()
            end
        end)
    end

    Track(root.InputBegan:Connect(function(dragStart)
        if not IsClick(dragStart) then return end
        local start = MousePos()
        if OverControl(start) then return end
        local origin = holder.Position
        local step, ended
        step = Track(RunService.RenderStepped:Connect(function()
            local delta = MousePos() - start
            if delta.Magnitude < 1 and not moved then return end
            moved = true
            local screen = Gui and Gui.AbsoluteSize or Vector2.new(1920, 1080)
            local half = holder.AbsoluteSize / 2
            local x = math.clamp(origin.X.Offset + delta.X, 60 - half.X, screen.X - 60 + half.X)
            local y = math.clamp(origin.Y.Offset + delta.Y, half.Y, math.max(half.Y, screen.Y - 30 + half.Y))
            holder.Position = Offset(round(x), round(y))
        end))
        ended = Track(UserInputService.InputEnded:Connect(function(released)
            if IsClick(released) then
                step:Disconnect()
                ended:Disconnect()
            end
        end))
    end))

    local controller = {}

    local function Destroy()
        for _, connection in connections do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(connections)
        if holder.Parent then holder:Destroy() end
        if Window == controller then Window = nil end
    end

    function controller.Close(callback)
        if closing then return end
        closing = true
        scale.Parent = holder
        Tween(scale, Fast, { Scale = fit * 0.97 })
        Fade(holder, false, Fast, function()
            Destroy()
            if callback then callback() end
        end)
    end

    function controller.ShowSuccess(details)
        closeButton.Visible = false
        local page, successColumns = NewPage(false)
        WatchColumns(successColumns)
        local done = Section(successColumns[1], "Unlocked", "check")
        local headline = Row(done.Card, done.Order(), 22)
        Text(headline, { Text = "You're in.", TextSize = 18, Weight = Enum.FontWeight.Bold, RowH = 22 })
        local detail = ("Starting %s now."):format(GameName)
        if details.ExpiresAt and not details.Lifetime then
            detail ..= (" Your key is good for another <font color=\"%s\">%s</font>."):format(
                Hex(Theme.Text), FormatDuration(details.ExpiresAt - os.time()))
        elseif details.Lifetime then
            detail ..= " Lifetime key, you won't see this screen again."
        end
        Paragraph(done.Card, done.Order(), detail)

        mainPage.Visible = false
        page.Visible = true
        page.Position = Offset(0, M.Pad + 10)
        Tween(page, Soft, { Position = Offset(0, M.Pad) })
        Resize()

        local finished = false
        local function Continue()
            if finished then return end
            finished = true
            details.OnContinue()
        end

        if details.Lifetime or not config.ShowPremiumPopup then
            task.delay(1.1, Continue)
            return
        end

        local upsell = Section(successColumns[2], "Make this your last key", "gem")
        Paragraph(upsell.Card, upsell.Order(),
            ("Free keys run out. Lifetime is <font color=\"%s\">%s once</font>: no links, every script, forever.")
                :format(Hex(Theme.Text), config.LifetimePrice))
        local buttons = ButtonRow(upsell.Card, upsell.Order())
        local buy = Button(buttons, { Text = "Go keyless", Order = 1, Size = UDim2.fromScale(0, 1), Primary = true })
        local skip = Button(buttons, { Text = "Continue", Order = 2, Size = UDim2.fromScale(0, 1) })
        local track = New("Frame", {
            Bg = "Element",
            Size = Dim2(1, 0, 0, 3),
            Radius = FULL,
            LayoutOrder = upsell.Order(),
        }, upsell.Card)
        local bar = New("Frame", { Bg = "Accent", Size = Dim2(1, 0, 1, 0), Radius = FULL }, track)
        Tween(bar, TweenInfo.new(config.UpsellSeconds, Enum.EasingStyle.Linear), { Size = Dim2(0, 0, 1, 0) })

        buy.OnClick(function()
            CopyCheckout()
            Continue()
        end)
        skip.OnClick(Continue)
        task.spawn(function()
            for remaining = config.UpsellSeconds, 1, -1 do
                if finished then return end
                skip.SetText(("Continue (%d)"):format(remaining))
                task.wait(1)
            end
            Continue()
        end)
    end

    controller.Destroy = Destroy
    controller.SetStatus = SetStatus
    controller.SetBusy = SetBusy
    controller.Shake = Shake
    controller.Input = input
    Window = controller

    local function Submit(raw)
        if State.busy or State.accepted then return end
        local key = ExtractKey(raw)
        if key == "" then
            SetStatus("error", "Paste your key first.")
            Shake()
            return
        end
        if not IsValidKeyFormat(key) then
            SetStatus("error", "That doesn't look like a key. Keys are exactly 32 letters.")
            Shake()
            return
        end
        if input.Text ~= key then input.Text = key end
        SetBusy(true)
        SetStatus("loading", "Checking your key...")
        task.spawn(function()
            local result = CheckKey(key)
            if Window ~= controller then return end
            if not result.ok then
                SetBusy(false)
                ClearKeyGlobals()
                if result.kind == "dead" then ForgetSavedKey() end
                SetStatus("error", result.message)
                Notify(result.message, "error", 5)
                Shake()
                return
            end

            State.accepted = true
            SetBusy(false)
            SetStatus("success", "Key accepted.")
            Notify("Key accepted.", "success", 3)
            SaveKey(key)
            local isLifetime = IsLifetimeKey(key, result.expiresAt, result.neverExpires)
            if NoteKeyInUse(key) and not isLifetime then CountCheckpoint() end
            task.wait(0.35)
            if Window ~= controller then return end
            controller.ShowSuccess({
                Lifetime = isLifetime,
                ExpiresAt = result.expiresAt,
                OnContinue = function() StartScript(key, result.sdk, result) end,
            })
        end)
    end

    closeButton.Activated:Connect(function()
        controller.Close(function()
            if not State.accepted then
                DestroyGui()
                ClearKeyGlobals()
                getgenv().NobulemKeySystemClosed = true
                getgenv().nobulem_loader_started = nil
            end
        end)
    end)

    unlock.OnClick(function() Submit(input.Text) end)

    paste.OnClick(function()
        if not getclipboard then
            SetStatus("error", IsMobile and "Your executor can't read the clipboard. Hold the key box to paste."
                or "Your executor can't read the clipboard. Paste with Ctrl+V.")
            return
        end
        local ok, data = pcall(getclipboard)
        local key = ExtractKey(ok and type(data) == "string" and data or "")
        if key == "" then
            SetStatus("error", "Your clipboard is empty. Copy your key first.")
            Shake()
            return
        end
        input.Text = key
        Submit(key)
    end)

    local idleText = "Paste a key and press Unlock."
    local lastAuto = nil
    Track(input:GetPropertyChangedSignal("Text"):Connect(function()
        UpdateCounter()
        if State.busy then return end
        local key = ExtractKey(input.Text)
        if statusKind == "error" and key ~= statusKey then SetStatus("idle", idleText) end
        if IsValidKeyFormat(key) and key ~= lastAuto then
            lastAuto = key
            task.delay(0.25, function()
                if Window == controller and ExtractKey(input.Text) == key then Submit(key) end
            end)
        end
    end))
    Track(input.Focused:Connect(function()
        focused = true
        PaintField()
    end))
    Track(input.FocusLost:Connect(function(enter)
        focused = false
        PaintField()
        if enter then Submit(input.Text) end
    end))

    SetStatus("idle", idleText)
    if opts.Prefill then
        lastAuto = ExtractKey(opts.Prefill)
        input.Text = opts.Prefill
    end
    UpdateCounter()
    if opts.Status then SetStatus(opts.Status[1], opts.Status[2]) end

    scale.Scale = fit * 0.97
    scale.Parent = holder
    Tween(scale, Smooth, { Scale = fit }).Completed:Connect(function()
        opening = false
        if not closing then
            scale.Scale = fit
            scale.Parent = fit < 1 and holder or nil
        end
    end)
    Fade(holder, true, Smooth)
    return controller
end

local function ProvidedKey()
    local env = getgenv()
    for _, value in { LoaderConfig.ScriptKey, env.script_key, _G.script_key } do
        if type(value) == "string" then
            local key = ExtractKey(value)
            if key ~= "" then return key end
        end
    end
    return nil
end

local function UnsupportedExecutor()
    local name = GetExecutorName()
    local lower = name:lower()
    for _, bad in config.UnsupportedExecutors do
        if lower:find(bad, 1, true) then return name end
    end
    return nil
end

local unsupported = UnsupportedExecutor()
if unsupported then
    Notify(unsupported .. " isn't supported and may break features. See nobulem.com/executors", "warning", 10)
end

local providedKey = ProvidedKey()
local savedKey = LoadSavedKey()
local candidates = {}
if providedKey and IsValidKeyFormat(providedKey) then table.insert(candidates, providedKey) end
if savedKey and IsValidKeyFormat(savedKey) and savedKey ~= providedKey then table.insert(candidates, savedKey) end

local lastFailure = nil
for _, key in candidates do
    local isSaved = key == savedKey
    local result = CheckKey(key)
    if result.ok then
        State.accepted = true
        if not isSaved then SaveKey(key) end
        local isLifetime = IsLifetimeKey(key, result.expiresAt, result.neverExpires)
        if NoteKeyInUse(key) and not isSaved and not isLifetime then CountCheckpoint() end
        Notify((isSaved and "Welcome back. Starting %s." or "Key accepted. Starting %s."):format(GameName), "success", 4)
        if config.ShowPremiumPopup and not isLifetime then
            Notify(("Skip keys: Lifetime is %s once at nobulem.com"):format(config.LifetimePrice), "info", 6)
        end
        StartScript(key, result.sdk, result)
        return
    end

    ClearKeyGlobals()
    if result.kind == "dead" and isSaved then ForgetSavedKey() end
    if not lastFailure then lastFailure = { key = key, result = result } end
end

if lastFailure then
    local result = lastFailure.result
    if result.kind == "dead" then
        OpenWindow({ Status = { "error", result.message } })
    elseif result.kind == "transient" then
        OpenWindow({ Prefill = lastFailure.key, Status = { "error", result.message .. " Press Unlock to retry." } })
    else
        OpenWindow({ Prefill = lastFailure.key, Status = { "error", result.message } })
    end
elseif providedKey then
    OpenWindow({ Prefill = providedKey, Status = { "error", "That doesn't look like a key. Keys are exactly 32 letters." } })
else
    OpenWindow()
end
