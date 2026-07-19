repeat task.wait() until game:IsLoaded()
local PassedLoaderConfig = ...
local LoaderConfig =
    (type(PassedLoaderConfig) == "table" and PassedLoaderConfig)
    or (getgenv and getgenv().NobulemLoaderConfig)
    or (_G and _G.NobulemLoaderConfig)
    or (type(shared) == "table" and shared.NobulemLoaderConfig)
    or {}
local wait = task.wait
local spawn = task.spawn
local CoreGui = cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local HttpService = cloneref(game:GetService("HttpService")) or game:GetService("HttpService")
local Players = cloneref(game:GetService("Players")) or game:GetService("Players")
local TweenService = cloneref(game:GetService("TweenService")) or game:GetService("TweenService")
local UserInputService = cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local RunService = cloneref(game:GetService("RunService")) or game:GetService("RunService")
local SoundService = cloneref(game:GetService("SoundService")) or game:GetService("SoundService")
local TextService = cloneref(game:GetService("TextService")) or game:GetService("TextService")
local Workspace = cloneref(game:GetService("Workspace")) or game:GetService("Workspace")
local getgenv = getgenv or function() return shared end
local setclipboard = setclipboard or nil
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function() return CoreGui end
local LucideIcons = nil
local IconReadyCallbacks = {}
task.spawn(function()
    local ok, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"))()
    end)
    if ok and result then
        LucideIcons = result
        for _, cb in IconReadyCallbacks do pcall(cb) end
    end
    IconReadyCallbacks = nil
end)
local function GetIcon(IconName)
    if not LucideIcons then return nil end
    local ok, icon = pcall(LucideIcons.GetAsset, IconName)
    if not ok then return nil end
    return icon
end
local function ApplyLucideIcon(imageLabel, iconName)
    local asset = GetIcon(iconName)
    if not asset or type(asset) ~= "table" then return false end
    imageLabel.Image = asset.Url or ("rbxassetid://" .. tostring(asset.Id or ""))
    imageLabel.ImageRectOffset = asset.ImageRectOffset or Vector2.zero
    imageLabel.ImageRectSize = asset.ImageRectSize or Vector2.zero
    return true
end
local function OnIconsReady(callback)
    if LucideIcons then
        pcall(callback)
    elseif IconReadyCallbacks then
        table.insert(IconReadyCallbacks, callback)
    end
end
local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
for _, name in {"ObsidianKeySystem", "ObsidianKeyNotification"} do
    if CoreGui:FindFirstChild(name) then
        CoreGui[name]:Destroy()
    end
end
if not LoaderConfig.LuaProtScriptId or LoaderConfig.LuaProtScriptId == "" then
    warn("[nobulem.wtf] keysystem.lua loaded without a LuaProt script ID - run loader.lua first")
    return
end
local config = {
    File = LoaderConfig.SaveFile or "nobulem_key.txt",
    Title = "nobulem.wtf",
    Version = LoaderConfig.GameName and (LoaderConfig.GameName .. " - Key system") or "Key system",
    Description = "Get your free key below to access the script.",
    LinkvertiseUrl = LoaderConfig.LinkvertiseUrl or "https://luaprot.net/ad/8734d1ba",
    WorkInkUrl = LoaderConfig.WorkInkUrl or "https://luaprot.net/ad/f77fb8ab",
    LuaProtScriptId = tostring(LoaderConfig.LuaProtScriptId),
    LuaProtSdkUrl = "https://sdk.luaprot.net/",
    Logo = "138831083704120",
    DiscordInvite = "https://discord.gg/nobulem",
    BuyUrl = "https://nobulem.wtf/pricing/",
    LifetimePrice = "$19.99",
    ShowPremiumPopup = LoaderConfig.ShowPremiumPopup ~= false,
    Prices = {
        { label = "Weekly",   price = "$3.50" },
        { label = "Monthly",  price = "$6.99" },
        { label = "3 Months", price = "$10.99" },
        { label = "Lifetime", price = "$19.99" },
    },
}
local Scheme = {
    BackgroundColor = Color3.fromRGB(15, 15, 15),
    MainColor = Color3.fromRGB(25, 25, 25),
    AccentColor = Color3.fromRGB(125, 85, 255),
    OutlineColor = Color3.fromRGB(40, 40, 40),
    FontColor = Color3.new(1, 1, 1),
    Font = Font.fromEnum(Enum.Font.Code),
    RedColor = Color3.fromRGB(255, 50, 50),
    DestructiveColor = Color3.fromRGB(220, 38, 38),
    DarkColor = Color3.new(0, 0, 0),
    WhiteColor = Color3.new(1, 1, 1),
    SuccessColor = Color3.fromRGB(80, 220, 120),
    WarningColor = Color3.fromRGB(255, 200, 60),
}
local CornerRadius = 4
local TweenInfoDefault = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfoSmooth = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfoSlow = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function GetBetterColor(Color, Add)
    Add = Add * 2
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end
local function GetDarkerColor(Color)
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, S, V / 2)
end
local function GetTextBounds(Text, FontFace, Size, Width)
    local Params = Instance.new("GetTextBoundsParams")
    Params.Text = Text
    Params.RichText = true
    Params.Font = FontFace
    Params.Size = Size
    Params.Width = Width or 999
    local Bounds = TextService:GetTextBoundsAsync(Params)
    return Bounds.X, Bounds.Y
end
local function New(ClassName, Properties)
    local Instance_ = Instance.new(ClassName)
    for k, v in Properties do
        Instance_[k] = v
    end
    return Instance_
