BINDING_HEADER_EXAMINER = "Examiner";
BINDING_NAME_EXAMINER_OPEN = "Open Examiner";

ExaminerMixin = {};

function ExaminerMixin:OnLoad()
	UIPanelWindows[self:GetName()] = { area = "left", pushable = 3, whileDead = 1 };
    --UISpecialFrames[#UISpecialFrames + 1] = modName;

	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UNIT_MODEL_CHANGED");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("UNIT_LEVEL");
	self:RegisterEvent("UNIT_NAME_UPDATE");
	self:RegisterEvent("INSPECT_READY");
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
    -- self:RegisterEvent("INSPECT_HONOR_UPDATE");

    ButtonFrameTemplate_HideButtonBar(self);
	PanelTemplates_SetNumTabs(self, 4);
	PanelTemplates_SetTab(self, 1); -- Character
	self.onUpdateTimer = 0;
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

	self:UpdateItems();
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

	self:UpdatePortraitFrame();
end

function ExaminerMixin:UNIT_LEVEL(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self.data.level = UnitLevel(unit) or -1;
	self.data.effectiveLevel = UnitEffectiveLevel(unit) or -1;

	self:UpdateDetailFrame();
end

function ExaminerMixin:UNIT_NAME_UPDATE(unit)
	if (not self:ShouldHandleEvent(UnitGUID(unit))) then
		return;
	end

	self.data.name, self.data.realm = UnitName(unit);
	self.data.pvpName = UnitPVPName(unit);

	self:UpdateTitleFrame();
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

	self:UpdateSpecialization();
	self:UpdateTalents();
	self:UpdateDetailFrame();
	self:UpdateItems();
	self:UpdateFrames();
end

function ExaminerMixin:PLAYER_SPECIALIZATION_CHANGED()
	if (not self:ShouldHandleEvent(UnitGUID("player"))) then
		return;
	end

	self:UpdateSpecialization();
	self:UpdateTalents();
	self:UpdateDetailFrame();
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

		npcID = guid and tonumber(guid:match("-(%d+)-%x+$"), 10) or nil,
		hasLoot = false,
		loot = {},
	};

	local oldData = self.data;
	self.data = data;

	if (data.isPlayer) then
		data.race, data.raceFileName = UnitRace(unit);

		if (data.canInspect) then
			if (not data.isSelf) then
				data.loading = true;
				NotifyInspect(unit);
			end

			self:UpdateItems();
			self:UpdateSpecialization();
			self:UpdateTalents();
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

	self:UpdateTitleFrame();
	self:UpdateDetailFrame();
	self:UpdatePortraitFrame();
	self:UpdateModel();
	self:UpdateFrames();

	ShowUIPanel(self);

	if (InspectEquip) then
		InspectEquip:SetParent(self);
		InspectEquip_InfoWindow:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0);
		InspectEquip:Inspect(unit);
	end
end

function ExaminerMixin:UpdateSpecialization()
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

function ExaminerMixin:UpdateItems()
	if (not self.data.isPlayer) then
		return;
	end

	local itemButtonFrames = { self.items:GetChildren() };
	for _, button in ipairs(itemButtonFrames) do
		button:Update();
	end
end

function ExaminerMixin:UpdateTalents()
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

function ExaminerMixin:UpdateTitleFrame()
	self.title:SetText(self.data.pvpName or self.data.name);
end

function ExaminerMixin:UpdateDetailFrame()
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

function ExaminerMixin:UpdatePortraitFrame()
	local unit = self.data.unit;

	if (UnitIsVisible(unit)) then
		SetPortraitTexture(self.portrait, unit);
	else
		self.portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-"..(self.data.sex == 3 and "Female" or "Male").."-"..(self.data.raceFileName or ""));
	end
end

function ExaminerMixin:UpdateModel()
	local isVisible = UnitIsVisible(self.data.unit);

	if (isVisible) then
		self.model:SetUnit(self.data.unit);
		local race, fileName = UnitRace(self.data.unit);
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

local function GetTabByIndex(frame, index)
	return frame.Tabs and frame.Tabs[index] or _G[frame:GetName().."Tab"..index];
end

local function TabSetEnable(frame, index, state)
	local tab = GetTabByIndex(frame, index);
	(state and PanelTemplates_EnableTab or PanelTemplates_DisableTab)(frame, index);
end

function ExaminerMixin:UpdateFrames()
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
		TabSetEnable(self, 3, false); --data.level >= SHOW_PVP_TALENT_LEVEL); -- PvP, TODO
		TabSetEnable(self, 4, false); --data.guild); -- Guild, TODO
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
