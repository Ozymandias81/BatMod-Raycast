/*
 * Copyright (c) 2022 Ddadd, Ozymandias81
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
**/

Class Batman : BMovePlayer
{
	Default
	{
	Speed 1;
	Species "notEnemy";
	Health 100;
	Radius 16;
	Height 50;
	Mass 100;
	PainChance 255;
	+NOBLOOD
	DeathSound "bat/death";
	Player.DisplayName "Batman";
	//Player.CrouchSprite "PLYC";
	Player.StartItem "Bola", 15;
	Player.StartItem "BatFist";
	Player.StartItem "BatUnderwater";
	//Player.StartItem "LedgeGrabWeapon";
	//This other stuff should be commented out later
	Player.StartItem "TriBaterang"; //enabled so when player picks up three baterangs
	//Player.StartItem "Baterang";
	//Player.StartItem "GasGun";
	//Player.StartItem "GasGunGreen";
	//Player.StartItem "Tazer";
	//Player.StartItem "EMPGun";
	//Player.StartItem "RemoteBaterang";
	//Player.StartItem "Cell", 300;
	//Player.StartItem "GasGunAmmo" 100;
	//Player.StartItem "BaterangAmmo", 50;
	Player.StartItem "BolaAmmo", 25;
	Player.WeaponSlot 1, "BatFist";
	Player.WeaponSlot 2, "Bola";
	Player.WeaponSlot 3, "TriBaterang", "Baterang";
	Player.WeaponSlot 4, "Tazer";
	Player.WeaponSlot 5, "GasGun";
	Player.WeaponSlot 6, "RemoteBaterang";
	Player.WeaponSlot 7, "EMPGun";
	DamageFactor "Firey", 0.8;
	DamageFactor "Smoke", 0.2;
	PainChance "Smoke", 0;
	//Player.DamageScreenColor "Grey", 0.8, "Smoke";
	Player.DamageScreenColor "00 de 00", 0.6, "Poison";
	Player.DamageScreenColor "Light Blue", 1, "Ice";
	Player.DamageScreenColor "8c 4f 0d", 1, "Clay";
	Player.ColorRange 112, 127;
	Player.Colorset 0, "Green",			0x70, 0x7F,  0x72;
	Player.Colorset 1, "Gray",			0x60, 0x6F,  0x62;
	Player.Colorset 2, "Brown",			0x40, 0x4F,  0x42;
	Player.Colorset 3, "Red",			0x20, 0x2F,  0x22;
	// Doom Legacy additions
	Player.Colorset 4, "Light Gray",	0x58, 0x67,  0x5A;
	Player.Colorset 5, "Light Brown",	0x38, 0x47,  0x3A;
	Player.Colorset 6, "Light Red",		0xB0, 0xBF,  0xB2;
	Player.Colorset 7, "Light Blue",	0xC0, 0xCF,  0xC2;
	}

	States
	{
	Spawn:
		DBFL A 0; //spaghetti placeholder for batcar frame inheritances
		PLAY A -1;
		Loop;
	See:
		PLAY ABCD 4;
		Loop;
	Missile:
		PLAY FE 6;
		Goto See;
	Melee:
		PLAY FE 6; //BRIGHT
		Goto See;
	Pain.Poison:
		PLAY G 0 ACS_NamedExecuteAlways("PoisonEffect"); //should be PoisonCheck but not working yet
		Goto Pain;
	Pain:
		PLAY G 4;
		PLAY G 4 A_Pain;
		Goto Spawn;
	Death:
		PLAY H 0 A_PlayerSkinCheck("AltSkinDeath");
	Death1:
		PLAY H 10 A_PlayerScream;
		PLAY I 10 A_NoBlocking;
		PLAY J 10;
		PLAY K -1;
		Stop;
	XDeath:
		PLAY O 0 A_PlayerSkinCheck("AltSkinXDeath");
	XDeath1:
		PLAY O 5;
		PLAY P 5 A_XScream;
		PLAY Q 5 A_NoBlocking;
		PLAY RSTUV 5;
		PLAY W -1;
		Stop;
	AltSkinDeath:
		PLAY H 6;
		PLAY I 6 A_PlayerScream;
		PLAY JK 6;
		PLAY L 6 A_NoBlocking;
		PLAY MNO 6;
		PLAY P -1;
		Stop;
	AltSkinXDeath:
		PLAY Q 5 A_PlayerScream;
		PLAY R 0 A_NoBlocking;
		PLAY R 5 A_SkullPop;
		PLAY STUVWX 5;
		PLAY Y -1;
		Stop;
	}
}

