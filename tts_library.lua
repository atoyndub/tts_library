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

BOARD_HEX_GUIDS =
{
	{'5384ef','457828','914958','420c11','8afabd','7ed8ce','beebcc','639538','ef5d05','f603aa','f83c62','277c25','4a26ce'},
	{'b7d978','19bc2f','668a90','99672f','bf6803','ac1bc2','5dd667','b97cf8','0da17a','198310','21c249','192df7'},
	{'3ddedb','e0dc53','bc85cc','8c81fd','34c970','36d31d','5d50d9','0f4969','f102ca','a09ad6','905a50','9685da','ff0b9d'},
	{'29eabe','6facb3','11d303','f46631','2c14de','8ac5f6','83c197','82ea80','e9dfc2','6ee52e','6eefb5','842b5c'},
	{'ce40d6','36411f','4d3bcb','fff06b','c378bb','6e5d27','4ecca3','2fd580','0cdbb9','ad6bf4','f9f663','fc8935','86a9c9'},
	{'b0ae29','15b2f1','4204e5','978480','7cfc15','5c1782','fadc93','4d3996','6bb2fd','3ca387','acbbb8','f3e8e4'},
	{'35ca67','7ae10b','a2206b','d1c315','1905d4','60c5c7','347b09','aa771f','e08efa','bb0509','476bcb','7d5a8c','270a34'},
	{'15948f','07e6e3','9aed06','651029','886279','d03305','ab441b','f7270b','c6add0','eb1600','67f2ec','cca510'},
	{'470d7e','afc6b0','b4f5c3','4cbd53','babbab','7a055d','e225ff','3c9665','20a7fc','cee5eb','5698de','247ba8','420ccb'},
}

