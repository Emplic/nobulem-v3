if getgenv().nobulem_loader_started then return end
getgenv().nobulem_loader_started = true

local KEYSYSTEM_URL = ("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/key-system.lua")

local Games = {
    [87018676608089] = {
        GameName        = "Pistol Arena",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "69589197133432135098",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [85207102870777] = {
        GameName        = "One Tap",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "30705437441887937520",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [99342262733194] = {
        GameName        = "Randomizer Redux",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "29407075271633530921",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [5307215810] = {
        GameName        = "Randomizer Legacy",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "38307661723468074678",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [119259569670784] = {
        GameName        = "Sniper Arena",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "72877165672068346715",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [4639625707] = {
        GameName        = "War Tycoon",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "49408082951445804304",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [6847090259] = {
        GameName        = "Bulked Up",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "91444182629983667670",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
    [136801880565837] = {
        GameName        = "Flick",
        SaveFile        = "nobulem_key.txt",
        LuaProtScriptId = "69056539903019355219",
        GetKeyUrl       = "https://nobulem.wtf/key",
    },
}

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

local cfg = Games[game.PlaceId]
if not cfg then
    Notify(
        "Unsupported Game",
        ("nobulem.wtf does not currently support this game (PlaceId: %d)."):format(game.PlaceId),
        10
    )
    getgenv().nobulem_loader_started = nil
    return
end

getgenv().NobulemLoaderConfig = {
    PlaceId         = game.PlaceId,
    GameName        = cfg.GameName,
    SaveFile        = cfg.SaveFile,
    LuaProtScriptId = cfg.LuaProtScriptId,
    GetKeyUrl       = cfg.GetKeyUrl,
}

local ok, err = pcall(function()
    loadstring(game:HttpGet(KEYSYSTEM_URL))()
end)

if not ok then
    Notify("Loader Error", tostring(err), 10)
    getgenv().nobulem_loader_started = nil
    getgenv().NobulemLoaderConfig = nil
end
