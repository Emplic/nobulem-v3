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
local Workspace = Service("Workspace")

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

if not PreviewMode and (#RawScriptId ~= 32 or not RawScriptId:match("^[0-9a-fA-F]+$")) then
    warn(("[nobulem.wtf] %s needs a valid 32-character Luarmor script ID."):format(GameName))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "nobulem.wtf",
            Text = GameName .. " is not set up on Luarmor yet - no key can validate here.",
            Duration = 10,
        })
    end)
    return
end

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
            { Name = "Work.ink", Url = LoaderConfig.WorkInkUrl or LoaderConfig.GetKeyUrl
                or "https://ads.luarmor.net/get_key?for=Work_ink-ENZrHfPIitmN" },
        },
        [24] = {
            { Name = "Linkvertise", Url = LoaderConfig.Linkvertise24hUrl
                or "https://ads.luarmor.net/get_key?for=Linkvertise_2-KLYIoYnluHnT" },
        },
    },
    Logo = "rbxassetid://138831083704120",
    DiscordInvite = "https://discord.gg/mugcSRnpuG",
    BuyUrl = "https://nobulem.com/pricing/",
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

local function IsLifetimeKey(key, expiresAt)
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
            return { ok = true, sdk = { load_script = function() print("[nobulem.wtf] preview: load_script") end },
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
        if expiresAt and expiresAt <= 0 then expiresAt = nil end
        return { ok = true, sdk = sdk, expiresAt = expiresAt }
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

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local Theme = {
    Window = rgb(12, 12, 17),
    Panel = rgb(17, 17, 24),
    Surface = rgb(23, 23, 32),
    SurfaceHover = rgb(30, 30, 41),
    Raised = rgb(36, 36, 50),
    Stroke = rgb(34, 34, 46),
    StrokeStrong = rgb(54, 54, 72),
    Text = rgb(238, 238, 245),
    Muted = rgb(152, 152, 172),
    Dim = rgb(100, 100, 120),
    Accent = rgb(125, 85, 255),
    AccentHover = rgb(146, 112, 255),
    Success = rgb(74, 222, 128),
    Error = rgb(248, 113, 113),
    Warning = rgb(251, 191, 36),
    White = rgb(255, 255, 255),
}

local Fonts = {
    Regular = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
    Medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
    Semibold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold),
    Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
    Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
}

local StatusColors = {
    idle = Theme.Dim,
    info = Theme.Muted,
    loading = Theme.Warning,
    success = Theme.Success,
    error = Theme.Error,
}

local Fast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local Smooth = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local Pop = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function Tween(instance, info, props)
    local tween = TweenService:Create(instance, info, props)
    tween:Play()
    return tween
end

local function New(className, props, children)
    local instance = Instance.new(className)
    local parent = props.Parent
    props.Parent = nil
    for key, value in props do
        instance[key] = value
    end
    for _, child in children or {} do
        child.Parent = instance
    end
    instance.Parent = parent
    return instance
end

local function Corner(radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function Stroke(color, transparency, thickness)
    return New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
    })
end

local function Padding(top, right, bottom, left)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, top),
        PaddingRight = UDim.new(0, right or top),
        PaddingBottom = UDim.new(0, bottom or top),
        PaddingLeft = UDim.new(0, left or right or top),
    })
end

local function List(padding, direction, hAlign, vAlign)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        FillDirection = direction or Enum.FillDirection.Vertical,
        HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
        VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function Label(props)
    local defaults = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Fonts.Regular,
        RichText = true,
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }
    for key, value in props do defaults[key] = value end
    return New("TextLabel", defaults)
end

local function Hex(color)
    return "#" .. color:ToHex()
end

local LucideIcons = nil
local IconWaiters = {}
task.spawn(function()
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"))()
    end)
    if ok and type(result) == "table" then LucideIcons = result end
    local waiters = IconWaiters
    IconWaiters = nil
    if LucideIcons then
        for _, callback in waiters do task.spawn(callback) end
    end
end)

local function ApplyIcon(image, name)
    if not LucideIcons then return false end
    local ok, asset = pcall(LucideIcons.GetAsset, name)
    if not ok or type(asset) ~= "table" then return false end
    image.Image = asset.Url or ("rbxassetid://" .. tostring(asset.Id or ""))
    image.ImageRectOffset = asset.ImageRectOffset or Vector2.zero
    image.ImageRectSize = asset.ImageRectSize or Vector2.zero
    return true
end

local function Icon(name, size, color, props)
    local image = New("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "",
        ImageColor3 = color or Theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromOffset(size, size),
    })
    for key, value in props or {} do image[key] = value end
    local function Load()
        if image.Parent then ApplyIcon(image, name) end
    end
    if LucideIcons then
        task.defer(Load)
    elseif IconWaiters then
        table.insert(IconWaiters, function() task.defer(Load) end)
    end
    return image
end

local function SetIcon(image, name)
    if not ApplyIcon(image, name) and IconWaiters then
        table.insert(IconWaiters, function() ApplyIcon(image, name) end)
    end
end