end
local function AddOutline(Frame)
    local OutlineStroke = New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Thickness = 1,
        ZIndex = 2,
        Parent = Frame,
    })
    local ShadowStroke = New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.DarkColor,
        Thickness = 1.5,
        ZIndex = 1,
        Parent = Frame,
    })
    return OutlineStroke, ShadowStroke
end
local function AddCorner(Frame, Radius)
    return New("UICorner", {
        CornerRadius = UDim.new(0, Radius or CornerRadius),
        Parent = Frame,
    })
end
local function SafeParentUI(UI)
    local success = pcall(function()
        pcall(protectgui, UI)
        UI.Parent = gethui()
    end)
    if not (success and UI.Parent) then
        UI.Parent = plr:WaitForChild("PlayerGui", math.huge)
    end
end
local function DeleteFile(path)
    if isfile and isfile(path) then
        delfile(path)
    end
end
local function SaveKey(key)
    if not isfolder or not writefile then return end
    if not isfolder("kiwisense") then makefolder("kiwisense") end
    pcall(writefile, config.File, key)
end
local function LoadSavedKey()
    if not isfile then return nil end
    if isfile(config.File) then
        local ok, data = pcall(readfile, config.File)
        if ok and data and #data > 0 then
            return data
        end
    end
    return nil
end
local function IsValidKeyFormat(key)
    if type(key) ~= "string" then return false end
    local cleaned = key:gsub("%s", "")
    return cleaned ~= "" and #cleaned <= 256
end
local ScriptLoaded = false

local function ClearKeyGlobals()
    _G.ScriptKey = nil
    _G.script_key = nil
    getgenv().ScriptKey = nil
    getgenv().script_key = nil
    getgenv().Key = nil
end

local function CreateLuaProtSdk()
    local source = game:HttpGet(config.LuaProtSdkUrl)
    local chunk, compileErr = loadstring(source)
    if not chunk then error("SDK compile: " .. tostring(compileErr)) end
    local sdk = chunk()
    if type(sdk) ~= "table" then error("SDK returned an invalid value") end
    sdk.scriptId = config.LuaProtScriptId
    return sdk
end

local function ValidateKey(key)
    if not IsValidKeyFormat(key) then return false, "format" end

    local sdkOk, sdkOrErr = pcall(CreateLuaProtSdk)
    if not sdkOk then
        return false, "LuaProt SDK: " .. tostring(sdkOrErr)
    end

    local sdk = sdkOrErr
    local checkOk, result = pcall(function()
        return sdk:checkKey(key)
    end)
    if not checkOk then
        return false, "LuaProt key check: " .. tostring(result)
    end
    if type(result) ~= "table" then
        return false, "LuaProt returned an invalid key-check response"
    end
    if result.status ~= "VALID" then
        return false, tostring(result.message or result.status or "Invalid key")
    end

    return true, nil, sdk
end

local function ExecuteScript(key, sdk)
    _G.ScriptKey = key
    _G.script_key = key
    getgenv().ScriptKey = key
    getgenv().script_key = key
    getgenv().Key = key

    local loadOk, loadErr = pcall(function()
        sdk:loadScript()
    end)

    if not loadOk then
        ClearKeyGlobals()
        return false, "LuaProt loader: " .. tostring(loadErr)
    end
    return true, nil
end

local function TryExecuteWithKey(key)
    local ok, reason, sdk = ValidateKey(key)
    if not ok then return false, reason end
    return ExecuteScript(key, sdk)
end
local function GetHWID()
    local ok, id = pcall(function()
        if identifyexecutor then
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end
        return tostring(plr.UserId) .. "-" .. tostring(game.JobId):sub(1, 8)
    end)
    if ok and id then return tostring(id) end
    return "UNKNOWN"
end
local function GetExecutorName()
    local ok, name = pcall(function()
        if identifyexecutor then
            local n = identifyexecutor()
            if type(n) == "table" then return n[1] end
            return n
        end
        return "Unknown"
    end)
    if ok and name then return tostring(name) end
    return "Unknown"
end
local function GetDeviceType()
    if IsMobile then return "Mobile" end
    if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return "Console" end
    return "PC"
end
local function FormatTime()
    local t = os.date("*t")
    local hour = t.hour
    local suffix = "AM"
    if hour >= 12 then suffix = "PM" end
    if hour > 12 then hour = hour - 12 elseif hour == 0 then hour = 12 end
    return string.format("%d:%02d:%02d %s", hour, t.min, t.sec, suffix)
end
local function FormatDate()
    local months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    local t = os.date("*t")
    return string.format("%s %d, %d", months[t.month], t.day, t.year)
