-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local VehicleList = {}


Citizen.CreateThread(function()
    Wait(1000)
    LoadKeysFromFile()
end)

-----------------------
----   Threads     ----
-----------------------

-----------------------
---- Server Events ----
-----------------------

-- Event to give keys. receiver can either be a single id, or a table of ids.
-- Must already have keys to the vehicle, trigger the event from the server, or pass forcegive paramter as true.
RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local giver = source

    if HasKeys(giver, plate) then
        TriggerClientEvent('QBCore:Notify', giver, "You hand over the keys.", 'success')
        if type(receiver) == 'table' then
            for _,r in ipairs(receiver) do
                GiveKeys(receiver[r], plate)
            end
        else
            GiveKeys(receiver, plate)
        end
    else
        TriggerClientEvent('QBCore:Notify', giver, "You don't have keys to this vehicle.", "error")
    end
end)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    GiveKeys(src, plate)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetVehicleKeys', function(source, cb)
    local citizenid = QBCore.Functions.GetPlayer(source).PlayerData.citizenid
    local keysList = {}
    for plate, citizenids in pairs (VehicleList) do
        if citizenids[citizenid] then
            keysList[plate] = true
        end
    end
    cb(keysList)
end)

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    local citizenid = QBCore.Functions.GetPlayer(id).PlayerData.citizenid

    if not VehicleList[plate] then VehicleList[plate] = {} end
    VehicleList[plate][citizenid] = true
    
    TriggerClientEvent('QBCore:Notify', id, "You get keys to the vehicle!")
    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', id, plate)
end

function RemoveKeys(id, plate)
    local citizenid = QBCore.Functions.GetPlayer(id).PlayerData.citizenid

    if VehicleList[plate] and VehicleList[plate][citizenid] then
        VehicleList[plate][citizenid] = nil
    end

    TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', id, plate)
end

function HasKeys(id, plate)
    local citizenid = QBCore.Functions.GetPlayer(id).PlayerData.citizenid
    if VehicleList[plate] and VehicleList[plate][citizenid] then
        return true
    end
    return false
end

QBCore.Commands.Add("engine", "Toggle Engine", {}, false, function(source, _)
	TriggerClientEvent('qb-vehiclekeys:client:ToggleEngine', source)
end)

QBCore.Commands.Add("givekeys", "Hand over the keys to someone. If no ID, gives to closest person or everyone in the vehicle.", {{name = "id", help = "Player ID"}}, false, function(source, args)
	local src = source
    TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', src, tonumber(args[1]))
end)

QBCore.Commands.Add("addkeys", "Adds keys to a vehicle for someone.", {{name = "id", help = "Player ID"}, {name = "plate", help = "Plate"}}, true, function(source, args)
	local src = source
    if not args[1] or not args[2] then 
        TriggerClientEvent('QBCore:Notify', src, 'Fill out the player ID and Plate arguments.')
        return
    end
    GiveKeys(tonumber(args[1]), args[2])
end, 'admin')

QBCore.Commands.Add("removekeys", "Remove keys to a vehicle for someone.", {{name = "id", help = "Player ID"}, {name = "plate", help = "Plate"}}, true, function(source, args)
	local src = source
    if not args[1] or not args[2] then 
        TriggerClientEvent('QBCore:Notify', src, 'Fill out the player ID and Plate arguments.')
        return
    end
    RemoveKeys(tonumber(args[1]), args[2])
end, 'admin')

function SaveKeysToFile()
    SaveResourceFile(GetCurrentResourceName(), "vehicle-keys.json", json.encode(VehicleList), -1)
end
  
function LoadKeysFromFile()
    local vehicles = LoadResourceFile(GetCurrentResourceName(), "vehicle-keys.json")
    if vehicles ~= '' then
        VehicleList = json.decode(vehicles)
    end
end

function Trim(value)
	if value then
		return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
	else
		return nil
	end
end

-- save keys when server reboots
AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining == 60 then
        Citizen.CreateThread(function() 
        Wait(50000)
        SaveKeysToFile()
        end)
    end
end)

-- remove key when vehicle is unregistered
RegisterServerEvent('persistent-vehicles/server/forget-vehicle')
AddEventHandler("persistent-vehicles/server/forget-vehicle", function(plate)
    if VehicleList ~= nil then
        for k, val in pairs(VehicleList) do
            if val.plate == plate then
                VehicleList[k] = nil
                break
            end
        end
    end
end)

RegisterServerEvent('persistent-vehicles/server/delete-vehicle-by-netId')
AddEventHandler("persistent-vehicles/server/delete-vehicle-by-netId", function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local plate = Trim(GetVehicleNumberPlateText(entity))
    if VehicleList ~= nil then
        for k, val in pairs(VehicleList) do
            if val.plate == plate then
                VehicleList[k] = nil
                break
            end
        end
    end
end)

-- save vehicle keys when mod restarts
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SaveKeysToFile()
end)
