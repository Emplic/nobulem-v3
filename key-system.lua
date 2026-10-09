repeat task.wait() until game:IsLoaded()
local PassedLoaderConfig = ...
local LoaderConfig =
    (type(PassedLoaderConfig) == "table" and PassedLoaderConfig)
    or (getgenv and getgenv().NobulemLoaderConfig)
    or (_G and _G.NobulemLoaderConfig)
    or (type(shared) == "table" and shared.NobulemLoaderConfig)
    or {}
local cloneref = cloneref or function(object) return object end
local CoreGui = cloneref(game:GetService("CoreGui"))
local HttpService = cloneref(game:GetService("HttpService"))
local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))
local getgenv = getgenv or function() return shared or _G end
local setclipboard = setclipboard
local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local previous = getgenv().NobulemKeySystem
if previous and previous.Destroy then pcall(previous.Destroy) end
for _, name in {"ObsidianKeySystem", "ObsidianKeyNotification"} do
    local gui = CoreGui:FindFirstChild(name)
    if gui then gui:Destroy() end
end
local RawScriptId = LoaderConfig.LuarmorScriptId and tostring(LoaderConfig.LuarmorScriptId) or ""
if #RawScriptId ~= 32 or not RawScriptId:match("^[0-9a-fA-F]+$") then
    local label = tostring(LoaderConfig.GameName or "This game")
    warn(("[nobulem.wtf] %s needs a valid 32-character Luarmor script ID."):format(label))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "nobulem.wtf",
            Text = label .. " is not set up on Luarmor yet - no key can validate here.",
            Duration = 10,
        })
    end)
    return
end
local config = {
    File = LoaderConfig.SaveFile or "nobulem_key.txt",
    KeyFile = "key.txt",
    Folder = "nobulem",
    Title = "nobulem.wtf",
    Version = LoaderConfig.GameName and (LoaderConfig.GameName .. " - Key system") or "Key system",
    Description = "Choose 12 or 24 hours of free access. Lifetime never asks again.",
    LinkvertiseUrl = LoaderConfig.Linkvertise12hUrl or LoaderConfig.LinkvertiseUrl or LoaderConfig.GetKeyUrl
        or "https://ads.luarmor.net/get_key?for=Linkvertise-WNOSNrUbmMHZ",
    Linkvertise24hUrl = LoaderConfig.Linkvertise24hUrl
        or "https://ads.luarmor.net/get_key?for=Linkvertise_2-KLYIoYnluHnT",
    WorkInkUrl = LoaderConfig.WorkInkUrl or LoaderConfig.GetKeyUrl
        or "https://ads.luarmor.net/get_key?for=Work_ink-ENZrHfPIitmN",
    LuarmorScriptId = RawScriptId,
    LuarmorSdkUrl = "https://sdkapi-public.luarmor.net/library.lua",
    Logo = "138831083704120",
    DiscordInvite = "https://discord.gg/mugcSRnpuG",
    BuyUrl = "https://nobulem.com/pricing/",
    LifetimePrice = "$19.99",
    LifetimeValue = 19.99,
    WeeklyValue = 3.50,
    MinutesPerCheckpoint = 3,
    PreloadNudgeSeconds = 3.5,
    ShowPremiumPopup = LoaderConfig.ShowPremiumPopup ~= false,
    Prices = {
        { label = "Weekly",   price = "$3.50" },
        { label = "Monthly",  price = "$6.99" },
        { label = "3 Months", price = "$10.99" },
        { label = "Lifetime", price = "$19.99" },
    },
}
 
local function LoadVitality()
    local url = LoaderConfig.VitalityLibraryUrl or getgenv().NobulemVitalityLibraryUrl
        or "https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/vitality-key-ui.lua"
    if type(url) ~= "string" or not url:match("^https://") then
        error("Set VitalityLibraryUrl to the raw URL of vitality-key-ui.lua")
    end
    local source = game:HttpGet(url)
    local chunk, err = loadstring(source, "NobulemKeyUI")
    if not chunk then error("Vitality UI compile: " .. tostring(err)) end
    local library = chunk()
    if type(library) ~= "table" or type(library.Window) ~= "function" then
        error("Vitality UI returned an invalid library")
    end
    return library
end
local function DeleteFile(path)
    if isfile and isfile(path) then
        pcall(delfile, path)
    end
end
local function EnsureFolder()
    if not isfolder or not makefolder then return false end
    if not isfolder(config.Folder) then
        local ok = pcall(makefolder, config.Folder)
        if not ok then return false end
    end
    return true
end
local function KeyFilePath()
    return config.Folder .. "/" .. config.KeyFile