BAG_GUIDS =
{
	BARBARIAN_LIGHT_INFANTRY = 'c96663', BARBARIAN_LIGHT_BOW_INFANTRY = '50c0fc', BARBARIAN_LIGHT_SLING_INFANTRY = '243e57',
	BARBARIAN_AUXILIA_INFANTRY = 'c9a23e', BARBARIAN_MEDIUM_INFANTRY = '1bdcea', BARBARIAN_WARRIOR_INFANTRY = 'dcb1d5',
	BARBARIAN_LIGHT_CAVALRY = '660a11', BARBARIAN_MEDIUM_CAVALRY = '8d463c', BARBARIAN_HEAVY_CAVALRY = '380937',
	BARBARIAN_LIGHT_CHARIOTS = 'efa21f', BARBARIAN_LEADER = 'afdd17', BARBARIAN_VICTORY_BANNER = 'd1deab',

	SPARTAN_LIGHT_INFANTRY = '0faacd', SPARTAN_LIGHT_BOW_INFANTRY = 'ab9a77', SPARTAN_LIGHT_SLING_INFANTRY = 'eea4a7',
	SPARTAN_AUXILIA_INFANTRY = '188f79', SPARTAN_MEDIUM_INFANTRY = 'dc2a39', SPARTAN_WARRIOR_INFANTRY = '57e815',
	SPARTAN_HEAVY_INFANTRY = '353004', SPARTAN_ALLIED_HOPLITE_INFANTRY = '42f6bb', SPARTAN_HOPLITE_INFANTRY = 'ae9b5e',
	SPARTAN_LIGHT_CAVALRY = '16d6d3', SPARTAN_MEDIUM_CAVALRY = '771580', SPARTAN_LEADER = '5652e3', SPARTAN_VICTORY_BANNER = '31254f',

	CARTHAGINIAN_LIGHT_INFANTRY = 'd59f45', CARTHAGINIAN_LIGHT_BOW_INFANTRY = '8e5358', CARTHAGINIAN_LIGHT_SLING_INFANTRY = '2bc1b8',
	CARTHAGINIAN_AUXILIA_INFANTRY = '60fc17', CARTHAGINIAN_MEDIUM_INFANTRY = 'd8cc0b', CARTHAGINIAN_WARRIOR_INFANTRY = '72fdaf',
	CARTHAGINIAN_HEAVY_INFANTRY = '329c22', CARTHAGINIAN_LIGHT_CAVALRY = 'cd9cd6', CARTHAGINIAN_MEDIUM_CAVALRY = '6ca950',
	CARTHAGINIAN_HEAVY_CAVALRY = '08dceb', CARTHAGINIAN_CHARIOTS = '64f9e4', CARTHAGINIAN_ELEPHANTS = '646f70',
	CARTHAGINIAN_LEADER = 'c4bf90', CARTHAGINIAN_VICTORY_BANNER = '180e4d',

	ROMAN_I_LIGHT_INFANTRY = '29d865', ROMAN_I_LIGHT_BOW_INFANTRY = '9c7502', ROMAN_I_LIGHT_SLING_INFANTRY = '8f6f26',
	ROMAN_I_AUXILIA_INFANTRY = '0b7982', ROMAN_I_MEDIUM_INFANTRY = 'f1411d', ROMAN_I_WARRIOR_INFANTRY = '19575c',
	ROMAN_I_HEAVY_INFANTRY = '4d476e', ROMAN_I_LIGHT_BOW_CAVALRY = 'bd4b5d', ROMAN_I_LIGHT_CAVALRY = 'faf0da',
	ROMAN_I_MEDIUM_CAVALRY = '55fd78', ROMAN_I_HEAVY_CAVALRY = 'beff92', ROMAN_I_HEAVY_CATAPHRACT_CAVALRY = '83fb27',
	ROMAN_I_LEADER = '2e80de', ROMAN_I_VICTORY_BANNER = '0bc8a5',

	ROMAN_II_LIGHT_INFANTRY = '541652', ROMAN_II_LIGHT_BOW_INFANTRY = 'e76962', ROMAN_II_LIGHT_SLING_INFANTRY = '0e3ad4',
	ROMAN_II_AUXILIA_INFANTRY = 'e0d06c', ROMAN_II_MEDIUM_INFANTRY = '953c12', ROMAN_II_WARRIOR_INFANTRY = '112d6d',
	ROMAN_II_HEAVY_INFANTRY = 'b0d7c9', ROMAN_II_WAR_MACHINES = 'a6141a', ROMAN_II_LIGHT_CAVALRY = '571bdd',
	ROMAN_II_MEDIUM_CAVALRY = 'd2de72', ROMAN_II_HEAVY_CAVALRY = '88790e', ROMAN_II_ELEPHANTS = '9c5ae9',
	ROMAN_II_CAESAR = '8b9b8b', ROMAN_II_LEADER = 'e632e3', ROMAN_II_VICTORY_BANNER = 'ae14c8',

	ROMAN_III_LIGHT_INFANTRY = 'b22de1', ROMAN_III_LIGHT_BOW_INFANTRY = 'f7a827', ROMAN_III_LIGHT_SLING_INFANTRY = 'b14aec',
	ROMAN_III_AUXILIA_INFANTRY = '07baf6', ROMAN_III_MEDIUM_INFANTRY = 'a414c6', ROMAN_III_WARRIOR_INFANTRY = '71e3c1',
	ROMAN_III_HEAVY_INFANTRY = 'a37024', ROMAN_III_WAR_MACHINES = 'efa9af', ROMAN_III_LIGHT_CAVALRY = '9f149e',
	ROMAN_III_MEDIUM_CAVALRY = '1ee765', ROMAN_III_HEAVY_CAVALRY = 'ff9021', ROMAN_III_CHARIOTS = '3521e4',
	ROMAN_III_ELEPHANTS = '8b70c9', ROMAN_III_LEADER = '190005', ROMAN_III_VICTORY_BANNER = 'a56aba',

}

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
			tag = 'PLAY',
			cards =
			{
				{guid = 'e57644', name = 'order two units right'},
				{guid = '341917', name = 'order light troops'},
				{guid = 'f558f8', name = 'inspired left leadership'},
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
			--	tag = 'EXAMPLE'} -- tag is the tag that will be assigned to this bag and any/all of its spawn
		-- }
	
		-- *** POPULATE BELOW ***

		-- barbarian bags
		{guid = BAG_GUIDS.BARBARIAN_LIGHT_INFANTRY, tag = 'BARBARIAN_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_LIGHT_BOW_INFANTRY, tag = 'BARBARIAN_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_LIGHT_SLING_INFANTRY, tag = 'BARBARIAN_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_AUXILIA_INFANTRY, tag = 'BARBARIAN_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_MEDIUM_INFANTRY, tag = 'BARBARIAN_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_WARRIOR_INFANTRY, tag = 'BARBARIAN_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.BARBARIAN_LIGHT_CAVALRY, tag = 'BARBARIAN_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.BARBARIAN_MEDIUM_CAVALRY, tag = 'BARBARIAN_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.BARBARIAN_HEAVY_CAVALRY, tag = 'BARBARIAN_HEAVY_CAVALRY'},
		{guid = BAG_GUIDS.BARBARIAN_LIGHT_CHARIOTS, tag = 'BARBARIAN_LIGHT_CHARIOTS'},
		{guid = BAG_GUIDS.BARBARIAN_LEADER, tag = 'BARBARIAN_LEADER'},
		{guid = BAG_GUIDS.BARBARIAN_VICTORY_BANNER, tag = 'BARBARIAN_VICTORY_BANNER'},

		-- spartan bags
		{guid = BAG_GUIDS.SPARTAN_LIGHT_INFANTRY, tag = 'SPARTAN_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_LIGHT_BOW_INFANTRY, tag = 'SPARTAN_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_LIGHT_SLING_INFANTRY, tag = 'SPARTAN_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_AUXILIA_INFANTRY, tag = 'SPARTAN_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_MEDIUM_INFANTRY, tag = 'SPARTAN_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_WARRIOR_INFANTRY, tag = 'SPARTAN_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_HEAVY_INFANTRY, tag = 'SPARTAN_HEAVY_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_ALLIED_HOPLITE_INFANTRY, tag = 'SPARTAN_ALLIED_HOPLITE_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_HOPLITE_INFANTRY, tag = 'SPARTAN_HOPLITE_INFANTRY'},
		{guid = BAG_GUIDS.SPARTAN_LIGHT_CAVALRY, tag = 'SPARTAN_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.SPARTAN_MEDIUM_CAVALRY, tag = 'SPARTAN_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.SPARTAN_LEADER, tag = 'SPARTAN_LEADER'},
		{guid = BAG_GUIDS.SPARTAN_VICTORY_BANNER, tag = 'SPARTAN_VICTORY_BANNER'},

		-- carthaginian bags
		{guid = BAG_GUIDS.CARTHAGINIAN_LIGHT_INFANTRY, tag = 'CARTHAGINIAN_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_LIGHT_BOW_INFANTRY, tag = 'CARTHAGINIAN_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_LIGHT_SLING_INFANTRY, tag = 'CARTHAGINIAN_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_AUXILIA_INFANTRY, tag = 'CARTHAGINIAN_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_MEDIUM_INFANTRY, tag = 'CARTHAGINIAN_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_WARRIOR_INFANTRY, tag = 'CARTHAGINIAN_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_HEAVY_INFANTRY, tag = 'CARTHAGINIAN_HEAVY_INFANTRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_LIGHT_CAVALRY, tag = 'CARTHAGINIAN_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_MEDIUM_CAVALRY, tag = 'CARTHAGINIAN_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_HEAVY_CAVALRY, tag = 'CARTHAGINIAN_HEAVY_CAVALRY'},
		{guid = BAG_GUIDS.CARTHAGINIAN_CHARIOTS, tag = 'CARTHAGINIAN_CHARIOTS'},
		{guid = BAG_GUIDS.CARTHAGINIAN_ELEPHANTS, tag = 'CARTHAGINIAN_ELEPHANTS'},
		{guid = BAG_GUIDS.CARTHAGINIAN_LEADER, tag = 'CARTHAGINIAN_LEADER'},
		{guid = BAG_GUIDS.CARTHAGINIAN_VICTORY_BANNER, tag = 'CARTHAGINIAN_VICTORY_BANNER'},

		-- roman i bags
		{guid = BAG_GUIDS.ROMAN_I_LIGHT_INFANTRY, tag = 'ROMAN_I_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_LIGHT_BOW_INFANTRY, tag = 'ROMAN_I_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_LIGHT_SLING_INFANTRY, tag = 'ROMAN_I_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_AUXILIA_INFANTRY, tag = 'ROMAN_I_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_MEDIUM_INFANTRY, tag = 'ROMAN_I_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_WARRIOR_INFANTRY, tag = 'ROMAN_I_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_HEAVY_INFANTRY, tag = 'ROMAN_I_HEAVY_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_I_LIGHT_BOW_CAVALRY, tag = 'ROMAN_I_LIGHT_BOW_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_I_LIGHT_CAVALRY, tag = 'ROMAN_I_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_I_MEDIUM_CAVALRY, tag = 'ROMAN_I_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_I_HEAVY_CAVALRY, tag = 'ROMAN_I_HEAVY_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_I_HEAVY_CATAPHRACT_CAVALRY, tag = 'ROMAN_I_HEAVY_CATAPHRACT_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_I_LEADER, tag = 'ROMAN_I_LEADER'},
		{guid = BAG_GUIDS.ROMAN_I_VICTORY_BANNER, tag = 'ROMAN_I_VICTORY_BANNER'},

		-- roman ii bags
		{guid = BAG_GUIDS.ROMAN_II_LIGHT_INFANTRY, tag = 'ROMAN_II_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_LIGHT_BOW_INFANTRY, tag = 'ROMAN_II_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_LIGHT_SLING_INFANTRY, tag = 'ROMAN_II_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_AUXILIA_INFANTRY, tag = 'ROMAN_II_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_MEDIUM_INFANTRY, tag = 'ROMAN_II_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_WARRIOR_INFANTRY, tag = 'ROMAN_II_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_HEAVY_INFANTRY, tag = 'ROMAN_II_HEAVY_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_II_WAR_MACHINES, tag = 'ROMAN_II_WAR_MACHINES'},
		{guid = BAG_GUIDS.ROMAN_II_LIGHT_CAVALRY, tag = 'ROMAN_II_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_II_MEDIUM_CAVALRY, tag = 'ROMAN_II_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_II_HEAVY_CAVALRY, tag = 'ROMAN_II_HEAVY_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_II_ELEPHANTS, tag = 'ROMAN_II_ELEPHANTS'},
		{guid = BAG_GUIDS.ROMAN_II_CAESAR, tag = 'ROMAN_II_CAESAR'},
		{guid = BAG_GUIDS.ROMAN_II_LEADER, tag = 'ROMAN_II_LEADER'},
		{guid = BAG_GUIDS.ROMAN_II_VICTORY_BANNER, tag = 'ROMAN_II_VICTORY_BANNER'},

		-- roman iii bags
		{guid = BAG_GUIDS.ROMAN_III_LIGHT_INFANTRY, tag = 'ROMAN_III_LIGHT_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_LIGHT_BOW_INFANTRY, tag = 'ROMAN_III_LIGHT_BOW_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_LIGHT_SLING_INFANTRY, tag = 'ROMAN_III_LIGHT_SLING_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_AUXILIA_INFANTRY, tag = 'ROMAN_III_AUXILIA_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_MEDIUM_INFANTRY, tag = 'ROMAN_III_MEDIUM_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_WARRIOR_INFANTRY, tag = 'ROMAN_III_WARRIOR_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_HEAVY_INFANTRY, tag = 'ROMAN_III_HEAVY_INFANTRY'},
		{guid = BAG_GUIDS.ROMAN_III_WAR_MACHINES, tag = 'ROMAN_III_WAR_MACHINES'},
		{guid = BAG_GUIDS.ROMAN_III_LIGHT_CAVALRY, tag = 'ROMAN_III_LIGHT_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_III_MEDIUM_CAVALRY, tag = 'ROMAN_III_MEDIUM_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_III_HEAVY_CAVALRY, tag = 'ROMAN_III_HEAVY_CAVALRY'},
		{guid = BAG_GUIDS.ROMAN_III_CHARIOTS, tag = 'ROMAN_III_CHARIOTS'},
		{guid = BAG_GUIDS.ROMAN_III_ELEPHANTS, tag = 'ROMAN_III_ELEPHANTS'},
		{guid = BAG_GUIDS.ROMAN_III_LEADER, tag = 'ROMAN_III_LEADER'},
		{guid = BAG_GUIDS.ROMAN_III_VICTORY_BANNER, tag = 'ROMAN_III_VICTORY_BANNER'},

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

	-- *** POPULATE BELOW ***
	
	BOARD_SPACES =
	{
		-- board hexes
		{tileGUID = BOARD_HEX_GUIDS[1][1], zoneGUID = 'd682e2', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[1][2], zoneGUID = 'a9a6af', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[1][3], zoneGUID = '082b3b', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[1][4], zoneGUID = '87a6ab', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[1][5], zoneGUID = '064b61', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[1][6], zoneGUID = 'af88e9', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[1][7], zoneGUID = 'f4a279', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[1][8], zoneGUID = '596ea6', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[1][9], zoneGUID = '5434a5', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[1][10], zoneGUID = 'f4124d', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[1][11], zoneGUID = '991275', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[1][12], zoneGUID = '860659', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 12},
		{tileGUID = BOARD_HEX_GUIDS[1][13], zoneGUID = 'de21ab', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 1, hexCoordY = 13},

		{tileGUID = BOARD_HEX_GUIDS[2][1], zoneGUID = '73fe0f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[2][2], zoneGUID = '11f8bf', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[2][3], zoneGUID = '31e37a', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[2][4], zoneGUID = '9f9eb4', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[2][5], zoneGUID = '94a06d', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[2][6], zoneGUID = 'd2413c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[2][7], zoneGUID = '68d069', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[2][8], zoneGUID = '90aa09', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[2][9], zoneGUID = '3a9588', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[2][10], zoneGUID = '2ff865', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[2][11], zoneGUID = '6b9c61', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[2][12], zoneGUID = 'bf7173', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 2, hexCoordY = 12},

		{tileGUID = BOARD_HEX_GUIDS[3][1], zoneGUID = 'f9e8bb', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[3][2], zoneGUID = '191b5f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[3][3], zoneGUID = 'a6586e', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[3][4], zoneGUID = '5851e2', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[3][5], zoneGUID = 'e8d6c1', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[3][6], zoneGUID = 'aeece5', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[3][7], zoneGUID = 'b631e1', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[3][8], zoneGUID = '23e069', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[3][9], zoneGUID = 'bd7309', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[3][10], zoneGUID = '5149af', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[3][11], zoneGUID = 'b09eeb', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[3][12], zoneGUID = '8da889', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 12},
		{tileGUID = BOARD_HEX_GUIDS[3][13], zoneGUID = 'a028d2', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 3, hexCoordY = 13},

		{tileGUID = BOARD_HEX_GUIDS[4][1], zoneGUID = 'c2b98f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[4][2], zoneGUID = '249310', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[4][3], zoneGUID = '49a436', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[4][4], zoneGUID = 'df3f19', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[4][5], zoneGUID = 'd7efab', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[4][6], zoneGUID = 'f83282', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[4][7], zoneGUID = '71e11c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[4][8], zoneGUID = '042f50', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[4][9], zoneGUID = 'abf79c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[4][10], zoneGUID = 'c64160', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[4][11], zoneGUID = 'a0184b', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[4][12], zoneGUID = '543878', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 4, hexCoordY = 12},

		{tileGUID = BOARD_HEX_GUIDS[5][1], zoneGUID = 'bd3ca7', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[5][2], zoneGUID = 'a3fb46', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[5][3], zoneGUID = '85a5ce', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[5][4], zoneGUID = '93c84c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[5][5], zoneGUID = '259f2c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[5][6], zoneGUID = 'd2fbd6', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[5][7], zoneGUID = 'ae57dd', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[5][8], zoneGUID = '5b165f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[5][9], zoneGUID = 'f51a09', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[5][10], zoneGUID = 'e4ff5c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[5][11], zoneGUID = 'e41b7f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[5][12], zoneGUID = '96f9be', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 12},
		{tileGUID = BOARD_HEX_GUIDS[5][13], zoneGUID = 'febcf8', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 5, hexCoordY = 13},

		{tileGUID = BOARD_HEX_GUIDS[6][1], zoneGUID = '3e8ee5', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[6][2], zoneGUID = 'acf9ca', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[6][3], zoneGUID = '9eea05', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[6][4], zoneGUID = '84c920', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[6][5], zoneGUID = 'd14278', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[6][6], zoneGUID = 'e42a6f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[6][7], zoneGUID = 'ee238f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[6][8], zoneGUID = 'af4d98', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[6][9], zoneGUID = '9dda32', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[6][10], zoneGUID = '80307c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[6][11], zoneGUID = 'bd45a9', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[6][12], zoneGUID = '4eba72', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 6, hexCoordY = 12},

		{tileGUID = BOARD_HEX_GUIDS[7][1], zoneGUID = '62dca3', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[7][2], zoneGUID = 'd8fa3c', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[7][3], zoneGUID = '46e378', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[7][4], zoneGUID = '1723f1', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[7][5], zoneGUID = '4a7732', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[7][6], zoneGUID = '15907e', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[7][7], zoneGUID = 'e82508', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[7][8], zoneGUID = '4fad76', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[7][9], zoneGUID = '3bff74', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[7][10], zoneGUID = 'e6c07a', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[7][11], zoneGUID = 'd37ea7', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[7][12], zoneGUID = '9af9a4', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 12},
		{tileGUID = BOARD_HEX_GUIDS[7][13], zoneGUID = 'db33c0', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 7, hexCoordY = 13},

		{tileGUID = BOARD_HEX_GUIDS[8][1], zoneGUID = '75b441', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[8][2], zoneGUID = '09ce13', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[8][3], zoneGUID = '41fa92', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[8][4], zoneGUID = 'abbf35', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[8][5], zoneGUID = 'bf0763', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[8][6], zoneGUID = 'a9d260', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[8][7], zoneGUID = '0aec2e', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[8][8], zoneGUID = '01f6fa', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[8][9], zoneGUID = 'e0b900', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[8][10], zoneGUID = '3025e5', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[8][11], zoneGUID = '138173', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[8][12], zoneGUID = '7b8ccf', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 8, hexCoordY = 12},

		{tileGUID = BOARD_HEX_GUIDS[9][1], zoneGUID = '399687', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 1},
		{tileGUID = BOARD_HEX_GUIDS[9][2], zoneGUID = 'b3570f', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 2},
		{tileGUID = BOARD_HEX_GUIDS[9][3], zoneGUID = 'c8893d', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 3},
		{tileGUID = BOARD_HEX_GUIDS[9][4], zoneGUID = 'b01513', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 4},
		{tileGUID = BOARD_HEX_GUIDS[9][5], zoneGUID = '075590', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 5},
		{tileGUID = BOARD_HEX_GUIDS[9][6], zoneGUID = '551585', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 6},
		{tileGUID = BOARD_HEX_GUIDS[9][7], zoneGUID = '6af5dc', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 7},
		{tileGUID = BOARD_HEX_GUIDS[9][8], zoneGUID = '62c420', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 8},
		{tileGUID = BOARD_HEX_GUIDS[9][9], zoneGUID = '102395', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 9},
		{tileGUID = BOARD_HEX_GUIDS[9][10], zoneGUID = '27e400', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 10},
		{tileGUID = BOARD_HEX_GUIDS[9][11], zoneGUID = 'ae68f8', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 11},
		{tileGUID = BOARD_HEX_GUIDS[9][12], zoneGUID = '90858e', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 12},
		{tileGUID = BOARD_HEX_GUIDS[9][13], zoneGUID = '5cd479', name = 'boardHex', associatedTags = {}, playerOwners = {}, hexCoordX = 9, hexCoordY = 13},
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

	-- commonly use prerequisites
	local Infinite = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Infinite'}}}
	local Figurine = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Figurine'}}}
	local TileSet = {functionName = 'meetsPrereqs_HoverObjectTypePermitted', addedContext = {typesPermitted = {'Tileset'}}}
	local BoardHexBS = {functionName = 'meetsPrereqs_BoardSpaceNamePermitted', addedContext = {namesPermitted = {'boardHex'}}}
	local UIShown = {functionName = 'meetsPrereqs_UIElementIsDisplayed', addedContext = {uiElementID = 'enlarged_tileset_image'}}
	local UIHidden = {functionName = 'meetsPrereqs_UIElementIsNotDisplayed', addedContext = {uiElementID = 'enlarged_tileset_image'}}

	-- pseudo shift key up, scripting button index 1
	addScriptingFunction(1, 1, 'playerToggleBagSelection', 'toggle bag to active/innactive', {Infinite})
	addScriptingFunction(1, 1, 'moveUnitsLeft', 'move units one hex left', {BoardHexBS})

	-- pseudo shift key up, scripting button index 2
	addScriptingFunction(1, 2, 'moveUnitsForwardLeft', 'move units one hex forward left', {BoardHexBS})

	-- pseudo shift key up, scripting button index 3
	addScriptingFunction(1, 3, 'moveUnitsForwardRight', 'move units one hex forward right', {BoardHexBS})

	-- pseudo shift key up, scripting button index 4
	addScriptingFunction(1, 4, 'moveUnitsRight', 'move units one hex right', {BoardHexBS})

	-- pseudo shift key up, scripting button index 5
	addScriptingFunction(1, 5, 'toggleHexTileColor', 'toggle hex color', {BoardHexBS})

	-- pseudo shift key down, scripting button index 1
	addScriptingFunction(2, 1, 'sendSingleFigurineToBoardHex', 'send player-selected figurine to board hex', {BoardHexBS})

	-- pseudo shift key down, scripting button index 2
	addScriptingFunction(2, 2, 'moveUnitsBackwardLeft', 'move units one hex backward left', {BoardHexBS})

	-- pseudo shift key down, scripting button index 3
	addScriptingFunction(2, 3, 'moveUnitsBackwardRight', 'move units one hex backward right', {BoardHexBS})

	-- pseudo shift key down, scripting button index 4
	addScriptingFunction(2, 4, 'displayEnlargedTilesetImage', 'print custom object info', {TileSet, UIHidden})
	addScriptingFunction(2, 4, 'hideEnlargedTilesetImage', 'hide custom object info', {UIShown})

	-- pseudo shift key down, scripting button index 5
	addScriptingFunction(2, 5, 'disposeOfSingleTile', 'remove tile', {Figurine})
end


-- **********************************
-- *** USER DEFINED ON LOAD TASKS ***
-- **********************************

function userDefinedOnLoadTasks()
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON STARTUP ***

end

function userDefinedOnObjectEnterContainerTasks(container, object)
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON OBJECT ENTER CONTAINER ***

end

function userDefinedOnObjectLeaveContainerTasks(container, object)
	-- *** POPULATE BELOW WITH ANY USER-DEFINED TASKS WHICH NEED TO BE COMPLETED ON OBJECT LEAVE CONTAINER ***

end


-- **************************************
-- *** SCRIPTING FUNCTION DEFINITIONS ***
-- **************************************

-- *** THESE ARE THE FUNCTIONS REFERRED TO IN THE SCRIPTING_FUNCTIONS 2-DIMENSIONAL ARRAY
-- *** WRITE ANY AND ALL FUNCTIONS HERE AS NEEDED

-- *** POPULATE BELOW ***


-- **********************************
-- *** TOKEN BAGS/TILES FUNCTIONS ***
-- **********************************

function playerToggleBagSelection(params)
	for i = 1, #INFINITE_BAGS do
		local currentBag = getObjectFromGUID(INFINITE_BAGS[i].guid)
		local bagHolder = getObjectMemoProperty(currentBag, 'heldByPlayer')
		local newBagColor = nil
		if bagHolder == nil then -- this bag not currently selected
			if params.hoverObject == currentBag then -- bag to be toggled
				setObjectMemoProperty(currentBag, 'heldByPlayer', params.playerColor)
				newBagColor = params.playerColor
			end
		elseif bagHolder == params.playerColor then -- this bag is marked as selected by this player
			setObjectMemoProperty(currentBag, 'heldByPlayer', '')
			newBagColor = INNACTIVE_BAG_GREY
		-- else -- bag previously selected by another player
			-- do nothing
		end
		if newBagColor != nil then
			currentBag.setColorTint(newBagColor)
		end
	end
end

function sendSingleFigurineToBoardHex(params)
	local selectedBag = nil
	for i = 1, #INFINITE_BAGS do
		local currentBag = getObjectFromGUID(INFINITE_BAGS[i].guid)
		local bagHolder = getObjectMemoProperty(currentBag, 'heldByPlayer')
		if bagHolder == params.playerColor then
			selectedBag = currentBag
			break
		end
	end
	if selectedBag == nil then
		return -- no selected bag from which to get figurines
	end
	local hexTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local hexZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local destPos = rearrangeFigurinesOnBoardHexToMakeRoomForAnother(hexTile, hexZone)
	if destPos != nil then
		selectedBag.takeObject({position = destPos, rotation = {180, 0 , 180}})
	end
end

-- helper, makes space for and returns position to send a new figurine on a board hex
function rearrangeFigurinesOnBoardHexToMakeRoomForAnother(hexTile, hexZone)
	local containedFigurines  = getObjectsByTypeInZone(hexZone, {'Figurine'})
	local returnPos = nil
	if #containedFigurines < 5 then
		local center = hexTile.getBounds().center
		if #containedFigurines == 0 then
			returnPos = {center.x, center.y + 1.25, center.z}		
		elseif #containedFigurines == 1 then
			containedFigurines[1].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z}, false, false)
			returnPos = {center.x + 1.25, center.y + 1.25, center.z}
		elseif #containedFigurines == 2 then
			containedFigurines[1].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z - 0.75}, false, false)
			containedFigurines[2].setPositionSmooth({center.x + 1.25, center.y + 1.25, center.z - 0.75}, false, false)		
			returnPos = {center.x, center.y + 1.25, center.z + 0.75}
		elseif #containedFigurines == 3 then
			containedFigurines[1].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z - 0.75}, false, false)
			containedFigurines[2].setPositionSmooth({center.x + 1.25, center.y + 1.25, center.z - 0.75}, false, false)
			containedFigurines[3].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z + 0.75}, false, false)
			returnPos = {center.x + 1.25, center.y + 1.25, center.z + 0.75}
		else -- #containedFigurines == 4 then
			containedFigurines[1].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z - 1}, false, false)
			containedFigurines[2].setPositionSmooth({center.x + 1.25, center.y + 1.25, center.z - 1}, false, false)
			containedFigurines[3].setPositionSmooth({center.x - 1.25, center.y + 1.25, center.z + 1}, false, false)
			containedFigurines[4].setPositionSmooth({center.x + 1.25, center.y + 1.25, center.z + 1}, false, false)
			returnPos = {center.x, center.y + 1.25, center.z}	
		end
		for i = 1, #containedFigurines do
			containedFigurines[i].setRotationSmooth(FACE_UP_TOP_NORTH, false, false)
		end
	end
	return returnPos
