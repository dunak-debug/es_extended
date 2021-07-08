local isDead = false
SetInterval('death', 100, function()
	local playerPed = PlayerPedId()
	if ESX.PlayerData.ped ~= playerPed then ESX.SetPlayerData('ped', playerPed) end

	if not isDead and IsPedFatallyInjured(playerPed) then
		isDead = true

		local killerEntity, deathCause = GetPedSourceOfDeath(playerPed), GetPedCauseOfDeath(playerPed)
		local killerClientId = NetworkGetPlayerIndexFromPed(killerEntity)

		if killerEntity ~= playerPed and killerClientId and NetworkIsPlayerActive(killerClientId) then
			PlayerKilledByPlayer(GetPlayerServerId(killerClientId), killerClientId, deathCause)
		else
			PlayerKilled(deathCause)
		end

	elseif isDead and not IsPedFatallyInjured(playerPed) then
		isDead = false
	else
		Citizen.Wait(400)
	end
end)

function PlayerKilledByPlayer(killerServerId, killerClientId, deathCause)
	local victimCoords = GetEntityCoords(PlayerPedId())
	local killerCoords = GetEntityCoords(GetPlayerPed(killerClientId))
	local distance = #(victimCoords - killerCoords)

	local data = {
		victimCoords = {x = ESX.Math.Round(victimCoords.x, 1), y = ESX.Math.Round(victimCoords.y, 1), z = ESX.Math.Round(victimCoords.z, 1)},
		killerCoords = {x = ESX.Math.Round(killerCoords.x, 1), y = ESX.Math.Round(killerCoords.y, 1), z = ESX.Math.Round(killerCoords.z, 1)},

		killedByPlayer = true,
		deathCause = deathCause,
		distance = ESX.Math.Round(distance, 1),

		killerServerId = killerServerId,
		killerClientId = killerClientId
	}

	TriggerEvent('esx:onPlayerDeath', data)
	TriggerServerEvent('esx:onPlayerDeath', data)
end

function PlayerKilled(deathCause)
	local playerPed = PlayerPedId()
	local victimCoords = GetEntityCoords(playerPed)

	local data = {
		victimCoords = {x = ESX.Math.Round(victimCoords.x, 1), y = ESX.Math.Round(victimCoords.y, 1), z = ESX.Math.Round(victimCoords.z, 1)},

		killedByPlayer = false,
		deathCause = deathCause
	}

	TriggerEvent('esx:onPlayerDeath', data)
	TriggerServerEvent('esx:onPlayerDeath', data)
end
