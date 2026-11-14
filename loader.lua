local Notify
do
    local TweenService = game:GetService("TweenService")
    local Players = game:GetService("Players")
    local Fast = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local Colors = { success = Color3.fromRGB(112, 205, 132), error = Color3.fromRGB(235, 104, 104), info = Color3.fromRGB(159, 109, 255) }
    local Gui, Area
    local Stack = {}

    local function EnsureGui()
        if Gui and Gui.Parent then return end
        Gui = Instance.new("ScreenGui")
        Gui.Name = "NobulemLoaderNotifications"
        Gui.IgnoreGuiInset = true
        Gui.ResetOnSpawn = false
        Gui.DisplayOrder = 1000
        local placed = false
        if type(gethui) == "function" then placed = pcall(function() Gui.Parent = gethui() end) and Gui.Parent ~= nil end
        if not placed then placed = pcall(function() Gui.Parent = game:GetService("CoreGui") end) and Gui.Parent ~= nil end
        if not placed then Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10) end
        Area = Instance.new("Frame")
        Area.BackgroundTransparency = 1
        Area.Position = UDim2.fromOffset(16, 16)
        Area.Size = UDim2.fromOffset(400, 600)
        Area.Parent = Gui
    end

    local function Restack()
        for index, frame in ipairs(Stack) do
            TweenService:Create(frame, Fast, { Position = UDim2.fromOffset(0, (#Stack - index) * 36) }):Play()
        end
    end

    local Icons = {
        success = { { "f", 2, 8.4, 6.2, 2, 45 }, { "f", 5.2, 6.8, 10, 2, -45 } },
        error = { { "f", 1, 1, 14, 14 }, { "h", 7, 3.6, 2, 6 }, { "h", 7, 10.8, 2, 2 } },
        info = { { "f", 1, 1, 14, 14 }, { "h", 7, 6.6, 2, 6 }, { "h", 7, 3.4, 2, 2 } },
    }

    local function Push(text, kind, color, duration)
        EnsureGui()
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
        frame.BorderSizePixel = 0
        frame.Size = UDim2.fromOffset(60, 28)
        frame.Position = UDim2.fromOffset(-36, #Stack * 36)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = Color3.fromRGB(44, 42, 52)
        stroke.Parent = frame
        local icon = Instance.new("Frame")
        icon.BackgroundTransparency = 1
        icon.Position = UDim2.fromOffset(8, 7)
        icon.Size = UDim2.fromOffset(14, 14)
        icon.Parent = frame
        local parts = {}
        for _, part in ipairs(Icons[kind] or Icons.info) do
            local piece = Instance.new("Frame")
            piece.BorderSizePixel = 0
            piece.BackgroundColor3 = part[1] == "h" and frame.BackgroundColor3 or color
            piece.Position = UDim2.fromScale(part[2] / 16, part[3] / 16)
            piece.Size = UDim2.fromScale(part[4] / 16, part[5] / 16)
            piece.Rotation = part[6] or 0
            local round = Instance.new("UICorner")
            round.CornerRadius = UDim.new(0.5, 0)
            round.Parent = piece
            piece.Parent = icon
            table.insert(parts, piece)
        end
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        label.TextSize = 12
        label.TextColor3 = Color3.fromRGB(234, 232, 244)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Position = UDim2.fromOffset(28, 8)
        label.Size = UDim2.fromOffset(340, 28)
        label.Text = text
        label.Parent = frame
        local function fit() frame.Size = UDim2.fromOffset(math.min(math.ceil(label.TextBounds.X), 340) + 38, 28) end
        label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
        fit()
        frame.Parent = Area
        table.insert(Stack, 1, frame)
        Restack()
        task.delay(duration, function()
            local index = table.find(Stack, frame)
            if index then table.remove(Stack, index) end
            TweenService:Create(frame, Fast, { Position = UDim2.fromOffset(-36, frame.Position.Y.Offset), BackgroundTransparency = 1 }):Play()
            TweenService:Create(label, Fast, { TextTransparency = 1 }):Play()
            for _, piece in ipairs(parts) do
                TweenService:Create(piece, Fast, { BackgroundTransparency = 1 }):Play()
            end
            TweenService:Create(stroke, Fast, { Transparency = 1 }):Play()
            Restack()
            task.delay(0.3, function()
                frame:Destroy()
                if #Stack == 0 and Gui then
                    Gui:Destroy()
                    Gui, Area = nil, nil
                end
            end)
        end)
    end

    Notify = function(text, kind, duration)
        local lines, line = {}, ""
        for word in tostring(text):gmatch("%S+") do
            if line ~= "" and #line + #word + 1 > 52 then
                table.insert(lines, line)
                line = word
            else
                line = line == "" and word or (line .. " " .. word)
            end
        end
        if line ~= "" then table.insert(lines, line) end
        for _, chunk in ipairs(lines) do
            pcall(Push, chunk, kind, Colors[kind] or Colors.info, duration or 6)
        end
    end
end

local LoaderEnv = (type(getgenv) == "function" and getgenv()) or shared

local function FindProvidedKey()
    local function Clean(value)
        if type(value) ~= "string" then return nil end
        local cleaned = value:gsub("%s", "")
        return #cleaned > 0 and cleaned or nil
    end
    local key = Clean(script_key)
    if key then return key end
    for level = 1, 3 do
        local ok, env = pcall(getfenv, level)
        if ok and type(env) == "table" then
            local okKey, value = pcall(function() return env.script_key end)
            key = okKey and Clean(value)
            if key then return key end
        end
    end
    return Clean(LoaderEnv.script_key)
        or Clean(_G and _G.script_key)
        or Clean(type(shared) == "table" and shared.script_key or nil)
end

local ProvidedScriptKey = FindProvidedKey()
local previousStart = LoaderEnv.nobulem_loader_started
if type(previousStart) == "number" and os.clock() - previousStart < 15 then
    return
end
LoaderEnv.nobulem_loader_started = os.clock()

local KEYSYSTEM_URL = ("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/key-system.lua")

local LuarmorScriptIds = {
    WarTycoon = "450d986ceeb9678f3455712371a99053",
    Flick = "2d3b779daff5c319a93d5d8f38b1bdc0",
    UrbanReload = "40c127c6813852ae8c544277c726345d",
    Wanted = "b59527dfe5520d0cd523a37e7ddf2b47",
    ProjectSlayers = "87e8b11127b9704a640347ccd6c6c033",
    Hypershot = "df41b2339aac3a6c2e5b10079fd0a0f7",
    WantedBreakAndStealAnEgg = "e47e9632261b3364b61f4442e3a03571",
    AnimeEyesFlick = "4fa70478d26de77a26c693dc707b4025",
    HypershotVenomEvolution = "8934f8215d1c598724cbbf2d65308305",
    AOTR = "a63c0c5667d3bff2e6b5416d51e03769",
    ABizarreRun = "1beffe3e89f9490b79c1f8d37520d1ee",
    ThrowFoodABizarreRun = "5166b69f34db48b2df9b9a6c2e36da8b",
    UrbanReloadBeyondNen = "a95faedf4db50a30ced44fd85e6c6ef1",
}
local LuarmorAdUrls = {
    Linkvertise = "https://ads.luarmor.net/get_key?for=Linkvertise-WNOSNrUbmMHZ",
    LootLabs = "https://ads.luarmor.net/get_key?for=Lootlabs-uWczMBbSTANN",
    Linkvertise24h = "https://ads.luarmor.net/get_key?for=Linkvertise_2-KLYIoYnluHnT",
}

for name, id in pairs(getgenv().NobulemLuarmorScriptIds or {}) do LuarmorScriptIds[name] = id end
for name, url in pairs(getgenv().NobulemLuarmorAdUrls or {}) do LuarmorAdUrls[name] = url end

local WantedBreakAndStealAnEggScriptId = LuarmorScriptIds.WantedBreakAndStealAnEgg or ""
local AnimeEyesFlickScriptId = LuarmorScriptIds.AnimeEyesFlick or ""
local HypershotVenomEvolutionScriptId = LuarmorScriptIds.HypershotVenomEvolution or ""
local ThrowFoodABizarreRunScriptId = LuarmorScriptIds.ThrowFoodABizarreRun or ""
local UrbanReloadBeyondNenScriptId = LuarmorScriptIds.UrbanReloadBeyondNen or ""

local Games = {
    {
        PlaceIds        = {
            13379208636, 13379349730, 13904207646, 14012874501, 14638336319, 14916516914, 14932214603,
            15030367419, 15220308770, 15374465998, 15824912319, 17688739434, 112374853034490, 126678335159530,
        },
        SubplaceRoots   = { 13379208636 },
        UniverseId      = 4658598196,
        GameName        = "Attack on Titan Revolution",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.AOTR or "",
        GetKeyUrl       = LuarmorAdUrls.AOTR or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 4639625707, 6856061811, 17267897726, 18161998932, 116355587227251 },
        UniverseId      = 1526814825,
        GameName        = "War Tycoon",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.WarTycoon or "",
        GetKeyUrl       = LuarmorAdUrls.WarTycoon or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 136801880565837 },
        UniverseId      = 8795154789,
        GameName        = "Flick",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = AnimeEyesFlickScriptId ~= "" and AnimeEyesFlickScriptId or LuarmorScriptIds.Flick or "",
        GetKeyUrl       = LuarmorAdUrls.AnimeEyesFlick or LuarmorAdUrls.Flick or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 97617452700163 },
        UniverseId      = 10770933473,
        GameName        = "Anime Eyes",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = AnimeEyesFlickScriptId,
        GetKeyUrl       = LuarmorAdUrls.AnimeEyesFlick or LuarmorAdUrls.AnimeEyes or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 84448037861644 },
        UniverseId      = 10769552054,
        GameName        = "Urban Reload",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = UrbanReloadBeyondNenScriptId ~= "" and UrbanReloadBeyondNenScriptId or LuarmorScriptIds.UrbanReload or "",
        GetKeyUrl       = LuarmorAdUrls.UrbanReloadBeyondNen or LuarmorAdUrls.UrbanReload or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = {
            6016716328, 7005753990, 9451104557, 9484492325, 10958232317, 13864209831, 15130508163, 17003530886,
            74767246064721, 77244271732649, 78073853031462, 86991121097984, 91386853670890, 92047435191451,
            92742253895919, 96127042759796, 99388499587789, 102319792688611, 103998171025949, 105638469971133,
            113623351751174, 123343333878430, 125055808970188, 125380695993213, 128763370767026, 133204612069550,
        },
        UniverseId      = 2174306620,
        GameName        = "Beyond Nen",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = UrbanReloadBeyondNenScriptId,
        GetKeyUrl       = LuarmorAdUrls.UrbanReloadBeyondNen or LuarmorAdUrls.BeyondNen or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 14438406081 },
        UniverseId      = 4987856151,
        GameName        = "Wanted",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = WantedBreakAndStealAnEggScriptId ~= "" and WantedBreakAndStealAnEggScriptId or LuarmorScriptIds.Wanted or "",
        GetKeyUrl       = LuarmorAdUrls.WantedBreakAndStealAnEgg or LuarmorAdUrls.Wanted or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 114326934417838 },
        UniverseId      = 10765288803,
        GameName        = "Break and Steal an Egg",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = WantedBreakAndStealAnEggScriptId,
        GetKeyUrl       = LuarmorAdUrls.WantedBreakAndStealAnEgg or LuarmorAdUrls.BreakAndStealAnEgg or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = {
            136406881576517, 13883059853, 11468075017, 5956785391, 9627847912, 75556147183481,
            16205713724, 17047024836, 109676363279588, 130395143593224,
        },
        UniverseId      = 5595353122,
        GameName        = "Project Slayers 2",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.ProjectSlayers or "",
        GetKeyUrl       = LuarmorAdUrls.ProjectSlayers or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = {
            86696142930150, 100040622766961, 108428559529058, 17516596118, 92980558919575, 97804379417079,
            105357751512007, 110169684430399, 122181485177067, 128220027114734, 131008473296170, 134474332601640,
        },
        UniverseId      = 5995470825,
        GameName        = "Hypershot",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = HypershotVenomEvolutionScriptId ~= "" and HypershotVenomEvolutionScriptId or LuarmorScriptIds.Hypershot or "",
        GetKeyUrl       = LuarmorAdUrls.HypershotVenomEvolution or LuarmorAdUrls.Hypershot or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 116448925875915 },
        UniverseId      = 10769464063,
        GameName        = "Venom Evolution",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = HypershotVenomEvolutionScriptId,
        GetKeyUrl       = LuarmorAdUrls.HypershotVenomEvolution or LuarmorAdUrls.VenomEvolution or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 108055619068945 },
        UniverseId      = 9867225552,
        GameName        = "A Bizarre Run",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = ThrowFoodABizarreRunScriptId ~= "" and ThrowFoodABizarreRunScriptId or LuarmorScriptIds.ABizarreRun or "",
        GetKeyUrl       = LuarmorAdUrls.ABizarreRun or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 120219252362013 },
        UniverseId      = 10766972131,
        GameName        = "Throw Food For Animals",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = ThrowFoodABizarreRunScriptId,
        GetKeyUrl       = LuarmorAdUrls.ThrowFoodForAnimals or LuarmorAdUrls.Default or "",
    },
}

