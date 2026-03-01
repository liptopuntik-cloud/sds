--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local maxAmmoCache = {}

local currentAmmoCache = {}

local fireModeCache = {}

local connections = {}

local soundConnections = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AmmoDisplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 200, 0, 50)
mainFrame.Position = UDim2.new(0, 10, 1, -60)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local titleBar = Instance.new("TextLabel")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 25)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundTransparency = 0.5
titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
titleBar.BorderSizePixel = 0
titleBar.Text = "Ammo Display"
titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
titleBar.Font = Enum.Font.SourceSansBold
titleBar.TextSize = 14
titleBar.Parent = mainFrame

local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(1, -10, 1, -30)
container.Position = UDim2.new(0, 5, 0, 27)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local function getFireModes(tool)
	local conf = tool:FindFirstChild("conf")
	if not conf or not conf:IsA("ModuleScript") then
		return nil
	end
	
	local success, config = pcall(function()
		return require(conf)
	end)
	
	if not success or not config then
		return nil
	end

	local startMode = config.general and config.general.mode
	local switchableModes = config.general and config.general.switchableModes

	if switchableModes then
		local validModes = {}
		for _, mode in ipairs(switchableModes) do
			if mode ~= nil then
				table.insert(validModes, mode)
			end
		end
		
		if #validModes > 0 then
			switchableModes = validModes
		else
			switchableModes = nil
		end
	end

	if not switchableModes and startMode then
		switchableModes = {startMode}
	end
	
	if not switchableModes or #switchableModes == 0 then
		return nil
	end
	
	return {
		modes = switchableModes,
		startMode = startMode or switchableModes[1],
		canSwitch = #switchableModes > 1
	}
end

local function getCurrentFireMode(tool)
	if fireModeCache[tool.Name] then
		return fireModeCache[tool.Name]
	end

	local fireModes = getFireModes(tool)
	if fireModes then
		fireModeCache[tool.Name] = fireModes.startMode
		return fireModes.startMode
	end
	
	return nil
end

