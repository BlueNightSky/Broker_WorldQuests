--[[----
--
-- Broker_WorldQuests
--
-- World of Warcraft addon to display Legion world quests in convenient list form.
-- Doesn't do anything on its own; requires a data broker addon!
--
-- Author: myno
--
--]]----

local ITEM_QUALITY_COLORS, WORLD_QUEST_QUALITY_COLORS = ITEM_QUALITY_COLORS, WORLD_QUEST_QUALITY_COLORS
local GetQuestsForPlayerByMapID = C_TaskQuest.GetQuestsForPlayerByMapID
local GetQuestTimeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes
local GetQuestTagInfo = GetQuestTagInfo
local GetQuestInfoByQuestID = C_TaskQuest.GetQuestInfoByQuestID
local GetFactionInfoByID = GetFactionInfoByID
local GetQuestObjectiveInfo = GetQuestObjectiveInfo
local GetQuestProgressBarInfo = C_TaskQuest.GetQuestProgressBarInfo
local UnitLevel, IsQuestFlaggedCompleted = UnitLevel, IsQuestFlaggedCompleted
local GetCurrentMapAreaID, GetCurrentMapContinent, GetCurrentMapDungeonLevel = GetCurrentMapAreaID, GetCurrentMapContinent, GetCurrentMapDungeonLevel
local GetNumQuestLogRewards, GetQuestLogRewardInfo, GetQuestLogRewardMoney = GetNumQuestLogRewards, GetQuestLogRewardInfo, GetQuestLogRewardMoney
local GetNumQuestLogRewardCurrencies, GetQuestLogRewardCurrencyInfo = GetNumQuestLogRewardCurrencies, GetQuestLogRewardCurrencyInfo

local WORLD_QUEST_ICONS_BY_TAG_ID = {
	[114] = "worldquest-icon-firstaid",
	[116] = "worldquest-icon-blacksmithing",
	[117] = "worldquest-icon-leatherworking",
	[118] = "worldquest-icon-alchemy",
	[119] = "worldquest-icon-herbalism",
	[120] = "worldquest-icon-mining",
	[122] = "worldquest-icon-engineering",
	[123] = "worldquest-icon-enchanting",
	[125] = "worldquest-icon-jewelcrafting",
	[126] = "worldquest-icon-inscription",
	[129] = "worldquest-icon-archaeology",
	[130] = "worldquest-icon-fishing",
	[131] = "worldquest-icon-cooking",
	[121] = "worldquest-icon-tailoring",
	[124] = "worldquest-icon-skinning",
	[137] = "worldquest-icon-dungeon",
	[113] = "worldquest-icon-pvp-ffa",
	[115] = "worldquest-icon-petbattle",
	[111] = "worldquest-questmarker-dragon",
	[112] = "worldquest-questmarker-dragon",
	[136] = "worldquest-questmarker-dragon",
}

local MAP_ZONES = {
	[1015] = { id = 1015, name = GetMapNameByID(1015), quests = {}, buttons = {}, glows = {}, },  -- Aszuna
	[1096] = { id = 1096, name = GetMapNameByID(1096), quests = {}, buttons = {}, glows = {}, },  -- Eye of Azshara
	[1018] = { id = 1018, name = GetMapNameByID(1018), quests = {}, buttons = {}, glows = {}, },  -- Val'sharah
	[1024] = { id = 1024, name = GetMapNameByID(1024), quests = {}, buttons = {}, glows = {}, },  -- Highmountain
	[1017] = { id = 1017, name = GetMapNameByID(1017), quests = {}, buttons = {}, glows = {}, },  -- Stormheim
	[1033] = { id = 1033, name = GetMapNameByID(1033), quests = {}, buttons = {}, glows = {}, },  -- Suramar
	[1014] = { id = 1014, name = GetMapNameByID(1014), quests = {}, buttons = {}, glows = {}, },  -- Dalaran
}
local MAP_ZONES_SORT = {
	1015, 1096, 1018, 1024, 1017, 1033, 1014
}
local SORT_ORDER = {
	ARTIFACTPOWER = 1,
	RELIC = 2,
	EQUIP = 3,
	ITEM = 4,
	PROFESSION = 5,
	RESOURCES = 6,
	MONEY = 7,
}

local ARTIFACTPOWER_SPELL_NAME = select(1, GetSpellInfo(228111))
local FAMILY_FAMILIAR_QUEST_IDS = { -- WQ pet battle achievement
	[42442] = true, -- Fight Night: Amalia
	[40299] = true, -- Fight Night: Bodhi Sunwayver
	[40298] = true, -- Fight Night: Sir Galveston
	[40277] = true, -- Fight Night: Tiffany Nelson
	[42159] = true, -- Training with the Nightwatchers
	[41860] = true, -- Dealing with Satyrs
	[40279] = true, -- Training with Durian
	[40280] = true, -- Training with Bredda
	[41687] = true, -- Snail Fight!
	[40282] = true, -- Tiny Poacher, Tiny Animals
	[40278] = true, -- My Beasts's Bidding
	[41944] = true, -- Jarrun's Ladder
	[41895] = true, -- The Master of Pets
	[40337] = true, -- Flummoxed
	[41990] = true, -- Chopped
}

local defaultConfig = {
	-- general
	attachToWorldMap = false,
	showOnClick = false,
	alwaysShowBountyQuests = true,
	alwaysShowEpicQuests = true,
	-- reward type
	showArtifactPower = true,
	showItems = true,
		showGear = true,
		showRelics = true,
		showCraftingMaterials = true,
		showOtherItems = true,
	showLowGold = true,
	showHighGold = true,
	showResources = true,
		showOrderHallResources = true,
		showAncientMana = true,
		showOtherResources = true,
	-- quest type
	showProfession = true,
		showProfessionAlchemy = true,
		showProfessionBlacksmithing = true,
		showProfessionInscription = true,
		showProfessionJewelcrafting = true,
		showProfessionLeatherworking = true,
		showProfessionTailoring = true,
		showProfessionEnchanting = true,
		showProfessionEngineering = true,
		showProfessionHerbalism = true,
		showProfessionMining = true,
		showProfessionSkinning = true,
		showProfessionCooking = true,
		showProfessionArchaeology = true,
		showProfessionFirstAid = true,
		showProfessionFishing = true,
	showDungeon = true,
	showPvP = true,
	alwaysShowCourtOfFarondis = false,
	alwaysShowDreamweavers = false,
	alwaysShowHighmountainTribe = false,
	alwaysShowNightfallen = false,
	alwaysShowWardens = false,
	alwaysShowValarjar = false,
	showPetBattle = true,
	hidePetBattleBountyQuests = false,
	alwaysShowPetBattleFamilyFamiliar = true,
}

local BWQ = CreateFrame("Frame", "Broker_WorldQuests", UIParent)
BWQ:EnableMouse(true)
BWQ:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
		tile = false,
		tileSize = 0,
		edgeSize = 2,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
BWQ:SetBackdropColor(0, 0, 0, .9)
BWQ:SetBackdropBorderColor(0, 0, 0, 1)
BWQ:SetClampedToScreen(true)
BWQ:Hide()


local Block_OnLeave = function(self)
	if not BWQcfg.attachToWorldMap or (BWQcfg.attachToWorldMap and not WorldMapFrame:IsShown()) then
		if not BWQ:IsMouseOver() then
			BWQ:Hide()
		end
	end
end
BWQ:SetScript("OnLeave", Block_OnLeave)