local HttpService = game:GetService("HttpService")

local function FetchSubplaceIds(rootPlaceId)
    local okU, uniBody = pcall(function()
        return game:HttpGet(("https://apis.roblox.com/universes/v1/places/%d/universe"):format(rootPlaceId))
    end)
    if not okU then return {} end
    local okD, uniData = pcall(function() return HttpService:JSONDecode(uniBody) end)
    if not okD or type(uniData) ~= "table" or not uniData.universeId then return {} end

    local ids = {}
    local cursor = nil
    repeat
        local url = ("https://develop.roblox.com/v1/universes/%d/places?sortOrder=Asc&limit=100"):format(uniData.universeId)
        if cursor then url = url .. "&cursor=" .. cursor end
        local okP, body = pcall(function() return game:HttpGet(url) end)
        if not okP then break end
        local okJ, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        if not okJ or type(decoded) ~= "table" then break end
        for _, place in ipairs(decoded.data or {}) do
            table.insert(ids, place.id)
        end
        cursor = decoded.nextPageCursor
    until not cursor or cursor == ""
    return ids
end

local SubplaceCache = {}

local function ResolveGame(placeId)
    for _, entry in ipairs(Games) do
        if placeId == game.PlaceId and entry.UniverseId and entry.UniverseId == game.GameId then
            return entry
        end
        for _, id in ipairs(entry.PlaceIds) do
            if id == placeId then return entry end
        end
    end
    for _, entry in ipairs(Games) do
        local roots = entry.SubplaceRoots or { entry.PlaceIds[1] }
        for _, rootId in ipairs(roots) do
            if rootId then
                if not SubplaceCache[rootId] then
                    SubplaceCache[rootId] = FetchSubplaceIds(rootId)
                end
                for _, id in ipairs(SubplaceCache[rootId]) do
                    if id == placeId then return entry end
                end
            end
        end
    end
    return nil