end
local function LegacyKeyPaths()
    local paths = {
        config.Folder .. "/key_" .. config.LuarmorScriptId .. ".txt",
        config.File,
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
        pcall(writefile, KeyFilePath(), key)
    else
        pcall(writefile, config.File, key)
    end
end
local function ReadKeyFile(path)
    if not isfile or not isfile(path) then return nil end
    local ok, data = pcall(readfile, path)
    if ok and type(data) == "string" then
        local cleaned = data:gsub("%s", "")
        if #cleaned > 0 then return cleaned end
    end
    return nil
end
local function LoadSavedKey()
    local shared = ReadKeyFile(KeyFilePath())
    if shared then
        return shared
    end
    for _, path in LegacyKeyPaths() do
        local legacy = ReadKeyFile(path)
        if legacy then
            SaveKey(legacy)
            return legacy
        end
    end
    return nil
end
local StatsData = { checkpoints = 0, lastKey = 0, keyId = "", keyFirstSeen = 0 }
local function StatsPath()
    return config.Folder .. "/usage.json"
end
local function LoadStats()
    local raw = nil
    if isfile and isfile(StatsPath()) then
        local ok, data = pcall(readfile, StatsPath())
        if ok then raw = data end
    end
    if not raw then return end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(decoded) == "table" then
        StatsData.checkpoints = tonumber(decoded.checkpoints) or 0
        StatsData.lastKey = tonumber(decoded.lastKey) or 0
        StatsData.keyId = tostring(decoded.keyId or "")
        StatsData.keyFirstSeen = tonumber(decoded.keyFirstSeen) or 0
    end
end
local function SaveStats()
    if not writefile then return end
    if not EnsureFolder() then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(StatsData) end)
    if ok and encoded then
        pcall(writefile, StatsPath(), encoded)
    end
