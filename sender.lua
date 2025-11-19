-- sender.lua
-- Usage:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/saiyyaa/bgsi-autotrade/refs/heads/main/sender.lua"))({
--     TARGET_PLAYER = "Tesploited",
--     ADD_PETS = true,
--     ACCEPT_DELAY = 15,
--     CONFIRM_DELAY = 10,
--     POST_TRADE_DELAY = 15,
--     MAX_PETS = 10,
--     JOB_IDS = { "1a42f208-4ce4-4828-904a-0a87c4e3cca8" },
-- })
--
-- The chunk returns a function that accepts a single config table and starts the autotrade loop.

return function(user_cfg)
    -- defaults
    local defaults = {
        TARGET_PLAYER = "Tesploited",
        ADD_PETS = true,
        ACCEPT_DELAY = 15,
        CONFIRM_DELAY = 10,
        POST_TRADE_DELAY = 15,
        MAX_PETS = 10,
        JOB_IDS = {
            "1a42f208-4ce4-4828-904a-0a87c4e3cca8",
        },
        AUTO_START = true,
        -- optional initial wait to allow game to load (kept small if not specified)
        INITIAL_WAIT = 20,
    }

    local cfg = {}
    user_cfg = user_cfg or {}
    for k, v in pairs(defaults) do
        if user_cfg[k] ~= nil then
            cfg[k] = user_cfg[k]
        else
            cfg[k] = v
        end
    end
    -- allow JOB_IDS as single string
    if user_cfg.JOB_IDS ~= nil then
        if type(user_cfg.JOB_IDS) == "string" then
            cfg.JOB_IDS = { user_cfg.JOB_IDS }
        elseif type(user_cfg.JOB_IDS) == "table" then
            cfg.JOB_IDS = user_cfg.JOB_IDS
        end
    end

    -- preserve original behavior: initial wait and fps cap if available
    if cfg.INITIAL_WAIT and cfg.INITIAL_WAIT > 0 then
        task.wait(cfg.INITIAL_WAIT)
    end
    pcall(function()
        if setfpscap and type(setfpscap) == "function" then
            setfpscap(15)
        end
    end)

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")

    -- try to get RemoteEvent safely
    local Network
    pcall(function()
        Network = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
    end)
    -- fallback to original path if WaitForChild chain fails (keeps compatibility with original)
    if not Network and ReplicatedStorage:FindFirstChild("Shared") then
        pcall(function()
            Network = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
        end)
    end

    local LocalPlayer = Players.LocalPlayer
    local ok, LocalData = pcall(function()
        return require(ReplicatedStorage.Client.Framework.Services.LocalData)
    end)
    if not ok then
        LocalData = nil
    end
    local ok2, PetsModule = pcall(function()
        return require(ReplicatedStorage.Shared.Data.Pets)
    end)
    if not ok2 then
        PetsModule = {}
    end

    -- teleport to job instance
    local function joinJob(jobId)
        if tostring(game.JobId) == tostring(jobId) then return true end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        end)
        return ok
    end

    local function tryJoinJobIds()
        for _, jobId in ipairs(cfg.JOB_IDS or {}) do
            if joinJob(jobId) then
                return true
            end
        end
        return false
    end

    pcall(tryJoinJobIds)

    local function getGoodPets()
        if not LocalData then return {} end
        local data = LocalData:Get()
        if not data or not data.Pets then return {} end
        local out = {}
        for _, pet in pairs(data.Pets) do
            local info = PetsModule and PetsModule[pet.Name]
            if info and (info.Rarity == "Secret" or info.Rarity == "Infinity") then
                table.insert(out, pet.Id)
            end
        end
        return out
    end

    local function tradeActive()
        -- original script always returned true; placeholder for future checks
        return true
    end

    local disconnect_handle
    if Network and Network.OnClientEvent then
        disconnect_handle = Network.OnClientEvent:Connect(function(action)
            if action == "TradeEnded" then
                task.delay(cfg.POST_TRADE_DELAY, function()
                    pcall(function() LocalPlayer:Kick("Trade complete") end)
                end)
            end
        end)
    end

    local function runTrade()
        local target = Players:FindFirstChild(cfg.TARGET_PLAYER)
        if not target then return end

        if Network then
            pcall(function()
                Network:FireServer("TradeRequest", target)
            end)
        end

        local t = cfg.ACCEPT_DELAY
        repeat
            task.wait(1)
            t = t - 1
        until t <= 0 or not tradeActive()

        if not tradeActive() then return end

        if cfg.ADD_PETS then
            local pets = getGoodPets()
            for i = 1, math.min(#pets, cfg.MAX_PETS) do
                if not tradeActive() then return end
                if Network then
                    pcall(function()
                        Network:FireServer("TradeAddPet", tostring(pets[i]) .. ":0")
                    end)
                end
                task.wait(0.6)
            end
        end

        if not tradeActive() then return end
        if Network then pcall(function() Network:FireServer("TradeAccept") end) end
        task.wait(cfg.CONFIRM_DELAY)

        if not tradeActive() then return end
        if Network then pcall(function() Network:FireServer("TradeConfirm") end) end
    end

    -- run loop in a separate thread and return controller
    local running = true
    local loop_thread = task.spawn(function()
        while running do
            pcall(runTrade)
            task.wait(2)
        end
    end)

    -- return control table so caller can stop or update config
    return {
        stop = function()
            running = false
            if disconnect_handle and disconnect_handle.Disconnect then
                pcall(function() disconnect_handle:Disconnect() end)
            elseif disconnect_handle and disconnect_handle.disconnect then
                pcall(function() disconnect_handle:disconnect() end)
            end
        end,
        update = function(new_cfg)
            if type(new_cfg) ~= "table" then return end
            for k, v in pairs(new_cfg) do
                if defaults[k] ~= nil then
                    cfg[k] = v
                end
            end
            if new_cfg.JOB_IDS ~= nil then
                if type(new_cfg.JOB_IDS) == "string" then
                    cfg.JOB_IDS = { new_cfg.JOB_IDS }
                elseif type(new_cfg.JOB_IDS) == "table" then
                    cfg.JOB_IDS = new_cfg.JOB_IDS
                end
            end
        end,
        cfg = cfg,
    }
end
