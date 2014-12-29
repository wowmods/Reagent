local _, FH = ...
local L = FH.L

local msq, msqGroups = nil, {}
if LibStub then
	msq = LibStub("Masque",true)
	if msq then
		msqGroups = {
			FarmhandTools = msq:Group("Farmhand","Tools"),
			FarmhandSeeds = msq:Group("Farmhand","Seeds"),
			FarmhandPortals = msq:Group("Farmhand","Portals"),
		}
	end
end

local function NewFarmhandButton(Name,Parent,ItemID,ItemType)
	--print(Name,Parent,ItemID)
	local f = CreateFrame("Button", Name, Parent, "SecureActionButtonTemplate")
	f:SetSize(32,32)
	f:SetPushedTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	f:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]],"ADD")
	f.Icon = f:CreateTexture(Name.."Icon","BACKGROUND")
	f.Icon:SetDrawLayer("BACKGROUND",0)
	f.Icon:SetAllPoints()
	f.SmallIcon = f:CreateTexture(Name.."SmallIcon","BACKGROUND")
	f.SmallIcon:SetDrawLayer("BACKGROUND",1)
	f.SmallIcon:SetPoint("BOTTOMRIGHT",f.Icon,"CENTER",-4,4)
	f.SmallIcon:SetSize(12,12)
	
	f.Count = f:CreateFontString(Name.."Count","ARTWORK","NumberFontNormal")
	f.Count:SetJustifyH("RIGHT")
	f.Count:SetPoint("BottomRight",-2,2)
	
	f.ItemType = ItemType

	f:RegisterForClicks("AnyUp","AnyDown")

	if ItemID then
		f.ItemID = ItemID
		f:SetAttribute("downbutton","ignore")
		f:SetAttribute("*type-ignore", "")
		f:SetAttribute("type","item")
		f:SetAttribute("item","item:"..ItemID)
		f:SetScript("PreClick", Farmhand_ItemPreClick)
		f:SetScript("PostClick", Farmhand_ItemPostClick)
	end
	
	f:SetScript("OnEnter", Farmhand_ItemOnEnter)
	f:SetScript("OnLeave", Farmhand_ItemOnLeave)

	f:SetScript("OnMouseDown", Farmhand_ButtonOnMouseDown)
	f:SetScript("OnMouseUp", Farmhand_ButtonOnMouseUp)
	f:SetScript("OnHide", Farmhand_ButtonOnHide)
	
	return f
end

local function CreateBarButtons(Bar, Items, ItemType)
	if Bar.Buttons == nil then
		Bar.Buttons = {}
	end
	local Buttons = Bar.Buttons
	local indexOffset = #Buttons
	for Index, ItemID in ipairs(Items) do
		--print(Index,ItemID)
		Index = Index + indexOffset
		local Button = NewFarmhandButton(Bar:GetName().."Button"..Index, Bar, ItemID, ItemType)
		tinsert(Buttons,Button)
		
		if msqGroups[Bar:GetName()] then
			msqGroups[Bar:GetName()]:AddButton(Button)
		end

	end
	return Buttons
end

local function NewMacroButton(Step, SubStep, MacroText)
	--print("Creating ".."FHSBE_"..Step.."_"..SubStep)
	local f = CreateFrame("Button", "FHSBE_"..Step.."_"..SubStep, FarmhandScanButton, "SecureActionButtonTemplate")
	f:SetSize(32,32)
	f:RegisterForClicks("AnyUp","AnyDown")
	f:SetAttribute("type", "macro")
	f:SetAttribute("macrotext", MacroText)
	f:Hide()
	return f
end

local f = CreateFrame("Frame","Farmhand",UIParent)
f:SetDontSavePosition(true)
f:SetClampedToScreen(true)
f:SetMovable(true)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent",function(self,event,...)
	if event == "ADDON_LOADED" then
		local AddOn = ...
		if AddOn == "Farmhand" then
