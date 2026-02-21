local ESX = exports['es_extended']:getSharedObject()

-- =========================
-- VARIABLES
-- =========================
local jobActive = false
local truckEntity = nil
local trailerEntity = nil
local deliveryBlip = nil
local currentDestination = nil
local currentConvoyID = nil
local playerLevel = 1 -- Local cache of level for verification

-- =========================
-- UTILS
-- =========================
local function LoadModel(model)
    if not model then return false end
    local modelHash = type(model) == "string" and joaat(model) or model

    RequestModel(modelHash)
    local timeout = 0

    while not HasModelLoaded(modelHash) do
        Wait(10)
        timeout = timeout + 10
        if timeout > 5000 then
            print("^1[Truck Job] Model load timeout:^7", modelHash)
            return false
        end
    end
    return true
end

local function ShowHelpText(msg)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- =========================
-- NPC SETUP
-- =========================
CreateThread(function()
    if not LoadModel(Config.NPCModel) then return end

    local ped = CreatePed(4, Config.NPCModel,
        Config.NPCCoords.x,
        Config.NPCCoords.y,
        Config.NPCCoords.z - 1.0,
        Config.NPCCoords.w,
        false,
        true
    )

    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)

    local npcBlip = AddBlipForEntity(ped)
    SetBlipSprite(npcBlip, Config.NPCBlip.sprite or 477)
    SetBlipColour(npcBlip, Config.NPCBlip.color or 5)
    SetBlipScale(npcBlip, Config.NPCBlip.scale or 0.8)
    SetBlipAsShortRange(npcBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.NPCBlip.name or "Truck Job")
    EndTextCommandSetBlipName(npcBlip)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'truck_job_npc',
            icon = 'fa-solid fa-truck',
            label = 'Open Trucking Dashboard',
            distance = 3.0,
            onSelect = function()
                if jobActive then
                    lib.notify({
                        title='Truck Job',
                        description='You are already on a job!',
                        type='error'
                    })
                    return
                end

                ESX.TriggerServerCallback('truckjob:getPlayerInfo', function(playerData)
                    if playerData then
                        playerLevel = playerData.level -- Sync local level
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action = "open",
                            player = {
                                name = playerData.name,
                                level = playerData.level,
                                xp = playerData.xp
                            },
                            jobs = Config.Jobs -- Ensure jobs list is passed
                        })
                    end
                end)
            end
        }
    })
end)

-- =========================
-- NUI CALLBACKS
-- =========================
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    SetNuiFocus(false, false)
    
    if data.jobData then
        -- FINAL LEVEL CHECK (Prevents UI exploits)
        local requiredLevel = tonumber(data.jobData.level) or 1
        if playerLevel < requiredLevel then
            lib.notify({ title = 'Locked', description = 'You need Level '..requiredLevel..' for this job!', type = 'error' })
            return cb('ok')
        end

        local job = string.lower(data.jobType)
        
        if currentConvoyID and currentConvoyID ~= 0 then
            TriggerServerEvent('truckjob:server:requestConvoyStart', job, currentConvoyID)
        else
            StartTruckJob(job)
        end
    end
    cb('ok')
end)

RegisterNetEvent('truckjob:client:joinFailed', function()
    currentConvoyID = nil
    SendNUIMessage({ action = "joinFailed" })
end)

RegisterNUICallback('createConvoy', function(data, cb)
    currentConvoyID = data.id
    TriggerServerEvent('truckjob:server:createConvoy', data.id)
    cb('ok')
end)

RegisterNUICallback('joinConvoy', function(data, cb)
    currentConvoyID = data.id
    TriggerServerEvent('truckjob:server:joinConvoy', data.id)
    cb('ok')
end)

RegisterNUICallback('leaveConvoy', function(_, cb)
    currentConvoyID = nil
    TriggerServerEvent('truckjob:server:leaveConvoy')
    cb('ok')
end)

-- =========================
-- CONVOY EVENTS
-- =========================
RegisterNetEvent('truckjob:client:startSyncedJob', function(jobType, destinationIndex)
    StartTruckJob(jobType, destinationIndex)
end)