local function cycleFireMode(tool)
	print("[DEBUG] cycleFireMode called for " .. tool.Name)
	local fireModes = getFireModes(tool)
	
	if not fireModes then
		print("[DEBUG] No fire modes found")
		return
	end
	
	print("[DEBUG] Fire modes available: " .. table.concat(fireModes.modes, ", "))
	print("[DEBUG] Can switch: " .. tostring(fireModes.canSwitch))
	
	if not fireModes.canSwitch then
		print("[DEBUG] Gun cannot switch modes")
		return
	end
	
	local currentMode = fireModeCache[tool.Name] or fireModes.startMode
	print("[DEBUG] Current mode: " .. tostring(currentMode))

	local currentIndex = 1
	for i, mode in ipairs(fireModes.modes) do
		if mode == currentMode then
			currentIndex = i
			break
		end
	end

	local nextIndex = (currentIndex % #fireModes.modes) + 1
	fireModeCache[tool.Name] = fireModes.modes[nextIndex]
	print("[DEBUG] Switched to mode: " .. fireModes.modes[nextIndex])
end

local function monitorFireMode(tool)
	if soundConnections[tool] then
		for _, conn in pairs(soundConnections[tool]) do
			if typeof(conn) == "RBXScriptConnection" then
				conn:Disconnect()
			end
		end
		soundConnections[tool] = nil
	end
	
	soundConnections[tool] = {}

	local union = tool:FindFirstChild("Union")
	if not union then
		return
	end

	local function isEquipped()
		local parent = tool.Parent
		if not parent then
			return false
		end

		if parent == workspace:FindFirstChild(player.Name) then
			return true
		end
		
		local npcsFolder = workspace:FindFirstChild("NPCSFolder")
		if npcsFolder and parent == npcsFolder:FindFirstChild(player.Name) then
			return true
		end
		
		return false
	end
	
	local function connectToCycleMode(sound)
		if sound.Name == "cycleMode" and sound:IsA("Sound") then
			print("[DEBUG] Connecting to cycleMode sound for " .. tool.Name)
			
			local conn = sound.Played:Connect(function()
				print("[DEBUG] cycleMode sound played for " .. tool.Name)
				if isEquipped() then
					print("[DEBUG] Tool is equipped, cycling fire mode")
					cycleFireMode(tool)
					updateGUI()
				else
					print("[DEBUG] Tool is NOT equipped, ignoring")
				end
			end)
			table.insert(soundConnections[tool], conn)

			if sound.IsPlaying then
				print("[DEBUG] Sound is already playing, cycling immediately")
				if isEquipped() then
					cycleFireMode(tool)
					updateGUI()
				end
			end
		end
	end

	for _, child in ipairs(union:GetChildren()) do
		connectToCycleMode(child)
	end

	local childAddedConn = union.ChildAdded:Connect(function(child)
		wait(0.01)
		connectToCycleMode(child)
	end)
	table.insert(soundConnections[tool], childAddedConn)
end
local function countChamberBullets(tool)
	local count = 0
	local attributes = tool:GetAttributes()
	
	for attrName, attrValue in pairs(attributes) do
		if string.sub(attrName, 1, 9) == "__chamber" and attrName ~= "__chambear" then
			if attrValue == true then
				count = count + 1
			end
		end
	end
	
	return count
end

local function getCurrentAmmo(tool)
	local attributes = tool:GetAttributes()

	if attributes.mag then
		return attributes.mag
	end

	local chamberCount = countChamberBullets(tool)

	if chamberCount > 0 then
		return chamberCount
	end

	if chamberCount == 0 and maxAmmoCache[tool.Name] then
		local hasChamberAttrs = false
		for attrName, _ in pairs(attributes) do
			if string.sub(attrName, 1, 9) == "__chamber" and attrName ~= "__chambear" then
				hasChamberAttrs = true
				break
			end
		end

		if not hasChamberAttrs then
			return maxAmmoCache[tool.Name]
		end
	end
	
	return chamberCount
end

local function getMaxAmmo(tool)
	if maxAmmoCache[tool.Name] then
		return maxAmmoCache[tool.Name]
	end
	
	local attributes = tool:GetAttributes()

	if attributes.mag then
		maxAmmoCache[tool.Name] = attributes.mag
		return attributes.mag
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == "ammoModil" and descendant:IsA("Model") then
			wait(0.1)
			
			local numberedParts = 0
			for _, part in ipairs(descendant:GetChildren()) do
				local num = tonumber(part.Name)
				if num then
					numberedParts = numberedParts + 1
				end
			end
			
			if numberedParts > 0 then
				maxAmmoCache[tool.Name] = numberedParts
				return numberedParts
			end
		end
	end
	
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == "ammoModel" and descendant:IsA("Model") then
			wait(0.1)
			
			local numberedParts = 0
			for _, part in ipairs(descendant:GetChildren()) do
				local num = tonumber(part.Name)
				if num then
					numberedParts = numberedParts + 1
				end
			end
			
			if numberedParts > 0 then
				maxAmmoCache[tool.Name] = numberedParts
				return numberedParts
			end
		end
	end
	
	local maxChambers = 0
	for attrName, _ in pairs(attributes) do
		if string.sub(attrName, 1, 9) == "__chamber" and attrName ~= "__chambear" then
			maxChambers = maxChambers + 1
		end
	end

	if maxChambers > 0 then
		maxAmmoCache[tool.Name] = maxChambers
		return maxChambers
	end

	local currentCount = countChamberBullets(tool)
	if currentCount > 0 then
		maxAmmoCache[tool.Name] = currentCount
		return currentCount
	end

	maxAmmoCache[tool.Name] = 1
	return 1
end

local function findAllWeapons()
	local weapons = {}
	local weaponNames = {}

	local function isWeapon(item)
		if not item:IsA("Tool") then
			return false
		end
		
		local attributes = item:GetAttributes()

		if attributes.mag then
			return true
		end

		for _, descendant in ipairs(item:GetDescendants()) do
			if descendant.Name == "ammoModil" and descendant:IsA("Model") then
				for _, child in ipairs(descendant:GetChildren()) do
					if tonumber(child.Name) then
						return true
					end
				end
			end
		end

		for attrName, _ in pairs(attributes) do
			if string.sub(attrName, 1, 9) == "__chamber" then
				return true
			end
		end

		for _, descendant in ipairs(item:GetDescendants()) do
			if descendant.Name == "ammoModel" and descendant:IsA("Model") then
				for _, child in ipairs(descendant:GetChildren()) do
					if tonumber(child.Name) then
						return true
					end
				end
			end
		end
		
		return false
	end

	local function addWeaponIfUnique(item)
		if isWeapon(item) and not weaponNames[item.Name] then
			table.insert(weapons, item)
			weaponNames[item.Name] = true
		end
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			addWeaponIfUnique(item)
		end
	end

	local npcsFolder = workspace:FindFirstChild("NPCSFolder")
	if npcsFolder then
		local npcPlayer = npcsFolder:FindFirstChild(player.Name)
		if npcPlayer then
			for _, item in ipairs(npcPlayer:GetChildren()) do
				addWeaponIfUnique(item)
			end
		end
	end

	if player:FindFirstChild("Backpack") then
		for _, item in ipairs(player.Backpack:GetChildren()) do
			addWeaponIfUnique(item)
		end
	end
	
	return weapons
end

local function updateGUI()
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	
	local weapons = findAllWeapons()

	local currentYPosition = 0
	
	for i, weapon in ipairs(weapons) do
		local maxAmmo = getMaxAmmo(weapon)
		local currentAmmo = getCurrentAmmo(weapon)

		if currentAmmo < 0 then
			currentAmmo = 0
		end
	
		currentAmmoCache[weapon.Name] = currentAmmo

		local attributes = weapon:GetAttributes()
		local chambered = attributes.chambered
		local chambear = attributes.__chambear
		local chamberPos = attributes.chamberPos
		local ammoColor = Color3.fromRGB(178, 251, 165) -- Default green

		if chambered ~= nil and chambered == false then
			ammoColor = Color3.fromRGB(255, 109, 97) -- Red
		end

		if chambear ~= nil and chambear == false then
			ammoColor = Color3.fromRGB(255, 109, 97) -- Red
		end

		if chamberPos ~= nil then
			local chamberName = "__chamber" .. tostring(chamberPos)
			local chamberValue = attributes[chamberName]

			if chamberValue == false or chamberValue == nil then
				ammoColor = Color3.fromRGB(255, 109, 97) -- Red
			end
		end

		local fireMode = getCurrentFireMode(weapon)
		local fireModeText = fireMode and (" [" .. string.upper(fireMode) .. "]") or ""

		local fullText = string.format("%d - %s\n%d/%d%s", i, weapon.Name, currentAmmo, maxAmmo, fireModeText)

		local tempLabel = Instance.new("TextLabel")
		tempLabel.Size = UDim2.new(1, -10, 1, 0)
		tempLabel.Font = Enum.Font.SourceSansBold
		tempLabel.TextSize = 16
		tempLabel.TextWrapped = true
		tempLabel.Text = fullText
		tempLabel.Parent = container

		local textBounds = tempLabel.TextBounds
		tempLabel:Destroy()

		local labelHeight = math.max(40, textBounds.Y + 10)
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, labelHeight)
		label.Position = UDim2.new(0, 0, 0, currentYPosition)
		label.BackgroundTransparency = 0.5
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.TextColor3 = ammoColor
		label.Font = Enum.Font.SourceSansBold
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Text = fullText
		label.Parent = container

		currentYPosition = currentYPosition + labelHeight + 5
	end

	local frameHeight = 25 + currentYPosition + 5
	mainFrame.Size = UDim2.new(0, 200, 0, frameHeight)