for _, name in { "NobulemKeySystem", "ObsidianKeySystem", "ObsidianKeyNotification" } do
    for _, parent in { CoreGui, gethui() } do
        local existing = parent:FindFirstChild(name)
        if existing then pcall(existing.Destroy, existing) end
    end
end

local Gui = nil
local ToastArea = nil

local function EnsureGui()
    if Gui and Gui.Parent then return Gui end
    Gui = New("ScreenGui", {
        Name = "NobulemKeySystem",
        DisplayOrder = 999,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local parented = pcall(function()
        pcall(protectgui, Gui)
        Gui.Parent = gethui()
    end)
    if not (parented and Gui.Parent) then
        Gui.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge)
    end
    ToastArea = New("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, IsMobile and 270 or 310, 1, -32),
        ZIndex = 50,
        Parent = Gui,
    }, {
        List(8, nil, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom),
    })
    return Gui
end

local function DestroyGui()
    if Gui then pcall(Gui.Destroy, Gui) end
    Gui, ToastArea = nil, nil
end

local ToastIcons = { info = "info", loading = "loader-circle", success = "circle-check", error = "circle-alert" }
local ToastOrder = 0

local function Toast(opts)
    EnsureGui()
    ToastOrder += 1
    local kind = opts.Kind or "info"
    local color = kind == "info" and Theme.Accent or StatusColors[kind]

    local wrapper = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = ToastOrder,
        Size = UDim2.fromScale(1, 0),
        Parent = ToastArea,
    })
    local card = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel,
        Position = UDim2.fromOffset(340, 0),
        Size = UDim2.fromScale(1, 0),
        Parent = wrapper,
    }, {
        Corner(10),
        Stroke(Theme.Stroke),
        Padding(12, 14, 14, 14),
    })
    local icon = Icon(ToastIcons[kind], 18, color, { Position = UDim2.fromOffset(0, 1), Parent = card })
    local body = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.new(1, -28, 0, 0),
        Parent = card,
    }, { List(3) })
    local title = Label({
        AutomaticSize = Enum.AutomaticSize.Y,
        FontFace = Fonts.Semibold,
        LayoutOrder = 1,
        Size = UDim2.fromScale(1, 0),
        Text = opts.Title or config.Title,
        TextSize = 15,
        TextWrapped = true,
        Parent = body,
    })
    local text = Label({
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        Size = UDim2.fromScale(1, 0),
        Text = opts.Body or "",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextWrapped = true,
        Visible = (opts.Body or "") ~= "",
        Parent = body,
    })
    local actionButton = New("TextButton", {
        AutoButtonColor = false,
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Accent,
        FontFace = Fonts.Semibold,
        LayoutOrder = 3,
        Size = UDim2.fromOffset(0, 28),
        Text = "",
        TextColor3 = Theme.White,
        TextSize = 13,
        Visible = false,
        Parent = body,
    }, { Corner(7), Padding(0, 12) })
    local progressTrack = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.new(0, -4, 1, 9),
        Size = UDim2.new(1, 8, 0, 2),
        Parent = card,
    })
    local progress = New("Frame", {
        BackgroundColor3 = color,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = progressTrack,
    })

    local handle = {}
    local closed = false
    local spin = nil
    local actionCallback = nil
    local lifetime = 0

    actionButton.MouseEnter:Connect(function() Tween(actionButton, Fast, { BackgroundColor3 = Theme.AccentHover }) end)
    actionButton.MouseLeave:Connect(function() Tween(actionButton, Fast, { BackgroundColor3 = Theme.Accent }) end)
    actionButton.Activated:Connect(function()
        if actionCallback then actionCallback() end
    end)

    function handle.Close()
        if closed then return end
        closed = true
        if spin then spin:Disconnect() end
        Tween(card, Smooth, { Position = UDim2.fromOffset(340, 0) })
        task.delay(0.3, function() wrapper:Destroy() end)
    end

    function handle.Update(update)
        if closed then return end
        kind = update.Kind or kind
        color = kind == "info" and Theme.Accent or StatusColors[kind]
        title.Text = update.Title or title.Text
        if update.Body then
            text.Text = update.Body
            text.Visible = update.Body ~= ""
        end
        icon.ImageColor3 = color
        icon.Rotation = 0
        SetIcon(icon, ToastIcons[kind])
        progress.BackgroundColor3 = color
        if spin then spin:Disconnect(); spin = nil end
        if kind == "loading" then
            spin = RunService.RenderStepped:Connect(function(dt)
                icon.Rotation = (icon.Rotation + dt * 360) % 360
            end)
        end
        actionCallback = update.Action and update.Action.Callback
        actionButton.Visible = update.Action ~= nil
        if update.Action then actionButton.Text = update.Action.Text end

        lifetime += 1
        local thisLife = lifetime
        local duration = update.Duration
        progressTrack.Visible = duration ~= nil and duration > 0
        if progressTrack.Visible then
            progress.Size = UDim2.fromScale(1, 1)
            Tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
            task.delay(duration, function()
                if lifetime == thisLife then handle.Close() end
            end)
        end
    end

    handle.Update({
        Kind = kind,
        Action = opts.Action,
        Duration = opts.Duration == nil and 5 or opts.Duration,
    })
    Tween(card, Pop, { Position = UDim2.fromOffset(0, 0) })
    return handle
