/*
 * Copyright (c) 2022 Ozymandias81
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

Class Debris_Base : Actor
{
	Default
	{
		Radius 1;
		Height 1;
		Mass 1;
		Scale 0.65;
		Projectile;
		-ACTIVATEIMPACT
		-ACTIVATEPCROSS
		-NOGRAVITY
		+FORCEXYBILLBOARD
		+RANDOMIZE
		+ROLLCENTER
		+ROLLSPRITE
		BounceCount 3;
		BounceFactor 0.7;
		BounceType "Doom";
		WallBounceFactor 0.7;
		Gravity 0.3;
	}
}

Class Trashcan_Lid : Debris_Base
{
	Default
	{
		-FLATSPRITE
		BounceCount 2;
		BounceFactor 0.8;
		WallBounceFactor 0.8;
		Gravity 0.5;
		BounceSound "METLDBRS";
	}
	
	States
	{
	Spawn:
		TBIN H 1 A_SetRoll(roll+random(15,30), SPF_INTERPOLATE);
		Loop;
	Death:
		TBIN H 0 {A_SetRoll(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE; bFlatSprite = TRUE;}
		"####" H 1 A_SetTics(35*5);
	DeathWait:
		"####" "#" 1 A_FadeOut(0.1);
		Wait;
	}
}

class Debris_Scraps : Debris_Base
{
	Default
	{
		-FLATSPRITE
		BounceFactor 0.5;
		BounceType "Doom";
		Scale 0.65;
		BounceSound "METLDBRS";
	}
	
	States
	{
	Spawn:
		SGON C 0 NODELAY A_Jump(256,"Set1","Set2","Set3","Set4","Set5","Set6","Set7","Set8","Set9","Set10");
		SGON C 0 A_Jump(256,"Set1");
		Set1:
		"####" C 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set2:
		"####" D 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set3:
		"####" E 1 {A_SetRoll(roll + 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set4:
		"####" F 1 {A_SetRoll(roll - 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set5:
		"####" G 1 {A_SetRoll(roll + 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set6:
		"####" H 1 {A_SetRoll(roll - 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set7:
		"####" I 1 {A_SetRoll(roll + 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set8:
		"####" J 1 {A_SetRoll(roll - 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set9:
		"####" K 1 {A_SetRoll(roll - 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set10:
		"####" L 1 {A_SetRoll(roll - 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		SGON "#" 0 A_SetMass(750);
		SGON "#" 0 A_Jump(256,"Swim");
	Swim:
		SGON "#" 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		SGON "#" 0 {A_SetRoll(0); A_SetAngle(0); A_SetPitch(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		SGON "#" 1 A_SetTics(35*5);
		SGON "#" 0 A_Jump(256,"DeathWait");
	DeathWait:
		"####" "#" 1 A_FadeOut(0.09);
		Wait;
	}
}

class Debris_Tire : Debris_Base
{
	States
	{
	Spawn:
		SGON M 1 {A_SetRoll(roll-random(15,30), SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		"####" M 0 A_SetMass(750);
		Goto Swim;
	Swim:
		"####" M 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		"####" N 0 {A_SetRoll(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		"####" N 1 A_SetTics(35*5);
	DeathWait:
		"####" N 1 A_FadeOut(0.1);
		Wait;
	}
}

class Debris_Steering : Debris_Base
{
	States
	{
	Spawn:
		SGON O 1 {A_SetRoll(roll-random(15,30), SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		"####" O 0 A_SetMass(750);
		Goto Swim;
	Swim:
		"####" O 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		"####" O 0 {A_SetRoll(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		"####" O 1 A_SetTics(35*5);
	DeathWait:
		"####" O 1 A_FadeOut(0.1);
		Wait;
	}
}

class Debris_GoonCar : Actor
{
	Default
	{
		Radius 8;
		Height 4;
		+NOBLOCKMAP
	}
	
	States
	{
	Spawn:
		TNT1 A 0 NODELAY A_Jump(256,1,2);
		SGON A -1 A_SetScale(Scale.X * RandomPick(-1, 1), Scale.Y);
		SGON B -1 A_SetScale(Scale.X * RandomPick(-1, 1), Scale.Y);
		Stop;
	}
}

class Debris_Toys : Debris_Base
{
	Default
	{
		Gravity 0.325;
	}
	
	States
	{
	Spawn:
		OLOV C 0 NODELAY A_Jump(256,"Set1","Set2","Set3");
		OLOV C 0 A_Jump(256,"Set1");
		Set1:
		"####" C 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_SetAngle(angle + random(-15, 15)); A_SetPitch(pitch + frandom(-0.25, 0.25)); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set2:
		"####" D 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_SetAngle(angle + random(-15, 15)); A_SetPitch(pitch + frandom(-0.25, 0.25)); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set3:
		"####" E 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_SetAngle(angle + random(-15, 15)); A_SetPitch(pitch + frandom(-0.25, 0.25)); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		OLOV "#" 0 A_SetMass(750);
		OLOV "#" 0 A_Jump(256,"Swim");
	Swim:
		OLOV "#" 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		OLOV "#" 0 {A_SetRoll(0); A_SetAngle(0); A_SetPitch(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		OLOV "#" 1 A_SetTics(35*5);
		OLOV "#" 0 A_Jump(256,"DeathWait");
	DeathWait:
		"####" "#" 1 A_FadeOut(0.09);
		Wait;
	}
}

class Debris_Toys2 : Debris_Base
{
	Default
	{
		Gravity 0.325;
	}
	
	States
	{
	Spawn:
		BEAR C 0 NODELAY A_Jump(256,"Set1","Set2");
		BEAR C 0 A_Jump(256,"Set1");
		Set1:
		"####" C 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_SetAngle(angle + random(-15, 15)); A_SetPitch(pitch + frandom(-0.25, 0.25)); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set2:
		"####" D 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_SetAngle(angle + random(-15, 15)); A_SetPitch(pitch + frandom(-0.25, 0.25)); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		BEAR "#" 0 A_SetMass(750);
		BEAR "#" 0 A_Jump(256,"Swim");
	Swim:
		BEAR "#" 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		BEAR "#" 0 {A_SetRoll(0); A_SetAngle(0); A_SetPitch(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		BEAR "#" 1 A_SetTics(35*5);
		BEAR "#" 0 A_Jump(256,"DeathWait");
	DeathWait:
		"####" "#" 1 A_FadeOut(0.09);
		Wait;
	}
}

Class Debris_TeddyHead : Trashcan_Lid
{
	Default
	{
		-FLATSPRITE
		BounceCount 2;
		BounceFactor 0.8;
		WallBounceFactor 0.8;
		Gravity 0.5;
		BounceSound "";
	}
	
	States
	{
	Spawn:
		BEAR B 1 A_SetRoll(roll+random(15,30), SPF_INTERPOLATE);
		Loop;
	Death:
		BEAR B 0 {A_SetRoll(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		"####" B 1 A_SetTics(35*5);
	DeathWait:
		"####" "#" 1 A_FadeOut(0.1);
		Wait;
	}
}

class Debris_McDonald : Debris_Base
{
	Default
	{
		-FLATSPRITE
		BounceFactor 0.5;
		BounceType "Doom";
	}
	
	States
	{
	Spawn:
		DRNK B 0 NODELAY A_Jump(256,"Set1","Set2","Set3","Set4","Set5","Set6","Set7");
		DRNK B 0 A_Jump(256,"Set1");
		Set1:
		"####" B 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set2:
		"####" C 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set3:
		"####" D 1 {A_SetRoll(roll + 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set4:
		"####" E 1 {A_SetRoll(roll - 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set5:
		"####" F 1 {A_SetRoll(roll + 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set6:
		"####" G 1 {A_SetRoll(roll - 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set7:
		"####" H 1 {A_SetRoll(roll + 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass"); bFlatSprite = TRUE;}
		Loop;
	AdjustMass:
		DRNK "#" 0 A_SetMass(750);
		DRNK "#" 0 A_Jump(256,"Swim");
	Swim:
		DRNK "#" 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		DRNK "#" 0 {A_SetRoll(0); A_SetAngle(0); A_SetPitch(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		DRNK "#" 1 A_SetTics(35*5);
		DRNK "#" 0 A_Jump(256,"DeathWait");
	DeathWait:
		"####" "#" 1 A_FadeOut(0.09);
		Wait;
	}
}

class Debris_Cart : Debris_Base
{
	Default
	{
		-FLATSPRITE
		BounceFactor 0.5;
		BounceType "Doom";
	}
	
	States
	{
	Spawn:
		GROC F 0 NODELAY A_Jump(256,"Set1","Set2","Set3","Set4","Set5","Set6","Set7","Set8","Set9","Set10","Set11","Set12","Set13","Set14","Set15","Set16","Set17");
		GROC F 0 A_Jump(256,"Set1");
		Set1:
		"####" F 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set2:
		"####" G 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set3:
		"####" H 1 {A_SetRoll(roll + 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set4:
		"####" I 1 {A_SetRoll(roll - 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set5:
		"####" J 1 {A_SetRoll(roll + 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set6:
		"####" K 1 {A_SetRoll(roll - 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set7:
		"####" L 1 {A_SetRoll(roll + 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set8:
		"####" M 1 {A_SetRoll(roll - 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set9:
		"####" N 1 {A_SetRoll(roll + 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set10:
		"####" O 1 {A_SetRoll(roll - 35, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set11:
		"####" P 1 {A_SetRoll(roll + 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set12:
		"####" Q 1 {A_SetRoll(roll - 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set13:
		"####" R 1 {A_SetRoll(roll + 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set14:
		"####" S 1 {A_SetRoll(roll - 25, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set15:
		"####" T 1 {A_SetRoll(roll + 40, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set16:
		"####" U 1 {A_SetRoll(roll + 30, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
		Set17:
		"####" V 1 {A_SetRoll(roll + 20, SPF_INTERPOLATE); A_JumpIf(waterlevel == 3, "AdjustMass");}
		Loop;
	AdjustMass:
		GROC "#" 0 A_SetMass(750);
		GROC "#" 0 A_Jump(256,"Swim");
	Swim:
		GROC "#" 2 A_ScaleVelocity(0.7);
		Loop;
	Death:
		GROC "#" 0 {A_SetRoll(0); A_SetAngle(0); A_SetPitch(0); bRollCenter = FALSE; bRollSprite = FALSE; bBounceOnActors = FALSE;}
		GROC "#" 1 A_SetTics(35*5);
		GROC "#" 0 A_Jump(256,"DeathWait");
	DeathWait:
		"####" "#" 1 A_FadeOut(0.09);
		Wait;
	}
}