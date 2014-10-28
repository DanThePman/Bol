require "Prodiction"

if myHero.charName ~= "Orianna" or not VIP_USER then return end

local ballPos = myHero
local version = 1.2
enemyHealth = {}

local InterruptList = 
	{
	  ["Katarina"] = "KatarinaR",
	  ["Malzahar"] = "AlZaharNetherGrasp",
	  ["Warwick"] = "InfiniteDuress",
	  ["Velkoz"] = "VelkozR",
	  ["MissFortune"] = "MissFortuneR", --not working
	  ["Caitlyn"] = "CaitlynR", -- not working
	  ["Fiddlesticks"] = "Crowstorm"
	}

local Qradius = 80
local Wradius = 240
local Eradius = 80
local Rradius = 380
local qCasted = false
local wCasted = false
local qCastedCheck = false

local Qrange = 825
local Erange = 1095

local Qdelay = 0
local Wdelay = 0.25
local Edelay = 0.25
local Rdelay = 0.6

local BallSpeed = 1200
local BallSpeedE = 1700

levelSequenceQ = {1,2,3,1,1,4,1,2,1,2,4,2,2,3,3,4,3,3}
levelSequenceW = {1,2,3,2,2,4,2,1,2,1,4,1,1,3,3,4,3,3}

combo = {_Q, _W, _R , _E}

local Rdamage = {150, 225, 300}
local Qdamage = {60, 90, 120, 150, 180}
local Wdamage = {70, 115, 160, 205, 250}
local Edamage = {60, 90, 120, 150, 180}

local enemyMinions = nil


local LastChampionSpell = {}

	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, 1500)