end
local NotifGui = New("ScreenGui", {
    Name = "ObsidianKeyNotification",
    DisplayOrder = 1002,
    ResetOnSpawn = false,
})
SafeParentUI(NotifGui)
local NotifArea = New("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -6, 0, 6),
    Size = UDim2.new(0, 300, 1, -6),
    Parent = NotifGui,
})
New("UIListLayout", {
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = NotifArea,
})
local function Notify(Title, Description, Duration, StatusColor)
    Duration = Duration or 5
    StatusColor = StatusColor or Scheme.AccentColor
    local FakeBackground = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        Visible = false,
        Parent = NotifArea,
    })
    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Scheme.MainColor,
        Position = UDim2.new(1, 8, 0, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 5,
        Parent = FakeBackground,
    })
    AddCorner(Holder)
    AddOutline(Holder)
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8),
        Parent = Holder,
    })
    local TitleLabel = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        FontFace = Scheme.Font,
        RichText = true,
        Size = UDim2.fromScale(1, 0),
        Text = Title or "",
        TextColor3 = StatusColor,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = Holder,
    })
    local DescLabel = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        FontFace = Scheme.Font,
        RichText = true,
        Size = UDim2.fromScale(1, 0),
        Text = Description or "",
        TextColor3 = Scheme.FontColor,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = Holder,
    })
    local TimerHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 7),
        ZIndex = 6,
        Parent = Holder,
    })
    local TimerBar = New("Frame", {
        BackgroundColor3 = Scheme.BackgroundColor,
        BorderColor3 = Scheme.OutlineColor,
        BorderSizePixel = 1,
        Position = UDim2.fromOffset(0, 3),
        Size = UDim2.new(1, 0, 0, 2),
        ZIndex = 6,
        Parent = TimerHolder,
    })
    local TimerFill = New("Frame", {
        BackgroundColor3 = StatusColor,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 7,
        Parent = TimerBar,
    })
    FakeBackground.Visible = true
    TweenService:Create(Holder, TweenInfoSmooth, { Position = UDim2.fromOffset(0, 0) }):Play()
    TweenService:Create(TimerFill, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
        Size = UDim2.fromScale(0, 1),
    }):Play()
    task.delay(Duration, function()
        TweenService:Create(Holder, TweenInfoSmooth, {
            Position = UDim2.new(1, 8, 0, 0),
        }):Play()
        task.delay(0.3, function()
            FakeBackground:Destroy()
        end)
    end)
end
local ScreenGui = nil
local MainFrame = nil
local StatusLabel = nil
local KeyTextBox = nil
local WINDOW_WIDTH = IsMobile and 530 or 655
local WINDOW_HEIGHT = 560
local CONTENT_RIGHT_PAD = IsMobile and 10 or 15
local SIDEBAR_WIDTH = 180
local function SetStatus(text, color)
    if StatusLabel then
        StatusLabel.Text = "Status: " .. text
        StatusLabel.TextColor3 = color or Scheme.WarningColor
    end
end
local function CloseUI()
    if not ScreenGui then return end
    TweenService:Create(MainFrame, TweenInfoSlow, {
        Size = UDim2.fromOffset(WINDOW_WIDTH, 0),
    }):Play()
    task.delay(0.4, function()
        if ScreenGui then
            ScreenGui:Destroy()
            ScreenGui = nil
        end
        if NotifGui then
            pcall(function() NotifGui:Destroy() end)
            NotifGui = nil
        end
    end)
end
local function HandleKeyObtained(key)
    if ScriptLoaded then return end
    if not IsValidKeyFormat(key) then
        Notify("Error", "Enter a valid LuaProt key.", 5, Scheme.RedColor)
        SetStatus("Invalid LuaProt key format", Scheme.RedColor)
        return
    end
    Notify(config.Title, "Checking LuaProt key...", 4, Scheme.AccentColor)
    SetStatus("Checking LuaProt...", Scheme.WarningColor)
    task.spawn(function()
        local success, reason = TryExecuteWithKey(key)
        if success then
            ScriptLoaded = true
            SaveKey(key)
            SetStatus("LuaProt loader started", Scheme.SuccessColor)
            CloseUI()
        else
            ClearKeyGlobals()
            DeleteFile(config.File)
            local msg = reason == "format" and "Invalid key format." or tostring(reason or "Unknown error")
            Notify("Error", msg, 8, Scheme.RedColor)
            SetStatus(msg, Scheme.RedColor)
        end
    end)
