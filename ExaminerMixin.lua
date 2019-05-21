BINDING_HEADER_EXAMINER = "Examiner";
BINDING_NAME_EXAMINER_OPEN = "Open Examiner";

ExaminerMixin = {};

function ExaminerMixin:OnLoad()
	UIPanelWindows[self:GetName()] = { area = "left", pushable = 3, whileDead = 1 };
    --UISpecialFrames[#UISpecialFrames + 1] = modName;

	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("INSPECT_READY");
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("UNIT_LEVEL");
	self:RegisterEvent("UNIT_MODEL_CHANGED");
	self:RegisterEvent("UNIT_NAME_UPDATE");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");

    ButtonFrameTemplate_HideButtonBar(self);
	PanelTemplates_SetNumTabs(self, 4);
	PanelTemplates_SetTab(self, 1); -- Character
	self.onUpdateTimer = 0;

	-- only show model controls when on first tab
	self.model:SetScript("OnEnter", function()
		local currentTab = PanelTemplates_GetSelectedTab(self);
		if (currentTab == 1) then
			self.model.controlFrame:Show();
		end
	end)

	-- only allow model rotation when on first tab
	self.model:SetScript("OnUpdate", function(_, elapsedTime, rotationsPerSecond)
		local currentTab = PanelTemplates_GetSelectedTab(self);
		if (currentTab == 1) then
			Model_OnUpdate(self.model, elapsedTime, rotationsPerSecond)
		end
	end)
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
	if (not UnitExists("target") or not self:IsVisible() or not (self.data and UnitGUID("target") ~= self.data.guid)) then
		return;
	end

	if (self.data.loading) then
		ClearInspectPlayer(self.data.guid);
	end

	self:Inspect();
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
	self:UpdateTalentTab();
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
	self:UpdateTalentTab();
	self:UpdateDetails();
end

function ExaminerMixin:Inspect()
	local unit = "target";

	if (not UnitExists(unit)) then
		unit = "player";
	end

	INSPECTED_UNIT = unit;

	local guid = UnitGUID(unit);
	local name, realm = UnitName(unit);
	local class, classFixed, classID = UnitClass(unit);
	local factionGroup, factionName = UnitFactionGroup(unit);

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

	local oldData = self.data;
	self.data = data;

	if (data.isPlayer) then
		data.race, data.raceFileName = UnitRace(unit);

		if (data.canInspect) then
			if (not data.isSelf) then
				data.loading = true;
				NotifyInspect(unit);
			else
				self:FetchHonorData();
			end

			self:FetchSpecialization();

			self:UpdateItemFrames();
			self:UpdateTalentTab();
			self:UpdatePVPTab();
			self:UpdateGuildTab();
		end

		local currentTab = PanelTemplates_GetSelectedTab(self);

		if (data.level < SHOW_TALENT_LEVEL and currentTab == 2) then
			self:SwitchTabs(1);
		end

		if (data.level < SHOW_PVP_TALENT_LEVEL and currentTab == 3) then
			self:SwitchTabs(1);
		end

		if (not data.guild and currentTab == 4) then
			self:SwitchTabs(1);
		end

		-- switch between npc and player
		if (oldData and oldData.guid and oldData.isPlayer ~= data.isPlayer) then
			self:SwitchTabs(1);
		end
	else
		data.race = UnitCreatureFamily(unit) or UnitCreatureType(unit);
		self:SwitchTabs(1);

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

	ShowUIPanel(self);

	if (InspectEquip) then
		InspectEquip:SetParent(self);
		InspectEquip_InfoWindow:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0);
		InspectEquip:Inspect(unit);
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
end

function ExaminerMixin:UpdateTalentTab()
	local data = self.data;

	if (not data.isPlayer) then
		return;
	end

	for tier=1, MAX_TALENT_TIERS do
		local tierFrame = self.talents["tier"..tier];
		if (tierFrame) then
			local tierAvailable, selectedTalent = GetTalentTierInfo(tier, data.specGroup, not data.isSelf, data.unit);
			local talentLevel = CLASS_TALENT_LEVELS[class] or CLASS_TALENT_LEVELS["DEFAULT"];
			tierFrame.level:SetText(talentLevel[tier] or "??");

			for column=1, NUM_TALENT_COLUMNS do
				local columnFrame = tierFrame["talent"..column];
				if (columnFrame) then
					local talentID, name, iconTexture, selected, available, _, _, _, _, _, grantedByAura = GetTalentInfo(tier, column, data.specGroup, not data.isSelf, data.unit);
					if (talentID) then
						columnFrame:SetID(talentID);
						SetItemButtonTexture(columnFrame, iconTexture);
						SetDesaturation(columnFrame.icon, not (selected or grantedByAura));
						columnFrame.border:SetShown(selected or grantedByAura);
						if (grantedByAura) then
							local color = ITEM_QUALITY_COLORS[LE_ITEM_QUALITY_LEGENDARY];
							columnFrame.border:SetVertexColor(color.r, color.g, color.b);
						else
							columnFrame.border:SetVertexColor(1, 1, 1);
						end
					end
				end
			end
		end
	end
