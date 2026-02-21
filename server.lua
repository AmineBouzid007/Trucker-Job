local ESX = exports['es_extended']:getSharedObject()

-- =========================
-- DATA STORAGE
-- =========================
-- Stores convoy data: { [id] = { leader = source, members = {{name, id}, ...}, currentJob = nil } }
local convoys = {} 

-- =========================
-- CALLBACKS
-- =========================

-- Fetches player name, level, and XP for the NUI Dashboard
ESX.RegisterServerCallback('truckjob:getPlayerInfo', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        cb({
            name = xPlayer.getName(),
            level = 1, -- Initial level (can be expanded with Database integration)
            xp = 25    -- Initial XP
        })
    else
        cb(nil)
    end
end)

-- =========================
-- INTERNAL UTILS
-- =========================

-- Updates the NUI player list for everyone inside a specific convoy
local function UpdateConvoyUI(convoyID)
    if not convoys[convoyID] then return end
    
    local members = convoys[convoyID].members
    for _, member in ipairs(members) do
        TriggerClientEvent('truckjob:client:updateConvoyPlayers', member.id, members)
    end
end

-- =========================
-- CONVOY LOGIC
-- =========================

-- Creates a new convoy and assigns the creator as the leader
RegisterNetEvent('truckjob:server:createConvoy', function(convoyID)
    local src = source
    local playerName = GetPlayerName(src)
    
    convoys[convoyID] = {
        leader = src,
        members = { {name = playerName .. " (Leader)", id = src} },
        currentJob = nil
    }
    
    print(string.format("^2[Truck Job]^7 Convoy #%s created by %s", convoyID, playerName))
    UpdateConvoyUI(convoyID)
end)

-- Adds a player to an existing convoy and syncs current mission if active
RegisterNetEvent('truckjob:server:joinConvoy', function(convoyID)
    local src = source
    local playerName = GetPlayerName(src)

    if convoys[convoyID] then
        table.insert(convoys[convoyID].members, {name = playerName, id = src})
        
        print(string.format("^2[Truck Job]^7 %s joined Convoy #%s", playerName, convoyID))
        
        -- Update the list for everyone in the convoy
        UpdateConvoyUI(convoyID)

        -- Sync existing mission details to the new member's UI
        if convoys[convoyID].currentJob then
            TriggerClientEvent('truckjob:client:syncConvoyJob', src, convoys[convoyID].currentJob)
        end
    else
        -- If convoy doesn't exist, tell the client to reset NUI state
        TriggerClientEvent('truckjob:client:joinFailed', src)
    end
end)

-- Triggered when a leader clicks a job in the UI to preview it for the lobby
RegisterNetEvent('truckjob:server:selectJob', function(data)
    local src = source
    local convoyID = data.convoyID
    local jobData = data.jobData

    if convoyID and convoys[convoyID] then
        if convoys[convoyID].leader == src then
            convoys[convoyID].currentJob = jobData
            
            -- Update the "Current Mission" panel for all members
            for _, member in ipairs(convoys[convoyID].members) do
                TriggerClientEvent('truckjob:client:syncConvoyJob', member.id, jobData)
            end
        else
            print(string.format("^1[Truck Job]^7 Unauthorized selection attempt by %s", GetPlayerName(src)))
        end
    else
        -- Solo Player: Simply sync to own UI
        TriggerClientEvent('truckjob:client:syncConvoyJob', src, jobData)
    end
end)

-- Finalizes the job selection and triggers the physical spawn for all members
RegisterNetEvent('truckjob:server:requestConvoyStart', function(jobType, convoyID)
    local src = source
    if convoys[convoyID] and convoys[convoyID].leader == src then
        -- Generate one random destination index for the whole group
        local destinationIndex = math.random(1, 3) 

        for _, member in ipairs(convoys[convoyID].members) do
            TriggerClientEvent('truckjob:client:startSyncedJob', member.id, jobType, destinationIndex)
        end
    end
end)

-- Handles players leaving via the NUI button
RegisterNetEvent('truckjob:server:leaveConvoy', function()
    local src = source
    for id, data in pairs(convoys) do
        for i, member in ipairs(data.members) do
            if member.id == src then
                table.remove(data.members, i)
                
                if data.leader == src then
                    -- If leader leaves, disband the whole group
                    for _, m in ipairs(data.members) do
                        TriggerClientEvent('truckjob:client:joinFailed', m.id)
                    end
                    convoys[id] = nil
                    print(string.format("^1[Truck Job]^7 Convoy #%s disbanded", id))
                else
                    -- Just update UI for remaining members
                    UpdateConvoyUI(id)
                end
                break
            end
        end
    end
end)

-- =========================
-- ECONOMY & PROGRESSION
-- =========================

-- Handles payment and XP rewards upon successful delivery
RegisterNetEvent('truckjob:pay', function(amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if xPlayer then
        xPlayer.addMoney(amount)
        
        -- Update Client side XP/Level locally
        TriggerClientEvent('truckjob:updateStats', src, {
            level = 1,
            xp = 75 
        })
        print(string.format("^2[Truck Job]^7 Paid $%s to %s", amount, xPlayer.getName()))
    end
end)

-- =========================
-- CLEANUP
-- =========================

-- Handles players disconnecting from the server
AddEventHandler('playerDropped', function()
    local src = source
    for id, data in pairs(convoys) do
        if data.leader == src then
            -- Disband if leader drops
            for _, m in ipairs(data.members) do
                if m.id ~= src then TriggerClientEvent('truckjob:client:joinFailed', m.id) end
            end
            convoys[id] = nil 
        else
            -- Remove specific member if they drop
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