end

function disposeOfSingleTile(params)
	deleteOneTile(params.hoverObject)
end

function disposeOfAllTilesInZone(params)
	local removalZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	deleteAllTilesInZone(removalZone)
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

function moveUnitsLeft(params)
	moveUnits(params, nil, 'left')
end

function moveUnitsForwardLeft(params)
	moveUnits(params, 'forward', 'left')
end

function moveUnitsBackwardLeft(params)
	moveUnits(params, 'backward', 'left')
end

function moveUnitsRight(params)
	moveUnits(params, nil, 'right')
end

function moveUnitsForwardRight(params)
	moveUnits(params, 'forward', 'right')
end

function moveUnitsBackwardRight(params)
	moveUnits(params, 'backward', 'right')
end

-- helper
function moveUnits(params, anteriorDirection, lateralDirection)
	local originHexTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local destinationHexTile = getUnitMovementDestinationHex(params, anteriorDirection, lateralDirection)
	if destinationHexTile == nil then
		destinationHexTile = originHexTile -- movement would be out of range
	end
	local originCenter = originHexTile.getBounds().center
	local destinationCenter = destinationHexTile.getBounds().center
	local originZone = getObjectFromGUID(params.boardSpaceRef.zoneGUID)
	local figurinesToMove = getObjectsByTypeInZone(originZone, {'Figurine'})
	for i = 1, #figurinesToMove do
		local figurePos = figurinesToMove[i].getPosition()
		figurinesToMove[i].setPositionSmooth({destinationCenter.x + figurePos.x - originCenter.x,
			destinationCenter.y + 1.25, destinationCenter.z + figurePos.z - originCenter.z,}, false, false)
	end