end

local cfg = ResolveGame(game.PlaceId)
if not cfg then
    Notify("nobulem.wtf doesn't support this game yet.", "error", 10)
    getgenv().nobulem_loader_started = nil
    return
end

local ResolvedName = (cfg.PlaceNames and cfg.PlaceNames[game.PlaceId]) or cfg.GameName

if cfg.LobbyPlaceIds and table.find(cfg.LobbyPlaceIds, game.PlaceId) then
    Notify("You're in the lobby. Join a game, then execute again.", "info", 10)
    getgenv().nobulem_loader_started = nil
    return
end

local scriptId = LuarmorScriptIds[game.PlaceId] or cfg.LuarmorScriptId
if type(scriptId) ~= "string" or #scriptId ~= 32 or not scriptId:match("^[0-9a-fA-F]+$") then
    Notify(ResolvedName .. " isn't set up on Luarmor yet.", "error", 10)
    getgenv().nobulem_loader_started = nil
    return
end

if cfg.Discontinued then
    Notify(ResolvedName .. " is discontinued for now. Try again later.", "error", 10)
    getgenv().nobulem_loader_started = nil
    return
end

getgenv().NobulemLoaderConfig = {
    PlaceId         = game.PlaceId,
    GameName        = ResolvedName,
    SaveFile        = cfg.SaveFile,
    LuarmorScriptId = scriptId,
    ScriptKey       = ProvidedScriptKey,
    GetKeyUrl       = cfg.GetKeyUrl,
    LinkvertiseUrl  = LuarmorAdUrls.Linkvertise,
    Linkvertise12hUrl = LuarmorAdUrls.Linkvertise12h or LuarmorAdUrls.Linkvertise,
    Linkvertise24hUrl = LuarmorAdUrls.Linkvertise24h,
    LootLabsUrl     = LuarmorAdUrls.LootLabs,
}