function OnLoad()

	PrintChat("Prodiction-Orianna v" .. version .. " loaded - Prodiction v" .. Prodiction.GetVersion() .. " loaded")
	Menu = scriptConfig("Orianna", "Orianna")

		Menu:addSubMenu("Combo", "Combo")
		Menu.Combo:addParam("UseQ", "Use Q", SCRIPT_PARAM_ONOFF , true)
		Menu.Combo:addParam("UseW1", "Use W", SCRIPT_PARAM_ONOFF , true)
		Menu.Combo:addParam("UseR1", "Use R", SCRIPT_PARAM_ONOFF , true)
		Menu.Combo:addParam("Enabled", "Normal combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
		Menu.Combo:addParam("UseE", "Use E for deepest ally in enemies", SCRIPT_PARAM_ONOFF, true)
		Menu.Combo:addParam("UseE2", "Force self shield if enemy is in range", SCRIPT_PARAM_ONOFF, true)
		Menu.Combo:addParam("UseE2Range", "Range:", SCRIPT_PARAM_SLICE, 500, 0, 700)

		Menu:addSubMenu("Harass", "Harass")
		Menu.Harass:addParam("harassKeyDown", "Harass", SCRIPT_PARAM_ONKEYDOWN , false, 192)
		Menu.Harass:addParam("harassKeyToggle", "Harass (TOGGLE)", SCRIPT_PARAM_ONKEYTOGGLE, false, 192)
		Menu.Harass:addParam("harassQ", "Use Q", SCRIPT_PARAM_ONOFF , true)
		Menu.Harass:addParam("harassW", "Use W", SCRIPT_PARAM_ONOFF , true)

		Menu:addSubMenu("Block", "Block")
		Menu.Block:addParam("Block", "Block ultimate if it will hit nothing", SCRIPT_PARAM_ONOFF, true)
		Menu.Block:addParam("Interrupt", "Interrupt spells", SCRIPT_PARAM_ONOFF, true)

		Menu:addSubMenu("Misc", "Misc")
		Menu.Misc:addParam("packets", "Use packets", SCRIPT_PARAM_ONOFF, true)
		Menu.Misc:addParam("UseW", "Use W in Combo if it will hit at least", SCRIPT_PARAM_SLICE, 1, 1, 5)
		Menu.Misc:addParam("UseR", "Use R in Combo if it will hit at least", SCRIPT_PARAM_SLICE, 3, 1, 5)
		Menu.Misc:addParam("rKill", "Kill enemy with ultimate if its possible", SCRIPT_PARAM_ONOFF, false)
		Menu.Misc:addParam("autolvl", "Auto lvl", SCRIPT_PARAM_ONOFF, true)
		Menu.Misc:addParam("autoMax", "Skill order:", SCRIPT_PARAM_LIST, 2, { "R>Q>W>E", "R>W>Q>E"})

		Menu:addSubMenu("TeamFightLogic", "TeamFightLogic")
		Menu.TeamFightLogic:addParam("tfKeyDown", "Initiate team fights with Q -> Ultimate", SCRIPT_PARAM_ONKEYDOWN , false, 192)
		Menu.TeamFightLogic:addParam("tfKeyToggle", "(TOGGLE)", SCRIPT_PARAM_ONKEYTOGGLE, false, 192)
		Menu.TeamFightLogic:addParam("UseRtoInitCount", "Use Ultimate if it will hit at least", SCRIPT_PARAM_SLICE, 3, 1, 5)

		Menu:addSubMenu("Drawing", "Drawing")
		Menu.Drawing:addParam("AArange", "Draw AA range", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("Qrange", "Draw Q range", SCRIPT_PARAM_ONOFF, true)
		Menu.Drawing:addParam("Wrange", "Draw W radius", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("Erange", "Draw E range", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("Rrange", "Draw R radius", SCRIPT_PARAM_ONOFF, false)
		Menu.Drawing:addParam("comboDmg", "Draw Combo damage", SCRIPT_PARAM_ONOFF, true)

		Menu:addParam("Version", "Version", SCRIPT_PARAM_INFO, version)
end

function OnGainBuff(unit, buff)
	if unit.team == myHero.team and buff.name:lower():find("orianaghostself") then
		ballPos = myHero
	end
end

function OnCreateObj(obj)
        if obj and obj.name:lower():find("yomu_ring_green") then
                ballPos = obj
            		qCasted = true
            		qCastedCheck = true
        end
        
        if obj and obj.name:lower():find("orianna_ball_flash_reverse") then
            	ballPos = myHero
            	qCasted = false
            	qCastedCheck = true
        end
end

function OnTick ()

ts:update()

if Menu.Misc.autolvl then
	if Menu.Misc.autoMax == 1 then
		autoLevelSetSequence(levelSequenceQ)
	elseif Menu.Misc.autoMax == 2 then
		autoLevelSetSequence(levelSequenceW)
	end
end

if Menu.Misc.UseR1 and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then
		if checkEnemiesHitWithR(ballPos) >= Menu.Misc.UseR then
			if Menu.Misc.packets then
				Packet('S_CAST', {spellId = _R}):send()
			else
				CastSpell(_R)
			end
	    end
end

if Menu.Misc.rKill and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) and checkEnemiesHitWithR(ballPos) >= 1 then
	killR()
end

if Menu.Block.Interrupt and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then
		Interrupt()
end

if Menu.TeamFightLogic.tfKeyDown or Menu.TeamFightLogic.tfKeyToggle and myHero:CanUseSpell(_R) == READY and myHero:GetSpellData(_R).level > 0 then
	TF_Calc()
end

if Menu.Combo.Enabled then

if Menu.Combo.UseQ and myHero:CanUseSpell(_Q) == READY and myHero:GetSpellData(_Q).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then

	local Qpos, info = Prodiction.GetLineAOEPrediction(ts.target, Qrange, BallSpeed, Qdelay, Qradius, ballPos)
		if Qpos and info.hitchance >= 1 then
			--Packet("S_CAST", {spellId = _Q,  Qpos.x, Qpos.z, ballPos.x, ballPos.z, targetNetworkId = ts.networkID}):send()
			CastSpell(_Q, Qpos.x, Qpos.z)
	    end
end

if Menu.Combo.UseW1 and myHero:CanUseSpell(_W) == READY and myHero:GetSpellData(_W).level > 0 then
		if checkEnemiesHitWithW() >= Menu.Misc.UseW then
			if Menu.Misc.packets then
				Packet('S_CAST', {spellId = _W}):send()
			else
				CastSpell(_W)
			end
	    end
	    wCasted = true
end

if wCasted and Menu.Combo.UseE and qCasted and qCastedCheck and myHero:CanUseSpell(_E) == READY and myHero:GetSpellData(_E).level > 0 and ts.target ~= nil then
		CastE()
end

end -- enabled
-----------------------------------------------------------------------------------------------HARASS
if Menu.Harass.harassKeyDown or Menu.Harass.harassKeyToggle then

if Menu.Combo.UseQ and myHero:CanUseSpell(_Q) == READY and myHero:GetSpellData(_Q).level > 0 and ts.target ~= nil and ValidTarget(ts.target) then

	local Qpos, info = Prodiction.GetLineAOEPrediction(ts.target, Qrange, BallSpeed, Qdelay, Qradius, ballPos)
		if Qpos and info.hitchance >= 1 then
			--Packet("S_CAST", {spellId = _Q,  Qpos.x, Qpos.z, ballPos.x, ballPos.z, targetNetworkId = ts.networkID}):send()
			CastSpell(_Q, Qpos.x, Qpos.z)
	    end
end

if myHero:CanUseSpell(_W) == READY and myHero:GetSpellData(_W).level > 0 and checkEnemiesHitWithW() > 0 then
	if Menu.Misc.packets then
		Packet('S_CAST', {spellId = _W}):send()
	else
		CastSpell(_W)
	end
	wCasted = true
end

end --harass

end -- ontick

function OnProcessSpell(unit, spell)
	if unit.type == "obj_AI_Hero" then
		LastChampionSpell[unit.networkID] = {name = spell.name, time=os.clock()}
	end
end

function checkEnemiesHitWithR(ballPosPoint)

enemies = {}
enemyHealth = {}

for i, enemy in ipairs(GetEnemyHeroes()) do

		local dashing, dashPos, info1 = Prodiction.IsDashing(enemy, 0, math.huge, Rdelay, Rradius, ballPosPoint)
		local position, info2 = Prodiction.GetCircularAOEPrediction(enemy, 0, math.huge, Rdelay, Rradius, ballPosPoint)
		local toSlow, pos, info2 = Prodiction.IsToSlow(enemy, 0, math.huge, Rdelay, Rradius, ballPosPoint)

		if not dashing and ValidTarget(enemy) and GetDistance(position, ballPosPoint) <= Rradius and GetDistance(enemy.visionPos, ballPosPoint) <= Rradius and toSlow and GetDistance(pos, ballPosPoint) <= Rradius then
				table.insert(enemies, enemy)
				table.insert(enemyHealth, enemy)
		elseif dashing and ValidTarget(enemy) and GetDistance(dashPos, ballPosPoint) <= Rradius and GetDistance(enemy.visionPos, ballPosPoint) <= Rradius and toSlow and GetDistance(pos, ballPosPoint) <= Rradius then
				table.insert(enemies, enemy)
				table.insert(enemyHealth, enemy)
		end
end

return #enemies

end

function checkEnemiesHitWithW()

enemies2 = {}

	for i, enemy in ipairs(GetEnemyHeroes()) do
	    local dashing, dashPos, info1 = Prodiction.IsDashing(enemy, 0, math.huge, Wdelay, Wradius, ballPos)
		local position, info2 = Prodiction.GetCircularAOEPrediction(enemy, 0, math.huge, Wdelay, Wradius, ballPos)
		if not dashing and ValidTarget(enemy) and GetDistance(position, ballPos) <= Wradius and GetDistance(enemy.visionPos, ballPos) <= Wradius then
			table.insert(enemies2, enemy)
		elseif dashing and ValidTarget(enemy) and GetDistance(dashPos, ballPos) <= Wradius and GetDistance(enemy.visionPos, ballPos) <= Wradius then
			table.insert(enemies2, enemy)
		end
	end

return #enemies2

end

function OnSendPacket(p)
	if Menu.Block.Block and p.header == Packet.headers.S_CAST then
		local packet = Packet(p)
		if packet:get('spellId') == _R then
			if checkEnemiesHitWithR(ballPos) == 0 then
				p:Block()
			end
		end
	end
end

function OnDraw()

if Menu.Drawing.AArange then
	DrawCircle(myHero.x, myHero.y, myHero.z, 550 + ((Qrange - 550) / 2), ARGB(255, 0, 255, 0))
end
if Menu.Drawing.Qrange then
	DrawCircle(myHero.x, myHero.y, myHero.z, Qrange, ARGB(255, 0, 255, 0))
end
if Menu.Drawing.Rrange then
	DrawCircle(ballPos.x, 0, ballPos.z, Rradius, ARGB(255,0,0,255))
end
if Menu.Drawing.Wrange then
	DrawCircle(ballPos.x, 0, ballPos.z, Wradius, ARGB(255, 0, 255, 0))
end
if Menu.Drawing.Erange then
	DrawCircle(myHero.x, myHero.y, myHero.z, Erange, ARGB(255, 0, 255, 0))
end
if ts.target ~= nil and Menu.Drawing.comboDmg then
	DrawOnHPBar(ts.target)
end
end

function CastE()
    smallestDist = nil
	allyToShield = myHero

	teamPos = {}
	enemyPos = {}

	for i=0, heroManager.iCount, 1 do
		currHero = heroManager:GetHero(i)
		if currHero.team == myHero.team and GetDistance(myHero, currHero) <= Erange then
			table.insert(teamPos, currHero)
		elseif currHero.team ~= myHero.team then
			table.insert(enemyPos, currHero)
		end
	end

	for _, enemy in ipairs(enemyPos) do
		for _, ally in ipairs(teamPos) do
			dist = GetDistance(ally, enemy)
			if smallestDist == nil or dist < smallestDist then
					smallestDist = dist
					allyToShield = ally
			end
		end
	end

	if Menu.Combo.UseE2 then
		for _, enemy in ipairs(enemyPos) do
			if GetDistance(enemy, myHero) <= Menu.Combo.UseE2Range then
				allyToShield = myHero
			end
		end
	end

	CastSpell(_E, allyToShield)
	qCasted = false
	qCastedCheck = false
	wCasted = false
	ballPos = allyToShield
end

function Interrupt ()
		for i, unit in ipairs(GetEnemyHeroes()) do
			for champion, spell in pairs(InterruptList) do
				if LastChampionSpell[unit.networkID] and spell == LastChampionSpell[unit.networkID].name and (os.clock() - LastChampionSpell[unit.networkID].time < 1) then
					local Qpos, info = Prodiction.GetLineAOEPrediction(unit, Qrange, BallSpeed, Qdelay, Qradius, ballPos)
						if Qpos then
							CastSpell(_Q, Qpos.x, Qpos.z)
	    				end
						if GetDistance(ballPos, unit) < Rradius then
							if Menu.Misc.packets then
								Packet('S_CAST', {spellId = _R}):send()
							else
								CastSpell(_R)
							end
					end
				end
			end
		end
end

function GetDamage(spell, target)
	local damage = 0
	if spell == _R then
		damage = myHero:CalcMagicDamage(target, Rdamage[myHero:GetSpellData(_R).level] + myHero.ap * 0.7)
	elseif spell == _Q then
		damage = myHero:CalcMagicDamage(target, Qdamage[myHero:GetSpellData(_Q).level] + myHero.ap * 0.5)
	elseif spell == _W then
		damage = myHero:CalcMagicDamage(target, Wdamage[myHero:GetSpellData(_W).level] + myHero.ap * 0.7)
	elseif spell == _E then
		damage = myHero:CalcMagicDamage(target, Wdamage[myHero:GetSpellData(_E).level] + myHero.ap * 0.3)
	end
	return damage
end

function killR ()

for _, enemy in ipairs(enemyHealth) do
		local dmg = GetDamage(_R, enemy)

		if myHero:CanUseSpell(_Q) == READY then
			dmg = dmg + GetDamage(_Q, enemy)
		end
			if not enemy.dead and enemy.health < dmg then

				local dashing, dashPos, info1 = Prodiction.IsDashing(enemy, 0, math.huge, Rdelay, Rradius, ballPos)
				local position, info2 = Prodiction.GetCircularAOEPrediction(enemy, 0, math.huge, Rdelay, Rradius, ballPos)
				local toSlow, pos, info2 = Prodiction.IsToSlow(enemy, 0, math.huge, Rdelay, Rradius, ballPos)

				if not dashing and ValidTarget(enemy) and GetDistance(position, ballPos) <= Rradius and GetDistance(enemy.visionPos, ballPos) <= Rradius and toSlow and GetDistance(pos, ballPos) <= Rradius then
					if Menu.Misc.packets then
						Packet('S_CAST', {spellId = _R}):send()
					else
						CastSpell(_R)
					end
				elseif dashing and ValidTarget(enemy) and GektDistance(dashPos, ballPos) <= Rradius and GetDistance(enemy.visionPos, ballPos) <= Rradius and toSlow and GetDistance(pos, ballPos) <= Rradius then
					if Menu.Misc.packets then
						Packet('S_CAST', {spellId = _R}):send()
					else
						CastSpell(_R)
					end
				end
			end
end

enemyHealth = {}

end

function DrawOnHPBar(unit)

	local tDmg = 0
	for _, spell in ipairs(combo) do
		if myHero:GetSpellData(spell).level > 0 and myHero:CanUseSpell(spell) == READY then
			tDmg = tDmg + GetDamage(spell, unit)
		end
	end

	local Pos = GetUnitHPBarPos(unit)
	if math.floor(unit.health - tDmg) <= 0 then
		DrawText("HP: Killable",13, Pos.x, Pos.y, ARGB(255, 0, 255, 0))
	else
		DrawText("HP: "..math.floor(unit.health - tDmg),13, Pos.x, Pos.y, ARGB(255, 0, 255, 0))
	end
end

function TF_Calc ()

points = {}
local circle = nil

for i, enemy in ipairs(GetEnemyHeroes()) do
	if ValidTarget(enemy) then
		local Position, HitChance = Prodiction.GetCircularAOEPrediction(enemy, Qrange, BallSpeed, Qdelay + Rdelay, Rradius, ballPos)
		local Dashing, DashPosition, DashHitChance = Prodiction.IsDashing(enemy, Qrange, BallSpeed, Qdelay + Rdelay, Rradius, ballPos)

			if not Dashing and GetDistance(myHero, Position) <= Qrange + Rradius then
				table.insert(points, Position)
			elseif Dashing and GetDistance(myHero, DashPosition) <= Qrange + Rradius then
				table.insert(points, DashPosition)
			end
	end
end

if #points >= Menu.TeamFightLogic.UseRtoInitCount then

	circle = MEC(points)
	circle = circle:Compute()

	if circle.radius <= Rradius then
			CastSpell(_Q, circle.center.x, circle.center.z)
			if checkEnemiesHitWithR(ballPos) >= #points then
				if Menu.Misc.packets then
					Packet('S_CAST', {spellId = _R}):send()
				else
					CastSpell(_R)
				end
				if myHero:CanUseSpell(_E) == READY and myHero:GetSpellData(_E).level > 0 and ts.target ~= nil then
					CastE()
				end
			end
	else --remove far points
		local index = 0
		for _, point in ipairs(points) do
			if GetDistance(point, circle.center) > Rradius then
				table.remove(points, index)
			end

			circle = MEC(points)
			circle = circle:Compute()

			if #points < Menu.TeamFightLogic.UseRtoInitCount then
				break
			else

				if circle.radius <= Rradius then
						CastSpell(_Q, circle.center.x, circle.center.z)
						if checkEnemiesHitWithR(ballPos) >= #points then
							if Menu.Misc.packets then
								Packet('S_CAST', {spellId = _R}):send()
							else
								CastSpell(_R)
							end
							if myHero:CanUseSpell(_E) == READY and myHero:GetSpellData(_E).level > 0 and ts.target ~= nil then
								CastE()
							end
							break
						end
				end
			end
			index = index + 1
		end
		index = 0
	end
end

end
