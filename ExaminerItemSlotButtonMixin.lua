local LibItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")

ExaminerItemSlotButtonMixin = {}

function ExaminerItemSlotButtonMixin:OnLoad()
    self.slotName = strsub(self:GetName(), 9);
	local id, texture = GetInventorySlotInfo(self.slotName);
	self:SetID(id);
    SetItemButtonTexture(self, texture);
	self.backgroundTextureName = texture;
end

function ExaminerItemSlotButtonMixin:OnClick(button)
	if (CursorHasItem()) then
		self:OnDrag();
		return;
	end

    local data = Examiner.data;

    if (not data or not self.link) then
        return;
    end

	if (IsModifiedClick("EXPANDITEM")) then
        if (data.isSelf) then
            local itemLocation = ItemLocation:CreateFromEquipmentSlot(self:GetID());
            if C_Item.DoesItemExist(itemLocation) and self.isAzeriteEmpoweredItem then
                OpenAzeriteEmpoweredItemUIFromItemLocation(itemLocation);
                return;
            end
        end
		if (self.link and self.azeritePowerIDs and self.isAzeriteEmpoweredItem) then
			OpenAzeriteEmpoweredItemUIFromLink(self.link, data.classID, self.azeritePowerIDs);
			return;
		end

        SocketInventoryItem(self:GetID());
		return;
	end

	if (HandleModifiedItemClick(self.link)) then
		return;
	end

	self:OnDrag();
end

function ExaminerItemSlotButtonMixin:OnUpdate()
    CursorOnUpdate(self);
end

function ExaminerItemSlotButtonMixin:OnEnter()
    local data = Examiner.data;

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

    if (data and data.unit and (UnitExists(data.unit) or UnitGUID(data.unit) == data.guid) and GameTooltip:SetInventoryItem(data.unit, self:GetID())) then
	    CursorUpdate(self);
        return;
	end

    if (self.link) then
        GameTooltip:SetHyperlink(self.link, data.classID, data.specID);
	    CursorUpdate(self);
        return;
    end

    GameTooltip:SetText(_G[strupper(self.slotName)]);
	CursorUpdate(self);
end

function ExaminerItemSlotButtonMixin:OnLeave()
	if (GameTooltip:IsOwned(self)) then
		GameTooltip:Hide();
	end
    ResetCursor();
end

function ExaminerItemSlotButtonMixin:OnDrag()
    local data = Examiner.data;

	if (data and data.isSelf) then
		PickupInventoryItem(self:GetID());
	end
end

function ExaminerItemSlotButtonMixin:Update()
    local data = Examiner.data;

    if (not data or not data.unit) then
        return;
    end

    local unit = data.unit;
    local id = self:GetID();

    self.isAzeriteItem = false;
    self.isAzeriteEmpoweredItem = false;
    self.azeritePowerLevel = nil;
    self.azeritePowerIDs = nil;
    self.hasAnyUnselectedPowers = false;

    local textureName = GetInventoryItemTexture(unit, id);
    if (textureName) then
        SetItemButtonTexture(self, textureName);
        SetItemButtonCount(self, GetInventoryItemCount(unit, id));
        self.hasItem = true;

        self.link = GetInventoryItemLink(unit, id);
        self.level:SetText(LibItemUpgradeInfo:GetUpgradedItemLevel(self.link));

        if (data.isSelf) then
            local itemLocation = ItemLocation:CreateFromEquipmentSlot(self:GetID());

            if (itemLocation and itemLocation:HasAnyLocation()) then
                self.isAzeriteItem = C_AzeriteItem.IsAzeriteItem(itemLocation);
                self.isAzeriteEmpoweredItem = C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLocation);
                if (self.isAzeriteItem) then
                    self.azeritePowerLevel = C_AzeriteItem.GetPowerLevel(itemLocation);
                end
                if (self.isAzeriteEmpoweredItem) then
                    self.hasAnyUnselectedPowers = C_AzeriteEmpoweredItem.HasAnyUnselectedPowers(itemLocation);
                end
            end
        elseif (self.link) then
            self.isAzeriteItem = C_AzeriteItem.IsAzeriteItemByID(self.link);
            self.isAzeriteEmpoweredItem = C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(self.link);
            self.azeritePowerIDs = C_PaperDollInfo.GetInspectAzeriteItemEmpoweredChoices(unit, self:GetID());
        end
    else
        SetItemButtonTexture(self, self.backgroundTextureName);
        SetItemButtonCount(self, 0);
        self.IconBorder:Hide();
        self.hasItem = nil;
        self.link = nil;
        self.level:SetText("");
    end

    local quality = GetInventoryItemQuality(unit, id);
    SetItemButtonQuality(self, quality, GetInventoryItemID(unit, id), self.HasPaperDollAzeriteItemOverlay);

    self:SetAzeriteItem(self);

	if (GameTooltip:IsOwned(self)) then
		GameTooltip:Hide();
	end
end
