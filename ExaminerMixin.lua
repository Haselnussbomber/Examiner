BINDING_HEADER_EXAMINER = "Examiner";
BINDING_NAME_EXAMINER_OPEN = "Open Examiner";

ExaminerMixin = {};

function ExaminerMixin:OnLoad()
	RegisterUIPanel(self, { area = "left", pushable = 3, whileDead = 1 });
	tinsert(UISpecialFrames, self:GetName());

	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("INSPECT_READY");
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("UNIT_LEVEL");
	self:RegisterEvent("UNIT_MODEL_CHANGED");
	self:RegisterEvent("UNIT_NAME_UPDATE");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("GUILD_ROSTER_UPDATE");

	ButtonFrameTemplate_HideButtonBar(self);
	PanelTemplates_SetNumTabs(self, 3);
	PanelTemplates_SetTab(self, 1); -- Character
	self.onUpdateTimer = 0;

	self.dungeonScores = {};
	self:UpdateDungeonScores();

	-- set guildName font size to 18 (instead of 20)
	local font, _, fontFlags = self.guild.guildName:GetFont();
	self.guild.guildName:SetFont(font, 18, fontFlags);

	-- only show model controlFrame and allow model rotating and zooming when on first tab
	for _, event in pairs({"OnEnter", "OnUpdate", "OnMouseWheel"}) do
		local fn = self.model:GetScript(event);
		self.model:SetScript(event, function(...)
			local currentTab = PanelTemplates_GetSelectedTab(self);
			if (currentTab == 1) then
				fn(...);
			end
		end)
	end
end

function ExaminerMixin:OnHide()
	self:ClearInspect();
end

function ExaminerMixin:OnEvent(event, ...)
	if (self[event]) then
		self[event](self, ...);
	end
end

function ExaminerMixin:OnUpdate(elapsed)
	if (not self.data or
		not self.data.isPlayer or
		self.data.loaded or
		not self.data.loading or
		not UnitExists(self.data.unit) or
		not CanInspect(self.data.unit) or
		UnitGUID(self.data.unit) ~= self.data.guid
	) then
		return;
	end

	self.onUpdateTimer = self.onUpdateTimer + elapsed;

	if (self.onUpdateTimer < 0.666) then
		return;
	end

	self.onUpdateTimer = 0;

	NotifyInspect(self.data.unit);
end

function ExaminerMixin:ShouldHandleEvent(guid)
	return self:IsVisible() and self.data and guid == self.data.guid;
end

function ExaminerMixin:PLAYER_TARGET_CHANGED()
	if (not self:IsVisible()) then
		return;
	end

	if (IsModifierKeyDown() or not UnitExists("target") or not (self.data and UnitGUID("target") ~= self.data.guid)) then
		return;
	end

	self:ClearInspect();
	self:Inspect();
	self:UpdateTalentButton();
end

