local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/rirusbro/VapeV4ForRoblox/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/rirusbro/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/rirusbro/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newvape/profiles/whitelist.json') and readfile('newvape/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('newvape/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()
run(function()
	local AimAssist
	local Targets
	local Part
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RightClick
	local ShowTarget
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	
	local function wrapAngle(num)
		num = num % math.pi
		num -= num >= (math.pi / 2) and math.pi or 0
		num += num < -(math.pi / 2) and math.pi or 0
		return num
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
				AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
	
					if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = gameCamera.CFrame.Position
						})
	
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
	
							if ShowTarget.Enabled then
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if new ~= Vector3.zero then
								local diffYaw = wrapAngle(math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z))
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
	
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))
	
				if RightClick.Enabled then
					AimAssist:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))
	
					AimAssist:Clean(inputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 30,
		Default = 15
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = AimAssist.Enabled
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	RightClick = AimAssist:CreateToggle({
		Name = 'Require right click',
		Function = function()
			if AimAssist.Enabled then
				AimAssist:Toggle()
				AimAssist:Toggle()
			end
		end
	})
	ShowTarget = AimAssist:CreateToggle({
		Name = 'Show target info'
	})
end)
	
run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and inputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not vape.gui.ScaledGui.ClickGui.Visible then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
	
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	Mode = AutoClicker:CreateDropdown({
		Name = 'Mode',
		List = {'Tool', 'Click', 'RightClick'},
		Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)
	
run(function()
	local Reach
	local Targets
	local Mode
	local Value
	local Chance
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local modified = {}
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					tool = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true)
					if tool then
						if Mode.Value == 'TouchInterest' then
							local entites = {}
							for _, v in entitylib.List do
								if v.Targetable then
									if not Targets.Players.Enabled and v.Player then continue end
									if not Targets.NPCs.Enabled and v.NPC then continue end
									table.insert(entites, v.Character)
								end
							end
	
							Overlay.FilterDescendantsInstances = entites
							local parts = workspace:GetPartBoundsInBox(tool.Parent.CFrame * CFrame.new(0, 0, Value.Value / 2), tool.Parent.Size + Vector3.new(0, 0, Value.Value), Overlay)
	
							for _, v in parts do
								if Random.new().NextNumber(Random.new(), 0, 100) > Chance.Value then
									task.wait(0.2)
									break
								end
	
								firetouchinterest(tool.Parent, v, 1)
								firetouchinterest(tool.Parent, v, 0)
							end
						else
							if not modified[tool.Parent] then
								modified[tool.Parent] = tool.Parent.Size
							end
							tool.Parent.Size = modified[tool.Parent] + Vector3.new(0, 0, Value.Value)
							tool.Parent.Massless = true
						end
					end
	
					task.wait()
				until not Reach.Enabled
			else
				for i, v in modified do
					i.Size = v
					i.Massless = false
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Extends tool attack reach'
	})
	Targets = Reach:CreateTargets({Players = true})
	Mode = Reach:CreateDropdown({
		Name = 'Mode',
		List = {'TouchInterest', 'Resize'},
		Function = function(val)
			Chance.Object.Visible = val == 'TouchInterest'
		end,
		Tooltip = 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Chance = Reach:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)
	
local mouseClicked
run(function()
	local SilentAim
	local Target
	local Mode
	local Method
	local MethodRay
	local IgnoredScripts
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local AutoFireShootDelay
	local AutoFireMode
	local AutoFirePosition
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Projectile
	local ProjectileSpeed
	local ProjectileGravity
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.Velocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()

						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end
					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local rayCheck, delayCheck = RaycastParams.new(), tick()
	
	local function getTriggerBotTarget()
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
		local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
		if ray and ray.Instance then
			for _, v in entitylib.List do
				if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
					if ray.Instance:IsDescendantOf(v.Character) then
						return entitylib.isVulnerable(v) and v
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						if getTriggerBotTarget() and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)



end)
	
	
local Fly
local LongJump
	
	
	
	
	
	
	
	
	
	
run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if (not ent.Targetable) then return end
		
		local function update()
			if not bkg then return end
			if not entitylib.isAlive then return end
			if not ent.RootPart then return end
			if not ent.Character then return end
			if not entitylib.character.RootPart then return end
			if not ent.Character:IsDescendantOf(workspace) then return end
			
			local selfPos = entitylib.character.RootPart.Position
			local headPos = (ent.Head and ent.Head.Position or ent.RootPart.Position)
			local newPos = CFrame.lookAt(Vector3.zero, (headPos - selfPos) * Vector3.new(1, 0, 1)).LookVector
			
			local dot = Reference[ent]
			if dot and dot.Parent then
				local ui = dot:FindFirstChild('UIAspectRatioConstraint') or Instance.new('UIAspectRatioConstraint')
				ui.AspectRatio = 1
				ui.Parent = dot
				local pos = newPos * math.floor((math.clamp((headPos - selfPos).Magnitude, 1, 150)) * 1.33)
				pos = pos + Vector3.new(bkg.AbsoluteSize.X / 2, bkg.AbsoluteSize.Y / 2, 0)
				if Clamp.Enabled then
					pos = Vector3.new(
						math.clamp(pos.X, 5, bkg.AbsoluteSize.X - 5),
						math.clamp(pos.Y, 5, bkg.AbsoluteSize.Y - 5),
						0
					)
				end
				dot.Position = UDim2.fromOffset(pos.X, pos.Y)
			end
		end
	
		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
	
		Reference[ent] = dot
		update()
		
		return function()
			if dot then
				dot:Destroy()
			end
		end
	end
	
	Radar = vape:CreateHUD({
		Name = 'Radar',
		Resizable = true,
		TargetAddition = Added,
		TargetUpdate = function(ent)
			local dot = Reference[ent]
			if dot and dot.Parent then
				dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
			end
		end,
		Construct = function(object)
			bkg = Instance.new('Frame')
			bkg.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
			bkg.Parent = object
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = bkg
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromRGB(52, 52, 52)
			stroke.Thickness = 1
			stroke.Parent = bkg
	
			local axis = Instance.new('Frame')
			axis.Size = UDim2.new(1, -8, 0, 1)
			axis.Position = UDim2.fromOffset(4, 0)
			axis.AnchorPoint = Vector2.new(0, 0.5)
			axis.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
			axis.BorderSizePixel = 0
			axis.Parent = bkg
			local axis2 = axis:Clone()
			axis2.Size = UDim2.new(0, 1, 1, -8)
			axis2.Position = UDim2.fromOffset(0, 4)
			axis2.AnchorPoint = Vector2.new(0.5, 0)
			axis2.Parent = bkg
	
			Radar:Clean(runService.RenderStepped:Connect(function()
				if not object.Visible then return end
				for ent in Reference do
					local dot = Reference[ent]
					if dot and dot.Parent then
						if entitylib.isAlive and ent.Character and ent.RootPart and entitylib.character.RootPart then
							local selfPos = entitylib.character.RootPart.Position
							local headPos = (ent.Head and ent.Head.Position or ent.RootPart.Position)
							local newPos = CFrame.lookAt(Vector3.new(), (headPos - selfPos) * Vector3.new(1, 0, 1)).LookVector
							local pos = newPos * math.floor((math.clamp((headPos - selfPos).Magnitude, 1, 150)) * 1.33)
							pos = pos + Vector3.new(bkg.AbsoluteSize.X / 2, bkg.AbsoluteSize.Y / 2, 0)
							if Clamp.Enabled then
								pos = Vector3.new(
									math.clamp(pos.X, 5, bkg.AbsoluteSize.X - 5),
									math.clamp(pos.Y, 5, bkg.AbsoluteSize.Y - 5),
									0
								)
							end
							dot.Position = UDim2.fromOffset(pos.X, pos.Y)
						end
					end
				end
			end))
		end
	})
	Targets = Radar:CreateTargets({Players = true, NPCs = true})
	DotStyle = Radar:CreateDropdown({
		Name = 'Dot Style',
		List = {'Circles', 'Squares'}
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function()
			for _, v in Reference do
				if v and v.Parent then
					v.BackgroundColor3 = Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
				end
			end
		end,
		Darker = true
	})
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(h, s, v)
			if bkg then
				bkg.BackgroundColor3 = Color3.fromHSV(h, s, v)
			end
		end,
		Hide = true,
		Default = 0.25,
		Darker = true
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Function = function(callback)
			if bkg then
				bkg.BackgroundTransparency = callback and 0 or 1
			end
		end,
		Default = true,
		Darker = true
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp'
	})
