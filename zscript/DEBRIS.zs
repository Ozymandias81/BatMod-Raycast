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