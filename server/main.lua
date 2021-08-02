local NewPlayer, LoadPlayer = -1, -1
CreateThread(function()
	SetMapName('San Andreas')
	SetGameType('ESX Legacy')

	local query = '`accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`' -- Select these fields from the database
	if Config.Multichar or Config.Identity then	-- append these fields to the select query
		query = query..', `firstname`, `lastname`, `dateofbirth`, `sex`, `height`'
	end

	if Config.Multichar then -- insert identity data with creation
		exports.ghmattimysql:store("INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?, `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?", function(storeId)
			NewPlayer = storeId
		end)
	else
		exports.ghmattimysql:store("INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?", function(storeId)
			NewPlayer = storeId
		end)
	end

	exports.ghmattimysql:store("SELECT "..query.." FROM `users` WHERE identifier = ?", function(storeId)
		LoadPlayer = storeId
	end)
end)

if Config.Multichar then
	AddEventHandler('esx:onPlayerJoined', function(src, char, data)
		if not ESX.Players[src] then
			local identifier = char..':'..ESX.GetIdentifier(src)
			if data then
				createESXPlayer(identifier, src, data)
			else
				loadESXPlayer(identifier, src, false)
			end
		end
	end)
else
	RegisterNetEvent('esx:onPlayerJoined')
	AddEventHandler('esx:onPlayerJoined', function()
		if not ESX.Players[source] then
			onPlayerJoined(source)
		end
	end)
end

