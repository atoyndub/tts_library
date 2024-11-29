-- **********************
-- *** GLOBAL OBJECTS ***
-- **********************
CARD_SETS = nil
INFINITE_BAGS = nil
BOARD_SPACES = nil
SCRIPTING_FUNCTIONS =
{
	-- pseudo shift key (scripting button index 10) is up
	{
		{}, -- scripting button index 1
		{}, -- scripting button index 2
		{}, -- scripting button index 3
		{}, -- scripting button index 4
		{}, -- scripting button index 5
		{}, -- scripting button index 6
		{}, -- scripting button index 7
		{}, -- scripting button index 8
	},

	-- pseudo shift key (scripting button index 10) is down
	{
			{}, -- scripting button index 1
			{}, -- scripting button index 2
			{}, -- scripting button index 3
			{}, -- scripting button index 4
			{}, -- scripting button index 5
			{}, -- scripting button index 6
			{}, -- scripting button index 7
			{}, -- scripting button index 8
	}
} 

-- **************
-- *** COLORS ***
-- **************

BOARDSPACE_TILE_GREEN = {r = 0, g = 1, b = 0, a = 0.2}
BOARDSPACE_TILE_RED = {r = 1, g = 0, b = 0, a = 0.2}
INNACTIVE_BAG_GREY = {r = 0.5, g = 0.5, b = 0.5}


-- ********************************
-- *** CARD ORIENTATION VECTORS ***
-- ********************************

FACE_UP_TOP_NORTH = {0, 180, 0}
FACE_DOWN_TOP_NORTH = {0, 180, 180}
DECAL_FACE_UP_TOP_NORTH = {90, 180, 0}


-- *********************************
-- *** ON LOAD STARTUP FUNCTIONS ***
-- *********************************

-- onLoad event is called after the game save finishes loading
function onLoad()
	userInitCardSets()
	userInitInfiniteBags()
	userInitBoardSpaces()	
	sortBoardSpacesByTileGUID()
	userInitScriptingFunctions()
	
	verifyPresenceOfAllTrackedAssets()

	userDefinedOnLoadTasks()
end

-- helper function
	function sortBoardSpacesByTileGUID()
		for i = 2, #BOARD_SPACES do
			local j = i
			while j > 1 and BOARD_SPACES[j - 1].tileGUID > BOARD_SPACES[j].tileGUID do
				temp = BOARD_SPACES[j - 1]
				BOARD_SPACES[j - 1] = BOARD_SPACES[j]
				BOARD_SPACES[j] = temp
				j = j - 1
			end
		end
	end


-- **************************
-- *** ASSET VERIFICATION ***
-- **************************

function verifyPresenceOfAllTrackedAssets()
	local objectsList
	local guidList
	local itemMissing = false
	for i = 1, #CARD_SETS do -- verify presence/tagging of all tracked cards
		objectsList = getObjectsByTypeAndTag(nil, {'Card', 'Deck', 'Tile'}, {CARD_SETS[i].tag})
		guidList = getAllCardGUIDsFromComingledCardsAndDecks(objectsList)
		local resultMessages = verifyPresenceOfCardsByGUIDList(guidList, CARD_SETS[i])
		if #resultMessages > 0 then
			itemMissing = true
			for j = 1, #resultMessages do
				print(resultMessages[j])
			end
		end
	end
	for k = 1, #INFINITE_BAGS do -- verify presence/tagging of all tracked infinite bags
		objectsList = getObjectsByTypeAndTag(nil, {'Infinite'}, {INFINITE_BAGS[k].tag})
		local resultMessage = verifyPresenceOfInfiniteBagsByBagObjList(objectsList, INFINITE_BAGS[k])
		if resultMessage != '' then
			itemMissing = true
			print(resultMessage)
		end
	end
	if itemMissing == false then
		print('All tracked objects located successfully on load')
	end
end

-- helper, returns {} if all good, a list of error messages otherwise
function verifyPresenceOfCardsByGUIDList(guidList, cardSet)
	local returnList = {}
	for i = 1, #cardSet.cards do
		local found = false
		for j = 1, #guidList do
			if cardSet.cards[i].guid == guidList[j] then
				found = true
				break
			end
		end
		if found == false then
			table.insert(returnList, 'Missing or untagged ' .. cardSet.tag .. ' card: ' .. cardSet.cards[i].name)
		end
	end
	return returnList
end

-- helper, returns '' if all good, an error message otherwise
function verifyPresenceOfInfiniteBagsByBagObjList(bagObjList, customTileBagRef)
	for i = 1, #bagObjList do
		if customTileBagRef.guid == bagObjList[i].guid then
			return ''
		end
	end
	return 'Missing or untagged ' .. customTileBagRef.tag .. ' bag'
end


-- ***********************
-- *** GLOBAL HANDLERS ***
-- ***********************

-- I'm using these handlers, in part, to override the default tagging behavior of
-- containers (which is bizarre) so as to ensure that a container always
-- has a tag if even one of it's contained objects has that tag

function onObjectEnterContainer(container, object)
	local tagsToAdd = object.getTags()
	for i = 1, #tagsToAdd do
		container.addTag(tagsToAdd[i])
	end
	userDefinedOnObjectEnterContainerTasks(container, object)
end

function onObjectLeaveContainer(container, object)
	if container.type == 'Infinite' then
		local bagTags = container.getTags()
		for m = 1, #bagTags do
			object.addTag(bagTags[m])
		end
	elseif container.type == 'Deck' then
		local remainingContents = container.getData().ContainedObjects
		local tagsToCheck = object.getTags()
		local i = 1
		while i <= #tagsToCheck do
			local tagFound = false
			for j, containedObj in pairs(remainingContents) do
				for k, tag in pairs(containedObj.Tags) do
					if tag == tagsToCheck[i] then
						tagFound = true
						break
					end
				end
				if tagFound == true then
					break
				end
			end
			if tagFound == true then
				table.remove(tagsToCheck, i)
			else -- tagFound == false
				container.removeTag(tagsToCheck[i])
				i = i + 1
			end
		end
	end
	userDefinedOnObjectLeaveContainerTasks(container, object)
end

-- prevent hard-coded default behaviour of drawing cards to hand
-- with alpha num key presses
function onObjectNumberTyped(object, player_color, number)
	return true
end


-- *************************************
-- *** SCRIPTING FUNCTION ASSIGNMENT ***
-- *************************************

function findMatchingScriptingFunctionData(player_presser_color, pseudoShiftIndex, keyPressIndex)

	local contextInfo = getHoverObjectAndBoardSpacesElementIndex(player_presser_color)
	local myBoardSpaceRef = nil
	if contextInfo.boardSpacesElementIndex != -1 then
		myBoardSpaceRef = BOARD_SPACES[contextInfo.boardSpacesElementIndex]
	end
	local functionsContext = {hoverObject = contextInfo.hoverObject, boardSpaceRef = myBoardSpaceRef, playerColor = player_presser_color}
	local scriptingFuncIndex = -1
	for i = 1, #SCRIPTING_FUNCTIONS[pseudoShiftIndex][keyPressIndex] do
		local currentFunc = SCRIPTING_FUNCTIONS[pseudoShiftIndex][keyPressIndex][i]
		local prerequisitesMet = true
		for j = 1, #currentFunc.prerequisites do
			for propName, propVal in pairs(currentFunc.prerequisites[j].addedContext) do
				functionsContext[propName] = propVal -- add or replace any additional properties needed for the function call
			end
			prerequisitesMet = Global.call(currentFunc.prerequisites[j].functionName, functionsContext)
			if prerequisitesMet == false then
				break
			end
		end
		if prerequisitesMet == true then
			scriptingFuncIndex = i
			break
		end
	end

	local returnObj =
	{
		scriptingFunctionIndex = scriptingFuncIndex,
		playerColor = player_presser_color,
		hoverObjectGUID = '000000',
		boardSpaceRefIndex = contextInfo.boardSpacesElementIndex,
	}
	if contextInfo.hoverObject != nil then
		returnObj.hoverObjectGUID = contextInfo.hoverObject.guid
	end
	return returnObj
end

-- helper
function getHoverObjectAndBoardSpacesElementIndex(player_presser_color)
	local hoverObj = Player[player_presser_color].getHoverObject()
	local boardSpacesIndex = -1
	if hoverObj != nil then
		boardSpacesIndex = getBoardSpaceElementIndexByTileGUID(hoverObj.guid)
		if boardSpacesIndex != -1 then -- hover object is a tracked tile in BOARD_SPACES
			hoverObj = nil
		else -- hover object is not a tracked tile in BOARD_SPACES
			local containedInZones = hoverObj.getZones()
			if #containedInZones > 0 then
				local containingZoneGUID = containedInZones[1].guid -- later this needs to change to select the most proximal containing zone
				boardSpacesIndex = getBoardSpaceElementIndexByZoneGUID(containingZoneGUID) -- returns -1 if no matching zone in BOARD_SPACES, the matching element index otherwise
			end
		end
	end
	return {hoverObject = hoverObj, boardSpacesElementIndex = boardSpacesIndex}
end


-- *************************************************
-- *** SCRIPTING FUNCTION STANDARD PREREQUISITES ***
-- *************************************************

-- expects hoverObject, boardSpaceRef, and playerColor context properties
function meetsPrereqs_HasHoverObj(context)
	return context.hoverObject != nil
end

-- expects hoverObject, boardSpaceRef, playerColor, and typesPermitted context properties
function  meetsPrereqs_HoverObjectTypePermitted(context)
	if meetsPrereqs_HasHoverObj(context) == false then
		return false
	end
	for i = 1, #context.typesPermitted do
		if context.hoverObject.type == context.typesPermitted[i] then
			return true
		end
	end
	return false
end

-- expects hoverObject, boardSpaceRef, playerColor, and tagsPermitted context properties
function  meetsPrereqs_HoverObjectTagsPermitted(context)
	if meetsPrereqs_HasHoverObj(context) == false then
		return false
	end
	local hoverObjectTags = context.hoverObject.getTags()
	if #hoverObjectTags == 0 then -- this logic requires hoverObjectTags to be a non-empty subset of tagsPermitted
		return false
	end
	for i = 1, #hoverObjectTags do
		local tagMatch = false	
		for j = 1, #context.tagsPermitted do
			if hoverObjectTags[i] == context.tagsPermitted[j] then
				tagMatch = true
				break
			end
		end
		if tagMatch == false then -- illegal tag
			return false
		end
	end
	return true
end

-- expects hoverObject, boardSpaceRef, and playerColor context properties
function meetsPrereqs_HasBoardSpace(context)
	return context.boardSpaceRef != nil
end

-- expects hoverObject, boardSpaceRef, playerColor, and namesPermitted context properties
function  meetsPrereqs_BoardSpaceNamePermitted(context)
	if meetsPrereqs_HasBoardSpace(context) == false then
		return false
	end
	for i = 1, #context.namesPermitted do
		if context.boardSpaceRef.name == context.namesPermitted[i] then
			return true
		end
	end
	return false
end

-- expects hoverObject, boardSpaceRef, and playerColor context properties
function  meetsPrereqs_PlayerOwnsBoardSpace(context)
	if meetsPrereqs_HasBoardSpace(context) == false then
		return false
	end
	for i = 1, #context.boardSpaceRef.playerOwners do
		if context.playerColor == context.boardSpaceRef.playerOwners[i] then
			return true
		end
	end
	return false
end

-- expects hoverObject boardSpaceRef, and playerColor context properties
function meetsPrereqs_HoverObjectTagsAreSubsetOfBoardSpaceAssociatedTags(context)
	if meetsPrereqs_HasHoverObj(context) == false or meetsPrereqs_HasBoardSpace(context) == false then
		return false
	end
	local hoverObjectTags = context.hoverObject.getTags()
	if #hoverObjectTags == 0 then -- this logic requires hoverObjectTags to be a non-empty subset of board space's associatedTags
		return false
	end
	for i = 1, #hoverObjectTags do
		local tagMatch = false	
		for j = 1, #context.boardSpaceRef.associatedTags do
			if hoverObjectTags[i] == context.boardSpaceRef.associatedTags[j] then
				tagMatch = true
				break
			end
		end
		if tagMatch == false then -- illegal tag
			return false
		end
	end
	return true
end

-- expects hoverObject, boardSpaceRef, playerColor, and uiElementID context properties
function meetsPrereqs_UIElementIsDisplayed(context)
	return globalUIElementExists(context.uiElementID, context.playerColor) == true
end

-- expects hoverObject, boardSpaceRef, playerColor, and uiElementID context properties
function meetsPrereqs_UIElementIsNotDisplayed(context)
	return globalUIElementExists(context.uiElementID, context.playerColor) == false
end


-- ****************************************
-- *** SCRIPTING BUTTON KEY PRESS LOGIC ***
-- ****************************************

function onScriptingButtonDown(button_index, player_presser_color)
	if button_index == 10 then -- pseudo shift key (tab?)
		onPseudoShiftKeyDown(player_presser_color)
	elseif button_index == 9 then -- information key (spacebar?)
		toggleKeyPressInstructionsUI(player_presser_color)
	else
		local pseudoShiftIndex = 1
		if getPseudoShiftKeyState(player_presser_color) == 'down' then
			pseudoShiftIndex = 2
		end
		local functionData = findMatchingScriptingFunctionData(player_presser_color, pseudoShiftIndex, button_index)
		if functionData.scriptingFunctionIndex != -1 then
			local foundFunction = SCRIPTING_FUNCTIONS[pseudoShiftIndex][button_index][functionData.scriptingFunctionIndex]
			local functionParams = createStandardScriptingFunctionsParamsObject(player_presser_color, functionData.hoverObjectGUID, functionData.boardSpaceRefIndex)
			Global.call(foundFunction.callSign, functionParams)
		end
	end
end

-- helper
function onPseudoShiftKeyDown(player_presser_color)
	local gameTable = Tables.getTableObject()
	local statePropertyName = player_presser_color .. 'PseudoShift'
	setObjectMemoProperty(gameTable, statePropertyName, 'down')
end

-- returns object w/ properties playerColor, hoverObject, and boardSpaceRef
function createStandardScriptingFunctionsParamsObject(player_presser_color, hoverObjectGUID, boardSpaceRefIndex)
	local returnParams = {playerColor = player_presser_color, hoverObject = nil, boardSpaceRef = nil}
	if hoverObjectGUID != '000000' then
		returnParams.hoverObject = getObjectFromGUID(hoverObjectGUID)
	end
	if boardSpaceRefIndex != -1 and boardSpaceRefIndex != '-1' then
		returnParams.boardSpaceRef = BOARD_SPACES[boardSpaceRefIndex]
	end
	return returnParams	
end

function onScriptingButtonUp(button_index, player_presser_color)
	if button_index == 10 then
		onPseudoShiftKeyUp(player_presser_color)
	end
end

-- helper
function onPseudoShiftKeyUp(player_presser_color)
	local gameTable = Tables.getTableObject()
	local statePropertyName = player_presser_color .. 'PseudoShift'
	setObjectMemoProperty(gameTable, statePropertyName, 'up')
end

-- helper
function getPseudoShiftKeyState(playerColor)
	local gameTable = Tables.getTableObject()
	local statePropertyName = playerColor .. 'PseudoShift'
	return getObjectMemoProperty(gameTable, statePropertyName)
end


-- ********************
-- *** XML UI LOGIC ***
-- ********************

function setGlobalUIElement(elementID, elementContentObj, playerColor, imageAssetURLs)

	-- load any additional UI image assets as needed
	local workingAssets = UI.getCustomAssets()
	for j = 1, #imageAssetURLs do
		local assetAlreadyExists = false
		for k = 1, #workingAssets do
			if imageAssetURLs[j] == workingAssets[k].url then
				assetAlreadyExists = true
				break
			end
		end
		if assetAlreadyExists == false then
			table.insert(workingAssets, {name = imageAssetURLs[j], url = imageAssetURLs[j]})
		end
	end
	UI.setCustomAssets(workingAssets)

	-- load the actual xml element
	local xmlTable = UI.getXmlTable()
	local individualizedElementID = playerColor .. '_' .. elementID
	local targetElementIndex = -1
	for i = 1, #xmlTable do
		if xmlTable[i].attributes.id != nil and xmlTable[i].attributes.id == individualizedElementID then
			targetElementIndex = i
			break
		end
	end
	if targetElementIndex != -1 then
		xmlTable[targetElementIndex] = elementContentObj
	else
		table.insert(xmlTable, elementContentObj)
		targetElementIndex = #xmlTable
		xmlTable[targetElementIndex].attributes.id = individualizedElementID
	end
	xmlTable[targetElementIndex].attributes.visibility = playerColor
	UI.setXmlTable(xmlTable)
end

function removeGlobalUIElement(elementID, playerColor)
	local xmlTable = UI.getXmlTable()
	local individualizedElementID = playerColor .. '_' .. elementID
	for i = 1, #xmlTable do
		if xmlTable[i].attributes.id != nil and xmlTable[i].attributes.id == individualizedElementID then
			table.remove(xmlTable, i)
			if #xmlTable == 0 then
				UI.setXml('')
			else
				UI.setXmlTable(xmlTable)
			end
			return
		end
	end
end

function globalUIElementExists(elementID, playerColor)
	local xmlTable = UI.getXmlTable()
	local individualizedElementID = playerColor .. '_' .. elementID
	for i = 1, #xmlTable do
		if xmlTable[i].attributes.id != nil and xmlTable[i].attributes.id == individualizedElementID then
			return true
		end
	end
	return false
end