end)

run(function()
	local SessionInfo
	local AvgFPS
	local FPS
	local Ping
	local KDRatio
	local KillCount
	local DeathCount
	local CPS
	local Space
	local startTime, oldamount, oldmouse, lastCount = tick(), 0, 0, tick()
	
	local function getTime()
		local new = tick() - startTime
		local s = math.floor(new % 60)
		local m = math.floor(new / 60) % 60
		local h = math.floor(new / 3600)
		return (h > 0 and (h < 10 and '0'..h or h) or '00')..':'..(m < 10 and '0'..m or m)..':'..(s < 10 and '0'..s or s)
	end
	
	SessionInfo = vape:CreateHUD({
		Name = 'Session Info',
		Construct = function(object)
			local layout = Instance.new('UIListLayout')
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 4)
			layout.Parent = object
	
			local child = function()
				local b = Instance.new('Frame')
				b.Size = UDim2.fromOffset(1, 12)
				b.AnchorPoint = Vector2.new(0, 0.5)
				b.BackgroundTransparency = 1
				b.Parent = object
				local t = Instance.new('TextLabel')
				t.Position = UDim2.fromOffset(0, 6)
				t.AnchorPoint = Vector2.new(0, 0.5)
				t.BackgroundTransparency = 1
				t.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
				t.TextSize = 12
				t.TextXAlignment = Enum.TextXAlignment.Left
				t.Parent = b
				local ui = Instance.new('UIAspectRatioConstraint')
				ui.AspectRatio = 0.066
				ui.Parent = b
				return t
			end
	
			local addSpace = function()
				local dot = Instance.new('TextLabel')
				dot.Size = UDim2.fromOffset(10, 10)
				dot.Position = UDim2.fromOffset(0, 6)
				dot.AnchorPoint = Vector2.new(0, 0.5)
				dot.BackgroundTransparency = 1
				dot.Text = ' | '
				dot.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
				dot.TextSize = 12
				dot.TextColor3 = Color3.fromRGB(200, 200, 200)
				dot.TextXAlignment = Enum.TextXAlignment.Center
				dot.Parent = object
			end
	
			AvgFPS = child()
			FPS = child()
			Ping = child()
			KDRatio = child()
			KillCount = child()
			DeathCount = child()
			CPS = child()
			Space = child()
			addSpace()
		end
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show Time',
		Function = function() end
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show FPS',
		Function = function() end,
		Default = true
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show Ping',
		Function = function() end,
		Default = true
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show K/D',
		Function = function() end,
		Default = true
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show Kills',
		Function = function() end
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show Deaths',
		Function = function() end
	})
	
	SessionInfo:CreateToggle({
		Name = 'Show CPS',
		Function = function() end
	})
	
	vape:Clean(runService.RenderStepped:Connect(function()
		if not SessionInfo.Object.Visible then return end
	
		local f = math.round((1 / runService.RenderStepped:Wait()))
		local mous = UserInputService:GetMouseButtonsPressed()
		local ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()
		local kd = (DeathCount and DeathCount.Value > 0 and (KillCount.Value / DeathCount.Value) or KillCount.Value)
		local cps = (mous and ((#mous - oldamount) / (tick() - lastCount)) or 0)
		oldamount = mous and #mous or 0
		lastCount = tick()
	
		local format = function(n) return tostring(n):gsub('%.?0+$', '') end
	
		local t = getTime()
		AvgFPS.Text = 'Up: '..t
		AvgFPS.TextColor3 = Color3.fromRGB(200, 200, 200)
		FPS.Text = ' FPS: '..format(f)
		FPS.TextColor3 = Color3.fromRGB(200, 200, 200)
		Ping.Text = ' Ping: '..math.round(ping)..'ms'
		Ping.TextColor3 = Color3.fromRGB(200, 200, 200)
		KDRatio.Text = ' K/D: '..format(kd)
		KDRatio.TextColor3 = Color3.fromRGB(200, 200, 200)
		KillCount.Text = ' Kills: '..KillCount.Value
		KillCount.TextColor3 = Color3.fromRGB(200, 200, 200)
		DeathCount.Text = ' Deaths: '..DeathCount.Value
		DeathCount.TextColor3 = Color3.fromRGB(200, 200, 200)
		CPS.Text = ' CPS: '..format(cps)
		CPS.TextColor3 = Color3.fromRGB(200, 200, 200)
	end))
end)

run(function()
	local Atmosphere
	local Color
	local SkyColor
	local Top
	local Bottom
	local Density
	local Glare
	
	Atmosphere = vape:CreateHUD({
		Name = 'Atmosphere',
		Construct = function(object)
			local atm = Instance.new('Atmosphere')
			atm.Parent = lightingService
			Atmosphere:Clean(atm)
			local sky = Instance.new('Sky')
			sky.Parent = lightingService
			Atmosphere:Clean(sky)
	
			Atmosphere:Clean(vape:SetPreview(object, function(bool)
				if bool then
					topcall(function()
						lightingService.Brightness = 3
						atm.Density = 0.497
						atm.Color = Color3.fromRGB(255, 244, 214)
						atm.Decay = Color3.fromRGB(255, 97, 21)
						atm.Glare = 0
						atm.Haze = 0
						sky.CelestialBodiesShown = false
						sky.SkyboxBk = 'rbxassetid://17277441270'
						sky.SkyboxDn = 'rbxassetid://17277442653'
						sky.SkyboxFt = 'rbxassetid://17277443736'
						sky.SkyboxLf = 'rbxassetid://17277415587'
						sky.SkyboxRt = 'rbxassetid://17276822753'
						sky.SkyboxUp = 'rbxassetid://17277407659'
						sky.SunAngularSize = 10
						sky.MoonAngularSize = 11
						sky.StarCount = 5000
					end)
				else
					Atmosphere:Toggle(true)
					Atmosphere:Toggle(false)
				end
			end))
	
			local function update()
				atm.Density = Density.Value
				atm.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				atm.Decay = Color3.fromHSV(SkyColor.Hue, SkyColor.Sat, SkyColor.Value)
				atm.Glare = Glare.Value
			end
	
			Atmosphere:Clean(Atmosphere.Update.Event:Connect(update))
		end
	})
	Glare = Atmosphere:CreateSlider({
		Name = 'Glare',
		Min = 0,
		Max = 10
	})
	Density = Atmosphere:CreateSlider({
		Name = 'Density',
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	Color = Atmosphere:CreateColorSlider({
		Name = 'Color',
		Default = 0.1
	})
	SkyColor = Atmosphere:CreateColorSlider({
		Name = 'Sky Color',
		Default = 0.3
	})
	Top = Atmosphere:CreateToggle({
		Name = 'Top Sky'
	})
	Bottom = Atmosphere:CreateToggle({
		Name = 'Bottom Sky'
	})
end)

run(function()
	local Breadcrumbs
	local Color
	local Filled
	local Transparency
	local Distance
	local Offsets = {}
	local Folder
	
	Breadcrumbs = vape:CreateHUD({
		Name = 'Breadcrumbs',
		ViewportColor = function()
			return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end,
		Construct = function()
			Folder = Instance.new('Folder')
			Folder.Name = 'breadcrumbs'
			Folder.Parent = workspace
			Breadcrumbs:Clean(Folder)
		end,
		Dimensions = Vector2.new(2, 1)
	})
	Color = Breadcrumbs:CreateColorSlider({
		Name = 'Color'
	})
	Transparency = Breadcrumbs:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	Filled = Breadcrumbs:CreateToggle({
		Name = 'Filled'
	})
	Distance = Breadcrumbs:CreateSlider({
		Name = 'Distance',
		Min = 2,
		Max = 10
	})
	
	Breadcrumbs:CreateToggle({
		Name = 'Self',
		Function = function(callback)
			if callback then
				Breadcrumbs:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero then
						local pos = entitylib.character.RootPart.Position + Vector3.new(0, -3, 0)
						if (not Offsets[1]) or (pos - Offsets[1].CFrame.Position).Magnitude > Distance.Value then
							local dot = Instance.new('Part')
							dot.Anchored = true
							dot.CanCollide = false
							dot.Material = Enum.Material.ForceField
							dot.Transparency = Transparency.Value
							dot.Size = Vector3.new(1, 1, 1)
							dot.Position = pos
							dot.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							dot.Parent = Folder
							local b = Instance.new('SpecialMesh')
							b.MeshType = Enum.MeshType[(Filled.Enabled and 'Sphere' or 'FileMesh')]
							b.MeshId = (Filled.Enabled and '' or 'rbxassetid://7895803811')
							b.Scale = Vector3.new(0.65, 0.65, 0.65)
							b.Parent = dot
	
							table.insert(Offsets, 1, dot)
							if #Offsets > 200 then
								Offsets[#Offsets]:Destroy()
								table.remove(Offsets, #Offsets)
							end
						end
					end
				end))
			end
		end
	})
end)

run(function()
	local Cape
	local Color
	local Transparency
	local obj
	
	Cape = vape:CreateHUD({
		Name = 'Cape',
		ViewportColor = function()
			return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	})
	Color = Cape:CreateColorSlider({
		Name = 'Color'
	})
	Transparency = Cape:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	
	Cape:CreateToggle({
		Name = 'Self',
		Function = function(callback)
			if callback then
				obj = Cape:AddCape(lplr)
				obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				obj.Transparency = Transparency.Value
			else
				if obj and obj.Parent then
					obj.Parent = nil
				end
			end
		end
	})
end)

run(function()
	local China
	local Color
	local Transparency
	local obj
	
	China = vape:CreateHUD({
		Name = 'China Hat',
		ViewportColor = function()
			return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	})
	Color = China:CreateColorSlider({
		Name = 'Color'
	})
	Transparency = China:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	
	China:CreateToggle({
		Name = 'Self',
		Function = function(callback)
			if callback then
				obj = China:AddChina(lplr)
				obj.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				obj.Transparency = Transparency.Value
			else
				if obj and obj.Parent then
					obj.Parent = nil
				end
			end
		end
	})
end)

run(function()
	local Clock
	local Color
	local Background
	local frame
	local label
	
	Clock = vape:CreateHUD({
		Name = 'Clock',
		Construct = function(object)
			frame = Instance.new('Frame')
			frame.Size = UDim2.fromOffset(110, 25)
			frame.Position = UDim2.fromOffset(0, 0)
			frame.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
			frame.Parent = object
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = frame
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromRGB(52, 52, 52)
			stroke.Thickness = 1
			stroke.Parent = frame
	
			label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = os.date('%I:%M %p')
			label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			label.TextSize = 15
			label.TextColor3 = Color3.fromHSV(0, 0, 1)
			label.Parent = frame
	
			Clock:Clean(runService.Heartbeat:Connect(function()
				if not Clock.Object.Visible then return end
				label.Text = os.date('%I:%M %p')
			end))
		end
	})
	Color = Clock:CreateColorSlider({Name = 'Color'})
	Background = Clock:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if frame then
				frame.BackgroundTransparency = callback and 0 or 1
			end
		end,
		Default = true
	})
end)

run(function()
	local Disguise
	local Player
	local Obj
	local Original
	local CornerPic
	
	Disguise = vape:CreateHUD({
		Name = 'Disguise',
		Construct = function(object)
			local img = Instance.new('ImageLabel')
			img.Size = UDim2.fromOffset(42, 42)
			img.ImageTransparency = 0.1
			img.ScaleType = Enum.ScaleType.Fit
			img.Parent = object
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = img
			CornerPic = img
		end
	})
	Player = Disguise:CreateTextBox({
		Name = 'Player',
		Function = function()
			if Obj and Obj.Parent then
				Obj.Parent = nil
			end
	
			local player = playersService:FindFirstChild(Player.Value)
			if player then
				Obj = Disguise:AddHat(LP, player)
				if CornerPic then
					local thumb = playersService:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					CornerPic.Image = thumb
				end
			else
				if CornerPic then
					CornerPic.Image = ''
				end
			end
		end
	})
end)

run(function()
	local FOV
	local Value
	local fov
	
	FOV = vape:CreateHUD({
		Name = 'FOV',
		Construct = function(object)
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = 'FOV: '..(math.floor(gameCamera.FieldOfView))
			label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			label.TextSize = 18
			label.TextColor3 = Color3.fromHSV(0, 0, 1)
			label.Parent = object
	
			FOV:Clean(runService.RenderStepped:Connect(function()
				if gameCamera then
					label.Text = 'FOV: '..(math.floor(gameCamera.FieldOfView))
				end
			end))
		end
	})
	Value = FOV:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 120,
		Default = 80,
		Function = function(val)
			fov = val
			gameCamera.FieldOfView = val
		end
	})
end)

