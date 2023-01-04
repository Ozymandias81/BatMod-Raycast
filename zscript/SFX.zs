/*
 * Copyright (c) 2021, 2022 AFADoomer, Ddadd, Ozymandias81, Tormentor667
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


//Weather Related
Class RainSpawner : Actor
{
	Default
	{
		Radius 1;
		Height 1;
		+NOCLIP
		+CLIENTSIDEONLY
		+SPAWNCEILING
		+NOGRAVITY
	}
	
	States
	{
	Spawn:
		TNT1 A 0;
		TNT1 A 0 A_JumpIf(Args[2] > 0, "NoSound");
		TNT1 A 0 A_JumpIf(Args[3] > 0, "Circle");
		TNT1 A 0 A_StartSound("Ambient/Rain", CHAN_7, CHANF_DEFAULT, 0.1);
		TNT1 A 2 A_SpawnItemEx("RainDrop", Random(-Args[0], Args[0]), Random(-Args[0], Args[0]), -2, 0, 0, 0, 0, 128, Args[1]);
		Loop;
	Circle:
		TNT1 A 2 A_SpawnItemEx("RainDrop", Random(-Args[0], Args[0]), 0, -2, 0, 0, 0, Random(0, 360), 128, Args[1]);
	NoSound:
		TNT1 A 0 A_Jumpif(Args[3] > 0, "NoSoundCircle");
		TNT1 A 2 A_SpawnItemEx("RainDrop", Random(-Args[0], Args[0]), Random(-Args[0], Args[0]), -2, 0, 0, 0, 0, 128, Args[1]);
		Loop;
	NoSoundCircle:
		TNT1 A 2 A_SpawnItemEx("RainDrop", Random(-Args[0], Args[0]), 0, -2, 0, 0, 0, Random(0, 360), 128, Args[1]);
		Loop;
	}
}

Class RainDrop : Actor
{
	Default
	{
		Height 2;
		Radius 2;
		+MISSILE
		+NOBLOCKMAP
		-NOGRAVITY
	}
	
	States
	{
	Spawn:
		RNDR A 1 A_JumpIf(WaterLevel > 0, "Death");
		Loop;
	Death:
		RNDR BCDEFGH 3 A_FadeOut(0.15);
		Stop;
	}
}

Class HealingParticle: Actor
{
	Default
	{
		+DONTSPLASH
		+FORCEXYBILLBOARD
		+MISSILE
		+NOBLOCKMAP
		+NOGRAVITY
		Radius 0;
		Height 0;
		RenderStyle "Add";
		Alpha 0.01;
		Scale 0.4;
	}
	
	States
	{
	Spawn:
		HELX A 0 NODELAY A_SetScale(frandom(0.2, 0.6));
		"####" AAAAAAAAAA 1 A_FadeIn(0.07);
		"####" AAAAAAAAAA 8 A_FadeOut(0.08);
	Death:
		"####" A 1 BRIGHT A_FadeOut(0.1);
		Loop;
	}
}