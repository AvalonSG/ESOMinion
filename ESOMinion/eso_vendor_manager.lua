--:===============================================================================================================
--: eso_vendor_manager
--:===============================================================================================================

eso_vendor_manager = {}

--:===============================================================================================================
--: profile: initialize
--:===============================================================================================================  
--: loads profile, and alternately, creates a blank profile, in case the default profile can't be found

function eso_vendor_manager:InitializeProfile()

	local blankprofile 		= {}
	blankprofile.itemtypes 	= {}
	blankprofile.qualities 	= {}
	blankprofile.data 		= {}
	
	local function nonzero(number)
		return number ~= 0
	end
	
	local itemtypes,excludeditemtypes = ITEMTYPES,ITEMTYPES_EXCLUDE
	local qualities,excludedqualities = ITEMQUALITIES,ITEMQUALITIES_EXCLUDE
	
	local itemtype,index = next(itemtypes)
	while itemtype and index do
		if not blankprofile.itemtypes[index] and nonzero(index) then
			blankprofile.itemtypes[index] 			= {}
			blankprofile.itemtypes[index].id 		= index
			blankprofile.itemtypes[index].name 		= itemtype
			blankprofile.itemtypes[index].label 	= eso_vendor_manager:CreateLabel(itemtype)
			blankprofile.itemtypes[index].show		= not excludeditemtypes[itemtype]
		end
		
		if not blankprofile.data[index] and nonzero(index) then
			blankprofile.data[index] = {}
		end
			
		local quality,qindex = next(qualities)
		while quality and qindex do
			if not blankprofile.qualities[qindex] and nonzero(qindex) then
				blankprofile.qualities[qindex] 			= {}
				blankprofile.qualities[qindex].id 		= qindex
				blankprofile.qualities[qindex].name 	= quality
				blankprofile.qualities[qindex].label 	= eso_vendor_manager:CreateLabel(quality)
				blankprofile.qualities[qindex].show		= not excludedqualities[quality]
			end
			if nonzero(index) and nonzero(qindex) then
				blankprofile.data[index][qindex] = false
			end
			quality,qindex = next(qualities,quality)
		end
		itemtype,index = next(itemtypes,itemtype)
	end
	
	local loadedprofile,error = persistence.load(eso_vendor_manager.profilepath .. "vendor.profile")
	
	if error or not ValidTable(loadedprofile) then
		local error = persistence.store(eso_vendor_manager.profilepath .. "vendor.profile", blankprofile)
	end

	return loadedprofile or blankprofile
end

--:===============================================================================================================
--: profile: save
--:===============================================================================================================  

function eso_vendor_manager.SaveProfile()
	if ValidTable(eso_vendor_manager.profile) then
		local err = persistence.store(eso_vendor_manager.profilepath .. "vendor.profile", eso_vendor_manager.profile)
		if err then
			d("VendorManager : Error Saving Profile -> " .. tostring(err))
		end
	end
	d("VendorManager : Profile saved")
end

--:===============================================================================================================
--: gui: initialize
--:===============================================================================================================  

function eso_vendor_manager.InitializeGui() 
		
	local window = { name = "VendorManager", coords = {270,50,250,350}, visible = false }
	local section = "ItemType"
	
	GUI_NewWindow(window.name, unpack(window.coords))
	GUI_NewComboBox(window.name, " Type", "vmItemTypeFilter", section, "")
	--GUI_NewButton(window.name, "Save Profile", "eso_vendor_manager.SaveProfile")
	--RegisterEventHandler("eso_vendor_manager.SaveProfile", eso_vendor_manager.SaveProfile)

	if ValidTable(eso_vendor_manager.profile) then
		local itemtypes = eso_vendor_manager.profile.itemtypes
		table.sort(itemtypes, function(a,b) return a.id < b.id end)
		local listitems = ""
		for index,itemtype in ipairs(itemtypes) do
			if itemtype.show == true then
				listitems = listitems .. itemtype.label .. ","
			end
		end
		listitems = listitems .. ", "
		vmItemTypeFilter_listitems = listitems
	end
	
	GUI_UnFoldGroup(window.name,"ItemType")
	GUI_WindowVisible(window.name, window.visible)
	return window
end

--:===============================================================================================================
--: gui: toggle
--:===============================================================================================================  

function eso_vendor_manager.OnGuiToggle()
	eso_vendor_manager.window.visible = not eso_vendor_manager.window.visible
	GUI_WindowVisible(eso_vendor_manager.window.name, eso_vendor_manager.window.visible)
end

--:===============================================================================================================
--: gui: vars update
--:===============================================================================================================  