run(function()
	local FPS
	local Average
	local Current
	
	FPS = vape:CreateHUD({
		Name = 'FPS',
		Construct = function(object)
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = 'FPS: 0'
			label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			label.TextSize = 16
			label.TextColor3 = Color3.fromHSV(0, 0, 1)
			label.Parent = object
	
			FPS:Clean(runService.RenderStepped:Connect(function(dt)
				if not FPS.Object.Visible then return end
				local fps = math.round(1 / dt)
				label.Text = 'FPS: '..fps
			end))
		end
	})
	Average = FPS:CreateToggle({
		Name = 'Average'
	})
	Current = FPS:CreateToggle({
		Name = 'Current',
		Default = true
	})
end)

run(function()
	local Keys
	local Mode
	local Board
	local Timing
	local Progress
	local ShowMouse
	local MouseCircle
	
	Keys = vape:CreateHUD({
		Name = 'Keystrokes',
		Construct = function(object)
			local function key(name, text)
				local container = Instance.new('Frame')
				container.Size = UDim2.fromOffset(36, 36)
				container.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
				container.Parent = object
				local corner = Instance.new('UICorner')
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = container
				local stroke = Instance.new('UIStroke')
				stroke.Color = Color3.fromRGB(52, 52, 52)
				stroke.Thickness = 1
				stroke.Parent = container
	
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = text
				label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
				label.TextSize = 20
				label.TextColor3 = Color3.fromHSV(0, 0, 1)
				label.Parent = container
	
				return container, label
			end
	
			local w, wl = key('W', 'W')
			local a, al = key('A', 'A')
			local s, sl = key('S', 'S')
			local d, dl = key('D', 'D')
			local sp, spl = key('Space', '⎵')
			local ml, mll = key('ml', 'L')
			local mr, mrl = key('mr', 'R')
			mr.Parent.LayoutOrder = 10
	
			local grid = Instance.new('UIGridLayout')
			grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
			grid.VerticalAlignment = Enum.VerticalAlignment.Bottom
			grid.CellPadding = UDim2.fromOffset(4, 4)
			grid.CellSize = UDim2.fromOffset(36, 36)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = object
	
			local cpos = Instance.new('Frame')
			cpos.Size = UDim2.fromOffset(100, 100)
			cpos.AnchorPoint = Vector2.new(0.5, 0.5)
			cpos.Position = UDim2.fromScale(0.5, 0.5)
			cpos.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
			cpos.Parent = object
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = cpos
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromRGB(52, 52, 52)
			stroke.Thickness = 1
			stroke.Parent = cpos
			local circ = Instance.new('Frame')
			circ.Size = UDim2.fromOffset(10, 10)
			circ.AnchorPoint = Vector2.new(0.5, 0.5)
			circ.Position = UDim2.fromScale(0.5, 0.5)
			circ.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			circ.Parent = cpos
			local cs = Instance.new('UICorner')
			cs.CornerRadius = UDim.new(1, 0)
			cs.Parent = circ
			MouseCircle = circ
	
			Keys:Clean(inputService.InputBegan:Connect(function(input)
				if not Keys.Object.Visible then return end
				if input.KeyCode == Enum.KeyCode.W then wl.TextColor3 = Color3.fromRGB(200, 200, 200) end
				if input.KeyCode == Enum.KeyCode.A then al.TextColor3 = Color3.fromRGB(200, 200, 200) end
				if input.KeyCode == Enum.KeyCode.S then sl.TextColor3 = Color3.fromRGB(200, 200, 200) end
				if input.KeyCode == Enum.KeyCode.D then dl.TextColor3 = Color3.fromRGB(200, 200, 200) end
				if input.KeyCode == Enum.KeyCode.Space then spl.TextColor3 = Color3.fromRGB(200, 200, 200) end
			end))
	
			Keys:Clean(inputService.InputEnded:Connect(function(input)
				if not Keys.Object.Visible then return end
				if input.KeyCode == Enum.KeyCode.W then wl.TextColor3 = Color3.fromHSV(0, 0, 1) end
				if input.KeyCode == Enum.KeyCode.A then al.TextColor3 = Color3.fromHSV(0, 0, 1) end
				if input.KeyCode == Enum.KeyCode.S then sl.TextColor3 = Color3.fromHSV(0, 0, 1) end
				if input.KeyCode == Enum.KeyCode.D then dl.TextColor3 = Color3.fromHSV(0, 0, 1) end
				if input.KeyCode == Enum.KeyCode.Space then spl.TextColor3 = Color3.fromHSV(0, 0, 1) end
			end))
	
			Keys:Clean(inputService.InputChanged:Connect(function(input)
				if not Keys.Object.Visible then return end
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					local delta = input.Delta
					local newPos = MouseCircle.Position + UDim2.fromOffset(delta.X, delta.Y)
					newPos = UDim2.fromOffset(
						math.clamp(newPos.X.Offset, 5, 95),
						math.clamp(newPos.Y.Offset, 5, 95)
					)
					MouseCircle.Position = newPos
				end
			end))
		end
	})
	Mode = Keys:CreateDropdown({
		Name = 'Mode',
		List = {'Board', 'Compact'},
		Function = function() end
	})
	Board = Keys:CreateToggle({
		Name = 'Board',
		Default = true
	})
	Timing = Keys:CreateToggle({
		Name = 'Timing'
	})
	Progress = Keys:CreateToggle({
		Name = 'Progress'
	})
	ShowMouse = Keys:CreateToggle({
		Name = 'Mouse Pos',
		Default = true
	})
end)