--			f:RegisterEvent("GET_ITEM_INFO_RECEIVED ")
			Farmhand_UpdateMiscToolOptionText()
			Farmhand_RunAfterCombat(Farmhand_Initialize)
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		Farmhand_RunAfterCombat(Farmhand_ZoneChanged)
	elseif event == "ZONE_CHANGED_NEW_AREA" or
		   event == "ZONE_CHANGED" or 
		   event == "ZONE_CHANGED_INDOORS" then
		Farmhand_RunAfterCombat(Farmhand_ZoneChanged)
	elseif event == "BAG_UPDATE" then
		Farmhand_RunAfterCombat(Farmhand_Update)
	elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
		if self:IsShown() then
			Farmhand_RunAfterCombat(Farmhand_MerchantEvent,{event == "MERCHANT_SHOW"})
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		Farmhand_CombatEnded()
	elseif event == "BAG_UPDATE_COOLDOWN" then
		Farmhand_UpdateSeedBagCharges()
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		Farmhand_UpdateMiscToolOptionText()
		Farmhand_UpdateButtonIcons(FarmhandSeeds)
	end
end)

f = CreateFrame("Frame","FarmhandSeeds",Farmhand)
f:SetPoint("Top")
f:SetScale(1)
f:Hide()
CreateBarButtons(f, FH.Seeds, "Seed")
CreateBarButtons(f, FH.SeedBags, "SeedBag")
f.ShowItemCount = true

f = CreateFrame("Frame","FarmhandTools",Farmhand)
f:SetPoint("Top",FarmhandSeeds,"Bottom")
f:SetScale(1.5)
f:Hide()
CreateBarButtons(f, FH.Tools, "FarmTool")
CreateBarButtons(f, FH.MiscTools, "MiscTool")

f = CreateFrame("Frame","FarmhandPortals",Farmhand)
f:SetPoint("Top",FarmhandTools,"Bottom")
f:SetScale(.75)
f:Hide()
CreateBarButtons(f, FH.Portals, "Portal")
f.ShowItemCount = true

f = NewFarmhandButton("FarmhandScanButton",FarmhandTools)
f.Icon:SetTexture([[Interface\AddOns\Farmhand\RadarIcon.tga]])
f.ItemType = "CropScanner"
tinsert(FarmhandTools.Buttons,f)

for Step, State in ipairs(FH.CropStates) do
	local SubStep = 1
	local MacroText = "/cleartarget\n"
	local IconLine = "/run if UnitExists(\"target\") and GetRaidTargetIndex(\"target\") ~= "..State.Icon.." then SetRaidTarget(\"target\","..State.Icon..") end\n"

	local Lines = { strsplit("\n", gsub(State.CropNames,"\r","")) }
	for i,line in ipairs(Lines) do
		line = "/tar "..strtrim(line).."\n"
		if strlen(MacroText) + strlen(line) + strlen(IconLine) + strlen("/click FHSBE_9999_9999\n") > 1023 then
			MacroText = MacroText..format("/click FHSBE_%d_%d\n",Step,SubStep+1)
			NewMacroButton(Step, SubStep, MacroText)
			SubStep = SubStep + 1
			MacroText = ""
		end
		MacroText = MacroText..line
	end
	MacroText = MacroText..IconLine
	MacroText = MacroText..format("/click FHSBE_%d_%d\n",Step+1,1)
	local f = NewMacroButton(Step, SubStep, MacroText)
	if Step > 1 then
		f:SetScript("PreClick", function() Farmhand_CropScannerCheckForTarget(false) end)
	end
	if Step == #FH.CropStates then
		f:SetScript("PostClick", function() Farmhand_CropScannerCheckForTarget(false) end)
	end
end

f:SetAttribute("downbutton","ignore")
f:SetAttribute("type", "click")
f:SetAttribute("clickbutton", FHSBE_1_1)
f:SetAttribute("*type-ignore", "")

f:SetScript("PreClick", Farmhand_CropScannerPreClick)
f:SetScript("PostClick",Farmhand_CropScannerPostClick)
f:SetScript("OnEnter", Farmhand_ScanButtonOnEnter)
f:SetScript("OnLeave", Farmhand_ScanButtonOnLeave)

f:SetScript("OnMouseDown", Farmhand_ButtonOnMouseDown)
f:SetScript("OnMouseUp", Farmhand_ButtonOnMouseUp)
f:SetScript("OnHide", Farmhand_ButtonOnHide)

f.ScannerOutput = {}

if msqGroups["FarmhandTools"] then
	msqGroups["FarmhandTools"]:AddButton(f)
end

f = CreateFrame("Frame","FarmhandOptionsPanel",nil)
f.name = "Farmhand"
InterfaceOptions_AddCategory(f)