end
LoadStats()
local function HashKey(key)
    local total = 7
    for i = 1, #key do
        total = (total * 31 + key:byte(i)) % 2147483647
    end
    return tostring(total) .. "-" .. tostring(#key)
end
local function NoteKeyInUse(key)
    if type(key) ~= "string" or key == "" then return end
    local id = HashKey(key)
    if StatsData.keyId ~= id then
        StatsData.keyId = id
        StatsData.keyFirstSeen = os.time()
        SaveStats()
    end
end
local function LooksLifetime(key)
    if type(key) ~= "string" or key == "" then return false end
    if StatsData.keyId ~= HashKey(key) then return false end
    local first = tonumber(StatsData.keyFirstSeen) or 0
    if first <= 0 then return false end
    return (os.time() - first) >= 259200
end
local function CountCheckpoint()
    StatsData.checkpoints = StatsData.checkpoints + 1
    StatsData.lastKey = os.time()
    SaveStats()
end
local function MinutesLost()
    return StatsData.checkpoints * config.MinutesPerCheckpoint
end
local function WeeksToBreakEven()
    return math.max(1, math.ceil(config.LifetimeValue / config.WeeklyValue))
end
local function PriceGapLine()
    local bestLabel, bestValue = nil, nil
    for _, tier in config.Prices do
        if tier.label ~= "Lifetime" then
            local value = tonumber((tostring(tier.price):gsub("[^%d%.]", "")))
            if value and (not bestValue or value > bestValue) then
                bestLabel, bestValue = tier.label, value
            end
        end
    end
    if not bestLabel then
        return "One payment, then it is yours forever"
    end
    return ("Lifetime is only <b>$%.2f</b> more than %s"):format(math.max(0, config.LifetimeValue - bestValue), bestLabel)
end
local function UsageLine()
    local count = StatsData.checkpoints
    if count <= 0 then
        return "Lifetime users skip this screen completely."
    end
    if count == 1 then
        return "That is 1 key unlocked on this device so far."
    end
    return ("That is %d keys unlocked on this device - about %d minutes spent on links."):format(count, MinutesLost())
end
local function IsValidKeyFormat(key)
    if type(key) ~= "string" then return false end
    local cleaned = key:gsub("%s", "")
    return #cleaned == 32 and cleaned:match("^[A-Za-z]+$") ~= nil
end
local ScriptLoaded = false
local Validating = false

local function ForgetSavedKey()
    DeleteFile(KeyFilePath())
    for _, path in LegacyKeyPaths() do
        DeleteFile(path)
    end
end

local function ClearKeyGlobals()
    _G.ScriptKey = nil
    _G.script_key = nil
    getgenv().ScriptKey = nil
    getgenv().script_key = nil
    getgenv().Key = nil
end

local function CreateLuarmorSdk()
    local source = game:HttpGet(config.LuarmorSdkUrl)
    local chunk, compileErr = loadstring(source)
    if not chunk then error("SDK compile: " .. tostring(compileErr)) end
    local sdk = chunk()
    if type(sdk) ~= "table" then error("SDK returned an invalid value") end
    sdk.script_id = config.LuarmorScriptId
    return sdk
end

local function CheckKeyWithScript(key)
    local sdkOk, sdkOrErr = pcall(CreateLuarmorSdk)
    if not sdkOk then
        return nil, "Luarmor SDK unreachable: " .. tostring(sdkOrErr), false, false
    end

    local sdk = sdkOrErr
    local checkOk, result = pcall(function()
        return sdk.check_key(key)
    end)
    if not checkOk then
        return nil, "Luarmor key check failed: " .. tostring(result), false, false
    end
    if type(result) ~= "table" or result.code == nil then
        return nil, "Luarmor returned an invalid key-check response", false, false
    end
    if result.code == "KEY_VALID" then
        return sdk, nil, false, false
    end

    local status = tostring(result.code)
    if status == "SCRIPT_ID_INVALID" or status == "SCRIPT_ID_INCORRECT" then
        return nil, "Luarmor script ID is invalid or not uploaded", false, false
    end
    local dead = status == "KEY_EXPIRED" or status == "KEY_BANNED"
    local rejected = dead or status == "KEY_INCORRECT" or status == "KEY_INVALID"
        or status == "KEY_HWID_LOCKED"
    return nil, tostring(result.message or status), dead, rejected
end

local function ValidateKey(key)
    if not IsValidKeyFormat(key) then return false, "format", nil, false, true end

    local sdk, err, dead, rejected = CheckKeyWithScript(key)
    if sdk then return true, nil, sdk, false, false end

    return false, err, nil, dead, rejected
end

local TeardownUI

local function LoadScript(key, sdk)
    _G.ScriptKey = key
    _G.script_key = key
    getgenv().ScriptKey = key
    getgenv().script_key = key
    getgenv().Key = key

    if TeardownUI then pcall(TeardownUI, true) end
    task.wait()

    sdk.script_id = config.LuarmorScriptId
    local loadOk, loadErr = pcall(function()
        return sdk.load_script()
    end)

    if not loadOk then
        ClearKeyGlobals()
        return false, "Luarmor loader: " .. tostring(loadErr)
    end
    return true, nil
end

local Scheme = {
    AccentColor = Color3.fromRGB(181, 32, 55),
    FontColor = Color3.fromRGB(200, 200, 200),
    RedColor = Color3.fromRGB(235, 85, 100),
    SuccessColor = Color3.fromRGB(110, 195, 140),
    WarningColor = Color3.fromRGB(220, 180, 100),
}
local Vitality, Window, ScreenGui, MainFrame, StatusLabel, KeyTextBox
local ValidateButton, AccessPage
local TouchButtons = {}
local Closed = false
local PendingUpsell, BuildUI, RecoverLoadFailure
local OfferOverlay, OfferDone, OfferTimer
local Session = {}
getgenv().NobulemKeySystem = Session
getgenv().NobulemKeySystemClosed = false

local function EnsureVitality()
    if Vitality then return Vitality end
    Vitality = LoadVitality()
    Vitality.MenuKeybind = tostring(Enum.KeyCode.RightShift)
    Vitality.NotificationsEnabled = true
    ScreenGui = Vitality.Holder.Instance
    ScreenGui.Name = "VitalityKeySystem"
    return Vitality
end
local function EscapeRichText(text)
    return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end
local function Notify(title, description, duration, color)
    if Closed then return end
    local ok, err = pcall(function()
        local library = EnsureVitality()
        local hex = (color or Scheme.AccentColor):ToHex()
         
        for line in tostring(description or ""):gmatch("[^\n]+") do
            library:Notification({
                Name = '<font color="#' .. hex .. '">' .. EscapeRichText(title) .. '</font>  ' .. EscapeRichText(line),
                Time = duration or 5,
            })
        end
    end)
    if not ok then warn("[KeySystem] " .. tostring(description) .. " (UI: " .. tostring(err) .. ")") end
end
local function SetStatus(text, color)
    if StatusLabel then
        StatusLabel:SetText("Status: " .. tostring(text))
        StatusLabel.Items.Text.Instance.TextColor3 = color or Scheme.WarningColor
    end
    if ValidateButton then
        ValidateButton:SetText(Validating and "Checking key..." or "Validate key")
    end
end
local function CancelOffer()
    if OfferTimer then pcall(task.cancel, OfferTimer); OfferTimer = nil end
    if OfferOverlay then OfferOverlay:Destroy(); OfferOverlay = nil end
    OfferDone = nil
end
TeardownUI = function(forLoad)
    Closed = true
    CancelOffer()
    local library = Vitality
    Vitality = nil
    if library then pcall(function() library:Exit() end) end
    Window, ScreenGui, MainFrame, StatusLabel, KeyTextBox, ValidateButton, AccessPage = nil, nil, nil, nil, nil, nil, nil
    PendingUpsell = nil
    TouchButtons = {}
    Session.UI = nil
    if getgenv().NobulemKeySystem == Session then getgenv().NobulemKeySystem = nil end
    getgenv().NobulemKeySystemClosed = true
end
Session.Destroy = TeardownUI
local function CloseUI()
     
    local done = OfferDone
    if done then
        CancelOffer()
        task.spawn(done)
    else
        TeardownUI()
    end
end
local function CopyLink(title, url)
    if type(url) ~= "string" or not url:match("^https://") then
        Notify("Link unavailable", "Configure this access link in the loader.", 6, Scheme.RedColor)
        return false
    end
    local ok = setclipboard and pcall(setclipboard, url)
    if ok then
        Notify("Link copied", title .. " - open it in your browser.", 5)
    else
        Notify(title, url, 12)
    end
    return true
end
local function FinishOffer()
    local done = OfferDone
    CancelOffer()
    if done then task.spawn(done) end
end

local function SizeKeyButton(button, touch)
    local items = button.Items
    local height = touch and 44 or 20
    local outer, inner = items.Button.Instance, items.RealButton.Instance
    outer.Size = UDim2.new(outer.Size.X.Scale, outer.Size.X.Offset, 0, height)
    inner.Size = UDim2.new(inner.Size.X.Scale, inner.Size.X.Offset, 0, height)
    items.Text.Instance.TextSize = touch and 16 or 14
end
local function KeyButton(section, spec)
    local button = section:Button(spec)
    SizeKeyButton(button, Vitality.TouchControls)
    table.insert(TouchButtons, button)
    return button
end
 
local function ComputeKeyLayout(viewport, touch, keyboardTop, topInset)
    local narrow = viewport.X < 620
    local useTouch = touch or viewport.X < 700
    local top = math.max(12, (topInset or 0) + 8)
    local bottom = math.min(viewport.Y - 12, keyboardTop and keyboardTop - 12 or viewport.Y - 12)
    local available = math.max(80, bottom - top)
    return {
        Width = math.max(120, math.min(useTouch and 780 or 700, viewport.X - 24)),
        Height = math.min(useTouch and 680 or 570, available),
        Top = top, Bottom = top + available, Touch = useTouch,
        SingleColumn = narrow or available < 260,
        HeaderHeight = (narrow or available < 260) and 66 or (useTouch and 46 or 38),
        Viewport = viewport,
    }
end

local function ShowPremiumOffer(mode, onDone)
    if not config.ShowPremiumPopup or Closed or not Window then return false end
    CancelOffer()
    local post = mode == "post"
    local library = Vitality
    OfferDone = onDone
    OfferOverlay = library:Create("TextButton", {
        Parent = MainFrame, Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 100,
    }).Instance
    local card = library:Create("Frame", {
        Parent = OfferOverlay, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -32, 0, math.min(library.TouchControls and 360 or 270, MainFrame.Size.Y.Offset - 24)),
        BorderSizePixel = 0, BackgroundColor3 = library.Theme.Background, ZIndex = 101,
    }):AddToTheme({BackgroundColor3 = "Background"})
    for index, theme in {"Outline 1", "Outline 3", "Outline 2", "Outline 4"} do
        library:Create("UIStroke", {
            Parent = card.Instance, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            LineJoinMode = Enum.LineJoinMode.Miter, Color = library.Theme[theme],
            BorderOffset = UDim.new(0, index - 1),
        }):AddToTheme({Color = theme})
    end
    local accent = library:Create("Frame", {
        Parent = card.Instance, Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = library.Theme.Accent, BorderSizePixel = 0, ZIndex = 102,
    }):AddToTheme({BackgroundColor3 = "Accent"})
    library:AccentGradient(accent, 0)
    local body = library:Create("ScrollingFrame", {
        Parent = card.Instance, Position = UDim2.fromOffset(16, 14),
        Size = UDim2.new(1, -32, 1, -28), BackgroundTransparency = 1, ZIndex = 102,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
        ScrollBarImageColor3 = library.Theme.Accent, BorderSizePixel = 0, Active = true,
    })
    library:Create("UIListLayout", {Parent = body.Instance, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
    local section = {Window = Window, Page = AccessPage, Items = {Content = body}}
    setmetatable(section, library)
    local title = section:Label({Name = post and "Make that your last key." or "Lifetime access"})
    title.Items.Text.Instance.TextColor3 = library.Theme.Accent
    section:Label({Name = "Skip ads and checkpoints. Unlock every current and future script with one purchase."})
    section:Label({Name = "No keys or checkpoints\nAll games and future releases\nPriority updates and support"})
    section:Label({Name = config.LifetimePrice .. " once - lifetime access"})
    KeyButton(section, {Name = "Go keyless - " .. config.LifetimePrice, Callback = function()
        CopyLink("Lifetime checkout", config.BuyUrl)
        FinishOffer()
    end})
    local remaining = math.max(1, math.ceil(config.PreloadNudgeSeconds))
    local continue = KeyButton(section, {Name = post and ("Continue with free key (" .. remaining .. ")") or "Maybe later", Callback = FinishOffer})
     
    for _, item in body.Instance:GetDescendants() do
        if item:IsA("GuiObject") then item.ZIndex = 103 end
    end
    library:Connect(OfferOverlay.Activated, FinishOffer)
    if post then
        OfferTimer = task.spawn(function()
            while remaining > 0 and OfferOverlay do
                task.wait(1)
                remaining -= 1
                if OfferOverlay then continue:SetText("Continue with free key (" .. remaining .. ")") end
            end
            OfferTimer = nil
            if OfferOverlay then FinishOffer() end
        end)
    end
    return true
end
local function HandleKeyObtained(key)
    if Closed or ScriptLoaded or Validating then return end
    if not IsValidKeyFormat(key) then
        Notify("Error", "Enter a valid 32-letter Luarmor key.", 5, Scheme.RedColor)
        SetStatus("Invalid Luarmor key format", Scheme.RedColor)
        return
    end
    Validating = true
    Notify(config.Title, "Checking Luarmor key...", 4, Scheme.AccentColor)
    SetStatus("Checking Luarmor...", Scheme.WarningColor)
    task.spawn(function()
        local ok, reason, sdk, dead = ValidateKey(key)
        Validating = false
        if Closed then return end
        if not ok then
            ClearKeyGlobals()
            if dead then ForgetSavedKey() end
            local msg = reason == "format" and "Invalid key format." or tostring(reason or "Unknown error")
            Notify("Error", msg, 8, Scheme.RedColor)
            SetStatus(msg, Scheme.RedColor)
            return
        end

        ScriptLoaded = true
        SaveKey(key)
        local isLifetime = LooksLifetime(key)
        local isNewKey = StatsData.keyId ~= HashKey(key)
        NoteKeyInUse(key)
        if isNewKey and not isLifetime then CountCheckpoint() end
        SetStatus("Key accepted - loading script", Scheme.SuccessColor)

        local started = false
        local function StartScript()
            if started then return end
            started = true
            local loadOk, loadErr = LoadScript(key, sdk)
            if not loadOk then
                ScriptLoaded = false
                warn("[nobulem.wtf] " .. tostring(loadErr))
                RecoverLoadFailure(loadErr)
            end
        end

        local shown = false
        if PendingUpsell and not isLifetime then
            local pcallOk, result = pcall(PendingUpsell, StartScript)
            shown = pcallOk and result == true
        end
        if not shown then StartScript() end
    end)
end

local function DragPosition(startPosition, startAbsolute, renderedSize, viewport, delta)
    local dx = math.clamp(delta.X, 8 - startAbsolute.X, math.max(8 - startAbsolute.X, viewport.X - 8 - startAbsolute.X - renderedSize.X))
    local dy = math.clamp(delta.Y, 8 - startAbsolute.Y, math.max(8 - startAbsolute.Y, viewport.Y - 8 - startAbsolute.Y - renderedSize.Y))
    return UDim2.new(startPosition.X.Scale, startPosition.X.Offset + dx,
        startPosition.Y.Scale, startPosition.Y.Offset + dy)
end
local function BindTitleDrag(library, handle)
    local pointer, origin, position, absolute
    local function StopDrag()
        pointer, origin, position, absolute = nil, nil, nil, nil
    end
    local function BeginDrag(input)
        if Closed or OfferOverlay or not Window.IsOpen then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if pointer then return end
        pointer, origin = input, input.Position
        position, absolute = MainFrame.Position, MainFrame.AbsolutePosition
    end
    local function UpdateDrag(input)
        if not pointer then return end
        if Closed or not MainFrame or not Window.IsOpen or OfferOverlay then StopDrag(); return end
        if pointer.UserInputType == Enum.UserInputType.Touch then
            if input ~= pointer then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local camera = Workspace.CurrentCamera
        if camera then
            local layout = Session.UI and Session.UI.Layout
            local bounds = camera.ViewportSize
            local top = layout and layout.Top or 8
            if layout then bounds = Vector2.new(bounds.X, layout.Bottom) end
            local shiftedAbsolute = Vector2.new(absolute.X, absolute.Y - top + 8)
            local shiftedBounds = Vector2.new(bounds.X, bounds.Y - top + 8)
            MainFrame.Position = DragPosition(position, shiftedAbsolute, MainFrame.AbsoluteSize, shiftedBounds, input.Position - origin)
        end
    end
    local function EndDrag(input)
        if not pointer then return end
        if input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then StopDrag() end
    end
    library:Connect(handle.InputBegan, BeginDrag)
    library:Connect(UserInputService.InputChanged, UpdateDrag)
    library:Connect(UserInputService.InputEnded, EndDrag)
    library:Connect(UserInputService.WindowFocusReleased, StopDrag)
    library:Connect(MainFrame:GetPropertyChangedSignal("Visible"), function()
        if not MainFrame.Visible then StopDrag() end
    end)
end

BuildUI = function()
    Closed = false
    getgenv().NobulemKeySystem = Session
    getgenv().NobulemKeySystemClosed = false
    local library = EnsureVitality()
    TouchButtons = {}
    local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(700, 570)
    library.TouchControls = UserInputService.TouchEnabled or viewport.X < 700
    library.FontSize = library.TouchControls and 16 or 14
    Window = library:Window({Name = config.Title})
    MainFrame = Window.Items.MainFrame.Instance
    MainFrame.Name = "NobulemKeyWindow"
    MainFrame.Size = UDim2.fromOffset(700, 570)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.fromScale(0.5, 0.5)
    local scale = library:Create("UIScale", {Parent = MainFrame, Scale = 1}).Instance

    local access = Window:Page({Name = "Key system"})
    AccessPage = access
    Window.Items.Pages.Instance.Visible = false
    Window.Items.Content.Instance.Position = UDim2.fromOffset(8, 46)
    Window.Items.Content.Instance.Size = UDim2.new(1, -16, 1, -54)
    Window.Items.Icon.Instance.Visible = false
    Window.Items.ActualTitle.Instance.Visible = false
    if Window.Items.IconBar then Window.Items.IconBar.Instance.Visible = false end
    local title = Window.Items.Title.Instance
    title.Name = "TitleBar"
    title.Size = UDim2.new(1, 0, 0, 37)
    local logo = library:Create("ImageLabel", {
        Name = "NobulemLogo", Parent = title, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(9, 4), Size = UDim2.fromOffset(29, 29),
        Image = "rbxassetid://" .. config.Logo, ScaleType = Enum.ScaleType.Fit, ZIndex = 4,
    }).Instance
    library:Create("TextLabel", {
        Name = "BrandTitle", Parent = title, BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0),
        Size = UDim2.new(0, 140, 1, 0), FontFace = library.BoldFont, TextSize = 16,
        Text = config.Title, TextColor3 = library.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, ZIndex = 4,
    }):AddToTheme({TextColor3 = "Text"})
    library:Create("TextLabel", {
        Name = "GameTitle", Parent = title, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -384, 1, 0), FontFace = library.Font, TextSize = library.FontSize,
        Text = config.Version, TextColor3 = library.Theme["Inactive Text"],
        TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
        BorderSizePixel = 0, ZIndex = 4,
    }):AddToTheme({TextColor3 = "Inactive Text"})
    local drag = library:Create("TextButton", {
        Name = "DragHandle", Parent = title, BackgroundTransparency = 1, Text = "",
        Size = UDim2.new(1, -40, 1, 0), Active = true, AutoButtonColor = false, ZIndex = 5,
    }).Instance
    local close = library:Create("TextButton", {
        Name = "Close", Parent = title, BackgroundTransparency = 1, Text = "×",
        Position = UDim2.new(1, -33, 0, 5), Size = UDim2.fromOffset(25, 26),
        FontFace = library.Font, TextSize = 20, TextColor3 = library.Theme["Inactive Text"],
        AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }):AddToTheme({TextColor3 = "Inactive Text"})
    close:Connect("Activated", CloseUI)
    BindTitleDrag(library, drag)
    Session.UI = {Frame = MainFrame, DragHandle = drag, Scale = scale, Page = access, Logo = logo}
    local entry = access:Section({Name = "Authentication", Side = 1, MaxHeight = 250})
    entry:Label({Name = "Paste your Luarmor key to unlock " .. tostring(LoaderConfig.GameName or "your script") .. "."})
    local textbox = entry:Textbox({Name = "License key", Flag = "nobulem_key_input", Placeholder = "Paste your 32-letter key", Finished = true})
    KeyTextBox = textbox.Items.Input.Instance
    KeyTextBox.Name = "KeyInput"
    KeyTextBox.Active, KeyTextBox.Selectable = true, true
    KeyTextBox.TextXAlignment = Enum.TextXAlignment.Left
    ValidateButton = KeyButton(entry, {Name = "Validate key", Callback = function()
        HandleKeyObtained((KeyTextBox.Text or ""):gsub("%s", ""))
    end})
    KeyButton(entry, {Name = "Paste from clipboard", Callback = function()
        if Closed or ScriptLoaded or Validating then return end
        local reader = getclipboard or getgenv().getclipboard or (syn and syn.get_clipboard)
        if not reader then
            Notify("Clipboard unavailable", "Paste your key into the input manually.", 5, Scheme.RedColor)
            return
        end
        local ok, data = pcall(reader)
        local cleaned = (ok and type(data) == "string" and data or ""):gsub("%s", "")
        if cleaned == "" then Notify("Clipboard empty", "Copy your key first.", 4, Scheme.RedColor); return end
        textbox:Set(cleaned)
        if IsValidKeyFormat(cleaned) then HandleKeyObtained(cleaned)
        else SetStatus("Pasted text is not a valid key", Scheme.RedColor) end
    end})
    StatusLabel = entry:Label({Name = "Status: Waiting for a key"})
    SetStatus("Waiting for a key", Scheme.FontColor)
    library:Connect(KeyTextBox.FocusLost, function(enter)
        if enter and KeyTextBox.Text ~= "" then HandleKeyObtained(KeyTextBox.Text:gsub("%s", "")) end
    end)
    entry:Label({Name = "Accepted keys are saved on this device and checked automatically next session."})

    local free = access:Section({Name = "Get a free key", Side = 1, MaxHeight = 250})
    free:Label({Name = "Choose a duration and complete a provider link in your browser."})
    local duration = "12 hours"
    local workInk, durationNote
    local durationDropdown = free:Dropdown({Name = "Key duration", Flag = "nobulem_key_duration", Items = {"12 hours", "24 hours"}, Default = duration, Callback = function(value)
        duration = value
        if workInk then workInk:SetVisibility(value == "12 hours") end
        if durationNote then durationNote:SetText(value == "12 hours" and "12 hours: Linkvertise or Work.ink" or "24 hours: Linkvertise only") end
    end})
    KeyButton(free, {Name = "Get key - Linkvertise", Callback = function()
        local url = duration == "24 hours" and config.Linkvertise24hUrl or config.LinkvertiseUrl
        if CopyLink("Linkvertise (" .. duration .. ")", url) then SetStatus("Finish Linkvertise, then paste your key", Scheme.WarningColor) end
    end})
    workInk = KeyButton(free, {Name = "Get key - Work.ink", Callback = function()
        if duration ~= "12 hours" then return end
        if CopyLink("Work.ink (12 hours)", config.WorkInkUrl) then SetStatus("Finish Work.ink, then paste your key", Scheme.WarningColor) end
    end})
    durationNote = free:Label({Name = "12 hours: Linkvertise or Work.ink"})

    local help = access:Section({Name = "Support", Side = 1, MaxHeight = 150})
    help:Label({Name = "Need help with a key? Join our Discord."})
    KeyButton(help, {Name = "Copy Discord invite", Callback = function() CopyLink("Discord community", config.DiscordInvite) end})
    KeyButton(help, {Name = "Copy pricing link", Callback = function() CopyLink("Premium pricing", config.BuyUrl) end})

    local plans = access:Section({Name = "Premium access", Side = 2, MaxHeight = 300})
    plans:Label({Name = "Skip ads and checkpoints. Get keyless access to every current and future script."})
    for _, tier in config.Prices do
        plans:Label({Name = tier.label .. "  -  " .. tier.price})
    end
    KeyButton(plans, {Name = "Purchase premium", Callback = function() CopyLink("Premium checkout", config.BuyUrl) end})

    local benefits = access:Section({Name = "Lifetime benefits", Side = 2, MaxHeight = 180})
    benefits:Label({Name = "No keys or checkpoints\nAll games and future releases\nPriority updates and support"})
    benefits:Label({Name = UsageLine()})
    KeyButton(benefits, {Name = "Copy lifetime link", Callback = function() CopyLink("Lifetime checkout", config.BuyUrl) end})

    local mobileColumn = library:Create("ScrollingFrame", {
        Name = "MobileContent", Parent = access.Items.Page.Instance, Visible = false,
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
        ScrollBarImageColor3 = library.Theme.Accent, Active = true, ClipsDescendants = true,
    }):AddToTheme({ScrollBarImageColor3 = "Accent"}).Instance
    library:Create("UIPadding", {
        Parent = mobileColumn, PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8),
    })
    library:Create("UIListLayout", {Parent = mobileColumn, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
    local sections = {
        {Object = entry, Side = 1, Order = 1}, {Object = free, Side = 1, Order = 2},
        {Object = plans, Side = 2, Order = 3}, {Object = benefits, Side = 2, Order = 4},
        {Object = help, Side = 1, Order = 5},
    }
    local gameTitle = title:FindFirstChild("GameTitle")
    local lastLayout, cameraConnection
    local function KeepInputVisible()
        if not KeyTextBox or Closed then return end
        local ok, focused = pcall(function() return UserInputService:GetFocusedTextBox() end)
        if not ok or focused ~= KeyTextBox then return end
        local scroll = lastLayout.SingleColumn and mobileColumn or access.ColumnsData[1].Instance
        local target = scroll.CanvasPosition.Y + KeyTextBox.AbsolutePosition.Y - scroll.AbsolutePosition.Y - 22
        local limit = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
        scroll.CanvasPosition = Vector2.new(0, math.clamp(target, 0, limit))
    end
    local function ApplyLayout(overrideViewport, overrideTouch, overrideKeyboardTop, overrideInset)
        if Closed or not MainFrame then return end
        local camera = Workspace.CurrentCamera
        local vp = overrideViewport or (camera and camera.ViewportSize) or Vector2.new(700, 570)
        local touch = overrideTouch
        if touch == nil then touch = UserInputService.TouchEnabled end
        local keyboardTop = overrideKeyboardTop
        if keyboardTop == nil then
            pcall(function()
                if UserInputService.OnScreenKeyboardVisible and UserInputService.OnScreenKeyboardPosition.Y > 0 then keyboardTop = UserInputService.OnScreenKeyboardPosition.Y end
            end)
        end
        local inset = overrideInset
        if inset == nil then
            inset = 0
            pcall(function() inset = game:GetService("GuiService"):GetGuiInset().Y end)
        end
        local layout = ComputeKeyLayout(vp, touch, keyboardTop, inset)
        local changed = not lastLayout or lastLayout.Width ~= layout.Width or lastLayout.Height ~= layout.Height
            or lastLayout.Top ~= layout.Top or lastLayout.Viewport.X ~= vp.X or lastLayout.Viewport.Y ~= vp.Y
        library.TouchControls, library.FontSize = layout.Touch, layout.Touch and 16 or 14
        scale.Scale = 1
        MainFrame.Size = UDim2.fromOffset(layout.Width, layout.Height)
        if changed then
            MainFrame.Position = UDim2.new(0.5, 0, 0.5, layout.Top + layout.Height / 2 - vp.Y / 2)
        end
        title.Size = UDim2.new(1, 0, 0, layout.HeaderHeight)
        Window.Items.Content.Instance.Position = UDim2.fromOffset(8, layout.HeaderHeight + 8)
        Window.Items.Content.Instance.Size = UDim2.new(1, -16, 1, -layout.HeaderHeight - 16)
        local closeSize = layout.Touch and 44 or 25
        close.Instance.Position = UDim2.new(1, -closeSize - 5, 0, 0)
        close.Instance.Size = UDim2.fromOffset(closeSize, layout.Touch and 44 or 37)
        drag.Size = UDim2.new(1, -closeSize - 12, 1, 0)
        if layout.SingleColumn then
            gameTitle.Position = UDim2.new(0.5, 0, 0, 49)
            gameTitle.Size = UDim2.new(1, -20, 0, 24)
        else
            gameTitle.Position = UDim2.fromScale(0.5, 0.5)
            gameTitle.Size = UDim2.new(1, -384, 1, 0)
        end
        local brand = title:FindFirstChild("BrandTitle")
        brand.Size = UDim2.new(0, 140, 0, layout.Touch and 44 or 38)
        logo.Position = UDim2.fromOffset(9, layout.Touch and 8 or 4)
        gameTitle.TextSize = library.FontSize
        mobileColumn.Visible = layout.SingleColumn
        for _, column in access.ColumnsData do
            column.Instance.Visible = not layout.SingleColumn
            column.Instance.ScrollBarThickness = layout.Touch and 4 or 0
        end
        for _, item in sections do
            local section = item.Object
            local frame = section.Items.Section.Instance
            frame.Parent = layout.SingleColumn and mobileColumn or access.ColumnsData[item.Side].Instance
            frame.LayoutOrder = item.Order
            local content = section.Items.Content.Instance
            content.ScrollingEnabled = not layout.Touch
            local height = section.Items.ContentLayout.Instance.AbsoluteContentSize.Y + 4
            content.Size = UDim2.new(1, -10, 0, layout.Touch and height or math.min(height, 300))
        end
        for _, button in TouchButtons do
            if button.Items.Button.Instance.Parent then SizeKeyButton(button, layout.Touch) end
        end
        textbox.Items.Textbox.Instance.Size = UDim2.new(1, 0, 0, layout.Touch and 66 or 38)
        textbox.Items.Background.Instance.Size = UDim2.new(1, -4, 0, layout.Touch and 44 or 22)
        KeyTextBox.Size = UDim2.new(1, -12, 0, layout.Touch and 44 or 16)
        local dropdownItems = durationDropdown.Items
        dropdownItems.Dropdown.Instance.Size = UDim2.new(1, 0, 0, layout.Touch and 68 or 42)
        dropdownItems.RealDropdown.Instance.Size = UDim2.new(1, -4, 0, layout.Touch and 44 or 20)
        durationDropdown:Filter("")
        for _, text in MainFrame:QueryDescendants("TextLabel, TextBox") do
            if text.Name ~= "BrandTitle" and text.TextSize >= 14 and text.TextSize <= 16 then text.TextSize = library.FontSize end
        end
        if durationDropdown.IsOpen then durationDropdown:SetOpen(false) end
        lastLayout = layout
        Session.UI.Layout = layout
        task.defer(KeepInputVisible)
    end
    local function BindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        local camera = Workspace.CurrentCamera
        if camera then cameraConnection = library:Connect(camera:GetPropertyChangedSignal("ViewportSize"), function() ApplyLayout() end) end
        ApplyLayout()
    end
    library:Connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), BindCamera)
    for _, property in {"OnScreenKeyboardVisible", "OnScreenKeyboardPosition", "OnScreenKeyboardSize", "TouchEnabled"} do
        pcall(function() library:Connect(UserInputService:GetPropertyChangedSignal(property), function() ApplyLayout() end) end)
    end
    library:Connect(KeyTextBox.Focused, function() ApplyLayout() end)
    library:Connect(KeyTextBox.FocusLost, function() ApplyLayout() end)
    Session.UI.UpdateLayout = ApplyLayout
    Session.UI.MobileColumn = mobileColumn
    Session.UI.DurationDropdown = durationDropdown
    BindCamera()
    PendingUpsell = function(onDone) return ShowPremiumOffer("post", onDone) end
    task.delay(0.55, function()
        if not Closed and not Validating and not ScriptLoaded then ShowPremiumOffer("intro") end
    end)