run(function()
	local Memory
	local memory
	Memory = vape:CreateHUD({
		Name = 'Memory',
		Construct = function(object)
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = 'Memory: 0 MB'
			label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			label.TextSize = 16
			label.TextColor3 = Color3.fromHSV(0, 0, 1)
			label.Parent = object
	
			Memory:Clean(runService.Heartbeat:Connect(function()
				if not Memory.Object.Visible then return end
				local stat = game:GetService('Stats'):FindFirstChild('PerformanceStats')
				if stat then
					local mem = stat:GetAttribute('MemoryUsageMb') or 0
					label.Text = 'Memory: '..math.floor(mem)..' MB'
				end
			end))
		end
	})
end)

run(function()
	local Ping
	Ping = vape:CreateHUD({
		Name = 'Ping',
		Construct = function(object)
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = 'Ping: 0ms'
			label.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			label.TextSize = 16
			label.TextColor3 = Color3.fromHSV(0, 0, 1)
			label.Parent = object
	
			Ping:Clean(runService.Heartbeat:Connect(function()
				if not Ping.Object.Visible then return end
				local ping = game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue()
				label.Text = 'Ping: '..math.round(ping)..'ms'
			end))
		end
	})
end)

run(function()
	local SongBeats
	local Tap
	local obj
	
	SongBeats = vape:CreateHUD({
		Name = 'Song Beats',
		Construct = function(object)
			obj = Instance.new('Frame')
			obj.Size = UDim2.fromOffset(160, 14)
			obj.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
			obj.Parent = object
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = obj
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromRGB(52, 52, 52)
			stroke.Thickness = 1
			stroke.Parent = obj
	
			local inner = Instance.new('Frame')
			inner.Size = UDim2.fromScale(0, 1)
			inner.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			inner.Parent = obj
			local ic = Instance.new('UICorner')
			ic.CornerRadius = UDim.new(0, 6)
			ic.Parent = inner
	
			local val = 0
			SongBeats:Clean(runService.Heartbeat:Connect(function()
				if not obj.Visible then return end
				val = (val + 0.02) % 1
				inner.Size = UDim2.fromScale(val, 1)
			end))
		end
	})
	Tap = SongBeats:CreateToggle({
		Name = 'Tap'
	})
end)