end

local function CopyText(value, title, body)
    if setclipboard and pcall(setclipboard, value) then
        Toast({ Title = title, Body = body, Kind = "success", Duration = 5 })
        return true
    end
    Toast({ Title = title, Body = "Your executor can't copy - here it is:\n" .. value, Kind = "info", Duration = 12 })
    return false
end

local function CopyCheckout()
    CopyText(config.BuyUrl, "Checkout link copied", "Paste it in your browser to go keyless for " .. config.LifetimePrice .. ".")
end

local WINDOW_W, WINDOW_H = 680, 430
local SIDE_W = 248
local TOUCH_ICON = IsMobile and 38 or 30

local Window = nil
local State = { busy = false, accepted = false }

local OpenWindow

local function StartScript(key, sdk)
    SetKeyGlobals(key)
    local function Run()
        DestroyGui()
        getgenv().NobulemKeySystemClosed = true
        task.wait()
        sdk.script_id = config.LuarmorScriptId
        local ok, err = pcall(sdk.load_script)
        if not ok then
            ClearKeyGlobals()
            State.accepted = false
            warn("[nobulem.wtf] Luarmor loader: " .. tostring(err))
            OpenWindow({ Prefill = key, Status = { "error", "The script failed to start. Press Unlock to try again." } })
        end
    end
    if Window then
        Window.Close(Run)
    else
        Run()
    end
end

local function Button(opts)
    local variant = opts.Variant or "secondary"
    local palette = ({
        primary = { Theme.Accent, Theme.AccentHover, Theme.White, nil },
        secondary = { Theme.Surface, Theme.SurfaceHover, Theme.Text, Theme.Stroke },
        ghost = { Theme.Window, Theme.Surface, Theme.Muted, nil },
    })[variant]

    local button = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = palette[1],
        BackgroundTransparency = variant == "ghost" and 1 or 0,
        LayoutOrder = opts.LayoutOrder or 0,
        Size = opts.Size or UDim2.new(1, 0, 0, 36),
        Text = "",
        Parent = opts.Parent,
    }, {
        Corner(opts.Radius or 8),
        List(7, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
    })
    if palette[4] then Stroke(palette[4]).Parent = button end
    local scale = New("UIScale", { Parent = button })

    local icon = nil
    if opts.Icon then
        icon = Icon(opts.Icon, opts.IconSize or 15, palette[3], { LayoutOrder = 1, Parent = button })
    end
    local label = Label({
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = variant == "primary" and Fonts.Bold or Fonts.Semibold,
        LayoutOrder = 2,
        Size = UDim2.fromScale(0, 1),
        Text = opts.Text or "",
        TextColor3 = palette[3],
        TextSize = opts.TextSize or 14,
        Parent = button,
    })
    if opts.IconRight then
        icon = icon or Icon(opts.IconRight, opts.IconSize or 14, palette[3], { LayoutOrder = 3, ImageTransparency = 0.3, Parent = button })
    end

    local enabled = true
    local hovered = false
    local function Refresh()
        local background = hovered and enabled and palette[2] or palette[1]
        Tween(button, Fast, {
            BackgroundColor3 = background,
            BackgroundTransparency = variant == "ghost" and (hovered and enabled and 0 or 1) or (enabled and 0 or 0.35),
        })
        Tween(label, Fast, { TextTransparency = enabled and 0 or 0.45 })
    end
    button.MouseEnter:Connect(function() hovered = true; Refresh() end)
    button.MouseLeave:Connect(function() hovered = false; Refresh(); Tween(scale, Fast, { Scale = 1 }) end)
    button.MouseButton1Down:Connect(function() if enabled then Tween(scale, Fast, { Scale = 0.97 }) end end)
    button.MouseButton1Up:Connect(function() Tween(scale, Fast, { Scale = 1 }) end)

    local controller = { Instance = button, Label = label, Icon = icon }
    function controller.SetText(text) label.Text = text end
    function controller.SetEnabled(state)
        enabled = state
        Refresh()
    end
    function controller.OnClick(callback)
        button.Activated:Connect(function()
            if enabled then callback() end
        end)
    end
    return controller
end

local function StepHeader(number, text, parent, order)
    local row = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 20),
        Parent = parent,
    })
    New("Frame", {
        BackgroundColor3 = Theme.Raised,
        Size = UDim2.fromOffset(20, 20),
        Parent = row,
    }, {
        Corner(10),
        Label({
            FontFace = Fonts.Bold,
            Size = UDim2.fromScale(1, 1),
            Text = tostring(number),
            TextColor3 = Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
        }),
    })
    Label({
        FontFace = Fonts.Semibold,
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(0.6, -30, 1, 0),
        Text = text,
        TextSize = 15,
        Parent = row,
    })
    return Label({
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.4, 0, 1, 0),
        Text = "",
        TextColor3 = Theme.Dim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })
end