local function InviteDiscord()
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
    
    if isMobile then
        pcall(function() setclipboard("https://discord.gg/mugcSRnpuG") end)
        Notify("Discord invite copied.", "success", 5)
    else
        pcall(function()
            request({
                Url = "http://127.0.0.1:6463/rpc?v=1",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json", Origin = "https://discord.com" },
                Body = HttpService:JSONEncode({
                    cmd = "INVITE_BROWSER",
                    nonce = HttpService:GenerateGUID(false),
                    args = { code = "mugcSRnpuG" }
                })
            })
        end)
    end
end

local DISCORD_INVITE_FILE = "nobulem_discord.txt"
local DISCORD_INVITE_LIMIT = 5

local function ShouldInviteDiscord()
    local count = 0
    pcall(function()
        if isfile and isfile(DISCORD_INVITE_FILE) then
            count = tonumber(readfile(DISCORD_INVITE_FILE)) or 0
        end
    end)
    if count >= DISCORD_INVITE_LIMIT then return false end
    pcall(function()
        if writefile then writefile(DISCORD_INVITE_FILE, tostring(count + 1)) end
    end)
    return true
end

if ShouldInviteDiscord() then
    task.spawn(InviteDiscord)
end

local function Download(url)
    local okGet, body = pcall(function() return game:HttpGet(url) end)
    if okGet and type(body) == "string" and #body > 0 then return body end
    local http = (type(request) == "function" and request) or (type(http_request) == "function" and http_request) or (syn and syn.request)
    if http then
        local okReq, response = pcall(http, { Url = url, Method = "GET" })
        if okReq and type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then return response.Body end
    end
    error("could not download " .. url .. " (" .. tostring(body) .. ")")
end

local ok, err = pcall(function()
    local source = Download(KEYSYSTEM_URL)
    local chunk, compileErr = loadstring(source)
    if not chunk then error("compile: " .. tostring(compileErr)) end
    chunk(getgenv().NobulemLoaderConfig)
end)

if ok then
    getgenv().nobulem_loader_started = nil
else
    Notify("The key system failed to open: " .. tostring(err), "error", 15)
    getgenv().nobulem_loader_started = nil
    getgenv().NobulemLoaderConfig = nil
end