run(function()
	local Speedmeter
	local obj
	
	Speedmeter = vape:CreateHUD({
		Name = 'Speedmeter',
		Construct = function(object)
			obj = Instance.new('TextLabel')
			obj.Size = UDim2.fromScale(1, 1)
			obj.BackgroundTransparency = 1
			obj.Text = 'Speed: 0'
			obj.FontFace = Font.new('rbxasset://fonts/families/RobotoMono.json')
			obj.TextSize = 16
			obj.TextColor3 = Color3.fromHSV(0, 0, 1)
			obj.Parent = object
	
			Speedmeter:Clean(runService.Heartbeat:Connect(function()
				if not Speedmeter.Object.Visible then return end
				if entitylib.isAlive then
					local vel = entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					obj.Text = 'Speed: '..tostring(math.round(vel.Magnitude))
				end
			end))
		end
	})
end)

run(function()
	local TimeChanger
	local Time
	TimeChanger = vape:CreateHUD({
		Name = 'Time Changer',
		Construct = function(object) end
	})
	Time = TimeChanger:CreateSlider({
		Name = 'Time',
		Min = 0,
		Max = 24,
		Default = 14,
		Function = function(val)
			lightingService.ClockTime = val
		end
	})
end)











local function getPartPos(part, hitbox)
	local cf = part.CFrame
	if hitbox == 'Center' then
		return cf.Position
	elseif hitbox == 'Up' then
		return (cf + Vector3.new(0, part.Size.Y / 2, 0)).Position
	elseif hitbox == 'Down' then
		return (cf - Vector3.new(0, part.Size.Y / 2, 0)).Position
	elseif hitbox == 'Right' then
		return (cf + (cf.RightVector * part.Size.X / 2)).Position
	elseif hitbox == 'Left' then
		return (cf - (cf.RightVector * part.Size.X / 2)).Position
	elseif hitbox == 'Forward' then
		return (cf + (cf.LookVector * part.Size.Z / 2)).Position
	elseif hitbox == 'Backward' then
		return (cf - (cf.LookVector * part.Size.Z / 2)).Position
	else
		return cf.Position
	end
end

local function getPos(data, part, hitbox)
	local pos2 = getPartPos(part, hitbox) - (3 < 0 and part.AssemblyLinearVelocity * 3 or Vector3.zero)
	local getpos = (pos2 + (data.Offset and data.Offset.Value or Vector3.zero))
	return getpos
end

local onLaunch
	local vz = vape.Categories.Exploits:CreateModule({
		Name = 'Speed',
			 Function = function(callback)
			if callback then
			local Speed =vz
				if not Spider.Enabled then
				end
				vz:CleanSpeedMethod = Speed:CreateDropdown({
				Name = 'Method',
				List = SpeedMethodList,
				Function = function()
					if Speed.Enabled then
						Speed:Toggle()
						Speed:Toggle()
					end
				end
			})
			vz:CleanValue = Speed:CreateSlider({
				Name = 'Value',
				Min = 1,
				Max = 30,
				Default = 22
			})
	vz:CleanAcceleration = Speed:CreateSlider({
		Name = 'Acceleration',
		Min = 1,
		Max = 4,
		Default = 2
	})
	vz:CleanBoost = Speed:CreateSlider({
		Name = 'Boost',
		Min = 1,
		Max = 4,
		Default = 2,
		Visible = false,
		Darker = true
	}) function ondeed()
         return os.clock()
          end 
          
			
	vz:CleanWallCheck = Speed:CreateToggle({Name = 'Wall Check'}) end 
		end,
		Tooltip = 'Speed by inj'
	})


