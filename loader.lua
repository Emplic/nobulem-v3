if getgenv().nobulem_loader_started then return end
getgenv().nobulem_loader_started = true

local KEYSYSTEM_URL = ("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/key-system.lua")

local LuarmorScriptIds = {
    WarTycoon = "450d986ceeb9678f3455712371a99053",
    Flick = "2d3b779daff5c319a93d5d8f38b1bdc0",
    UrbanReload = "40c127c6813852ae8c544277c726345d",
    Wanted = "b59527dfe5520d0cd523a37e7ddf2b47",
    ProjectSlayers = "9955c61131117e72e978555014354b74",
    Hypershot = "df41b2339aac3a6c2e5b10079fd0a0f7",
    WantedBreakAndStealAnEgg = "e47e9632261b3364b61f4442e3a03571",
    AnimeEyesFlick = "4fa70478d26de77a26c693dc707b4025",
    HypershotVenomEvolution = "8934f8215d1c598724cbbf2d65308305",
    ProjectSlayersSpiderArm = "08a06d4201aadf0d1eaf19cda5c9256a",
    AOTR = "a63c0c5667d3bff2e6b5416d51e03769",
    ABizarreRun = "1beffe3e89f9490b79c1f8d37520d1ee",
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
local ProjectSlayersSpiderArmScriptId = LuarmorScriptIds.ProjectSlayersSpiderArm or ""

local Games = {
    {
        -- menu, Town Central (lobby), Trade Central and every mission/raid map
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
        LuarmorScriptId = LuarmorScriptIds.UrbanReload or "",
        GetKeyUrl       = LuarmorAdUrls.UrbanReload or LuarmorAdUrls.Default or "",
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
        LuarmorScriptId = ProjectSlayersSpiderArmScriptId ~= "" and ProjectSlayersSpiderArmScriptId or LuarmorScriptIds.ProjectSlayers or "",
        GetKeyUrl       = LuarmorAdUrls.ProjectSlayersSpiderArm or LuarmorAdUrls.ProjectSlayers or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 117734411290994, 76196077709659, 101278483792069 },
        UniverseId      = 10771997908,
        GameName        = "+1 Spider Arm",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = ProjectSlayersSpiderArmScriptId,
        GetKeyUrl       = LuarmorAdUrls.ProjectSlayersSpiderArm or LuarmorAdUrls.SpiderArm or LuarmorAdUrls.Default or "",
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
        LuarmorScriptId = LuarmorScriptIds.ABizarreRun or "",
        GetKeyUrl       = LuarmorAdUrls.ABizarreRun or LuarmorAdUrls.Default or "",
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

local ObsidianLibrary
local function LoadObsidian()
    if ObsidianLibrary then return ObsidianLibrary end
    local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
    local okL, Library = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))() end)
    if not okL or not Library then return nil end
    Library.CornerRadius = 10
    local okT, ThemeManager = pcall(function() return loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))() end)
    if okT and ThemeManager then
        pcall(function()
            ThemeManager:SetLibrary(Library)
            ThemeManager:ApplyTheme("Tokyo Night")
        end)
    end
    pcall(function() Library:SetNotifySide("Right") end)
    ObsidianLibrary = Library
    return Library
end

local function Notify(title, text, duration)
    local Library = LoadObsidian()
    if Library and Library.Notify then
        local ok = pcall(function()
            Library:Notify({ Title = title, Description = text, Time = duration or 6 })
        end)
        if ok then return end
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 6,
        })
    end)
    warn(("[nobulem.wtf] %s: %s"):format(title, text))
end

local cfg = ResolveGame(game.PlaceId)
if not cfg then
    Notify(
        "Unsupported Game",
        ("nobulem.wtf does not currently support this game (PlaceId: %d)."):format(game.PlaceId),
        10
    )
    getgenv().nobulem_loader_started = nil
    return
end

local ResolvedName = (cfg.PlaceNames and cfg.PlaceNames[game.PlaceId]) or cfg.GameName

if cfg.LobbyPlaceIds and table.find(cfg.LobbyPlaceIds, game.PlaceId) then
    Notify(ResolvedName, "You're in the lobby. Please join a game, then execute again.", 10)
    getgenv().nobulem_loader_started = nil
    return
end

local scriptId = LuarmorScriptIds[game.PlaceId] or cfg.LuarmorScriptId
if type(scriptId) ~= "string" or #scriptId ~= 32 or not scriptId:match("^[0-9a-fA-F]+$") then
    Notify("Luarmor setup needed", "Set the Luarmor script ID for " .. ResolvedName .. " in loader.lua.", 10)
    getgenv().nobulem_loader_started = nil
    return
end

if cfg.Discontinued then
    Notify(
        ResolvedName,
        ("%s is currently discontinued for nobulem at this time. Please try again later."):format(ResolvedName),
        10
    )
    getgenv().nobulem_loader_started = nil
    return
end

getgenv().NobulemLoaderConfig = {
    PlaceId         = game.PlaceId,
    GameName        = ResolvedName,
    SaveFile        = cfg.SaveFile,
    LuarmorScriptId = scriptId,
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
        Notify("nobulem.wtf", "Discord invite copied to clipboard!", 5)
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

local ok, err = pcall(function()
    local source = game:HttpGet(KEYSYSTEM_URL)
    local chunk, compileErr = loadstring(source)
    if not chunk then error("compile: " .. tostring(compileErr)) end
    chunk(getgenv().NobulemLoaderConfig)
end)

if not ok then
    Notify("Loader Error", tostring(err), 10)
    getgenv().nobulem_loader_started = nil
    getgenv().NobulemLoaderConfig = nil
end