BWQ.slider = CreateFrame("Slider", nil, BWQ)
BWQ.slider:SetWidth(16)
BWQ.slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
BWQ.slider:SetBackdrop( {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	--edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	edgeSize = 8, tile = true, tileSize = 8,
	insets = { left=3, right=3, top=6, bottom=6 }
} )
BWQ.slider:SetValueStep(1)

BWQ.slider:SetHeight(200)
BWQ.slider:SetMinMaxValues( 0, 100 )
BWQ.slider:SetValue(0)
BWQ.slider:Hide()


local bounties = {}
local questIds = {}
local numQuestsTotal, totalWidth, offsetTop = 0, 0, -15
local showDownwards = false
local blockYPos = 0
local highlightedRow = true

local CreateBountyBoardFS = function()
	BWQ.bountyBoardFS = BWQ:CreateFontString("BWQbountyBoardFS", "OVERLAY", "SystemFont_Shadow_Med1")
	BWQ.bountyBoardFS:SetJustifyH("CENTER")
	BWQ.bountyBoardFS:SetTextColor(0.95, 0.95, 0.95)
	BWQ.bountyBoardFS:SetPoint("TOP", BWQ, "TOP", 0, offsetTop)
end

local CreateErrorFS = function()
	BWQ.errorFS = BWQ:CreateFontString("BWQerrorFS", "OVERLAY", "SystemFont_Shadow_Med1")
	BWQ.errorFS:SetJustifyH("CENTER")
	BWQ.errorFS:SetTextColor(.9, .8, 0)
end

local hasUnlockedWorldQuests
function BWQ:WorldQuestsUnlocked()
	if not hasUnlockedWorldQuests then
		hasUnlockedWorldQuests = (UnitLevel("player") == 110 and IsQuestFlaggedCompleted(43341)) -- http://wowhead.com/quest=43341
	end

	if not hasUnlockedWorldQuests then
		if BWQcfg.attachToWorldMap and WorldMapFrame:IsShown() then -- don't show error box on map
			BWQ:Hide()
			return false
		end
		if not BWQ.errorFS then CreateErrorFS() end

		BWQ.errorFS:SetPoint("TOP", BWQ, "TOP", 0, -10)
		BWQ.errorFS:SetText("You need to reach Level 110 and complete the\nquest \124cffffff00\124Hquest:43341:-1\124h[Uniting the Isles]\124h\124r to unlock World Quests.")
		BWQ:SetSize(BWQ.errorFS:GetStringWidth() + 20, BWQ.errorFS:GetStringHeight() + 20)
		BWQ.errorFS:Show()

		return false
	else
		if BWQ.errorFS then
			BWQ.errorFS:Hide()
		end

		return true
	end
end

function BWQ:ShowNoWorldQuestsInfo()
	if not BWQ.errorFS then CreateErrorFS() end

	BWQ.errorFS:ClearAllPoints()
	BWQ.errorFS:SetPoint("TOP", BWQ, "TOP", 0, offsetTop - 10)

	BWQ.errorFS:SetText("There are no world quests available that match your filter settings.")
	BWQ.errorFS:Show()
end


local ArtifactPowerScanTooltip = CreateFrame ("GameTooltip", "ArtifactPowerScanTooltip", nil, "GameTooltipTemplate")
function BWQ:GetArtifactPowerValue(itemId)
	local _, itemLink = GetItemInfo(itemId)
	ArtifactPowerScanTooltip:SetOwner (BWQ, "ANCHOR_NONE")
	ArtifactPowerScanTooltip:SetHyperlink (itemLink)
	return _G["ArtifactPowerScanTooltipTextLeft4"]:GetText():gsub("%p", ""):match("%d+") or ""
end

local FormatTimeLeftString = function(timeLeft)
	local timeLeftStr = ""
	-- if timeLeft >= 60 * 24 then -- at least 1 day
	-- 	timeLeftStr = string.format("%.0fd", timeLeft / 60 / 24)
	-- end
	if timeLeft >= 60 then -- hours
		timeLeftStr = string.format("%.0fh", math.floor(timeLeft / 60))
	end
	timeLeftStr = string.format("%s%s%sm", timeLeftStr, timeLeftStr ~= "" and " " or "", timeLeft % 60) -- always show minutes

	if 		timeLeft <= 120 then timeLeftStr = string.format("|cffD96932%s|r", timeLeftStr)
	elseif 	timeLeft <= 240 then timeLeftStr = string.format("|cffDBA43B%s|r", timeLeftStr)
	elseif 	timeLeft <= 480 then timeLeftStr = string.format("|cffE6D253%s|r", timeLeftStr)
	elseif 	timeLeft <= 960 then timeLeftStr = string.format("|cffE6DA8E%s|r", timeLeftStr)
	end
	return timeLeftStr
end


local tip = GameTooltip
local ShowQuestObjectiveTooltip = function(row)
	tip:SetOwner(row, "ANCHOR_CURSOR")
	local color = WORLD_QUEST_QUALITY_COLORS[row.quest.isRare]
	tip:AddLine(row.quest.title, color.r, color.g, color.b, true)

	for objectiveIndex = 1, row.quest.numObjectives do
		local objectiveText, objectiveType, finished = GetQuestObjectiveInfo(row.quest.questId, objectiveIndex, false);
		if objectiveText and #objectiveText > 0 then
			color = finished and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR;
			tip:AddLine(QUEST_DASH .. objectiveText, color.r, color.g, color.b, true);
		end
	end

	local percent = GetQuestProgressBarInfo(row.quest.questId);
	if percent then
		GameTooltip_InsertFrame(GameTooltip, WorldMapTaskTooltipStatusBar);
		WorldMapTaskTooltipStatusBar.Bar:SetValue(percent);
		WorldMapTaskTooltipStatusBar.Bar.Label:SetFormattedText(PERCENTAGE_STRING, percent);
	end

	tip:Show()
end

local ShowQuestLogItemTooltip = function(button)
	local name, texture = GetQuestLogRewardInfo(1, button.quest.questId)
	if name and texture then
		tip:SetOwner(button.reward, "ANCHOR_CURSOR")
		tip:SetQuestLogItem("reward", 1, button.quest.questId)
		tip:Show()
	end
end


-- super track map ping
local mapTextures = CreateFrame("Frame", "BWQ_MapTextures", WorldMapButton)
mapTextures:SetSize(64, 64)
mapTextures:SetFrameStrata("DIALOG")
mapTextures:SetFrameLevel(2001)
local highlightArrow = mapTextures:CreateTexture("highlightArrow")
highlightArrow:SetTexture("Interface\\minimap\\MiniMap-DeadArrow")
highlightArrow:SetSize(56, 56)
highlightArrow:SetRotation(3.14)
highlightArrow:SetPoint("CENTER", mapTextures)
highlightArrow:SetDrawLayer("ARTWORK", 1)
mapTextures.highlightArrow = highlightArrow
local animationGroup = mapTextures:CreateAnimationGroup()
animationGroup:SetLooping("REPEAT")
animationGroup:SetScript("OnPlay", function(self)
	mapTextures.highlightArrow:Show()
end)
animationGroup:SetScript("OnStop", function(self)
	mapTextures.highlightArrow:Hide()
end)
local downAnimation = animationGroup:CreateAnimation("Translation")
downAnimation:SetChildKey("highlightArrow")
downAnimation:SetOffset(0, -10)
downAnimation:SetDuration(0.4)
downAnimation:SetOrder(1)
local upAnimation = animationGroup:CreateAnimation("Translation")
upAnimation:SetChildKey("highlightArrow")
upAnimation:SetOffset(0, 10)
upAnimation:SetDuration(0.4)
upAnimation:SetOrder(2)
mapTextures.animationGroup = animationGroup
BWQ.mapTextures = mapTextures


