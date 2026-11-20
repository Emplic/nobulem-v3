do
    local NobulemFooterEnv = getgenv()
    NobulemFooterEnv.NobulemCreateBlossomWindow = function(Blossom, Info)
        local Window = Blossom.new(Info)
        local Base = type(Info) == "table" and type(Info.Build) == "string" and Info.Build or ""
        local BuildLabel
        local Native = type(Window.SetWatermarkBuild) == "function"
        if not Native then
            for _, Child in ipairs(Window.Watermark and Window.Watermark:GetChildren() or {}) do
                if Child:IsA("TextLabel") and Child.Text == Base then BuildLabel = Child break end
            end
            if not BuildLabel then return Window end
        end
        local Shown
        local function KeyText()
            local KeyInfo = NobulemFooterEnv.NobulemKeyInfo
            if type(KeyInfo) ~= "table" then return nil end
            if KeyInfo.Lifetime then return "Lifetime" end
            local ExpiresAt = tonumber(KeyInfo.ExpiresAt)
            if not ExpiresAt then return nil end
            local Left = math.floor(ExpiresAt - os.time())
            if Left <= 0 then return "Key expired" end
            local Days, Hours, Minutes, Seconds = Left // 86400, Left % 86400 // 3600, Left % 3600 // 60, Left % 60
            if Days > 0 then return string.format("%dd %dh %dm left", Days, Hours, Minutes) end
            if Hours > 0 then return string.format("%dh %dm left", Hours, Minutes) end
            return string.format("%dm %ds left", Minutes, Seconds)
        end
        local function Render()
            local Extra = KeyText()
            local Text = Extra and (Base ~= "" and Base .. " | " .. Extra or Extra) or Base
            if Native then
                if Text ~= Shown then
                    Shown = Text
                    Window:SetWatermarkBuild(Text)
                end
            elseif BuildLabel.Text ~= Text then
                BuildLabel.Text = Text
            end
        end
        local function Alive()
            if Native then return Window.Watermark and Window.Watermark.Parent end
            return BuildLabel.Parent
        end
        Render()
        task.spawn(function()
            while Alive() do
                task.wait(1)
                pcall(Render)
            end
        end)
        return Window
    end
end

local Environment = getgenv and getgenv() or _G
local Previous = Environment.NobulemBloxNG
if Previous and Previous.Unload then pcall(Previous.Unload) end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local SoftBody = ReplicatedStorage:WaitForChild("SoftBody", 20)
assert(SoftBody, "Nobulem: SoftBody missing, is this BloxNG?")
local Remotes = SoftBody:WaitForChild("Remotes", 20)
assert(Remotes, "Nobulem: SoftBody.Remotes missing")

local LOGO = "rbxassetid://138831083704120"
local WEB_LOGO = "https://cdn.discordapp.com/icons/1412397197705871376/5e4cd3efcc6f59fe7f3678e41d3d52b9.png?size=128"
local LOADER_SOURCE = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/loader.lua"))()]]
local DATA_FOLDER = "nobulem_bloxng"
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local KNOWN_CODES = {"GARAGE"}
local MAPS = {motorway = "Motorway", valley = "Desert Valley", canyon = "Canyon"}
local MAP_IDS = {Motorway = "motorway", ["Desert Valley"] = "valley", Canyon = "canyon"}

-- server caps read from ReplicatedStorage.Economy (falls back to the values seen on release)
local Economy = {SkillRate = 0.12, SkillMax = 6000, SkillPerMinute = 4000, CrashMax = 1800, CrashPerMinute = 2160,
    DrivePerMinute = 1300, TotaledAt = 0.55}
do
    local done = false
    task.spawn(function()
        pcall(function()
            local loaded = require(ReplicatedStorage:WaitForChild("Economy", 5))
            for key, v in pairs(loaded) do if type(v) == "number" then Economy[key] = v end end
        end)
        done = true
    end)
    local started = os.clock()
    while not done and os.clock() - started < 6 do task.wait() end
end

local Runtime = {Alive = true, Connections = {}, Threads = {}, Changed = {}, Error = "", Started = os.clock(),
    Earned = 0, EarnedBy = {}, Crashes = 0, Repairs = 0, SkillBanks = 0}
Environment.NobulemBloxNG = Runtime
local Library, Window, Esp
local Options, Toggles = {}, {}

---------------------------------------------------------------- core helpers

local function on(id)
    return Toggles[id] and Toggles[id].Value == true or false
end

local function value(id, fallback)
    local option = Options[id]
    if option and option.Value ~= nil then return option.Value end
    return fallback
end

local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        if Runtime.Alive then callback(...) end
    end)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function launch(callback)
    if not Runtime.Alive then return end
    local thread = coroutine.create(function()
        local ok, err = xpcall(callback, debug.traceback)
        Runtime.Threads[coroutine.running()] = nil
        if not ok and Runtime.Alive then Runtime.Error = tostring(err); warn("[Nobulem BloxNG] " .. Runtime.Error) end
    end)
    Runtime.Threads[thread] = true
    task.spawn(thread)
    return thread
end

-- runs `step` every `delay` seconds while the toggle is on; errors are kept, not thrown
local function loop(id, delay, step)
    launch(function()
        while Runtime.Alive do
            if on(id) then
                local ok, err = xpcall(step, debug.traceback)
                if not ok then Runtime.Error = tostring(err) end
            end
            task.wait(type(delay) == "function" and delay() or delay)
        end
    end)
end

local function notify(text)
    if Runtime.Alive and Window and Window.Notify then
        pcall(Window.Notify, Window, {Text = tostring(text), Duration = 4})
    end
end

local function change(object, key, desired)
    local changes = Runtime.Changed[object]
    if not changes then changes = {}; Runtime.Changed[object] = changes end
    if not changes[key] then changes[key] = {Original = object[key]} end
    changes[key].Applied = desired
    object[key] = desired
end

local function restore(object, key)
    local changes = Runtime.Changed[object]
    local entry = changes and changes[key]
    if not entry then return end
    pcall(function() object[key] = entry.Original end)
    changes[key] = nil
    if not next(changes) then Runtime.Changed[object] = nil end
end