function onPlayerJoined(playerId)
	local identifier = ESX.GetIdentifier(playerId)
	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			DropPlayer(playerId, ('there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			exports.ghmattimysql:scalar('SELECT 1 FROM users WHERE identifier = @identifier', {
				['@identifier'] = identifier
			}, function(result)
				if result then
					loadESXPlayer(identifier, playerId, false)
				else createESXPlayer(identifier, playerId) end
			end)
		end
	else
		DropPlayer(playerId, 'there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end

function createESXPlayer(identifier, playerId, data)
	local accounts = {}

	for account,money in pairs(Config.StartingAccountMoney) do
		accounts[account] = money
	end

	if IsPlayerAceAllowed(playerId, "command") then
		print(('^2[INFO] ^0 Player ^5%s ^0Has been granted admin permissions via ^5Ace Perms.^7'):format(playerId))
		defaultGroup = "admin"
	else
		defaultGroup = "user"
	end

	if not Config.Multichar then
		exports.ghmattimysql:execute(NewPlayer, {
				json.encode(accounts),
				identifier,
				defaultGroup,
		}, function(result)
			loadESXPlayer(identifier, playerId, true)
		end)
	else
		exports.ghmattimysql:execute(NewPlayer, {
				json.encode(accounts),
				identifier,
				defaultGroup,
				data.firstname,
				data.lastname,
				data.dateofbirth,
				data.sex,
				data.height,
		}, function(result)
			loadESXPlayer(identifier, playerId, true)
		end)
	end
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
	deferrals.defer()
	local playerId = source
	local identifier = ESX.GetIdentifier(playerId)
	Wait(100)

	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			deferrals.done(('There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same account.\n\nYour identifier: %s'):format(identifier))
		else
			deferrals.done()
		end
	else
		deferrals.done('There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end)

function loadESXPlayer(identifier, playerId, isNew)
	local tasks = {}

	local userData = {
		accounts = {},
		inventory = {},
		job = {},
		playerName = GetPlayerName(playerId),
	}

	table.insert(tasks, function(cb)
		exports.ghmattimysql:execute(LoadPlayer, { identifier
		}, function(result)
			local Player = Player(playerId).state

			local job, grade, jobObject, gradeObject = result[1].job, result[1].job_grade
			local foundAccounts, foundItems = {}, {}

			-- Accounts
			if result[1].accounts and result[1].accounts ~= '' then
				local accounts = json.decode(result[1].accounts)

				for account,money in pairs(accounts) do
					foundAccounts[account] = money
				end
			end

			for account,label in pairs(Config.Accounts) do
				table.insert(userData.accounts, {
					name = account,
					money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
					label = label
				})
			end

			-- Job
			if ESX.DoesJobExist(job, grade) then
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			else
				print(('[^3WARNING^7] Ignoring invalid job for %s [job: %s, grade: %s]'):format(identifier, job, grade))
				job, grade = 'unemployed', 1
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			end

			userData.job.id = jobObject.id
			userData.job.name = jobObject.name
			userData.job.label = jobObject.label

			userData.job.grade = tonumber(grade)
			userData.job.grade_name = gradeObject.name
			userData.job.grade_label = gradeObject.label
			userData.job.grade_salary = gradeObject.salary

			userData.job.skin_male = {}
			userData.job.skin_female = {}

			if gradeObject.skin_male then userData.job.skin_male = json.decode(gradeObject.skin_male) end
			if gradeObject.skin_female then userData.job.skin_female = json.decode(gradeObject.skin_female) end

			-- Inventory
			if result[1].inventory and result[1].inventory ~= '' then
				userData.inventory = json.decode(result[1].inventory)
			end

			-- Group
			if result[1].group then
				if result[1].group == "superadmin" then
					userData.group = "admin"
				else
					userData.group = result[1].group
				end
			else
				userData.group = 'user'
			end

			-- Position
			if result[1].position and result[1].position ~= '' then
				userData.coords = json.decode(result[1].position)
			else
				print('[^3WARNING^7] Column ^5"position"^0 in ^5"users"^0 table is missing required default value. Using backup coords, fix your database.')
				userData.coords = {x = -269.4, y = -955.3, z = 31.2, heading = 205.8}
			end

			-- Skin
			if result[1].skin and result[1].skin ~= '' then
				userData.skin = json.decode(result[1].skin)
			else
				if userData.sex == 'f' then userData.skin = {sex=1} else userData.skin = {sex=0} end
			end

			-- Identity
			if result[1].firstname and result[1].firstname ~= '' then
				userData.firstname = result[1].firstname
				userData.lastname = result[1].lastname
				userData.playerName = userData.firstname..' '..userData.lastname
				if result[1].dateofbirth then userData.dateofbirth = result[1].dateofbirth end
				if result[1].sex then userData.sex = result[1].sex end
				if result[1].height then userData.height = result[1].height end
			end

			-- Statebags
			Player.firstName = userData.firstname
			Player.lastName = userData.lastname
			Player.job = jobObject.label
			Player.grade = gradeObject.label
			Player.cuffed = false
			Player.handsup = false
			Player.escorted = false
			Player.busy = false
			Player.duty = false
			Player.dead = false

			cb()
		end)
	end)

	Async.parallel(tasks, function(results)
		local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.job, userData.playerName, userData.coords)
		ESX.Players[playerId] = xPlayer

		if userData.firstname then
			xPlayer.set('firstName', userData.firstname)
			xPlayer.set('lastName', userData.lastname)
			if userData.dateofbirth then xPlayer.set('dateofbirth', userData.dateofbirth) end
			if userData.sex then xPlayer.set('sex', userData.sex) end
			if userData.height then xPlayer.set('height', userData.height) end
		end
		TriggerEvent('esx:playerLoaded', playerId, xPlayer, isNew)

		xPlayer.triggerEvent('esx:playerLoaded', {
			accounts = xPlayer.getAccounts(),
			coords = xPlayer.getCoords(),
			identifier = xPlayer.getIdentifier(),
			inventory = xPlayer.getInventory(),
			job = xPlayer.getJob(),
			money = xPlayer.getMoney(),
			name = xPlayer.getName(),
			dead = false
		}, isNew, userData.skin)

		TriggerEvent('linden_inventory:setPlayerInventory', xPlayer, userData.inventory)
		xPlayer.triggerEvent('esx:registerSuggestions', Core.RegisteredCommands)
		print(('[^2INFO^0] Player ^5"%s" ^0has connected to the server. ID: ^5%s^7'):format(xPlayer.getName(), playerId))
	end)
end

AddEventHandler('chatMessage', function(playerId, author, message)
	if message:sub(1, 1) == '/' and playerId > 0 then
		CancelEvent()
		local commandName = message:sub(1):gmatch("%w+")()
		TriggerClientEvent('chat:addMessage', playerId, {args = {'^1SYSTEM', _U('commanderror_invalidcommand', commandName)}})
	end
end)

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		TriggerEvent('esx:playerDropped', playerId, reason)

		ESX.SavePlayer(xPlayer, function()
			ESX.Players[playerId] = nil
		end)
	end
end)