local function partNormalize(pos, normal)
	local dot = ((pos - Vector3.zero).Unit:Dot(normal))
	return (pos - (normal * dot))
end

run(function()
	local Blink
	local Delay
	local Delaytime
	local PacketAmount
	local Bypass
	local Folder = Instance.new('Folder')
	Folder.Name = 'packets'
	Folder.Parent = game
	local Packets, oldpacket, newCFrame = {}, 0, 0

	local function send()
		local pos = entitylib.character.RootPart.CFrame
		local mm = #Packets > 0 and (Delay.Enabled and (Pack.Size >= DelayTime.Value) or true) or false
		if mm then
			for i, v in Packets do
				task.spawn(function()
					entitylib.character.RootPart.CFrame = v[1]
					task.wait()
					entitylib.character.RootPart.CFrame = pos
				end)
				table.remove(Packets, i)
			end
		end
	end

	Blink = vape.Categories.Exploits:CreateModule({
		Name = 'Blink',
		Function = function(callback)
			if callback then
				local conPacket
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					conPacket = root:GetPropertyChangedSignal('CFrame'):Connect(function()
						newCFrame = os.clock()
					end)
				end

				local Pack = Instance.new('Part')
				Pack.Transparency = 1
				Pack.CanCollide = false
				Pack.Anchored = true
				Pack.Parent = Folder
				Pack.Size = Vector3.zero
				Packets[Pack] = {}

				Blink:Clean(function()
					if conPacket then
						conPacket:Disconnect()
					end
				end)
				Blink:Clean(runService.Heartbeat:Connect(function(x)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if oldpacket ~= newCFrame then
							table.insert(Packets[Pack], {root.CFrame, os.clock()})
							oldpacket = newCFrame
							Pack.Position = root.Position
							Pack.Size += Vector3.new(0.04, 0.04, 0.04)
						end
					end

					if Delay.Enabled and (Pack.Size >= Delaytime.Value) then
						send()
					end
				end))
			else
				send()
				Packets = {}
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Queues movements for later'
	})
	Delay = Blink:CreateToggle({
		Name = 'Delay',
		Function = function(callback)
			Delaytime.Object.Visible = callback
		end
	})
	Delaytime = Blink:CreateSlider({
		Name = 'Delay Time',
		Min = 0,
		Max = 10,
		Default = 1,
		Darker = true,
		Visible = false
	})
	PacketAmount = Blink:CreateSlider({
		Name = 'Packet Amount',
		Min = 1,
		Max = 50,
		Default = 10
	})
	Bypass = Blink:CreateToggle({
		Name = 'Flag Bypass'
	})
end)

run(function()
	local ZanzenaFly
	local Speed
	local mode
	local method
	local Visualize
	local Height
	local tiltSpeed
	local Smoothness
	local ModeList = {'Force','BodyVelocity'}

	local folder = Instance.new('Folder', workspace)
	local p, p2, p3, p4
	local oldfly
	local force, bodyv

	local function PartP(size, c, name)
		local part = Instance.new('Part')
		part.Size = size
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = (Visualize.Enabled and 0) or 1
		part.Position = entitylib.character.RootPart.Position + Vector3.new(0, -3, 0)
		part.Parent = folder
		part.Color = c
		part.Name = name
		return part
	end

	ZanzenaFly = vape.Categories.Exploits:CreateModule({
		Name = 'ZanzenaFly',
		Function = function(callback)
			if callback then
				local originalGravity = 150
				local appliedForce = 15
				local acc = 0
				local humanoid = entitylib.character.Humanoid
				local JumpCon
				local vel = 0
				p = PartP(Vector3.new(16, 1, 16), Color3.fromRGB(255, 58, 58), 'Base')
				p2 = PartP(Vector3.new(256, 1, 256), Color3.fromRGB(195, 0, 255), 'Huge')
				p4 = PartP(Vector3.new(0.5 ,0.5 ,0.5), Color3.fromRGB(32, 0, 225), 'Beam')

				runService.Stepped:Connect(function()
					if entitylib.isAlive then
						if method.Value == 'BodyVelocity' then
							local moveVector = entitylib.character.Humanoid.MoveDirection
							local moveConstant = 1
							local move = moveVector * (moveConstant * vel)
							entitylib.character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(move.X, entitylib.character.HumanoidRootPart.AssemblyLinearVelocity.Y, move.Z)
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							vel = math.clamp(vel + 0.05, 0 , Speed.Value)

							local pos = entitylib.character.RootPart.Position - Vector3.new(0, entitylib.character.RootPart.Position.Y - p.Position.Y, 0)
							local xz = (pos - entitylib.character.RootPart.Position) * Vector3.new(5/5, 0, 5/5)
							local v = Vector3.new(entitylib.character.HumanoidRootPart.AssemblyLinearVelocity.X /5 , 0, entitylib.character.HumanoidRootPart.AssemblyLinearVelocity.Z /5 )
							p.Position = (entitylib.character.RootPart.Position + Vector3.new(0, -3, 0)) + xz
							p2.Position = entitylib.character.RootPart.Position + Vector3.new(0, -128, 0)
							p4.Size = Vector3.new(0.9 ,(entitylib.character.RootPart.Position - p.Position).Magnitude, 0.9) * Vector3.new(1, 0.9, 1)
							p4.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, p.Position) * CFrame.Angles(math.rad(90),0,0)
						else
							entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
							if entitylib.character.RootPart.FloorMaterial == Enum.Material.Air then
								if entitylib.character.RootPart.Velocity.Y > 0 then
									force.Force = Vector3.new(0,0,0)
								else
									appliedForce = 15 + (Height.Value / 25)
									local forceGiven = ((lightingService.ClockTime > 10 and math.sin(acc) or -math.sin(acc)) * (tiltSpeed.Value / 10)) + appliedForce
									force.Force = Vector3.new(0,(originalGravity * math.max(forceGiven, 0)),0)
									acc = (acc + ((tick() - onLaunch) * (tiltSpeed.Value / (20 / Smoothness.Value))))
								end
							else
								force.Force = Vector3.new(0, 0, 0)
							end

							local moveVector = entitylib.character.Humanoid.MoveDirection
							local moveConstant = 5

							local move = moveVector * (moveConstant * Speed.Value)
							bodyv.Velocity = Vector3.new(move.X, entitylib.character.RootPart.Velocity.Y, move.Z)
							bodyv.MaxForce = Vector3.new(100000, 0, 100000)
						end
					end
				end)

				vape:Clean(function()
					if force then force:Destroy() end
					if bodyv then bodyv:Destroy() end
					if p then p:Destroy() end
					if p2 then p2:Destroy() end
					if p4 then p4:Destroy() end
					if p3 then p3:Destroy() end
				end)

				ZanzenaFly:Clean(function()
					if JumpCon then
						JumpCon:Disconnect()
					end
				end)

				ZanzenaFly:Clean(function()
					if runService.Stepped then
						runService.Stepped:Wait()
					end
				end)

				vape:Clean(function()
					if entitylib.character and entitylib.character.Humanoid then
						entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
					end
				end)

				force = Instance.new('VectorForce')
				force.Attachment0 = entitylib.character.HumanoidRootPart:FindFirstChildOfClass('Attachment') or Instance.new('Attachment', entitylib.character.HumanoidRootPart)
				force.Force = Vector3.new(0, 0, 0)
				force.ApplyAtCenterOfMass = true
				force.Parent = entitylib.character.HumanoidRootPart

				bodyv = Instance.new('BodyVelocity')
				bodyv.Parent = entitylib.character.RootPart
				bodyv.MaxForce = Vector3.new(0, 0, 0)

				onLaunch = tick()
			else
				if force then force:Destroy() end
				if bodyv then bodyv:Destroy() end
				if p then p:Destroy() end
				if p2 then p2:Destroy() end
				if p4 then p4:Destroy() end
				if p3 then p3:Destroy() end
			end
		end,
		Tooltip = 'Fly using body movers or forces'
	})

	method = ZanzenaFly:CreateDropdown({
		Name = 'Method',
		List = ModeList
	})

	Speed = ZanzenaFly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 50,
		Default = 20
	})

	Height = ZanzenaFly:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 500,
		Default = 180
	})

	tiltSpeed = ZanzenaFly:CreateSlider({
		Name = 'Tilt Speed',
		Min = 1,
		Max = 10,
		Default = 5
	})

	Smoothness = ZanzenaFly:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 10,
		Default = 5
	})

	Visualize = ZanzenaFly:CreateToggle({
		Name = 'Visualize'
	})