function BWQ:QueryZoneQuestCoordinates(mapId)
	if mapId == GetCurrentMapAreaID() then
		local quests = GetQuestsForPlayerByMapID(mapId)
		for _, v in next, quests do
			if MAP_ZONES[mapId].quests[v.questId] then
				MAP_ZONES[mapId].quests[v.questId].x = v.x
				MAP_ZONES[mapId].quests[v.questId].y = v.y
			end
		end
	end
end

function BWQ:CalculateMapPosition(x, y)
	return x * WorldMapPlayersFrame:GetWidth(), -1 * y * WorldMapPlayersFrame:GetHeight()
end

function BWQ:CreateWatchGlow()
	local texture = BWQ.mapTextures:CreateTexture("glowTexture")
	texture:SetAtlas("worldquest-questmarker-glow", true);
	texture:SetSize(48, 48)
	texture:SetDesaturated(1)
	texture:SetBlendMode("ADD")
	texture:SetDrawLayer("BORDER", -1)
	texture:SetVertexColor(1, 1, 1, 0.9)

	return texture
end

function BWQ:UpdateWatchGlows(mapId)
	if not MAP_ZONES[mapId] or not MAP_ZONES[mapId].questsSort then return end

	for _, questId in next, MAP_ZONES[mapId].questsSort do
		if IsWorldQuestHardWatched(questId) then
			BWQ:AddWatchGlow(mapId, questId)
			BWQ:ShowWatchGlow(mapId, questId)
		else
			BWQ:HideWatchGlow(mapId, questId)
		end
	end
end

function BWQ:ShowAllWatchGlows(mapId)
	if not MAP_ZONES[mapId] then return end

	for questId, glow in next, MAP_ZONES[mapId].glows do
		if glow.active then
			BWQ:ShowWatchGlow(mapId, questId)
		end
	end
end

function BWQ:ShowWatchGlow(mapId, questId)
	if not MAP_ZONES[mapId] or not MAP_ZONES[mapId].glows then return end

	MAP_ZONES[mapId].glows[questId].active = true
	local glow = MAP_ZONES[mapId].glows[questId]
	local quest = MAP_ZONES[mapId].quests[questId]
	if not quest.x or not quest.y then
		BWQ:QueryZoneQuestCoordinates(mapId)
	end
	quest = MAP_ZONES[mapId].quests[questId]

	if quest.x and quest.y then
		local x, y = BWQ:CalculateMapPosition(quest.x, quest.y)
		glow.texture:ClearAllPoints()
		glow.texture:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x, y)
		glow.texture:Show()
	end
end

function BWQ:AddWatchGlow(mapId, questId)
	if not MAP_ZONES[mapId] then return end

	local glow = MAP_ZONES[mapId].glows[questId] or {}
	if not glow.texture then
		glow.texture = BWQ:CreateWatchGlow()
	end
	MAP_ZONES[mapId].glows[questId] = glow
end

function BWQ:HideAllWatchGlows(mapId)
	if not MAP_ZONES[mapId] then return end

	for questId in next, MAP_ZONES[mapId].glows do
		BWQ:HideWatchGlow(mapId, questId)
	end
end

function BWQ:HideWatchGlow(mapId, questId)
	if not MAP_ZONES[mapId] then return end

	if MAP_ZONES[mapId].glows[questId] then
		MAP_ZONES[mapId].glows[questId].texture:Hide()
		MAP_ZONES[mapId].glows[questId].active = false
	end
end

function BWQ:DisableWatchGlow(mapId, questId)
	if not MAP_ZONES[mapId] then return end

	if MAP_ZONES[mapId].glows[questId] then
		MAP_ZONES[mapId].glows[questId].active = false
		MAP_ZONES[mapId].glows[questId].texture:Hide()
	end
end

local Row_OnClick = function(row)
	if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
	if not InCombatLockdown() then SetMapByID(row.mapId) end

	if IsShiftKeyDown() then
		if IsWorldQuestHardWatched(row.quest.questId) or (IsWorldQuestWatched(row.quest.questId) and GetSuperTrackedQuestID() == row.quest.questId) then
			BonusObjectiveTracker_UntrackWorldQuest(row.quest.questId)
		else
			BonusObjectiveTracker_TrackWorldQuest(row.quest.questId, true)
		end
	else
		if not row.quest.x or not row.quest.y then BWQ:QueryZoneQuestCoordinates(row.mapId) end
		local x, y = BWQ:CalculateMapPosition(row.quest.x, row.quest.y)
		BWQ.mapTextures:ClearAllPoints()
		BWQ.mapTextures:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x, y + 25)
  		BWQ.mapTextures.animationGroup:Play()
	end
end