end

local function monitorTool(tool)
	if connections[tool] then
		connections[tool]:Disconnect()
	end

	connections[tool] = tool.AttributeChanged:Connect(function(attributeName)
		if attributeName == "mag" or string.sub(attributeName, 1, 9) == "__chamber" then
			updateGUI()
		end
	end)

	monitorFireMode(tool)
end

local function setupMonitoring()
	for _, connection in pairs(connections) do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	connections = {}

	for _, connections in pairs(soundConnections) do
		if type(connections) == "table" then
			for _, conn in pairs(connections) do
				if typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		elseif typeof(connections) == "RBXScriptConnection" then
			connections:Disconnect()
		end
	end
	soundConnections = {}

	local weapons = findAllWeapons()
	for _, weapon in ipairs(weapons) do
		monitorTool(weapon)
	end

	if player:FindFirstChild("Backpack") then
		connections.backpackAdded = player.Backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				wait(0.1) 
				monitorTool(child)
				updateGUI()
			end
		end)
		
		connections.backpackRemoved = player.Backpack.ChildRemoved:Connect(function()
			updateGUI()
		end)
	end

	if player.Character then
		connections.characterAdded = player.Character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				wait(0.1)
				monitorTool(child)
				updateGUI()
			end
		end)
		
		connections.characterRemoved = player.Character.ChildRemoved:Connect(function()
			updateGUI()
		end)
	end
end

setupMonitoring()
updateGUI()

player.CharacterAdded:Connect(function(character)
	wait(1)
	setupMonitoring()
	updateGUI()
end)

spawn(function()
	while true do
		wait(0.5)
		updateGUI()
	end
end)