end
RecoverLoadFailure = function(reason)
     
    local ok, err = pcall(BuildUI)
    if ok then
        SetStatus("Script failed to load - validate again to retry", Scheme.RedColor)
        Notify("Loader error", tostring(reason), 10, Scheme.RedColor)
    else warn("[KeySystem] Could not reopen UI: " .. tostring(err)) end
end
local savedKey = LoadSavedKey()
if savedKey then
    local execOk, execErr, sdk, execDead, execRejected = ValidateKey(savedKey)
    if not execOk and not execRejected then
        task.wait(2)
        execOk, execErr, sdk, execDead, execRejected = ValidateKey(savedKey)
    end
    if Closed then return end
    if execOk then
        ScriptLoaded = true
        NoteKeyInUse(savedKey)
        if config.ShowPremiumPopup and not LooksLifetime(savedKey) then
            Notify(
                config.Title,
                "Saved key accepted - starting script. " .. UsageLine() .. "\nGo keyless once for " .. config.LifetimePrice .. " and never do this again: " .. config.BuyUrl,
                config.PreloadNudgeSeconds,
                Scheme.AccentColor
            )
            task.wait(config.PreloadNudgeSeconds + 0.35)
        end
        if Closed then return end
        local loadOk, loadErr = LoadScript(savedKey, sdk)
        if not loadOk then
            ScriptLoaded = false
            warn("[nobulem.wtf] " .. tostring(loadErr))
            RecoverLoadFailure(loadErr)
        end
        return
    end

    ClearKeyGlobals()
    ScriptLoaded = false
    if execDead then
        ForgetSavedKey()
        Notify(config.Title, "Saved key is no longer valid: " .. tostring(execErr) .. "\nGet a new key below.", 8, Scheme.RedColor)
    else
        Notify(
            config.Title,
            ("Your saved key was not accepted for %s: %s\nThe key is kept - press Validate Key to retry."):format(
                tostring(LoaderConfig.GameName or "this game"),
                tostring(execErr)
            ),
            10,
            Scheme.WarningColor
        )
    end
end
local buildOk, buildErr = pcall(BuildUI)
if not buildOk then
    TeardownUI()
    warn("[KeySystem] UI Error: " .. tostring(buildErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = config.Title, Text = "Key UI failed to initialize: " .. tostring(buildErr), Duration = 15,
        })
    end)
    warn("[KeySystem] BuildUI error: " .. tostring(buildErr))
elseif savedKey and KeyTextBox then
    KeyTextBox.Text = savedKey
    SetStatus("Saved key loaded - press Validate Key to retry", Scheme.WarningColor)
end