local function fetch(url, label)
    local ok, source = pcall(game.HttpGet, game, url)
    assert(ok and type(source) == "string" and #source > 0, label .. " download failed: " .. tostring(source))
    local chunk, err = loadstring(source, "Nobulem/" .. label)
    assert(chunk, label .. " compile failed: " .. tostring(err))
    return chunk()
end

local function remote(name)
    return Remotes:FindFirstChild(name)
end

local function fire(name, ...)
    local object = remote(name)
    if object then pcall(object.FireServer, object, ...) end
end

local function invokeObject(object, ...)
    if not object then return end
    local result = table.pack(pcall(object.InvokeServer, object, ...))
    if not result[1] then Runtime.Error = tostring(result[2]); return end
    return table.unpack(result, 2, result.n)
end

local function invoke(name, ...)
    return invokeObject(remote(name), ...)
end

local function command(...)
    fire("CarCommand", ...)
end

local function formatMoney(amount)
    amount = math.floor((tonumber(amount) or 0) + 0.5)
    local text = tostring(math.abs(amount)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (amount < 0 and "-$" or "$") .. text
end

local function character()
    return Player.Character
end

-- small json files next to the Blossom configs (lifetime stats, waypoints)
local function readData(name, fallback)
    if not (isfile and readfile) then return fallback end
    local ok, decoded = pcall(function()
        local path = DATA_FOLDER .. "/" .. name .. ".json"
        if not isfile(path) then return nil end
        return HttpService:JSONDecode(readfile(path))
    end)
    return ok and type(decoded) == "table" and decoded or fallback
end

local function writeData(name, data)
    if not writefile then return end
    pcall(function()
        if makefolder and isfolder and not isfolder(DATA_FOLDER) then makefolder(DATA_FOLDER) end
        writefile(DATA_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
end

local LoaderQueued = false
local function queueLoader()
    if LoaderQueued or not (Toggles.AutoExecute and Toggles.AutoExecute.Value) then return end
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(queue) == "function" and pcall(queue, LOADER_SOURCE) then LoaderQueued = true end
end

local function rejoin()
    queueLoader()
    if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, Player)
    else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end
end

local function postWebhook(url, embed)
    url = tostring(url or "")
    if not url:match("^https://") then return false, "Webhook URL must start with https://" end
    local http = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if type(http) ~= "function" then return false, "Executor has no request function" end
    embed.author = {name = "nobulem.wtf", icon_url = WEB_LOGO}
    embed.footer = {text = "nobulem.wtf  \u{2022}  BloxNG", icon_url = WEB_LOGO}
    embed.timestamp = DateTime.now():ToIsoDate()
    embed.color = embed.color or 0x8B5CF6
    local body = HttpService:JSONEncode({username = "nobulem.wtf", avatar_url = WEB_LOGO, embeds = {embed}})
    local ok, response = pcall(http, {Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
    if not ok then return false, tostring(response) end
    local code = type(response) == "table" and tonumber(response.StatusCode) or 204
    return code >= 200 and code < 300, "HTTP " .. tostring(code)
end

local function root()
    local model = character()
    return model and model:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local model = character()
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function sortedKeys(set)
    local list = {}
    for key in pairs(set) do table.insert(list, key) end
    table.sort(list)
    return list
end

---------------------------------------------------------------- game layer

local Game = {}

function Game.carsFolder()
    local crash = workspace:FindFirstChild("CrashTest")
    return crash and crash:FindFirstChild("Cars")
end

function Game.cars()
    local folder = Game.carsFolder()
    return folder and folder:GetChildren() or {}
end

function Game.myCar()
    for _, model in ipairs(Game.cars()) do
        if model:GetAttribute("Owner") == Player.UserId and model:FindFirstChild("Hull") then return model end
    end
end

function Game.carOf(player)
    for _, model in ipairs(Game.cars()) do
        if model:GetAttribute("Owner") == player.UserId and model:FindFirstChild("Hull") then return model end
    end
end

-- the car a player is actually sitting in (their own or someone else's)
function Game.drivenCar(player)
    local model = player.Character
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat then return nil end
    local folder = Game.carsFolder()
    local car = seat
    while car and car.Parent ~= folder do car = car.Parent end
    return car
end

function Game.seated()
    local car = Game.myCar()
    local hum = humanoid()
    return car ~= nil and hum ~= nil and hum.SeatPart ~= nil and hum.SeatPart:IsDescendantOf(car), car
end

function Game.isTraffic(model)
    return model:GetAttribute("AI") ~= nil and not model:GetAttribute("Police")
end

function Game.isPolice(model)
    return model:GetAttribute("Police") == true
end

function Game.owned()
    local set = {}
    for kind in tostring(Player:GetAttribute("OwnedCars") or ""):gmatch("[^,]+") do set[kind] = true end
    return set
end

function Game.money()
    return tonumber(Player:GetAttribute("Money")) or 0
end

function Game.hub()
    local crash = workspace:FindFirstChild("CrashTest")
    local map = crash and crash:FindFirstChild("Map")
    return map and map:FindFirstChild("SpawnHub")
end

-- SpawnHub is a folder, so measure from its spawn pad
function Game.hubPosition()
    local hub = Game.hub()
    local spawn = hub and (hub:FindFirstChild("SpawnLocation") or hub:FindFirstChild("CarSpawns"))
    if not spawn then return nil end
    local ok, pivot = pcall(spawn.GetPivot, spawn)
    return ok and pivot.Position or nil
end

-- a big anchored piece of road/scenery; hitting it pays like a "Mega crash", so the farm never waits on traffic
function Game.crashSurface()
    local cached = Game.SurfaceCache
    if cached and cached.Parent then return cached end
    local hub, cars = Game.hub(), Game.carsFolder()
    for _, name in ipairs({"MotorwayMap_V2", "CanyonMap", "AdminMaps", "CrashTest"}) do
        local folder = workspace:FindFirstChild(name)
        if folder then
            for _, part in ipairs(folder:GetDescendants()) do
                if part:IsA("BasePart") and part.Anchored and part.Size.Magnitude > 20
                    and not (hub and part:IsDescendantOf(hub)) and not (cars and part:IsDescendantOf(cars)) then
                    Game.SurfaceCache = part
                    return part
                end
            end
        end
    end
end

-- nearest car worth crashing into (traffic, police when allowed), else a map surface
function Game.crashTarget(from, allowPolice)
    local best, bestScore
    for _, model in ipairs(Game.cars()) do
        local hull = model:FindFirstChild("Hull")
        if hull and model:GetAttribute("Owner") ~= Player.UserId and (Game.isTraffic(model) or (allowPolice and Game.isPolice(model))) then
            local score = from and (hull.Position - from).Magnitude or 0
            if not bestScore or score < bestScore then best, bestScore = hull, score end
        end
    end
    return best or Game.crashSurface()
end

function Game.entryOf(kind)
    for _, entry in ipairs(Game.catalog()) do if entry.kind == kind then return entry end end
end

-- the server stops paying distance once the car moves faster than it could really drive (~2x its mph in studs/s)
function Game.cruiseLimit(car)
    local entry = car and Game.entryOf(car:GetAttribute("Kind"))
    if entry and entry.topSpeed > 0 then return entry.topSpeed * 1.9 end
    return 190
end

-- sit back down in our car, or ask the server for one
function Game.ensureCar()
    local seated, car = Game.seated()
    if seated then return car end
    local hum = humanoid()
    if car and hum and hum.Health > 0 then
        local seat = car:FindFirstChild("DriverSeat")
        if seat and not seat.Occupant then
            local part = root()
            if part then part.CFrame = seat.CFrame + Vector3.new(0, 3, 0) end
            pcall(seat.Sit, seat, hum)
            task.wait(0.5)
            seated = Game.seated()
            if seated then return car end
        end
    end
    if os.clock() - (Runtime.LastRespawn or 0) > 6 then
        Runtime.LastRespawn = os.clock()
        command("respawn")
    end
    return nil
end

function Game.repair()
    Runtime.Repairs += 1
    command("repair")
end

-- moves whatever we are in (car when seated, character otherwise)
function Game.teleport(cframe)
    local seated, car = Game.seated()
    if seated and car then
        car:PivotTo(cframe + Vector3.new(0, 4, 0))
        local hull = car:FindFirstChild("Hull")
        if hull then hull.AssemblyLinearVelocity, hull.AssemblyAngularVelocity = Vector3.zero, Vector3.zero end
        return true
    end
    local model, part = character(), root()
    if not model or not part then return false end
    part.AssemblyLinearVelocity = Vector3.zero
    model:PivotTo(cframe + Vector3.new(0, 4, 0))
    return true
end

function Game.groundBelow(position)
    local params = RaycastParams.new()
    local ignore = {character()}
    local car = Game.myCar()
    if car then table.insert(ignore, car) end
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -3000, 0), params)
    return hit and hit.Position or Vector3.new(position.X, 3, position.Z)
end

-- game module code can yield and resume us at a lower thread identity, which breaks UI building;
-- so it always runs on a throwaway thread and only plain data comes back
local function isolated(callback)
    local done, result = false, nil
    task.spawn(function()
        result = table.pack(pcall(callback))
        done = true
    end)
    local started = os.clock()
    while not done and os.clock() - started < 10 do task.wait() end
    if not result or not result[1] then return nil end
    return table.unpack(result, 2, result.n)
end

function Game.catalog()
    if Game.CatalogCache and #Game.CatalogCache > 0 then return Game.CatalogCache end
    local list = isolated(function()
        local dealership = ReplicatedStorage:WaitForChild("Dealership", 5)
        local catalog = require(dealership:WaitForChild("Catalog", 5))
        local entries = catalog.Entries
        if type(catalog.dealerList) == "function" then
            local ok, listed = pcall(catalog.dealerList)
            if ok and type(listed) == "table" then entries = listed end
        end
        local out = {}
        for _, entry in ipairs(type(entries) == "table" and entries or {}) do
            if type(entry) == "table" and entry.kind then
                table.insert(out, {kind = tostring(entry.kind), name = tostring(entry.name or entry.kind), price = tonumber(entry.price) or 0,
                    pass = entry.pass ~= nil, class = tostring(entry.class or ""), topSpeed = tonumber(entry.topSpeed) or 0})
            end
        end
        return out
    end) or {}
    table.sort(list, function(a, b) return a.price < b.price end)
    Game.CatalogCache = list
    return list
end

function Game.buyable()
    local list = {}
    for _, entry in ipairs(Game.catalog()) do
        if not entry.pass and entry.price > 0 then table.insert(list, entry) end
    end
    return list
end

function Game.buy(kind)
    local purchase = ReplicatedStorage:FindFirstChild("Dealership")
    purchase = purchase and purchase:FindFirstChild("Remotes") and purchase.Remotes:FindFirstChild("Purchase")
    if not purchase then return false, "Dealership remote missing" end
    local ok, message = invokeObject(purchase, kind, "buy")
    return ok == true, message
end

function Game.bestOwned()
    local owned, best = Game.owned(), nil
    for _, entry in ipairs(Game.catalog()) do
        if owned[entry.kind] and (not best or entry.topSpeed > best.topSpeed) then best = entry end
    end
    return best
end

-- "Cheapest" = next unowned car by price; "Faster" = cheapest unowned car quicker than anything owned
function Game.nextCar(mode)
    local owned, best = Game.owned(), Game.bestOwned()
    for _, entry in ipairs(Game.buyable()) do
        if not owned[entry.kind] and (mode ~= "Faster" or not best or entry.topSpeed > best.topSpeed) then return entry end
    end
end

function Game.spawnCar(kind)
    local ok, message = invoke("Garage", kind)
    return ok == true, message
end

function Game.travel(id)
    local ok, message = invoke("MapTravel", id)
    return ok == true, message
end

function Game.redeem(code)
    local codes = ReplicatedStorage:FindFirstChild("Codes")
    local redeem = codes and codes:FindFirstChild("Redeem")
    if not redeem then return false, "Codes remote missing" end
    local ok, message = invokeObject(redeem, code)
    return ok == true, message
end

-- presses a visible gui button whose text matches; used to get through the start menu
function Game.pressButton(pattern)
    local gui = Player:FindFirstChildOfClass("PlayerGui")
    if not gui then return false end
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("GuiButton") and object.Visible then
            local text = object:IsA("TextButton") and object.Text or ""
            if text == "" then
                local label = object:FindFirstChildWhichIsA("TextLabel", true)
                text = label and label.Text or ""
            end
            if text:upper():match(pattern) then
                local shown, node = true, object
                while node and node ~= gui do
                    if node:IsA("GuiObject") and not node.Visible then shown = false break end
                    if node:IsA("ScreenGui") and not node.Enabled then shown = false break end
                    node = node.Parent
                end
                if shown and getconnections then
                    for _, signal in ipairs({object.Activated, object.MouseButton1Click, object.MouseButton1Down}) do
                        for _, conn in ipairs(getconnections(signal)) do pcall(function() conn:Fire() end) end
                    end
                    return true
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------- unload

local function unload()
    if not Runtime.Alive then return end
    Runtime.Alive = false
    for _, connection in ipairs(Runtime.Connections) do pcall(function() connection:Disconnect() end) end
    for thread in pairs(Runtime.Threads) do if thread ~= coroutine.running() then pcall(task.cancel, thread) end end
    for object, changes in pairs(Runtime.Changed) do
        for key in pairs(changes) do restore(object, key) end
    end
    if Runtime.SaveStats then pcall(Runtime.SaveStats) end
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if Runtime.Spectating then
        pcall(function() Camera.CameraSubject = humanoid() end)
    end
    if Runtime.Cruising and Runtime.CruiseHome then
        pcall(function()
            local car = Game.myCar()
            if car then
                car:PivotTo(Runtime.CruiseHome)
                car.Hull.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    end
    if Esp then pcall(Esp.Unload) end
    if Window and not Runtime.LibraryUnloading then
        Runtime.LibraryUnloading = true
        pcall(function() Window:Destroy() end)
    end
    if Environment.NobulemBloxNG == Runtime then Environment.NobulemBloxNG = nil end
end
Runtime.Unload = unload

---------------------------------------------------------------- esp (Sense, reworked for drivers in soft-body cars)

local function buildEsp()
    local floor, round, sin, cos = math.floor, math.round, math.sin, math.cos
    local clear = table.clear
    local wtvp = Camera.WorldToViewportPoint
    local lerpColor = Color3.new().Lerp
    local min2, max2, lerp2 = Vector2.zero.Min, Vector2.zero.Max, Vector2.zero.Lerp

    local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
    local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
    local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
    local NAME_OFFSET = Vector2.new(0, 2)
    local DISTANCE_OFFSET = Vector2.new(0, 2)
    local VERTICES = {
        Vector3.new(-1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(-1, -1, 1),
        Vector3.new(1, -1, -1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1), Vector3.new(1, -1, 1),
    }
    local container = Instance.new("Folder")
    container.Name = "NobulemChams"
    pcall(function() container.Parent = gethui and gethui() or game:GetService("CoreGui") end)

    local renderers, lastError = {}, nil
    local dispatch = RunService.RenderStepped:Connect(function()
        for _, callback in pairs(renderers) do
            local ok, err = pcall(callback)
            if not ok then lastError = tostring(err) end
        end
    end)
    local function bindRenderer(callback)
        local entry = {}
        function entry:Disconnect() renderers[self] = nil end
        renderers[entry] = callback
        return entry
    end

    local function worldToScreen(world)
        local screen, inBounds = wtvp(Camera, world)
        return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
    end

    local function calculateCorners(cframe, size)
        local corners = table.create(#VERTICES)
        for i = 1, #VERTICES do
            corners[i] = worldToScreen((cframe + cframe:VectorToWorldSpace(size * 0.5 * VERTICES[i])).Position)
        end
        local viewport = Camera.ViewportSize
        local min = min2(viewport, table.unpack(corners))
        local max = max2(Vector2.zero, table.unpack(corners))
        return {
            corners = corners,
            topLeft = Vector2.new(floor(min.X), floor(min.Y)),
            topRight = Vector2.new(floor(max.X), floor(min.Y)),
            bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
            bottomRight = Vector2.new(floor(max.X), floor(max.Y)),
        }
    end

    local function rotateVector(vector, radians)
        local x, y = vector.X, vector.Y
        local c, s = cos(radians), sin(radians)
        return Vector2.new(x * c - y * s, x * s + y * c)
    end

    local Esp = {_objectCache = {}, _labelCache = {}, settings = {
        enabled = false, maxDistance = 2000, textSize = 13, textFont = 2, useTeamColor = false,
        box = true, boxColor = {Color3.fromRGB(255, 90, 90), 1}, boxOutline = true, boxOutlineColor = {Color3.new(), 1},
        boxFill = false, boxFillColor = {Color3.fromRGB(255, 90, 90), 0.25},
        box3d = false, box3dColor = {Color3.fromRGB(255, 90, 90), 1},
        healthBar = true, healthyColor = Color3.fromRGB(80, 255, 120), dyingColor = Color3.fromRGB(255, 60, 60),
        healthBarOutline = true, healthBarOutlineColor = {Color3.new(), 0.5},
        healthText = false, healthTextColor = {Color3.new(1, 1, 1), 1}, healthTextOutline = true, healthTextOutlineColor = Color3.new(),
        name = true, nameColor = {Color3.new(1, 1, 1), 1}, nameOutline = true, nameOutlineColor = Color3.new(),
        vehicle = true, vehicleColor = {Color3.fromRGB(255, 200, 90), 1}, vehicleOutline = true, vehicleOutlineColor = Color3.new(),
        distance = true, distanceColor = {Color3.fromRGB(200, 200, 200), 1}, distanceOutline = true, distanceOutlineColor = Color3.new(),
        tracer = false, tracerOrigin = "Bottom", tracerColor = {Color3.fromRGB(255, 90, 90), 1}, tracerOutline = true, tracerOutlineColor = {Color3.new(), 1},
        offScreenArrow = false, offScreenArrowColor = {Color3.new(1, 1, 1), 1}, offScreenArrowSize = 15, offScreenArrowRadius = 150,
        offScreenArrowOutline = true, offScreenArrowOutlineColor = {Color3.new(), 1},
        chams = false, chamsVisibleOnly = false, chamsFillColor = {Color3.fromRGB(255, 90, 90), 0.6}, chamsOutlineColor = {Color3.fromRGB(255, 90, 90), 0},
    }}

    local function tint(self, color, isOutline)
        if Esp.settings.useTeamColor and not isOutline then
            local team = self.player.Team
            if team then return team.TeamColor.Color end
        end
        return color
    end

    local function prettyKind(kind)
        return tostring(kind or ""):gsub("V%d+$", ""):gsub("(%l)(%u)", "%1 %2")
    end

    -- player object: boxes the car they drive, or their body when on foot
    local EspObject = {}
    EspObject.__index = EspObject

    function EspObject.new(player)
        local self = setmetatable({player = player, bin = {}}, EspObject)
        local function make(class, properties)
            local drawing = Drawing.new(class)
            for property, v in next, properties do pcall(function() drawing[property] = v end) end
            self.bin[#self.bin + 1] = drawing
            return drawing
        end
        self.box3d = {}
        for face = 1, 4 do
            self.box3d[face] = {make("Line", {Thickness = 1, Visible = false}), make("Line", {Thickness = 1, Visible = false}),
                make("Line", {Thickness = 1, Visible = false})}
        end
        self.drawings = {
            tracerOutline = make("Line", {Thickness = 3, Visible = false}),
            tracer = make("Line", {Thickness = 1, Visible = false}),
            boxFill = make("Square", {Filled = true, Visible = false}),
            boxOutline = make("Square", {Thickness = 3, Visible = false}),
            box = make("Square", {Thickness = 1, Visible = false}),
            healthBarOutline = make("Line", {Thickness = 3, Visible = false}),
            healthBar = make("Line", {Thickness = 1, Visible = false}),
            healthText = make("Text", {Center = true, Visible = false}),
            name = make("Text", {Center = true, Visible = false}),
            vehicle = make("Text", {Center = true, Visible = false}),
            distance = make("Text", {Center = true, Visible = false}),
            arrowOutline = make("Triangle", {Thickness = 3, Visible = false}),
            arrow = make("Triangle", {Filled = true, Visible = false}),
        }
        self.highlight = Instance.new("Highlight")
        self.highlight.Enabled = false
        self.highlight.Parent = container
        self.renderConnection = bindRenderer(function()
            self:Update()
            self:Render()
        end)
        return self
    end

    function EspObject:Destruct()
        self.renderConnection:Disconnect()
        for i = 1, #self.bin do pcall(self.bin[i].Remove, self.bin[i]) end
        pcall(function() self.highlight:Destroy() end)
        clear(self)
    end

    function EspObject:Update()
        local settings = Esp.settings
        local player = self.player
        local body = player and player.Character
        local hum = body and body:FindFirstChildOfClass("Humanoid")
        self.enabled = settings.enabled and hum ~= nil and player ~= Player
        if not self.enabled then self.onScreen = false; self.target = nil; return end

        local car = Game.drivenCar(player)
        self.car = car
        self.target = car or body
        self.health, self.maxHealth = math.max(hum.Health, 0), math.max(hum.MaxHealth, 1)
        if car then
            -- in a car the bar shows how intact the car is
            local damage = tonumber(car:GetAttribute("Damage")) or 0
            self.health, self.maxHealth = math.clamp(1 - damage, 0, 1) * 100, 100
        end

        local ok, cframe, size = pcall(self.target.GetBoundingBox, self.target)
        if not ok then self.enabled, self.onScreen = false, false return end
        local _, onScreen = worldToScreen(cframe.Position)
        local eye = Camera.CFrame.Position
        self.distance = (cframe.Position - eye).Magnitude
        self.onScreen = onScreen
        if self.distance > settings.maxDistance then self.enabled, self.onScreen = false, false return end
        if onScreen then
            self.corners = calculateCorners(cframe, size)
        elseif settings.offScreenArrow then
            local camera = Camera.CFrame
            local flat = CFrame.fromMatrix(camera.Position, camera.RightVector, Vector3.yAxis)
            local objectSpace = flat:PointToObjectSpace(cframe.Position)
            self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit
        end
    end

    function EspObject:Render()
        local options, d = Esp.settings, self.drawings
        local enabled, onScreen, corners = self.enabled or false, self.onScreen or false, self.corners
        local viewport = Camera.ViewportSize
        local visible = enabled and onScreen

        d.box.Visible = visible and options.box
        d.boxOutline.Visible = d.box.Visible and options.boxOutline
        if d.box.Visible then
            d.box.Position = corners.topLeft
            d.box.Size = corners.bottomRight - corners.topLeft
            d.box.Color, d.box.Transparency = tint(self, options.boxColor[1]), options.boxColor[2]
            d.boxOutline.Position, d.boxOutline.Size = d.box.Position, d.box.Size
            d.boxOutline.Color, d.boxOutline.Transparency = options.boxOutlineColor[1], options.boxOutlineColor[2]
        end

        d.boxFill.Visible = visible and options.boxFill
        if d.boxFill.Visible then
            d.boxFill.Position = corners.topLeft
            d.boxFill.Size = corners.bottomRight - corners.topLeft
            d.boxFill.Color, d.boxFill.Transparency = tint(self, options.boxFillColor[1]), options.boxFillColor[2]
        end

        local ratio = self.health and self.health / self.maxHealth or 1
        d.healthBar.Visible = visible and options.healthBar
        d.healthBarOutline.Visible = d.healthBar.Visible and options.healthBarOutline
        if d.healthBar.Visible then
            local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
            local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
            d.healthBar.To = barTo
            d.healthBar.From = lerp2(barTo, barFrom, ratio)
            d.healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, ratio)
            d.healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
            d.healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
            d.healthBarOutline.Color, d.healthBarOutline.Transparency = options.healthBarOutlineColor[1], options.healthBarOutlineColor[2]
        end

        d.healthText.Visible = visible and options.healthText
        if d.healthText.Visible then
            local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
            local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET
            local text = d.healthText
            text.Text = round(self.health) .. (self.car and "%" or "hp")
            text.Size, text.Font = options.textSize, options.textFont
            text.Color, text.Transparency = options.healthTextColor[1], options.healthTextColor[2]
            text.Outline, text.OutlineColor = options.healthTextOutline, options.healthTextOutlineColor
            text.Position = lerp2(barTo, barFrom, ratio) - text.TextBounds * 0.5 - HEALTH_TEXT_OFFSET
        end

        local top = corners and (corners.topLeft + corners.topRight) * 0.5
        d.vehicle.Visible = visible and options.vehicle and self.car ~= nil
        if d.vehicle.Visible then
            local text = d.vehicle
            local speed = 0
            local hull = self.car:FindFirstChild("Hull")
            if hull then speed = hull.AssemblyLinearVelocity.Magnitude end
            text.Text = prettyKind(self.car:GetAttribute("Kind")) .. " | " .. round(speed) .. " sps"
            text.Size, text.Font = options.textSize, options.textFont
            text.Color, text.Transparency = options.vehicleColor[1], options.vehicleColor[2]
            text.Outline, text.OutlineColor = options.vehicleOutline, options.vehicleOutlineColor
            text.Position = top - Vector2.yAxis * text.TextBounds.Y - NAME_OFFSET
            top = text.Position
        end

        d.name.Visible = visible and options.name
        if d.name.Visible then
            local name = d.name
            name.Text = self.player.DisplayName
            name.Size, name.Font = options.textSize, options.textFont
            name.Color, name.Transparency = tint(self, options.nameColor[1]), options.nameColor[2]
            name.Outline, name.OutlineColor = options.nameOutline, options.nameOutlineColor
            name.Position = top - Vector2.yAxis * name.TextBounds.Y - (d.vehicle.Visible and Vector2.zero or NAME_OFFSET)
        end

        d.distance.Visible = visible and options.distance and self.distance ~= nil
        if d.distance.Visible then
            local distance = d.distance
            distance.Text = round(self.distance) .. " studs"
            distance.Size, distance.Font = options.textSize, options.textFont
            distance.Color, distance.Transparency = options.distanceColor[1], options.distanceColor[2]
            distance.Outline, distance.OutlineColor = options.distanceOutline, options.distanceOutlineColor
            distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET
        end

        d.tracer.Visible = visible and options.tracer
        d.tracerOutline.Visible = d.tracer.Visible and options.tracerOutline
        if d.tracer.Visible then
            d.tracer.Color, d.tracer.Transparency = tint(self, options.tracerColor[1]), options.tracerColor[2]
            d.tracer.To = (corners.bottomLeft + corners.bottomRight) * 0.5
            d.tracer.From = options.tracerOrigin == "Middle" and viewport * 0.5
                or options.tracerOrigin == "Top" and viewport * Vector2.new(0.5, 0)
                or options.tracerOrigin == "Mouse" and Input:GetMouseLocation()
                or viewport * Vector2.new(0.5, 1)
            d.tracerOutline.Color, d.tracerOutline.Transparency = options.tracerOutlineColor[1], options.tracerOutlineColor[2]
            d.tracerOutline.To, d.tracerOutline.From = d.tracer.To, d.tracer.From
        end

        d.arrow.Visible = enabled and not onScreen and options.offScreenArrow and self.direction ~= nil
        d.arrowOutline.Visible = d.arrow.Visible and options.offScreenArrowOutline
        if d.arrow.Visible then
            local arrow = d.arrow
            arrow.PointA = min2(max2(viewport * 0.5 + self.direction * options.offScreenArrowRadius, Vector2.one * 25), viewport - Vector2.one * 25)
            arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45) * options.offScreenArrowSize
            arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45) * options.offScreenArrowSize
            arrow.Color, arrow.Transparency = tint(self, options.offScreenArrowColor[1]), options.offScreenArrowColor[2]
            d.arrowOutline.PointA, d.arrowOutline.PointB, d.arrowOutline.PointC = arrow.PointA, arrow.PointB, arrow.PointC
            d.arrowOutline.Color, d.arrowOutline.Transparency = options.offScreenArrowOutlineColor[1], options.offScreenArrowOutlineColor[2]
        end

        local box3dEnabled = visible and options.box3d
        for i = 1, 4 do
            local face = self.box3d[i]
            for i2 = 1, 3 do
                local line = face[i2]
                line.Visible = box3dEnabled
                line.Color, line.Transparency = tint(self, options.box3dColor[1]), options.box3dColor[2]
            end
            if box3dEnabled then
                local c = corners.corners
                face[1].From, face[1].To = c[i], c[i == 4 and 1 or i + 1]
                face[2].From, face[2].To = c[i == 4 and 1 or i + 1], c[i == 4 and 5 or i + 5]
                face[3].From, face[3].To = c[i == 4 and 5 or i + 5], c[i == 4 and 8 or i + 4]
            end
        end

        local highlight = self.highlight
        local chams = enabled and options.chams and self.target ~= nil
        highlight.Enabled = chams
        if chams then
            highlight.Adornee = self.target
            highlight.FillColor, highlight.FillTransparency = tint(self, options.chamsFillColor[1]), options.chamsFillColor[2]
            highlight.OutlineColor, highlight.OutlineTransparency = tint(self, options.chamsOutlineColor[1], true), options.chamsOutlineColor[2]
            highlight.DepthMode = options.chamsVisibleOnly and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    -- world label (Sense's InstanceObject), pooled per instance
    local LabelObject = {}
    LabelObject.__index = LabelObject

    function LabelObject.new(instance, options)
        local self = setmetatable({instance = instance, options = options}, LabelObject)
        self.text = Drawing.new("Text")
        self.text.Center = true
        self.renderConnection = bindRenderer(function() self:Render() end)
        return self
    end

    function LabelObject:Destruct()
        self.renderConnection:Disconnect()
        pcall(self.text.Remove, self.text)
        clear(self)
    end

    function LabelObject:Render()
        local instance, text, options = self.instance, self.text, self.options
        if not instance or not instance.Parent or not options.enabled then text.Visible = false return end
        local ok, pivot = pcall(instance.GetPivot, instance)
        if not ok then text.Visible = false return end
        local world = pivot.Position + Vector3.new(0, options.lift or 4, 0)
        local position, visible = worldToScreen(world)
        local depth = (world - Camera.CFrame.Position).Magnitude
        if options.maxDistance and depth > options.maxDistance then visible = false end
        text.Visible = visible
        if not visible then return end
        text.Position = position
        text.Color, text.Transparency = options.textColor[1], options.textColor[2]
        text.Outline, text.OutlineColor = true, Color3.new()
        text.Size, text.Font = Esp.settings.textSize, Esp.settings.textFont
        local label = type(options.text) == "function" and options.text(instance) or tostring(options.text or instance.Name)
        text.Text = label:gsub("{distance}", tostring(round(depth)))
    end

    function Esp.AddPlayer(player)
        if Esp._objectCache[player] or player == Player then return end
        Esp._objectCache[player] = EspObject.new(player)
    end

    function Esp.RemovePlayer(player)
        local object = Esp._objectCache[player]
        if object then object:Destruct(); Esp._objectCache[player] = nil end
    end

    function Esp.AddLabel(instance, options)
        local object = Esp._labelCache[instance]
        if object then object.options = options return object end
        object = LabelObject.new(instance, options)
        Esp._labelCache[instance] = object
        return object
    end

    function Esp.RemoveLabel(instance)
        local object = Esp._labelCache[instance]
        if object then object:Destruct(); Esp._labelCache[instance] = nil end
    end

    function Esp.GetLastError() return lastError end

    function Esp.Unload()
        dispatch:Disconnect()
        for player in pairs(Esp._objectCache) do Esp.RemovePlayer(player) end
        for instance in pairs(Esp._labelCache) do Esp.RemoveLabel(instance) end
        pcall(function() container:Destroy() end)
    end

    Esp.prettyKind = prettyKind
    return Esp
end

---------------------------------------------------------------- setup

local function setup()
    Library = fetch("https://raw.githubusercontent.com/Emplic/nobulem-v3/refs/heads/main/blossom.lua", "Blossom")
    Runtime.Library = Library
    Options, Toggles = {}, {}
    Runtime.Options, Runtime.Toggles = Options, Toggles
    local view = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
    local width = math.clamp(math.floor(view.X - 40), 480, 700)
    local height = math.clamp(math.floor(view.Y - 40), 300, 520)
    Window = getgenv().NobulemCreateBlossomWindow(Library, {
        Title = "nobulem.wtf",
        Logo = LOGO,
        Script = "nobulem.wtf",
        Build = "BloxNG | " .. (MAPS[Player:GetAttribute("Map")] or "Motorway"),
        ConfigFolder = "nobulem_bloxng/blossom",
        Size = Vector2.new(width, height),
        MinSize = Vector2.new(math.min(520, width), math.min(380, height)),
    })

    local Tabs = {}
    Tabs.Home = Window:Tab({Name = "Home", Icon = "house"})
    Window:Category("Money")
    Tabs.Farm = Window:Tab({Name = "Auto Farm", Icon = "tractor"})
    Tabs.Shop = Window:Tab({Name = "Dealership", Icon = "shopping-cart"})
    Window:Category("Driving")
    Tabs.Vehicle = Window:Tab({Name = "Vehicle", Icon = "car"})
    Tabs.Player = Window:Tab({Name = "Player", Icon = "footprints"})
    Tabs.Teleport = Window:Tab({Name = "Teleport", Icon = "map"})
    Window:Category("Visuals")
    Tabs.Visuals = Window:Tab({Name = "Visuals", Icon = "eye"})
    Window:Category("Other")
    Tabs.Misc = Window:Tab({Name = "Misc", Icon = "settings-2"})
    Tabs.Settings = Window:Tab({Name = "Settings", Icon = "settings"})
    Runtime.Tabs = Tabs

    -- Blossom keeps state on the element, so give each one the Options/Toggles shape the rest of the script reads.
    local function control(store, id, object, callback)
        object.Changed = {}
        object.Callback = function(...)
            if callback then callback(...) end
            for _, fn in ipairs(object.Changed) do pcall(fn, ...) end
        end
        function object:SetValue(v)
            if self.Multi and type(v) == "table" then
                local list = {}
                for key, state in pairs(v) do
                    if type(key) == "number" then table.insert(list, state) elseif state then table.insert(list, key) end
                end
                v = list
            end
            self:Set(v)
        end
        function object:OnChanged(fn) table.insert(self.Changed, fn) end
        if object.SetOptions then
            local setOptions = object.SetOptions
            function object:SetValues(list) setOptions(self, list) end
        end
        store[id] = object
        return object
    end
    local function section(tab, side, name, icon, description)
        return tab:Section({Name = name, Icon = icon, Side = side, Description = description})
    end
    local function toggle(box, id, text, default, callback, keybind)
        local object = box:Toggle({Name = text, Default = default or false, Flag = id,
            Keybind = keybind and Enum.KeyCode.Unknown or nil, KeybindName = keybind})
        if object.Keybind then object.Keybind:Set(nil) end
        return control(Toggles, id, object, callback)
    end
    local function slider(box, id, text, default, low, high, decimals, callback)
        return control(Options, id, box:Slider({Name = text, Default = default, Min = low, Max = high, Decimals = decimals or 0, Flag = id}), callback)
    end
    local function dropdown(box, id, text, values, default, callback, multi)
        return control(Options, id, box:Dropdown({Name = text, Options = values, Default = default, Multi = multi == true, MaxRows = 8, Flag = id}), callback)
    end
    local function color(box, id, text, default)
        return control(Options, id, box:Colorpicker({Name = text, Default = default, Flag = id}), nil)
    end
    local function textbox(box, id, text, placeholder, noSave)
        return control(Options, id, box:Textbox({Name = text, Placeholder = placeholder, Default = "", Flag = id, NoSave = noSave}), nil)
    end
    local function button(box, text, callback)
        return box:Button({Name = text, Callback = function() task.spawn(callback) end})
    end
    local function info(box, text)
        local object = box:Label({Name = text})
        local inst = object.Instance
        if inst then inst.TextTruncate = Enum.TextTruncate.AtEnd end
        object.Raw = text
        function object:SetText(new)
            new = tostring(new)
            if self.Raw == new then return end
            self.Raw = new
            self:Set(new)
        end
        return object
    end

    local function carNames()
        local list = {}
        for _, entry in ipairs(Game.buyable()) do table.insert(list, entry.name .. " (" .. formatMoney(entry.price) .. ")") end
        return #list > 0 and list or {"none"}
    end
    local function entryFromLabel(label)
        for _, entry in ipairs(Game.catalog()) do
            if label and label:sub(1, #entry.name + 2) == entry.name .. " (" then return entry end
        end
    end
    local function ownedNames()
        local list, owned = {}, Game.owned()
        for _, entry in ipairs(Game.catalog()) do if owned[entry.kind] then table.insert(list, entry.name) end end
        for kind in pairs(owned) do
            local found = false
            for _, entry in ipairs(Game.catalog()) do if entry.kind == kind then found = true break end end
            if not found then table.insert(list, kind) end
        end
        table.sort(list)
        return #list > 0 and list or {"none"}
    end
    local function kindFromName(name)
        for _, entry in ipairs(Game.catalog()) do if entry.name == name then return entry.kind end end
        return name
    end
    local function playerNames()
        local list = {}
        for _, other in ipairs(Players:GetPlayers()) do if other ~= Player then table.insert(list, other.Name) end end
        table.sort(list)
        return #list > 0 and list or {"none"}
    end

    ---------------------------------------------------------------- Home
    local statusLabel, moneyLabel, rateLabel, breakdownLabel, errorLabel, nextLabel, lifetimeLabel, bestLabel
    do
        local session = section(Tabs.Home, 1, "Session", "activity", "Live status")
        statusLabel = info(session, "Car: waiting")
        moneyLabel = info(session, "Money: " .. formatMoney(Game.money()))
        rateLabel = info(session, "Earned: $0")
        breakdownLabel = info(session, "Sources: none yet")
        nextLabel = info(session, "Next car: checking")
        errorLabel = info(session, "Runtime: ready")
        local lifetime = section(Tabs.Home, 2, "Lifetime", "trophy", "Kept across rejoins")
        lifetimeLabel = info(lifetime, "Total: $0")
        bestLabel = info(lifetime, "Best rate: $0/min")
        button(lifetime, "Reset lifetime stats", function()
            Runtime.Stats = {Earned = 0, Minutes = 0, BestRate = 0, Sessions = 1}
            Runtime.StatsBase = {Earned = Runtime.Earned, Clock = os.clock()}
            if Runtime.SaveStats then Runtime.SaveStats() end
            notify("Lifetime stats reset")
        end)
        button(session, "Stop all automation", function()
            for id, object in pairs(Toggles) do
                if id ~= "AntiAFK" and id:sub(1, 3) ~= "Esp" and object.Value then object:SetValue(false) end
            end
            notify("Stopped")
        end)
        local about = section(Tabs.Home, 2, "About", "info")
        info(about, "Money: skill chains, crashes, wrecks, distance.")
        info(about, "Auto Farm flies your car in a loop off the road.")
        info(about, "The server caps each source per minute.")
        info(about, "Toggles with a key chip can be bound from the UI.")
    end

    ---------------------------------------------------------------- Auto Farm
    do
        local main = section(Tabs.Farm, 1, "Auto Farm", "tractor", "Every money source at the server's limit")
        toggle(main, "AutoFarm", "Auto Farm (everything)", false, function(state)
            for _, id in ipairs({"FarmSkill", "FarmCrash", "FarmDrive"}) do
                if Toggles[id] and Toggles[id].Value ~= state then Toggles[id]:SetValue(state) end
            end
        end, "Auto Farm")
        toggle(main, "FarmSkill", "Skill Chains", false)
        toggle(main, "FarmCrash", "Crash + Wreck Payouts", false)
        toggle(main, "FarmDrive", "Distance Driving", false)
        toggle(main, "FarmAutoCar", "Auto spawn / re-enter car", true)
        toggle(main, "FarmWatchdog", "Watchdog (respawn if stalled)", true)
        slider(main, "WatchdogSeconds", "Stalled after (s)", 60, 20, 300)
        info(main, string.format("Caps: skill %s, crash %s, drive %s per min",
            formatMoney(Economy.SkillPerMinute), formatMoney(Economy.CrashPerMinute), formatMoney(Economy.DrivePerMinute)))

        local tune = section(Tabs.Farm, 2, "Tuning", "sliders-horizontal", "Defaults sit right under the caps")
        slider(tune, "SkillAmount", "Skill score per bank", Economy.SkillMax, 500, Economy.SkillMax)
        slider(tune, "SkillInterval", "Skill bank every (s)", 11, 3, 60, 1)
        slider(tune, "CrashSpeed", "Crash impact speed", 200, 40, 250)
        slider(tune, "CrashInterval", "Crash every (s)", 25, 4, 90, 1)
        toggle(tune, "CrashPolice", "Allow ramming police", false)
        slider(tune, "CruisePercent", "Cruise speed (% of car limit)", 95, 30, 100)
        slider(tune, "CruiseHeight", "Cruise height", 350, 60, 1200)
        slider(tune, "CruiseRadius", "Loop radius", 600, 150, 2000)
        info(tune, "Faster cars earn more distance pay per minute.")

        local rewards = section(Tabs.Farm, 2, "Rewards", "gift", "Free cash")
        toggle(rewards, "AutoDaily", "Auto claim daily reward", true)
        button(rewards, "Redeem all known codes", function()
            for _, code in ipairs(KNOWN_CODES) do
                local ok, message = Game.redeem(code)
                notify(code .. ": " .. tostring(message or (ok and "redeemed" or "failed")))
                task.wait(0.5)
            end
        end)
        textbox(rewards, "RedeemCode", "Code", "Enter a code", true)
        button(rewards, "Redeem code", function()
            local code = tostring(value("RedeemCode", "")):gsub("^%s+", ""):gsub("%s+$", "")
            if code == "" then notify("Type a code first") return end
            local ok, message = Game.redeem(code)
            notify(tostring(message or (ok and "Redeemed" or "Failed")))
        end)
    end

    ---------------------------------------------------------------- Dealership
    do
        local buy = section(Tabs.Shop, 1, "Buy", "shopping-cart", "APEX dealership, delivered to your garage")
        local carDrop = dropdown(buy, "BuyCar", "Car", carNames(), carNames()[1])
        button(buy, "Buy selected", function()
            local entry = entryFromLabel(value("BuyCar"))
            if not entry then notify("Pick a car first") return end
            if Game.owned()[entry.kind] then notify("Already owned") return end
            if Game.money() < entry.price then notify("Need " .. formatMoney(entry.price - Game.money()) .. " more") return end
            local ok, message = Game.buy(entry.kind)
            notify(ok and ("Bought " .. entry.name) or tostring(message or "Purchase failed"))
        end)
        toggle(buy, "AutoBuy", "Auto buy next car", false)
        dropdown(buy, "AutoBuyMode", "Buy which", {"Cheapest", "Faster"}, "Faster")
        slider(buy, "AutoBuyKeep", "Keep at least", 0, 0, 500000)
        info(buy, "Faster = cheapest car quicker than your best.")
        button(buy, "Refresh list", function() carDrop:SetValues(carNames()) end)

        local garage = section(Tabs.Shop, 2, "Garage", "warehouse", "Swap to any car you own")
        local ownedDrop = dropdown(garage, "SpawnCarKind", "Owned car", ownedNames(), ownedNames()[1])
        button(garage, "Spawn selected", function()
            local name = value("SpawnCarKind")
            if not name or name == "none" then notify("Nothing owned yet") return end
            local ok, message = Game.spawnCar(kindFromName(name))
            notify(ok and ("Spawned " .. name) or tostring(message or "Spawn failed"))
        end)
        button(garage, "Refresh owned", function() ownedDrop:SetValues(ownedNames()) end)
        toggle(garage, "AutoBestCar", "Always drive fastest owned", false)
        connect(Player:GetAttributeChangedSignal("OwnedCars"), function()
            pcall(function() ownedDrop:SetValues(ownedNames()) end)
        end)
    end

    ---------------------------------------------------------------- Vehicle
    do
        local mods = section(Tabs.Vehicle, 1, "Handling", "gauge", "Works on any car you drive")
        toggle(mods, "CarBoost", "Speed boost (hold W)", false, nil, "Speed Boost")
        slider(mods, "CarBoostPower", "Boost power", 60, 10, 300)
        slider(mods, "CarBoostMax", "Boost top speed (sps)", 250, 80, 800)
        toggle(mods, "CarBrake", "Instant brake (hold S)", false)
        toggle(mods, "CarFly", "Car fly", false, nil, "Car Fly")
        slider(mods, "CarFlySpeed", "Fly speed", 150, 20, 600)
        toggle(mods, "CarNoFlip", "Keep upright", false)
        toggle(mods, "CarGrip", "Extra grip (less sliding)", false)
        slider(mods, "CarGripStrength", "Grip strength %", 50, 5, 100)
        toggle(mods, "CarDownforce", "Downforce", false)
        slider(mods, "CarDownforcePower", "Downforce power", 60, 10, 300)
        toggle(mods, "CarDrift", "Drift (hold Left Shift)", false)
        slider(mods, "CarDriftPower", "Drift turn power", 40, 5, 150)

        local traffic = section(Tabs.Vehicle, 2, "Traffic", "traffic-cone", "Only changes your screen and your car")
        toggle(traffic, "GhostTraffic", "Ghost traffic (drive through)", false)
        toggle(traffic, "HideTraffic", "Hide traffic", false)

        local health = section(Tabs.Vehicle, 2, "Damage", "shield", "Keep the car alive")
        toggle(health, "NoCrashDamage", "No crash damage", false)
        toggle(health, "NoEject", "Never get thrown out", false)
        toggle(health, "AutoRepair", "Auto repair", false)
        slider(health, "AutoRepairAt", "Repair at damage %", 45, 5, 95)
        info(health, "No crash damage also stops natural crash pay.")
        button(health, "Repair now", Game.repair)
        button(health, "Respawn car", function() command("respawn") end)
        button(health, "Bring car to me", function() command("bring") end)
        button(health, "Flip upright", function()
            local car = Game.myCar()
            if not car then notify("No car") return end
            local pivot = car:GetPivot()
            local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
            if look.Magnitude < 0.1 then look = Vector3.zAxis end
            car:PivotTo(CFrame.lookAt(pivot.Position + Vector3.new(0, 5, 0), pivot.Position + Vector3.new(0, 5, 0) + look.Unit))
        end)
    end

    ---------------------------------------------------------------- Player
    do
        local body = section(Tabs.Player, 1, "Movement", "footprints", "On foot")
        toggle(body, "WalkSpeedOn", "WalkSpeed", false)
        slider(body, "WalkSpeed", "Speed", 32, 16, 200)
        toggle(body, "JumpOn", "JumpPower", false)
        slider(body, "JumpPower", "Power", 75, 50, 300)
        toggle(body, "InfJump", "Infinite jump", false)
        toggle(body, "Noclip", "Noclip", false, nil, "Noclip")
    end

    ---------------------------------------------------------------- Teleport
    do
        local areas = section(Tabs.Teleport, 1, "Areas", "map", "Server map travel")
        dropdown(areas, "TravelMap", "Map", {"Motorway", "Desert Valley", "Canyon"}, MAPS[Player:GetAttribute("Map")] or "Motorway")
        button(areas, "Travel", function()
            local id = MAP_IDS[value("TravelMap", "Motorway")]
            local ok, message = Game.travel(id)
            notify(ok and ("Travelling to " .. value("TravelMap")) or tostring(message or "Travel failed"))
        end)

        local spots = section(Tabs.Teleport, 1, "Hub", "map-pin", "Motorway spawn hub")
        local function spot(name, child)
            button(spots, name, function()
                local hub = Game.hub()
                local target = hub and hub:FindFirstChild(child)
                if not target then notify(name .. " is only on the motorway") return end
                Game.teleport(target:GetPivot())
            end)
        end
        spot("Spawn", "SpawnLocation")
        spot("APEX Dealership", "Dealership")
        spot("Garage", "Garage")
        spot("Car park", "CarPark")

        local people = section(Tabs.Teleport, 2, "Players", "users", "Goes to their car when they drive")
        local playerDrop = dropdown(people, "TeleportPlayer", "Player", playerNames(), playerNames()[1])
        button(people, "Teleport", function()
            local target = Players:FindFirstChild(value("TeleportPlayer", ""))
            if not target then notify("Player left") return end
            local car = Game.drivenCar(target)
            local model = car or target.Character
            if not model then notify("No character") return end
            local pivot = model:GetPivot()
            Game.teleport(pivot - pivot.LookVector * 12)
        end)
        button(people, "Refresh", function() playerDrop:SetValues(playerNames()) end)
        toggle(people, "Spectate", "Spectate selected", false, function(state)
            if not state then
                Runtime.Spectating = false
                local hum = humanoid()
                if hum then Camera.CameraSubject = hum end
            end
        end)
        local function refreshPlayers()
            pcall(function() playerDrop:SetValues(playerNames()) end)
        end
        connect(Players.PlayerAdded, refreshPlayers)
        connect(Players.PlayerRemoving, function() task.defer(refreshPlayers) end)

        -- waypoints are saved per map so they survive rejoins
        local marks = section(Tabs.Teleport, 2, "Waypoints", "flag", "Moves your car when you drive")
        Runtime.Waypoints = readData("waypoints", {})
        local function mapKey() return tostring(Player:GetAttribute("Map") or "motorway") end
        local function waypointNames()
            local list = {}
            for name in pairs(Runtime.Waypoints[mapKey()] or {}) do table.insert(list, name) end
            table.sort(list)
            return #list > 0 and list or {"none"}
        end
        textbox(marks, "WaypointName", "Name", "e.g. Big jump", true)
        local markDrop = dropdown(marks, "Waypoint", "Waypoint", waypointNames(), waypointNames()[1])
        button(marks, "Save current spot", function()
            local seated, car = Game.seated()
            local model = seated and car or character()
            if not model then notify("No character") return end
            local name = tostring(value("WaypointName", "")):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then name = "Spot " .. os.date("%H:%M:%S") end
            local p = model:GetPivot()
            local key = mapKey()
            Runtime.Waypoints[key] = Runtime.Waypoints[key] or {}
            Runtime.Waypoints[key][name] = {p.X, p.Y, p.Z, p.LookVector.X, p.LookVector.Z}
            writeData("waypoints", Runtime.Waypoints)
            markDrop:SetValues(waypointNames())
            markDrop:SetValue(name)
            notify("Saved " .. name)
        end)
        button(marks, "Go to waypoint", function()
            local spot = (Runtime.Waypoints[mapKey()] or {})[value("Waypoint", "")]
            if not spot then notify("Pick a waypoint") return end
            local position = Vector3.new(spot[1], spot[2], spot[3])
            local look = Vector3.new(spot[4] or 0, 0, spot[5] or 1)
            if look.Magnitude < 0.1 then look = Vector3.zAxis end
            Game.teleport(CFrame.lookAt(position, position + look.Unit))
        end)
        button(marks, "Delete waypoint", function()
            local list = Runtime.Waypoints[mapKey()]
            local name = value("Waypoint", "")
            if not list or not list[name] then notify("Pick a waypoint") return end
            list[name] = nil
            writeData("waypoints", Runtime.Waypoints)
            markDrop:SetValues(waypointNames())
            notify("Deleted " .. name)
        end)
        connect(Player:GetAttributeChangedSignal("Map"), function() pcall(function() markDrop:SetValues(waypointNames()) end) end)
    end

    ---------------------------------------------------------------- Visuals
    do
        local players = section(Tabs.Visuals, 1, "Player ESP", "user", "Sense, boxes the car they drive")
        toggle(players, "EspPlayers", "Player ESP", false, nil, "Player ESP")
        toggle(players, "EspBox", "Boxes", true)
        toggle(players, "EspBoxFill", "Box fill", false)
        toggle(players, "EspBox3d", "3D boxes", false)
        toggle(players, "EspName", "Names", true)
        toggle(players, "EspVehicle", "Car + speed", true)
        toggle(players, "EspDistance", "Distance", true)
        toggle(players, "EspHealth", "Health / car condition", true)
        toggle(players, "EspHealthText", "Health text", false)
        toggle(players, "EspTracer", "Tracers", false)
        dropdown(players, "EspTracerOrigin", "Tracer origin", {"Bottom", "Middle", "Top", "Mouse"}, "Bottom")
        toggle(players, "EspArrow", "Off-screen arrows", false)
        toggle(players, "EspChams", "Chams", false)
        toggle(players, "EspChamsVisible", "Chams visible only", false)
        toggle(players, "EspTeamColor", "Use team color", false)
        color(players, "EspColor", "Color", Color3.fromRGB(255, 90, 90))
        slider(players, "EspRange", "Range", 2000, 100, 10000)

        local world = section(Tabs.Visuals, 2, "Vehicle ESP", "car", "Labels on cars around you")
        toggle(world, "EspPolice", "Police", false)
        color(world, "EspPoliceColor", "Police color", Color3.fromRGB(90, 160, 255))
        toggle(world, "EspTraffic", "Traffic", false)
        color(world, "EspTrafficColor", "Traffic color", Color3.fromRGB(220, 220, 220))
        toggle(world, "EspEmpty", "Parked player cars", false)
        color(world, "EspEmptyColor", "Parked color", Color3.fromRGB(255, 200, 90))
        slider(world, "EspVehicleRange", "Range", 800, 100, 5000)

        local look = section(Tabs.Visuals, 2, "World", "sun")
        toggle(look, "Fullbright", "Fullbright", false)
        toggle(look, "NoFog", "No fog", false)
        slider(look, "FieldOfView", "Field of view", 70, 50, 120)
        toggle(look, "FovOn", "Custom field of view", false)
        toggle(look, "StreamerMode", "Hide my name (your screen)", false)
    end

    ---------------------------------------------------------------- Misc / Settings
    do
        local misc = section(Tabs.Misc, 1, "Misc", "wrench")
        toggle(misc, "AntiAFK", "Anti AFK", true)
        toggle(misc, "AutoPlay", "Auto skip start menu", true)
        button(misc, "Rejoin", function()
            notify("Rejoining")
            rejoin()
        end)
        button(misc, "Server hop", function()
            local ok, body = pcall(game.HttpGet, game, ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100"):format(game.PlaceId))
            if not ok then notify("Server list failed") return end
            local data = HttpService:JSONDecode(body)
            for _, server in ipairs(data.data or {}) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    notify("Hopping")
                    queueLoader()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, Player)
                    return
                end
            end
            notify("No other server found")
        end)

        local afk = section(Tabs.Misc, 1, "AFK", "moon", "Long unattended runs")
        toggle(afk, "AutoRejoin", "Auto rejoin on disconnect", true)
        toggle(afk, "AutoExecute", "Re-run script after teleport", false, function(state)
            if state then return end
            local clear = clear_teleport_queue or cleartpqueue
            if LoaderQueued and type(clear) == "function" and pcall(clear) then LoaderQueued = false end
        end)
        info(afk, "Use a config with autoload so farm toggles come back.")
        toggle(afk, "NoRender", "Disable 3D rendering", false, function(state)
            pcall(function() RunService:Set3dRenderingEnabled(not state) end)
        end)
        toggle(afk, "FpsCap", "Limit FPS", false, function(state)
            local cap = setfpscap or set_fps_cap
            if type(cap) ~= "function" then notify("Executor has no setfpscap") return end
            pcall(cap, state and value("FpsCapValue", 30) or 0)
        end)
        slider(afk, "FpsCapValue", "FPS cap", 30, 5, 240, 0, function(v)
            local cap = setfpscap or set_fps_cap
            if on("FpsCap") and type(cap) == "function" then pcall(cap, v) end
        end)
        button(afk, "Low graphics (until rejoin)", function()
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            pcall(function() Lighting.GlobalShadows = false end)
            for _, fx in ipairs(Lighting:GetChildren()) do
                if fx:IsA("PostEffect") then pcall(function() fx.Enabled = false end) end
            end
            local count = 0
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    pcall(function() obj.Enabled = false end)
                    count += 1
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    pcall(function() obj.Transparency = 1 end)
                    count += 1
                elseif obj:IsA("BasePart") then
                    pcall(function() obj.Material = Enum.Material.SmoothPlastic; obj.CastShadow = false end)
                end
            end
            notify(string.format("Lowered graphics, hid %d effects", count))
        end)

        local hook = section(Tabs.Misc, 2, "Discord Webhook", "send", "Farm reports to your server")
        toggle(hook, "WebhookOn", "Send farm reports", false)
        textbox(hook, "WebhookURL", "Webhook URL", "https://discord.com/api/webhooks/...")
        slider(hook, "WebhookMinutes", "Every (min)", 10, 1, 60)
        toggle(hook, "WebhookPurchases", "Also report car purchases", true)
        button(hook, "Send test report", function()
            if not Runtime.Report then notify("Not ready yet") return end
            local ok, message = Runtime.Report("Test report")
            notify(ok and "Webhook sent" or ("Webhook failed: " .. tostring(message)))
        end)

        local menu = section(Tabs.Misc, 2, "Menu", "layout-panel-left")
        button(menu, "Copy Discord invite", function() if setclipboard then setclipboard("https://discord.gg/mcYasYZN87"); notify("Invite copied") end end)
        button(menu, "Unload", unload)
    end
    local settingsOK, settingsError = pcall(function() Window:BuildSettings(Tabs.Settings) end)
    if not settingsOK then notify("Settings tab unavailable: " .. tostring(settingsError):sub(1, 100)) end

    ---------------------------------------------------------------- remote hook (damage / eject)

    if hookmetamethod and getnamecallmethod and checkcaller then
        local crashRemote, scrapeRemote, thrownRemote = remote("Crash"), remote("Scrape"), remote("DriverThrown")
        local old
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(function(self, ...)
            if Runtime.Alive and not checkcaller() and getnamecallmethod() == "FireServer" then
                if (self == crashRemote or self == scrapeRemote) and on("NoCrashDamage") then return nil end
                if self == thrownRemote and on("NoEject") then
                    local action = ...
                    if action == "eject" or action == "knocked" or action == "whiplash" then return nil end
                end
            end
            return old(self, ...)
        end) or function(self, ...)
            if Runtime.Alive and not checkcaller() and getnamecallmethod() == "FireServer" then
                if (self == crashRemote or self == scrapeRemote) and on("NoCrashDamage") then return nil end
            end
            return old(self, ...)
        end)
    end

    ---------------------------------------------------------------- earnings tracker

    local moneyEvent = remote("MoneyEvent")
    if moneyEvent then
        connect(moneyEvent.OnClientEvent, function(kind, amount, label)
            if kind ~= "earn" or type(amount) ~= "number" then return end
            Runtime.Earned += amount
            local key = tostring(label or "Other")
            local lower = key:lower()
            if lower:find("smash") or lower:find("crash") then key = "Crash"
            elseif key:find("Skill") then key = "Skill"
            elseif key:find("Driving") then key = "Drive"
            elseif key:find("Totaled") then key = "Wreck" end
            Runtime.EarnedBy[key] = (Runtime.EarnedBy[key] or 0) + amount
            Runtime.LastEarn = os.clock()
        end)
    end

    ---------------------------------------------------------------- lifetime stats

    Runtime.Stats = readData("stats", {Earned = 0, Minutes = 0, BestRate = 0, Sessions = 0})
    Runtime.Stats.Sessions = (tonumber(Runtime.Stats.Sessions) or 0) + 1
    Runtime.StatsBase = {Earned = 0, Clock = os.clock()}
    local function sessionRate()
        local minutes = math.max((os.clock() - Runtime.Started) / 60, 1 / 60)
        return Runtime.Earned / minutes, minutes
    end
    local function lifetime()
        local stats, base = Runtime.Stats, Runtime.StatsBase
        return (tonumber(stats.Earned) or 0) + (Runtime.Earned - base.Earned),
            (tonumber(stats.Minutes) or 0) + (os.clock() - base.Clock) / 60
    end
    function Runtime.SaveStats()
        local earned, minutes = lifetime()
        local rate, sessionMinutes = sessionRate()
        local best = tonumber(Runtime.Stats.BestRate) or 0
        -- only count a rate once it has had a few minutes to settle
        if sessionMinutes >= 3 and rate > best then best = rate end
        Runtime.Stats = {Earned = earned, Minutes = minutes, BestRate = best, Sessions = Runtime.Stats.Sessions}
        Runtime.StatsBase = {Earned = Runtime.Earned, Clock = os.clock()}
        writeData("stats", Runtime.Stats)
    end
    launch(function()
        while Runtime.Alive do
            task.wait(30)
            pcall(Runtime.SaveStats)
        end
    end)

    ---------------------------------------------------------------- webhook

    function Runtime.Report(title, extra)
        local rate, minutes = sessionRate()
        local total = lifetime()
        local parts = {}
        for _, key in ipairs(sortedKeys(Runtime.EarnedBy)) do table.insert(parts, key .. ": " .. formatMoney(Runtime.EarnedBy[key])) end
        local car = Game.myCar()
        local fields = {
            {name = "Money", value = formatMoney(Game.money()), inline = true},
            {name = "Session", value = formatMoney(Runtime.Earned) .. " in " .. math.floor(minutes) .. " min", inline = true},
            {name = "Rate", value = formatMoney(rate) .. "/min", inline = true},
            {name = "Sources", value = #parts > 0 and table.concat(parts, "\n") or "none yet", inline = false},
            {name = "Car", value = car and (Esp and Esp.prettyKind(car:GetAttribute("Kind")) or tostring(car:GetAttribute("Kind"))) or "none", inline = true},
            {name = "Lifetime", value = formatMoney(total), inline = true},
        }
        for _, field in ipairs(extra or {}) do table.insert(fields, field) end
        return postWebhook(value("WebhookURL", ""), {title = title or "BloxNG farm report", fields = fields})
    end
    launch(function()
        local last = os.clock()
        while Runtime.Alive do
            task.wait(5)
            if on("WebhookOn") and os.clock() - last >= value("WebhookMinutes", 10) * 60 then
                last = os.clock()
                local ok, message = Runtime.Report()
                if not ok then Runtime.Error = "Webhook: " .. tostring(message) end
            elseif not on("WebhookOn") then
                last = os.clock()
            end
        end
    end)

    ---------------------------------------------------------------- auto rejoin

    local function onDisconnect()
        if not on("AutoRejoin") or Runtime.Rejoining then return end
        Runtime.Rejoining = true
        task.wait(5)
        while Runtime.Alive do
            pcall(rejoin)
            task.wait(15)
        end
    end
    connect(GuiService.ErrorMessageChanged, function()
        local message = GuiService:GetErrorMessage()
        if message and message ~= "" then task.spawn(onDisconnect) end
    end)
    launch(function()
        local prompt = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = prompt and prompt:WaitForChild("promptOverlay", 10)
        if not overlay then return end
        connect(overlay.ChildAdded, function(child)
            if child.Name == "ErrorPrompt" then task.spawn(onDisconnect) end
        end)
    end)
    connect(Player.OnTeleport, function(state)
        if state == Enum.TeleportState.Started then queueLoader() end
    end)

    ---------------------------------------------------------------- shared loops

    connect(Player.Idled, function()
        if not on("AntiAFK") then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    launch(function()
        while Runtime.Alive do
            pcall(function()
                local seated, car = Game.seated()
                local damage = car and tonumber(car:GetAttribute("Damage")) or 0
                statusLabel:SetText(string.format("Car: %s%s | dmg %d%%%s", car and Esp and Esp.prettyKind(car:GetAttribute("Kind")) or (car and "yes" or "none"),
                    seated and "" or " (not seated)", math.floor(damage * 100),
                    Runtime.Cruising and (" | cruising " .. math.floor(Runtime.CruiseSpeed or 0) .. " sps") or ""))
                moneyLabel:SetText("Money: " .. formatMoney(Game.money()))
                local minutes = math.max((os.clock() - Runtime.Started) / 60, 1 / 60)
                rateLabel:SetText(string.format("Earned: %s | %s/min | %.0f min", formatMoney(Runtime.Earned),
                    formatMoney(Runtime.Earned / minutes), minutes))
                local parts = {}
                for _, key in ipairs(sortedKeys(Runtime.EarnedBy)) do table.insert(parts, key .. " " .. formatMoney(Runtime.EarnedBy[key])) end
                breakdownLabel:SetText(#parts > 0 and table.concat(parts, " | ") or "Sources: none yet")
                local rate = Runtime.Earned / minutes
                local goal = Game.nextCar(value("AutoBuyMode", "Faster"))
                if goal then
                    local short = goal.price + value("AutoBuyKeep", 0) - Game.money()
                    if short <= 0 then
                        nextLabel:SetText("Next car: " .. goal.name .. " (affordable now)")
                    elseif rate > 1 and minutes >= 1 then
                        nextLabel:SetText(string.format("Next car: %s in ~%.0f min (%s left)", goal.name, short / rate, formatMoney(short)))
                    else
                        nextLabel:SetText("Next car: " .. goal.name .. " (" .. formatMoney(short) .. " left)")
                    end
                else
                    nextLabel:SetText("Next car: you own them all")
                end
                if Runtime.Stats and Runtime.StatsBase then
                    local stats, base = Runtime.Stats, Runtime.StatsBase
                    local total = (tonumber(stats.Earned) or 0) + Runtime.Earned - base.Earned
                    local totalMinutes = (tonumber(stats.Minutes) or 0) + (os.clock() - base.Clock) / 60
                    lifetimeLabel:SetText(string.format("Total: %s | %.1f h | %d sessions", formatMoney(total), totalMinutes / 60, stats.Sessions or 1))
                    local best = math.max(tonumber(stats.BestRate) or 0, minutes >= 3 and rate or 0)
                    bestLabel:SetText("Best rate: " .. formatMoney(best) .. "/min | watchdog resets " .. (Runtime.WatchdogResets or 0))
                end
                local espError = Esp and Esp.GetLastError()
                errorLabel:SetText("Runtime: " .. ((espError or Runtime.Error ~= "") and tostring(espError or Runtime.Error):sub(1, 120) or "ready"))
            end)
            task.wait(1)
        end
    end)

    ---------------------------------------------------------------- auto farm

    -- skill chains: the server pays SkillRate per point, up to SkillMax per bank and SkillPerMinute in cash
    loop("FarmSkill", function() return value("SkillInterval", 11) end, function()
        fire("SkillBank", math.floor(value("SkillAmount", Economy.SkillMax)))
        Runtime.SkillBanks += 1
    end)

    -- cruising: a smooth loop in the sky, under the speed where distance stops paying and where crashes still count
    local function wantCruise()
        return on("FarmDrive") or on("FarmCrash")
    end
    local angle = 0
    connect(RunService.Heartbeat, function(dt)
        if not wantCruise() then
            if Runtime.Cruising then
                Runtime.Cruising = false
                local car = Game.myCar()
                if car and Runtime.CruiseHome then
                    car:PivotTo(Runtime.CruiseHome)
                    local hull = car:FindFirstChild("Hull")
                    if hull then hull.AssemblyLinearVelocity, hull.AssemblyAngularVelocity = Vector3.zero, Vector3.zero end
                end
            end
            return
        end
        local seated, car = Game.seated()
        if not seated or not car then return end
        local hull = car:FindFirstChild("Hull")
        if not hull then return end
        if not Runtime.Cruising or not Runtime.CruiseCenter then
            local start = car:GetPivot().Position
            local hub = Game.hubPosition()
            -- the spawn hub shields cars from crash damage, so loop well away from it
            if hub and (hub - start).Magnitude < 700 then start += Vector3.new(1300, 0, 300) end
            local ground = Game.groundBelow(start)
            Runtime.CruiseHome = CFrame.new(ground + Vector3.new(0, 6, 0))
            Runtime.CruiseCenter = ground
            Runtime.Cruising = true
            angle = 0
        end
        local radius = value("CruiseRadius", 600)
        local speed = math.clamp(Game.cruiseLimit(car) * value("CruisePercent", 95) / 100, 40, 600)
        Runtime.CruiseSpeed = speed
        angle += speed / radius * dt
        local center = Runtime.CruiseCenter + Vector3.new(0, value("CruiseHeight", 350), 0)
        local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
        car:PivotTo(CFrame.lookAt(position, position + tangent))
        hull.AssemblyLinearVelocity = tangent * speed
        hull.AssemblyAngularVelocity = Vector3.zero
    end)

    -- crashes: report a hit on the nearest traffic car, take the wreck bonus, repair, repeat
    loop("FarmCrash", 0.5, function()
        local now = os.clock()
        if now - (Runtime.LastCrash or 0) < value("CrashInterval", 25) then return end
        local seated, car = Game.seated()
        if not seated or not car or not Runtime.Cruising then return end
        local hull = car:FindFirstChild("Hull")
        local target = Game.crashTarget(hull and hull.Position, on("CrashPolice"))
        if not target or not hull then return end
        Runtime.LastCrash = now
        local speed = value("CrashSpeed", 200)
        fire("Crash", car, {{Vector3.new(0, 0, -2), Vector3.new(0, 0, 1), speed, target}}, {})
        Runtime.Crashes += 1
        task.wait(1.5)
        local damage = tonumber(car:GetAttribute("Damage")) or 0
        if damage >= 0.3 then
            Game.repair()
            task.wait(2)
        end
    end)

    -- watchdog: no money for a while while farming means something is stuck, so start the car over
    Runtime.LastEarn = os.clock()
    launch(function()
        while Runtime.Alive do
            task.wait(5)
            local farming = on("FarmSkill") or on("FarmCrash") or on("FarmDrive")
            if not farming or not on("FarmWatchdog") then
                Runtime.LastEarn = os.clock()
            elseif os.clock() - (Runtime.LastEarn or 0) > value("WatchdogSeconds", 60) then
                Runtime.LastEarn = os.clock()
                Runtime.WatchdogResets = (Runtime.WatchdogResets or 0) + 1
                notify("Watchdog: no income, respawning car")
                Runtime.Cruising, Runtime.CruiseCenter = false, nil
                command("respawn")
                Runtime.LastRespawn = os.clock()
            end
        end
    end)

    -- keeps us in a car for every farm that needs one
    launch(function()
        while Runtime.Alive do
            if on("FarmAutoCar") and (on("FarmCrash") or on("FarmDrive")) then pcall(Game.ensureCar) end
            task.wait(2)
        end
    end)

    loop("AutoDaily", 30, function()
        if Player:GetAttribute("DailyReady") ~= true then return end
        local reward = remote("DailyReward")
        if reward then
            local ok, message = invokeObject(reward, "claim")
            if ok then notify("Daily reward claimed") end
        end
    end)

    loop("AutoBuy", 10, function()
        local entry = Game.nextCar(value("AutoBuyMode", "Cheapest"))
        if entry and Game.money() - entry.price >= value("AutoBuyKeep", 0) then
            local ok = Game.buy(entry.kind)
            if ok then
                notify("Auto bought " .. entry.name)
                if on("WebhookOn") and on("WebhookPurchases") then
                    task.spawn(Runtime.Report, "Bought " .. entry.name, {{name = "Price", value = formatMoney(entry.price), inline = true}})
                end
            end
        end
    end)

    loop("AutoBestCar", 8, function()
        local best = Game.bestOwned()
        local car = Game.myCar()
        if best and (not car or car:GetAttribute("Kind") ~= best.kind) and os.clock() - (Runtime.LastSwap or 0) > 20 then
            Runtime.LastSwap = os.clock()
            Game.spawnCar(best.kind)
        end
    end)

    loop("AutoPlay", 3, function()
        if Player:GetAttribute("StartMenuOpen") ~= true then return end
        if not Game.pressButton("^%s*PLAY%s*$") then
            Game.pressButton("^%s*DRIVE%s*$")
        end
    end)

    ---------------------------------------------------------------- vehicle

    connect(RunService.Heartbeat, function(dt)
        if Runtime.Cruising then return end
        local seated, car = Game.seated()
        if not seated or not car then return end
        local hull = car:FindFirstChild("Hull")
        if not hull then return end
        local typing = Input:GetFocusedTextBox() ~= nil

        if on("CarFly") then
            local move = Vector3.zero
            local cam = Camera.CFrame
            if not typing then
                if Input:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
                if Input:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
                if Input:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
                if Input:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
                if Input:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
                if Input:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
            end
            local pivot = car:GetPivot()
            local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
            if flat.Magnitude < 0.1 then flat = Vector3.zAxis end
            local step = move.Magnitude > 0 and move.Unit * value("CarFlySpeed", 150) * dt or Vector3.zero
            car:PivotTo(CFrame.lookAt(pivot.Position + step, pivot.Position + step + flat.Unit))
            hull.AssemblyLinearVelocity = move.Magnitude > 0 and move.Unit * value("CarFlySpeed", 150) or Vector3.zero
            hull.AssemblyAngularVelocity = Vector3.zero
            return
        end

        local look = hull.CFrame.LookVector
        if on("CarBoost") and not typing and Input:IsKeyDown(Enum.KeyCode.W) then
            local velocity = hull.AssemblyLinearVelocity
            if velocity:Dot(look) < value("CarBoostMax", 250) then
                hull.AssemblyLinearVelocity = velocity + look * value("CarBoostPower", 60) * dt
            end
        end
        if on("CarBrake") and not typing and Input:IsKeyDown(Enum.KeyCode.S) and hull.AssemblyLinearVelocity:Dot(look) > 5 then
            hull.AssemblyLinearVelocity = hull.AssemblyLinearVelocity * Vector3.new(0, 1, 0)
        end
        local right = hull.CFrame.RightVector
        local drifting = on("CarDrift") and not typing and Input:IsKeyDown(Enum.KeyCode.LeftShift)
        if on("CarGrip") and not drifting then
            -- bleed off sideways speed so the car tracks where it points
            local velocity = hull.AssemblyLinearVelocity
            local side = velocity:Dot(right)
            local keep = 1 - math.clamp(value("CarGripStrength", 50) / 100 * dt * 10, 0, 1)
            hull.AssemblyLinearVelocity = velocity - right * side * (1 - keep)
        end
        if drifting then
            local steer = (Input:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (Input:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
            if steer ~= 0 and hull.AssemblyLinearVelocity.Magnitude > 20 then
                local spin = hull.AssemblyAngularVelocity
                local target = -steer * value("CarDriftPower", 40) / 10
                hull.AssemblyAngularVelocity = Vector3.new(spin.X, spin.Y + (target - spin.Y) * math.clamp(dt * 6, 0, 1), spin.Z)
            end
        end
        if on("CarDownforce") then
            local speed = hull.AssemblyLinearVelocity.Magnitude
            hull.AssemblyLinearVelocity -= hull.CFrame.UpVector * value("CarDownforcePower", 60) * math.clamp(speed / 100, 0, 2) * dt
        end
        if on("CarNoFlip") and hull.CFrame.UpVector.Y < 0.3 then
            local pivot = car:GetPivot()
            local flat = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
            if flat.Magnitude < 0.1 then flat = Vector3.zAxis end
            car:PivotTo(CFrame.lookAt(pivot.Position + Vector3.new(0, 3, 0), pivot.Position + Vector3.new(0, 3, 0) + flat.Unit))
            hull.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    loop("AutoRepair", 1, function()
        if on("FarmCrash") then return end
        local car = Game.myCar()
        local damage = car and tonumber(car:GetAttribute("Damage")) or 0
        if damage * 100 >= value("AutoRepairAt", 45) and os.clock() - (Runtime.LastAutoRepair or 0) > 4 then
            Runtime.LastAutoRepair = os.clock()
            Game.repair()
        end
    end)

    ---------------------------------------------------------------- player

    connect(RunService.Stepped, function()
        local hum = humanoid()
        if hum then
            if on("WalkSpeedOn") then hum.WalkSpeed = value("WalkSpeed", 32) end
            if on("JumpOn") then hum.UseJumpPower = true; hum.JumpPower = value("JumpPower", 75) end
        end
        if on("Noclip") then
            local model = character()
            if model then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
    end)
    connect(Input.JumpRequest, function()
        if not on("InfJump") then return end
        local hum = humanoid()
        if hum and not hum.SeatPart then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
    Toggles.WalkSpeedOn:OnChanged(function(state)
        local hum = humanoid()
        if not state and hum then hum.WalkSpeed = 16 end
    end)

    ---------------------------------------------------------------- visuals

    loop("Fullbright", 0.5, function()
        change(Lighting, "Brightness", 2)
        change(Lighting, "ClockTime", 14)
        change(Lighting, "GlobalShadows", false)
        change(Lighting, "Ambient", Color3.fromRGB(178, 178, 178))
        change(Lighting, "OutdoorAmbient", Color3.fromRGB(178, 178, 178))
    end)
    Toggles.Fullbright:OnChanged(function(state)
        if state then return end
        for _, key in ipairs({"Brightness", "ClockTime", "GlobalShadows", "Ambient", "OutdoorAmbient"}) do restore(Lighting, key) end
    end)

    loop("NoFog", 0.5, function()
        change(Lighting, "FogEnd", 1e6)
        change(Lighting, "FogStart", 1e6)
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then change(atmosphere, "Density", 0) end
    end)
    Toggles.NoFog:OnChanged(function(state)
        if state then return end
        restore(Lighting, "FogEnd")
        restore(Lighting, "FogStart")
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then restore(atmosphere, "Density") end
    end)

    -- traffic only exists on our screen and in our car's physics, so these are client-side
    local function trafficCars()
        local list = {}
        for _, model in ipairs(Game.cars()) do
            if model:GetAttribute("AI") ~= nil or model:GetAttribute("Police") then table.insert(list, model) end
        end
        local shells = workspace:FindFirstChild("TrafficShells")
        if shells then for _, model in ipairs(shells:GetChildren()) do table.insert(list, model) end end
        return list
    end
    local function eachTrafficPart(callback)
        for _, model in ipairs(trafficCars()) do
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then callback(part) end
            end
        end
    end
    loop("GhostTraffic", 0.5, function()
        eachTrafficPart(function(part) if part.CanCollide then change(part, "CanCollide", false) end end)
    end)
    loop("HideTraffic", 0.5, function()
        eachTrafficPart(function(part) if part.LocalTransparencyModifier < 1 then change(part, "LocalTransparencyModifier", 1) end end)
    end)
    local function restoreTraffic(key)
        for object, changes in pairs(Runtime.Changed) do
            if changes[key] and typeof(object) == "Instance" and object:IsA("BasePart") then restore(object, key) end
        end
    end
    Toggles.GhostTraffic:OnChanged(function(state) if not state then restoreTraffic("CanCollide") end end)
    Toggles.HideTraffic:OnChanged(function(state) if not state then restoreTraffic("LocalTransparencyModifier") end end)

    -- spectate: follow the picked player's car, or their body on foot
    loop("Spectate", 0.2, function()
        local target = Players:FindFirstChild(value("TeleportPlayer", ""))
        if not target or target == Player then return end
        local car = Game.drivenCar(target)
        local subject = car and car:FindFirstChild("Hull") or (target.Character and target.Character:FindFirstChildOfClass("Humanoid"))
        if subject and Camera.CameraSubject ~= subject then
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = subject
        end
        Runtime.Spectating = subject ~= nil
    end)

    -- streamer mode: swap our name for "Hidden" in game ui and name tags on our screen
    loop("StreamerMode", 1, function()
        local names = {Player.Name, Player.DisplayName}
        local roots = {}
        local function add(object) if object then table.insert(roots, object) end end
        add(Player:FindFirstChildOfClass("PlayerGui"))
        add(character())
        add(Game.myCar())
        pcall(function()
            add(CoreGui:FindFirstChild("PlayerList"))
            local robloxGui = CoreGui:FindFirstChild("RobloxGui")
            add(robloxGui and robloxGui:FindFirstChild("Blossom"))
            if gethui then add(gethui():FindFirstChild("Blossom")) end
        end)
        for _, rootObject in ipairs(roots) do
            if rootObject then
                for _, object in ipairs(rootObject:GetDescendants()) do
                    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                        local text = object.Text
                        if type(text) == "string" and text ~= "" then
                            local replaced = text
                            for _, name in ipairs(names) do
                                replaced = replaced:gsub(name:gsub("%p", "%%%0"), "Hidden")
                            end
                            if replaced ~= text then change(object, "Text", replaced) end
                        end
                    end
                end
            end
        end
    end)
    Toggles.StreamerMode:OnChanged(function(state)
        if state then return end
        for object, changes in pairs(Runtime.Changed) do
            if changes.Text then restore(object, "Text") end
        end
    end)

    loop("FovOn", 0, function()
        if not Runtime.Changed[Camera] or not Runtime.Changed[Camera].FieldOfView then change(Camera, "FieldOfView", Camera.FieldOfView) end
        Camera.FieldOfView = value("FieldOfView", 70)
    end)
    Toggles.FovOn:OnChanged(function(state) if not state then restore(Camera, "FieldOfView") end end)

    local espOk, espResult = pcall(buildEsp)
    if espOk then Esp = espResult; Runtime.Esp = espResult else notify("ESP could not start: " .. tostring(espResult)) end

    if Esp then
        for _, other in ipairs(Players:GetPlayers()) do Esp.AddPlayer(other) end
        connect(Players.PlayerAdded, Esp.AddPlayer)
        connect(Players.PlayerRemoving, Esp.RemovePlayer)

        local function carLabel(prefix)
            return function(model)
                local hull = model:FindFirstChild("Hull")
                local speed = hull and math.round(hull.AssemblyLinearVelocity.Magnitude) or 0
                return prefix .. Esp.prettyKind(model:GetAttribute("Kind")) .. " [{distance}] " .. speed .. " sps"
            end
        end
        local policeText, trafficText = carLabel("POLICE "), carLabel("")
        local function parkedText(model)
            local owner = Players:GetPlayerByUserId(tonumber(model:GetAttribute("Owner")) or 0)
            return (owner and owner.DisplayName .. "'s " or "") .. Esp.prettyKind(model:GetAttribute("Kind")) .. " [{distance}]"
        end

        launch(function()
            while Runtime.Alive do
                pcall(function()
                    local settings = Esp.settings
                    local accent = value("EspColor", Color3.fromRGB(255, 90, 90))
                    settings.enabled = on("EspPlayers")
                    settings.box, settings.boxFill, settings.box3d = on("EspBox"), on("EspBoxFill"), on("EspBox3d")
                    settings.name, settings.vehicle, settings.distance = on("EspName"), on("EspVehicle"), on("EspDistance")
                    settings.healthBar, settings.healthText = on("EspHealth"), on("EspHealthText")
                    settings.tracer, settings.tracerOrigin = on("EspTracer"), value("EspTracerOrigin", "Bottom")
                    settings.offScreenArrow = on("EspArrow")
                    settings.chams, settings.chamsVisibleOnly = on("EspChams"), on("EspChamsVisible")
                    settings.useTeamColor = on("EspTeamColor")
                    settings.boxColor = {accent, 1}
                    settings.boxFillColor = {accent, 0.25}
                    settings.box3dColor = {accent, 1}
                    settings.tracerColor = {accent, 1}
                    settings.chamsFillColor = {accent, 0.6}
                    settings.chamsOutlineColor = {accent, 0}
                    settings.maxDistance = value("EspRange", 2000)

                    local range = value("EspVehicleRange", 800)
                    local eye = Camera.CFrame.Position
                    local live = {}
                    for _, model in ipairs(Game.cars()) do
                        local hull = model:FindFirstChild("Hull")
                        if hull and (hull.Position - eye).Magnitude <= range then
                            local options
                            if Game.isPolice(model) and on("EspPolice") then
                                options = {enabled = true, text = policeText, textColor = {value("EspPoliceColor", Color3.fromRGB(90, 160, 255)), 1}}
                            elseif Game.isTraffic(model) and on("EspTraffic") then
                                options = {enabled = true, text = trafficText, textColor = {value("EspTrafficColor", Color3.fromRGB(220, 220, 220)), 1}}
                            elseif on("EspEmpty") and (tonumber(model:GetAttribute("Owner")) or 0) > 0
                                and model:GetAttribute("Owner") ~= Player.UserId and (tonumber(model:GetAttribute("Driver")) or 0) == 0 then
                                options = {enabled = true, text = parkedText, textColor = {value("EspEmptyColor", Color3.fromRGB(255, 200, 90)), 1}}
                            end
                            if options then
                                options.maxDistance = range
                                live[model] = true
                                Esp.AddLabel(model, options)
                            end
                        end
                    end
                    for instance in pairs(Esp._labelCache) do
                        if not live[instance] then Esp.RemoveLabel(instance) end
                    end
                end)
                task.wait(0.5)
            end
        end)
    end

    Runtime.Ready = true
    Runtime.Game = Game
    notify("BloxNG loaded")
end

local ok, err = xpcall(setup, debug.traceback)
if not ok then unload(); error("Nobulem BloxNG: " .. tostring(err), 0) end
