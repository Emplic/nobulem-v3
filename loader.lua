if getgenv().nobulem_loader_started then return end
getgenv().nobulem_loader_started = true

local KEYSYSTEM_URL = ("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/key-system.lua")

local LuarmorScriptIds = {
    WarTycoon = "450d986ceeb9678f3455712371a99053",
    Flick = "2d3b779daff5c319a93d5d8f38b1bdc0",
    WarRivals = "c6d70ed6afc7fcb69b5d72b8d40491b7",
    SCPRoleplay = "916111fd797faab13af7b223958c2a98",
    ProjectSlayers = "9955c61131117e72e978555014354b74",
}
local LuarmorAdUrls = {
    Linkvertise = "https://ads.luarmor.net/get_key?for=Linkvertise-WNOSNrUbmMHZ",
    WorkInk = "https://ads.luarmor.net/get_key?for=Work_ink-ENZrHfPIitmN",
}

for name, id in pairs(getgenv().NobulemLuarmorScriptIds or {}) do LuarmorScriptIds[name] = id end
for name, url in pairs(getgenv().NobulemLuarmorAdUrls or {}) do LuarmorAdUrls[name] = url end

local Games = {
    {
        PlaceIds        = { 4639625707 },
        GameName        = "War Tycoon",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.WarTycoon or "",
        GetKeyUrl       = LuarmorAdUrls.WarTycoon or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 136801880565837 },
        GameName        = "Flick",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.Flick or "",
        GetKeyUrl       = LuarmorAdUrls.Flick or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 121918565917280 },
        GameName        = "War Rivals",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.WarRivals or "",
        GetKeyUrl       = LuarmorAdUrls.WarRivals or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 5041144419, 6939657427, 10953555034},
        GameName        = "SCP: Roleplay",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.SCPRoleplay or "",
        GetKeyUrl       = LuarmorAdUrls.SCPRoleplay or LuarmorAdUrls.Default or "",
    },
    {
        PlaceIds        = { 136406881576517, 13883059853, 11468075017, 5956785391, 9627847912, 75556147183481},
        GameName        = "Project Slayers 2",
        SaveFile        = "nobulem_key.txt",
        LuarmorScriptId = LuarmorScriptIds.ProjectSlayers or "",
        GetKeyUrl       = LuarmorAdUrls.ProjectSlayers or LuarmorAdUrls.Default or "",
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
    local okL, Library = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/offperms/nobulem/refs/heads/main/library.lua"))() end)
    if not okL or not Library then return nil end
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
    WorkInkUrl      = LuarmorAdUrls.WorkInk,
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

task.spawn(InviteDiscord)

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