local lastUpdate, updateTries = 0, 0
local needsRefresh = false
local RetrieveWorldQuests = function(mapId)

	local numQuests
	local currentTime = GetTime()
	local questList = GetQuestsForPlayerByMapID(mapId)

	-- quest object fields are: x, y, floor, numObjectives, questId, inProgress
	if questList and (#questList > 0 or not MAP_ZONES[mapId].questsSort) then
		numQuests = 0
		MAP_ZONES[mapId].questsSort = {}

		local timeLeft, tagId, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex, title, factionId
		for i = 1, #questList do
			--[[
			local tagID, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex = GetQuestTagInfo(v);

			tagId = 116
			tagName = Blacksmithing World Quest
			worldQuestType =
				2 -> profession,
				3 -> pve?
				4 -> pvp
				5 -> battle pet
				7 -> dungeon
			isRare =
				1 -> normal
				2 -> rare
				3 -> epic
			isElite = true/false
			tradeskillLineIndex = some number, no idea of meaning atm
			]]

			timeLeft = GetQuestTimeLeftMinutes(questList[i].questId)
			if timeLeft > 0 then -- only show available quests
				tagId, tagName, worldQuestType, isRare, isElite, tradeskillLineIndex = GetQuestTagInfo(questList[i].questId);
				if worldQuestType ~= nil then
					local questId = questList[i].questId
					table.insert(MAP_ZONES[mapId].questsSort, questId)
					local quest = MAP_ZONES[mapId].quests[questId] or {}

					if not quest.timeAdded then
						quest.wasSaved = questIds[questId] ~= nil
					end
					quest.timeAdded = quest.timeAdded or currentTime
					if quest.wasSaved or currentTime - quest.timeAdded > 900 then
						quest.isNew = false
					else
						quest.isNew = true
					end

					quest.hide = true
					quest.sort = 0

					-- GetQuestsForPlayerByMapID fields
					quest.questId = questId
					quest.numObjectives = questList[i].numObjectives
					quest.xFlight = questList[i].x
					quest.yFlight = questList[i].y

					-- GetQuestTagInfo fields
					quest.tagId = tagId
					quest.tagName = tagName
					quest.worldQuestType = worldQuestType
					quest.isRare = isRare
					quest.isElite = isElite
					quest.tradeskillLineIndex = tradeskillLineIndex

					title, factionId = GetQuestInfoByQuestID(quest.questId)
					quest.title = title
					if factionId then
						quest.faction = GetFactionInfoByID(factionId)
					end
					quest.timeLeft = timeLeft
					quest.bounties = {}

					quest.reward = {}
					-- item reward
					local hasReward = false
					if GetNumQuestLogRewards(quest.questId) > 0 then
						local itemName, itemTexture, quantity, quality, isUsable, itemId = GetQuestLogRewardInfo(1, quest.questId)
						if itemName then
							hasReward = true
							quest.reward.itemTexture = itemTexture
							quest.reward.itemId = itemId
							quest.reward.itemQuality = quality
							quest.reward.itemQuantity = quantity

							local itemSpell = GetItemSpell(quest.reward.itemId)
							local _, itemLink, _, _, _, class, subClass, _, equipSlot, _, _ = GetItemInfo(quest.reward.itemId)
							quest.reward.itemLink = itemLink
							if itemSpell and ARTIFACTPOWER_SPELL_NAME and itemSpell == ARTIFACTPOWER_SPELL_NAME then
								quest.reward.artifactPower = BWQ:GetArtifactPowerValue(quest.reward.itemId)
								quest.sort = SORT_ORDER.ARTIFACTPOWER
								if BWQcfg.showArtifactPower then quest.hide = false end
							else
								quest.reward.itemName = itemName

								if BWQcfg.showItems then
									if class == "Tradeskill" then
										quest.sort = SORT_ORDER.PROFESSION
										if BWQcfg.showCraftingMaterials then quest.hide = false end
									elseif equipSlot ~= "" then
										quest.sort = SORT_ORDER.EQUIP
										if BWQcfg.showGear then quest.hide = false end
									elseif subClass == "Artifact Relic" then
										quest.sort = SORT_ORDER.RELIC
										if BWQcfg.showRelics then quest.hide = false end
									else
										quest.sort = SORT_ORDER.ITEM
										if BWQcfg.showOtherItems then quest.hide = false end
									end
								end
							end
						end
					end
					-- gold reward
					local money = GetQuestLogRewardMoney(quest.questId);
					if money > 0 then
						hasReward = true
						quest.reward.money = money
						quest.sort = SORT_ORDER.MONEY

						if money < 1000000 then
							if BWQcfg.showLowGold then quest.hide = false end
						else
							if BWQcfg.showHighGold then quest.hide = false end
						end
					end
					-- currency reward
					local numQuestCurrencies = GetNumQuestLogRewardCurrencies(quest.questId)
					for i = 1, numQuestCurrencies do

						local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, quest.questId)
						if name then
							hasReward = true
							quest.reward.resourceName = name
							quest.reward.resourceTexture = texture
							quest.reward.resourceAmount = numItems
							quest.sort = SORT_ORDER.RESOURCES

							if BWQcfg.showResources then
								if name == "Ancient Mana" then
									if BWQcfg.showAncientMana then quest.hide = false end
								elseif name == "Order Resources" then
									if BWQcfg.showOrderHallResources then quest.hide = false end
								else
									if BWQcfg.showOtherResources then quest.hide = false end
								end
							end
						end
					end

					if not hasReward then needsRefresh = true end -- quests always have a reward, if not api returned bad data

					for _, bounty in ipairs(bounties) do
						if IsQuestCriteriaForBounty(quest.questId, bounty.questID) then
							quest.bounties[#quest.bounties + 1] = bounty.icon
						end
					end

					-- quest type filters
					if quest.worldQuestType == 5 then
						if BWQcfg.showPetBattle or (BWQcfg.alwaysShowPetBattleFamilyFamiliar and FAMILY_FAMILIAR_QUEST_IDS[quest.questId] ~= nil) then
							quest.hide = false
						else
							quest.hide = true
						end
					elseif quest.worldQuestType == 2 then
						if BWQcfg.showProfession then

							if     quest.tagId == 118 then 	if BWQcfg.showProfessionAlchemy 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 129 then	if BWQcfg.showProfessionArchaeology 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 116 then 	if BWQcfg.showProfessionBlacksmithing 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 131 then 	if BWQcfg.showProfessionCooking 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 123 then 	if BWQcfg.showProfessionEnchanting 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 122 then 	if BWQcfg.showProfessionEngineering 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 114 then 	if BWQcfg.showProfessionFirstAid 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 130 then 	if BWQcfg.showProfessionFishing 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 119 then 	if BWQcfg.showProfessionHerbalism 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 126 then 	if BWQcfg.showProfessionInscription 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 125 then 	if BWQcfg.showProfessionJewelcrafting 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 117 then 	if BWQcfg.showProfessionLeatherworking 	then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 120 then 	if BWQcfg.showProfessionMining 			then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 124 then 	if BWQcfg.showProfessionSkinning 		then quest.hide = false else quest.hide = true end
							elseif quest.tagId == 121 then 	if BWQcfg.showProfessionTailoring 		then quest.hide = false else quest.hide = true end
							end
						else
							quest.hide = true
						end
					elseif not BWQcfg.showPvP and quest.worldQuestType == 4 then quest.hide = true
					elseif not BWQcfg.showDungeon and quest.worldQuestType == 7 then quest.hide = true
					end
					-- always show bounty quests or reputation for faction filter
					if (BWQcfg.alwaysShowBountyQuests and #quest.bounties > 0) or
					   (BWQcfg.alwaysShowCourtOfFarondis 	and (mapId == 1015 or mapId == 1096)) or
					   (BWQcfg.alwaysShowDreamweavers 		and mapId == 1018) or
					   (BWQcfg.alwaysShowHighmountainTribe 	and mapId == 1024) or
					   (BWQcfg.alwaysShowNightfallen 		and mapId == 1033) or
					   (BWQcfg.alwaysShowWardens 			and quest.faction == "The Wardens") or
					   (BWQcfg.alwaysShowValarjar 			and mapId == 1017) then

						-- pet battle override
						if BWQcfg.hidePetBattleBountyQuests and not BWQcfg.showPetBattle and quest.worldQuestType == 5 then
							quest.hide = true
						else
							quest.hide = false
						end
					end
					-- don't filter epic quests based on setting
					if BWQcfg.alwaysShowEpicQuests and quest.isRare == 3 then quest.hide = false end

					MAP_ZONES[mapId].quests[questId] = quest

					if not quest.hide then
						numQuests = numQuests + 1
					end
				end
			end
		end

		table.sort(MAP_ZONES[mapId].questsSort, function(a, b) return MAP_ZONES[mapId].quests[a].sort < MAP_ZONES[mapId].quests[b].sort end)

		if numQuests == nil then numQuests = 0 end
		MAP_ZONES[mapId].numQuests = numQuests
	end
end


function BWQ:UpdateBountyData()
	bounties = GetQuestBountyInfoForMapID(1014) -- zone id doesn't matter
	local bountyBoardText = ""
	for bountyIndex, bounty in ipairs(bounties) do
		local questIndex = GetQuestLogIndexByID(bounty.questID);
		local title = GetQuestLogTitle(questIndex);
		local _, _, finished, numFulfilled, numRequired = GetQuestObjectiveInfo(bounty.questID, 1, false)

		if bounty.icon and title then
			bountyBoardText = string.format("%s|T%s$s:20:20|t %s   %d/%d", bountyBoardText, bounty.icon, title, numFulfilled or 0, numRequired or 0)
			if bountyIndex < #bounties then
				bountyBoardText = string.format("%s        ", bountyBoardText)
			end
		end
	end

	if not BWQ.bountyBoardFS then CreateBountyBoardFS(offsetTop) end
	if #bounties > 0 then
		BWQ.bountyBoardFS:Show()
		BWQ.bountyBoardFS:SetText(bountyBoardText)
		offsetTop = offsetTop - 25
	else
		BWQ.bountyBoardFS:Hide()
	end
end

local originalMap, originalContinent, originalDungeonLevel
function BWQ:UpdateQuestData()
	questIds = BWQcache.questIds or {}

	if not InCombatLockdown() then
		local _, _, _, isMicroDungeon, _ = GetMapInfo()
		if not isMicroDungeon then
			originalMap = GetCurrentMapAreaID()
			originalContinent = GetCurrentMapContinent()
			originalDungeonLevel = GetCurrentMapDungeonLevel()
		end

		SetMapByID(1007) -- Broken Isles map, able to query all world quests on it
		for mapId in next, MAP_ZONES do
			if mapId ~= 1014 then
				RetrieveWorldQuests(mapId)
			end
		end
		-- we need to do Dalaran separately
		SetMapByID(1014)
		RetrieveWorldQuests(1014)

		-- set map back to the original map from before updating
		if not isMicroDungeon then
			-- setting the maelstrom continent map via SetMapByID would make it non-interactive
			if originalMap == 751 then
				SetMapZoom(WORLDMAP_MAELSTROM_ID)
			elseif originalMap == -1 then
				SetMapZoom(originalContinent)
			else
				SetMapByID(originalMap)
				if originalDungeonLevel ~= 0 then
					SetDungeonMapLevel(originalDungeonLevel)
				end
			end
		else
			SetMapToCurrentZone()
		end
	else
		local mapId = GetCurrentMapAreaID()
		if MAP_ZONES[mapId] ~= nil then
			RetrieveWorldQuests(mapId)
		end
	end

	numQuestsTotal = 0
	for mapId in next, MAP_ZONES do
		numQuestsTotal = numQuestsTotal + MAP_ZONES[mapId].numQuests
	end

	-- save quests to saved vars to check new status after reload/relog
	if numQuestsTotal ~= 0 then
		questIds = {}
		for mapId in next, MAP_ZONES do
			for _, questId in next, MAP_ZONES[mapId].questsSort do
				questIds[questId] = true
			end
		end
		BWQcache.questIds = questIds
	end

	if needsRefresh and updateTries <= 5 then
		needsRefresh = false
		updateTries = updateTries + 1
		C_Timer.After(1, function() BWQ:UpdateBlock() end)
	end
end

function BWQ:RenderRows()
	local screenHeight = UIParent:GetHeight()
	local availableHeight = 0
	if showDownwards then availableHeight = screenHeight - (screenHeight - blockYPos) - 30
	else availableHeight = screenHeight - blockYPos - 30 end

	local ROW_HEIGHT = -16
	local maxEntries = math.floor((availableHeight + offsetTop - 10) / ( -1 * ROW_HEIGHT ))

	local numEntries = numQuestsTotal
	for mapId in next, MAP_ZONES do
		if MAP_ZONES[mapId].numQuests ~= 0 then
			numEntries = numEntries + 1
		end
	end

	if maxEntries >= numEntries then
		BWQ.slider:Hide()
		maxEntries = numEntries - 1
		BWQ.slider:SetMinMaxValues(0, numEntries - 1 - maxEntries)
	else
		BWQ.slider:Show()
		BWQ.slider:SetPoint("TOPRIGHT", BWQ, "TOPRIGHT", -5, offsetTop)
		BWQ.slider:SetHeight((ROW_HEIGHT * -1) * (maxEntries + 1))
		BWQ.slider:SetMinMaxValues(0, numEntries - 1 - maxEntries)
	end


	-- all quests filtered or all done (haha.)
	if numQuestsTotal == 0 then
		BWQ:ShowNoWorldQuestsInfo()
		BWQ:SetHeight((offsetTop * -1) + 10 + 30)
	else
		if BWQ.errorFS then BWQ.errorFS:Hide() end
		BWQ:SetHeight((offsetTop * -1) + 10 + (ROW_HEIGHT * -1) * (maxEntries + 1))
	end

	local sliderval = math.floor(BWQ.slider:GetValue())
	local rowIndex = 0
	local rowInViewIndex = 0
	for _, mapId in next, MAP_ZONES_SORT do
		if MAP_ZONES[mapId].numQuests == 0 or rowIndex < sliderval or rowIndex > sliderval + maxEntries then

			MAP_ZONES[mapId].zoneSep.fs:Hide()
			MAP_ZONES[mapId].zoneSep.texture:Hide()
		else

			MAP_ZONES[mapId].zoneSep.fs:Show()
			MAP_ZONES[mapId].zoneSep.fs:SetPoint("TOP", BWQ, "TOP", 15 + (totalWidth / -2) + (MAP_ZONES[mapId].zoneSep.fs:GetStringWidth() / 2), offsetTop + ROW_HEIGHT * rowInViewIndex - 2)
			MAP_ZONES[mapId].zoneSep.texture:Show()
			MAP_ZONES[mapId].zoneSep.texture:SetPoint("TOP", BWQ, "TOP", 5, offsetTop + ROW_HEIGHT * rowInViewIndex - 3)

			rowInViewIndex = rowInViewIndex + 1
		end

		if MAP_ZONES[mapId].numQuests ~= 0 then
			rowIndex = rowIndex + 1 -- count up from row with zone name
		end

		highlightedRow = true
		local buttonIndex = 1
		for _, button in ipairs(MAP_ZONES[mapId].buttons) do

			if not button.quest.hide and buttonIndex <= MAP_ZONES[mapId].numQuests then
				if rowIndex < sliderval  or rowIndex > sliderval + maxEntries then
					button:Hide()
				else
					button:Show()
					button:SetPoint("TOP", BWQ, "TOP", 0, offsetTop + ROW_HEIGHT * rowInViewIndex)
					rowInViewIndex = rowInViewIndex + 1

					if highlightedRow then
						button.rowHighlight:Show()
					else
						button.rowHighlight:Hide()
					end
				end
				highlightedRow = not highlightedRow
				buttonIndex = buttonIndex + 1
				rowIndex = rowIndex + 1
			else
				button:Hide()
			end
		end
	end
end

function BWQ:RunUpdate()
	local currentTime = GetTime()
	if currentTime - lastUpdate > 5 then
		updateTries = 1
		BWQ:UpdateBlock()
		lastUpdate = currentTime
	end
end

function BWQ:UpdateBlock()
	if not BWQ:WorldQuestsUnlocked() then return end

	offsetTop = -15 -- initial padding from top
	BWQ:UpdateBountyData()
	BWQ:UpdateQuestData()

	local titleMaxWidth, bountyMaxWidth, factionMaxWidth, rewardMaxWidth, timeLeftMaxWidth = 0, 0, 0, 0, 0
	for mapId in next, MAP_ZONES do
		local buttonIndex = 1

		if not MAP_ZONES[mapId].zoneSep then
			local zoneSep = {
				fs = BWQ:CreateFontString("BWQzoneNameFS", "OVERLAY", "SystemFont_Shadow_Med1"),
				texture = BWQ:CreateTexture(),
			}
			zoneSep.fs:SetJustifyH("LEFT")
			zoneSep.fs:SetTextColor(.9, .8, 0)
			zoneSep.fs:SetText(MAP_ZONES[mapId].name)
			zoneSep.texture:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
			zoneSep.texture:SetHeight(8)

			MAP_ZONES[mapId].zoneSep = zoneSep
		end

		for _, questId in next, MAP_ZONES[mapId].questsSort do

			local button
			if buttonIndex > #MAP_ZONES[mapId].buttons then

				button = CreateFrame("Button", nil, BWQ)
				button:RegisterForClicks("AnyUp")

				button.highlight = button:CreateTexture()
				button.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
				button.highlight:SetBlendMode("ADD")
				button.highlight:SetAlpha(0)
				button.highlight:SetAllPoints(button)

				button.rowHighlight = button:CreateTexture()
				button.rowHighlight:SetTexture("Interface\\Buttons\\WHITE8x8")
				button.rowHighlight:SetBlendMode("ADD")
				button.rowHighlight:SetAlpha(0.05)
				button.rowHighlight:SetAllPoints(button)

				button:SetScript("OnLeave", function(self)
					Block_OnLeave()
					button.highlight:SetAlpha(0)
				end)
				button:SetScript("OnEnter", function(self)
					button.highlight:SetAlpha(1)
				end)

				button:SetScript("OnClick", function(self)
					Row_OnClick(button)
				end)

				button.icon = button:CreateTexture()
				button.icon:SetTexture("Interface\\QUESTFRAME\\WorldQuest")
				button.icon:SetSize(12, 12)

				-- create font strings
				button.title = CreateFrame("Button", nil, button)
				button.title:SetScript("OnClick", function(self)
					Row_OnClick(button)
				end)
				button.title:SetScript("OnEnter", function(self)
					button.highlight:SetAlpha(1)

					ShowQuestObjectiveTooltip(button)
				end)
				button.title:SetScript("OnLeave", function(self)
					button.highlight:SetAlpha(0)

					tip:Hide()
					Block_OnLeave()
				end)

				button.titleFS = button:CreateFontString("BWQtitleFS", "OVERLAY", "SystemFont_Shadow_Med1")
				button.titleFS:SetJustifyH("LEFT")
				button.titleFS:SetTextColor(.9, .9, .9)
				button.titleFS:SetWordWrap(false)

				button.bountyFS = button:CreateFontString("BWQbountyFS", "OVERLAY", "SystemFont_Shadow_Med1")
				button.bountyFS:SetJustifyH("LEFT")
				button.bountyFS:SetWordWrap(false)

				button.factionFS = button:CreateFontString("BWQfactionFS", "OVERLAY", "SystemFont_Shadow_Med1")
				button.factionFS:SetJustifyH("LEFT")
				button.factionFS:SetTextColor(.9, .9, .9)
				button.factionFS:SetWordWrap(false)

				button.reward = CreateFrame("Button", nil, button)
				button.reward:SetScript("OnClick", function(self)
					Row_OnClick(button)
				end)

				button.rewardFS = button.reward:CreateFontString("BWQrewardFS", "OVERLAY", "SystemFont_Shadow_Med1")
				button.rewardFS:SetJustifyH("LEFT")
				button.rewardFS:SetTextColor(.9, .9, .9)
				button.rewardFS:SetWordWrap(false)

				button.timeLeftFS = button:CreateFontString("BWQtimeLeftFS", "OVERLAY", "SystemFont_Shadow_Med1")
				button.timeLeftFS:SetJustifyH("LEFT")
				button.timeLeftFS:SetTextColor(.9, .9, .9)
				button.timeLeftFS:SetWordWrap(false)

				MAP_ZONES[mapId].buttons[buttonIndex] = button
			else
				button = MAP_ZONES[mapId].buttons[buttonIndex]
			end

			button.mapId = mapId
			button.quest = MAP_ZONES[mapId].quests[questId]

			-- fill and format row
			local rewardText = ""
			if button.quest.reward.itemName or button.quest.reward.artifactPower then
				local itemText
				if button.quest.reward.artifactPower then
					itemText = string.format("|cffe5cc80[%s Artifact Power]|r", button.quest.reward.artifactPower)
				else
					itemText = string.format("%s[%s]|r", ITEM_QUALITY_COLORS[button.quest.reward.itemQuality].hex, button.quest.reward.itemName)
				end

				rewardText = string.format(
					"|T%s$s:14:14|t %s%s",
					button.quest.reward.itemTexture,
					itemText,
					button.quest.reward.itemQuantity > 1 and " x" .. button.quest.reward.itemQuantity or ""
				)

				button.reward:SetScript("OnEvent", function(self, event)
					if event == "MODIFIER_STATE_CHANGED" then
						ShowQuestLogItemTooltip(button)
					end
				end)

				button.reward:SetScript("OnEnter", function(self)
					button.highlight:SetAlpha(1)
					self:RegisterEvent("MODIFIER_STATE_CHANGED")

					ShowQuestLogItemTooltip(button)
				end)

				button.reward:SetScript("OnLeave", function(self)
					button.highlight:SetAlpha(0)

					self:UnregisterEvent("MODIFIER_STATE_CHANGED")
					tip:Hide()
					Block_OnLeave()
				end)
			else
				button.reward:SetScript("OnEnter", function(self)
					button.highlight:SetAlpha(1)
				end)
				button.reward:SetScript("OnLeave", function(self)
					button.highlight:SetAlpha(0)

					tip:Hide()
					Block_OnLeave()
				end)
			end
			if button.quest.reward.money and button.quest.reward.money > 0 then
				local moneyText = GetCoinTextureString(button.quest.reward.money)
				rewardText = string.format(
					"%s%s%s",
					rewardText,
					rewardText ~= "" and "   " or "", -- insert some space between rewards
					moneyText
				)
			end
			if button.quest.reward.resourceName then
				local currencyText = string.format(
					"|T%1$s:14:14|t %2$d %3$s",
					button.quest.reward.resourceTexture,
					button.quest.reward.resourceAmount,
					button.quest.reward.resourceName
				)

				rewardText = string.format(
					"%s%s%s",
					rewardText,
					rewardText ~= "" and "   " or "", -- insert some space between rewards
					currencyText
				)
			end

			-- if button.quest.tagId == 136 or button.quest.tagId == 111 or button.quest.tagId == 112 then
			--button.icon:SetTexCoord(.81, .84, .68, .79) -- skull tex coords
			if WORLD_QUEST_ICONS_BY_TAG_ID[button.quest.tagId] then
				button.icon:SetAtlas(WORLD_QUEST_ICONS_BY_TAG_ID[button.quest.tagId], true)
				button.icon:SetAlpha(1)
			else
				button.icon:SetAlpha(0)
			end
			button.icon:SetSize(12, 12)


			button.titleFS:SetText(string.format("|cffe5cc80%s|r%s%s|r", button.quest.isNew and "NEW  " or "", WORLD_QUEST_QUALITY_COLORS[button.quest.isRare].hex, button.quest.title))
			--local titleWidth = button.titleFS:GetStringWidth()
			--if titleWidth > titleMaxWidth then titleMaxWidth = titleWidth end

			local bountyText = ""
			for _, bountyIcon in ipairs(button.quest.bounties) do
				bountyText = string.format("%s |T%s$s:14:14|t", bountyText, bountyIcon)
			end
			button.bountyFS:SetText(bountyText)
			local bountyWidth = button.bountyFS:GetStringWidth()
			if bountyWidth > bountyMaxWidth then bountyMaxWidth = bountyWidth end

			button.factionFS:SetText(button.quest.faction)
			local factionWidth = button.factionFS:GetStringWidth()
			if factionWidth > factionMaxWidth then factionMaxWidth = factionWidth end

			button.timeLeftFS:SetText(FormatTimeLeftString(button.quest.timeLeft))
			--local timeLeftWidth = button.factionFS:GetStringWidth()
			--if timeLeftWidth > timeLeftMaxWidth then timeLeftMaxWidth = timeLeftWidth end

			button.rewardFS:SetText(rewardText)

			local rewardWidth = button.rewardFS:GetStringWidth()
			if rewardWidth > rewardMaxWidth then rewardMaxWidth = rewardWidth end
			button.reward:SetHeight(button.rewardFS:GetStringHeight())
			button.title:SetHeight(button.titleFS:GetStringHeight())

			button.icon:SetPoint("LEFT", button, "LEFT", 5, 0)
			button.titleFS:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
			button.title:SetPoint("LEFT", button.titleFS, "LEFT", 0, 0)
			button.rewardFS:SetPoint("LEFT", button.titleFS, "RIGHT", 10, 0)
			button.reward:SetPoint("LEFT", button.rewardFS, "LEFT", 0, 0)
			button.bountyFS:SetPoint("LEFT", button.rewardFS, "RIGHT", 10, 0)
			button.factionFS:SetPoint("LEFT", button.bountyFS, "RIGHT", 10, 0)
			button.timeLeftFS:SetPoint("LEFT", button.factionFS, "RIGHT", 10, 0)

			buttonIndex = buttonIndex + 1
		end -- quest loop
	end -- maps loop

	titleMaxWidth = 125
	rewardMaxWidth = rewardMaxWidth < 150 and 150 or rewardMaxWidth
	factionMaxWidth = factionMaxWidth < 100 and 100 or factionMaxWidth
	timeLeftMaxWidth = 65
	totalWidth = titleMaxWidth + bountyMaxWidth + factionMaxWidth + rewardMaxWidth + timeLeftMaxWidth + 70

	local bountyBoardWidth = BWQ.bountyBoardFS:GetStringWidth()
	if totalWidth < bountyBoardWidth then
		local diff = bountyBoardWidth - totalWidth
		totalWidth = bountyBoardWidth
		rewardMaxWidth = rewardMaxWidth + diff
	end

	for mapId in next, MAP_ZONES do
		for i = 1, #MAP_ZONES[mapId].buttons do
			if not MAP_ZONES[mapId].buttons[i].quest.hide then -- dont care about the hidden ones
				MAP_ZONES[mapId].buttons[i]:SetHeight(15)
				MAP_ZONES[mapId].buttons[i]:SetWidth(totalWidth)
				MAP_ZONES[mapId].buttons[i].title:SetWidth(titleMaxWidth)
				MAP_ZONES[mapId].buttons[i].titleFS:SetWidth(titleMaxWidth)
				MAP_ZONES[mapId].buttons[i].bountyFS:SetWidth(bountyMaxWidth)
				MAP_ZONES[mapId].buttons[i].factionFS:SetWidth(factionMaxWidth)
				MAP_ZONES[mapId].buttons[i].reward:SetWidth(rewardMaxWidth)
				MAP_ZONES[mapId].buttons[i].rewardFS:SetWidth(rewardMaxWidth)
				MAP_ZONES[mapId].buttons[i].timeLeftFS:SetWidth(timeLeftMaxWidth)
			else
				MAP_ZONES[mapId].buttons[i]:Hide()
			end
		end
		MAP_ZONES[mapId].zoneSep.texture:SetWidth(totalWidth + 20)
	end

	totalWidth = totalWidth + 20
	BWQ:SetWidth(totalWidth > 550 and totalWidth or 550)

	BWQ:RenderRows()
end


local configMenu
local info = {}
function BWQ:SetupConfigMenu()
	configMenu = CreateFrame("Frame", "BWQ_ConfigMenu")
	configMenu.displayMode = "MENU"

	local options = {
		{ text = "Attach list frame to world map", check = "attachToWorldMap" },
		{ text = "Show list frame on click", check = "showOnClick" },
		{ text = "" },
		{ text = "Always show |cffa335eeepic|r world quests (e.g. world bosses)", check = "alwaysShowEpicQuests" },
		{ text = "Don't filter quests for active bounties", check = "alwaysShowBountyQuests" },
		{ text = "" },
		{ text = "Filter by reward...", isTitle = true },
		{ text = ("|T%1$s:16:16|t  Artifact Power"):format("Interface\\Icons\\inv_enchant_shardradientlarge"), check = "showArtifactPower" },
		{ text = ("|T%1$s:16:16|t  Items"):format("Interface\\Minimap\\Tracking\\Banker"), check = "showItems", submenu = {
				{ text = ("|T%1$s:16:16|t  Gear"):format("Interface\\Icons\\Inv_chest_plate_legionendgame_c_01"), check = "showGear" },
				{ text = ("|T%1$s:16:16|t  Artifact Relics"):format("Interface\\Icons\\inv_misc_statue_01"), check = "showRelics" },
				{ text = ("|T%s$s:16:16|t  Crafting Materials"):format("1417744"), check = "showCraftingMaterials" },
				{ text = "Other", check = "showOtherItems" },
			}
		},
		{ text = ("|T%1$s:16:16|t  Low gold reward"):format("Interface\\GossipFrame\\auctioneerGossipIcon"), check = "showLowGold" },
		{ text = ("|T%1$s:16:16|t  High gold reward"):format("Interface\\GossipFrame\\auctioneerGossipIcon"), check = "showHighGold" },
		{ text = "Resources", check = "showResources", submenu = {
				{ text = ("|T%1$s:16:16|t  Order Hall Resources"):format("Interface\\Icons\\inv_orderhall_orderresources"), check = "showOrderHallResources" },
				{ text = ("|T%1$s:16:16|t  Ancient Mana"):format("Interface\\Icons\\inv_misc_ancient_mana"), check = "showAncientMana" },
				{ text = "Other", check = "showOtherResources" },
			}
		},
		{ text = "" },
		{ text = "Filter by type...", isTitle = true },
		{ text = ("|T%1$s:16:16|t  Profession Quests"):format("Interface\\Minimap\\Tracking\\Profession"), check = "showProfession", submenu = {
				{ text = "Alchemy", check="showProfessionAlchemy" },
				{ text = "Blacksmithing", check="showProfessionBlacksmithing" },
				{ text = "Inscription", check="showProfessionInscription" },
				{ text = "Jewelcrafting", check="showProfessionJewelcrafting" },
				{ text = "Leatherworking", check="showProfessionLeatherworking" },
				{ text = "Tailoring", check="showProfessionTailoring" },
				{ text = "Enchanting", check="showProfessionEnchanting" },
				{ text = "Engineering", check="showProfessionEngineering" },
				{ text = "" },
				{ text = "Herbalism", check="showProfessionHerbalism" },
				{ text = "Mining", check="showProfessionMining" },
				{ text = "Skinning", check="showProfessionSkinning" },
				{ text = "" },
				{ text = "Cooking", check="showProfessionCooking" },
				{ text = "Archaeology", check="showProfessionArchaeology" },
				{ text = "FirstAid", check="showProfessionFirstAid" },
				{ text = "Fishing", check="showProfessionFishing" },
			}
		},
		{ text = "Dungeon Quests", check = "showDungeon" },
		{ text = ("|T%1$s:16:16|t  PvP Quests"):format("Interface\\Minimap\\Tracking\\BattleMaster"), check = "showPvP" },
		{ text = "" },
		{ text = ("|T%1$s:16:16|t  Pet Battle Quests"):format("Interface\\Icons\\tracking_wildpet"), isTitle = true },
		{ text = "Show Pet Battle Quests", check = "showPetBattle" },
		{ text = "Hide Pet Battle Quests even when active bounty", check = "hidePetBattleBountyQuests" },
		{ text = "Always show Pet Battle Quests for \"Family Familiar\" achievement", check = "alwaysShowPetBattleFamilyFamiliar" },
		{ text = "" },
		{ text = "Always show quests for faction...", isTitle = true },
		{ text = "Court of Farondis", check="alwaysShowCourtOfFarondis" },
		{ text = "Dreamweavers", check="alwaysShowDreamweavers" },
		{ text = "Highmountain Tribe", check="alwaysShowHighmountainTribe" },
		{ text = "The Nightfallen", check="alwaysShowNightfallen" },
		{ text = "The Wardens", check="alwaysShowWardens" },
		{ text = "Valarjar", check="alwaysShowValarjar" },
	}

	local SetOption = function(bt, var, val)
		BWQcfg[var] = val or not BWQcfg[var]
		BWQ:UpdateBlock()
		if WorldMapFrame:IsShown() then
			BWQ:OpenConfigMenu(nil)
		end

		-- toggle block when changing attach setting
		if var == "attachToWorldMap" then
			BWQ:Hide()
			if BWQcfg[var] == true and WorldMapFrame:IsShown() then
				BWQ:AttachToWorldMap()
			end
		end
	end

	configMenu.initialize = function(self, level)
		if not level then return end
		local opt = level > 1 and UIDROPDOWNMENU_MENU_VALUE or options
		for i, v in ipairs(opt) do
			info = wipe(info)
			info.text = v.text
			info.isTitle = v.isTitle

			if v.check then
				info.checked = v.inv and not BWQcfg[v.check] or not v.inv and BWQcfg[v.check]
				info.func, info.arg1 = SetOption, v.check
				info.isNotRadio = true
				info.keepShownOnClick = true
			else
				info.notCheckable = true
				info.disabled = true
			end
			info.hasArrow, info.value = v.submenu, v.submenu
			UIDropDownMenu_AddButton( info, level )
		end
	end

	BWQ.SetupConfigMenu = nil
end


function BWQ:OpenConfigMenu(anchor)
	if not configMenu and anchor then
		BWQ:SetupConfigMenu()
		configMenu.anchor = anchor
	end
	--BWQ:Hide()
	ToggleDropDownMenu(1, nil, configMenu, configMenu.anchor, 0, 0)
end

function BWQ:AttachToBlock(anchor)
	if not BWQcfg.attachToWorldMap or (BWQcfg.attachToWorldMap and not WorldMapFrame:IsShown()) then
		CloseDropDownMenus()

		blockYPos = select(2, anchor:GetCenter())
		showDownwards = blockYPos > UIParent:GetHeight() / 2
		BWQ:ClearAllPoints()
		BWQ:SetPoint(showDownwards and "TOP" or "BOTTOM", anchor, showDownwards and "BOTTOM" or "TOP", 0, 0)
		BWQ:SetFrameStrata("DIALOG")
		BWQ:Show()

		BWQ:RunUpdate()
	end
end

function BWQ:AttachToWorldMap()
	BWQ:ClearAllPoints()
	BWQ:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 3, 0)
	BWQ:SetFrameStrata("HIGH")
	BWQ:Show()
end

local skipNextUpdate = false
BWQ:RegisterEvent("PLAYER_ENTERING_WORLD")
BWQ:RegisterEvent("ADDON_LOADED")
BWQ:SetScript("OnEvent", function(self, event, arg1)
	if event == "QUEST_LOG_UPDATE" then
		if not skipNextUpdate then
			BWQ:RunUpdate()
		end
		skipNextUpdate = false
	--[[
	Opening quest details in the side bar of the world map fires QUEST_LOG_UPDATE event.
	To avoid setting the currently shown map again, which would hide the quest details,
	skip updating after a WORLD_MAP_UPDATE event happened
	--]]
	elseif event == "WORLD_MAP_UPDATE" and WorldMapFrame:IsShown() then
		skipNextUpdate = true
		local mapId = GetCurrentMapAreaID()
		if BWQ.currentMapId and BWQ.currentMapId ~= mapId then
			BWQ.mapTextures.animationGroup:Stop()
			BWQ:HideAllWatchGlows(BWQ.currentMapId)
		end
		BWQ:UpdateWatchGlows(mapId)
		BWQ.currentMapId = mapId
	elseif event == "QUEST_WATCH_LIST_CHANGED" then
		BWQ:UpdateWatchGlows(GetCurrentMapAreaID())
	elseif event == "PLAYER_ENTERING_WORLD" then
		BWQ.slider:SetScript("OnLeave", Block_OnLeave )
		BWQ.slider:SetScript("OnValueChanged", function(self, value)
			BWQ:RenderRows()
		end)

		BWQ:SetScript("OnMouseWheel", function(self, delta)
			BWQ.slider:SetValue(BWQ.slider:GetValue() - delta * 3)
		end)

		if Aurora and Aurora[1] then
			Aurora[1].CreateBD(BWQ)
		elseif ElvUI then
			BWQ:SetTemplate("Transparent")
		elseif TipTac then
			local tiptacBKG = { tile = false, insets = {} }
			local cfg = TipTac_Config
			if cfg.tipBackdropBG and cfg.tipBackdropEdge and cfg.tipColor and cfg.tipBorderColor then
				tiptacBKG.bgFile = cfg.tipBackdropBG
				tiptacBKG.edgeFile = cfg.tipBackdropEdge
				tiptacBKG.edgeSize = cfg.backdropEdgeSize
				tiptacBKG.insets.left = cfg.backdropInsets
				tiptacBKG.insets.right = cfg.backdropInsets
				tiptacBKG.insets.top = cfg.backdropInsets
				tiptacBKG.insets.bottom = cfg.backdropInsets
				BWQ:SetBackdrop(tiptacBKG)
				BWQ:SetBackdropColor(unpack(cfg.tipColor))
				BWQ:SetBackdropBorderColor(unpack(cfg.tipBorderColor))
			end
		end

		hooksecurefunc(WorldMapFrame, "Hide", function(self)
			if BWQcfg["attachToWorldMap"] then
				BWQ:Hide()
			end

			BWQ.mapTextures.animationGroup:Stop()
			BWQ:HideAllWatchGlows(BWQ.currentMapId)
		end)
		hooksecurefunc(WorldMapFrame, "Show", function(self)
			if BWQcfg["attachToWorldMap"] then
				BWQ:AttachToWorldMap()
				BWQ:RunUpdate()
			end
		end)

		BWQ:UnregisterEvent("PLAYER_ENTERING_WORLD")

		BWQ:RegisterEvent("QUEST_LOG_UPDATE")
		BWQ:RegisterEvent("WORLD_MAP_UPDATE")
		BWQ:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	elseif event == "ADDON_LOADED" and arg1 == "Broker_WorldQuests" then
		BWQcfg = BWQcfg or defaultConfig
		for i, v in next, defaultConfig do
			if BWQcfg[i] == nil then
				BWQcfg[i] = v
			end
		end
		BWQcache = BWQcache or {}

		BWQ:UnregisterEvent("ADDON_LOADED")
	end
end)

-- data broker object
local ldb = LibStub("LibDataBroker-1.1")
BWQ.WorldQuestsBroker = ldb:NewDataObject("WorldQuests", {
	type = "launcher",
	label = "World Quests",
	text = "World Quests",
	icon = "Interface\\ICONS\\Achievement_Dungeon_Outland_DungeonMaster",
	OnEnter = function(self)
		if not BWQcfg.showOnClick then
			BWQ:AttachToBlock(self)
		end
	end,
	OnLeave = Block_OnLeave,
	OnClick = function(self, button)
		if button == "LeftButton" then
			if BWQcfg.showOnClick then
				BWQ:AttachToBlock(self)
			else
				BWQ:RunUpdate()
			end
		elseif button == "RightButton" then
			Block_OnLeave()
			BWQ:OpenConfigMenu(self)
		end
	end,
})