f = CreateFrame("CheckButton","FarmhandToolsLockOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",50,-50)
f:SetScript("OnClick",function(self) Farmhand_SetLockToolsOption(self:GetChecked()) end)
FarmhandToolsLockOptionText:SetText(L["Lock tools to prevent them being dropped when you leave the farm."])

f = CreateFrame("CheckButton","FarmhandMessagesOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandToolsLockOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_SetMessagesOption(self:GetChecked()) end)
FarmhandMessagesOptionText:SetText(L["Show crop scanner findings in the chat window."])

f = CreateFrame("CheckButton","FarmhandSoundsOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandMessagesOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_SetSoundsOption(self:GetChecked()) end)
FarmhandSoundsOptionText:SetText(L["Play sounds when crop scanner finishes."])

f = CreateFrame("CheckButton","FarmhandPortalsOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandSoundsOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetPortalsOption,{self:GetChecked()}) end)
FarmhandPortalsOptionText:SetText(L["Show Portal Shard icons below the tools buttons."])

f = CreateFrame("CheckButton","FarmhandHideInCombatOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandPortalsOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetHideInCombatOption,{self:GetChecked()}) end)
FarmhandHideInCombatOptionText:SetText(L["Hide Farmhand entirely during combat."])

f = CreateFrame("CheckButton","FarmhandStockTipOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandHideInCombatOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetStockTipOption,{self:GetChecked()}) end)
FarmhandStockTipOptionText:SetText(L["Show special tooltip for vegetable seeds in merchant window."])

f = CreateFrame("Frame", "FarmhandStockTipPositionDropdown", FarmhandOptionsPanel, "UIDropDownMenuTemplate")
f:SetPoint("TopLeft",FarmhandStockTipOption,"Bottomleft",10,0)
UIDropDownMenu_SetWidth(f, 300)
UIDropDownMenu_JustifyText(f,"LEFT")
UIDropDownMenu_Initialize(f, Farmhand_InitializeStockTipDropdown)
Farmhand.StockTipPositionDropdown = f

f = CreateFrame("GameTooltip","FarmhandMerchantStockTip",Farmhand,"GameTooltipTemplate")
Farmhand.StockTip = f

f = CreateFrame("CheckButton","FarmhandSeedIconOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandStockTipOption,"Bottomleft",0,-45)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetSeedIconOption,{self:GetChecked()}) end)
FarmhandSeedIconOptionText:SetText(L["Show Vegetable Icon on Seed Buttons"])

f = CreateFrame("CheckButton","FarmhandBagIconOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandSeedIconOption,"Bottomleft",0,0)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetBagIconOption,{self:GetChecked()}) end)
FarmhandBagIconOptionText:SetText(L["Show Vegetable Icon on Seed Bag Buttons"])

f = CreateFrame("CheckButton","FarmhandMiscToolsOption",FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
f:SetPoint("TopLeft",FarmhandBagIconOption,"Bottomleft",0,-15)
f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetMiscToolsOption,{self:GetChecked()}) end)
FarmhandMiscToolsOptionText:SetText(L["Show Optional Miscellaneous Tools"])

local LastTool
for _,v in ipairs(FH.MiscTools) do
	f = CreateFrame("CheckButton","FarmhandMiscToolsOption"..v,FarmhandOptionsPanel,"OptionsCheckButtonTemplate")
	f:SetPoint("TopLeft",LastTool or FarmhandMiscToolsOption,"Bottomleft",LastTool == nil and 20 or 0, 0)
	f:SetScript("OnClick",function(self) Farmhand_RunAfterCombat(Farmhand_SetMiscToolsOption,{self:GetChecked(), v}) end)
	f:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetHyperlink("item:"..v)
		GameTooltip:Show()
	end)
	LastTool = f
end

function Farmhand_UpdateMiscToolOptionText()
	for _,v in ipairs(FH.MiscTools) do
		local Txt = _G["FarmhandMiscToolsOption"..v.."Text"]
		if Txt:GetText() == nil then
			local ToolName, ToolLink, _, _, _, _, _, _, _, ToolIcon = GetItemInfo(v)
			if ToolName ~= nil then
				Txt:SetText(format("|T%s:0|t %s",ToolIcon,ToolLink))
			end
		end
	end
end

f = CreateFrame("GameTooltip","FarmhandScanningTooltip",nil,"GameTooltipTemplate")
f:SetOwner( WorldFrame, "ANCHOR_NONE" );
f.ScanningTooltip = f
