/*
 * Copyright (c) 2021 AFADoomer, Ozymandias81
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

class BubbleSpawner : EffectSpawner
{
	Default
	{
		//$Category New SFX (BatMod)
		//$Title Underwater Bubble Spawner
		//$Color 12
		//$Sprite SBUBA0
		Radius 2;
		Height 2;
		+NOINTERACTION
		EffectSpawner.Range 1280;
		+EffectSpawner.ALLOWTICKDELAY
	}

	States
	{
		Spawn:
			TNT1 A 0;
		Active:
			TNT1 A 2 SpawnEffect();
			Loop;
	}

	override void SpawnEffect()
	{
		Super.SpawnEffect();

		A_SpawnItemEx("Bubble", random (-16, 16), 0, 0, 0, 0, 2, random (0, 360), 0, 128);
	}
}

class Bubble : ParticleBase
{
	int ticker;

	Default
	{
		Radius 2;
		Height 2;
		Speed 1;
		Scale 0.05;
		Alpha 0.25;
		RenderStyle "Add";
		Projectile;
		+CLIENTSIDEONLY
		+FORCEXYBILLBOARD
		+NOBLOCKMAP
		+NOCLIP
	}

	States
	{
		Spawn:
			SBUB A 1;
			Loop;
	}

	override void Tick()
	{
		if (!waterlevel) { Destroy(); } // Disappear at water surface
		else if (pos.z + height == ceilingz) // Fade out on ceilings
		{
			ticker++;

			if (ticker > 70)
			{
				alpha -= 0.01;
				if (alpha <= 0) { Destroy(); }
			}
		}

		if (Random() < 32) // Randomly move slightly on x/y axis
		{
			angle = Random(0, 360);
			vel.xy = RotateVector((-0.1, 0), angle);
		}

		Super.Tick();
	}
}

class PlayerBubble : Bubble
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		vel.z += FRandom(1.0, 3.0);
	}
}