-- =========================
-- START JOB LOGIC
-- =========================
function StartTruckJob(jobType, forcedDestIndex)
    if jobActive then return end

    local truckModel = Config.TruckModels[jobType]
    local trailerModel = Config.TrailerModels[jobType]
    local destinations = Config.DeliveryPoints[jobType]

    if not destinations or #destinations == 0 then
        print("^1[Truck Job] No destinations for:^7", jobType)
        return
    end

    jobActive = true
    
    if forcedDestIndex then
        currentDestination = destinations[forcedDestIndex]
    else
        currentDestination = destinations[math.random(#destinations)]
    end

    -- 1. Spawn Truck
    if not LoadModel(truckModel) then jobActive = false return end
    
    -- Sync Offset spawning for convoys (Prevents explosions on spawn)
    local playerIdx = GetPlayerServerId(PlayerId())
    local spawnOffset = (playerIdx % 5) * 5.0 
    
    truckEntity = CreateVehicle(truckModel, Config.TruckSpawn.x + spawnOffset, Config.TruckSpawn.y, Config.TruckSpawn.z, Config.TruckSpawn.w, true, false)

    SetVehicleNumberPlateText(truckEntity, "TRKJOB")
    SetEntityAsMissionEntity(truckEntity, true, true)
    SetVehicleOnGroundProperly(truckEntity)
    
    -- 2. Spawn Trailer
    if not LoadModel(trailerModel) then return end

    local trailerPositions = {
        vector4(-1188.752, -2150.241, 13.188, 133.228),
        vector4(-1184.373, -2154.909, 13.188, 133.228),
        vector4(-1190.426, -2196.276, 13.188, 328.818),
        vector4(-1143.626, -2223.138, 13.188, 325.984),
        vector4(-1133.090, -2228.861, 13.188, 328.818)
    }

    local trailerSpawn = trailerPositions[math.random(#trailerPositions)]
    trailerEntity = CreateVehicle(trailerModel, trailerSpawn.x, trailerSpawn.y, trailerSpawn.z, trailerSpawn.w, true, false)
    SetEntityAsMissionEntity(trailerEntity, true, true)

    if not DoesEntityExist(trailerEntity) then
        jobActive = false
        DeleteVehicle(truckEntity)
        lib.notify({ title = 'Vehicle Error', description = 'Trailer failed to spawn!', type = 'error' })
        return
    end
    
    -- 3. Setup Blips
    deliveryBlip = AddBlipForCoord(currentDestination.coords)
    SetBlipSprite(deliveryBlip, 478) -- Cargo Icon
    SetBlipColour(deliveryBlip, 5)
    SetBlipRoute(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Point")
    EndTextCommandSetBlipName(deliveryBlip)

    local truckBlip = AddBlipForEntity(truckEntity)
    SetBlipSprite(truckBlip, 477)
    SetBlipColour(truckBlip, 5)
    SetBlipScale(truckBlip, 0.7)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Your Work Truck")
    EndTextCommandSetBlipName(truckBlip)

    lib.notify({
        title='Truck Job',
        description='Collect your trailer and head to '..currentDestination.label,
        type='success'
    })

    CreateThread(function()
        local inTruck = false
        while not inTruck and jobActive do
            Wait(500)
            if DoesEntityExist(truckEntity) and IsPedInVehicle(PlayerPedId(), truckEntity, false) then
                inTruck = true
                if DoesBlipExist(truckBlip) then RemoveBlip(truckBlip) end
            end
        end
    end)
end

-- =========================
-- DELIVERY LOOP
-- =========================
CreateThread(function()
    while true do
        local sleep = 1000
        if jobActive and currentDestination then
            sleep = 0
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            if truckEntity then
                -- PART 1: DELIVERING THE TRAILER
                if trailerEntity and DoesEntityExist(trailerEntity) then
                    local destCoords = currentDestination.coords
                    local distToFinish = #(playerCoords - destCoords)

                    if distToFinish < 50.0 then
                        DrawMarker(1, destCoords.x, destCoords.y, destCoords.z - 1.0, 0,0,0,0,0,0, 4.0, 4.0, 1.5, 66, 234, 123, 150, false, false, 2, false, nil, nil, false)

                        if distToFinish < 10.0 then
                            if IsVehicleAttachedToTrailer(truckEntity) then
                                ShowHelpText("Park and ~INPUT_VEH_HEADLIGHT~ (Hold) to unhook trailer")
                            else
                                local trailerPos = GetEntityCoords(trailerEntity)
                                if #(trailerPos - destCoords) < 15.0 then
                                    
                                    lib.notify({
                                        title='Truck Job',
                                        description='Cargo Delivered! Return the truck to the depot.',
                                        type='success'
                                    })

                                    local oldTrailer = trailerEntity
                                    SetEntityAsMissionEntity(oldTrailer, false, false)
                                    trailerEntity = nil 
                                    
                                    SetTimeout(3000, function()
                                        if DoesEntityExist(oldTrailer) then DeleteVehicle(oldTrailer) end
                                    end)

                                    if deliveryBlip then RemoveBlip(deliveryBlip) end

                                    local spawn = Config.TruckSpawn
                                    deliveryBlip = AddBlipForCoord(spawn.x, spawn.y, spawn.z)
                                    SetBlipSprite(deliveryBlip, 477)
                                    SetBlipColour(deliveryBlip, 2)
                                    SetBlipRoute(deliveryBlip, true)
                                    BeginTextCommandSetBlipName("STRING")
                                    AddTextComponentString("Return Truck")
                                    EndTextCommandSetBlipName(deliveryBlip)
                                else
                                    ShowHelpText("~r~Unhook the trailer inside the marker!")
                                end
                            end
                        end
                    end
                
                -- PART 2: RETURNING THE TRUCK
                else
                    local spawn = Config.TruckSpawn
                    local distToDepot = #(playerCoords - vector3(spawn.x, spawn.y, spawn.z))

                    if distToDepot < 60.0 then
                        DrawMarker(2, spawn.x, spawn.y, spawn.z + 1.5, 0,0,0, 180.0,0,0, 2.0, 2.0, 2.0, 66, 234, 123, 150, true, true, 2, false, nil, nil, false)
                        
                        if distToDepot < 8.0 then
                            ShowHelpText("Press ~INPUT_CONTEXT~ to finish")

                            if IsControlJustReleased(0, 38) then
                                if IsPedInVehicle(playerPed, truckEntity, false) then
                                    TriggerServerEvent('truckjob:pay', 500) -- Payment
                                    
                                    if deliveryBlip then RemoveBlip(deliveryBlip) end
                                    DeleteVehicle(truckEntity)
                                    truckEntity = nil
                                    jobActive = false
                                    currentDestination = nil
                                    
                                    lib.notify({title='Job Complete', description='Payment received!', type='success'})
                                else
                                    lib.notify({title='Error', description='You must be inside your truck!', type='error'})
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- =========================
-- UPDATE STATS
-- =========================
RegisterNetEvent('truckjob:updateStats', function(stats)
    if stats.level then playerLevel = stats.level end
    SendNUIMessage({ updateStats = stats }) -- Sync with app.js
end)

-- =========================
-- CLEANUP
-- =========================
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if truckEntity then DeleteVehicle(truckEntity) end
        if trailerEntity then DeleteVehicle(trailerEntity) end
        if deliveryBlip then RemoveBlip(deliveryBlip) end
    end
end)