function eso_vendor_manager.OnGuiVarUpdate(event,data,...)
	for key,value in pairs(data) do
	
		if key == "vmItemTypeFilter" then
			eso_vendor_manager.OnNewItemTypeSelected(value)
		end
		
		if key:find("VendorManager") then
			local handler = assert(loadstring("return " .. key))()
			
			if type(handler) == "table" then
				if eso_vendor_manager.profile then
					local itemtype 	= handler.itemtype
					local quality	= handler.quality
					local ilabel	= eso_vendor_manager.profile.itemtypes[itemtype].label
					local qlabel	= eso_vendor_manager.profile.qualities[quality].label
					
					local old = eso_vendor_manager.profile.data[handler.itemtype][handler.quality]
					local new = value == "1"
					eso_vendor_manager.profile.data[handler.itemtype][handler.quality] = new
					
					local debugstr = "VendorManager : " .. ilabel .. " (" .. qlabel .. ") -> " ..
					tostring(eso_vendor_manager.profile.data[handler.itemtype][handler.quality])
					d(debugstr)
					eso_vendor_manager.SaveProfile()
				end
			end
		end
	end
end

--:===============================================================================================================
--: gui: new item type
--:===============================================================================================================  
--: new item type was selected from the combobox, updating checkboxes accordingly

function eso_vendor_manager.OnNewItemTypeSelected(itemtypelabel)

	if eso_vendor_manager.profile and eso_vendor_manager.profile.itemtypes then
		local newitemtype = nil
		local itemtypes = eso_vendor_manager.profile.itemtypes
		local qualities = eso_vendor_manager.profile.qualities
		local index,itemtype = next(itemtypes)
		
		while index and itemtype do
			if itemtype.label == itemtypelabel then
				newitemtype = index
				break
			end
			index,itemtype = next(itemtypes,index)
		end
		
		if newitemtype then
			GUI_DeleteGroup("VendorManager", "ItemQuality")
			table.sort(qualities, function(a,b) return a.id < b.id end)
			
			for index,quality in ipairs(qualities) do
				if quality.show then
					local handler = "{ " ..
						"module = VendorManager, " ..
						"itemtype = " .. tostring(newitemtype) .. ", " ..
						"quality  = " .. tostring(index) .. " }"
					GUI_NewCheckbox("VendorManager", " " .. quality.label, handler, "ItemQuality")
					
					if 	eso_vendor_manager.profile.data[newitemtype] then
						local checked = "0"
						if eso_vendor_manager.profile.data[newitemtype][index] == true then
							checked = "1"
						end
						_G[handler] = checked
					end
				end
			end
			GUI_UnFoldGroup("VendorManager", "ItemQuality")
		end
	end
end

--:===============================================================================================================
--: create label
--:===============================================================================================================
--: cleans then _G keys ie, "ITEMTYPE_GLYPH_WEAPON" returns "GlyphWeapon"

function eso_vendor_manager:CreateLabel(label)
	label = string.gsub(label,"ITEMTYPE_","")
	label = string.gsub(label,"ITEM_QUALITY_","")
	label = string.gsub(label,"ENCHANTING_","")
	label = string.gsub(label,"_"," ")
	label = string.gsub(" " .. string.lower(label), "%W%l", string.upper):sub(2)
	label = string.gsub(label," ", "")
	return label
end

--:===============================================================================================================
--: constants
--:===============================================================================================================  

