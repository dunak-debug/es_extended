ESX = {}
ESX.Players = {}
ESX.UsableItemsCallbacks = {}
ESX.Items = {}
ESX.ServerCallbacks = {}
ESX.TimeoutCount = -1
ESX.CancelledTimeouts = {}
ESX.Jobs = {}
ESX.RegisteredCommands = {}
Core = {}

AddEventHandler('esx:getSharedObject', function(cb)
	cb(ESX)
end)

function getSharedObject()
	return ESX
end

RegisterServerEvent('esx:clientLog')
AddEventHandler('esx:clientLog', function(msg)
	if Config.EnableDebug then
		print(('[^2TRACE^7] %s^7'):format(msg))
	end
end)

RegisterServerEvent('esx:triggerServerCallback')
AddEventHandler('esx:triggerServerCallback', function(name, requestId, ...)
	local playerId = source

	ESX.TriggerServerCallback(name, requestId, playerId, function(...)
		TriggerClientEvent('esx:serverCallback', playerId, requestId, ...)
	end, ...)
end)



AddEventHandler('linden_inventory:loaded', function(data)
	ESX.Items = data
end)

exports('Jobs', function()
	return ESX.Jobs
end)

exports('Items', function()
	return ESX.Items
end)

Core.LoadJobs = function()
	local Jobs = {}
	local file = load(LoadResourceFile('es_extended', '/data/jobs.lua'))()
	for job, data in pairs(file) do
		Jobs[job] = {name=job, label=data.label, grades=data.grades}
		for k, v in pairs(Jobs[job].grades) do
			v.job_name = job
			v.grade = k
		end
	end
	ESX.Jobs = Jobs
	print('[^2INFO^7] Loaded jobs data')
end

Core.LoadJobs()
Core.StartPayCheck()
print('[^2INFO^7] ESX ^5Legacy^0 initialized')

SetInterval('save', 900000, function() -- 15 minutes
	ESX.SavePlayers(true)
end)