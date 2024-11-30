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

	-- pseudo shift key up, scripting button index 1
	-- example to assign the doStuffFunc() to scripting key one (no pseudoshift) when user hovers over a card within a 'boardHex' boardspace:
		-- addScriptingFunction(1, 1, 'doStuffFunc', 'does stuff', {Tile, BoardHexBS})
		
	-- pseudo shift key up, scripting button index 2

	-- pseudo shift key up, scripting button index 3

	-- pseudo shift key up, scripting button index 4

	-- pseudo shift key up, scripting button index 5

	-- pseudo shift key up, scripting button index 6

	-- pseudo shift key up, scripting button index 7

	-- pseudo shift key up, scripting button index 8

	-- pseudo shift key down, scripting button index 1

	-- pseudo shift key down, scripting button index 2

	-- pseudo shift key down, scripting button index 3

	-- pseudo shift key down, scripting button index 4

	-- pseudo shift key down, scripting button index 5

	-- pseudo shift key down, scripting button index 6

	-- pseudo shift key down, scripting button index 7

	-- pseudo shift key down, scripting button index 8

end


-- ***********************************
-- *** USER DEFINED ON EVENT TASKS ***
-- ***********************************

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

-- *** POPULATE BELOW ***