end)

run(function()
	local Nodef
	local Freeze
	local thing = Instance.new('Folder')
	thing.Parent= workspace
	local con


	Nodef = vape.Categories.Exploits:CreateModule({
		Name = 'NoDefeat',
		Function = function(callback)
			if callback then
				if entitylib.isAlive then
					con = entitylib.character.Humanoid:GetPropertyChangedSignal('Health'):Connect(function()
						entitylib.character.Humanoid.WalkSpeed = 16
						entitylib.character.Humanoid.AutoRotate = true
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
					end)
				end
			else
				if con then
					con:Disconnect()
				end
			end
		end,
		Tooltip = 'Anti defeat states'
	})

	Freeze = Nodef:CreateToggle({
		Name = 'Freeze'
	})
end)

run(function()
	local NoSlow
	local wobble
	local cameraFreeze

	local function giveEffect(callback)
		if entitylib.isAlive then
			local hum = entitylib.character.Humanoid
				hum.WalkSpeed = 10
			hum.HipHeight = 2
			if wobble.Enabled then
				gameCamera.CFrame *= CFrame.new(math.sin(tick() * 2) * 0.1, math.cos(tick() * 2) * 0.1, 0)
			end
			if cameraFreeze.Enabled then
				gameCamera.CFrame *= CFrame.new(0, 0, 0)
			end
		end
	end

	NoSlow = vape.Categories.Exploits:CreateModule({
		Name = 'NoSlow',
		Function = function(callback)
			if callback then
				repeat
					giveEffect(callback)
					task.wait()
				until not NoSlow.Enabled
			end
		end,
		Tooltip = 'Prevents slow effects'
	})

	wobble = NoSlow:CreateToggle({
		Name = 'Wobble'
	})
	cameraFreeze = NoSlow:CreateToggle({
		Name = 'Freeze Camera'
	})
end)

run(function()
	local NoFall
	local AntiVoid
	local voidPart
	local mv = RaycastParams.new()
	mv.RespectCanCollide = true
	mv.FilterType = Enum.RaycastFilterType.Exclude
	local lastY = 0

	NoFall = vape.Categories.Exploits:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Velocity.Y < lastY then
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), mv)
							if ray and ray.Instance and ray.Position then
								if (root.Position.Y - ray.Position.Y) > 50 then
									root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 5, 0))
								end
							else
								if AntiVoid.Enabled then
									root.CFrame = root.CFrame + Vector3.new(0, 5, 0)
								end
							end
						end
						lastY = root.Velocity.Y
					end
					task.wait()
				until not NoFall.Enabled
			end
		end,
		Tooltip = 'Prevents fall damage or void'
	})
	AntiVoid = NoFall:CreateToggle({
		Name = 'AntiVoid'
	})
end)

run(function()
	local PhaseModule
	local Mode
	local Phasing
	local blk = Instance.new('Part')
	blk.Anchored = true
	blk.CanCollide = false
	blk.Transparency = 1
	blk.Size = Vector3.new(2, 1, 2)
	blk.Parent = workspace

	PhaseModule = vape.Categories.Exploits:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if Mode.Value == 'TP' then
							local newpos = root.CFrame + (root.CFrame.LookVector * 3)
							blk.CFrame = newpos
							root.CFrame = blk.CFrame
						else
							root.CanCollide = false
						end
					end
					task.wait()
				until not PhaseModule.Enabled

				if entitylib.isAlive then
					entitylib.character.RootPart.CanCollide = true
				end
			else
				if entitylib.isAlive then
					entitylib.character.RootPart.CanCollide = true
				end
			end
		end,
		Tooltip = 'Clip through walls'
	})

	Mode = PhaseModule:CreateDropdown({
		Name = 'Mode',
		List = {'Collision', 'TP'}
	})
end)

run(function()
	local SpiderWalk
	local Speed
	local Angle
	local Stick

	SpiderWalk = vape.Categories.Exploits:CreateModule({
		Name = 'Spider',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local moveVec = entitylib.character.Humanoid.MoveDirection
						local dir = CFrame.lookAt(root.Position, root.Position + moveVec)
						local up = Angle.Value
						if Stick.Enabled then
							root.CFrame = dir * CFrame.Angles(math.rad(up), 0, 0)
						else
							root.CFrame = dir
						end
						root.AssemblyLinearVelocity = root.CFrame.LookVector * Speed.Value
					end
					task.wait()
				until not SpiderWalk.Enabled
			end
		end,
		Tooltip = 'Walk on walls'
	})
	Speed = SpiderWalk:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 50,
		Default = 20
	})
	Angle = SpiderWalk:CreateSlider({
		Name = 'Angle',
		Min = 0,
		Max = 90,
		Default = 45
	})
	Stick = SpiderWalk:CreateToggle({
		Name = 'Stick'
	})
