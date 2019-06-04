--[[
	Omni Cooldown Count
		A universal cooldown count, based on Gello's spec
		Lightweight version for WoW 1.12.1 modified by kebabstorm
		v1.3.3.7
--]]

--[[
	Saved Variables
		These values are reloaded from saved variables if the user already has saved settings.
--]]

OmniCC = {
	size = 18,
	shine = 1
}

--constants!
local DAY, HOUR, MINUTE = 86400, 3600, 60 --used for formatting text
local DAYISH, HOURISH, MINUTEHALFISH, MINUTEISH, SOONISH = 3600 * 23.5, 60 * 59.5, 89.5, 59.5, 5.5 --used for formatting text at transition points
local HALFDAYISH, HALFHOURISH, HALFMINUTEISH = DAY/2 + 0.5, HOUR/2 + 0.5, MINUTE/2 + 0.5 --used for calculating next update times
local SHINESCALE = 4;
local MIN_DURATION = 3;
local YELLOW = "|c00FFFF00";

--local bindings!
local floor = math.floor
local min = math.min
local round = function(x) return floor(x + 0.5) end
local GetTime = GetTime

--returns the formatted time, scaling to use, color, and the time until the next update is needed
local function GetFormattedTime(s)

	--format text as seconds when at 90 seconds or below
	if s < MINUTEISH then
		local seconds = round(s)

		--prevent 0 seconds from displaying
		if seconds == 0 then
			return '', s
		end

		return seconds, s - (seconds - 0.51)
	--format text as minutes when below an hour
	elseif s < HOURISH then
		local minutes = round(s/MINUTE)
		return minutes .. 'm', minutes > 1 and (s - (minutes*MINUTE - HALFMINUTEISH)) or (s - MINUTEISH)
	--format text as hours when below a day
	elseif s < DAYISH then
		local hours = round(s/HOUR)
		return hours .. 'h', hours > 1 and (s - (hours*HOUR - HALFHOURISH)) or (s - HOURISH)
	--format text as days
	else
		local days = round(s/DAY)
		return days .. 'd', days > 1 and (s - (days*DAY - HALFDAYISH)) or (s - DAYISH)
	end
end

--[[
	Text cooldown constructor
		Its a seperate frame to prevent some rendering issues.
--]]

local function CreateCooldownCount(cooldown, start, duration)
	--[[
		OmniCC hides the text cooldown if the icon the button is hidden or not.
		This makes it a bit more dependent on other mods as far as their icon format goes.
		Its the only way I can think of to absolutely make sure that the text cooldown is hidden properly.
	--]]
	local icon = 
		--standard action button icon, $parentIcon
		getglobal(cooldown:GetParent():GetName() .. "Icon") or 
		--standard item button icon,  $parentIconTexture
		getglobal(cooldown:GetParent():GetName() .. "IconTexture") or 
		--discord action button, $parent_Icon
		getglobal(cooldown:GetParent():GetName() .. "_Icon");
	
	if icon then
		local textFrame = CreateFrame("Frame", nil, cooldown:GetParent());
		textFrame:SetAllPoints(cooldown:GetParent());
		textFrame:SetFrameLevel(textFrame:GetFrameLevel() + 5);
		cooldown.textFrame = textFrame;
		
		textFrame.text = textFrame:CreateFontString(nil, "OVERLAY");
		textFrame.text:SetPoint("CENTER", 0, 0);
		textFrame.text:SetJustifyH("CENTER");
		
		textFrame.icon = icon;
		
		textFrame:SetAlpha(cooldown:GetParent():GetAlpha());
		textFrame:Hide();
		
		textFrame:SetScript("OnUpdate", OmniCC_OnUpdate);
		
		return textFrame;
	end
end

--[[  Shine Code  - adapted from ABInfo ]]--

local function Shine_Update()
	local shine = this.shine;
	local alpha = shine:GetAlpha();
	shine:SetAlpha(alpha * 0.95);
	
	if alpha < 0.1 then
		this:Hide();
	else
		shine:SetHeight(alpha * this:GetHeight() * SHINESCALE);
		shine:SetWidth(alpha * this:GetWidth() * SHINESCALE);
	end
end

local function CreateShineFrame(parent)
	local shineFrame = CreateFrame("Frame", nil, parent);
	shineFrame:SetAllPoints(parent);
	
	local shine = shineFrame:CreateTexture(nil, "OVERLAY");
	shine:SetTexture("Interface\\Cooldown\\star4");
	shine:SetPoint("CENTER", shineFrame, "CENTER");
	shine:SetBlendMode("ADD");
	shineFrame.shine = shine;
	
	shineFrame:Hide();
	shineFrame:SetScript("OnUpdate", Shine_Update);
	shineFrame:SetAlpha(parent:GetAlpha());
	
	return shineFrame;