if Config.Multichar then
	AddEventHandler('esx:playerLogout', function(playerId)
		local xPlayer = ESX.GetPlayerFromId(playerId)
		if xPlayer then
			TriggerEvent('esx:playerDropped', playerId, reason)

			ESX.SavePlayer(xPlayer, function()
				ESX.Players[playerId] = nil
			end)
		end
		TriggerClientEvent("esx:onPlayerLogout", playerId)
	end)
end

RegisterNetEvent('esx:updateCoords')
AddEventHandler('esx:updateCoords', function(coords)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

ESX.RegisterServerCallback('esx:getPlayerData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		money        = xPlayer.getMoney(),
		name		 = xPlayer.getName()
	})
end)

ESX.RegisterServerCallback('esx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		money        = xPlayer.getMoney(),
		name         = xPlayer.getName()
	})
end)

ESX.RegisterServerCallback('esx:getPlayerNames', function(source, cb, players)
	players[source] = nil

	for playerId,v in pairs(players) do
		local xPlayer = ESX.GetPlayerFromId(playerId)

		if xPlayer then
			players[playerId] = xPlayer.getName()
		else
			players[playerId] = nil
		end
	end

	cb(players)
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
	if eventData.secondsRemaining == 60 then
		CreateThread(function()
			Wait(50000)
			Core.SavePlayers()
		end)
	end
end)

print('[^2INFO^7] ESX ^5Legacy^0 initialized')
Core.StartPayCheck()
SetInterval('save', 900000, function() -- 15 minutes
	Core.SavePlayers()
end)

-- version check
CreateThread(
	function()
		local vRaw = LoadResourceFile(GetCurrentResourceName(), 'version.json')
		if vRaw then
			local v = json.decode(vRaw)
			PerformHttpRequest(
				'https://raw.githubusercontent.com/overextended/es_extended/main/version.json',
				function(code, res, headers)
					if code == 200 then
						local rv = json.decode(res)
						if rv.version == v.version then
							if rv.commit ~= v.commit then
							print(
								([[

^1----------------------------------------------------------------------
^1URGENT: YOUR ES_EXTENDED IS OUTDATED!
^1COMMIT UPDATE: ^5%s AVAILABLE
^1DOWNLOAD:^5 https://github.com/overextended/es_extended
^1CHANGELOG:^5 %s
^1-----------------------------------------------------------------------
^0]]):format(
									rv.commit,
									rv.changelog
								)
							)
						else
							print(
								([[

^8-------------------------------------------------------
^2Your es_extended is the latest version!
^5Version:^0 %s
^5COMMIT:^0 %s
^5CHANGELOG:^0 %s
^8-------------------------------------------------------
^0]]):format(
								 	rv.version,
									rv.commit,
									rv.changelog
								)
							)
						end
					else
						print(
							([[
^1----------------------------------------------------------------------
^1URGENT: YOUR ES_EXTENDED IS OUTDATED!!!
^1COMMIT UPDATE: ^5%s AVAILABLE
^1DOWNLOAD:^5 https://github.com/overextended/es_extended
^1CHANGELOG:^5 %s
^1-----------------------------------------------------------------------
^0]]):format(
								rv.commit,
								rv.changelog
							)
						)
						end
					else
						print('[^1ERROR^0] es_extended unable to check version!')
					end
				end,
				'GET'
			)
		end
	end
)