function toggleKeyPressInstructionsUI(player_presser_color)
	local keyPressInstructionsElementID = 'key_press_instructions'
	if globalUIElementExists(keyPressInstructionsElementID, player_presser_color) == false then
		local keyPressInstructionsElement =
		{
			tag = 'HorizontalLayout',
			attributes =
			{
				height = 700,
				width = 750,
				padding = '40 40 25 25',
				color = 'rgba(0,0,0,0.6)',
				rectAlignment = 'MiddleRight',
			},
			children =
			{
				{
					tag = 'VerticalLayout',
					attributes =
					{
						color = 'rgba(0.8, 0.8, 0.8)',
					},
					children = {}
				},
				{
					tag = 'VerticalLayout',
					attributes =
					{
						color = 'rgba(0.8, 0.8, 0.8)',
					},
					children = {}
				}
			}
		}
		for i = 1, 2 do
			for j = 1, 8 do
				local currentButtonElement =
				{
					tag = 'Button',
					attributes =
					{
						fontSize = 18,
						color = 'black',
						textColor = 'white',
					}
				}
				local buttonText
				if j < 6 then
					buttonText = j .. ') '
				elseif j == 6 then 
					buttonText = 'z) '
				elseif j == 7 then 
					buttonText = 'x) '
				else -- j == 8 then 
					buttonText = 'c) '
				end
				if i == 2 then
					buttonText = 'tab+' .. buttonText
				end
				local functionData = findMatchingScriptingFunctionData(player_presser_color, i, j)
				if functionData.scriptingFunctionIndex != -1 then
					local foundFunction = SCRIPTING_FUNCTIONS[i][j][functionData.scriptingFunctionIndex]
					local stringParams = foundFunction.callSign .. ' ' .. player_presser_color .. ' ' .. functionData.hoverObjectGUID .. ' ' .. functionData.boardSpaceRefIndex
					currentButtonElement.attributes.onClick = 'xmlButtonClick(' .. stringParams .. ')'
					buttonText = buttonText .. foundFunction.description
				else -- no matching function found
					buttonText = buttonText .. '---'
				end
				currentButtonElement.attributes.text = buttonText
				table.insert(keyPressInstructionsElement.children[i].children, currentButtonElement)
			end
		end
		setGlobalUIElement(keyPressInstructionsElementID, keyPressInstructionsElement, player_presser_color, {})
	else -- key press instructions menu is currently shown
		removeGlobalUIElement(keyPressInstructionsElementID, player_presser_color)
	end
end

-- got this information from a forum post claiming the API is wrong
-- if xml has no value, e.g. onClick="clickFunction()" then clickTypeOrValue will be a number depending on the type of click that triggered onClocl
-- if xml has a value, e.g. onClick="clickFunction(stringName)" then clickTypeOrValue will be that value a a string. in this case: "stringName"
function xmlButtonClick(player, clickTypeOrValue, id)
	local parameterStrings = {}
	for i in clickTypeOrValue:gmatch("%w+") do -- parse the clickTypeOrValue string into segments based on ' ' sentinel
		table.insert(parameterStrings, i)
	end
	local functionCallSign = table.remove(parameterStrings, 1)
	local functionParams = createStandardScriptingFunctionsParamsObject(parameterStrings[1], parameterStrings[2], tonumber(parameterStrings[3]))
	Global.call(functionCallSign, functionParams)
end


-- *****************************
-- *** GENERAL USE FUNCTIONS ***
-- *****************************

function getCardSetRefByTag(cardSetTag)
	for i = 1, #CARD_SETS do
		if CARD_SETS[i].tag == cardSetTag then
			return CARD_SETS[i]
		end
	end
	return nil -- not found
end

function getCardRefByTagAndGUID(cardSetTag, cardGUID)
	local cardSetRef = getCardSetRefByTag(cardSetTag)
	if cardSetRef != nil then
		for i = 1, #cardSetRef.cards do
			if cardSetRef.cards[i].guid == cardGUID then
				return cardSetRef.cards[i]
			end
		end
	end
	return nil -- not found
end

function getBoardSpaceElementIndexByZoneGUID(guid)
	for i = 1, #BOARD_SPACES do
		if BOARD_SPACES[i].zoneGUID == guid then
			return i
		end
	end
	return -1 -- no matching guid found
end

function getBoardSpaceElementIndexByTileGUID(guid)
	local min = 1
	local max = #BOARD_SPACES
	while max >= min do
		local i = math.floor(((max - min) / 2)) + min
		if BOARD_SPACES[i].tileGUID == guid then
			return i
		elseif BOARD_SPACES[i].tileGUID > guid then
			max = i - 1
		else -- BOARD_SPACES[i].tileGUID < guid
			min = i + 1
		end
	end
	return -1 -- no matching guid found
end

function getObjectsByTypeAndTag(fromZone, includeTypes, includeTags)
	local objectsOfDesiredType = getObjectsByTypeInZone(fromZone, includeTypes)	
	for i = #objectsOfDesiredType, 1, -1 do
		local tagMatch = false
		for j = 1, #includeTags do
			if objectsOfDesiredType[i].hasTag(includeTags[j]) then
				tagMatch = true
				break
			end
		end
		if tagMatch == false then
			table.remove(objectsOfDesiredType, i)
		end
	end
	for n = 2, #objectsOfDesiredType do -- sort the objects vertically so that ascending index corresponds to descending vertical
		local m = n + 0
		while m > 1 and objectsOfDesiredType[m].getPosition().y > objectsOfDesiredType[m - 1].getPosition().y do
			local temp = objectsOfDesiredType[m - 1]
			objectsOfDesiredType[m - 1] = objectsOfDesiredType[m]
			objectsOfDesiredType[m] = temp
			m = m - 1
		end
	end
	return objectsOfDesiredType
end

function getObjectsByTypeInZone(fromZone, includeTypes)
	local containedObjects
	if fromZone != nil then -- get objects from a single zone
		containedObjects = fromZone.getObjects()
	else -- get objects from the whole board
		containedObjects = getObjects()
	end
	for i = #containedObjects, 1, -1 do
		local typeMatch = false
		for j = 1, #includeTypes do
			if containedObjects[i].type == includeTypes[j] then
				typeMatch = true
				break
			end
		end
		if typeMatch == false then -- type doesn't match, object removed from return list
			table.remove(containedObjects, i)
		end
	end
	return containedObjects
end

function getAllObjectTagsInZone(fromZone, includeTypes)
	local returnTags = {}
	local objectsOfDesiredType = getObjectsByTypeInZone(fromZone, includeTypes)
	for i = 1, #objectsOfDesiredType do
		local objectTags = objectsOfDesiredType[i].getTags()
		for j = 1, #objectTags do
			local tagAlreadyFound = false
			for k = 1, #returnTags do
				if objectTags[j] == returnTags[k] then
					tagAlreadyFound = true
					break
				end
			end
			if tagAlreadyFound == false then
				table.insert(returnTags, objectTags[j])
			end
		end
	end
	return returnTags
end

function containerHasUndesiredTags(container, desiredTags)
	local containerTags = container.getTags()
	for j = 1, #containerTags do
		local undesiredTag = true
		for k = 1, #desiredTags do
			if containerTags[j] == desiredTags[k] then
				undesiredTag = false
				break
			end
		end
		if undesiredTag == true then
			return true
		end
	end
	return false
end

function countContainedObjectsWithUndesiredTags(container, desiredTags)
	local undesiredCount = 0
	local containedObjects = container.getData().ContainedObjects
	for i, containedObj in pairs(containedObjects) do
		local allObjectTagsAreDesired = true
		for j, tag in pairs(containedObj.Tags) do
			local tagIsDesired = false
			for k = 1, #desiredTags do
				if tag == desiredTags[k] then
					tagIsDesired = true
					break
				end
			end
			if tagIsDesired == false then
				allObjectTagsAreDesired = false
				break
			end
		end
		if allObjectTagsAreDesired == false then
			undesiredCount = undesiredCount + 1
		end
	end
	return undesiredCount
end

-- expected parameter structure
-- {
	-- from: zone from which objects should be taken, or nil for all objects
	-- to: zone or object to be used as destination for objects to be moved
	-- types: table of type strings characterizing objects to be moved e.g. 'Card', 'Deck', etc.
	-- tags: table of tag strings characterizing objects to be moved e.g. 'RUNNER', 'BLACK_MARKET', etc.
	-- num: max number of objects to be moved
	-- rotation: vector to characterize the final rotation orientation of objects to be moved
	-- fromTop: boolean flag to determine whether objects get pulled from the top (true) or bottom (false) of space/containers
	-- smoothMove: boolean flag to determine whether movement should be immediate (false) or smooth/slow (true)
-- }
function moveObjectsFromZoneToTile(p)
	local targetObjects = getObjectsByTypeAndTag(p.from, p.types, p.tags)
	local toPos = p.to.getPosition()

	-- count max number of individual target objects
	local maxTargetObjects = 0
	local numContents
	for i = 1, #targetObjects do
		numContents = targetObjects[i].getQuantity()
		if numContents > 1 then -- containter
			local undesiredCount = 0
			if containerHasUndesiredTags(targetObjects[i], p.tags) then
				undesiredCount = countContainedObjectsWithUndesiredTags(targetObjects[i], p.tags)
			end
			maxTargetObjects = maxTargetObjects + numContents - undesiredCount
		else -- targetObjects[i].getQuantity() == -1 --non container
			maxTargetObjects = maxTargetObjects + 1
		end
	end

	-- setup parameters for movement
	local toPosVec = {toPos.x, toPos.y + 1.25, toPos.z}
	local takeObjParams = 
	{
		position = toPosVec,
		top = p.fromTop,
		smooth = p.smoothMove,
		rotation = p.rotation
	}

	-- set directionality of iteration and number of singular objects to move
	local jStart
	local jEnd
	local jChange
	if p.fromTop == true then
		jStart = 1
		jEnd = #targetObjects + 1
		jChange = 1
	else
		jStart = #targetObjects
		jEnd = 0
		jChange = -1		
	end
	local numToMove = p.num
	if numToMove == nil or numToMove < 1 or numToMove > maxTargetObjects then
		numToMove = maxTargetObjects
	end
	local j = jStart

	-- peform the movement(s)
	while j != jEnd and numToMove > 0 do
		numContents = targetObjects[j].getQuantity()
		if numContents > 1 then -- container

			if containerHasUndesiredTags(targetObjects[j], p.tags) == true then -- the container has some contents which should be filtered out of the move based on their tags
				local goodGUIDs = getGUIDsOfContainedObjectsWithOnlyDesiredTags(targetObjects[j], p.tags)				
				for k = 1, #goodGUIDs do
					takeObjParams.guid = goodGUIDs[k]
					targetObjects[j].takeObject(takeObjParams)
					numToMove = numToMove - 1
					if numToMove == 0 then
						return
					end
				end
				takeObjParams.guid = nil
				j = j + jChange --iterate to next target object
				
			else -- the container does not have contents which should be filtered out of the move based on their tags
				if numContents <= numToMove then -- move the whole container
					if p.smoothMove == false then
						targetObjects[j].setPosition(toPosVec)
					else
						targetObjects[j].setPositionSmooth(toPosVec, false, false)
					end
					targetObjects[j].setRotation(p.rotation)
					numToMove = numToMove - numContents
					j = j + 1 --iterate to next target object
				else -- move less than all of the contents out of the container
					if numToMove == 1 then
						targetObjects[j].takeObject(takeObjParams)
					else -- numToMove > 1 (assumed)
						local topAndBottom = targetObjects[j].cut(numToMove)
						Wait.frames( --waiting because the cut takes time to create the new decks
							function()
								local index = 1 -- bottom
								if getFromTop == true then
									index = 2 -- top
								end
								if p.smoothMove == false then
									topAndBottom[index].setPosition(toPosVec)
								else
									topAndBottom[index].setPositionSmooth(toPosVec, false, false)
								end
								topAndBottom[index].setRotation(p.rotation)
							end,
							1
						)
					end
					return -- numToMove has been exhausted
				end
			end

		else -- single item

			if p.smoothMove == false then
				targetObjects[j].setPosition(toPosVec)
			else
				targetObjects[j].setPositionSmooth(toPosVec, false, false)
			end
			targetObjects[j].setRotation(p.rotation)
			j = j + jChange --iterate to next target object
			numToMove = numToMove - 1

		end
	end
end