end

local function StartToShine(textFrame)
	local shineFrame = textFrame.shine or CreateShineFrame(textFrame:GetParent());
	
	shineFrame.shine:SetAlpha(shineFrame:GetParent():GetAlpha());
	shineFrame.shine:SetHeight(shineFrame:GetHeight() * SHINESCALE);
	shineFrame.shine:SetWidth(shineFrame:GetWidth() * SHINESCALE);
	
	shineFrame:Show();
end

--[[ Text Update ]]--

function OmniCC_OnUpdate()
	if this.timeToNextUpdate <= 0 or not this.icon:IsVisible() then
		local remain = this.duration - (GetTime() - this.start);

		if floor(remain + 0.5) > 0 and this.icon:IsVisible() then
			local time, timeToNextUpdate = GetFormattedTime( remain );
			local scale, r, g, b = OmniCC_GetTimeStyle(remain);
			this.text:SetFont(STANDARD_TEXT_FONT , OmniCC.size * scale, "OUTLINE");
			this.text:SetText( time );
			this.text:SetTextColor(r, g, b);
			this.timeToNextUpdate = timeToNextUpdate;
		else
			if OmniCC.shine and this.icon:IsVisible() then
				StartToShine(this);
			end
			this:Hide();
		end
	else
		this.timeToNextUpdate = this.timeToNextUpdate - arg1;
	end
end

function OmniCC_GetTimeStyle(s)
	-- return scale, r, g, b
	
	if s < SOONISH then
		return 1.5, 1, 0, 0;
	elseif s < MINUTEISH then
		return 1, 1, 1, 0;
	elseif s <  HOURISH then
		return 1, 1, 1, 1;
	else
		return 0.75, 0.7, 0.7, 0.7;
	end
end

--[[ Function Hooks ]]--

local oCooldownFrame_SetTimer = CooldownFrame_SetTimer
CooldownFrame_SetTimer = function(cooldownFrame, start, duration, enable)
	oCooldownFrame_SetTimer(cooldownFrame, start, duration, enable);
	
	if start > 0 and duration > MIN_DURATION and enable > 0 then
		local cooldownCount = cooldownFrame.textFrame or CreateCooldownCount(cooldownFrame, start, duration);	
		if cooldownCount then
			cooldownCount.start = start;
			cooldownCount.duration = duration;
			cooldownCount.timeToNextUpdate = 0;
			cooldownCount:Show();
		end
	elseif cooldownFrame.textFrame then
		cooldownFrame.textFrame:Hide();
	end
end

--[[
	Slash Command Handler
--]]
SlashCmdList["OmniCCCOMMAND"] = function(msg)
	if(not msg or msg == "" or msg == "help" or msg == "?" or msg == "version") then
		--print help messages
		DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC (v1.3.3.7) Commands:");
		DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "/omnicc size <value> - Set font size. 18 is the default. Current setting: " .. OmniCC.size .. ".");
		DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "/omnicc shine (true/false) - Cooldown shine effect. Current setting: " .. (OmniCC.shine and "enabled." or "disabled."));
	else
		local args = {};
		
		local word;
		for word in string.gfind(msg, "[^%s]+") do
			table.insert(args, word );
		end

		cmd = string.lower(args[1]);
		
		--/omnicc size <size>
		if(cmd == "size") then
			if(not args[2] or args[2] == "") then
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC font size: " .. OmniCC.size .. ".");
			elseif(tonumber(args[2]) > 0) then
				OmniCC.size = tonumber(args[2]);
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC font size set to " .. OmniCC.size .. ".");
			else
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Invalid font size.");
			end
		--/omnicc size <size>
		elseif(cmd == "shine") then
			if(not args[2] or args[2] == "") then
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC shine effect: " .. (OmniCC.shine and "enabled." or "disabled."));
			elseif(tonumber(args[2]) == 1 or args[2] == "true" or args[2] == "enable") then
				OmniCC.shine = 1;
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC shine effect set to enabled.");
			elseif(tonumber(args[2]) == 0 or args[2] == "false" or args[2] == "disable") then
				OmniCC.shine = nil;
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "OmniCC shine effect set to disabled.");
			else
				DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Invalid value.");
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Invalid command.");
		end
	end
end
SLASH_OmniCCCOMMAND1 = "/omnicc";
SLASH_OmniCCCOMMAND2 = "/occ";