Class GreenArrow : BMovePlayer
{
	Default
	{
	Speed 1;
	Health 100;
	Radius 16;
	Height 56;
	Species "notEnemy";
	Mass 100;
	PainChance 255;
	Player.DisplayName "GreenArrow";
	//Player.CrouchSprite "PLYC";
	Player.StartItem "BowNormal";
	Player.StartItem "BowIce";
	Player.StartItem "BowFire";
	Player.StartItem "GAFist";
	//This other stuff should be commented out later
	Player.StartItem "TriBaterang";
	Player.StartItem "GasGunGreen";
	Player.StartItem "EMPGun";
	Player.StartItem "RemoteBaterang";
	Player.StartItem "Cell", 300;
	Player.StartItem "GasGunAmmo", 100;
	Player.StartItem "BaterangAmmo", 50;
	Player.WeaponSlot 1, "GAFist", "Chainsaw";
	Player.WeaponSlot 2, "BowNormal";
	Player.WeaponSlot 3, "Baterang", "TriBaterang";
	Player.WeaponSlot 4, "BowIce";
	Player.WeaponSlot 5, "BowFire";
	Player.WeaponSlot 6, "RemoteBaterang";
	Player.WeaponSlot 7, "EMPGun";
	+NOBLOOD
	Player.DamageScreenColor "00 de 00", 0.8, "Poison";
	Player.DamageScreenColor "Light Blue", 0.8, "Ice";
	Player.DamageScreenColor "8c 4f 0d", 1, "Clay";
	Player.ColorRange 112, 127;
	Player.Colorset 0, "Green",			0x70, 0x7F,  0x72;
	Player.Colorset 1, "Gray",			0x60, 0x6F,  0x62;
	Player.Colorset 2, "Brown",			0x40, 0x4F,  0x42;
	Player.Colorset 3, "Red",			0x20, 0x2F,  0x22;
	// Doom Legacy additions
	Player.Colorset 4, "Light Gray",	0x58, 0x67,  0x5A;
	Player.Colorset 5, "Light Brown",	0x38, 0x47,  0x3A;
	Player.Colorset 6, "Light Red",		0xB0, 0xBF,  0xB2;
	Player.Colorset 7, "Light Blue",	0xC0, 0xCF,  0xC2;
	}

	States
	{
	Spawn:
		PLAY A -1;
		Loop;
	See:
		PLAY ABCD 4;
		Loop;
	Missile:
		PLAY E 12;
		Goto Spawn;
	Melee:
		PLAY F 6 BRIGHT;
		Goto Missile;
	Pain:
		PLAY G 4;
		PLAY G 4 A_Pain;
		Goto Spawn;
	Death:
		PLAY H 0 A_PlayerSkinCheck("AltSkinDeath");
	Death1:
		PLAY H 10;
		PLAY I 10 A_PlayerScream;
		PLAY J 10 A_NoBlocking;
		PLAY KLM 10;
		PLAY N -1;
		Stop;
	XDeath:
		PLAY O 0 A_PlayerSkinCheck("AltSkinXDeath");
	XDeath1:
		PLAY O 5;
		PLAY P 5 A_XScream;
		PLAY Q 5 A_NoBlocking;
		PLAY RSTUV 5;
		PLAY W -1;
		Stop;
	AltSkinDeath:
		PLAY H 6;
		PLAY I 6 A_PlayerScream;
		PLAY JK 6;
		PLAY L 6 A_NoBlocking;
		PLAY MNO 6;
		PLAY P -1;
		Stop;
	AltSkinXDeath:
		PLAY Q 5 A_PlayerScream;
		PLAY R 0 A_NoBlocking;
		PLAY R 5 A_SkullPop;
		PLAY STUVWX 5;
		PLAY Y -1;
		Stop;
	}
}

Class Freedom : Health
{
	Default
	{
		+COUNTITEM;
		+NOCLIP;
		+INVENTORY.AUTOACTIVATE;
		+INVENTORY.ALWAYSPICKUP;
		+INVENTORY.FANCYPICKUPSOUND;
		+INVENTORY.NOSCREENFLASH;
		Inventory.Amount 0;
		Inventory.MaxAmount 200;
		Inventory.PickupMessage "";
	}
	
	States
	{
	Spawn:
		TNT1 ABCDCB 6 Bright;
		Loop;
	}

	Override void Tick()
	{ //Tick override gets called every tick
		Super.Tick();
		GlideToPlayer(); //Call the function
	}
	
	void GlideToPlayer()
	{ //Function definition
		For(let i = BlockThingsIterator.Create(self,9999); i.Next();)
		{ //Iterate through all actors in a 9999 unit range
			Actor other = i.thing;
			If(other==self)
		{Continue;} //If the actor is the item, skip
		double distance = Distance3D(other);
		If(distance>9999)
		{Continue;} //If it's above the specified distance, skip
		If(other is "PlayerPawn")
			{ //If it's a player, continue
				A_Face(other); //Face the player
				VelFromAngle(10.0); //Move towards the player with a speed of 10 units per tick
			}
		}
	}
} 

//Counters
Class PoisonStop : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

Class PoisonIntensity : Inventory
{
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 400;
	}
}