function spreadCardsOverBoardSpaceTile(boardSpaceRef, targetTags)
    local targetZone = getObjectFromGUID(boardSpaceRef.zoneGUID)
    local targetTile = getObjectFromGUID(boardSpaceRef.tileGUID)
	local obstacleCardsAndDecks = getObjectsByTypeAndTag(targetZone, {'Card', 'Deck'}, targetTags)
	if #obstacleCardsAndDecks == 0 then
		return
	end
	local combinedDeck = table.remove(obstacleCardsAndDecks, #obstacleCardsAndDecks)
	while #obstacleCardsAndDecks > 0 do
		local currentCardOrDeck = table.remove(obstacleCardsAndDecks, #obstacleCardsAndDecks)
		combinedDeck = combinedDeck.putObject(currentCardOrDeck) -- combinedDeck becomes the newly created deck if it was originally just a card
	end

	local deckWidth = combinedDeck.getBounds().size.x
	local tileWidth = targetTile.getBounds().size.x
	local numCards = combinedDeck.getQuantity()
	if numCards < 1 then
		numCards = 1 --getQuantity() returns -1 when called on a single card
	end
	local cumulativeCardsWidth = deckWidth * numCards
	local uncoveredWidth = tileWidth - cumulativeCardsWidth
	local spacer
	local cardOffset
	if uncoveredWidth > 0 then
		spacer = uncoveredWidth / (numCards + 1)
		cardOffset = deckWidth + spacer
	else
		spacer = 0.2
		cardOffset = (tileWidth - (spacer * 2) - deckWidth) / (numCards - 1) -- accounts for uncovered spacers on either side and one whole card exposed at the end of the spread
	end
	local tilePosition = targetTile.getPosition()
	local firstCardPosition =
	{
		x = tilePosition.x - (tileWidth / 2) + (deckWidth / 2) + spacer,
		y = tilePosition.y + 1.5,
		z = tilePosition.z
	}
	spreadCardsRecursivelyWithTimeDelay(combinedDeck, firstCardPosition, cardOffset) -- recursive
end

-- helper
function spreadCardsRecursivelyWithTimeDelay(remainingDeck, cardPosition, cardOffset)
	local curNumCards = remainingDeck.getQuantity()
	local myRotation = FACE_UP_TOP_NORTH
	if curNumCards > 2 then
		remainingDeck.takeObject({position = cardPosition, top = false, smooth = true, rotation = myRotation})
		Wait.frames(
			function()
				cardPosition.x = cardPosition.x + cardOffset
				spreadCardsRecursivelyWithTimeDelay(remainingDeck, cardPosition, cardOffset)
			end,
			8
		)
	elseif curNumCards == 2 then
		remainingDeck.takeObject({position = cardPosition, top = false, smooth = true, rotation = myRotation})
		remainingDeck = remainingDeck.remainder -- should be the spawning final card
		Wait.frames(
			function()
				cardPosition.x = cardPosition.x + cardOffset
				spreadCardsRecursivelyWithTimeDelay(remainingDeck, cardPosition, cardOffset)
			end,
			8
		)
	else --curNumCards == 1
		remainingDeck.setPositionSmooth(cardPosition, false, false)
		remainingDeck.setRotationSmooth(myRotation, false, false)
	end
end

function getGUIDsOfContainedObjectsWithOnlyDesiredTags(container, desiredTags)
	returnList = {}
	local containedObjects = container.getData().ContainedObjects
	for i, containedObj in pairs(containedObjects) do
		local allObjectTagsAreDesired = true
		for j, tag in pairs(containedObj.Tags) do
			local tagIsDesired = false
			for k = 1, #desiredTags do
				if tag == desiredTags[k] then
					tagIsDesired = true
					break
				end
			end
			if tagIsDesired == false then
				allObjectTagsAreDesired = false
				break
			end
		end
		if allObjectTagsAreDesired == true then
			table.insert(returnList, containedObj.GUID)
		end
	end
	return returnList
end

function getAllCardGUIDsFromComingledCardsAndDecks(cardsAndDecksObjList)
	local returnList = {}
	for i = 1, #cardsAndDecksObjList do
		local obj = cardsAndDecksObjList[i]
		if obj.type == 'Deck' then
			local containerContents = obj.getObjects()
			for j = 1, #containerContents do
				table.insert(returnList, containerContents[j].guid)
			end
		else -- obj.type == 'Card' (assumed)
			table.insert(returnList, obj.guid)
		end
	end
	return returnList
end

function deleteOneTile(targetTile)
	numTilesInStack = targetTile.getQuantity()
	if numTilesInStack == -1 then -- single tile
		targetTile.destruct()
	else -- tile stack
		local stackPos = targetTile.getPosition()
		local takeObjParams =
		{
			position = {x = stackPos.x, y = stackPos.y + 1.5, z = stackPos.z},
			smooth = false,
			callback_function = function(takenObj) --function to operate on the taken tile, once spawned
				takenObj.destruct()
			end,
		}
		targetTile.takeObject(takeObjParams)
	end
end

function deleteAllTilesInZone(removalZone)
	local containedTileTags = getAllObjectTagsInZone(removalZone, {'Tile'})
	local targetObjects = getObjectsByTypeAndTag(removalZone, {'Tile'}, containedTileTags)
	for i = 1, #targetObjects do
		targetObjects[i].destruct()
	end
end

-- updates targetObj.memo json associated with propertyNameStr, without disturbing any other properties in the json
-- assumes the object's memo is valid json or an empty string
-- assumes all of the lowest-level property values within the json object representation are strings
function setObjectMemoProperty(targetObj, propertyNameStr, propertyValStr)
	local memoObject
	if targetObj.memo == nil or targetObj.memo == '' then -- uninitialized memo
		memoObject = {}
		memoObject[propertyNameStr] = propertyValStr
	else -- previously initialized memo
		memoObject = JSON.decode(targetObj.memo)
		memoObject[propertyNameStr] = propertyValStr
	end
	targetObj.memo = JSON.encode(memoObject)
end

-- returns nil if the property doesn't exist or has a value of '',
-- otherwise returns the property value
function getObjectMemoProperty(targetObj, propertyNameStr)
	if targetObj.memo == nil or targetObj.memo == '' then -- uninitialized memo
		return nil
	else -- previously initialized memo
		local memoObject = JSON.decode(targetObj.memo)
		if memoObject[propertyNameStr] == nil or memoObject[propertyNameStr] == '' then -- uninitialized or empty string property
			return nil
		else -- previously initialized property
			return memoObject[propertyNameStr]
		end
	end
end

function getObjectMemoAsTable(targetObj)
	if targetObj.memo == nil or targetObj.memo == '' then -- uninitialized memo
		return nil
	end
	return JSON.decode(targetObj.memo) -- previously initialized memo
end

-- *** FULL LIST OF GENERAL USE FUNCTIONS ***

-- GETTING REFERENCES TO CODE-BASED REPRESENTATIONS OF TRACKED OBJECTS
-- getCardSetRefByTag(cardSetTag)
-- getCardRefByTagAndGUID(cardSetTag, cardGUID)
-- getBoardSpaceElementIndexByZoneGUID(guid)
-- getBoardSpaceElementIndexByTileGUID(guid)

-- GETTING REFERENCES TO OBJECTS IN GAME
-- getObjectsByTypeAndTag(fromZone, includeTypes, includeTags)
-- getObjectsByTypeInZone(fromZone, includeTypes)

-- GETTING INFORMATION ABOUT OBJECT TAGS
-- getAllObjectTagsInZone(fromZone, includeTypes)
-- containerHasUndesiredTags(container, desiredTags)
-- countContainedObjectsWithUndesiredTags(container, desiredTags)

-- FUNCTIONS USED FOR FINDING AND MOVING OBJECTS
-- moveObjectsFromZoneToTile(p)
-- spreadCardsOverBoardSpaceTile(boardSpaceRef, targetTags)
-- spreadCardsRecursivelyWithTimeDelay(remainingDeck, cardPosition, cardOffset)

-- GETTING OBJECT GUIDS FROM WITHIN CONTAINERS (MOSTLY CARDS WITHIN DECKS)
-- getGUIDsOfContainedObjectsWithOnlyDesiredTags(container, desiredTags)
-- getAllCardGUIDsFromComingledCardsAndDecks(cardsAndDecksObjList)

-- FUNCTIONS TO DELETE TILES
-- deleteOneTile(targetTile)
-- deleteAllTilesInZone(removalZone)

-- FUNCTIONS TO WORK WITH OBJECT MEMOS
-- setObjectMemoProperty(targetObj, propertyNameStr, propertyValStr)
-- getObjectMemoProperty(targetObj, propertyNameStr)
-- getObjectMemoAsTable(targetObj)



--- *******************************************************************
--- *******************************************************************
--- *******************************************************************
--- *** MARGINAL END OF PREDEFINED LIBRARY OF STRUCTURES/FUNCTIONS ***
--- ***     SEE SYNTAX EXAMPLES AND 'POPULATE BELOW' STATEMENTS     ***
--- ***   FOR INSTRUCTIONS TO IMPLEMENT THIS LIBRARY IN A NEW MOD   ***
--- *******************************************************************
--- *******************************************************************
--- *******************************************************************



-- *******************
-- *** NAMED GUIDS ***
-- *******************

-- optionally assign specific guids names here, to make accessing
-- the associated objects in later functions simpler/easier

-- single named tile guid example:
-- ENEMY_DISCARD_TILE_GUID = '123456'

-- simple array of named tile guids example:
-- ENEMY_PLAY_TILE_GUIDS = {'123456', '234567', '345678'}

-- array of named tile guids by player color example:
-- PLAYER_PLAY_TILE_GUIDS = {Green = '123456', Red = '234567', White = '345678', Blue = '456789'}

-- *** POPULATE BELOW ***

RUNNER_HOME_TILE_GUID = '262a53'
RUNNER_UPGRADE_TILE_GUID = 'bd9b3a'
MISSION_BOARD_TILE_GUID = 'a9b26b'
RUNNER_KARMA_STICKER_TILE_GUID = '44f630'

NORMAL_OBSTACLE_DRAW_TILE_GUID = '1655a4'
NORMAL_OBSTACLE_DRAWN_TILE_GUID = '6ba9a3'
NORMAL_OBSTACLE_DISCARD_TILE_GUID = 'a7f6f4'

HARD_OBSTACLE_DRAW_TILE_GUID = '830274'
HARD_OBSTACLE_DRAWN_TILE_GUID = '9c60a7'
HARD_OBSTACLE_DISCARD_TILE_GUID = '0954ad'

EVENT_DRAW_TILE_GUID = 'd60a17'
EVENT_DRAWN_TILE_GUID = 'ccb472'
EVENT_DISCARD_TILE_GUID = 'd0ef1e'

BLACK_MARKET_DRAW_TILE_GUID = '29ebc1'
BLACK_MARKET_DRAWN_TILE_GUIDS = {'9a2c0a', 'b603d0', 'c0da53', '7fec21', '18c414', 'f7213b', '5a6dcc', 'd1ddda'}
BLACK_MARKET_DISCARD_TILE_GUID = 'c2d224'

TILE_BAG_GUIDS = {TILE_MAX_HEALTH = '80bfb8', TILE_HEALTH = '00d330', TILE_GENERIC_ROUND = '6c930c', TILE_GENERIC_SQUARE = '4503cb',
			TILE_EXHAUSTED = 'f2889a', TILE_DAMAGE = '105ae8', TILE_NUYEN_ONE = '2f9676', TILE_NUYEN_THREE = 'd67846',
			TILE_NUYEN_FIVE = '8aece2', TILE_MOD_NEG_THREE = '4be0af', TILE_MOD_NEG_TWO = '338807', TILE_MOD_NEG_ONE = 'f3bc60',
			TILE_MOD_POS_ONE = 'fc1efe', TILE_MOD_POS_TWO = 'e29882', TILE_MOD_POS_THREE = '67bc61'}

PLAYER_ASSIST_TILE_GUIDS = {Green = 'f322ce', Red = 'fbc944', White = '54ce04', Blue = '61bd8f'}
PLAYER_PLAY_TILE_GUIDS = {Green = 'e0b938', Red = 'f0cc80', White = '836cb4', Blue = 'f164fe'}
PLAYER_OBSTACLESPACE_TILE_GUIDS = {Green = 'add1a4', Red = '9054a4', White = '9634f9', Blue = '01ad6e'}
PLAYER_RUNNERSPACE_TILE_GUIDS = {Green = 'fc31e4', Red = 'c91adf', White = 'bdcb60', Blue = 'c11777'}
PLAYER_ROLE_TILE_GUIDS = {Green = 'b78bfc', Red = 'f532f7', White = '91e1f3', Blue = '6d172b'}
PLAYER_TURN_SEQUENCE_TILE_GUIDS = {Green = '77da2a', Red = '75bd4f', White = '246425', Blue = 'dff451'}
PLAYER_MODIFIER_TOKENS_TILE_GUIDS = {Green = 'ec64dd', Red = 'c27b87', White = 'f7f99d', Blue = 'ef484c'}
PLAYER_NUYEN_TOKENS_TILE_GUIDS = {Green = '482fb7', Red = '686eea', White = 'd250c7', Blue = 'ac5b76'}
PLAYER_VARIOUS_TOKENS_TILE_GUIDS = {Green = '3bfb3d', Red = '2b6651', White = '1e819f', Blue = '377f44'}
PLAYER_DRAW_TILE_GUIDS = {Green = 'b40f67', Red = '41561c', White = 'f88d73', Blue = 'c2adf2'}
PLAYER_DISCARD_TILE_GUIDS = {Green = 'f16d40', Red = '259cc0', White = 'c1082d', Blue = 'cd6f05'}
PLAYER_HAND_TILE_GUIDS = {Green = 'e96ed2', Red = '0c7fe4', White = '717929', Blue = 'ad87e6'}


-- *****************
-- *** CARD SETS ***
-- *****************

function userInitCardSets()
	CARD_SETS =
	{
		-- single card set syntax example
		-- {
			-- tag = 'EXAMPLE' -- the tag that will be assigned to all cards in this set, and any decks containing them
			-- cards = 
			-- {
					-- {guid = '123456', name = 'description of this card'},
					-- ...
			-- }
		-- }
	
		-- *** POPULATE BELOW ***

		{
			tag = 'RUNNER',
			cards =
			{
				{guid = '996b29', name = 'ork'},
				{guid = '4e2f3e', name = 'oni'},
				{guid = 'a39400', name = 'jury rig'},
				{guid = '9d47d3', name = 'elf'},
				{guid = '55d92a', name = 'elf'},
				{guid = '81ab71', name = 'troll'},
				{guid = 'fa43c4', name = 'tank'},
				{guid = '8b3263', name = 'fury'},
				{guid = 'baf31c', name = 'connections'},
				{guid = '03c931', name = 'ork'},
				{guid = 'cdd9fc', name = 'human'},
				{guid = 'c05cfd', name = 'dwarf'},
				{guid = 'e7795f', name = 'seer'},
				{guid = '7af413', name = 'troll'},
				{guid = 'a95186', name = 'human'},
				{guid = 'b69572', name = 'dwarf'}
			}
		},
		{
			tag = 'SINGLE_ROLE',
			cards =
			{
				{guid = '491643', name = 'street samurai role'},
				{guid = 'ddf5d8', name = 'face role'},
				{guid = 'd28277', name = 'decker role'},
				{guid = '26e456', name = 'mage role'}
			}
		},
		{
			tag = 'HYBRID_ROLE',
			cards =
			{
				{guid = 'afc7a6', name = 'drone rigger decker role'},
				{guid = '811842', name = 'social adept mage role'},
				{guid = '00781b', name = 'social adept face role'},
				{guid = '813d25', name = 'drone rigger street samurai role'}
			}
		},
		{
			tag = 'DUAL_ROLE',
			cards =
			{
				{guid = '04e8fd', name = 'otaku role'},
				{guid = 'ab13a2', name = 'adept role'},
				{guid = '1bf12b', name = 'magician role'},
				{guid = '93d341', name = 'technomancer role'},
				{guid = 'ffd081', name = 'hacker role'},
				{guid = '55c8a9', name = 'cyber role'},
				{guid = 'c1f354', name = 'rigger role'},
				{guid = '6702ee', name = 'razor role'},
				{guid = '273b35', name = 'zealot role'},
				{guid = 'adec19', name = 'ringleader role'},
				{guid = '7cc1b0', name = 'infiltrator role'},
				{guid = '0fb975', name = 'shogun role'}
			}
		},
		{
			tag = 'TURN_SEQUENCE',
			cards =
			{
				{guid = 'd9a443', name = 'turn sequence'},
				{guid = '1f7b62', name = 'turn sequence'},
				{guid = '92be06', name = 'turn sequence'},
				{guid = '3aab38', name = 'turn sequence'},
				{guid = 'd540c0', name = 'turn sequence'},
			}
		},
		{
			tag = 'EVENT',
			cards =
			{
				{guid = '0fcc56', name = 'harlequin\'s shadow'},
				{guid = '187328', name = 'enemy comms'},
				{guid = 'f13ba1', name = 'unfriendly fire'},
				{guid = '414bf0', name = 'it\'s getting real'},
				{guid = '7a0cf9', name = 'no more toys'},
				{guid = 'daaf3c', name = 'this wasn\'t the plan'},
				{guid = 'bf79ce', name = 'a little help!'},
				{guid = 'edc9ce', name = 'focused combat'},
				{guid = '4db9c7', name = 'into the breach'},
				{guid = '575150', name = 'just survive'},
				{guid = '9344eb', name = 'instinct'},
				{guid = 'be1c37', name = 'win one, lose one'},
				{guid = '666138', name = 'reversal of fortune'},
				{guid = '850770', name = 'gps hack'},
				{guid = 'd2e849', name = 'top shelf'},
				{guid = 'f50ea5', name = 'we trained for this'},
				{guid = 'fe2617', name = 'new world'},
				{guid = '4c38af', name = 'no cover'},
				{guid = '2ebeea', name = 'first to wake'},
				{guid = '7c7d44', name = 'astral surge'},
				{guid = 'f8e7b4', name = 'professional problems'},
				{guid = 'd1cc9b', name = 'one hot minute'},
				{guid = 'fe8d32', name = 'danger zone'},
				{guid = 'e75f44', name = 'cunning plan'},
				{guid = 'eefb9d', name = 'hardened defenses'},
				{guid = 'bdb0e3', name = 'chummers'},
				{guid = 'ed8bc5', name = 'drekstorm'},
				{guid = '3a214c', name = 'yomi this'},
				{guid = 'df487d', name = 'humanis mercs'},
				{guid = 'ee6a1f', name = 'separated'},
				{guid = 'b1bd89', name = 'enemy tactics'},
				{guid = '81d127', name = 'we need a hero'},
				{guid = 'd6ad64', name = 'largest target'},
				{guid = '16ce50', name = 'stranger things happen'},
				{guid = 'add689', name = 'flicker of despair'},
				{guid = '9db3e4', name = 'big uglies'},
				{guid = '7eecea', name = 'we gotta slow them down!'},
				{guid = 'fa3d32', name = 'scavenging'},
				{guid = '1ca346', name = 'reinforcements'},
				{guid = 'e45c07', name = 'snafu'},
				{guid = 'ef425e', name = 'pay the man'},
				{guid = '4f8c96', name = 'no holding back'},
				{guid = '15726b', name = 'bad biz'},
				{guid = 'dee4aa', name = 'take the merchandise and run'},
				{guid = '0d0295', name = 'bullets & blades'},
				{guid = '19c2c2', name = 'pure chaos'},
				{guid = '850bc7', name = 'harlequinade'},
				{guid = 'bf4f7b', name = 'timebomb'},
				{guid = 'b04b24', name = 'grenade!'},
				{guid = 'e6d235', name = 'we\'re hacked'},
				{guid = '21e4e1', name = 'coordinated defenses'}
			}
		},
		{
			tag = 'NORMAL_OBSTACLE',
			cards =
			{
				{guid = 'afb947', name = 'death mage'},
				{guid = 'a7b8de', name = 'ancients shaman'},
				{guid = '5441e5', name = 'spirit of air'},
				{guid = 'd39eef', name = 'rampaging ghoul'},
				{guid = '16d6b1', name = 'conflicted elf ganger'},
				{guid = '273d6a', name = 'starving ghoul'},
				{guid = '673758', name = 'corporate adept'},
				{guid = 'be3dcc', name = 'combat decker'},
				{guid = '86e5e4', name = 'troll enforcer'},
				{guid = '725312', name = 'wage mage'},
				{guid = '75b22d', name = 'lone start trooper'},
				{guid = 'b4e85b', name = 'ancients champion'},
				{guid = '1033e7', name = 'virtuoso'},
				{guid = '06cdcb', name = 'troll mage'},
				{guid = 'b55c8b', name = 'dump mage'},
				{guid = 'a0a1cb', name = 'deckhead'},
				{guid = '2fbb5e', name = 'mouthy ganger'},
				{guid = 'dbe37a', name = 'fire adept'},
				{guid = 'af6bd7', name = 'light combat drone'},
				{guid = 'ca0867', name = 'harnessed ai'},
				{guid = '8e7d79', name = 'aztlan decker'},
				{guid = 'd5ed4b', name = 'buttoned-up hacker'},
				{guid = '2a8724', name = 'spell sniper'},
				{guid = '93c331', name = 'thought worm'},
				{guid = '044f03', name = 'ork bounty hunter'},
				{guid = '909dce', name = 'rampage virus'},
				{guid = 'd93c8a', name = 'bonelaced adept'},
				{guid = '4d154a', name = 'exiled prince'},
				{guid = 'e09452', name = 'jaguar shifter'},
				{guid = '4577c8', name = 'trip beams'},
				{guid = '70ff93', name = 'hacker team'},
				{guid = '56a198', name = 'knucklehead'},
				{guid = '557d2b', name = 'elf freelancer'},
				{guid = '302ddd', name = 'covert ops specialist'},
				{guid = '6ef3f8', name = 'gutter punks'},
				{guid = 'fe92ff', name = 'squad leader'},
				{guid = '2c68b6', name = 'chipped decker'},
				{guid = '2fb5ad', name = 'street prophet'},
				{guid = '87734d', name = 'solder punk'},
				{guid = '1cca57', name = 'careless researcher'},
				{guid = 'c3fc2d', name = 'wrecked limo'},
				{guid = 'acaf28', name = 'mil spec tuskers'},
				{guid = 'd7d6ad', name = 'yak muscle'},
				{guid = 'e14dfc', name = 'banshee operative'},
				{guid = 'eda954', name = 'aerial combat drone'},
				{guid = '703c69', name = 'ancients fanatic'},
				{guid = '87923c', name = 'ancients sentry'},
				{guid = 'e5fa21', name = 'astral shiver'},
				{guid = '6f574d', name = 'scrybot tracer'},
				{guid = '6fb243', name = 'wrecked battle wagon'},
				{guid = '77f3c0', name = 'sudden fade'},
				{guid = 'e738b7', name = 'out of ammo'},
				{guid = '0479b4', name = 'orc fixer'},
				{guid = '304652', name = 'mercenary elf decker'},
				{guid = 'e78c79', name = 'ancients ganger'},
				{guid = 'a1c4e6', name = 'demolitions expert'},
				{guid = 'c8da03', name = 'security goons'},
				{guid = '5e5a4f', name = 'buzzback'},
				{guid = '7efded', name = 'gang leader'},
				{guid = 'a893f3', name = 'wired ganger'},
				{guid = '479ebc', name = 'wired merc'},
				{guid = 'ff721d', name = 'shielded coven'},
				{guid = '752900', name = 'eye alarm'},
				{guid = 'f0cb6b', name = 'elf shaman'},
				{guid = '4e0159', name = 'freelance assassin'},
				{guid = '116ece', name = 'courier'},
				{guid = 'ee819f', name = 'warded mage'},
				{guid = 'a45a42', name = 'orc on the run'},
				{guid = 'f690d2', name = 'ancients lieutenant'},
				{guid = 'a33bf4', name = 'urban spirit'},
				{guid = 'e0c73b', name = 'customs officer'},
				{guid = '11f225', name = 'astral scout'}
			}
		},
		{
			tag = 'HARD_OBSTACLE',
			cards =
			{
				{guid = '01fcf0', name = 'renraku red samurai'},
				{guid = 'df8181', name = 'ic'},
				{guid = 'bb036d', name = 'black market profiteer'},
				{guid = 'da4032', name = 'drone rigger'},
				{guid = '5fcfaf', name = 'ares field rep'},
				{guid = 'a445b9', name = 'grey ops rigger team'},
				{guid = 'ebb413', name = 'trickster initiate'},
				{guid = '5ad26b', name = 'combat shaman'},
				{guid = 'bbe736', name = 'mayor of the street'},
				{guid = 'da8ab6', name = 'tir badass'},
				{guid = 'b171ff', name = 'border war vet'},
				{guid = '49bb99', name = 'wrecked tir copter'},
				{guid = 'c4ccd2', name = 'bug spirit'},
				{guid = '74be53', name = 'guy in the van'},
				{guid = '4c9912', name = 'weapons specialist'},
				{guid = '734937', name = 'aztlan veteran'},
				{guid = '9e420d', name = 'elf blademaster'},
				{guid = '4c1fb8', name = 'lone star lieutenant'},
				{guid = '737dfe', name = 'wrecked sensor bus'},
				{guid = 'dec703', name = 'indentured otaku'},
				{guid = 'f3ae8d', name = 'spirit of earth'},
				{guid = '12bcba', name = 'troll boot'},
				{guid = 'c7e42a', name = 'godwire'},
				{guid = '20a967', name = 'hush'},
				{guid = 'd31c5a', name = 'lone star sergeant'},
				{guid = '6925a1', name = 'tir ghost'},
				{guid = 'feec8a', name = 'wrecked auto duelist'},
				{guid = 'a8139e', name = 'security chief'},
				{guid = '5d3f7d', name = 'spirit of fire'},
				{guid = '607f1b', name = 'rent-a-trooper'},
				{guid = 'ada3d4', name = 'unusual suspects'},
				{guid = '8c44da', name = 'network fixer'},
				{guid = '9e6f7b', name = 'corporate shaman'},
				{guid = 'c860a8', name = 'gunslinger adept'},
				{guid = 'd29d2d', name = 'dzoo-noo-qua'},
				{guid = 'f07483', name = 'chromed samurai'},
				{guid = '7db93f', name = 'corp tactician'},
				{guid = '0b780a', name = 'reckless mastermind'},
				{guid = '35e19f', name = 'armored troopers'},
				{guid = '37b514', name = 'ghoul adept'},
				{guid = '93b114', name = 'knight errant field agent'},
				{guid = 'f859b8', name = 'banshee virus'},
				{guid = '26a297', name = 't-bird jockey'},
				{guid = '22af03', name = 'fomorian mage'},
				{guid = '976d94', name = 'drake assassin'},
				{guid = '4a683e', name = 'lightning mage'},
				{guid = '529506', name = 'vampire operative'},
				{guid = '1e8768', name = 'chaos sprite'},
				{guid = '802a4f', name = 'mercenary technomancer'},
				{guid = '30987f', name = 'warded decker'},
				{guid = '804da1', name = 'drake enforcer'},
				{guid = 'b09db9', name = 'military spec ic'},
				{guid = 'e8ee85', name = 'gargoyle'},
				{guid = 'e867e1', name = 'lone star commander'},
				{guid = 'e8ad5e', name = 'mage hunter'},
				{guid = 'e53a9f', name = 'saeder-krupp observer'}
			}
		},
		{
			tag = 'BLACK_MARKET',
			cards =
			{
				{guid = '5ff674', name = 'aztechnology striker'},
				{guid = 'dd26e5', name = 'badger combat tow truck'},
				{guid = 'e0da75', name = 'badger combat tow truck'},
				{guid = '11f8d6', name = 'covering fire'},
				{guid = '4a0f89', name = 'covering fire'},
				{guid = 'f1571e', name = 'covering fire'},
				{guid = 'e5000b', name = 'katana'},
				{guid = 'f4bfbb', name = 'katana'},
				{guid = '9f7e14', name = 'katana'},
				{guid = '86b1c5', name = 'monofilament whip'},
				{guid = 'fe9c9d', name = 'monofilament whip'},
				{guid = 'e513b6', name = 'monofilament whip'},
				{guid = '5ebd6d', name = 'crazy katie\'s autogun'},
				{guid = '1afe1c', name = 'crazy katie\'s autogun'},
				{guid = '0f9b92', name = 'suzuki mirage'},
				{guid = 'c5304a', name = 'suzuki mirage'},
				{guid = '6d77ca', name = 'ra sm-4 sniper rifle'},
				{guid = '423c9c', name = 'ra sm-4 sniper rifle'},
				{guid = 'dc3824', name = 'remington roomsweeper'},
				{guid = 'ceee2b', name = 'remington roomsweeper'},
				{guid = 'd01a86', name = 'remington roomsweeper'},
				{guid = 'cfdf4b', name = 'powerball'},
				{guid = '900398', name = 'powerball'},
				{guid = '519265', name = 'doc wagon contract'},
				{guid = 'd57eae', name = 'doc wagon contract'},
				{guid = '819bf6', name = 'doc wagon contract'},
				{guid = '5c7d14', name = 'coordinated attack'},
				{guid = 'f0c46c', name = 'coordinated attack'},
				{guid = '413ebe', name = 'coordinated attack'},
				{guid = '112abf', name = 'thinking ahead'},
				{guid = 'a79987', name = 'divination'},
				{guid = 'efc43b', name = 'divination'},
				{guid = '33214e', name = 'black market contacts'},
				{guid = '6b252b', name = 'black market contacts'},
				{guid = '39e3c2', name = 'black market contacts'},
				{guid = '567539', name = 'negotiation'},
				{guid = '1a19ff', name = 'negotiation'},
				{guid = '7dccf2', name = 'negotiation'},
				{guid = '4a6f90', name = 'bartering'},
				{guid = 'a04e62', name = 'bartering'},
				{guid = '171d2e', name = 'press the advantage'},
				{guid = '9fabf6', name = 'press the advantage'},
				{guid = 'bc7180', name = 'double double'},
				{guid = '94a0a4', name = 'thinking ahead'},
				{guid = 'faf8c9', name = 'hero move'},
				{guid = 'f7fcc5', name = 'heart of the team'},
				{guid = '0e3297', name = 'heart of the team'},
				{guid = '23c5d5', name = 'jacked in'},
				{guid = '2ad385', name = 'jacked in'},
				{guid = '5782a7', name = 'jacked in'},
				{guid = '62dac3', name = 'jacked in'},
				{guid = 'dae799', name = 'hack their comms'},
				{guid = 'a4ce26', name = 'hack their comms'},
				{guid = '1e2260', name = 'shield drone'},
				{guid = 'ff0d5e', name = 'shield drone'},
				{guid = '81bd46', name = 'icon grab'},
				{guid = 'a1d309', name = 'icon grab'},
				{guid = 'b23b6b', name = 'icon grab'},
				{guid = '45eeb4', name = 'icon grab'},
				{guid = '6f94db', name = 'data spike'},
				{guid = 'b17cc5', name = 'data spike'},
				{guid = '0c59dd', name = 'pair programming'},
				{guid = 'c5d0e7', name = 'pair programming'},
				{guid = 'c032f8', name = 'backdoor'},
				{guid = '46bb08', name = 'backdoor'},
				{guid = 'a55148', name = 'retrieval agent'},
				{guid = '2929c8', name = 'retrieval agent'},
				{guid = '5de980', name = 'drone army'},
				{guid = '377a5e', name = 'hack the world'},
				{guid = '238e4c', name = 'brute force hack'},
				{guid = '551295', name = 'brute force hack'},
				{guid = '23b204', name = 'stunbolt'},
				{guid = '8cdab1', name = 'stunbolt'},
				{guid = 'efe9c8', name = 'guiding spirit'},
				{guid = 'bbab15', name = 'guiding spirit'},
				{guid = '62258b', name = 'guiding spirit'},
				{guid = '145101', name = 'clairvoyance'},
				{guid = 'a7525d', name = 'clairvoyance'},
				{guid = 'cdb850', name = 'clairvoyance'},
				{guid = '352066', name = 'deathtouch'},
				{guid = 'c32f59', name = 'deathtouch'},
				{guid = '128f2f', name = 'deathtouch'},
				{guid = '27dd8d', name = 'deathtouch'},
				{guid = '93a00a', name = 'clairaudience'},
				{guid = '66d957', name = 'clairaudience'},
				{guid = 'fd5428', name = 'shatter'},
				{guid = 'a5b929', name = 'shatter'},
				{guid = '4ddd7c', name = 'fireball'},
				{guid = '049665', name = 'lightning bolt'},
				{guid = 'fb4c58', name = 'lightning bolt'}
			}
		},
		{
			tag = 'QUICK_SHOT',
			cards =
			{
				{guid = '211f87', name = 'old style'},
				{guid = 'c7e18b', name = 'old style'},
				{guid = '78bc7a', name = 'old style'},
				{guid = '1dcdfe', name = 'old style'},
				{guid = '2ff691', name = 'old style'},
				{guid = 'c6dc0d', name = 'old style'},
				{guid = 'd55d55', name = 'old style'},
				{guid = '2e8773', name = 'old style'}
			}
		},
		{
			tag = 'STREET_SMARTS',
			cards =
			{
				{guid = '6564a0', name = 'old style'},
				{guid = 'ca9947', name = 'old style'},
				{guid = '9806bc', name = 'old style'},
				{guid = '8fe12a', name = 'old style'},
				{guid = 'dd1d6a', name = 'old style'},
				{guid = '66a1f9', name = 'old style'},
				{guid = 'a42c83', name = 'old style'},
				{guid = 'd09cf8', name = 'old style'}
			}
		},
		{
			tag = 'MARK',
			cards =
			{
				{guid = 'ae1db4', name = 'old style'},
				{guid = '83fa2a', name = 'new style'},
				{guid = '0848fa', name = 'old style'},
				{guid = 'e843b8', name = 'old style'},
				{guid = 'fee2a9', name = 'old style'},
				{guid = '986f18', name = 'old style'},
				{guid = '9b9ac5', name = 'old style'},
				{guid = '4b9a8d', name = 'old style'}
			}
		},
		{
			tag = 'MANA',
			cards =
			{
				{guid = 'a59552', name = 'old style'},
				{guid = '7fba79', name = 'old style'},
				{guid = 'a85aa7', name = 'old style'},
				{guid = '47d04f', name = 'old style'},
				{guid = '841613', name = 'old style'},
				{guid = '168403', name = 'old style'},
				{guid = 'a4bf69', name = 'old style'},
				{guid = 'b99d32', name = 'old style'}
			}
		},
		{
			tag = 'UPGRADE_FIVE_KARMA',
			cards =
			{
				{guid = '1ae64f', name = 'cigar money', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599718154641383/36454ACA401FC89D3D646D5EE197C86F7C4CC8B3/'},
				{guid = 'c66807', name = 'just tough', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035684593/7B5986CDBF96B42641DACD5FBD8C1BA16D4620DE/'},
				{guid = '469d15', name = 'minor knack', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035689670/FA0199138BD429DDBFED98AE5A71EED9219C83CE/'},
				{guid = 'de189f', name = 'combat fu', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035685996/A73B9885CEC378A171EDA44D8FA0B2C74D3FC0DA/'},
				{guid = '9d46a9', name = 'got your backs', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035681079/B457C1D2E43AEE0BF7D3B54D09D808EECB75C39D/'},
				{guid = '571769', name = 'in training', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035682757/C91A8859D417F9C7867B90F1A6DE59E1B083CB43/'},
				{guid = '72ce3b', name = 'button masher', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035676667/098E3111C9DA4628A21D9DB520733C4BCE4D6A39/'},
				{guid = '967e95', name = 'fundamentals', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035691112/57C571C2343A914BCDFB1AFCACD41923B035382B/'},
				{guid = 'e898e9', name = 'competence', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785035688213/0863BFBD1C9EA417200D554F85109A6ADB025D42/'},
				{guid = '80b677', name = 'big plans', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646994035/4C2861828BD6FD3F2CF06900515626F014D2E2E0/'},
				{guid = '9a4c56', name = 'shopping agent', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646995106/4E45053FF06EDE4C2A6256909DBDF9BE5C776BAF/'},
				{guid = '988d86', name = 'high roller', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599718154638806/1EBEFA7FD1AE4D3AD7B3BA98C34988B2C1C9A60A/'},
				{guid = '8a793f', name = 'gambler', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936961997/61BED80ACB5C190129F22DBF2294973249DAA244/'},
				{guid = 'cf88dd', name = 'a stitch in time', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936960982/41DB7AD5D1A3452A26F6ACCF6045156FB314F806/'},
				{guid = '651fea', name = 'called shot', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936962984/EF11E852E9645212F966C71F4B916FCF3B00C920/'}
			}
		},
		{
			tag = 'UPGRADE_TEN_KARMA',
			cards =
			{
				{guid = '267ae7', name = 'minimalist', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936990681/76B9E3DD0690D6754998E0A52EF6C304D83577C2/'},
				{guid = '67c5d7', name = 'bribe the guard', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936989503/990F872D5763B5951550797B05BF4C7930FE57DB/'},
				{guid = '93bb35', name = 'precision tools', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936988367/71D7039EFD1FF944524A78E34307E88A251684CA/'},
				{guid = '6cb457', name = 'ace in the hole', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936987252/117A7C5699A454BCF52B88D237FA3568E0E02FBF/'},
				{guid = '832f8f', name = 'living fast', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036290883/02ED95D469ECA2B65B87BEE57A712394EA00487E/'},
				{guid = '94a39f', name = 'chill', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036295514/E4F794054951DB344F1E01FFB409D4B0327DD0E9/'},
				{guid = '1eabf7', name = 'specialist', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036296628/B7340A36636E8F34B0376C6827D2EA19A466F0F9/'},
				{guid = 'ae3b70', name = 'shock frills', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036299131/BEC4535D2A4DAACD66895617AD41AB086AADAB2F/'},
				{guid = 'c00533', name = 'prep work', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036297990/0766A298AAF55D8A975E2219859E96CB7B60EEAD/'},
				{guid = '8e9f95', name = 'lifestyle choice', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036293073/18A740EFE2063D6D7ADEA99D4FEB4ABCDDCA0867/'},
				{guid = '7cf10a', name = 'die hard', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599785036294429/723510525256A2A487C696B50C6B868686008FE3/'},
				{guid = '5dbe80', name = 'master trader', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936984855/89B91EBC605FA737647AFED7D3D5F4CFCB64D930/'},
				{guid = 'a39620', name = 'it\'s a raid!', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936986032/4FDE9D5C84F0874B710153BB553192CA654D54C2/'}
			}
		},
		{
			tag = 'UPGRADE_FIFTEEN_KARMA',
			cards =
			{
				{guid = 'e3d234', name = 'one step ahead', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937005033/48DAA586BF0CF45B4297B890D6C58B3CFCF1E557/'},
				{guid = '7d12dd', name = 'team player', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937004067/E49A00696583E33B7459B1F03345A88B190D1667/'},
				{guid = '86271c', name = 'luxury option', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937005987/6D090556DF9ECA36C09FFA53865DF2CB818C2F55/'},
				{guid = '9f84af', name = 'selfish chummer', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646904947/C0FCD7AE8CC3ADC91BBF60DF819F2A34942C9AB2/'},
				{guid = '5dbe80', name = 'been there, killed that', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646906976/2F0B82E04160C72EAF136644C07EE1D98146BD36/'}
			}
		},
		{
			tag = 'UPGRADE_TWENTY_KARMA',
			cards =
			{
				{guid = '8ee7db', name = 'wired reflexes', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646986252/3CDDE2109482FAD51FF78C806D7B339998B85CF6/'},
				{guid = '6d6fff', name = 'fragging touch', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646947391/D2951B0338158CE656E56132ED6A402E8601DAC8/'},
				{guid = '61e4c3', name = 'pain is gain', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646945451/36EBCB82713BA064F9C3BE77018B337F42BEDD55/'},
				{guid = 'e5a8c8', name = 'timing', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646944555/D4FFC77965D9F3BDFDD839B7868FEED9407CB8DD/'},
				{guid = '024bff', name = 'it\'s a jing thing', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646946419/BD0CAAB8A9BDE38C23166E634D7857189334A9E9/'},
				{guid = '8b52b1', name = 'jack of everything', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646940790/B7CD114BD05EF017E30A93A7081317FB6B11CAF8/'},
				{guid = 'e20caf', name = 'the long view', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646987229/C16E801B7E201D897DAF28E0F088CC5DAF47F38C/'},
				{guid = '2bfa91', name = 'bring it!', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646943844/7C3B6B6B4E0120C68179FF74B240397F30BB8C82/'},
				{guid = '780f06', name = 'rich & famous', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937023902/51102C6EF68E65AF6A3021A83024640278DCDAD0/'},
				{guid = 'f4e075', name = 'wealth & power', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937022873/E3773C3756E165BA2E24A9B1B2333BF17CC60C0A/'},
				{guid = '3aec0f', name = 'strength & wisdom', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937021984/5319CDC39E18C4E32A5F81E7F77425675265A58F/'}
			}
		},
		{
			tag = 'UPGRADE_TWENTYFIVE_KARMA',
			cards =
			{
				{guid = '8699ab', name = 'stim patch', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937043596/87B9960095015F7A01888B308EE881503AA5DD1F/'},
				{guid = '68656b', name = 'omae', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646969505/2830856DDF25D825220BCC409238C0B9195E4A16/'},
				{guid = '5a6030', name = 'inventory hack', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937042744/40A8D3B59E0AF892560F21FE75B95CD865C9872E/'},
				{guid = 'fef57a', name = 'stick to your guns', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937044606/CF4D21A8BDBE3529059925172E6CBFCF8907D9DB/'},
				{guid = 'b74e69', name = 'double move', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655599967646978820/8ECB4FDD487FAA601E7895E5A2AA7453EDF868BC/'}
			}
		},
		{
			tag = 'UPGRADE_THIRTY_KARMA',
			cards =
			{
				{guid = '8ee7db', name = 'shop when they drop', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937041809/376FCED0511D4B2D7F3BB1068EE0B42647F61628/'},
				{guid = '76f49a', name = 'practiced recovery', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212897175/588F9AAF6ADB4F00F290C04522047661FBADD595/'},
				{guid = '6b2b02', name = 'tricks', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212899248/6D75B0701A993BB2064A73B1F31264A901F72E03/'},
				{guid = '4377f2', name = 'true pro', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212900887/15C37DF259D1C4401DC2DA20C1AB811A7F5C737D/'},
				{guid = '22e1e6', name = 'strong arm', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937053587/CD5434C9BAECA670C6E8FA70A401F63FCADB5663/'}
			}
		},
		{
			tag = 'UPGRADE_THIRTYFIVE_KARMA',
			cards =
			{
				{guid = '218c5e', name = 'wiz decker', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212919128/CFC72F6C7500DB3B49F2A41A23433A2EFDA91520/'},
				{guid = '73fe30', name = 'juice', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212920064/576CAA5F222290EB0B730826A76E7F03E98BE430/'},
				{guid = '76f49a', name = 'one move ahead', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212921470/A1784A15A3C1C9021968D9E371987D620CB56889/'},
				{guid = '71b3f0', name = 'ground work', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212924902/791703DB53D0E5891FFE65E4053F85A4B20A59AD/'},
				{guid = '9b0c9d', name = 'drive a hard bargain', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937062971/27EF09658390D7FE7F511C7B819F1F97BF6B9048/'},
				{guid = '3f1117', name = 'tactician', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212922607/D8D63FF83B9CB3EF7A7FED1CEDB79D507C541F2D/'},
				{guid = '303b92', name = 'shadow messiah', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212923990/75EF91B3CEF139B454D48917C83948DDD6C0D7EC/'}
			}
		},
		{
			tag = 'UPGRADE_FORTY_KARMA',
			cards =
			{
				{guid = 'c70ced', name = 'perfect focus', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212957534/465EA3130A1487BB35626F83AAF2600A11472044/'},
				{guid = '5ce82f', name = 'your team, your rules', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212954981/04AB59D78C2C44509BD61BDF8C6461FD3DF708E9/'},
				{guid = '73fe30', name = 'head computer', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937068074/C7EADD7585E39C69B01F8AF89D04491711B35FB2/'},
				{guid = '13dc34', name = 'red haze', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212953515/871B5C88D807C238B291D5C26ADDCA26FE36B24A/'},
				{guid = 'c32d7b', name = 'fourth wind', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600400212956231/24BA1CF79022B55BE78E3469890DADF482062351/'}
			}
		},
		{
			tag = 'UPGRADE_FORTYFIVE_KARMA',
			cards =
			{
				{guid = 'c70ced', name = 'hat trick', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937073545/D7768A4627CA01F57ABB2BEB6F32EBD48BC9879E/'},
				{guid = '253103', name = 'show-off', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936928493/9A155029EBBDE2A6EDDBB90764E3B772A3B4626E/'},
				{guid = 'fddb10', name = 'zealot', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936929716/2EFA1638B4FA8F07D3D1FF176F3BE9F6D1634179/'}
			}
		},
		{
			tag = 'UPGRADE_FIFTY_KARMA',
			cards =
			{
				{guid = '253103', name = 'prime runner', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936937941/DFACB4A48BF1C80D536E6D869A952E2E3206C3D2/'},
				{guid = '0d67a1', name = 'charm', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937082215/B7B5355F7562A373C93B106122BDC2B7CB1C47CF/'},
				{guid = '505686', name = 'drone arsenal', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561937081162/88B93C9C1FA942D3E38CB6DEBA1812BC1E56D551/'},
				{guid = '5b4843', name = 'killing machine', url = 'https://steamusercontent-a.akamaihd.net/ugc/1655600561936938905/B53902A1C641EDDA9E5F4D9366196320B95DE916/'}
			}
		},
		{
			tag = 'MISSION',
			cards =
			{
				{guid = '9a3caa', name = 'crossfire'},
				{guid = 'c14c07', name = 'crazy katie\'s combat towing'},
				{guid = '9a3caa', name = 'pandemic'},
			}
		}
	}
end


-- *********************
-- *** INFINITE BAGS ***
-- *********************
function userInitInfiniteBags()
	INFINITE_BAGS =
	{
		-- single infinite bag syntax example
		-- {
			-- guid = '123456',
			-- tag = 'EXAMPLE'} -- tag is the tag that will be assigned to this bag and any/all of its spawn
		-- }
	
		-- *** POPULATE BELOW ***
	
		{guid = '80bfb8', tag = 'TILE_MAX_HEALTH'},
		{guid = '00d330', tag = 'TILE_HEALTH'},
		{guid = '105ae8', tag = 'TILE_DAMAGE'},
		{guid = 'f2889a', tag = 'TILE_EXHAUSTED'},
		{guid = '6c930c', tag = 'TILE_GENERIC_ROUND'},
		{guid = '4503cb', tag = 'TILE_GENERIC_SQUARE'},
		{guid = '4be0af', tag = 'TILE_MOD_NEG_THREE'},
		{guid = '338807', tag = 'TILE_MOD_NEG_TWO'},
		{guid = 'f3bc60', tag = 'TILE_MOD_NEG_ONE'},
		{guid = 'fc1efe', tag = 'TILE_MOD_POS_ONE'},
		{guid = 'e29882', tag = 'TILE_MOD_POS_TWO'},
		{guid = '67bc61', tag = 'TILE_MOD_POS_THREE'},
		{guid = '2f9676', tag = 'TILE_NUYEN_ONE'},
		{guid = 'd67846', tag = 'TILE_NUYEN_THREE'},
		{guid = '8aece2', tag = 'TILE_NUYEN_FIVE'},
	}
end


-- ********************
-- *** BOARD SPACES ***
-- ********************

-- requirements:
-- each board space consists of a tile (must be locked)
-- with a zone right on top of it

function userInitBoardSpaces()
	-- single board space syntax example
	-- {tileGUID = '123456', zoneGUID = '654321', name = 'mySpecialSpace', associatedTags = {'SPECIAL_CARDS_1', 'SPECIAL_CARDS_2'}, playerOwners = {'Green', 'Red'}},
	
	-- note: these will all be sorted by tileGUID asscending (on load)
	
	BOARD_SPACES =
	{
		
		-- *** POPULATE BELOW ***

		-- runner
		{tileGUID = RUNNER_HOME_TILE_GUID, zoneGUID = '62394d', name = 'home', associatedTags = {'RUNNER'}, playerOwners = {}},
		{tileGUID = RUNNER_UPGRADE_TILE_GUID, zoneGUID = '9a11d6', name = 'upgrade', associatedTags = {'RUNNER'}, playerOwners = {}},

		-- karma upgrades
		{tileGUID = 'e7f040', zoneGUID = '577128', name = 'home', associatedTags = {'UPGRADE_FIVE_KARMA'}, playerOwners = {}},
		{tileGUID = 'a3491d', zoneGUID = '3b977c', name = 'home', associatedTags = {'UPGRADE_TEN_KARMA'}, playerOwners = {}},
		{tileGUID = 'a64f6b', zoneGUID = '7c84e6', name = 'home', associatedTags = {'UPGRADE_FIFTEEN_KARMA'}, playerOwners = {}},
		{tileGUID = 'fe6558', zoneGUID = '132d46', name = 'home', associatedTags = {'UPGRADE_TWENTY_KARMA'}, playerOwners = {}},
		{tileGUID = 'd60577', zoneGUID = '74db6c', name = 'home', associatedTags = {'UPGRADE_TWENTYFIVE_KARMA'}, playerOwners = {}},
		{tileGUID = '90d03c', zoneGUID = '144ddd', name = 'home', associatedTags = {'UPGRADE_THIRTY_KARMA'}, playerOwners = {}},
		{tileGUID = '101633', zoneGUID = 'b1d02d', name = 'home', associatedTags = {'UPGRADE_THIRTYFIVE_KARMA'}, playerOwners = {}},
		{tileGUID = '5e4bd5', zoneGUID = '11b96c', name = 'home', associatedTags = {'UPGRADE_FORTY_KARMA'}, playerOwners = {}},
		{tileGUID = '81f627', zoneGUID = '82183d', name = 'home', associatedTags = {'UPGRADE_FORTYFIVE_KARMA'}, playerOwners = {}},
		{tileGUID = '4afd2e', zoneGUID = '136202', name = 'home', associatedTags = {'UPGRADE_FIFTY_KARMA'}, playerOwners = {}},
		{tileGUID = RUNNER_KARMA_STICKER_TILE_GUID, zoneGUID = '1a08a1', name = 'sticker', associatedTags = {'UPGRADE_FIVE_KARMA', 'UPGRADE_TEN_KARMA',
					'UPGRADE_FIFTEEN_KARMA', 'UPGRADE_TWENTY_KARMA', 'UPGRADE_TWENTYFIVE_KARMA', 'UPGRADE_THIRTY_KARMA',
					'UPGRADE_THIRTYFIVE_KARMA', 'UPGRADE_FORTY_KARMA', 'UPGRADE_FORTYFIVE_KARMA', 'UPGRADE_FIFTY_KARMA',}, playerOwners = {}},

		-- role
		{tileGUID = '92aee4', zoneGUID = 'b87346', name = 'home', associatedTags = {'SINGLE_ROLE'}, playerOwners = {}},
		{tileGUID = '5fdb77', zoneGUID = '194ae7', name = 'home', associatedTags = {'HYBRID_ROLE'}, playerOwners = {}},
		{tileGUID = 'bdd366', zoneGUID = '06f160', name = 'home', associatedTags = {'DUAL_ROLE'}, playerOwners = {}},

		-- turn sequence
		{tileGUID = 'b35659', zoneGUID = 'd77f0b', name = 'home', associatedTags = {'TURN_SEQUENCE'}, playerOwners = {}},

		-- basic cards
		{tileGUID = 'ac3735', zoneGUID = '34460e', name = 'home', associatedTags = {'MARK'}, playerOwners = {}},
		{tileGUID = 'bf6720', zoneGUID = 'eb6eaa', name = 'home', associatedTags = {'QUICK_SHOT'}, playerOwners = {}},
		{tileGUID = 'c8bd3d', zoneGUID = '8dda1e', name = 'home', associatedTags = {'MANA'}, playerOwners = {}},
		{tileGUID = '7f9767', zoneGUID = 'abddce', name = 'home', associatedTags = {'STREET_SMARTS'}, playerOwners = {}},

		-- black market
		{tileGUID = '353ef7', zoneGUID = '3fc4e3', name = 'home', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAW_TILE_GUID, zoneGUID = '1fbcc4', name = 'draw_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[1], zoneGUID = 'caab76', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[2], zoneGUID = '60c118', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[3], zoneGUID = 'c5e553', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[4], zoneGUID = '9fb857', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[5], zoneGUID = 'd3ba03', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[6], zoneGUID = '88c48b', name = 'drawn_black_market', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[7], zoneGUID = 'aca082', name = 'drawn_black_market_optional', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DRAWN_TILE_GUIDS[8], zoneGUID = '118633', name = 'drawn_black_market_optional', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},
		{tileGUID = BLACK_MARKET_DISCARD_TILE_GUID, zoneGUID = '06fb45', name = 'discard', associatedTags = {'BLACK_MARKET'}, playerOwners = {}},

		-- event
		{tileGUID = 'fa2532', zoneGUID = '366818', name = 'home', associatedTags = {'EVENT'}, playerOwners = {}},
		{tileGUID = EVENT_DRAW_TILE_GUID, zoneGUID = 'd6e087', name = 'draw_event', associatedTags = {'EVENT'}, playerOwners = {}},
		{tileGUID = EVENT_DRAWN_TILE_GUID, zoneGUID = '3ce91a', name = 'drawn_event', associatedTags = {'EVENT'}, playerOwners = {}},
		{tileGUID = EVENT_DISCARD_TILE_GUID, zoneGUID = 'b2a6f8', name = 'discard_event', associatedTags = {'EVENT'}, playerOwners = {}},

		-- normal obstacle
		{tileGUID = 'e3eab5', zoneGUID = 'f7df05', name = 'home', associatedTags = {'NORMAL_OBSTACLE'}, playerOwners = {}},
		{tileGUID = NORMAL_OBSTACLE_DRAW_TILE_GUID, zoneGUID = '28d68d', name = 'draw_normal_obstacle', associatedTags = {'NORMAL_OBSTACLE'}, playerOwners = {}},
		{tileGUID = NORMAL_OBSTACLE_DRAWN_TILE_GUID, zoneGUID = '97b3dc', name = 'drawn_normal_obstacle', associatedTags = {'NORMAL_OBSTACLE'}, playerOwners = {}},
		{tileGUID = NORMAL_OBSTACLE_DISCARD_TILE_GUID, zoneGUID = 'f40d3f', name = 'discard_normal_obstacle', associatedTags = {'NORMAL_OBSTACLE'}, playerOwners = {}},
		
		-- hard obstacle
		{tileGUID = '6ce69a', zoneGUID = 'a9de42', name = 'home', associatedTags = {'HARD_OBSTACLE'}, playerOwners = {}},
		{tileGUID = HARD_OBSTACLE_DRAW_TILE_GUID, zoneGUID = '6d6d4c', name = 'draw_hard_obstacle', associatedTags = {'HARD_OBSTACLE'}, playerOwners = {}},
		{tileGUID = HARD_OBSTACLE_DRAWN_TILE_GUID, zoneGUID = 'feef08', name = 'drawn_hard_obstacle', associatedTags = {'HARD_OBSTACLE'}, playerOwners = {}},
		{tileGUID = HARD_OBSTACLE_DISCARD_TILE_GUID, zoneGUID = '486690', name = 'discard_hard_obstacle', associatedTags = {'HARD_OBSTACLE'}, playerOwners = {}},

		-- mission
		{tileGUID = '846ecd', zoneGUID = '3f7e52', name = 'home', associatedTags = {'MISSION'}, playerOwners = {}},
		{tileGUID = MISSION_BOARD_TILE_GUID, zoneGUID = 'a8abb3', name = 'board', associatedTags = {'MISSION'}, playerOwners = {}},

		-- player assist spaces
		{tileGUID = PLAYER_ASSIST_TILE_GUIDS.Green, zoneGUID = '292fb3', name = 'assistSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_ASSIST_TILE_GUIDS.Red, zoneGUID = '71a7af', name = 'assistSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_ASSIST_TILE_GUIDS.White, zoneGUID = '2619d3', name = 'assistSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_ASSIST_TILE_GUIDS.Blue, zoneGUID = '423640', name = 'assistSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Blue'}},

		-- player play spaces
		{tileGUID = PLAYER_PLAY_TILE_GUIDS.Green, zoneGUID = '4f8d41', name = 'playSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_PLAY_TILE_GUIDS.Red, zoneGUID = '6c2bb4', name = 'playSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_PLAY_TILE_GUIDS.White, zoneGUID = '662b10', name = 'playSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_PLAY_TILE_GUIDS.Blue, zoneGUID = 'b2218a', name = 'playSpace', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Blue'}},

		-- player obstacle spaces
		{tileGUID = PLAYER_OBSTACLESPACE_TILE_GUIDS.Green, zoneGUID = 'ee00c0', name = 'obstacleSpace', associatedTags = {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_OBSTACLESPACE_TILE_GUIDS.Red, zoneGUID = 'e54cfd', name = 'obstacleSpace', associatedTags = {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_OBSTACLESPACE_TILE_GUIDS.White, zoneGUID = '0bf7a5', name = 'obstacleSpace', associatedTags = {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_OBSTACLESPACE_TILE_GUIDS.Blue, zoneGUID = '0ef3be', name = 'obstacleSpace', associatedTags = {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'},
					playerOwners = {'Blue'}},

		-- player runner spaces
		{tileGUID = PLAYER_RUNNERSPACE_TILE_GUIDS.Green, zoneGUID = '', name = 'runnerSpace', associatedTags = {'RUNNER'}, playerOwners = {'Green'}},
		{tileGUID = PLAYER_RUNNERSPACE_TILE_GUIDS.Red, zoneGUID = '', name = 'runnerSpace', associatedTags = {'RUNNER'}, playerOwners = {'Red'}},
		{tileGUID = PLAYER_RUNNERSPACE_TILE_GUIDS.White, zoneGUID = '', name = 'runnerSpace', associatedTags = {'RUNNER'}, playerOwners = {'White'}},
		{tileGUID = PLAYER_RUNNERSPACE_TILE_GUIDS.Blue, zoneGUID = '', name = 'runnerSpace', associatedTags = {'RUNNER'}, playerOwners = {'Blue'}},

		-- player various token spaces
		{tileGUID = PLAYER_VARIOUS_TOKENS_TILE_GUIDS.Green, zoneGUID = 'd7ab6b', name = 'various_tokens', associatedTags = {'TILE_HEALTH',
					'TILE_MAX_HEALTH', 'TILE_GENERIC_ROUND', 'TILE_GENERIC_SQUARE', 'TILE_EXHAUSTED', 'TILE_DAMAGE'}, playerOwners = {'Green'}},
		{tileGUID = PLAYER_VARIOUS_TOKENS_TILE_GUIDS.Red, zoneGUID = 'f3b50f', name = 'various_tokens', associatedTags = {'TILE_HEALTH',
					'TILE_MAX_HEALTH', 'TILE_GENERIC_ROUND', 'TILE_GENERIC_SQUARE', 'TILE_EXHAUSTED', 'TILE_DAMAGE'}, playerOwners = {'Red'}},
		{tileGUID = PLAYER_VARIOUS_TOKENS_TILE_GUIDS.White, zoneGUID = '39beff', name = 'various_tokens', associatedTags = {'TILE_HEALTH',
					'TILE_MAX_HEALTH', 'TILE_GENERIC_ROUND', 'TILE_GENERIC_SQUARE', 'TILE_EXHAUSTED', 'TILE_DAMAGE'}, playerOwners = {'White'}},
		{tileGUID = PLAYER_VARIOUS_TOKENS_TILE_GUIDS.Blue, zoneGUID = '4367ee', name = 'various_tokens', associatedTags = {'TILE_HEALTH',
					'TILE_MAX_HEALTH', 'TILE_GENERIC_ROUND', 'TILE_GENERIC_SQUARE', 'TILE_EXHAUSTED', 'TILE_DAMAGE'}, playerOwners = {'Blue'}},

		-- player nuyen token spaces
		{tileGUID = PLAYER_NUYEN_TOKENS_TILE_GUIDS.Green, zoneGUID = 'aa31cb', name = 'nuyen_tokens', associatedTags = {'TILE_NUYEN_THREE', 'TILE_NUYEN_ONE', 'TILE_NUYEN_FIVE'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_NUYEN_TOKENS_TILE_GUIDS.Red, zoneGUID = 'a2b5c4', name = 'nuyen_tokens', associatedTags = {'TILE_NUYEN_THREE', 'TILE_NUYEN_ONE', 'TILE_NUYEN_FIVE'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_NUYEN_TOKENS_TILE_GUIDS.White, zoneGUID = '58708a', name = 'nuyen_tokens', associatedTags = {'TILE_NUYEN_THREE', 'TILE_NUYEN_ONE', 'TILE_NUYEN_FIVE'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_NUYEN_TOKENS_TILE_GUIDS.Blue, zoneGUID = '021902', name = 'nuyen_tokens', associatedTags = {'TILE_NUYEN_THREE', 'TILE_NUYEN_ONE', 'TILE_NUYEN_FIVE'},
					playerOwners = {'Blue'}},

		-- player modifier token spaces
		{tileGUID = PLAYER_MODIFIER_TOKENS_TILE_GUIDS.Green, zoneGUID = '6356fc', name = 'modifier_tokens', associatedTags = {'TILE_MOD_NEG_THREE', 'TILE_MOD_NEG_TWO',
					'TILE_MOD_NEG_ONE', 'TILE_MOD_POS_ONE', 'TILE_MOD_POS_TWO', 'TILE_MOD_POS_THREE',}, playerOwners = {'Green'}},
		{tileGUID = PLAYER_MODIFIER_TOKENS_TILE_GUIDS.Red, zoneGUID = 'd58de7', name = 'modifier_tokens', associatedTags = {'TILE_MOD_NEG_THREE', 'TILE_MOD_NEG_TWO',
					'TILE_MOD_NEG_ONE', 'TILE_MOD_POS_ONE', 'TILE_MOD_POS_TWO', 'TILE_MOD_POS_THREE',}, playerOwners = {'Red'}},
		{tileGUID = PLAYER_MODIFIER_TOKENS_TILE_GUIDS.White, zoneGUID = '028235', name = 'modifier_tokens', associatedTags = {'TILE_MOD_NEG_THREE', 'TILE_MOD_NEG_TWO',
					'TILE_MOD_NEG_ONE', 'TILE_MOD_POS_ONE', 'TILE_MOD_POS_TWO', 'TILE_MOD_POS_THREE',}, playerOwners = {'White'}},
		{tileGUID = PLAYER_MODIFIER_TOKENS_TILE_GUIDS.Blue, zoneGUID = 'bc6ed4', name = 'modifier_tokens', associatedTags = {'TILE_MOD_NEG_THREE', 'TILE_MOD_NEG_TWO',
					'TILE_MOD_NEG_ONE', 'TILE_MOD_POS_ONE', 'TILE_MOD_POS_TWO', 'TILE_MOD_POS_THREE',}, playerOwners = {'Blue'}},

		-- player draw spaces
		{tileGUID = PLAYER_DRAW_TILE_GUIDS.Green, zoneGUID = '57af6e', name = 'draw_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_DRAW_TILE_GUIDS.Red, zoneGUID = '90002b', name = 'draw_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_DRAW_TILE_GUIDS.White, zoneGUID = 'bb8063', name = 'draw_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_DRAW_TILE_GUIDS.Blue, zoneGUID = '30aac0', name = 'draw_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Blue'}},

		-- player role spaces
		{tileGUID = PLAYER_ROLE_TILE_GUIDS.Green, zoneGUID = '69e224', name = 'roleSpace', associatedTags = {'SINGLE_ROLE', 'HYBRID_ROLE', 'DUAL_ROLE'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_ROLE_TILE_GUIDS.Red, zoneGUID = 'a1e85b', name = 'roleSpace', associatedTags = {'SINGLE_ROLE', 'HYBRID_ROLE', 'DUAL_ROLE'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_ROLE_TILE_GUIDS.White, zoneGUID = '83242e', name = 'roleSpace', associatedTags = {'SINGLE_ROLE', 'HYBRID_ROLE', 'DUAL_ROLE'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_ROLE_TILE_GUIDS.Blue, zoneGUID = '27b6c6', name = 'roleSpace', associatedTags = {'SINGLE_ROLE', 'HYBRID_ROLE', 'DUAL_ROLE'},
					playerOwners = {'Blue'}},

		-- player turn sequence spaces
		{tileGUID = PLAYER_TURN_SEQUENCE_TILE_GUIDS.Green, zoneGUID = '0b92c3', name = 'turnSequenceSpace', associatedTags = {'TURN_SEQUENCE'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_TURN_SEQUENCE_TILE_GUIDS.Red, zoneGUID = 'bb1361', name = 'turnSequenceSpace', associatedTags = {'TURN_SEQUENCE'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_TURN_SEQUENCE_TILE_GUIDS.White, zoneGUID = '281459', name = 'turnSequenceSpace', associatedTags = {'TURN_SEQUENCE'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_TURN_SEQUENCE_TILE_GUIDS.Blue, zoneGUID = 'ccb8b6', name = 'turnSequenceSpace', associatedTags = {'TURN_SEQUENCE'},
					playerOwners = {'Blue'}},

		-- player discard spaces
		{tileGUID = PLAYER_DISCARD_TILE_GUIDS.Green, zoneGUID = 'ef8de6', name = 'discard_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_DISCARD_TILE_GUIDS.Red, zoneGUID = '8abe4f', name = 'discard_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_DISCARD_TILE_GUIDS.White, zoneGUID = 'b47a90', name = 'discard_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_DISCARD_TILE_GUIDS.Blue, zoneGUID = 'cb7b8a', name = 'discard_player', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Blue'}},

		-- player hand spaces
		{tileGUID = PLAYER_HAND_TILE_GUIDS.Green, zoneGUID = '5bce83', name = 'hand', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Green'}},
		{tileGUID = PLAYER_HAND_TILE_GUIDS.Red, zoneGUID = 'cffa62', name = 'hand', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Red'}},
		{tileGUID = PLAYER_HAND_TILE_GUIDS.White, zoneGUID = '919aee', name = 'hand', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'White'}},
		{tileGUID = PLAYER_HAND_TILE_GUIDS.Blue, zoneGUID = '572997', name = 'hand', associatedTags = {'BLACK_MARKET', 'MANA', 'MARK', 'QUICK_SHOT', 'STREET_SMARTS'},
					playerOwners = {'Blue'}},	
	}
end


-- ***********************************************************
-- *** SCRIPTING FUNCTION REFERENCE ARRAYS AND COMPARATORS ***
-- ***********************************************************

-- helper
function addScriptingFunction(pseudoShiftIndex, scriptingButtonIndex, pCallSign, pDescription, pPrerequisites)
	local newScriptingFunctionMember =
	{
		callSign = pCallSign,
		description = pDescription,
		prerequisites = pPrerequisites
	}
	table.insert(SCRIPTING_FUNCTIONS[pseudoShiftIndex][scriptingButtonIndex], newScriptingFunctionMember)
end

-- SCRIPTING_FUNCTIONS is a 3D array
-- the highest level dimension has exactly two elements corresponding to pseudo shift (tab?) up and down states, respectively
-- the second level dimension has exactly 5 elements within each of the higher-level elements, corresponding to scripting buttons 1 - 5
-- the lowest level dimension has variable numbers of elements with the following syntax:
-- {
	-- callSign = 'doSomethingFunction', description = 'does something cool', prerequisites =
	-- {
		-- {functionName = 'meetsPrereqs_SomeBooleanFunction', addedContext = {additionaParam1 = 'someParam', additionalParam2 = {'listParamA', 'listParamB'}}},
		-- {functionName = 'meetsPrereqs_SomeOtherBooleanFunction', addedContext = {}},
	-- }
-- },

-- the prerequisites property is a list of reference boolean functions which will be used to determine whether this function can be called in the current context
-- any prerequisite functions listed will automatically have access to the hoverObject (if any) and boardSpaceRef (if any) in the current context
-- each function will additionally have access to any/all of it's addedContext members
-- some 'meetsPrereqs_...' functions are defined in the core library, but additional 'meetsPrereqs_...' functions can be defined
-- by the user-developer and referenced here as well

-- quick reference for predefined 'meetsPrereqs' functions
-- (context contains hoverObject, boardSpaceRef, and playerColor properties by default)
-- function meetsPrereqs_HasHoverObj(context)
-- function meetsPrereqs_HoverObjectTypePermitted(context) -- expects context.typesPermitted property
-- function meetsPrereqs_HoverObjectTagsPermitted(context) -- expects context.tagsPermitted property
-- function meetsPrereqs_HasBoardSpace(context)
-- function meetsPrereqs_BoardSpaceNamePermitted(context) -- expects context.namesPermitted property
-- function meetsPrereqs_PlayerOwnsBoardSpace(context)
-- function meetsPrereqs_HoverObjectTagsAreSubsetOfBoardSpaceAssociatedTags(context)
-- function meetsPrereqs_UIElementIsDisplayed(context) -- expects context.uiElementID context property
-- function meetsPrereqs_UIElementIsNotDisplayed(context) -- expects context.uiElementID context property

-- SCRIPTING_FUNCTIONS is populated below via the addScriptingFunction() helper

function userInitScriptingFunctions()

        -- *** POPULATE BELOW ***

		-- commonly use prerequisites (to support shorter addScriptingFunction() calls)
		-- examples:
			-- local Card = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Card'}}}
			-- local BoardHexBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'boardHex'}}}

		local DeckOrCard = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Deck', 'Card'}}}
		local Deck = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Deck'}}}
        local Card = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Card'}}}
		local Infinite = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Infinite'}}}
        local Tile = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Tile'}}}
        local RunnerTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'RUNNER'}}}
		local BlackMarketTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'BLACK_MARKET'}}}
		local EventTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'EVENT'}}}
		local HardObstTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'HARD_OBSTACLE'}}}
		local NormObstTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'NORMAL_OBSTACLE'}}}
		local ObstTag = {functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted = {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'}}}
		local KarmaTag =
		{
			functionName = 'meetsPrereqs_HoverObjectTagsPermitted',
			addedContext =
			{
				tagsPermitted =
				{
					'UPGRADE_FIVE_KARMA', 'UPGRADE_TEN_KARMA', 'UPGRADE_FIFTEEN_KARMA', 'UPGRADE_TWENTY_KARMA', 'UPGRADE_TWENTYFIVE_KARMA',
					'UPGRADE_THIRTY_KARMA', 'UPGRADE_THIRTYFIVE_KARMA', 'UPGRADE_FORTY_KARMA', 'UPGRADE_FORTYFIVE_KARMA', 'UPGRADE_FIFTY_KARMA'
				}
			}
		}
		local TokenTag =
		{
			functionName = 'meetsPrereqs_HoverObjectTagsPermitted',
			addedContext =
			{
				tagsPermitted =
				{
					'TILE_MOD_NEG_THREE', 'TILE_MOD_NEG_TWO', 'TILE_MOD_NEG_ONE', 'TILE_MOD_POS_ONE', 'TILE_MOD_POS_TWO', 'TILE_MOD_POS_THREE',
					'TILE_NUYEN_ONE', 'TILE_NUYEN_THREE', 'TILE_NUYEN_FIVE', 'TILE_HEALTH', 'TILE_MAX_HEALTH', 'TILE_GENERIC_ROUND',
					'TILE_GENERIC_SQUARE', 'TILE_EXHAUSTED', 'TILE_DAMAGE'
				}
			}
		}
		local HomeBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'home'}}}
        local HomeOrDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'home', 'draw', 'draw_black_market', 'draw_normal_obstacle', 'draw_hard_obstacle', 'draw_event'}}}
		local ModTokensBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'modifier_tokens'}}}
		local NuyenTokensBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'nuyen_tokens'}}}
		local VarTokensBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'various_tokens'}}}
		local AnyTokensBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'modifier_tokens', 'nuyen_tokens', 'various_tokens'}}}
		local StickerBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'sticker'}}}
		local BlackMarketDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'draw_black_market'}}}
		local BlackMarketDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_black_market', 'drawn_black_market_optional'}}}
		local OptionalBlackMarketDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_black_market_optional'}}}
        local NormObstDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'draw_normal_obstacle'}}}
		local HardObstDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'draw_hard_obstacle'}}}
        local NormObstDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_normal_obstacle'}}}
        local HardObstDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_hard_obstacle'}}}
		local ObstDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_normal_obstacle', 'drawn_hard_obstacle'}}}
		local EventDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'draw_event'}}}
        local EventDrawnBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'drawn_event'}}}
		local UpgradeBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'upgrade'}}}
		local PlayerObstBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'obstacleSpace'}}}
		local PlayerDrawBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'draw_player'}}}
		local PlayerDiscardBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'discard_player'}}}
		local PlayerHandBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'hand'}}}
        local PlayerPlayBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'playSpace'}}}
		local PlayerOwnsBS = {functionName = 'meetsPrereqs_PlayerOwnsBoardSpace', addedContext = {}}
		local MatchesBSTags = {functionName = 'meetsPrereqs_HoverObjectTagsAreSubsetOfBoardSpaceAssociatedTags', addedContext = {}}

		-- pseudo shift key up, scripting button index 1
		-- example to assign the doStuffFunc() to scripting key one (no pseudoshift) when user hovers over a card within a 'boardHex' boardspace:
			-- addScriptingFunction(1, 1, 'doStuffFunc', 'does stuff', {Tile, BoardHexBS})
		addScriptingFunction(1, 1, 'sendAllBlackMarketFromHomeZoneToDraw', 'send all cards to draw tile', {HomeBS, DeckOrCard, BlackMarketTag})
		addScriptingFunction(1, 1, 'sendAllEventFromHomeZoneToDraw', 'send all cards to draw tile', {HomeBS, DeckOrCard, EventTag})
		addScriptingFunction(1, 1, 'sendAllHardObstacleFromHomeZoneToDraw', 'send all cards to draw tile', {HomeBS, DeckOrCard, HardObstTag})
		addScriptingFunction(1, 1, 'sendAllNormalObstacleFromHomeZoneToDraw', 'send all cards to draw tile', {HomeBS, DeckOrCard, NormObstTag})
		addScriptingFunction(1, 1, 'sendTopCardFromHomeZoneToPlayBoard', 'send top card to play board',
		{
            -- maybe need to change this name and separate out this function definition into multiple functions
            {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'home', 'upgrade'}}},
			DeckOrCard,
			{
				functionName = 'meetsPrereqs_HoverObjectTagsPermitted', addedContext = {tagsPermitted =
				{
					'RUNNER', 'MANA', 'MARK', 'STREET_SMARTS', 'QUICK_SHOT','MISSION',
					'SINGLE_ROLE', 'HYBRID_ROLE', 'DUAL_ROLE', 'TURN_SEQUENCE'
				}}
			},
		})
		addScriptingFunction(1, 1, 'sendTopKarmaCardFromHomeZoneToRunnerUpgradeTile', 'send top card to runner upgrade tile', {HomeBS, DeckOrCard, KarmaTag})
		addScriptingFunction(1, 1, 'affixKarmaUpgradeToRunnerCardSlot1', 'affix karma upgrade to slot 1', {StickerBS, Card, MatchesBSTags})
		addScriptingFunction(1, 1, 'oneModPos1TileToPlayer', 'take one +1 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 1, 'oneNuyen1TileToPlayer', 'take one nuyen 1 tile', {NuyenTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 1, 'oneMaxHealthTileToPlayer', 'take one max health tile', {VarTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 1, 'sendTopBlackMarketCardFromDrawZoneToNextAvailableDrawnTile', 'draw one card to available space', {BlackMarketDrawBS, DeckOrCard, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendTopBlackMarketCardFromDrawnZoneToPlayerHand', 'send one card to hand', {BlackMarketDrawnBS, DeckOrCard, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendTopNormalObstacleCardFromDrawZoneToDrawnTile', 'draw one card', {NormObstDrawBS, DeckOrCard, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendTopHardObstacleCardFromDrawZoneToDrawnTile', 'draw one card', {HardObstDrawBS, DeckOrCard, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendTopObstacleCardFromDrawnZoneToPlayerObstacleTile', 'send one obstacle to player', {ObstDrawnBS, DeckOrCard, ObstTag})
		addScriptingFunction(1, 1, 'sendSingleTokenToPlayerTileFromHoveredBag', 'send one token to player', {Infinite, TokenTag})
		addScriptingFunction(1, 1, 'sendTopEventCardFromDrawZoneToDrawnTile', 'draw one card', {EventDrawBS, DeckOrCard, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendHoveredObstacleCardOrDeckFromPlayerObstacleSpaceToObstacleDiscardTile', 'send obstacle to discard',
					{PlayerObstBS, Card, PlayerOwnsBS, ObstTag})
		addScriptingFunction(1, 1, 'sendTopPlayerDrawCardToPlayerHand', 'draw one card to hand', {PlayerDrawBS, DeckOrCard, PlayerOwnsBS, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendAllPlayerDiscardCardsAndDecksToPlayerDraw', 'return all to draw pile', {PlayerDiscardBS, DeckOrCard, PlayerOwnsBS, MatchesBSTags})
		addScriptingFunction(1, 1, 'sendHoveredCardFromPlayerHandZoneToPlayerPlayTile', 'play card', {PlayerHandBS, Card, PlayerOwnsBS, MatchesBSTags})
		
		-- pseudo shift key up, scripting button index 2
		addScriptingFunction(1, 2, 'sendTopRunnerCardFromUpgradeZoneToHomeTile', 'return top card to home tile', {UpgradeBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopRunnerCardFromHomeZoneToUpgradeTile', 'send top card to upgrade tile', {HomeBS, DeckOrCard, RunnerTag})
        addScriptingFunction(1, 2, 'affixKarmaUpgradeToRunnerCardSlot2', 'affix karma upgrade to slot 2', {StickerBS, Card, MatchesBSTags})
		addScriptingFunction(1, 2, 'oneModPos2TileToPlayer', 'take one +2 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 2, 'oneNuyen3TileToPlayer', 'take one nuyen 3 tile', {NuyenTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 2, 'oneHealthTileToPlayer', 'take one health tile', {VarTokensBS, PlayerOwnsBS})
        addScriptingFunction(1, 2, 'sendTopBlackMarketCardFromDrawnZoneToDiscardTile', 'discard top card', {BlackMarketDrawBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopNormalObstacleCardFromDrawZoneToDiscardTile', 'discard top card', {NormObstDrawBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopHardObstacleCardFromDrawZoneToDiscardTile', 'discard top card', {HardObstDrawBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopEventCardFromDrawZoneToDiscardTile', 'discard top card', {EventDrawBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopNormalObstacleCardFromDrawnZoneToDiscardTile', 'discard top card', {NormObstDrawnBS, DeckOrCard, MatchesBSTags})        
        addScriptingFunction(1, 2, 'sendTopHardObstacleCardFromDrawnZoneToDiscardTile', 'discard top card', {HardObstDrawnBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopEventCardFromDrawnZoneToDiscardTile', 'discard top card', {EventDrawnBS, DeckOrCard, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendHoveredCardFromPlayerHandZoneToPlayerDiscardTile', 'discard card', {PlayerHandBS, Card, PlayerOwnsBS, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendTopPlayerDiscardCardToPlayerHand', 'return top to hand', {PlayerDiscardBS, DeckOrCard, PlayerOwnsBS, MatchesBSTags})
        addScriptingFunction(1, 2, 'sendHoveredCardFromPlayerPlaySpaceToPlayerHandTile', 'return to hand', {PlayerPlayBS, DeckOrCard, PlayerOwnsBS, MatchesBSTags})
        
		-- pseudo shift key up, scripting button index 3
        addScriptingFunction(1, 3, 'gatherAllToHomeZone', 'gather all cards/decks to home tile', {HomeBS})
        addScriptingFunction(1, 3, 'affixKarmaUpgradeToRunnerCardSlot3', 'affix karma upgrade to slot 3', {StickerBS, Card, MatchesBSTags})
		addScriptingFunction(1, 3, 'oneModPos3TileToPlayer', 'take one +3 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 3, 'oneNuyen5TileToPlayer', 'take one nuyen 5 tile', {NuyenTokensBS, PlayerOwnsBS})
		addScriptingFunction(1, 3, 'oneGenericRoundTileToPlayer', 'take one generic round tile', {VarTokensBS, PlayerOwnsBS})
        addScriptingFunction(1, 3, 'removeAllTilesAssociatedWithHoveredBag', 'remove all tokens associated with bag', {Infinite, TokenTag})
        addScriptingFunction(1, 3, 'sendAllPlayCardsAndDecksInPlayerPlaySpaceToPlayerDiscard', 'discard all', {PlayerPlayBS, PlayerOwnsBS})

		-- pseudo shift key up, scripting button index 4
        addScriptingFunction(1, 4, 'cycleCardInDeck', 'move bottom card to top of deck', {HomeBS, Deck})
        addScriptingFunction(1, 4, 'cycleCardInDeck', 'move bottom card to top of deck', {PlayerDiscardBS, Deck, PlayerOwnsBS})
        addScriptingFunction(1, 4, 'affixKarmaUpgradeToRunnerCardSlot4', 'affix karma upgrade to slot 4', {StickerBS, Card, MatchesBSTags})
        addScriptingFunction(1, 4, 'spreadObstaclesInPlayerObstacleSpace', 'spread obstacles', {PlayerObstBS, PlayerOwnsBS})
        addScriptingFunction(1, 4, 'spreadPlayCardsInPlayerPlaySpace', 'spread play cards', {PlayerPlayBS, PlayerOwnsBS})
        addScriptingFunction(1, 4, 'disposeOfSingleTile', 'remove single token', {Tile, TokenTag})

		-- pseudo shift key up, scripting button index 5
        addScriptingFunction(1, 5, 'shuffleDeck', 'shuffle the deck', {HomeOrDrawBS, Deck})
        addScriptingFunction(1, 5, 'shuffleDeck', 'shuffle the deck', {PlayerDrawBS, Deck, PlayerOwnsBS})

		-- pseudo shift key up, scripting button index 6

		-- pseudo shift key up, scripting button index 7

		-- pseudo shift key up, scripting button index 8

        -- pseudo shift key down, scripting button index 1
		addScriptingFunction(2, 1, 'clearKarmaUpgradeFromRunnerCardSlot1', 'clear karma upgrade from slot 1', {StickerBS})
        addScriptingFunction(2, 1, 'oneModNeg1TileToPlayer', 'take one -1 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(2, 1, 'oneGenericSquareTileToPlayer', 'take one generic square tile', {VarTokensBS, PlayerOwnsBS})

		-- pseudo shift key down, scripting button index 2
		addScriptingFunction(2, 2, 'clearKarmaUpgradeFromRunnerCardSlot2', 'clear karma upgrade from slot 2', {StickerBS})
        addScriptingFunction(2, 2, 'oneModNeg2TileToPlayer', 'take one -2 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(2, 2, 'oneExhaustedTileToPlayer', 'take one exhausted tile', {VarTokensBS, PlayerOwnsBS})

		-- pseudo shift key down, scripting button index 3
		addScriptingFunction(2, 3, 'clearKarmaUpgradeFromRunnerCardSlot3', 'clear karma upgrade from slot 3', {StickerBS})
        addScriptingFunction(2, 3, 'oneModNeg3TileToPlayer', 'take one -3 mod tile', {ModTokensBS, PlayerOwnsBS})
		addScriptingFunction(2, 3, 'oneDamageTileToPlayer', 'take one damage tile', {VarTokensBS, PlayerOwnsBS})

		-- pseudo shift key down, scripting button index 4
        addScriptingFunction(2, 4, 'clearKarmaUpgradeFromRunnerCardSlot4', 'clear karma upgrade from slot 4', {StickerBS})
        addScriptingFunction(2, 4, 'disposeOfAllTilesInZone', 'remove all tokens from zone', {AnyTokensBS, PlayerOwnsBS})
        addScriptingFunction(2, 4, 'toggleBlackMarketDrawnTile', 'toggle optional drawn tile', {OptionalBlackMarketDrawnBS})
        
		-- pseudo shift key down, scripting button index 5
        addScriptingFunction(2, 5, 'changePlayerSeat', 'change player seat', {PlayerHandBS})
        -- {
            -- callSign = 'cameraChange', description = 'change camera preset view', prerequisites = {}
        -- },

		-- pseudo shift key down, scripting button index 6

		-- pseudo shift key down, scripting button index 7

		-- pseudo shift key down, scripting button index 8
end


-- ***********************************
-- *** USER DEFINED ON EVENT TASKS ***
-- ***********************************

function userDefinedOnLoadTasks()
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON STARTUP ***

	refreshBlackMarketDrawnSpaceColor(getObjectFromGUID(BLACK_MARKET_DRAWN_TILE_GUIDS[7]))
	refreshBlackMarketDrawnSpaceColor(getObjectFromGUID(BLACK_MARKET_DRAWN_TILE_GUIDS[8]))
end

function userDefinedOnObjectEnterContainerTasks(container, object)
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON OBJECT ENTER CONTAINER ***
	
	object.setDecals({}) -- undraw any decals
end

function userDefinedOnObjectLeaveContainerTasks(container, object)	
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON OBJECT LEAVE CONTAINER ***
	
	if object.type == "Card" and object.getTags()[1] == 'RUNNER' then
		redrawAllRunnerCardDecalsBasedOnMemo(object)
	end
end


-- **************************************
-- *** SCRIPTING FUNCTION DEFINITIONS ***
-- **************************************

-- *** THESE ARE THE FUNCTIONS REFERRED TO IN THE SCRIPTING_FUNCTIONS 2-DIMENSIONAL ARRAY
-- *** WRITE ANY AND ALL FUNCTIONS HERE AS NEEDED

-- *** POPULATE BELOW ***

function shuffleDeck(params)
	local deck = params.hoverObject
	deck.shuffle()
end

-- gathers all cards/decks of matching tag to a 'home' board space
function gatherAllToHomeZone(params)
	local homeTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local movementParams = {from = nil, to = homeTile, types = {'Card', 'Deck'}, tags = {params.boardSpaceRef.associatedTags[1]},
				num = -1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = false}
	moveObjectsFromZoneToTile(movementParams)
end

-- generalized function for cycling one card in a deck occupying either a home zone or a player discard
function cycleCardInDeck(params)

	local deckBounds = params.hoverObject.getBounds()
	local takeObjParams =
	{
		position =
		{
			x = deckBounds.center.x + deckBounds.offset.x,
			y = deckBounds.center.y  + deckBounds.offset.y + deckBounds.size.y + 0.05,
			z = deckBounds.center.z + deckBounds.offset.z
		},
		top = false,
		smooth = false,
		--callback_function = function(takenObj) --function to operate on the taken tile, once spawned
			--params.hoverObject.putObject(takenObj) -- should place at top of deck since y coordintate of takenObj is elevated
		--end,
	}
	params.hoverObject.takeObject(takeObjParams)
end

function sendAllBlackMarketFromHomeZoneToDraw(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local destinationTile = getObjectFromGUID(BLACK_MARKET_DRAW_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
				num = -1, rotation = FACE_DOWN_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendAllNormalObstacleFromHomeZoneToDraw(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local destinationTile = getObjectFromGUID(NORMAL_OBSTACLE_DRAW_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
				num = -1, rotation = FACE_DOWN_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendAllHardObstacleFromHomeZoneToDraw(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local destinationTile = getObjectFromGUID(HARD_OBSTACLE_DRAW_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
				num = -1, rotation = FACE_DOWN_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendAllEventFromHomeZoneToDraw(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local destinationTile = getObjectFromGUID(EVENT_DRAW_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
				num = -1, rotation = FACE_DOWN_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

-- generalized handler for sending top card from home zone to somewhere on the board
function sendTopCardFromHomeZoneToPlayBoard(params)
	local rotationVec	
	local destinationTile
	local cardTag = params.boardSpaceRef.associatedTags[1]
	if cardTag == 'QUICK_SHOT' or cardTag == 'STREET_SMARTS' or cardTag == 'MARK' or cardTag == 'MANA' then
		rotationVec = FACE_DOWN_TOP_NORTH
		destinationTile = getObjectFromGUID(PLAYER_DRAW_TILE_GUIDS[params.playerColor])
	else
		rotationVec = FACE_UP_TOP_NORTH
		if cardTag == 'MISSION' then
			destinationTile = getObjectFromGUID(MISSION_BOARD_TILE_GUID)
		elseif cardTag == 'RUNNER' then
			destinationTile = getObjectFromGUID(PLAYER_RUNNERSPACE_TILE_GUIDS[params.playerColor])
		elseif cardTag == 'SINGLE_ROLE' or cardTag == 'HYBRID_ROLE' or cardTag == 'DUAL_ROLE' then
			destinationTile = getObjectFromGUID(PLAYER_ROLE_TILE_GUIDS[params.playerColor])
		elseif cardTag == 'TURN_SEQUENCE' then
			destinationTile = getObjectFromGUID(PLAYER_TURN_SEQUENCE_TILE_GUIDS[params.playerColor])
		end
	end
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
		num = 1, rotation = rotationVec, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopRunnerCardFromUpgradeZoneToHomeTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(RUNNER_HOME_TILE_GUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
					num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopRunnerCardFromHomeZoneToUpgradeTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)	
	local destinationTile = getObjectFromGUID(RUNNER_UPGRADE_TILE_GUID)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
					num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopKarmaCardFromHomeZoneToRunnerUpgradeTile(params)
	local cardTag = params.boardSpaceRef.associatedTags[1]
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(RUNNER_KARMA_STICKER_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {cardTag},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end


-- *********************************************
-- *** NORMAL OBSTACLE CARD SPACES FUNCTIONS ***
-- *********************************************

function sendTopNormalObstacleCardFromDrawZoneToDrawnTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(NORMAL_OBSTACLE_DRAWN_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'NORMAL_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopNormalObstacleCardFromDrawZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(NORMAL_OBSTACLE_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'NORMAL_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopNormalObstacleCardFromDrawnZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(NORMAL_OBSTACLE_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'NORMAL_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopObstacleCardFromDrawnZoneToPlayerObstacleTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(PLAYER_OBSTACLESPACE_TILE_GUIDS[params.playerColor])
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = params.boardSpaceRef.associatedTags,
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

-- *******************************************
-- *** HARD OBSTACLE CARD SPACES FUNCTIONS ***
-- *******************************************

function sendTopHardObstacleCardFromDrawZoneToDrawnTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(HARD_OBSTACLE_DRAWN_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'HARD_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopHardObstacleCardFromDrawZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(HARD_OBSTACLE_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'HARD_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopHardObstacleCardFromDrawnZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(HARD_OBSTACLE_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'HARD_OBSTACLE'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end


-- ***********************************
-- *** EVENT CARD SPACES FUNCTIONS ***
-- ***********************************

function sendTopEventCardFromDrawZoneToDrawnTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(EVENT_DRAWN_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'EVENT'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopEventCardFromDrawZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(EVENT_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'EVENT'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopEventCardFromDrawnZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(EVENT_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'EVENT'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end


-- ******************************************
-- *** BLACK MARKET CARD SPACES FUNCTIONS ***
-- ******************************************

function sendTopBlackMarketCardFromDrawZoneToNextAvailableDrawnTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local drawnBoardSpace
	local drawnZone
	local zoneContents
	local drawnTile
	local movementParams
	-- untoggleable card spaces
	for i = 1, 6 do
		drawnBoardSpaceRef = BOARD_SPACES[getBoardSpaceElementIndexByTileGUID(BLACK_MARKET_DRAWN_TILE_GUIDS[i])]
		drawnZone = getObjectFromGUID(drawnBoardSpaceRef.zoneGUID)
		zoneContents = getObjectsByTypeAndTag(drawnZone, {'Deck', 'Card'}, {'BLACK_MARKET'})
		if #zoneContents == 0 then
			drawnTile = getObjectFromGUID(drawnBoardSpaceRef.tileGUID)
			movementParams = {from = sourceZone, to = drawnTile, types = {'Card', 'Deck'}, tags = {'BLACK_MARKET'},
						num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
			moveObjectsFromZoneToTile(movementParams)
			return -- drawing only a single card
		end
	end
	-- card spaces which can be toggled on/off
	for j = 7, 8 do
		drawnBoardSpaceRef = BOARD_SPACES[getBoardSpaceElementIndexByTileGUID(BLACK_MARKET_DRAWN_TILE_GUIDS[j])]
		drawnTile = getObjectFromGUID(drawnBoardSpaceRef.tileGUID)
		if getObjectMemoProperty(drawnTile, 'toggle_state') == 'enabled' then
			drawnZone = getObjectFromGUID(drawnBoardSpaceRef.zoneGUID)
			zoneContents = getObjectsByTypeAndTag(drawnZone, {'Deck', 'Card'}, {'BLACK_MARKET'})
			if #zoneContents == 0 then
				movementParams = {from = sourceZone, to = drawnTile, types = {'Card', 'Deck'}, tags = {'BLACK_MARKET'},
							num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
				moveObjectsFromZoneToTile(movementParams)
				return -- drawing only a single card
			end			
		end
	end
	-- no effect if all slots are full
end

function sendTopBlackMarketCardFromDrawnZoneToPlayerHand(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(PLAYER_HAND_TILE_GUIDS[params.playerColor])
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'BLACK_MARKET'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopBlackMarketCardFromDrawnZoneToDiscardTile(params)
	local sourceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destinationTile = getObjectFromGUID(BLACK_MARKET_DISCARD_TILE_GUID)
	local movementParams = {from = sourceZone, to = destinationTile, types = {'Card', 'Deck'}, tags = {'BLACK_MARKET'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function toggleBlackMarketDrawnTile(params)
	local drawnTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local toggleState = getObjectMemoProperty(drawnTile, 'toggle_state')
	if toggleState == 'enabled' then
		setObjectMemoProperty(drawnTile, 'toggle_state', 'disabled')
	else -- toggleState == 'disabled' or toggleState == nil
		setObjectMemoProperty(drawnTile, 'toggle_state', 'enabled')
	end
	refreshBlackMarketDrawnSpaceColor(drawnTile)
end

-- helper
function refreshBlackMarketDrawnSpaceColor(drawnTile)
	local toggleState = getObjectMemoProperty(drawnTile, 'toggle_state')
	if toggleState == 'enabled' then
		drawnTile.setColorTint(BOARDSPACE_TILE_GREEN)
	else -- toggleState == 'disabled' or toggleState == nil
		drawnTile.setColorTint(BOARDSPACE_TILE_RED)
	end
end


-- *******************************************************
-- *** RUNNER CARD CUSTOMIZATION BUTTON PUSH FUNCTIONS ***
-- *******************************************************

function affixKarmaUpgradeToRunnerCardSlot1(params)
	affixKarmaUpgradeToRunnerCardSlotX(params, 1)
end
function affixKarmaUpgradeToRunnerCardSlot2(params)
	affixKarmaUpgradeToRunnerCardSlotX(params, 2)
end
function affixKarmaUpgradeToRunnerCardSlot3(params)
	affixKarmaUpgradeToRunnerCardSlotX(params, 3)
end
function affixKarmaUpgradeToRunnerCardSlot4(params)
	affixKarmaUpgradeToRunnerCardSlotX(params, 4)
end

-- helper
function affixKarmaUpgradeToRunnerCardSlotX(params, slotIndex)
	local karmaStickerZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local karmaStickerTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local karmaTags = getAllObjectTagsInZone(karmaStickerZone, {'Card'})
	local runnerUpgradeTile = getObjectFromGUID(RUNNER_UPGRADE_TILE_GUID)
	local runnerUpgradeBoardSpaceIndex = getBoardSpaceElementIndexByTileGUID(RUNNER_UPGRADE_TILE_GUID)
	local runnerUpgradeZone = getObjectFromGUID(BOARD_SPACES[runnerUpgradeBoardSpaceIndex].zoneGUID)
	local targetKarmaSticker = getObjectsByTypeAndTag(karmaStickerZone, {'Card'}, karmaTags)[1]
	local targetRunnerCard = getObjectsByTypeAndTag(runnerUpgradeZone, {'Card'}, {'Runner'})[1]
	if targetRunnerCard != nil then -- a single runner card was in the runner upgrade zone
		if targetKarmaSticker != nil then -- a single karma upgrade card was in the karma sticker zone
			local karmaCardRef = getCardRefByTagAndGUID(targetKarmaSticker.getTags()[1], targetKarmaSticker.guid)
			local partialName = 'decal_' .. slotIndex
			local posZCoord = -1.1 + ((slotIndex - 1) * 0.75)
			setObjectMemoProperty(targetRunnerCard, partialName .. '_name', partialName)
			setObjectMemoProperty(targetRunnerCard, partialName .. '_url', karmaCardRef.url)
			setObjectMemoProperty(targetRunnerCard, partialName .. '_posX', '0.805')
			setObjectMemoProperty(targetRunnerCard, partialName .. '_posY', '1')
			setObjectMemoProperty(targetRunnerCard, partialName .. '_posZ', tostring(posZCoord))
			setObjectMemoProperty(targetRunnerCard, partialName .. '_rotX', tostring(DECAL_FACE_UP_TOP_NORTH[1]))
			setObjectMemoProperty(targetRunnerCard, partialName .. '_rotY', tostring(DECAL_FACE_UP_TOP_NORTH[2]))
			setObjectMemoProperty(targetRunnerCard, partialName .. '_rotZ', tostring(DECAL_FACE_UP_TOP_NORTH[3]))
			setObjectMemoProperty(targetRunnerCard, partialName .. '_scaleX', '0.5')
			setObjectMemoProperty(targetRunnerCard, partialName .. '_scaleY', '0.5')
			setObjectMemoProperty(targetRunnerCard, partialName .. '_scaleZ', '0.8')
	
			redrawAllRunnerCardDecalsBasedOnMemo(targetRunnerCard)
		end
	end
end

-- helper
function redrawAllRunnerCardDecalsBasedOnMemo(runnerCard)
	local nonEmptyDecalSlots = {}
	local fullMemoObject = getObjectMemoAsTable(runnerCard)
	if fullMemoObject != nil then -- memo has been initialized
		for i = 1, 4 do
			local decalName = getObjectMemoProperty(runnerCard, 'decal_' .. i .. '_name')
			if decalName != nil then -- the card has a decal in this slot
				local partialName = 'decal_' .. i
				table.insert(nonEmptyDecalSlots, 
				{
					name = decalName,
					url = fullMemoObject[partialName .. '_url'],
					position =
					{
						fullMemoObject[partialName .. '_posX'],
						fullMemoObject[partialName .. '_posY'],
						fullMemoObject[partialName .. '_posZ'],
					},
					rotation =
					{
						fullMemoObject[partialName .. '_rotX'],
						fullMemoObject[partialName .. '_rotY'],
						fullMemoObject[partialName .. '_rotZ'],
					},
					scale =
					{
						fullMemoObject[partialName .. '_scaleX'],
						fullMemoObject[partialName .. '_scaleY'],
						fullMemoObject[partialName .. '_scaleZ'],
					}
				})				
			end
		end
	end
	runnerCard.setDecals(nonEmptyDecalSlots)
end

function clearKarmaUpgradeFromRunnerCardSlot1(params)
	clearKarmaUpgradeFromRunnerCardSlotX(params, 1)
end
function clearKarmaUpgradeFromRunnerCardSlot2(params)
	clearKarmaUpgradeFromRunnerCardSlotX(params, 2)
end
function clearKarmaUpgradeFromRunnerCardSlot3(params)
	clearKarmaUpgradeFromRunnerCardSlotX(params, 3)
end
function clearKarmaUpgradeFromRunnerCardSlot4(params)
	clearKarmaUpgradeFromRunnerCardSlotX(params, 4)
end

-- helper
function clearKarmaUpgradeFromRunnerCardSlotX(params, slotIndex)
	-- currently based on clicking the karma sticker tile, but this should maybe change
	local runnerUpgradeTile = getObjectFromGUID(RUNNER_UPGRADE_TILE_GUID)
	local runnerUpgradeBoardSpaceIndex = getBoardSpaceElementIndexByTileGUID(RUNNER_UPGRADE_TILE_GUID)
	local runnerUpgradeZone = getObjectFromGUID(BOARD_SPACES[runnerUpgradeBoardSpaceIndex].zoneGUID)
	local targetRunnerCard = getObjectsByTypeAndTag(runnerUpgradeZone, {'Card'}, {'Runner'})[1]
	if targetRunnerCard != nil then -- a single runner card was in the runner upgrade zone
		local partialName = 'decal_' .. slotIndex
		setObjectMemoProperty(targetRunnerCard, partialName .. '_name', '') -- this will be interpreted as no sticker
		redrawAllRunnerCardDecalsBasedOnMemo(targetRunnerCard)		
	end
end


-- **********************************
-- *** TOKEN BAGS/TILES FUNCTIONS ***
-- **********************************

function disposeOfSingleTile(params)
	deleteOneTile(params.hoverObject)
end

function disposeOfAllTilesInZone(params)
	local removalZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	deleteAllTilesInZone(removalZone)
end

function oneModNeg3TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_NEG_THREE')
end
function oneModNeg2TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_NEG_TWO')
end
function oneModNeg1TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_NEG_ONE')
end
function oneModPos1TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_POS_ONE')
end
function oneModPos2TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_POS_TWO')
end
function oneModPos3TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MOD_POS_THREE')
end
function oneNuyen1TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_NUYEN_ONE')
end
function oneNuyen3TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_NUYEN_THREE')
end
function oneNuyen5TileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_NUYEN_FIVE')
end

function oneHealthTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_HEALTH')
end
function oneMaxHealthTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_MAX_HEALTH')
end
function oneGenericRoundTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_GENERIC_ROUND')
end
function oneGenericSquareTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_GENERIC_SQUARE')
end
function oneExhaustedTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_EXHAUSTED')
end
function oneDamageTileToPlayer(params)
	sendSingleTokenToPlayerTileByBagTag(params, 'TILE_DAMAGE')
end

-- helper
function sendSingleTokenToPlayerTileByBagTag(params, tileBagTag)
	local sourceBag = getObjectFromGUID(TILE_BAG_GUIDS[tileBagTag])
	local destinationTile
	if params.boardSpaceRef.name == 'modifier_tokens' then -- calling while hovering over modifier tokens player boardspace
		destinationTile = getObjectFromGUID(PLAYER_MODIFIER_TOKENS_TILE_GUIDS[params.playerColor])
	elseif params.boardSpaceRef.name == 'nuyen_tokens' then -- calling while hovering over nuyen tokens player boardspace
		destinationTile = getObjectFromGUID(PLAYER_NUYEN_TOKENS_TILE_GUIDS[params.playerColor])
	elseif params.boardSpaceRef.name == 'various_tokens' then -- calling while hovering over various tokens player boardspace
		destinationTile = getObjectFromGUID(PLAYER_VARIOUS_TOKENS_TILE_GUIDS[params.playerColor])
	end
	local destPos = destinationTile.getPosition()
	local tileDecals = destinationTile.getDecals()
	for i = 1, #tileDecals do
		if tileDecals[i].name == tileBagTag then
			local tileScale = destinationTile.getScale()
			local xOffset = tileDecals[i].position.x * tileScale.x
			local zOffset = tileDecals[i].position.z * tileScale.z
			destPos.x = destPos.x + xOffset
			destPos.z = destPos.z + (zOffset * 2.15) -- not sure why these are necessary, but they are 
			break
		end
	end
	sourceBag.takeObject({position = {destPos.x, destPos.y + 1.25, destPos.z}, rotation = {180, 0 , 180}})
end

function sendSingleTokenToPlayerTileFromHoveredBag(params)
	local sourceBag = params.hoverObject
	local bagTag = sourceBag.getTags()[1]
	local destinationTile
	if bagTag == 'TILE_MOD_NEG_THREE' or bagTag == 'TILE_MOD_NEG_TWO' or bagTag == 'TILE_MOD_NEG_ONE'
				or bagTag == 'TILE_MOD_POS_ONE' or bagTag == 'TILE_MOD_POS_TWO' or bagTag == 'TILE_MOD_POS_THREE' then
		destinationTile = getObjectFromGUID(PLAYER_MODIFIER_TOKENS_TILE_GUIDS[params.playerColor])			
	elseif bagTag == 'TILE_NUYEN_ONE' or bagTag == 'TILE_NUYEN_THREE' or bagTag == 'TILE_NUYEN_FIVE' then
		destinationTile = getObjectFromGUID(PLAYER_NUYEN_TOKENS_TILE_GUIDS[params.playerColor])
	elseif bagTag == 'TILE_HEALTH' or bagTag == 'TILE_MAX_HEALTH' or bagTag == 'TILE_GENERIC_ROUND'
				or bagTag == 'TILE_GENERIC_SQUARE' or bagTag == 'TILE_EXHAUSTED' or bagTag == 'TILE_DAMAGE' then
		destinationTile = getObjectFromGUID(PLAYER_VARIOUS_TOKENS_TILE_GUIDS[params.playerColor])
	end
	local destPos = destinationTile.getPosition()
	local tileDecals = destinationTile.getDecals()
	for i = 1, #tileDecals do
		if tileDecals[i].name == bagTag then
			local tileScale = destinationTile.getScale()
			local xOffset = tileDecals[i].position.x * tileScale.x
			local zOffset = tileDecals[i].position.z * tileScale.z
			destPos.x = destPos.x + xOffset
			destPos.z = destPos.z + (zOffset * 2.15) -- not sure why these are necessary, but they are 
			break
		end
	end
	sourceBag.takeObject({position = {destPos.x, destPos.y + 1.25, destPos.z}, rotation = {180, 0 , 180}})
end

function removeAllTilesAssociatedWithHoveredBag(params)
	local sourceBag = params.hoverObject
	local bagTag = sourceBag.getTags()[1]
	local targetObjects = getObjectsByTypeAndTag(nil, {'Tile'}, {bagTag})
	if #targetObjects > 0 then
		print('clearing ' .. #targetObjects .. ' ' .. bagTag .. ' tiles/stacks')
		for i = 1, #targetObjects do
			targetObjects[i].destruct()
		end
	else
		print('found 0 ' .. bagTag .. ' tiles/stacks' )
	end
end


-- ************************************
-- *** PLAYER BOARDSPACES FUNCTIONS ***
-- ************************************

function spreadObstaclesInPlayerObstacleSpace(params)
	spreadCardsOverBoardSpaceTile(params.boardSpaceRef, {'NORMAL_OBSTACLE', 'HARD_OBSTACLE'})
end

function spreadPlayCardsInPlayerPlaySpace(params)
	spreadCardsOverBoardSpaceTile(params.boardSpaceRef, {'BLACK_MARKET', 'QUICK_SHOT', 'MARK', 'STREET_SMARTS', 'MANA'})
end

function sendHoveredObstacleCardOrDeckFromPlayerObstacleSpaceToObstacleDiscardTile(params)
    local destinationTile = nil
    local hoveredTags = params.hoverObject.getTags()
    if #hoveredTags == 1 then
        if hoveredTags[1] == 'HARD_OBSTACLE' then
            destinationTile = getObjectFromGUID(HARD_OBSTACLE_DISCARD_TILE_GUID)
        elseif hoveredTags[1] == 'NORMAL_OBSTACLE' then
            destinationTile = getObjectFromGUID(NORMAL_OBSTACLE_DISCARD_TILE_GUID)
        end
        if destinationTile != nil then
			local destinationPos = destinationTile.getPosition()
			destinationPos.y = destinationPos.y + 1.25
            params.hoverObject.setPositionSmooth(destinationPos, false, false)
            params.hoverObject.setRotationSmooth(FACE_UP_TOP_NORTH, false, false)
        end
    else
        -- *** NEED ADDITIONAL LOGIC HERE TO HANDLE THE POSSIBILITY OF A COMBINED DECK ***
    end
end

function sendHoveredCardFromPlayerHandZoneToPlayerDiscardTile(params)
    local destinationTile = getObjectFromGUID(PLAYER_DISCARD_TILE_GUIDS[params.playerColor])
	local destinationPos = destinationTile.getPosition()
	destinationPos.y = destinationPos.y + 1.25
	params.hoverObject.setPosition(destinationPos) -- can't be smooth because hands are sticky?
	params.hoverObject.setRotationSmooth(FACE_UP_TOP_NORTH, false, false)
end

function sendHoveredCardFromPlayerHandZoneToPlayerPlayTile(params)
    local destinationTile = getObjectFromGUID(PLAYER_PLAY_TILE_GUIDS[params.playerColor])
	local destinationPos = destinationTile.getPosition()
	destinationPos.y = destinationPos.y + 1.25
	params.hoverObject.setPosition(destinationPos) -- can't be smooth because hands are sticky?
	params.hoverObject.setRotationSmooth(FACE_UP_TOP_NORTH, false, false)
end

function sendTopPlayerDrawCardToPlayerHand(params)
	local drawZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local handTile = getObjectFromGUID(PLAYER_HAND_TILE_GUIDS[params.playerColor])
	local movementParams = {from = drawZone, to = handTile, types = {'Card', 'Deck'},
				tags = {'BLACK_MARKET', 'QUICK_SHOT', 'MARK', 'STREET_SMARTS', 'MANA'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendAllPlayerDiscardCardsAndDecksToPlayerDraw(params)
	local discardZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local drawTile = getObjectFromGUID(PLAYER_DRAW_TILE_GUIDS[params.playerColor])
	local movementParams = {from = discardZone, to = drawTile, types = {'Card', 'Deck'},
				tags = {'BLACK_MARKET', 'QUICK_SHOT', 'MARK', 'STREET_SMARTS', 'MANA'},
				num = -1, rotation = FACE_DOWN_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendTopPlayerDiscardCardToPlayerHand(params)
	local discardZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local handTile = getObjectFromGUID(PLAYER_HAND_TILE_GUIDS[params.playerColor])
	local movementParams = {from = discardZone, to = handTile, types = {'Card', 'Deck'},
				tags = {'BLACK_MARKET', 'QUICK_SHOT', 'MARK', 'STREET_SMARTS', 'MANA'},
				num = 1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

function sendHoveredCardFromPlayerPlaySpaceToPlayerHandTile(params)
    local destinationTile = getObjectFromGUID(PLAYER_HAND_TILE_GUIDS[params.playerColor])
	local destinationPos = destinationTile.getPosition()
	destinationPos.y = destinationPos.y + 1.25
	params.hoverObject.setPositionSmooth(destinationPos, false, false)
	params.hoverObject.setRotationSmooth(FACE_UP_TOP_NORTH, false, false)
end

function sendAllPlayCardsAndDecksInPlayerPlaySpaceToPlayerDiscard(params)
	local playSpaceZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local discardTile = getObjectFromGUID(PLAYER_DISCARD_TILE_GUIDS[params.playerColor])
	local movementParams = {from = playSpaceZone, to = discardTile, types = {'Card', 'Deck'},
				tags = {'BLACK_MARKET', 'QUICK_SHOT', 'MARK', 'STREET_SMARTS', 'MANA'},
				num = -1, rotation = FACE_UP_TOP_NORTH, fromTop = true, smoothMove = true}
	moveObjectsFromZoneToTile(movementParams)
end

-- *******************************
-- *** 	MISCELANEOUS FUNCTIONS ***
-- *******************************

--function cameraChange(params)
	--local runnerCardTile = getObjectFromGUID(PLAYER_RUNNERSPACE_TILE_GUIDS[params.playerColor])
	--local views = {}
	--table.insert(views, {position = runnerCardTile.getPosition(), pitch = 65, yaw = 0, distance = 20})
	--Player[params.playerColor].lookAt(views[1]) -- testing
--end

function changePlayerSeat(params)
	local targetTileGUID = params.boardSpaceRef.tileGUID
	local targetSeatColor
	if targetTileGUID == PLAYER_HAND_TILE_GUIDS.Green then
		targetSeatColor = 'Green'
	elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.Red then
		targetSeatColor = 'Red'
	elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.White then
		targetSeatColor = 'White'
	elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.Blue then
		targetSeatColor = 'Blue'
	end
	if params.playerColor != targetSeatColor then
		Player[params.playerColor].changeColor(targetSeatColor)	
	end
end

-- USEFULL WHEN CHANGING THE PARADIGM FOR WORKING WITH OBJECT MEMOS
-- function clearObjMemo(params)
	-- params.hoverObject.memo = ''
	-- print(params.hoverObject.type .. ' memo cleared !')
-- end

-- examples:

	-- function cameraChange(params)
		-- local runnerCardTile = getObjectFromGUID(PLAYER_RUNNERSPACE_TILE_GUIDS[params.playerColor])
		-- local views = {}
		-- table.insert(views, {position = runnerCardTile.getPosition(), pitch = 65, yaw = 0, distance = 20})
		-- Player[params.playerColor].lookAt(views[1])
	-- end

	-- function changePlayerSeat(params)
		-- local targetTileGUID = params.boardSpaceRef.tileGUID
		-- local targetSeatColor
		-- if targetTileGUID == PLAYER_HAND_TILE_GUIDS.Green then
			-- targetSeatColor = 'Green'
		-- elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.Red then
			-- targetSeatColor = 'Red'
		-- elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.White then
			-- targetSeatColor = 'White'
		-- elseif targetTileGUID == PLAYER_HAND_TILE_GUIDS.Blue then
			-- targetSeatColor = 'Blue'
		-- end
		-- if params.playerColor != targetSeatColor then
			-- Player[params.playerColor].changeColor(targetSeatColor)	
		-- end
	-- end