local function BuildSidebar(window)
    local side = New("Frame", {
        BackgroundColor3 = Theme.Panel,
        Size = UDim2.new(0, SIDE_W, 1, 0),
        Parent = window,
    }, {
        Corner(14),
        Padding(20, 18, 18, 18),
        New("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(Theme.Panel:Lerp(Theme.Accent, 0.07), Theme.Panel),
        }),
    })
    New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 18, 0, -20),
        Size = UDim2.new(0, 14, 1, 38),
        Parent = side,
    }, {
        New("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(Theme.Panel:Lerp(Theme.Accent, 0.07), Theme.Panel),
        }),
    })
    New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 18, 0, -20),
        Size = UDim2.new(0, 1, 1, 38),
        Parent = side,
    })

    New("ImageLabel", {
        BackgroundTransparency = 1,
        Image = config.Logo,
        Size = UDim2.fromOffset(30, 30),
        Parent = side,
    })
    Label({
        FontFace = Fonts.Bold,
        Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -40, 0, 18),
        Text = ("nobulem<font color=\"%s\">.wtf</font>"):format(Hex(Theme.Accent)),
        TextSize = 19,
        Parent = side,
    })
    Label({
        Position = UDim2.fromOffset(40, 18),
        Size = UDim2.new(1, -40, 0, 14),
        Text = GameName,
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = side,
    })

    local offer = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        Position = UDim2.fromOffset(0, 54),
        Size = UDim2.fromScale(1, 0),
        Parent = side,
    }, {
        Corner(12),
        Stroke(Theme.Accent, 0.55),
        Padding(14),
        List(10),
    })
    local tag = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.82,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 20),
        Parent = offer,
    }, {
        Corner(6),
        Padding(0, 8),
        List(5, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center),
    })
    Icon("sparkles", 12, Theme.AccentHover, { LayoutOrder = 1, Parent = tag })
    Label({
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = Fonts.Bold,
        LayoutOrder = 2,
        Size = UDim2.fromScale(0, 1),
        Text = "LIFETIME",
        TextColor3 = Theme.AccentHover,
        TextSize = 11,
        Parent = tag,
    })
    Label({
        FontFace = Fonts.Bold,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 30),
        Text = ("%s <font size=\"14\" color=\"%s\" weight=\"regular\">one time</font>"):format(config.LifetimePrice, Hex(Theme.Muted)),
        TextSize = 30,
        Parent = offer,
    })
    local perks = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Size = UDim2.fromScale(1, 0),
        Parent = offer,
    }, { List(7) })
    for index, perk in { "No keys or links, ever", "Every current & future script", "Priority updates & support" } do
        local row = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = index,
            Size = UDim2.new(1, 0, 0, 16),
            Parent = perks,
        })
        Icon("check", 14, Theme.Success, { Position = UDim2.fromOffset(0, 1), Parent = row })
        Label({
            Position = UDim2.fromOffset(22, 0),
            Size = UDim2.new(1, -22, 1, 0),
            Text = perk,
            TextColor3 = Theme.Text,
            TextSize = 13,
            Parent = row,
        })
    end
    local buy = Button({
        Parent = offer,
        LayoutOrder = 4,
        Variant = "primary",
        Text = "Go keyless",
        IconRight = "arrow-right",
        Size = UDim2.new(1, 0, 0, 36),
    })
    buy.OnClick(CopyCheckout)
    Label({
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 5,
        Size = UDim2.fromScale(1, 0),
        Text = UsageLine(),
        TextColor3 = Theme.Dim,
        TextSize = 12,
        TextWrapped = true,
        Parent = offer,
    })

    local plans = New("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 2, 1, -50),
        Size = UDim2.new(1, -4, 0, 16),
        Text = "",
        Parent = side,
    })
    local plansLabel = Label({
        Size = UDim2.new(1, -18, 1, 0),
        Text = ("Or go weekly from <font color=\"%s\">%s</font>"):format(Hex(Theme.Text), config.WeeklyPrice),
        TextColor3 = Theme.Muted,
        TextSize = 13,
        Parent = plans,
    })
    local plansArrow = Icon("arrow-up-right", 14, Theme.Muted, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Parent = plans,
    })
    plans.MouseEnter:Connect(function()
        Tween(plansLabel, Fast, { TextColor3 = Theme.Text })
        Tween(plansArrow, Fast, { ImageColor3 = Theme.AccentHover })
    end)
    plans.MouseLeave:Connect(function()
        Tween(plansLabel, Fast, { TextColor3 = Theme.Muted })
        Tween(plansArrow, Fast, { ImageColor3 = Theme.Muted })
    end)
    plans.Activated:Connect(function()
        CopyText(config.BuyUrl, "Pricing link copied", "Weekly, monthly, 3-month and lifetime plans are all there.")
    end)
    New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -44),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = side,
    })

    local user = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 34),
        Parent = side,
    })
    local avatar = New("ImageLabel", {
        BackgroundColor3 = Theme.Raised,
        Size = UDim2.fromOffset(34, 34),
        Parent = user,
    }, { Corner(17) })
    task.spawn(function()
        local ok, image = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        if ok and avatar.Parent then avatar.Image = image end
    end)
    Label({
        FontFace = Fonts.Semibold,
        Position = UDim2.fromOffset(44, 0),
        Size = UDim2.new(1, -80, 0, 18),
        Text = LocalPlayer.DisplayName,
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = user,
    })
    Label({
        Position = UDim2.fromOffset(44, 18),
        Size = UDim2.new(1, -80, 0, 14),
        Text = GetExecutorName() .. "  ·  " .. GetDeviceType(),
        TextColor3 = Theme.Dim,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = user,
    })
    local hwid = Button({
        Parent = user,
        Variant = "ghost",
        Icon = "fingerprint",
        IconSize = 16,
        Size = UDim2.fromOffset(TOUCH_ICON, TOUCH_ICON),
    })
    hwid.Instance.AnchorPoint = Vector2.new(1, 0.5)
    hwid.Instance.Position = UDim2.fromScale(1, 0.5)
    hwid.Label.Visible = false
    hwid.OnClick(function()
        CopyText(GetHWID(), "HWID copied", "Send it to support if you need a key reset.")
    end)
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

    local root = New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Window,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
        Parent = Gui,
    }, {
        Corner(14),
        Stroke(Theme.StrokeStrong, 0.2),
    })
    local scale = New("UIScale", { Scale = 0.92, Parent = root })
    local fit = 1
    local function Fit()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local inset = Service("GuiService"):GetGuiInset().Y
        local function FitFor(topSpace)
            return math.clamp(math.min((viewport.X - 24) / WINDOW_W, (viewport.Y - topSpace - 16) / WINDOW_H, 1), 0.5, 1)
        end
        fit = FitFor(0)
        local clearsCorners = (viewport.X - WINDOW_W * fit) / 2 >= 120
        if not clearsCorners then fit = FitFor(inset) end
        scale.Scale = fit
        if root.Position.X.Scale == 0.5 then
            root.Position = UDim2.new(0.5, 0, 0.5, clearsCorners and 0 or inset / 2)
        end
    end
    Fit()
    if Workspace.CurrentCamera then
        Track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit))
    end
    scale.Scale = fit * 0.94
    Tween(scale, Pop, { Scale = fit })

    BuildSidebar(root)

    local main = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(SIDE_W, 0),
        Size = UDim2.new(1, -SIDE_W, 1, 0),
        Parent = root,
    }, { Padding(22, 26, 18, 28) })

    do
        local handle = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 64),
            ZIndex = 0,
            Parent = root,
        })
        local dragStart, startPos, dragInput
        Track(handle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragStart, startPos, dragInput = input.Position, root.Position, input
        end))
        Track(UserInputService.InputChanged:Connect(function(input)
            if not dragStart then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= dragInput then return end
            local delta = input.Position - dragStart
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
            local halfW, halfH = WINDOW_W * fit / 2, WINDOW_H * fit / 2
            local x = math.clamp(viewport.X * startPos.X.Scale + startPos.X.Offset + delta.X, halfW - 40, viewport.X - halfW + 40)
            local y = math.clamp(viewport.Y * startPos.Y.Scale + startPos.Y.Offset + delta.Y, halfH - 20, viewport.Y - halfH + 20)
            root.Position = UDim2.fromOffset(x, y)
        end))
        Track(UserInputService.InputEnded:Connect(function(input)
            if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragStart, dragInput = nil, nil
            end
        end))
    end

    local close = Button({
        Parent = main,
        Variant = "ghost",
        Icon = "x",
        IconSize = 18,
        Size = UDim2.fromOffset(TOUCH_ICON, TOUCH_ICON),
    })
    close.Label.Visible = false
    close.Instance.AnchorPoint = Vector2.new(1, 0)
    close.Instance.Position = UDim2.new(1, 6, 0, -4)
    close.Instance.ZIndex = 5

    local auth = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = main,
    }, { List(0) })

    local function Gap(height, order)
        return New("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Parent = auth })
    end

    Label({
        FontFace = Fonts.Bold,
        LayoutOrder = 1,
        Size = UDim2.new(1, -40, 0, 26),
        Text = "Unlock " .. GameName,
        TextSize = 24,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = auth,
    })
    Gap(4, 2)
    Label({
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 16),
        Text = "Grab a free key, or paste one you already have.",
        TextColor3 = Theme.Muted,
        TextSize = 14,
        Parent = auth,
    })
    Gap(22, 4)

    local providerHint = StepHeader(1, "Get a free key", auth, 5)
    Gap(10, 6)

    local hours = 12
    local segment = New("Frame", {
        BackgroundColor3 = Theme.Surface,
        LayoutOrder = 7,
        Size = UDim2.new(1, 0, 0, 34),
        Parent = auth,
    }, { Corner(9), Stroke(Theme.Stroke) })
    local indicator = New("Frame", {
        BackgroundColor3 = Theme.Raised,
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.new(0.5, -3, 1, -6),
        Parent = segment,
    }, { Corner(7), Stroke(Theme.Accent, 0.5) })
    local segmentLabels = {}

    Gap(8, 8)
    local providerRow = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 9,
        Size = UDim2.new(1, 0, 0, 36),
        Parent = auth,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local providerButtons = {}
    local SetStatus

    local function RenderProviders()
        for _, existing in providerButtons do existing.Instance:Destroy() end
        table.clear(providerButtons)
        for index, provider in config.Links[hours] do
            local button = Button({
                Parent = providerRow,
                LayoutOrder = index,
                Text = provider.Name,
                IconRight = "external-link",
                IconSize = 13,
                Size = UDim2.fromScale(0, 1),
            })
            button.OnClick(function()
                if type(provider.Url) ~= "string" or not provider.Url:match("^https://") then
                    Toast({ Title = "Link not set up", Body = "This key link is missing from the loader config.", Kind = "error" })
                    return
                end
                CopyText(provider.Url, provider.Name .. " link copied", ("Open it in your browser - your %d-hour key appears at the end."):format(hours))
                SetStatus("info", ("Finish the %s steps, then paste your key here."):format(provider.Name))
            end)
            table.insert(providerButtons, button)
        end
        local names = {}
        for _, provider in config.Links[hours] do table.insert(names, provider.Name) end
        providerHint.Text = table.concat(names, " or ")
    end

    local function SelectHours(value)
        hours = value
        Tween(indicator, Smooth, { Position = value == 12 and UDim2.fromOffset(3, 3) or UDim2.new(0.5, 0, 0, 3) })
        for option, label in segmentLabels do
            Tween(label, Fast, { TextColor3 = option == value and Theme.Text or Theme.Muted })
        end
        RenderProviders()
    end

    for index, value in { 12, 24 } do
        local option = New("TextButton", {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale((index - 1) * 0.5, 0),
            Size = UDim2.fromScale(0.5, 1),
            Text = "",
            ZIndex = 2,
            Parent = segment,
        })
        segmentLabels[value] = Label({
            FontFace = Fonts.Semibold,
            Size = UDim2.fromScale(1, 1),
            Text = ("%d hours"):format(value),
            TextColor3 = value == hours and Theme.Text or Theme.Muted,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 2,
            Parent = option,
        })
        option.Activated:Connect(function() SelectHours(value) end)
    end
    RenderProviders()

    Gap(24, 10)

    local counter = StepHeader(2, "Paste your key", auth, 11)
    Gap(10, 12)

    local field = New("Frame", {
        BackgroundColor3 = Theme.Surface,
        LayoutOrder = 13,
        Size = UDim2.new(1, 0, 0, 44),
        Parent = auth,
    }, { Corner(9) })
    local fieldStroke = Stroke(Theme.Stroke)
    fieldStroke.Parent = field
    Icon("key-round", 16, Theme.Dim, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Parent = field })
    local input = New("TextBox", {
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        FontFace = Fonts.Mono,
        PlaceholderColor3 = Theme.Dim,
        PlaceholderText = "32-letter key",
        Position = UDim2.fromOffset(40, 0),
        Size = UDim2.new(1, -86, 1, 0),
        Text = "",
        TextColor3 = Theme.Text,
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = field,
    })
    local paste = Button({
        Parent = field,
        Variant = "secondary",
        Icon = "clipboard-paste",
        IconSize = 15,
        Size = UDim2.fromOffset(IsMobile and 40 or 34, 32),
        Radius = 7,
    })
    paste.Label.Visible = false
    paste.Instance.AnchorPoint = Vector2.new(1, 0.5)
    paste.Instance.Position = UDim2.new(1, -6, 0.5, 0)

    Gap(8, 14)
    local statusRow = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 15,
        Size = UDim2.new(1, 0, 0, 16),
        Parent = auth,
    })
    local statusDot = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Dim,
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(6, 6),
        Parent = statusRow,
    }, { Corner(3) })
    local statusLabel = Label({
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -14, 1, 0),
        Text = "",
        TextColor3 = Theme.Dim,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = statusRow,
    })

    Gap(14, 16)
    local unlock = Button({
        Parent = auth,
        LayoutOrder = 17,
        Variant = "primary",
        Text = "Unlock",
        Icon = "lock-open",
        IconSize = 16,
        TextSize = 15,
        Size = UDim2.new(1, 0, 0, 42),
        Radius = 9,
    })

    local statusKind = "idle"
    local statusKey = nil
    SetStatus = function(kind, text)
        statusKind = kind
        statusKey = ExtractKey(input.Text)
        local color = StatusColors[kind] or Theme.Dim
        statusLabel.Text = text
        Tween(statusLabel, Fast, { TextColor3 = kind == "idle" and Theme.Dim or color })
        Tween(statusDot, Fast, { BackgroundColor3 = color })
        Tween(fieldStroke, Fast, {
            Color = (kind == "error" or kind == "success") and color or Theme.Stroke,
            Transparency = (kind == "error" or kind == "success") and 0.25 or 0,
        })
    end

    local function UpdateCounter()
        local letters = select(2, ExtractKey(input.Text):gsub("%a", ""))
        local valid = IsValidKeyFormat(ExtractKey(input.Text))
        counter.Text = ("%d / 32"):format(math.min(letters, 99))
        counter.TextColor3 = valid and Theme.Success or (letters > 32 and Theme.Error or Theme.Dim)
    end

    local spinner = nil
    local function SetBusy(busy)
        State.busy = busy
        unlock.SetEnabled(not busy)
        paste.SetEnabled(not busy)
        input.TextEditable = not busy
        unlock.SetText(busy and "Checking key..." or "Unlock")
        if unlock.Icon then
            SetIcon(unlock.Icon, busy and "loader-circle" or "lock-open")
            unlock.Icon.Rotation = 0
        end
        if spinner then spinner:Disconnect(); spinner = nil end
        if busy and unlock.Icon then
            spinner = Track(RunService.RenderStepped:Connect(function(dt)
                unlock.Icon.Rotation = (unlock.Icon.Rotation + dt * 420) % 360
            end))
        end
    end

    local function Shake()
        local base = root.Position
        task.spawn(function()
            for _, offset in { 8, -7, 5, -3, 0 } do
                Tween(root, TweenInfo.new(0.05), { Position = base + UDim2.fromOffset(offset, 0) }).Completed:Wait()
            end
        end)
    end

    local footer = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 18),
        Parent = main,
    })
    local discord = New("TextButton", {
        AutoButtonColor = false,
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(0, 1),
        Text = "",
        Parent = footer,
    }, { List(6, Enum.FillDirection.Horizontal, nil, Enum.VerticalAlignment.Center) })
    Icon("message-circle", 14, Theme.Muted, { LayoutOrder = 1, Parent = discord })
    local discordLabel = Label({
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        Size = UDim2.fromScale(0, 1),
        Text = "Need help? Join the Discord",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        Parent = discord,
    })
    discord.MouseEnter:Connect(function() Tween(discordLabel, Fast, { TextColor3 = Theme.Text }) end)
    discord.MouseLeave:Connect(function() Tween(discordLabel, Fast, { TextColor3 = Theme.Muted }) end)
    discord.Activated:Connect(function()
        CopyText(config.DiscordInvite, "Discord invite copied", "Paste it in your browser or Discord to join.")
    end)
    local secured = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromScale(0, 1),
        Parent = footer,
    }, { List(5, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
    Icon("shield-check", 13, Theme.Dim, { LayoutOrder = 1, Parent = secured })
    Label({
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 2,
        Size = UDim2.fromScale(0, 1),
        Text = "Secured by Luarmor",
        TextColor3 = Theme.Dim,
        TextSize = 12,
        Parent = secured,
    })

    local success = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, 0, 1, -24),
        Visible = false,
        Parent = main,
    }, { List(0, nil, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })

    local controller = {}
    local closing = false

    local function Destroy()
        for _, connection in connections do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(connections)
        if root.Parent then root:Destroy() end
        if Window == controller then Window = nil end
    end

    function controller.Close(callback)
        if closing then return end
        closing = true
        Tween(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
        task.delay(0.23, function()
            Destroy()
            if callback then callback() end
        end)
    end

    function controller.ShowSuccess(info)
        auth.Visible = false
        footer.Visible = false
        close.Instance.Visible = false
        success.Visible = true
        Tween(success, Smooth, { Position = UDim2.fromOffset(0, 0) })

        local badge = New("Frame", {
            BackgroundColor3 = Theme.Success,
            BackgroundTransparency = 0.86,
            LayoutOrder = 1,
            Size = UDim2.fromOffset(52, 52),
            Parent = success,
        }, { Corner(26) })
        local check = Icon("check", 26, Theme.Success, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(4, 4),
            Parent = badge,
        })
        Tween(check, Pop, { Size = UDim2.fromOffset(26, 26) })
        New("Frame", { BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), Parent = success })
        Label({
            FontFace = Fonts.Bold,
            LayoutOrder = 3,
            Size = UDim2.new(1, 0, 0, 28),
            Text = "You're in.",
            TextSize = 26,
            Parent = success,
        })
        local detail = ("Starting %s now."):format(GameName)
        if info.ExpiresAt and not info.Lifetime then
            detail ..= (" Your key is good for another <font color=\"%s\">%s</font>."):format(
                Hex(Theme.Text), FormatDuration(info.ExpiresAt - os.time()))
        elseif info.Lifetime then
            detail ..= " Lifetime key - you won't see this screen again."
        end
        Label({
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            Size = UDim2.fromScale(1, 0),
            Text = detail,
            TextColor3 = Theme.Muted,
            TextSize = 14,
            TextWrapped = true,
            Parent = success,
        })

        local finished = false
        local function Continue()
            if finished then return end
            finished = true
            info.OnContinue()
        end

        if info.Lifetime or not config.ShowPremiumPopup then
            task.delay(1.1, Continue)
            return
        end

        New("Frame", { BackgroundTransparency = 1, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 22), Parent = success })
        local cardFrame = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Surface,
            LayoutOrder = 6,
            Size = UDim2.fromScale(1, 0),
            Parent = success,
        }, { Corner(12), Stroke(Theme.Accent, 0.55) })
        local card = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            Parent = cardFrame,
        }, { Padding(16, 16, 20, 16), List(6) })
        Label({
            FontFace = Fonts.Semibold,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "Make this your last key",
            TextSize = 16,
            Parent = card,
        })
        Label({
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
            Size = UDim2.fromScale(1, 0),
            Text = ("Free keys run out. Lifetime is <font color=\"%s\"><b>%s once</b></font> - no links, every script, forever.")
                :format(Hex(Theme.Text), config.LifetimePrice),
            TextColor3 = Theme.Muted,
            TextSize = 13,
            TextWrapped = true,
            Parent = card,
        })
        New("Frame", { BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 6), Parent = card })
        local actions = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = 4,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = card,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
        local buy = Button({
            Parent = actions,
            LayoutOrder = 1,
            Variant = "primary",
            Text = "Go keyless - " .. config.LifetimePrice,
            Size = UDim2.fromScale(0, 1),
        })
        local skip = Button({
            Parent = actions,
            LayoutOrder = 2,
            Text = "Continue",
            Size = UDim2.fromScale(0, 1),
        })
        local track = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 16, 1, -8),
            Size = UDim2.new(1, -32, 0, 3),
            Parent = cardFrame,
        }, { Corner(2) })
        Tween(track, TweenInfo.new(config.UpsellSeconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) })

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
            SetStatus("error", "That doesn't look like a key - they're exactly 32 letters.")
            Shake()
            return
        end
        if input.Text ~= key then input.Text = key end
        SetBusy(true)
        SetStatus("loading", "Checking your key with Luarmor...")
        task.spawn(function()
            local result = CheckKey(key)
            if Window ~= controller then return end
            if not result.ok then
                SetBusy(false)
                ClearKeyGlobals()
                if result.kind == "dead" then ForgetSavedKey() end
                SetStatus("error", result.message)
                Shake()
                return
            end

            State.accepted = true
            SetBusy(false)
            SetStatus("success", "Key accepted.")
            SaveKey(key)
            local lifetime = IsLifetimeKey(key, result.expiresAt)
            if NoteKeyInUse(key) and not lifetime then CountCheckpoint() end
            task.wait(0.35)
            if Window ~= controller then return end
            controller.ShowSuccess({
                Lifetime = lifetime,
                ExpiresAt = result.expiresAt,
                OnContinue = function() StartScript(key, result.sdk) end,
            })
        end)
    end

    close.OnClick(function()
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
            SetStatus("error", IsMobile and "Your executor can't read the clipboard - hold the key box to paste."
                or "Your executor can't read the clipboard - paste with Ctrl+V.")
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

    local lastAuto = nil
    Track(input:GetPropertyChangedSignal("Text"):Connect(function()
        UpdateCounter()
        if State.busy then return end
        local key = ExtractKey(input.Text)
        if statusKind == "error" and key ~= statusKey then SetStatus("idle", "Your key is saved on this device once it works.") end
        if IsValidKeyFormat(key) and key ~= lastAuto then
            lastAuto = key
            task.delay(0.25, function()
                if Window == controller and ExtractKey(input.Text) == key then Submit(key) end
            end)
        end
    end))
    Track(input.Focused:Connect(function()
        if statusKind ~= "error" and statusKind ~= "success" then
            Tween(fieldStroke, Fast, { Color = Theme.Accent, Transparency = 0.2 })
        end
    end))
    Track(input.FocusLost:Connect(function(enter)
        if statusKind ~= "error" and statusKind ~= "success" then
            Tween(fieldStroke, Fast, { Color = Theme.Stroke, Transparency = 0 })
        end
        if enter then Submit(input.Text) end
    end))

    SetStatus("idle", "Your key is saved on this device once it works.")
    if opts.Prefill then
        lastAuto = ExtractKey(opts.Prefill)
        input.Text = opts.Prefill
    end
    UpdateCounter()
    if opts.Status then SetStatus(opts.Status[1], opts.Status[2]) end
    return controller
end

local savedKey = LoadSavedKey()
if savedKey and IsValidKeyFormat(savedKey) then
    local toast = Toast({ Title = "Checking saved key", Body = GameName, Kind = "loading", Duration = 0 })
    local result = CheckKey(savedKey)
    if result.ok then
        State.accepted = true
        local lifetime = IsLifetimeKey(savedKey, result.expiresAt)
        NoteKeyInUse(savedKey)
        if config.ShowPremiumPopup and not lifetime then
            toast.Update({
                Title = "Saved key accepted",
                Body = ("Starting %s. %s"):format(GameName, UsageLine()),
                Kind = "success",
                Duration = config.PreloadNudgeSeconds,
                Action = { Text = "Go keyless - " .. config.LifetimePrice, Callback = CopyCheckout },
            })
            task.wait(config.PreloadNudgeSeconds)
        else
            toast.Update({ Title = "Welcome back", Body = "Starting " .. GameName .. ".", Kind = "success", Duration = 1.2 })
            task.wait(0.8)
        end
        StartScript(savedKey, result.sdk)
        return
    end

    toast.Close()
    ClearKeyGlobals()
    if result.kind == "dead" then
        ForgetSavedKey()
        OpenWindow({ Status = { "error", result.message } })
    elseif result.kind == "transient" then
        OpenWindow({ Prefill = savedKey, Status = { "error", result.message .. " Press Unlock to retry." } })
    else
        OpenWindow({ Prefill = savedKey, Status = { "error", result.message } })
    end
else
    OpenWindow()
end