end

-- helper
function getUnitMovementDestinationHex(params, anteriorDirection, lateralDirection)
	local curHexX = params.boardSpaceRef.hexCoordX
	local curHexY = params.boardSpaceRef.hexCoordY
	local c = params.playerColor
	local anteriorHexChange
	local lateralHexChange
	if anteriorDirection == nil then
		anteriorHexChange = 0
		if (c == 'Red' or c == 'Brown' or c == 'White') then
			if lateralDirection == 'left' then
				lateralHexChange = -1
			else -- lateralDirection == 'right'
				lateralHexChange = 1
			end
		elseif (c == 'Green' or c == 'Teal' or c == 'Blue') then
			if lateralDirection == 'left' then
				lateralHexChange = 1
			else -- lateralDirection == 'right'
				lateralHexChange = -1
			end
		end
	else -- anteriorDirection == 'forward' or anteriorDirection == 'backward'
		lateralHexChange = 0
		if (c == 'Red' or c == 'Brown' or c == 'White') then
			if lateralDirection == 'left' and curHexX % 2 == 1 then
				lateralHexChange = -1
			elseif lateralDirection == 'right' and curHexX % 2 == 0 then
				lateralHexChange = 1
			end
			if anteriorDirection == 'forward' then
				anteriorHexChange = -1
			else -- anteriorDirection == 'backward'
				anteriorHexChange = 1
			end
		elseif (c == 'Green' or c == 'Teal' or c == 'Blue') then
			if lateralDirection == 'right' and curHexX % 2 == 1 then
				lateralHexChange = -1
			elseif lateralDirection == 'left' and curHexX % 2 == 0 then
				lateralHexChange = 1
			end
			if anteriorDirection == 'forward' then
				anteriorHexChange = 1
			else -- anteriorDirection == 'backward'
				anteriorHexChange = -1
			end
		end
	end
	local destHexX = curHexX + anteriorHexChange
	local destHexY = curHexY + lateralHexChange
	if destHexX >= 1 and destHexX <= 9 then
		if destHexY >= 1 and destHexY <= (12 + (destHexX % 2)) then
			return getObjectFromGUID(BOARD_HEX_GUIDS[destHexX][destHexY])
		end
	end
	return nil