end
local function BuildUI()
    ScreenGui = New("ScreenGui", {
        Name = "ObsidianKeySystem",
        DisplayOrder = 999,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
    })
    SafeParentUI(ScreenGui)
    MainFrame = New("TextButton", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = GetBetterColor(Scheme.BackgroundColor, -1),
        ClipsDescendants = true,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WINDOW_WIDTH, 0),
        Text = "",
        Visible = true,
        Parent = ScreenGui,
    })
    AddCorner(MainFrame)
    AddOutline(MainFrame)
    local UiScale = New("UIScale", {
        Scale = 1,
        Parent = MainFrame,
    })
    local Camera = Workspace.CurrentCamera
    local function FitToViewport()
        if not Camera then return end
        local vp = Camera.ViewportSize
        local margin = 24
        local scaleX = (vp.X - margin) / WINDOW_WIDTH
        local scaleY = (vp.Y - margin) / WINDOW_HEIGHT
        UiScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.5, 1)
    end
    FitToViewport()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(FitToViewport)
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        ZIndex = 5,
        Parent = MainFrame,
    })
    New("Frame", {
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 5,
        Parent = MainFrame,
    })
    do
        local StartPos, FramePos, Dragging, Changed
        TopBar.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                StartPos = Input.Position
                FramePos = MainFrame.Position
                Dragging = true
                Changed = Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                        if Changed then Changed:Disconnect(); Changed = nil end
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(Input)
            if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
                local Delta = Input.Position - StartPos
                MainFrame.Position = UDim2.new(
                    FramePos.X.Scale, FramePos.X.Offset + Delta.X,
                    FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y
                )
            end
        end)
    end
    local TitleHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
        ZIndex = 5,
        Parent = TopBar,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = TitleHolder,
    })
    New("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxassetid://" .. config.Logo,
        ImageColor3 = Scheme.WhiteColor,
        Size = UDim2.fromOffset(26, 26),
        ZIndex = 5,
        Parent = TitleHolder,
    })
    local TitleX = GetTextBounds(config.Title, Scheme.Font, 20, SIDEBAR_WIDTH - 40)
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        RichText = true,
        Size = UDim2.new(0, TitleX, 1, 0),
        Text = config.Title,
        TextColor3 = Scheme.FontColor,
        TextSize = 20,
        ZIndex = 5,
        Parent = TitleHolder,
    })
    local RightInfo = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(1, -SIDEBAR_WIDTH - 24, 0, 24),
        ZIndex = 5,
        Parent = TopBar,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        Parent = RightInfo,
    })
    local VersionBadge = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Scheme.MainColor,
        Size = UDim2.fromOffset(0, 20),
        ZIndex = 5,
        Parent = RightInfo,
    })
    AddCorner(VersionBadge, CornerRadius / 2)
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = VersionBadge,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent = VersionBadge,
    })
    New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        Size = UDim2.fromScale(0, 1),
        Text = config.Version,
        TextColor3 = Scheme.FontColor,
        TextSize = 12,
        TextTransparency = 0.4,
        ZIndex = 5,
        Parent = VersionBadge,
    })
    local CloseBtn = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Scheme.MainColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(20, 20),
        Text = "×",
        FontFace = Scheme.Font,
        TextColor3 = Scheme.FontColor,
        TextSize = 18,
        TextTransparency = 0.4,
        ZIndex = 5,
        Parent = RightInfo,
    })
    AddCorner(CloseBtn, CornerRadius / 2)
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = CloseBtn,
    })
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfoDefault, { TextTransparency = 0, BackgroundColor3 = Scheme.RedColor }):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfoDefault, { TextTransparency = 0.4, BackgroundColor3 = Scheme.MainColor }):Play()
    end)
    CloseBtn.MouseButton1Click:Connect(CloseUI)
    New("Frame", {
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
        Size = UDim2.new(0, 1, 1, -21),
        ZIndex = 3,
        Parent = MainFrame,
    })
    local Sidebar = New("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Scheme.BackgroundColor,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromScale(0, 0),
        Position = UDim2.fromOffset(0, 49),
        ScrollBarThickness = 0,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -70),
        ZIndex = 3,
        Parent = MainFrame,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Sidebar,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8),
        Parent = Sidebar,
    })
    local UserGroupbox = New("Frame", {
        BackgroundColor3 = Scheme.BackgroundColor,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = Sidebar,
    })
    AddCorner(UserGroupbox)
    AddOutline(UserGroupbox)
    New("Frame", {
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = UserGroupbox,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        Position = UDim2.fromOffset(0, 0),
        RichText = true,
        Size = UDim2.new(1, 0, 0, 34),
        Text = "User Info",
        TextColor3 = Scheme.FontColor,
        TextSize = 15,
        ZIndex = 3,
        Parent = UserGroupbox,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = UserGroupbox:FindFirstChildOfClass("TextLabel"),
    })
    local UserContent = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 35),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = UserGroupbox,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = UserContent,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 7),
        Parent = UserContent,
    })
    local AvatarHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 50),
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = UserContent,
    })
    local AvatarFrame = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Scheme.MainColor,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(44, 44),
        ZIndex = 3,
        Parent = AvatarHolder,
    })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = AvatarFrame })
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.AccentColor,
        Thickness = 1.5,
        Parent = AvatarFrame,
    })
    local AvatarImage = New("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(1, -4, 1, -4),
        ZIndex = 4,
        Parent = AvatarFrame,
    })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = AvatarImage })
    pcall(function()
        AvatarImage.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    end)
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 2,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 14),
        Text = plr.Name,
        TextColor3 = Scheme.FontColor,
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
        Parent = UserContent,
    })
    local function AddInfoRow(label, value, order)
        local Row = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, 24),
            ZIndex = 3,
            Parent = UserContent,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            RichText = true,
            Size = UDim2.new(1, 0, 0, 10),
            Text = label,
            TextColor3 = Scheme.FontColor,
            TextSize = 10,
            TextTransparency = 0.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = Row,
        })
        local ValLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(0, 11),
            RichText = true,
            Size = UDim2.new(1, 0, 0, 13),
            Text = value,
            TextColor3 = Scheme.FontColor,
            TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = Row,
        })
        return ValLabel
    end
    AddInfoRow("EXECUTOR", GetExecutorName(), 3)
    AddInfoRow("DEVICE", GetDeviceType(), 4)
    do
        local hwidValue = GetHWID()
        local hwidHidden = true
        local maskedText = string.rep("*", math.min(#hwidValue, 12))
        local HwidRow = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = 5,
            Size = UDim2.new(1, 0, 0, 54),
            ZIndex = 3,
            Parent = UserContent,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            RichText = true,
            Size = UDim2.new(1, 0, 0, 10),
            Text = "HWID",
            TextColor3 = Scheme.FontColor,
            TextSize = 10,
            TextTransparency = 0.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = HwidRow,
        })
        local HwidBox = New("Frame", {
            BackgroundColor3 = Scheme.MainColor,
            Position = UDim2.fromOffset(0, 13),
            Size = UDim2.new(1, 0, 0, 38),
            ZIndex = 3,
            Parent = HwidRow,
        })
        AddCorner(HwidBox, 4)
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Scheme.OutlineColor,
            Parent = HwidBox,
        })
        local HwidLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(6, 0),
            Size = UDim2.new(1, -44, 1, 0),
            Text = maskedText,
            TextColor3 = Scheme.FontColor,
            TextSize = 10,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 4,
            Parent = HwidBox,
        })
        local EyeBtn = New("TextButton", {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -34, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            FontFace = Scheme.Font,
            Text = "o",
            TextColor3 = Scheme.FontColor,
            TextSize = 11,
            TextTransparency = 0.4,
            ZIndex = 5,
            Parent = HwidBox,
        })
        EyeBtn.MouseEnter:Connect(function()
            TweenService:Create(EyeBtn, TweenInfoDefault, { TextTransparency = 0 }):Play()
        end)
        EyeBtn.MouseLeave:Connect(function()
            TweenService:Create(EyeBtn, TweenInfoDefault, { TextTransparency = 0.4 }):Play()
        end)
        EyeBtn.MouseButton1Click:Connect(function()
            hwidHidden = not hwidHidden
            HwidLabel.Text = hwidHidden and maskedText or hwidValue
            EyeBtn.Text = hwidHidden and "o" or "x"
        end)
        local CopyBtn = New("TextButton", {
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            FontFace = Scheme.Font,
            Text = "c",
            TextColor3 = Scheme.FontColor,
            TextSize = 11,
            TextTransparency = 0.4,
            ZIndex = 5,
            Parent = HwidBox,
        })
        CopyBtn.MouseEnter:Connect(function()
            TweenService:Create(CopyBtn, TweenInfoDefault, { TextTransparency = 0 }):Play()
        end)
        CopyBtn.MouseLeave:Connect(function()
            TweenService:Create(CopyBtn, TweenInfoDefault, { TextTransparency = 0.4 }):Play()
        end)
        CopyBtn.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard(hwidValue)
            end
            Notify("Copied", "HWID copied to clipboard.", 3, Scheme.SuccessColor)
        end)
        OnIconsReady(function()
            local EyeIcon = New("ImageLabel", {
                BackgroundTransparency = 1,
                ImageColor3 = Scheme.FontColor,
                ImageTransparency = 0.4,
                Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 6,
                Parent = EyeBtn,
            })
            if ApplyLucideIcon(EyeIcon, "eye-off") then
                EyeBtn.Text = ""
                EyeBtn.MouseEnter:Connect(function()
                    TweenService:Create(EyeIcon, TweenInfoDefault, { ImageTransparency = 0 }):Play()
                end)
                EyeBtn.MouseLeave:Connect(function()
                    TweenService:Create(EyeIcon, TweenInfoDefault, { ImageTransparency = 0.4 }):Play()
                end)
                EyeBtn.MouseButton1Click:Connect(function()
                    ApplyLucideIcon(EyeIcon, hwidHidden and "eye-off" or "eye")
                end)
            else
                EyeIcon:Destroy()
            end
            local CopyIcon = New("ImageLabel", {
                BackgroundTransparency = 1,
                ImageColor3 = Scheme.FontColor,
                ImageTransparency = 0.4,
                Size = UDim2.fromScale(1, 1),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 6,
                Parent = CopyBtn,
            })
            if ApplyLucideIcon(CopyIcon, "copy") then
                CopyBtn.Text = ""
                CopyBtn.MouseEnter:Connect(function()
                    TweenService:Create(CopyIcon, TweenInfoDefault, { ImageTransparency = 0 }):Play()
                end)
                CopyBtn.MouseLeave:Connect(function()
                    TweenService:Create(CopyIcon, TweenInfoDefault, { ImageTransparency = 0.4 }):Play()
                end)
                CopyBtn.MouseButton1Click:Connect(function()
                    ApplyLucideIcon(CopyIcon, "check")
                    task.delay(1.2, function()
                        if CopyIcon and CopyIcon.Parent then
                            ApplyLucideIcon(CopyIcon, "copy")
                        end
                    end)
                end)
            else
                CopyIcon:Destroy()
            end
        end)
    end
    New("Frame", {
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        LayoutOrder = 6,
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = UserContent,
    })
    local TimeLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 7,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 12),
        Text = FormatTime(),
        TextColor3 = Scheme.FontColor,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = UserContent,
    })
    local DateLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 8,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 10),
        Text = FormatDate(),
        TextColor3 = Scheme.FontColor,
        TextSize = 10,
        TextTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = UserContent,
    })
    spawn(function()
        while ScreenGui and TimeLabel.Parent do
            TimeLabel.Text = FormatTime()
            task.wait(1)
        end
    end)
    local AdGroupbox = New("Frame", {
        BackgroundColor3 = Scheme.BackgroundColor,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2,
        ZIndex = 3,
    })
    AddCorner(AdGroupbox)
    AddOutline(AdGroupbox)
    local AdContent = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = AdGroupbox,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = AdContent,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        Parent = AdContent,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 1,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 16),
        Text = "<b>Stop doing keys. Go Lifetime.</b>",
        TextColor3 = Scheme.AccentColor,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = AdContent,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 2,
        RichText = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        TextWrapped = true,
        Text = "Pay once, skip every checkpoint, and <b>unlock every current and future nobulem.wtf script.</b>",
        TextColor3 = Scheme.FontColor,
        TextSize = 11,
        TextTransparency = 0.35,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 3,
        Parent = AdContent,
    })
    local BenefitsList = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 3,
        Parent = AdContent,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = BenefitsList,
    })
    local benefits = {
        { icon = "key-round",   text = "Skip the key system forever" },
        { icon = "gamepad-2",   text = "All current & future games" },
        { icon = "zap",         text = "Priority updates & support" },
        { icon = "sparkles",    text = "Exclusive lifetime-only features" },
        { icon = "shield-check", text = "Undetected & HWID locked" },
    }
    for i, b in benefits do
        local Row = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 3,
            Parent = BenefitsList,
        })
        local IconHolder = New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 1),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = 3,
            Parent = Row,
        })
        local FallbackTick = New("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = Scheme.Font,
            Size = UDim2.fromScale(1, 1),
            Text = "+",
            TextColor3 = Scheme.SuccessColor,
            TextSize = 12,
            ZIndex = 3,
            Parent = IconHolder,
        })
        local IconImg = New("ImageLabel", {
            BackgroundTransparency = 1,
            ImageColor3 = Scheme.SuccessColor,
            Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Fit,
            Visible = false,
            ZIndex = 3,
            Parent = IconHolder,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(20, 0),
            Size = UDim2.new(1, -20, 1, 0),
            Text = b.text,
            TextColor3 = Scheme.FontColor,
            TextSize = 11,
            TextTransparency = 0.15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 3,
            Parent = Row,
        })
        OnIconsReady(function()
            if ApplyLucideIcon(IconImg, b.icon) then
                IconImg.Visible = true
                FallbackTick.Visible = false
            end
        end)
    end
    local PricingBox = New("Frame", {
        BackgroundColor3 = GetBetterColor(Scheme.BackgroundColor, 4),
        LayoutOrder = 4,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 3,
        Parent = AdContent,
    })
    AddCorner(PricingBox, CornerRadius / 2)
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = PricingBox,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = PricingBox,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 6),
        Parent = PricingBox,
    })
    for i, tier in config.Prices do
        local isLifetime = tier.label == "Lifetime"
        local Row = New("Frame", {
            BackgroundTransparency = 1,
            LayoutOrder = i,
            Size = UDim2.new(1, 0, 0, 16),
            ZIndex = 3,
            Parent = PricingBox,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            FontFace = Scheme.Font,
            Size = UDim2.new(0.55, 0, 1, 0),
            Text = tier.label,
            TextColor3 = isLifetime and Scheme.AccentColor or Scheme.FontColor,
            TextSize = 11,
            TextTransparency = isLifetime and 0 or 0.25,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = Row,
        })
        New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            FontFace = Scheme.Font,
            Position = UDim2.fromScale(1, 0),
            RichText = true,
            Size = UDim2.new(0.45, 0, 1, 0),
            Text = isLifetime and ("<b>" .. tier.price .. "</b>") or tier.price,
            TextColor3 = isLifetime and Scheme.AccentColor or Scheme.FontColor,
            TextSize = 11,
            TextTransparency = isLifetime and 0 or 0.15,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 3,
            Parent = Row,
        })
    end
    local BuyBtn = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Scheme.AccentColor,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 5,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 24),
        Text = "<b>Buy Lifetime — " .. config.LifetimePrice .. "</b>",
        TextColor3 = Scheme.WhiteColor,
        TextSize = 14,
        TextTransparency = 0.1,
        ZIndex = 3,
        Parent = AdContent,
    })
    AddCorner(BuyBtn, CornerRadius / 2)
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = BuyBtn,
    })
    BuyBtn.MouseEnter:Connect(function()
        TweenService:Create(BuyBtn, TweenInfoDefault, { TextTransparency = 0 }):Play()
    end)
    BuyBtn.MouseLeave:Connect(function()
        TweenService:Create(BuyBtn, TweenInfoDefault, { TextTransparency = 0.4 }):Play()
    end)
    BuyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(config.BuyUrl)
        end
        Notify("Buy Link Copied", config.BuyUrl, 5, Scheme.AccentColor)
    end)
    local DiscordBtn = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Scheme.MainColor,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 6,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 21),
        Text = "Discord Server",
        TextColor3 = Scheme.WhiteColor,
        TextSize = 14,
        TextTransparency = 0.4,
        ZIndex = 3,
        Parent = AdContent,
    })
    AddCorner(DiscordBtn, CornerRadius / 2)
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = DiscordBtn,
    })
    DiscordBtn.MouseEnter:Connect(function()
        TweenService:Create(DiscordBtn, TweenInfoDefault, { TextTransparency = 0 }):Play()
    end)
    DiscordBtn.MouseLeave:Connect(function()
        TweenService:Create(DiscordBtn, TweenInfoDefault, { TextTransparency = 0.4 }):Play()
    end)
    DiscordBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(config.DiscordInvite)
        end
        Notify("Discord", "Invite link copied to clipboard.", 4, Color3.fromRGB(114, 137, 218))
    end)
    local Container = New("ScrollingFrame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = GetBetterColor(Scheme.BackgroundColor, 1),
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 0, 49),
        Size = UDim2.new(1, -SIDEBAR_WIDTH - 1, 1, -70),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromScale(0, 0),
        ScrollBarThickness = IsMobile and 6 or 4,
        ScrollBarImageColor3 = Scheme.AccentColor,
        ScrollBarImageTransparency = 0.6,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 2,
        Parent = MainFrame,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 6),
        Parent = Container,
    })
    local AuthBoxHolder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 0),
        ZIndex = 3,
        Parent = Container,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 2 + CONTENT_RIGHT_PAD),
        PaddingTop = UDim.new(0, 4),
        Parent = AuthBoxHolder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = AuthBoxHolder,
    })
    AdGroupbox.Parent = AuthBoxHolder
    local AuthGroupbox = New("Frame", {
        BackgroundColor3 = Scheme.BackgroundColor,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        ZIndex = 3,
        Parent = AuthBoxHolder,
    })
    AddCorner(AuthGroupbox)
    AddOutline(AuthGroupbox)
    New("Frame", {
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = AuthGroupbox,
    })
    local AuthHeaderLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 34),
        Text = "Authentication",
        TextColor3 = Scheme.FontColor,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = AuthGroupbox,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = AuthHeaderLabel,
    })
    local AuthContent = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 35),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = AuthGroupbox,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = AuthContent,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 7),
        Parent = AuthContent,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 1,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 14),
        Text = config.Description,
        TextColor3 = Scheme.FontColor,
        TextSize = 14,
        TextTransparency = 0.4,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = AuthContent,
    })
    local InputHolder = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 39),
        ZIndex = 3,
        Parent = AuthContent,
    })
    New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "Key",
        TextColor3 = Scheme.FontColor,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = InputHolder,
    })
    local InputBox = New("TextBox", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Scheme.MainColor,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        FontFace = Scheme.Font,
        PlaceholderColor3 = GetDarkerColor(Scheme.FontColor),
        PlaceholderText = "paste your key here...",
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 21),
        Text = "",
        TextColor3 = Scheme.FontColor,
        TextEditable = true,
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = InputHolder,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 3),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 4),
        Parent = InputBox,
    })
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = Scheme.OutlineColor,
        Parent = InputBox,
    })
    AddCorner(InputBox, CornerRadius / 2)
    KeyTextBox = InputBox
    StatusLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        LayoutOrder = 3,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 14),
        Text = "Status: Waiting for key...",
        TextColor3 = Scheme.WarningColor,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = AuthContent,
    })
    local ButtonRow = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 4,
        Size = UDim2.new(1, 0, 0, 21),
        ZIndex = 3,
        Parent = AuthContent,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ButtonRow,
    })
    local function CreateObsidianButton(text, layoutOrder, parent)
        local Btn = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Scheme.MainColor,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            LayoutOrder = layoutOrder,
            RichText = true,
            Size = UDim2.fromScale(1, 1),
            Text = text,
            TextColor3 = Scheme.FontColor,
            TextSize = 14,
            TextTransparency = 0.4,
            ZIndex = 3,
            Parent = parent,
        })
        AddCorner(Btn, CornerRadius / 2)
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Scheme.OutlineColor,
            Parent = Btn,
        })
        Btn.MouseEnter:Connect(function()
            TweenService:Create(Btn, TweenInfoDefault, { TextTransparency = 0 }):Play()
        end)
        Btn.MouseLeave:Connect(function()
            TweenService:Create(Btn, TweenInfoDefault, { TextTransparency = 0.4 }):Play()
        end)
        return Btn
    end
    local LinkvertiseBtn = CreateObsidianButton("Linkvertise", 1, ButtonRow)
    local WorkInkBtn = CreateObsidianButton("Work.ink", 2, ButtonRow)
    local CheckStatusBtn = CreateObsidianButton("Validate Key", 3, ButtonRow)
    local BottomBg = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = GetBetterColor(Scheme.BackgroundColor, 4),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 20 + CornerRadius),
        ZIndex = 2,
        Parent = MainFrame,
    })
    AddCorner(BottomBg)
    New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Scheme.OutlineColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -20),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 3,
        Parent = MainFrame,
    })
    New("TextLabel", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Scheme.Font,
        Position = UDim2.fromScale(0, 1),
        RichText = true,
        Size = UDim2.new(1, 0, 0, 20),
        Text = config.Title .. " • Key System",
        TextColor3 = Scheme.FontColor,
        TextSize = 14,
        TextTransparency = 0.5,
        ZIndex = 4,
        Parent = MainFrame,
    })
    local function CopyKeyLink(provider, url)
        if setclipboard then
            setclipboard(url)
            Notify("Link Copied", provider .. " key link copied. Open it in your browser.", 5, Scheme.AccentColor)
        else
            Notify(provider .. " Key Link", url, 10, Scheme.AccentColor)
        end
        SetStatus("Complete the " .. provider .. " link, then paste your key...", Scheme.WarningColor)
    end
    LinkvertiseBtn.MouseButton1Click:Connect(function()
        CopyKeyLink("Linkvertise", config.LinkvertiseUrl)
    end)
    WorkInkBtn.MouseButton1Click:Connect(function()
        CopyKeyLink("Work.ink", config.WorkInkUrl)
    end)
    CheckStatusBtn.MouseButton1Click:Connect(function()
        if ScriptLoaded then return end
        local cleaned = (KeyTextBox.Text or ""):gsub("%s", "")
        if cleaned == "" then
            Notify("Error", "Paste your key into the input field first.", 4, Scheme.RedColor)
            SetStatus("No key entered", Scheme.RedColor)
            return
        end
        HandleKeyObtained(cleaned)
    end)
    KeyTextBox.FocusLost:Connect(function(Enter)
        if not Enter then return end
        if KeyTextBox.Text == "" or ScriptLoaded then return end
        local cleaned = KeyTextBox.Text:gsub("%s", "")
        if not IsValidKeyFormat(cleaned) then
            Notify("Error", "Enter a valid LuaProt key.", 4, Scheme.RedColor)
            SetStatus("Invalid LuaProt key format", Scheme.RedColor)
            KeyTextBox.Text = ""
            return
        end
        HandleKeyObtained(cleaned)
    end)
    local function ShowPremiumOffer()
        if not config.ShowPremiumPopup or not ScreenGui or not ScreenGui.Parent then return end

        local Overlay = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            ZIndex = 30,
            Parent = ScreenGui,
        })
        local Card = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = GetBetterColor(Scheme.BackgroundColor, 2),
            Position = UDim2.fromScale(0.5, 0.54),
            Size = UDim2.fromOffset(IsMobile and 340 or 390, 300),
            ZIndex = 31,
            Parent = Overlay,
        })
        AddCorner(Card, 12)
        New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Scheme.OutlineColor,
            Thickness = 1,
            Transparency = 0.1,
            Parent = Card,
        })
        New("Frame", {
            BackgroundColor3 = Scheme.AccentColor,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 4),
            ZIndex = 32,
            Parent = Card,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(24, 28),
            RichText = true,
            Size = UDim2.new(1, -48, 0, 34),
            Text = "<b>Make this your last key.</b>",
            TextColor3 = Scheme.FontColor,
            TextSize = 24,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 32,
            Parent = Card,
        })
        New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(24, 68),
            RichText = true,
            Size = UDim2.new(1, -48, 0, 42),
            Text = "Skip the ads and checkpoints forever. One purchase unlocks <b>every current and future script.</b>",
            TextColor3 = Scheme.FontColor,
            TextSize = 13,
            TextTransparency = 0.22,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 32,
            Parent = Card,
        })

        local benefits = {
            "No keys or checkpoints",
            "All games and future releases",
            "Priority updates and support",
        }
        for i, text in benefits do
            New("TextLabel", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                FontFace = Scheme.Font,
                Position = UDim2.fromOffset(24, 117 + ((i - 1) * 24)),
                Size = UDim2.new(1, -48, 0, 20),
                Text = "+  " .. text,
                TextColor3 = i == 1 and Scheme.SuccessColor or Scheme.FontColor,
                TextSize = 13,
                TextTransparency = i == 1 and 0 or 0.12,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 32,
                Parent = Card,
            })
        end

        New("TextLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(24, 194),
            RichText = true,
            Size = UDim2.new(1, -48, 0, 22),
            Text = "One payment  •  <b>" .. config.LifetimePrice .. " lifetime</b>",
            TextColor3 = Scheme.AccentColor,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 32,
            Parent = Card,
        })

        local BuyNow = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Scheme.AccentColor,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.fromOffset(24, 228),
            RichText = true,
            Size = UDim2.new(1, -142, 0, 44),
            Text = "<b>Go keyless — " .. config.LifetimePrice .. "</b>",
            TextColor3 = Scheme.WhiteColor,
            TextSize = 14,
            ZIndex = 32,
            Parent = Card,
        })
        AddCorner(BuyNow, 8)
        local ContinueFree = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Scheme.MainColor,
            BorderSizePixel = 0,
            FontFace = Scheme.Font,
            Position = UDim2.new(1, -110, 0, 228),
            Size = UDim2.fromOffset(86, 44),
            Text = "Continue free",
            TextColor3 = Scheme.FontColor,
            TextSize = 12,
            TextTransparency = 0.35,
            ZIndex = 32,
            Parent = Card,
        })
        AddCorner(ContinueFree, 8)

        local closed = false
        local function CloseOffer()
            if closed then return end
            closed = true
            TweenService:Create(Overlay, TweenInfoDefault, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(Card, TweenInfoDefault, {
                Position = UDim2.fromScale(0.5, 0.54),
            }):Play()
            task.delay(0.22, function()
                if Overlay then Overlay:Destroy() end
            end)
        end
        BuyNow.MouseEnter:Connect(function()
            TweenService:Create(BuyNow, TweenInfoDefault, { BackgroundColor3 = GetBetterColor(Scheme.AccentColor, 8) }):Play()
        end)
        BuyNow.MouseLeave:Connect(function()
            TweenService:Create(BuyNow, TweenInfoDefault, { BackgroundColor3 = Scheme.AccentColor }):Play()
        end)
        ContinueFree.MouseEnter:Connect(function()
            TweenService:Create(ContinueFree, TweenInfoDefault, { TextTransparency = 0 }):Play()
        end)
        ContinueFree.MouseLeave:Connect(function()
            TweenService:Create(ContinueFree, TweenInfoDefault, { TextTransparency = 0.35 }):Play()
        end)
        BuyNow.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard(config.BuyUrl)
                Notify("Lifetime Link Copied", "Open the checkout link to go keyless forever.", 6, Scheme.AccentColor)
            else
                Notify("Lifetime Checkout", config.BuyUrl, 10, Scheme.AccentColor)
            end
            CloseOffer()
        end)
        ContinueFree.MouseButton1Click:Connect(CloseOffer)

        TweenService:Create(Overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.28 }):Play()
        TweenService:Create(Card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.fromScale(0.5, 0.5),
        }):Play()
    end

    TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),
    }):Play()
    task.delay(0.55, ShowPremiumOffer)
end
local savedKey = LoadSavedKey()
if savedKey then
    local execOk, execErr = TryExecuteWithKey(savedKey)
    if execOk then
        ScriptLoaded = true
        if NotifGui then
            pcall(function() NotifGui:Destroy() end)
            NotifGui = nil
        end
        return
    end

    DeleteFile(config.File)
    ClearKeyGlobals()
    Notify(config.Title, "Saved key could not start LuaProt: " .. tostring(execErr), 7, Scheme.RedColor)
end
local buildOk, buildErr = pcall(BuildUI)
if not buildOk then
    Notify("UI Error", tostring(buildErr), 15, Scheme.RedColor)
    warn("[KeySystem] BuildUI error: " .. tostring(buildErr))
end