end

-- from Blizzard_InspectUI/InspectPaperDollFrame.lua
local factionLogoTextures = {
	["Alliance"]	= "Interface\\Timer\\Alliance-Logo",
	["Horde"]		= "Interface\\Timer\\Horde-Logo",
	["Neutral"]		= "Interface\\Timer\\Panda-Logo",
};

function ExaminerMixin:FetchHonorData()
	local data = self.data;

	if (not data or not data.isPlayer or data.level < SHOW_PVP_TALENT_LEVEL) then
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

		for i=1, 4 do
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

	if (not data.isPlayer or data.level < SHOW_PVP_TALENT_LEVEL) then
		return;
	end

	-- Background
	if (data.factionGroup) then
		self.pvp.background:SetTexture(factionLogoTextures[data.factionGroup]);
		self.pvp.background:Show();
	else
		self.pvp.background:Hide();
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

	--local pointFrame = self.guild.Points;
	--pointFrame.SumText:SetText(data.guildPoints);
	--local width = pointFrame.SumText:GetStringWidth() + pointFrame.LeftCap:GetWidth() + pointFrame.RightCap:GetWidth() + pointFrame.Icon:GetWidth();
	--pointFrame:SetWidth(width);

	SetDoubleGuildTabardTextures(
		data.unit,
		self.guild.tabardLeftIcon,
		self.guild.tabardRightIcon,
		self.guild.banner,
		self.guild.bannerBorder
	);
end

function ExaminerMixin:UpdateTitle()
	self.title:SetText(self.data.pvpName or self.data.name);
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

	if (data.specName and data.specRole) then
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
		SetPortraitTexture(self.portrait, data.unit);
	else
		self.portrait:SetTexture(
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
	local isPlayer = data.isPlayer;

	if (data.loading) then
		self.Bg:SetVertexColor(0.5, 1, 0.5);
		self.Inset.Bg:SetVertexColor(0.5, 1, 0.5);
		self.TitleBg:SetVertexColor(0.5, 1, 0.5);
	else
		self.Bg:SetVertexColor(1, 1, 1);
		self.Inset.Bg:SetVertexColor(1, 1, 1);
		self.TitleBg:SetVertexColor(1, 1, 1);
	end

	self.items:SetShown(isPlayer);

	local TabSetShown = _G[isPlayer and "PanelTemplates_ShowTab" or "PanelTemplates_HideTab"];
	TabSetShown(self, 1); -- Character
	TabSetShown(self, 2); -- Talents
	TabSetShown(self, 3); -- PvP
	TabSetShown(self, 4); -- Guild

	if (isPlayer) then
		TabSetEnable(self, 2, data.level >= SHOW_TALENT_LEVEL); -- Talents
		TabSetEnable(self, 3, data.level >= SHOW_PVP_TALENT_LEVEL); -- PvP
		TabSetEnable(self, 4, data.guild); -- Guild
	end

	self.ej:SetShown(not isPlayer and data.hasLoot);
end

function ExaminerMixin:SwitchTabs(id)
	local isPlayer = self.data.isPlayer;

	PanelTemplates_SetTab(self, id);

	self.model:SetAlpha(id ~= 1 and 0.2 or 1);
	self.talents:SetShown(isPlayer and id == 2);
	self.pvp:SetShown(isPlayer and id == 3);
	self.guild:SetShown(isPlayer and id == 4);
end

function ExaminerMixin:OpenJournal()
	local data = self.data;

	if (not data.isPlayer and data.hasLoot) then
		EncounterJournal_LoadUI();
		EncounterJournal_OpenJournal(nil, data.instanceID, data.encounterID);
	end
end