end)

run(function()
	local Velocity
	local Power
	local Randomize
	local axisX
	local axisY
	local axisZ

	Velocity = vape.Categories.Exploits:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local x = axisX.Value
						local y = axisY.Value
						local z = axisZ.Value
						local rand = Randomize.Enabled and Random.new():NextNumber(-Power.Value, Power.Value) or Power.Value
						root.AssemblyLinearVelocity += Vector3.new(x * rand, y * rand, z * rand)
					end
					task.wait()
				until not Velocity.Enabled
			end
		end,
		Tooltip = 'Adds random velocity to the character'
	})
	Power = Velocity:CreateSlider({
		Name = 'Power',
		Min = 0,
		Max = 50,
		Default = 10
	})
	Randomize = Velocity:CreateToggle({
		Name = 'Randomize'
	})
	axisX = Velocity:CreateSlider({
		Name = 'X',
		Min = -1,
		Max = 1,
		Default = 1,
		Decimal = 10
	})
	axisY = Velocity:CreateSlider({
		Name = 'Y',
		Min = -1,
		Max = 1,
		Default = 0,
		Decimal = 10
	})
	axisZ = Velocity:CreateSlider({
		Name = 'Z',
		Min = -1,
		Max = 1,
		Default = 1,
		Decimal = 10
	})
end)

run(function()
	local Xray
	local Transparency
	local materials = {}

	Xray = vape.Categories.Exploits:CreateModule({
		Name = 'Xray',
		Function = function(callback)
			if callback then
				for _, obj in workspace:GetDescendants() do
					if obj:IsA('BasePart') and obj.Transparency < 1 then
						materials[obj] = obj.Transparency
						obj.Transparency = Transparency.Value
					end
				end
			else
				for obj, t in materials do
					if obj and obj.Parent then
						obj.Transparency = t
					end
				end
				table.clear(materials)
			end
		end,
		Tooltip = 'See through objects'
	})

	Transparency = Xray:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimal = 10
	})
end)

run(function()
	local Zoom
	local Value
	local Original = gameCamera and gameCamera.FieldOfView or 70

	Zoom = vape.Categories.Exploits:CreateModule({
		Name = 'Zoom',
		Function = function(callback)
			if callback then
				repeat
					if gameCamera then
						gameCamera.FieldOfView = math.clamp(Value.Value, 1, 120)
					end
					task.wait()
				until not Zoom.Enabled
				if gameCamera then
					gameCamera.FieldOfView = Original
				end
			else
				if gameCamera then
					gameCamera.FieldOfView = Original
				end
			end
		end,
		Tooltip = 'Adjust camera FOV'
	})

	Value = Zoom:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 120,
		Default = 60
	})
end)

run(function()
	local ZoomKey
	local Keybind
	local Amount
	local Original = gameCamera and gameCamera.FieldOfView or 70
	local down = false

	ZoomKey = vape.Categories.Exploits:CreateModule({
		Name = 'ZoomKey',
		Function = function(callback)
			if callback then
				ZoomKey:Clean(inputService.InputBegan:Connect(function(input,gp)
					if gp then return end
					if input.KeyCode.Name == Keybind.Value then
						down = true
						if gameCamera then
							gameCamera.FieldOfView = math.clamp(Amount.Value, 1, 120)
						end
					end
				end))
				ZoomKey:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode.Name == Keybind.Value then
						down = false
						if gameCamera then
							gameCamera.FieldOfView = Original
						end
					end
				end))
			else
				if gameCamera then
					gameCamera.FieldOfView = Original
				end
				down = false
			end
		end,
		Tooltip = 'Hold key to zoom'
	})

	Keybind = ZoomKey:CreateTextBox({
		Name = 'Key',
		Default = 'LeftShift'
	})
	Amount = ZoomKey:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 120,
		Default = 40
	})
end)

run(function()
	local ZoomScroll
	local Step
	local Min
	local Max
	local Original = gameCamera and gameCamera.FieldOfView or 70

	ZoomScroll = vape.Categories.Exploits:CreateModule({
		Name = 'ZoomScroll',
		Function = function(callback)
			if callback then
				ZoomScroll:Clean(inputService.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseWheel then
						if gameCamera then
							local new = math.clamp((gameCamera.FieldOfView - (input.Position.Z * Step.Value)), Min.Value, Max.Value)
							gameCamera.FieldOfView = new
						end
					end
				end))
			else
				if gameCamera then
					gameCamera.FieldOfView = Original
				end
			end
		end,
		Tooltip = 'Zoom with mouse wheel'
	})
	Step = ZoomScroll:CreateSlider({
		Name = 'Step',
		Min = 0.1,
		Max = 20,
		Default = 1,
		Decimal = 10
	})
	Min = ZoomScroll:CreateSlider({
		Name = 'Min',
		Min = 1,
		Max = 120,
		Default = 30
	})
	Max = ZoomScroll:CreateSlider({
		Name = 'Max',
		Min = 1,
		Max = 120,
		Default = 90
	})
end)

run(function()
	local ZoomADS
	local Key
	local ADSValue
	local NormalValue
	local down = false

	ZoomADS = vape.Categories.Exploits:CreateModule({
		Name = 'ZoomADS',
		Function = function(callback)
			if callback then
				ZoomADS:Clean(inputService.InputBegan:Connect(function(input,gp)
					if gp then return end
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						down = true
						if gameCamera then
							gameCamera.FieldOfView = ADSValue.Value
						end
					end
				end))
				ZoomADS:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						down = false
						if gameCamera then
							gameCamera.FieldOfView = NormalValue.Value
						end
					end
				end))
			else
				if gameCamera then
					gameCamera.FieldOfView = NormalValue.Value
				end
				down = false
			end
		end,
		Tooltip = 'Zoom when aiming'
	})

	ADSValue = ZoomADS:CreateSlider({
		Name = 'ADS FOV',
		Min = 1,
		Max = 120,
		Default = 40
	})
	NormalValue = ZoomADS:CreateSlider({
		Name = 'Normal FOV',
		Min = 1,
		Max = 120,
		Default = 80
	})
end)

-- End of cleaned script