ITEMTYPES = {
	ITEMTYPE_NONE = 0,
	ITEMTYPE_WEAPON = 1,
	ITEMTYPE_ARMOR = 2,
	ITEMTYPE_PLUG = 3,
	ITEMTYPE_FOOD = 4,
	ITEMTYPE_TROPHY = 5,
	ITEMTYPE_SIEGE = 6,
	ITEMTYPE_POTION = 7,
	ITEMTYPE_RACIAL_STYLE_MOTIF = 8,
	ITEMTYPE_TOOL = 9,
	ITEMTYPE_INGREDIENT = 10,
	ITEMTYPE_ADDITIVE = 11,
	ITEMTYPE_DRINK = 12,
	ITEMTYPE_COSTUME = 13,
	ITEMTYPE_DISGUISE = 14,
	ITEMTYPE_TABARD = 15,
	ITEMTYPE_LURE = 16,
	ITEMTYPE_RAW_MATERIAL = 17,
	ITEMTYPE_CONTAINER = 18,
	ITEMTYPE_SOUL_GEM = 19,
	ITEMTYPE_GLYPH_WEAPON = 20,
	ITEMTYPE_GLYPH_ARMOR = 21,
	ITEMTYPE_LOCKPICK = 22,
	ITEMTYPE_WEAPON_BOOSTER = 23,
	ITEMTYPE_ARMOR_BOOSTER = 24,
	ITEMTYPE_ENCHANTMENT_BOOSTER = 25,
	ITEMTYPE_GLYPH_JEWELRY = 26,
	ITEMTYPE_SPICE = 27,
	ITEMTYPE_FLAVORING = 28,
	ITEMTYPE_RECIPE = 29,
	ITEMTYPE_POISON = 30,
	ITEMTYPE_REAGENT = 31,
	ITEMTYPE_DEPRECATED = 32,
	ITEMTYPE_ALCHEMY_BASE = 33,
	ITEMTYPE_COLLECTIBLE = 34,
	ITEMTYPE_BLACKSMITHING_RAW_MATERIAL = 35,
	ITEMTYPE_BLACKSMITHING_MATERIAL = 36,
	ITEMTYPE_WOODWORKING_RAW_MATERIAL = 37,
	ITEMTYPE_WOODWORKING_MATERIAL = 38,
	ITEMTYPE_CLOTHIER_RAW_MATERIAL = 39,
	ITEMTYPE_CLOTHIER_MATERIAL = 40,
	ITEMTYPE_BLACKSMITHING_BOOSTER = 41,
	ITEMTYPE_WOODWORKING_BOOSTER = 42,
	ITEMTYPE_CLOTHIER_BOOSTER = 43,
	ITEMTYPE_STYLE_MATERIAL = 44,
	ITEMTYPE_ARMOR_TRAIT = 45,
	ITEMTYPE_WEAPON_TRAIT = 46,
	ITEMTYPE_AVA_REPAIR = 47,
	ITEMTYPE_TRASH = 48,
	ITEMTYPE_SPELLCRAFTING_TABLET = 49,
	ITEMTYPE_MOUNT = 50,
	ITEMTYPE_ENCHANTING_RUNE_POTENCY = 51,
	ITEMTYPE_ENCHANTING_RUNE_ASPECT = 52,
	ITEMTYPE_ENCHANTING_RUNE_ESSENCE = 53,
}

ITEMTYPES_EXCLUDE = {
	ITEMTYPE_NONE = 0,					--nothing
	ITEMTYPE_PLUG = 3,					--nothing
	ITEMTYPE_SIEGE = 6,					--soulbound
	ITEMTYPE_RACIAL_STYLE_MOTIF = 8,	--protected
	ITEMTYPE_TOOL = 9,					--protected
	ITEMTYPE_ADDITIVE = 11,				--nothing
	ITEMTYPE_TABARD = 15,				--soulbound
	ITEMTYPE_SOUL_GEM = 19,				--protected
	ITEMTYPE_LOCKPICK = 22,				--protected
	ITEMTYPE_WEAPON_BOOSTER = 23,		--nothing
	ITEMTYPE_ARMOR_BOOSTER = 24,		--nothing
	ITEMTYPE_ENCHANTMENT_BOOSTER = 25,	--nothing
	ITEMTYPE_SPICE = 27,				--nothing
	ITEMTYPE_FLAVORING = 28,			--nothing
	ITEMTYPE_POISON = 30,				--nothing
	ITEMTYPE_DEPRECATED = 32,			--nothing
	ITEMTYPE_BLACKSMITHING_BOOSTER = 41,--tempers(protected)
	ITEMTYPE_WOODWORKING_BOOSTER = 42,	--tanins(protected)
	ITEMTYPE_CLOTHIER_BOOSTER = 43,		--resins(protected)
	ITEMTYPE_AVA_REPAIR = 47,			--soulbound
	ITEMTYPE_TRASH = 48,				--nothing
	ITEMTYPE_SPELLCRAFTING_TABLET = 49,	--nothing
	ITEMTYPE_MOUNT = 50,				--soulbound
}

ITEMQUALITIES = {
	ITEM_QUALITY_TRASH = 0,
	ITEM_QUALITY_NORMAL = 1,
	ITEM_QUALITY_MAGIC = 2,
	ITEM_QUALITY_ARCANE = 3,
	ITEM_QUALITY_ARTIFACT = 4,
	ITEM_QUALITY_LEGENDARY = 5,
}

ITEMQUALITIES_EXCLUDE = {
	ITEM_QUALITY_TRASH = 0,				--nothing
	ITEM_QUALITY_LEGENDARY = 5,			--only ferenz vendors handmade legendaries
}

--:===============================================================================================================
--: module: initialize
--:===============================================================================================================  

function eso_vendor_manager.Initialize() 
	eso_vendor_manager.profilepath = GetStartupPath() .. [[\LuaMods\ESOMinion\SharedProfiles\]];
	eso_vendor_manager.profile = eso_vendor_manager:InitializeProfile()
	eso_vendor_manager.window  = eso_vendor_manager.InitializeGui() 
end

--:===============================================================================================================
--: register event handlers
--:===============================================================================================================  

RegisterEventHandler("eso_vendor_manager.OnGuiToggle", eso_vendor_manager.OnGuiToggle)
RegisterEventHandler("GUI.Update", eso_vendor_manager.OnGuiVarUpdate)
RegisterEventHandler("Module.Initalize", eso_vendor_manager.Initialize)
