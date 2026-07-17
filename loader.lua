if getgenv().nobulem_loader_started then return end
getgenv().nobulem_loader_started = true

local KEYSYSTEM_URL = ("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/key-system.lua")

local Games = {
    {
        PlaceIds        = { 87018676608089 },
        GameName        = "Pistol Arena",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 85207102870777, 90568084448279 },
        GameName        = "One Tap",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 99342262733194 },
        GameName        = "Randomizer Redux",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 5307215810 },
        GameName        = "Randomizer Legacy",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 119259569670784, 122446657157717, 126042865144779, 119259569670784, 96216501849190, 124955530864032, 114188007571146, 101571206862372, 90165746516953, 74424488747487, 119661268047775, 111189101942839, 113390337779988, 115517196855730, 109094919875208, 102220551718323, 90625015569871, 112261221918322, 92726474449929, 125154235269776 },
        GameName        = "Sniper Arena",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 4639625707 },
        GameName        = "War Tycoon",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 6847090259 },
        GameName        = "Bulked Up",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 136801880565837 },
        GameName        = "Flick",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 98927955463992, 114204398207377 },
        GameName        = "Survive Zombie Arena",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 134558434771720, 130736793665498, 91654345256890, 92216849541624, 95439417741900, 108281974227624, 124085311761907 },
        GameName        = "Arcade Basketball",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 13997264379, 13997018456, 13997531040 },
        GameName        = "Operations Siege",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 100040622766961 },
        GameName        = "Hypershot",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 94590879393563, 98784084213911, 96076204236629, 82097489006022 },
        GameName        = "Weird Gun Game",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 15555246249, 107316497864340, 76759187707484, 74400058410183, 121395544767340, 116147279609754, 70816182080869, 117482669510587 },
        GameName        = "Dogs of War",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 3678761576 },
        GameName        = "Entrenched",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 95721658376580 },
        GameName        = "Multicrew Tank Combat",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 6804602922 },
        GameName        = "1B Boxing",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    {
        PlaceIds        = { 17625359962, 129604661913557, 133215910299950, 117398147513099, 18126510175, 71874690745115 },
        GameName        = "Rivals",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
        Discontinued    = true,
    },
    {
        PlaceIds        = { 98800969324557 },
        GameName        = "Storage Hunters: Open World",
        SaveFile        = "nobulem_key.txt",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
}

local function ResolveGame(placeId)
    for _, entry in ipairs(Games) do
        for _, id in ipairs(entry.PlaceIds) do
            if id == placeId then return entry end
        end
    end
    return nil
end

local ObsidianLibrary
local function LoadObsidian()
    if ObsidianLibrary then return ObsidianLibrary end
    local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
    local okL, Library = pcall(function() return loadstring(game:HttpGet(repo .. "Library.lua"))() end)
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
    -- Syscure is the routing source of truth. Unknown places are passed to its
    -- loader, which can use a newly-added mapping or its configured fallback.
    cfg = {
        GameName  = game.Name or ("Place " .. tostring(game.PlaceId)),
        SaveFile  = "nobulem_key.txt",
        GetKeyUrl = "https://nobulem.wtf/key",
    }
end

if cfg.Discontinued then
    Notify(
        cfg.GameName,
        ("%s is currently discontinued for nobulem at this time. Please try again later."):format(cfg.GameName),
        10
    )
    getgenv().nobulem_loader_started = nil
    return
end

getgenv().NobulemLoaderConfig = {
    PlaceId          = game.PlaceId,
    GameName         = cfg.GameName,
    SaveFile         = cfg.SaveFile,
    GetKeyUrl        = cfg.GetKeyUrl,
    SyscureLoaderId  = "b210d4a5705efb0abe7c5590",
    SyscureLoaderUrl = "https://auth.syscure.vip/loader/b210d4a5705efb0abe7c5590.lua",
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
    loadstring(game:HttpGet(KEYSYSTEM_URL))()
end)

if not ok then
    Notify("Loader Error", tostring(err), 10)
    getgenv().nobulem_loader_started = nil
    getgenv().NobulemLoaderConfig = nil
end