end

function toggleHexTileColor(params)
	local targetHexTile = getObjectFromGUID(params.boardSpaceRef.tileGUID)
	local hexToggledVal = getObjectMemoProperty(targetHexTile, 'toggledVal')
	if hexToggledVal == params.playerColor then
		setObjectMemoProperty(targetHexTile, 'toggledVal', 'none')
		targetHexTile.setColorTint(Color(0, 0, 0, 0.15625))
	else -- untoggled or toggled by another player
		local playerColorObj = Color.fromString(params.playerColor)
		local newTileColor = Color(playerColorObj.r, playerColorObj.g, playerColorObj.b, 0.35)
		setObjectMemoProperty(targetHexTile, 'toggledVal', params.playerColor)
		targetHexTile.setColorTint(newTileColor)
	end
end

function displayEnlargedTilesetImage(params)
	local customObjInfo = params.hoverObject.getCustomObject()
	local imageURL = customObjInfo.image -- this property represents the image url for tileset
	if imageURL != nil then
		local newElement =
		{
			tag = 'Image',
			attributes =
			{
				height = 900,
				width = 1200,
				image = imageURL,
				preserveAspect = true,
			},
		}
		setGlobalUIElement('enlarged_tileset_image', newElement, params.playerColor, {imageURL})
	end
end

function hideEnlargedTilesetImage(params)
	removeGlobalUIElement('enlarged_tileset_image', params.playerColor)
end











function shuffleDeck(params)
	local deck = params.hoverObject
	deck.shuffle()
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