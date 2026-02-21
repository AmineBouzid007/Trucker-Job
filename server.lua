local ESX = exports['es_extended']:getSharedObject()

-- =========================
-- DATA STORAGE
-- =========================
local convoys = {} 
local DynamicJobs = {} 

-- =========================
-- JOB GENERATION LOGIC
-- =========================

local function GenerateDailyJobs()
    DynamicJobs = {}
    math.randomseed(os.time())
    
    -- Pull from Config.JobPool defined in convoy_config.lua
    if not Config or not Config.JobPool then
        print("^1[Truck Job] Error: Config.JobPool is missing! Check your fxmanifest loading order.^7")
        return
    end

    for i = 1, (Config.MaxDailyJobs or 4) do
        local base = Config.JobPool[math.random(#Config.JobPool)]
        table.insert(DynamicJobs, {
            id = i,
            name = base.name .. " #" .. math.random(100, 999),
            type = base.type,
            totalPrice = (base.basePrice or 500) + math.random(50, 200),
            imgSrc = base.img,
            level = base.minLevel or 1,
            distance = math.random(50, 150)
        })
    end
    print("^2[Truck Job]^7 Generated " .. #DynamicJobs .. " dynamic contracts.")
end

local function AttemptJobGeneration()
    local attempts = 0
    while not Config or not Config.JobPool do
        attempts = attempts + 1
        print("^3[Truck Job] Waiting for Config to load (Attempt " .. attempts .. ")...^7")
        Wait(1000) -- Wait 1 second
        if attempts > 5 then
            print("^1[Truck Job] Error: Config.JobPool NOT FOUND after 5 attempts. Check convoy_config.lua syntax!^7")
            return
        end
    end
    GenerateDailyJobs()
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Run this in a thread so it doesn't block the whole server
        CreateThread(function()
            AttemptJobGeneration()
        end)
    end
end)

-- =========================
-- CALLBACKS
-- =========================

ESX.RegisterServerCallback('truckjob:getData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        cb({
            serverID = source,
            player = {
                name = xPlayer.getName(),
                level = 1, 
                xp = 25
            },
            jobs = DynamicJobs -- Critical: Sends the generated list
        })
    else
        cb(nil)
    end
end)

-- =========================
-- INTERNAL UTILS
-- =========================

local function UpdateConvoyUI(convoyID)
    if not convoys[convoyID] then return end
    local members = convoys[convoyID].members
    for _, member in ipairs(members) do
        TriggerClientEvent('truckjob:client:updateConvoyPlayers', member.id, members, convoyID)
    end
end

-- =========================
-- CONVOY LOGIC
-- =========================

RegisterNetEvent('truckjob:server:createConvoy', function(convoyID)
    local src = source
    local playerName = GetPlayerName(src)
    convoys[convoyID] = {
        leader = src,
        members = { {name = playerName .. " (Leader)", id = src, isLeader = true} },
        currentJob = nil
    }
    UpdateConvoyUI(convoyID)
end)

RegisterNetEvent('truckjob:server:joinConvoy', function(convoyID)
    local src = source
    if convoys[convoyID] then
        table.insert(convoys[convoyID].members, {name = GetPlayerName(src), id = src, isLeader = false})
        UpdateConvoyUI(convoyID)
        -- If a job is already picked, sync it to the new member
        if convoys[convoyID].currentJob then
            TriggerClientEvent('truckjob:client:syncConvoyJob', src, convoys[convoyID].currentJob)
        end
    else
        TriggerClientEvent('truckjob:client:joinFailed', src)
    end
end)

RegisterNetEvent('truckjob:server:selectJob', function(data)
    local src = source
    local convoyID = data.convoyID
    if convoyID and convoys[convoyID] and convoys[convoyID].leader == src then
        convoys[convoyID].currentJob = data.jobData
        for _, member in ipairs(convoys[convoyID].members) do
            TriggerClientEvent('truckjob:client:syncConvoyJob', member.id, data.jobData)
        end
    end
end)

RegisterNetEvent('truckjob:server:requestConvoyStart', function(jobType, convoyID)
    local src = source
    local destCount = 3 
    if Locations and Locations.DeliveryPoints and Locations.DeliveryPoints[jobType] then
        destCount = #Locations.DeliveryPoints[jobType]
    end
    local sharedIndex = math.random(1, destCount)

    if convoys[convoyID] and convoys[convoyID].leader == src then
        for _, member in ipairs(convoys[convoyID].members) do
            TriggerClientEvent('truckjob:client:startSyncedJob', member.id, jobType, sharedIndex)
        end
    else
        TriggerClientEvent('truckjob:client:startSyncedJob', src, jobType, sharedIndex)
    end
end)

RegisterNetEvent('truckjob:pay', function(amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        xPlayer.addMoney(amount)
        TriggerClientEvent('truckjob:updateStats', source, { level = 1, xp = 75 })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, data in pairs(convoys) do
        if data.leader == src then
            for _, m in ipairs(data.members) do
                if m.id ~= src then TriggerClientEvent('truckjob:client:joinFailed', m.id) end
            end
            convoys[id] = nil 
        else
            for i, m in ipairs(data.members) do
                if m.id == src then 
                    table.remove(data.members, i) 
                    UpdateConvoyUI(id)
                    break 
                end
            end
        end
    end
end)