function ExaminerMixin:UNIT_INVENTORY_CHANGED(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self:UpdateItemFrames();
end

function ExaminerMixin:UNIT_MODEL_CHANGED(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self.model:RefreshUnit();
end

function ExaminerMixin:UNIT_PORTRAIT_UPDATE(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self:UpdatePortrait();
end

function ExaminerMixin:UNIT_LEVEL(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self.data.level = UnitLevel(unit) or -1;
	self.data.effectiveLevel = UnitEffectiveLevel(unit) or -1;

	self:UpdateDetails();
end

function ExaminerMixin:UNIT_NAME_UPDATE(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self.data.name, self.data.realm = UnitName(unit);
	self.data.pvpName = UnitPVPName(unit);

	self:UpdateTitle();
end

function ExaminerMixin:GUILD_ROSTER_UPDATE()
	self:UpdateDungeonScores();
end

function ExaminerMixin:INSPECT_READY(guid)
	if (not self:ShouldHandleEvent(guid)) then
		return;
	end

	self.data.loading = false;
	self.data.loaded = true;

	if (self.data.guild) then
		self.data.guildPoints, self.data.guildMembers = GetInspectGuildInfo(self.data.unit);
	end

	self:FetchSpecialization();
	self:UpdateTalentButton();
	self:UpdateGuildTab();
	self:UpdateDetails();
	self:UpdateItemFrames();
	self:UpdateFrame();
end

function ExaminerMixin:INSPECT_HONOR_UPDATE()
	if (not self.data or not self:ShouldHandleEvent(UnitGUID(self.data.unit))) then
		return;
	end

	self:FetchHonorData();
	self:UpdatePVPTab();
end

function ExaminerMixin:PLAYER_SPECIALIZATION_CHANGED()
	if (not self:ShouldHandleEvent(UnitGUID("player"))) then
		return;
	end

	self:FetchSpecialization();
	self:UpdateTalentButton();
	self:UpdateDetails();
end

function ExaminerMixin:Inspect()
	local unit = "target";

	if (not UnitExists(unit)) then
		unit = "player";
	end

	local guid = UnitGUID(unit);

	if (guid:find("^ClientActor-") ~= nil) then
		return;
	end

	INSPECTED_UNIT = unit;

	local name, realm = UnitName(unit);
	local class, classFixed, classID = UnitClass(unit);
	local factionGroup, factionName = UnitFactionGroup(unit);

	local playerFlag = nil
	local mentorshipStatus = C_PlayerMentorship.GetMentorshipStatus(PlayerLocation:CreateFromUnit(unit))

	if (mentorshipStatus == Enum.PlayerMentorshipStatus.Mentor) then
		playerFlag = "|A:newplayerchat-chaticon-guide:0:0:0:0|a"; -- NPEV2_CHAT_USER_TAG_GUIDE
	elseif (mentorshipStatus == Enum.PlayerMentorshipStatus.Newcomer) then
		playerFlag = NPEV2_CHAT_USER_TAG_NEWCOMER;
	end

	-- Note: NPC guild names are only accessible via tooltip parsing
	local guild, guildRank, guildIndex = GetGuildInfo(unit);

	local data = {
		unit = unit,

		isPlayer = UnitIsPlayer(unit),
		isSelf = UnitIsUnit(unit, "player"),
		--canCooperate = UnitCanCooperate("player", unit),
		canInspect = CanInspect(unit),

		guid = guid,
		name = name,
		realm = realm or nil,
		factionGroup = factionGroup,
		factionName = factionName,
		pvpName = UnitPVPName(unit),
		playerFlag = playerFlag,
		level = UnitLevel(unit) or -1,
		effectiveLevel = UnitEffectiveLevel(unit) or -1,
		sex = UnitSex(unit) or 1,
		class = class,
		classFixed = classFixed,
		classID = classID,
		guild = guild,
		guildRank = guildRank,
		guildIndex = guildIndex,

		lifetimeHKs = 0,
		honorLevel = 0,
		ratedBgRating = 0,
		ratedBgPlayed = 0,
		ratedBgWon = 0,
		arenaTeams = {},
		pvpTalents = {},

		npcID = guid and tonumber(guid:match("-(%d+)-%x+$"), 10) or nil,
		hasLoot = false,
	};

	data.loading = not data.isSelf;
	data.loaded = data.isSelf;

	local oldData = self.data;
	self.data = data;

	if (data.isPlayer) then
		data.race, data.raceFileName = UnitRace(unit);

		if (data.canInspect) then
			if (not data.isSelf) then
				NotifyInspect(unit);
			else
				self:FetchHonorData();
			end

			self:FetchSpecialization();

			self:UpdateItemFrames();
			self:UpdatePVPTab();
			self:UpdateGuildTab();
		end

		local currentTab = PanelTemplates_GetSelectedTab(self);

		if (not C_SpecializationInfo.CanPlayerUsePVPTalentUI() and currentTab == 2) then
			self:SwitchTabs(1);
		end

		if (not data.guild and currentTab == 3) then
			self:SwitchTabs(1);
		end

		-- switch between npc and player
		if (oldData and oldData.guid and oldData.isPlayer ~= data.isPlayer) then
			self:SwitchTabs(1);
		end
	else
		data.race = UnitCreatureFamily(unit) or UnitCreatureType(unit);
		self:SwitchTabs(1);
		self.averageItemLevel:SetShown(false);

		local entry = ExaminerNPCData[data.npcID];
		if (entry) then
			local instanceID, encounterID = unpack(entry);

			data.instanceID = instanceID;
			data.encounterID = encounterID;

			EJ_SelectInstance(instanceID);
			EJ_SelectEncounter(encounterID);

			data.hasLoot = C_EncounterJournal.InstanceHasLoot();
		end
	end

	self:UpdateTitle();
	self:UpdateDetails();
	self:UpdatePortrait();
	self:UpdateModel();
	self:UpdateFrame();
	self:UpdateTalentButton();

	if (InCombatLockdown()) then
		self:Show();
	else
		ShowUIPanel(self);
	end

	if (InspectEquip) then
		InspectEquip:SetParent(self);
		InspectEquip_InfoWindow:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0);
		InspectEquip:Inspect(unit);
	end
end

function ExaminerMixin:ClearInspect()
	if (self.data) then
		ClearInspectPlayer(self.data.guid);
		self.data = nil;
	end
end

function ExaminerMixin:UpdateDungeonScores()
	if (not C_Club.IsEnabled()) then
		return;
	end

	local clubs = C_Club.GetSubscribedClubs();
	for i, clubInfo in ipairs(clubs) do
		local memberIds = C_Club.GetClubMembers(clubInfo.clubId);

		for _, memberId in ipairs(memberIds) do
			local memberInfo = C_Club.GetMemberInfo(clubInfo.clubId, memberId);
			if (memberInfo and memberInfo.overallDungeonScore) then
				self.dungeonScores[memberInfo.guid] = memberInfo.overallDungeonScore;
			end
		end
	end
end

function ExaminerMixin:FetchSpecialization()
	local data = self.data;
	if (data.isSelf) then
		local specID = GetSpecialization();
		if (specID) then
			local _, name, _, _, role = GetSpecializationInfo(specID, nil, nil, nil, data.sex);
			data.specName = name;
			data.specRole = role;
		end
	else
		local specID = GetInspectSpecialization(data.unit);
		if (specID) then
			local _, name, _, _, role = GetSpecializationInfoByID(specID, data.sex);
			data.specName = name;
			data.specRole = role;
		end
	end

	data.specGroup = GetActiveSpecGroup(data.unit);
end

function ExaminerMixin:UpdateItemFrames()
	if (not self.data.isPlayer) then
		return;
	end

	local itemButtonFrames = { self.items:GetChildren() };
	for _, button in ipairs(itemButtonFrames) do
		button:Update();
	end

	local dungeonScore = "";
	if (self.dungeonScores[self.data.guid]) then
		local score = self.dungeonScores[self.data.guid];
		local color = C_ChallengeMode.GetDungeonScoreRarityColor(score);
		dungeonScore = color and color:WrapTextInColorCode(score) or score;
	end

	local averageItemLevel = 0;
	if (self.data.isSelf) then
		averageItemLevel = select(2, GetAverageItemLevel());
	else
		local totalItemLevel = 0;
		local totalItemCount = 0;
		for _, button in ipairs(itemButtonFrames) do
			-- ignore shirt and tabard
			local isShirtOrTabard = button:GetID() == 4 or button:GetID() == 19;
			local hasValidItemLevel = button.itemLevel and button.itemLevel > 0;
			if (not isShirtOrTabard and hasValidItemLevel) then
				totalItemLevel = totalItemLevel + button.itemLevel;
				totalItemCount = totalItemCount + 1;
			end
		end
		if (totalItemCount > 0) then
			averageItemLevel = totalItemLevel / totalItemCount;
		end
	end

	if (averageItemLevel > 0 and dungeonScore ~= "") then
		self.averageItemLevel.text:SetFormattedText("Ø: %d|nM+: %s", averageItemLevel, dungeonScore);
		self.averageItemLevel:SetShown(true);
	elseif (averageItemLevel > 0) then
		self.averageItemLevel.text:SetFormattedText("Ø: %d", averageItemLevel);
		self.averageItemLevel:SetShown(true);
	elseif (dungeonScore ~= "") then
		self.averageItemLevel.text:SetFormattedText("M+: %s", dungeonScore);
		self.averageItemLevel:SetShown(true);
	else
		self.averageItemLevel.text:SetText("");
		self.averageItemLevel:SetShown(false);
	end

	self.data.itemTransmogInfoList = C_TransmogCollection.GetInspectItemTransmogInfoList();
end

function ExaminerMixin:UpdateTalentButton()
	local data = self.data;

	if (not data.isPlayer
			or not self.data.loaded
			or (not data.isSelf and not C_Traits.HasValidInspectData())
			or UnitGUID(self.data.unit) ~= self.data.guid) then
		self.TalentsButtonFrame.TalentsButton:Hide();
		return;
	end

	ClassTalentFrame_LoadUI();
	ClassTalentFrame:SetInspecting(not data.isSelf and data.unit or nil);
	self.TalentsButtonFrame.TalentsButton:Show();
end

function ExaminerMixin:OpenTalents()
	local data = self.data;

	if (not data.isPlayer) then
		return;
	end

	if not ClassTalentFrame:IsShown() then
		ShowUIPanel(ClassTalentFrame);
	end
end

function ExaminerMixin:FetchHonorData()
	local data = self.data;

	if (not data or not data.isPlayer or not C_SpecializationInfo.CanPlayerUsePVPTalentUI()) then
		return;
	end

	local _, arenaTeams, pvpTalents = nil, {}, {};
	local ratedBgRating, ratedBgPlayed, ratedBgWon, lifetimeHKs, honorLevel;

	if (data.isSelf) then
		-- local RATED_BG_ID = 3 in Blizzard_PVPUI/Blizzard_PVPUI.lua
		ratedBgRating, _, _, ratedBgPlayed, ratedBgWon = GetPersonalRatedInfo(3);
		lifetimeHKs = GetPVPLifetimeStats();
		honorLevel = UnitHonorLevel(data.unit);

		for i=1, MAX_ARENA_TEAMS do
			local arenarating, _, _, seasonPlayed, seasonWon = GetPersonalRatedInfo(i);
			arenaTeams[i] = {
				arenarating = arenarating,
				seasonPlayed = seasonPlayed,
				seasonWon = seasonWon,
			};
		end

		pvpTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs();
	else
		ratedBgRating, ratedBgPlayed, ratedBgWon = GetInspectRatedBGData();
		_, _, _, _, lifetimeHKs, _, honorLevel = GetInspectHonorData();

		for i=1, MAX_ARENA_TEAMS do
			local arenarating, seasonPlayed, seasonWon = GetInspectArenaData(i);
			arenaTeams[i] = {
				arenarating = arenarating,
				seasonPlayed = seasonPlayed,
				seasonWon = seasonWon,
			};
		end

		for i=1, 3 do
			pvpTalents[i] = C_SpecializationInfo.GetInspectSelectedPvpTalent(data.unit, i);
		end
	end

	data.ratedBgRating = ratedBgRating;
	data.ratedBgPlayed = ratedBgPlayed;
	data.ratedBgWon = ratedBgWon;
	data.lifetimeHKs = lifetimeHKs;
	data.honorLevel = honorLevel;
	data.arenaTeams = arenaTeams;
	data.pvpTalents = pvpTalents;
end

function ExaminerMixin:UpdatePVPTab()
	local data = self.data;

	if (not data.isPlayer or not C_SpecializationInfo.CanPlayerUsePVPTalentUI()) then
		return;
	end

	-- Honor Level, Honorable Kills
	self.pvp.honorLevel:SetFormattedText(
		HONOR_LEVEL_LABEL:gsub("%%d", "%%s"),
		HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(data.honorLevel)
	);
	self.pvp.HKs:SetFormattedText(INSPECT_HONORABLE_KILLS, data.lifetimeHKs);

	-- Talents
	for i, frame in ipairs(self.pvp.talents) do
		local selectedTalentID = data.pvpTalents[i];
		if (selectedTalentID) then
			frame:SetID(selectedTalentID);
			SetPortraitToTexture(frame.Texture, select(3, GetPvpTalentInfoByID(selectedTalentID)));
			frame:Show();
		else
			frame:Hide();
		end
	end

	-- Rated BG
	self.pvp.ratedbg.Rating:SetFormattedText(
		"%s %s",
		PVP_RATING,
		HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(data.ratedBgRating)
	);
	self.pvp.ratedbg.Record:SetFormattedText(
		"%s %s",
		PVP_RECORD,
		HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
			PVP_RECORD_DESCRIPTION:format(
				data.ratedBgWon,
				data.ratedBgPlayed - data.ratedBgWon
			)
		)
	);

	-- Arena
	for i, arenaTeam in ipairs(data.arenaTeams) do
		local frame = self.pvp["arena"..i];
		if (frame) then
			frame.Rating:SetFormattedText(
				"%s %s",
				PVP_RATING,
				HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(arenaTeam.arenarating)
			);
			frame.Record:SetFormattedText(
				"%s %s",
				PVP_RECORD,
				HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(
					PVP_RECORD_DESCRIPTION:format(
						arenaTeam.seasonWon,
						arenaTeam.seasonPlayed - arenaTeam.seasonWon
					)
				)
			);
		end
	end
end

function ExaminerMixin:UpdateGuildTab()
	local data = self.data;

	if (not data.isPlayer or not data.guild) then
		return;
	end

	self.guild.guildName:SetText(data.guild);

	if (data.factionName and data.guildMembers) then
		self.guild.guildLevel:SetFormattedText(INSPECT_GUILD_FACTION, data.factionName);
		self.guild.guildNumMembers:SetFormattedText(INSPECT_GUILD_NUM_MEMBERS, data.guildMembers);
	end

	SetDoubleGuildTabardTextures(
		data.unit,
		self.guild.tabardLeftIcon,
		self.guild.tabardRightIcon,
		self.guild.banner,
		self.guild.bannerBorder
	);
end

function ExaminerMixin:UpdateTitle()
	local flag = self.data.playerFlag and (self.data.playerFlag .. " ") or "";
	self:SetTitle(flag .. (self.data.pvpName or self.data.name));
end

function ExaminerMixin:UpdateDetails()
	local data = self.data;

	local classColorString = RAID_CLASS_COLORS[data.classFixed or "WARRIOR"].colorStr;
	local level = data.level;

	if (level == -1 or effectiveLevel == -1) then
		level = "??";
	elseif (data.level == -1 and data.effectiveLevel ~= data.level) then
		level = data.effectiveLevel;
	elseif (data.level ~= -1 and data.effectiveLevel ~= data.level) then
		level = EFFECTIVE_LEVEL_FORMAT:format(data.effectiveLevel, data.level);
	end

	if (not data.isPlayer) then
		self.details:SetFormattedText(PLAYER_LEVEL_NO_SPEC..(data.name ~= data.class and "\n%s" or ""), level, classColorString, data.race, data.class);
		return;
	end

	local guild = "";
	if (data.guild and data.guildRank and data.guildIndex) then
		guild = string.format("\n<%s> %s (%d)", data.guild, data.guildRank, data.guildIndex);
	end

	if (data.specName and data.specName ~= "" and data.specRole) then
		local texture = "";
		if (data.specRole == "TANK") then
			texture = " " .. CreateAtlasMarkup("roleicon-tiny-tank");
		elseif (data.specRole == "DAMAGER") then
			texture = " " .. CreateAtlasMarkup("roleicon-tiny-dps");
		elseif (data.specRole == "HEALER") then
			texture = " " .. CreateAtlasMarkup("roleicon-tiny-healer");
		end
		self.details:SetFormattedText(PLAYER_LEVEL..texture..guild, level, classColorString, data.specName, data.class);
	else
		self.details:SetFormattedText(PLAYER_LEVEL_NO_SPEC..guild, level, classColorString, data.class);
	end
end

function ExaminerMixin:UpdatePortrait()
	local data = self.data;

	if (UnitIsVisible(data.unit)) then
		SetPortraitTexture(self.PortraitContainer.portrait, data.unit);
	else
		self.PortraitContainer.portrait:SetTexture(
			("%s-%s-%s"):format(
				"Interface\\CharacterFrame\\TemporaryPortrait",
				data.sex == 3 and "Female" or "Male",
				data.raceFileName or ""
			)
		);
	end
end

function ExaminerMixin:UpdateModel()
	local isVisible = UnitIsVisible(self.data.unit);

	if (isVisible) then
		self.model:SetUnit(self.data.unit);
		local _, fileName = UnitRace(self.data.unit);
		local texture = DressUpTexturePath(fileName);
		self.model.BackgroundTopLeft:SetTexture(texture..1);
		self.model.BackgroundTopRight:SetTexture(texture..2);
		self.model.BackgroundBotLeft:SetTexture(texture..3);
		self.model.BackgroundBotRight:SetTexture(texture..4);
	else
		self.model:ClearModel();
	end

	self.model.BackgroundTopLeft:SetShown(isVisible);
	self.model.BackgroundTopRight:SetShown(isVisible);
	self.model.BackgroundBotLeft:SetShown(isVisible);
	self.model.BackgroundBotRight:SetShown(isVisible);
end

local function TabSetEnable(frame, index, state)
	(state and PanelTemplates_EnableTab or PanelTemplates_DisableTab)(frame, index);
end

function ExaminerMixin:UpdateFrame()
	local data = self.data;
	local canInspect = data.isPlayer and data.canInspect;

	if (data.loading) then
		self.Bg:SetVertexColor(0.5, 1, 0.5);
		self.Inset.Bg:SetVertexColor(0.5, 1, 0.5);
		self.TopTileStreaks:SetVertexColor(0.5, 1, 0.5);
	else
		self.Bg:SetVertexColor(1, 1, 1);
		self.Inset.Bg:SetVertexColor(1, 1, 1);
		self.TopTileStreaks:SetVertexColor(1, 1, 1);
	end

	self.items:SetShown(canInspect);

	local TabSetShown = _G[canInspect and "PanelTemplates_ShowTab" or "PanelTemplates_HideTab"];
	TabSetShown(self, 1); -- Character
	TabSetShown(self, 2); -- PvP
	TabSetShown(self, 3); -- Guild

	if (canInspect) then
		TabSetEnable(self, 2, C_SpecializationInfo.CanPlayerUsePVPTalentUI()); -- PvP
		TabSetEnable(self, 3, data.guild); -- Guild
	end

	self.ej:SetShown(not canInspect and data.hasLoot);
	self.dressUpButton:SetShown(canInspect and self.data.itemTransmogInfoList);
end

function ExaminerMixin:SwitchTabs(id)
	local isPlayer = self.data.isPlayer;

	PanelTemplates_SetTab(self, id);

	self.model:SetAlpha(id ~= 1 and 0.2 or 1);
	self.pvp:SetShown(isPlayer and id == 2);
	self.guild:SetShown(isPlayer and id == 3);
end

function ExaminerMixin:OpenJournal()
	local data = self.data;

	if (not data.isPlayer and data.hasLoot) then
		EncounterJournal_LoadUI();
		EncounterJournal_OpenJournal(nil, data.instanceID, data.encounterID);
	end
end

function ExaminerMixin:DressUp()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

	DressUpFrame.ModelScene:Reset();

	local playerActor = DressUpFrame.ModelScene:GetPlayerActor();
	if (playerActor) then
		playerActor:Undress();
	end

	DressUpItemTransmogInfoList(self.data.itemTransmogInfoList);

	if (playerActor) then
		playerActor:SetSheathed(true);
	end
end
