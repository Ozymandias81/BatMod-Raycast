Class ZMoveDemon : PlayerPawn
{
	//=========================
	//Common
	
	const BOB_MIN_REALIGN 	 = 0.25f;
	
	//Movement General
	bool	Pain;
	double	ViewAngleDelta;
	float	ActualSpeed;
	float	MaxAirSpeed;
	float 	MaxGroundSpeed;
	float	MoveFactor;
	int		AnimateJump;
	int		ForceVelocity;
	int		MoveType;
	int		OldFloorZ;
	playerinfo ZMPlayer;
	vector2 OldVelXY;
	vector3	Acceleration;
	
	//////////////////
	
	//Jumping
	bool 	BlockJump;
	bool	Jumped;
	float	FloorAngle;
	int		JumpSoundCooler;
	
	//Elevator Jumps
	float	ElevatorJumpBoost;
	int		OldSecIndex;
	
	//////////////////
	
	//View Bobbing
	bool	PostLandingBob;
	float	ZMBob;
	
	//Weapon bobbing
	bool	DoBob;
	double	BobTime;
	double	HorizontalSway;
	double	BobRange;
	double 	OldTicFrac;
	double	VerticalOffset;
	
	//=========================
	//Painkiller only
	
	//Movement
	bool	TrickFailed;
	float	AirControl;
	float	ActualMaxAirSpeed;
	
	//Jumping
	float	TrickJumpAngle;
	int		SmallerJumpHeight;
	
	//=========================
	//Build Engine Only
	
	//Movement
	bool	DeepWater;
	float	LandingVelZ;
	int		FVel;
	int		SVel;
	int		UVel;
	
	//Jumping
	int		BuildJumpDelay;
	
	Default
    {
		Player.DisplayName "ZMovement Demon";
        PainChance 255;
    }
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////																						////
	//// Non-Movement Stuff																		////
	////																						////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	
	//Because GZDoom's Unit() returns NaN if a vector has no value
	vector3 SafeUnit3(Vector3 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	vector2 SafeUnit2(Vector2 VecToUnit)
	{
		if(VecToUnit.Length()) { VecToUnit /= VecToUnit.Length(); }
		return VecToUnit;
	}
	
	Override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		
		//No voodoo dolls allowed past this point
		if(!self.player || self.player.mo != self) { return; }
		bNOFRICTION = True;
	}
	
	Override void PlayerThink()
	{
		//======================================
		//Store info needed in multiple places
		
		ZMPlayer = self.player;
		ActualSpeed = Speed * GetPowerSpeed();
		MaxGroundSpeed = zm_maxgroundspeed * ActualSpeed;
		MoveFactor = ScaleMovement();
		MoveType = zm_movetype;
		Pain = InStateSequence(CurState, FindState("Pain"));
		ZMPlayer.OnGround = Pos.Z <= FloorZ || bONMOBJ || bMBFBOUNCER || (ZMPlayer.Cheats & CF_NOCLIP2);
		
		//======================================
		//Execute Player tic cycle
		
		CheckFOV();
		
		if(ZMPlayer.inventorytics) { ZMPlayer.inventorytics--; }
		CheckCheats();

		bool totallyfrozen = CheckFrozen();

		// Handle crouching
		CheckCrouch(totallyfrozen);
		CheckMusicChange();

		if(ZMPlayer.playerstate == PST_DEAD)
		{
			DeathThink();
			return;
		}
		if(ZMPlayer.morphTics && !(ZMPlayer.cheats & CF_PREDICTING)) { MorphPlayerThink (); }

		CheckPitch();
		HandleMovement();
		CalcHeight();

		if(!(ZMPlayer.cheats & CF_PREDICTING))
		{
			CheckEnvironment();
			// Note that after this point the PlayerPawn may have changed due to getting unmorphed or getting its skull popped so 'self' is no longer safe to use.
			// This also must not read mo into a local variable because several functions in this block can change the attached PlayerPawn.
			ZMPlayer.mo.CheckUse();
			ZMPlayer.mo.CheckUndoMorph();
			// Cycle psprites.
			ZMPlayer.mo.TickPSprites();
			// Other Counters
			if(ZMPlayer.damagecount) ZMPlayer.damagecount--;
			if(ZMPlayer.bonuscount) ZMPlayer.bonuscount--;

			if(ZMPlayer.hazardcount)
			{
				ZMPlayer.hazardcount--;
				if(!(Level.maptime % ZMPlayer.hazardinterval) && ZMPlayer.hazardcount > 16*TICRATE)
					ZMPlayer.mo.DamageMobj (NULL, NULL, 5, ZMPlayer.hazardtype);
			}
			ZMPlayer.mo.CheckPoison();
			ZMPlayer.mo.CheckDegeneration();
			ZMPlayer.mo.CheckAirSupply();
		}
		
		//Bob weapon stuff
		BobWeaponAuxiliary();
		
		//Old values for comparisons
		OldFloorZ = FloorZ;
		OldVelXY = Vel.XY;
	}
	
	float GetPowerSpeed()
	{
		float factor = 1.f;
		
		if(!ZMPlayer.morphTics)
		{
			for(let it = Inv; it != null; it = it.Inv)
			{
				factor *= it.GetSpeedFactor();
			}
		}
		
		return factor;
	}
	
	Override void DeathThink()
	{
		bNOFRICTION = False;
		Gravity = zm_setgravity;
		
		Super.DeathThink();
	}
	
	Override void CalcHeight()
	{
		double HeightAngle;
		double bob;
		bool still = false;

		if(!ZMPlayer.OnGround || (ZMPlayer.OnGround && ((ZMPLayer.cmd.buttons & BT_JUMP) && !BlockJump)) || ZMPlayer.cheats & CF_NOCLIP2) //nobody walks in the air
		{
			ZMBob--;
			ZMBob = max(bNOGRAVITY ? 0.5f : 0.f, ZMBob);
			PostLandingBob = True;
		}
		else
		{
			if(PostLandingBob)
			{
				ZMBob += Vel.XY.Length() / (MaxGroundSpeed ? MaxGroundSpeed : 1.f);
				if(ZMBob >= Vel.XY.Length() * ZMPlayer.GetMoveBob()) { PostLandingBob = False; }
			}
			else
			{
				ZMBob = Vel.XY.Length() * ZMPlayer.GetMoveBob(); //this way all GetMoveBob() values are meaningful
			}
			
			if(!ZMBob)
				still = true;
			else
				ZMBob = min(MaxGroundSpeed, ZMBob);
		}

		double defaultviewheight = ViewHeight + ZMPlayer.crouchviewdelta;

		if(ZMPlayer.cheats & CF_NOVELOCITY)
		{
			ZMPlayer.viewz = pos.Z + defaultviewheight;

			if(ZMPlayer.viewz > ceilingz-4)
				ZMPlayer.viewz = ceilingz-4;

			return;
		}

		if(still)
		{
			if(ZMPlayer.health > 0)
				bob = 2 * ZMPlayer.GetStillBob() * sin(2 * Level.maptime);
			else
				bob = 0;
		}
		else
		{
			HeightAngle = Level.maptime / 20. * 360.;
			bob = ZMBob * sin(HeightAngle) * (waterlevel > 2 ? 0.25f : 0.5f);
		}
		
		if(ZMPlayer.morphTics) { bob = 0; }
		
		//=======================================
		// Customizable Landing
		
		if(zm_landing || MoveType == 1)
		{
			if(ZMPlayer.playerstate == PST_LIVE)
			{
				if(!ZMPlayer.OnGround)
				{
					if(Vel.Z >= 0)
					{
						ZMPlayer.viewheight += ZMPlayer.deltaviewheight;
						ZMPlayer.deltaviewheight += zm_landingspeed * 2.f; //ensure a speedy recovery while in the air
						if(ZMPlayer.viewheight >= defaultviewheight)
						{
							ZMPlayer.deltaviewheight = 0;
							ZMPlayer.viewheight = defaultviewheight;
						}
					}
					else
					{
						LandingVelZ = abs(Vel.Z);
						ZMPlayer.deltaviewheight = Vel.Z / zm_landingsens;
						ZMPlayer.viewheight = defaultviewheight;
					}
				}
				else
				{
					ZMPlayer.viewheight += ZMPlayer.deltaviewheight;

					if(ZMPlayer.viewheight > defaultviewheight)
					{
						ZMPlayer.viewheight = defaultviewheight;
						ZMPlayer.deltaviewheight = 0;
					}
					else if(ZMPlayer.viewheight < defaultviewheight * zm_minlanding && !BuildJumpDelay)
					{
						ZMPlayer.viewheight = defaultviewheight * zm_minlanding;
						if(ZMPlayer.deltaviewheight <= 0) { ZMPlayer.deltaviewheight = 1 / 65536.f; }
					}
					
					if(ZMPlayer.deltaviewheight)	
					{
						ZMPlayer.deltaviewheight += zm_landingspeed;
						if(!ZMPlayer.deltaviewheight) { ZMPlayer.deltaviewheight = 1 / 65536.f; }
					}
				}
			}
		}
		else //regular Doom landing
		{
			if(ZMPlayer.playerstate == PST_LIVE)
			{
				ZMPlayer.viewheight += ZMPlayer.deltaviewheight;
				
				if(ZMPlayer.viewheight > defaultviewheight)
				{
					ZMPlayer.viewheight = defaultviewheight;
					ZMPlayer.deltaviewheight = 0;
				}
				else if(ZMPlayer.viewheight < (defaultviewheight/2))
				{
					ZMPlayer.viewheight = defaultviewheight/2;
					if(ZMPlayer.deltaviewheight <= 0)
						ZMPlayer.deltaviewheight = 1 / 65536.;
				}
				
				if(ZMPlayer.deltaviewheight)	
				{
					ZMPlayer.deltaviewheight += 0.25;
					if(!ZMPlayer.deltaviewheight) { ZMPlayer.deltaviewheight = 1/65536.; }
				}
			}
		}
			
		//Let's highlight the important stuff shall we?
		ZMPlayer.viewz = pos.Z + ZMPlayer.viewheight + (bob * clamp(ViewBob, 0., 1.5));
		
		if(Floorclip && ZMPlayer.playerstate != PST_DEAD && pos.Z <= floorz) { ZMPlayer.viewz -= Floorclip; }
		if(ZMPlayer.viewz > ceilingz - 4) { ZMPlayer.viewz = ceilingz - 4; }
		if(ZMPlayer.viewz < FloorZ + 4) { ZMPlayer.viewz = FloorZ + 4; }
	}
	
	Override void CheckPitch()
	{
		int clook = ZMPlayer.cmd.pitch;
		if(clook != 0)
		{
			if(clook == -32768)
			{
				ZMPlayer.centering = true;
			}
			else if(!ZMPlayer.centering)
			{
				A_SetPitch(Pitch - clook * (360. / 65536.), SPF_INTERPOLATE);
			}
		}
		
		if(ZMPlayer.centering)
		{
			if(abs(Pitch) > 2.)
			{
				Pitch *= (2. / 3.);
			}
			else
			{
				Pitch = 0.;
				ZMPlayer.centering = false;
				if(PlayerNumber() == consoleplayer)
				{
					LocalViewPitch = 0;
				}
			}
		}
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////																						////
	//// Movement Stuff																			////
	////																						////
	////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////
	
	Override void HandleMovement()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		// [RH] Check for fast turn around
		if(cmd.buttons & BT_TURN180 && !(ZMPlayer.oldbuttons & BT_TURN180)) { ZMPlayer.turnticks = TURN180_TICKS; }

		// Handle movement
		if(reactiontime)
		{ // Player is frozen
			reactiontime--;
		}
		else
		{	
			ViewAngleDelta = cmd.Yaw * (360.0 / 65536.0); //needed for two other things
			
			if(ZMPlayer.TurnTicks) //moved here to save many doubled lines
			{
				ZMPlayer.TurnTicks--;
				A_SetAngle(Angle + (180.0 / TURN180_TICKS), SPF_INTERPOLATE);
			}
			else
			{
				A_SetAngle(Angle + ViewAngleDelta, SPF_INTERPOLATE);
			}
			
			//========================================
			//Gravity
			if(MoveType == 1)
				BuildGravity();
			else if(MoveType == 3)
				PainkillerGravity();
			else if(MoveType == 5)
				UTGravity();
			else
				DGravity();
			
			//========================================
			//Say no to wall friction
			QuakeWallFriction();
			
			//========================================
			//Actual Movement selection
			if(WaterLevel >= 2)
			{
				if(!MoveType)
					DoomWaterMove();
				else if(MoveType == 1)
					BuildWaterMove();
				else if(MoveType == 2)
					DuskWaterMove();
				else if(MoveType == 3)
					PainkillerWaterMove();
				else if(MoveType == 4)
					QuakeWaterMove();
				else if(MoveType == 5)
					UTWaterMove();
			}
			else if(bNOGRAVITY)
			{
				if(!MoveType)
					DoomFlyMove();
				else if(MoveType == 1)
					BuildFlyMove();
				else if(MoveType == 2)
					DuskFlyMove();
				else if(MoveType == 3)
					PainkillerFlyMove();
				else if(MoveType == 4)
					QuakeFlyMove();
				else if(MoveType == 5)
					UTFlyMove();
			}
			else
			{
				if(!MoveType)
					DoomHandleMove();
				else if(MoveType == 1)
					BuildHandleMove();
				else if(MoveType == 2)
					DuskHandleMove();
				else if(MoveType == 3)
					PainkillerHandleMove();
				else if(MoveType == 4)
					QuakeHandleMove();
				else
					UTHandleMove();
			}
			
			//========================================
			//Jumping
			if(MoveType == 1)
				BuildJump();
			else if(MoveType == 3)
				PainkillerJump();
			else if(MoveType == 5)
				UTJump();
			else
				CheckJump();
			
			//========================================
			//Misc
			if(ZMPlayer.Cheats & CF_REVERTPLEASE != 0)
			{
				ZMPlayer.Cheats &= ~CF_REVERTPLEASE;
				ZMPlayer.Camera = ZMPlayer.Mo;
			}
			
			CheckMoveUpDown();
		}
	}
	
	void QuakeWallFriction()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		if(ForceVelocity)
		{
			if(OldVelXY.Length() && Vel.XY.Length() && (cmd.forwardmove || cmd.sidemove))
			{
				Vector2 VelUnit = Vel.XY.Unit();
				Float VelDot = OldVelXY.Unit() dot VelUnit;
				if(VelDot > 0)
				{
				   if(VelDot > 0.75)
					  VelDot = 1.f;
				   else
					  VelDot /= 0.75;
				   
				   Vel.XY = VelDot * OldVelXY.Length() * VelUnit;
				}
				ForceVelocity--;
			}
			else
			{
				ForceVelocity = 0;
			}
		}
		if(!CheckMove(Pos.XY + Vel.XY)) { ForceVelocity = 2; }
	}
	
	//////////////////////////////////////////
	// Jumping								//
	//////////////////////////////////////////
	
	void PreJumpCommon()
	{
		//Jumptics settings
		if(Jumped && (Player.OnGround || WaterLevel >= 2 || bNOGRAVITY)) { Jumped = False; }
		
		//Jump Sound Cooler
		if(JumpSoundCooler) { JumpSoundCooler--; }
	}
	
	float GetPowerJump()
	{
		Float JumpFac = 0.f;
		
		for(let p = Inv; p != null; p = p.Inv)
		{
			let pp = PowerHighJump(p);
			if(pp) { JumpFac = max(JumpFac, pp.Strength); }
		}
		
		return JumpFac;
	}
	
	bool, bool CheckIfJumpable()
	{
		if(CeilingZ - FloorZ <= Height) //sector is just high enough for player to pass through but not jump
		{
			return True, False;
		}
		else
		{
			//===============================
			// Get floor normal
			
			Vector3 FloorNormal;
			F3DFloor ThreeDFloor;
			for(int i = 0; i < FloorSector.Get3DFloorCount(); i++)
			{
				if(FloorSector.Get3DFloor(i).Top.ZAtPoint(Pos.XY) ~== FloorZ)
				{
					ThreeDFloor = FloorSector.Get3DFloor(i);
					break;
				}
			}
			FloorNormal = ThreeDFloor ? - ThreeDFloor.Top.Normal : FloorSector.FloorPlane.Normal;
			FloorAngle = atan2(FloorNormal.XY.Length(), FloorNormal.Z);
			
			//==============================
			//Come to the logical conclusion
			
			if(FloorAngle < 45)
				return BlockJump ? True : False, !FloorAngle ? False : True;
			else
				return ZMPlayer.OnGround ? True : False, True; //floor is too steep
		}
    }
	
	void ElevatorJump(bool SlopedFloor)
	{
		Int SecIndex = FloorSector.Index();
		Bool CheckForElevator = ZMPlayer.OnGround && SecIndex == OldSecIndex && !SlopedFloor;
		
		if(zm_elevatorjump)
		{
			if(CheckForElevator && FloorZ > OldFloorZ) //no accidental elevator jump boost on slopes
				ElevatorJumpBoost = (FloorZ - OldFloorZ) * zm_ejumpmultiplier;
			else
				ElevatorJumpBoost = 0;
		}
		else
		{
			if(CheckForElevator && FloorZ - OldFloorZ >= zm_jumpheight / 2.f) { BlockJump = True; } //floor is raising too fast to not spam jump
			ElevatorJumpBoost = 0;
		}
		
		OldSecIndex = SecIndex;
	}
	
	void DGravity()
	{
		if(WaterLevel >= 2)
		{
			if(Vel.Length() < MaxGroundSpeed / 3.f)
				Gravity = 0.5f;
			else
				Gravity = 0.f;
		}
		else if(bNOGRAVITY)
		{
			Gravity = 0.f;
		}
		else
		{
			Gravity = zm_setgravity;
		}
	}
	
	Override void CheckJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(ZMPlayer.cmd.buttons & BT_JUMP)
		{
			if(ZMPlayer.crouchoffset != 0)
			{
				ZMPlayer.crouching = 1;
			}
			else if(ZMPlayer.OnGround && !BlockJump)
			{
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
				
				bOnMobj = false;
				Jumped = True;
				
				if(!(ZMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				//if autojump is off set BlockJump true until jump key is unpressed
				BlockJump = zm_autojump ? False : True;
			}
		}
		else
		{
			BlockJump = False;
		}
	}
	
	void BuildGravity()
	{
		if(!bNOGRAVITY && !WaterLevel < 2)
			Gravity = zm_setgravity;
		else
			Gravity = 0.f;
	}
	
	void BuildJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(ZMPlayer.cmd.buttons & BT_JUMP || BuildJumpDelay)
		{
			if(ZMPlayer.crouchoffset != 0)
			{
				ZMPlayer.crouching = 1;
			}
			else if(ZMPlayer.onground && !BlockJump)
			{
				Double BuildSmallerJump;
				
				if(ZMPlayer.deltaviewheight)
				{
					BuildSmallerJump = 0.85f;
				}
				else
				{
					BuildJumpDelay++;
					if(BuildJumpDelay == 1)
					{
						ZMPlayer.viewheight -= be_jumpanim;
						return;
					}
					else
					{
						BuildJumpDelay = 0;
						BuildSmallerJump = 1.f;
					}
				}
				
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
					
				bOnMobj = false;
				Jumped = True;
					
				if(!(ZMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				BlockJump = zm_autojump ? False : True;
			}
			else if(!ZMPlayer.OnGround)
			{
				if(BuildJumpDelay) { BuildJumpDelay = 0; }
			}
		}
		else
		{
			BlockJump = False;
		}
	}
	
	void PainkillerGravity()
	{
		if(WaterLevel >= 2)
		{
			if(Vel.Length() < MaxGroundSpeed / 3.f)
				Gravity = 0.5f;
			else
				Gravity = 0.f;
		}
		else if(bNOGRAVITY)
		{
			Gravity = 0.f;
		}
		else
		{
			Gravity = zm_setgravity;
		}
	}
	
	void PainkillerJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(ZMPlayer.cmd.buttons & BT_JUMP)
		{
			if(ZMPlayer.crouchoffset != 0)
			{
				ZMPlayer.crouching = 1;
			}
			else if(ZMPlayer.onground && !BlockJump)
			{
				SmallerJumpHeight++;
				
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
					
				Vel.Z += (SmallerJumpHeight > 1 ? pk_bhopjumpheight : 1) * (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
				
				bOnMobj = false;
				Jumped = True;
				
				if(!(ZMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				//if autojump is on set Blockjump false while jump key is pressed
				BlockJump = zm_autojump ? False : True;
			}
		}
		else
		{
			BlockJump = False;
		}
	}
	
	void UTGravity()
	{
		//Gravity
		if(WaterLevel >= 2)
		{
			if(Vel.Length() < MaxGroundSpeed / 3.f && !(ZMPlayer.cmd.buttons & BT_JUMP))
				Gravity = 0.5f;
			else
				Gravity = 0.f;
		}
		else if(bNOGRAVITY)
		{
			Gravity = 0.f;
		}
		else
		{
			Gravity = zm_setgravity;
		}
	}
	
	void UTJump()
	{
		//Common stuff
		PreJumpCommon();
		
		//underwater/flying specific jump behavior are in WaterMove and FlyMove
		if(WaterLevel >= 2 || bNOGRAVITY) { return; }
		
		//Check slope angle and sector height
		Bool SlopedFloor;
		[BlockJump, SlopedFloor] = CheckIfJumpable();
		
		//Elevators Jump Boost
		ElevatorJump(SlopedFloor);
		
		////////////////////////////////
		//Actual Jump
		if(ZMPlayer.cmd.buttons & BT_JUMP)
		{
			if(ZMPlayer.crouchoffset != 0)
			{
				ZMPlayer.crouching = 1;
			}
			else if(ZMPlayer.OnGround && !BlockJump)
			{
				Float JumpVelZ = zm_jumpheight + ElevatorJumpBoost;
				Float JumpFac = GetPowerJump();
				if(JumpFac) { JumpVelZ *= JumpFac; }
				
				Vel.Z += (Vel.Z > 0 ? zm_rjumpmulti : 1) * JumpVelZ;
				
				bOnMobj = false;
				Jumped = True;
				
				if(!(ZMPlayer.cheats & CF_PREDICTING) && !JumpSoundCooler)
				{
					A_PlaySound("*jump", CHAN_BODY);
					JumpSoundCooler = 4;
				}
				
				//if autojump is on set Blockjump false while jump key is pressed
				BlockJump = zm_autojump ? False : True;
			}
		}
		else
		{
			if(ZMPlayer.OnGround) { BlockJump = False; }
		}
	}
	
	//////////////////////////////////////////
	// Ground Movement						//
	//////////////////////////////////////////
	
	float ScaleMovement()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		Float MoveMulti;
		if(cmd.sidemove || cmd.forwardmove)
		{
			Bool IsWalking = (CVar.GetCVar("cl_run", Player).GetBool() && (cmd.buttons & BT_SPEED)) || (!CVar.GetCVar("cl_run", Player).GetBool() && !(cmd.buttons & BT_SPEED));
			
			if(ZMPlayer.CrouchFactor == 0.5)
				MoveMulti = min(zm_crouchspeed, zm_walkspeed);
			else if(IsWalking)
				MoveMulti = zm_walkspeed;
			else
				MoveMulti = 1;
		}
		else
		{
			MoveMulti = 1;
		}
		
		return MoveMulti;
	}
	
	float SpeedMulti()
	{
		return MoveFactor * (ZMPLayer.cmd.forwardmove && ZMPlayer.cmd.sidemove ? zm_strafemodifier : 1);
	}
	
	float AccelMulti()
	{
		return ActualSpeed * (ZMPlayer.cmd.forwardmove && ZMPLayer.cmd.sidemove ? zm_strafemodifier : 1);
	}
	
	void DropPrevention()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		Bool GuardRail = ((!cmd.sidemove && !cmd.forwardmove && Vel.XY.Length()) ||
						 (CVar.GetCVar("cl_run", Player).GetBool() && (cmd.buttons & BT_SPEED)) || (!CVar.GetCVar("cl_run", Player).GetBool() && !(cmd.buttons & BT_SPEED))) //fuck me having to do this
						 && ZMPlayer.OnGround && !Pain;
		
		if(GuardRail)
		{
			Float GuardAngle = VectorAngle(Vel.X, Vel.Y);
			Float GuardX = Pos.X + Radius * cos(GuardAngle);
			Float GuardY = Pos.Y + Radius * sin(GuardAngle);
			Bool FallDanger = Pos.Z - GetZAt(GuardX, GuardY, 0, GZF_ABSOLUTEPOS|GZF_ABSOLUTEANG) > Height;
			if(FallDanger) { Vel.XY *= 0.5f; }
		}
	}
	
	void GroundSpriteAnimation()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		if(ZMPlayer.Cheats & CF_PREDICTING == 0 && Vel.XY.Length() > 1.f && (cmd.forwardmove || cmd.sidemove))
			PlayRunning();
		else
			PlayIdle();
			
		AnimateJump = 6;
	}
	
	void AirSpriteAnimation()
	{
		if(AnimateJump)
		{
			PlayRunning();
			AnimateJump--;
		}
		else
		{
			PlayIdle();
		}
	}
	
	//=========================
	// Doom
	
	void DoomHandleMove()
	{	
		if(!ZMPlayer.OnGround)
		{
			DoomAirMove();
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			DoomGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void DFriction()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Going too slow, stop
		if(WaterLevel >= 2 || bNOGRAVITY)
		{
			if(Vel.Length() < 1.f && !cmd.sidemove && !cmd.forwardmove)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
		else if(Vel.XY.Length() < 1.f && !cmd.sidemove && !cmd.forwardmove)
		{
			Vel.XY = (0, 0);
			return;
		}
		
		//Balance friction with inputs strength
		if(WaterLevel >= 2)
		{
			Acceleration *= 4.f;
			Vel *= 0.6f;
		}
		else if(bNOGRAVITY)
		{
			Vel *= 0.9f;
		}
		else
		{
			Acceleration.XY *= zm_friction;
			Vel.XY *= 1 - zm_friction / 10.f;
		}
	}
	
	void DoomGroundMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 10.f) * SafeUnit2(Acceleration.XY);
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		// Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DoomAirMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 20.f) * SafeUnit2(Acceleration.XY);
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void WaterVelZLimiter()
	{
		//Avoids dolphin jumping out of water
		Vel.Z = min(6.f, Vel.Z);
		if(Pitch < 0) { Acceleration.Z = 0; }
	}
	
	void DoomWaterMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = (MaxGroundSpeed / 20.f) * SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * (MaxGroundSpeed / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DoomFlyMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//=========================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		if(Acceleration.Length()) { Acceleration.XY = (MaxGroundSpeed * 3.f / 20.f) * SafeUnit2(Acceleration.XY); }
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * (MaxGroundSpeed * 3.f / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Limiter
		Vel = min(Vel.Length(), (MaxGroundSpeed * 3.f) / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// Build Engine
	
	void BuildHandleMove()
	{
		MaxGroundSpeed *= SpeedMulti();
		
		if(!ZMPlayer.OnGround)
		{
			BuildAirMove();
		}
		else
		{
			BuildGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void BuildInputDetection()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		if(cmd.sidemove)
		{
			if(cmd.buttons & BT_MOVERIGHT)
				SVel += 40;
			else
				SVel -= 40;
				
			SVel = clamp(SVel, -90, 90);
		}
		else
		{
			SVel = 0;
		}
		
		if(cmd.forwardmove)
		{
			if(cmd.buttons & BT_FORWARD)
				FVel += 40;
			else
				FVel -= 40;
				
			FVel = clamp(FVel, -90, 90);
		}
		else
		{
			FVel = 0;
		}
		
		//Only for flying and swimming
		if(WaterLevel == 2 && DeepWater)
		{
			if(cmd.buttons & BT_JUMP)
			{
				if(Vel.Z > 0) { Vel.Z = 0.f; }
				UVel = 0;
				return;
			}
			else
			{
				DeepWater = False;
			}
		}
		
		if(bNOGRAVITY || WaterLevel >= 2)
		{
			if(cmd.buttons & BT_JUMP)
				UVel += 40;
			else if(cmd.buttons & BT_CROUCH)
				UVel -= 40;
			else
				UVel = 0;
				
			UVel = clamp(UVel, -90, 90);
		}
		else
		{
			UVel = 0;
		}
	}
	
	int BuildFriction()
	{
		//Friction Value
		Int Friction;
		if(WaterLevel >= 2)
			Friction = - 0x2000;
		else if(bNOGRAVITY)
			Friction = 0;
		else
			Friction = (8 - zm_friction) * 2 * 0x0200;
		
		//Applying the friction on the length of the vector instead of the single components fixed the Build engine directional distortion
		Int FrictionedVel = Int((!bNOGRAVITY && WaterLevel < 2 ? Vel.XY.Length() : Vel.Length()) * (0xCFD0 + Friction)) >> 16;
		
		return FrictionedVel <= 10.f ? 0 : FrictionedVel;
	}
	
	void BuildGroundMove()
	{
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		///////////////////////////////////////////
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel.XY *= 20.f;
		
		if(LandingVelZ < 10.f) //this value feels good
		{
			//Directional inputs
			BuildInputDetection();
			Acceleration.XY = RotateVector((FVel, - SVel), Angle);
			if(Acceleration.XY.Length()) { Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti(); }
			
			//Acceleration
			Vel.XY += Acceleration.XY;
		}
		else //landing recovery
		{
			LandingVelZ--;
		}
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Translate back into Doom Units
		Vel.XY /= 20.f;
		FrictionedVel /= 20.f;
		
		//Limiter
		Vel.XY = min(FrictionedVel, MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void BuildAirMove()
	{
		//Convert Velocity in Build Units
		Vel.XY *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.XY.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Limiter
		Vel.XY = min(FrictionedVel, MaxGroundSpeed * 20) * SafeUnit2(Vel.XY);
		
		//Translate back into Doom Units
		Vel.XY /= 20.f;
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void BuildWaterMove()
	{
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		if(WaterLevel == 3) { DeepWater = True; }
		
		///////////////////////////////////////////
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Crouch/jump press
		Vel.Z += UVel;
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Limiter
		Vel = min(FrictionedVel, MaxGroundSpeed * 15.f) * SafeUnit3(Vel);
		if(Deepwater && WaterLevel == 2 && Vel.Z > 0) { Vel.Z = 0; }
		
		//Translate back into Doom Units
		Vel /= 20.f;
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void BuildFlyMove()
	{
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		///////////////////////////////////////////
		//Actual Movement
		
		//Convert Velocity in Build Units
		Vel *= 20.f;
		
		//Directional inputs
		BuildInputDetection();
		Acceleration.XY = RotateVector((FVel, - SVel), Angle);
		Acceleration.XY = min(Acceleration.Length(), 90) * SafeUnit2(Acceleration.XY) * AccelMulti();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Crouch/jump press
		Vel.Z += UVel;
		
		//Friction
		Int FrictionedVel = BuildFriction();
		
		//Limiter
		Vel = min(FrictionedVel, MaxGroundSpeed * 30.f) * SafeUnit3(Vel);
		
		//Translate back into Doom Units
		Vel /= 20.f;
		
		// Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// Dusk
	
	void DuskHandleMove()
	{
		if(!ZMPlayer.OnGround || (ZMPlayer.OnGround && ((ZMPlayer.cmd.buttons & BT_JUMP) && !BlockJump)))
		{
			DuskAirMove();
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			DuskGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void DuskGroundMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, -cmd.sidemove), Angle);
		Acceleration.XY = (MaxGroundSpeed / 10.f) * SafeUnit2(Acceleration.XY);
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DuskAirMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		Bool CanAccelerate = ((cmd.buttons & BT_MOVERIGHT) && !(cmd.buttons & BT_MOVELEFT)) || (!(cmd.buttons & BT_MOVERIGHT) && (cmd.buttons & BT_MOVELEFT));
		
		//====================================
		//Actual Movement
		
		//Top Speed Penalty
		if(!CanAccelerate && ZMPlayer.OnGround) { MaxAirSpeed = max(MaxAirSpeed - dsk_acceleration * ActualSpeed / 2.f, MaxGroundSpeed); }
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		if(Acceleration.XY.Length())
		{
			Acceleration.XY = MaxAirSpeed * SafeUnit2(Acceleration.XY) / 3.f; //multiplying by Vel / 10.f mantains air control consistent at all speed
			
			//Top Speed
			if(ZMPlayer.OnGround && CanAccelerate) { MaxAirSpeed += dsk_acceleration * ActualSpeed; }
			MaxAirSpeed = clamp(MaxAirSpeed, MaxGroundSpeed, zm_maxhopspeed);
		}
		
		//Friction
		if(Vel.XY.Length() < 1.f)
			Vel.XY = (0, 0);
		else
			Vel.XY *= 0.8f;
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxAirSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void DuskWaterMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional Inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.XY = (0, 0);
			Acceleration.Z = (cmd.buttons & BT_CROUCH ? -1 : 1) * (MaxGroundSpeed * 3.f / 40.f) * ActualSpeed;
		}
		else
		{
			Acceleration.XY = (MaxGroundSpeed * 3.f / 40.f) * SafeUnit2(Acceleration.XY);
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void DuskFlyMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional Inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.XY = (0, 0);
			Acceleration.Z = (cmd.buttons & BT_CROUCH ? -1 : 1) * (MaxGroundSpeed * 3.f / 20.f) * ActualSpeed;
		}
		else
		{
			Acceleration.XY = (MaxGroundSpeed * 3.f / 20.f) * SafeUnit2(Acceleration.XY);
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		DFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//////////////////////////////////////////
	// Painkiller
	
	void PainkillerHandleMove()
	{
		if(!ZMPlayer.OnGround || (ZMPlayer.OnGround && ((ZMPLayer.cmd.buttons & BT_JUMP) && !BlockJump)))
		{
			PainkillerAirMove();
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			PainkillerGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void PainkillerFriction()
	{
		//Going too slow, stop
		if(WaterLevel >= 2 || bNOGRAVITY)
		{
			if(Vel.Length() < 1.f)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
		else if(Vel.XY.Length() < 1.f)
		{
			Vel.XY = (0, 0);
			return;
		}
		
		Float Friction; //I modded PK to print to console the length of the velocity vector and it increased and decreased by a fixed value
		if(WaterLevel >= 2 || bNOGRAVITY)
		{
			Friction = MaxGroundSpeed / (WaterLevel >= 2 ? 2.f : 10.f);
			
			if(Vel.Length() >= Friction)
				Vel -= Friction * SafeUnit3(Vel);
			else if(Vel.Length())
				Vel -= Vel.Length() * SafeUnit3(Vel);
		}
		else
		{
			Friction = MaxGroundSpeed / (12.f - zm_friction);
			
			if(Vel.XY.Length() >= Friction)
				Vel.XY -= Friction * SafeUnit2(Vel.XY);
			else if(Vel.XY.Length())
				Vel.XY -= Vel.XY.Length() * SafeUnit2(Vel.XY);
		}
	}
	
	void PainkillerValuesReset()
	{
		MaxAirSpeed = ActualMaxAirSpeed = max(Vel.XY.Length(), MaxGroundSpeed / 4.f);
		SmallerJumpHeight = TrickFailed = 0;
		AirControl = 1;
	}
	
	void PainkillerGroundMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Values Reset
		PainkillerValuesReset();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = (cmd.forwardmove, - cmd.sidemove);
		Acceleration.XY = MaxGroundSpeed * 0.6f * SafeUnit2(Acceleration.XY);
		
		//Friction
		PainkillerFriction();
		
		//Acceleration
		Vel.XY += RotateVector(Acceleration.XY, Angle);
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void PainkillerAirMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		Vector2 DirInput = SafeUnit2((cmd.forwardmove, - cmd.sidemove));
		ActualMaxAirSpeed = Vel.XY.Length(); //if speed is forcefully lowered due to impact with walls or actors we need to get along with that. Not lowering going up stairs
		
		if(!TrickFailed)
		{
			//Air Control
			AirControlCheck(DirInput.Length());
			//Trickjump check
			if(DirInput.Length()) { TrickJumpCheck(DirInput); }
		}
		
		if(ZMPlayer.OnGround) //ground hop
		{
			if(TrickFailed) //Trick jump failed
			{
				Acceleration.XY = MaxAirSpeed * DirInput;
				MaxAirSpeed = MaxGroundSpeed / 2.f; //penalty
				Vel.XY = RotateVector(Acceleration.XY, Angle); //redirect movement in the pressed direction before applying the uber low air control
				AirControl = 0.01f;
				TrickFailed = False;
			}
			else if(AirControl == 1) //regular movement
			{
				//Directional inputs
				Acceleration.XY = MaxAirSpeed * DirInput;
				
				//Top Speed
				if(ZMPlayer.CrouchFactor == 1) { MaxAirSpeed = clamp(Vel.XY.Length() + pk_acceleration * ActualSpeed, MaxGroundSpeed, zm_maxhopspeed); } //no cheap speed up coming out of QSlide
				ActualMaxAirSpeed = MaxAirSpeed;
			}
			else
			{
				//Top Speed
				MaxAirSpeed = clamp(Vel.XY.Length() - pk_acceleration * ActualSpeed, MaxGroundSpeed, zm_maxhopspeed);
			}
			
			//Acceleration
			Vel.XY += RotateVector(Acceleration.XY, Angle) * AirControl;
			
			//Limiter
			Vel.XY = min(Vel.XY.Length(), MaxAirSpeed) * SafeUnit2(Vel.XY);
		}
		else //mid air
		{
			if(TrickFailed) //Trick jump failed
			{
				PainkillerFriction();
			}
			else //regular movement
			{
				//Acceleration
				Vel.XY += RotateVector(Acceleration.XY, Angle) * AirControl;
				
				//Top speed penality
				TopSpeedPenality();
				
				//Limiter
				Vel.XY = min(Vel.XY.Length(), ActualMaxAirSpeed) * SafeUnit2(Vel.XY);
			}
		}
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void AirControlCheck(Bool DirInput)
	{
		if(!DirInput || Pain)
		{
			AirControl = 0.01f;
			if(!DirInput && Vel.XY.Length() <= 1.f)
			{
				Acceleration.XY = (0, 0);
				Vel.XY = (0, 0);
			}
		}
		else
		{
			AirControl = 1;
		}
	}
	
	void TrickJumpCheck(Vector2 DirInput)
	{
		Bool BadTrick = SafeUnit2(Acceleration.XY) dot DirInput <= 0;
		
		if(abs(FloorZ - Pos.Z) > 16)
		{
			if(BadTrick)
				TrickFailed = True;
			else
				TrickJumpAngle = Angle;
		}
		else
		{
			if(BadTrick && abs(Angle - TrickJumpAngle) < 90) { TrickFailed = True; }
		}
	}
	
	void TopSpeedPenality()
	{
		//Directional change top speed penalty
		Float AbsViewAngleDelta = abs(ViewAngleDelta);									//In Painkiller speed punishment
		if(AbsViewAngleDelta >= 3.f)													//is 5 times the angle variation,		
			ActualMaxAirSpeed -= AbsViewAngleDelta * 0.01f; //this feels good			//although in that engine view angle
		else																			//is 0 to pi for real world 0 to 180,
			ActualMaxAirSpeed += 0.2f; //this too										//and -pi to 0 for 180 to 360.
		
		ActualMaxAirSpeed = clamp(ActualMaxAirSpeed, MaxGroundSpeed, MaxAirSpeed);		//This is an as close as possible imitation
	}
	
	void PainkillerWaterMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		PainkillerValuesReset();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = (MaxGroundSpeed / 2.f) * SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 30.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		PainkillerFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Limiter
		Vel = min(Vel.Length(), MaxGroundSpeed / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animation
		GroundSpriteAnimation();
		
		//Set acceleration for when you stop swimming
		Acceleration.XY = 30.f * SafeUnit2(Acceleration.XY);
	}
	
	void PainkillerFlyMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		PainkillerValuesReset();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = (MaxGroundSpeed * 3.f) / 2.f * SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 30.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		PainkillerFriction();
		
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		
		//Limiter
		Vel = min(Vel.Length(), (MaxGroundSpeed * 3.f) / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animatiom
		PlayIdle();
		
		//Set acceleration for when the flight ends
		Acceleration.XY = 30.f * SafeUnit2(Acceleration.XY);
	}
	
	//====================================
	// Quake
	
	void QuakeHandleMove()
	{
		if(!ZMPlayer.OnGround || (ZMPlayer.OnGround && ((ZMPLayer.cmd.buttons & BT_JUMP) && !BlockJump)))
		{
			QuakeAirMove();
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			QuakeGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void QuakeFriction(float StopSpeed, float Friction)
	{
		if(Vel.Length() > 100000) //WTF bro
		{
			Vel = (0, 0, 0);
			return;
		}
		else if(WaterLevel >= 2 || bNOGRAVITY)
		{
			if(Vel.Length() < 0.5f)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
		else if(Vel.XY.Length() < 1.f)
		{
			Vel.XY = (0, 0);
			return;
		}
		
		Double Velocity = Vel.Length();
		Double Drop, Control;
		if(WaterLevel >= 2)
		{
			drop = Velocity * Friction / TICRATE; //very tight friction
		}
		else if(bNOGRAVITY)
		{
			drop = Velocity * Friction / TICRATE; //loose friction
		}
		else if(ZMPlayer.OnGround)
		{
			if(!Pain)
			{
				Control = Velocity < StopSpeed ? zm_friction : Velocity;
				Drop = Control * Friction / TICRATE;
			}
		}
		
		Double NewVelocity = (Velocity - Drop <= 0 ? 0 : Velocity - Drop) / Velocity;
		if(WaterLevel >= 2 || bNOGRAVITY)
			Vel *= NewVelocity;
		else
			Vel.XY *= NewVelocity;
	}
	
	void QuakeAcceleration(Vector3 WishDir, Float WishSpeed, Float Accel)
	{
		Float CurrentSpeed = WishDir dot Vel;
		Float AddSpeed = WishSpeed - CurrentSpeed;
		if(AddSpeed <= 0) { return; }
		
		Float AccelerationSpeed = min(Accel * WishSpeed / TICRATE, AddSpeed);
		Vel += AccelerationSpeed * WishDir;
	}
	
	void QuakeGroundMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		
		//Friction
		QuakeFriction(MaxGroundSpeed, 6.f);
	
		//Acceleration
		QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, Pain ? 1.f : 10.f / MoveFactor);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void QuakeAirMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		
		//Acceleration
		if(!q_strafetype)
		{
			QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, q_3airaccel);
		}
		else if(q_strafetype == 1)
		{
			QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), q_1airaccel, 106.f);
		}
		else
		{
			if(cmd.sidemove && !cmd.forwardmove)
				QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), q_1airaccel, 106.f);
			else
				QuakeAcceleration((SafeUnit2(Acceleration.XY), 0), MaxGroundSpeed, q_3airaccel);
		}
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), zm_maxhopspeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		AirSpriteAnimation();
	}
	
	void QuakeWaterMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1);
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		QuakeFriction(0, 2.f);
		
		//Acceleration
		Acceleration = (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		QuakeAcceleration(SafeUnit3(Acceleration), (MaxGroundSpeed * 3.f) / 5.f, 4.f / MoveFactor);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void QuakeFlyMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, -cmd.sidemove, 0);
		//XY
		Acceleration.XY = SafeUnit2(Acceleration.XY);
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1);
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		QuakeFriction(0, 3.f);
		
		//Acceleration
		Acceleration = (RotateVector(Acceleration.XY, Angle), Acceleration.Z);
		QuakeAcceleration(SafeUnit3(Acceleration), (MaxGroundSpeed * 3.f) / 2.f, 8.f / MoveFactor);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//====================================
	// UT
	
	void UTHandleMove()
	{
		if(!ZMPlayer.OnGround)
		{
			UTAirMove();
		}
		else
		{
			MaxGroundSpeed *= SpeedMulti();
			UTGroundMove();
			if(zm_dropprevention) { DropPrevention(); }
		}
	}
	
	void UTFriction(Float BrakeFriction)
	{
		if(!Vel.XY.Length()) { return; }
		
		Float RemainingTime = 1.f / TICRATE;
		Float MaxTimeStep = 1.f / 33.f;
		
		while(RemainingTime >= 0.0002f) //value taken from UT4 source code
		{
			Float dt = min(MaxTimeStep, RemainingTime * 0.5f);
			RemainingTime -= dt;
			
			Vel.XY = Vel.XY - BrakeFriction * Vel.XY * dt ;
			
			if(Vel.XY.Length() <= 1.f)
			{
				Vel.XY = (0, 0);
				return;
			}
		}
	}
	
	void UTGroundMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Values Reset
		MaxAirSpeed = Vel.XY.Length();
		
		///////////////////////////////////////////
		//Actual Movement
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		Acceleration.XY = 200.f * SafeUnit2(Acceleration.XY) * AccelMulti() / zm_friction;
		
		//Friction
		if(Acceleration.Length())
			Vel.XY = Vel.XY - (Vel.XY - Acceleration.XY * Vel.XY.Length()) / TICRATE;
		else
			UTFriction(1.5f * zm_friction); //this feels good
		
		//Acceleration
		Vel.XY += Acceleration.XY / TICRATE;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxGroundSpeed) * SafeUnit2(Vel.XY);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void UTAirMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Directional inputs
		Acceleration.XY = RotateVector((cmd.forwardmove, - cmd.sidemove), Angle);
		Acceleration.XY = 0.62f * SafeUnit2(Acceleration.XY);
		
		//Acceleration
		Vel.XY += Acceleration.XY;
		
		//Limiter
		Vel.XY = min(Vel.XY.Length(), MaxAirSpeed > MaxGroundSpeed ? MaxAirSpeed : MaxGroundSpeed) * SafeUnit2(Vel.XY);
			
		//Sprite Animation
		AirSpriteAnimation();
		
		//Reset speed cap
		if(Vel.XY.Length() <= MaxGroundSpeed) { MaxAirSpeed = Vel.XY.Length(); }
	}
	
	void UTWaterFlyFriction(Float BrakeFriction)
	{
		if(Vel.Length() < 1.f) { return; }
		
		Float RemainingTime = 1.f / TICRATE;
		Float MaxTimeStep = 1.f / 33.f;
		
		while(RemainingTime >= 0.0002f) //value taken from UT4 source code
		{
			Float dt = min(MaxTimeStep, RemainingTime * 0.5f);
			RemainingTime -= dt;
			
			Vel = Vel - BrakeFriction * Vel * dt;
			
			if(Vel.Length() <= 1.f)
			{
				Vel = (0, 0, 0);
				return;
			}
		}
	}
	
	void UTWaterMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		//XY
		Acceleration.XY = 10.f * SafeUnit2(Acceleration.XY) * AccelMulti();
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 10.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		if(WaterLevel == 2) { WaterVelZLimiter(); }
		if(Acceleration.Length())
			Vel = Vel - (Vel - (RotateVector(Acceleration.XY, Angle), Acceleration.Z) * Vel.Length()) / TICRATE;
		else
			UTWaterFlyFriction(2.f);
			
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z) / TICRATE;
		
		//Limiter
		Vel = min(Vel.Length(), MaxGroundSpeed / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animation
		GroundSpriteAnimation();
	}
	
	void UTFlyMove()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		//Value Resets
		MaxAirSpeed = Vel.XY.Length();
		
		//====================================
		//Actual Movement
		
		//Directional inputs
		Acceleration = (cmd.forwardmove, - cmd.sidemove, 0);
		//XY
		Acceleration.XY = 20.f * SafeUnit2(Acceleration.XY) * AccelMulti();
		//Z
		if(cmd.buttons & BT_JUMP || cmd.buttons & BT_CROUCH)
		{
			Acceleration.Z = (cmd.buttons & BT_JUMP ? 1 : -1) * 20.f * ActualSpeed;
		}
		else
		{
			Acceleration.Z = Acceleration.X * sin(-Pitch);
			Acceleration.X *= cos(Pitch);
		}
		
		//Friction
		if(Acceleration.Length())
			Vel = Vel - (Vel - (RotateVector(Acceleration.XY, Angle), Acceleration.Z) * Vel.Length()) / TICRATE;
		else
			UTWaterFlyFriction(2.f);
			
		//Acceleration
		Vel += (RotateVector(Acceleration.XY, Angle), Acceleration.Z) / TICRATE;
		
		//Limiter
		Vel = min(Vel.Length(), (MaxGroundSpeed * 3.f) / 2.f) * SafeUnit3(Vel);
		
		//Sprite Animatiom
		PlayIdle();
	}
	
	//////////////////////////////////////////
	// Crouching							//
	//////////////////////////////////////////
	
	//====================================
	// Regular crouching
	
	Override void CheckCrouch(bool totallyfrozen)
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		if(cmd.buttons & BT_JUMP)
		{
			cmd.buttons &= ~BT_CROUCH;
		}
		
		if(ZMPlayer.health > 0)
		{
			if(!totallyfrozen)
			{
				int crouchdir = ZMPlayer.crouching;
				
				if(bNOGRAVITY || WaterLevel >= 2) //forcefully uncrouch when flying/swimming
					crouchdir = 1;
				else if(crouchdir == 0)
					crouchdir = (cmd.buttons & BT_CROUCH) ? -1 : 1;
				else if(cmd.buttons & BT_CROUCH)
					ZMPlayer.crouching = 0;
				
				if(crouchdir == 1 && ZMPlayer.crouchfactor < 1 && pos.Z + height < ceilingz)
					CrouchMove(1);
				else if(crouchdir == -1 && ZMPlayer.crouchfactor > 0.5)
					CrouchMove(-1);
			}
		}
		else
		{
			ZMPlayer.Uncrouch();
		}

		ZMPlayer.crouchoffset = -(ViewHeight) * (1 - ZMPlayer.crouchfactor);
	}
	
	Override void CrouchMove(int direction)
	{
		double defaultheight = FullHeight;
		double savedheight = Height;
		double crouchspeed = direction * CROUCHSPEED;
		double oldheight = ZMPlayer.viewheight;

		ZMPlayer.crouchdir = direction;
		ZMPlayer.crouchfactor += crouchspeed;

		// check whether the move is ok
		Height  = defaultheight * ZMPlayer.crouchfactor;
		if(!TryMove(Pos.XY, false, NULL))
		{
			Height = savedheight;
			if(direction > 0)
			{
				// doesn't fit
				ZMPlayer.crouchfactor -= crouchspeed;
				return;
			}
		}
		Height = savedheight;

		ZMPlayer.crouchfactor = clamp(ZMPlayer.crouchfactor, 0.5, 1.);
		ZMPlayer.viewheight = ViewHeight * ZMPlayer.crouchfactor;
		ZMPlayer.crouchviewdelta = ZMPlayer.viewheight - ViewHeight;

		// Check for eyes going above/below fake floor due to crouching motion.
		CheckFakeFloorTriggers(pos.Z + oldheight, true);
	}
	
	//////////////////////////////////////
	// Bobbing							//
	//////////////////////////////////////
	
	void BobWeaponAuxiliary()
	{
		Usercmd cmd = ZMPlayer.cmd;
		
		Float Velocity = min(Vel.XY.Length(), zm_maxgroundspeed);
		Bool  InTheAirNoOffset = bNOGRAVITY || WaterLevel >= 2;
		Bool  InTheAir = Jumped || abs(FloorZ - Pos.Z) > 16 || InTheAirNoOffset;
		
		//////////////////////////////////////////
		//Bobbing counter						//
		/////////////////////////////////////////
		
		DoBob = (cmd.forwardmove || cmd.sidemove) && Velocity > 1.f && !InTheAir && !VerticalOffset;
		if(DoBob || BobRange)
			BobTime += Velocity / zm_maxgroundspeed;
		else
			BobTime = 0;
		
		//////////////////////////////////////////
		//Horizontal sway and Vertical offset	//
		//////////////////////////////////////////
		
		Let PWeapon = ZMPlayer.ReadyWeapon;
		if(PWeapon == Null || PWeapon.bDontBob || !(ZMPlayer.WeaponState & WF_WEAPONBOBBING))
		{
			HorizontalSway = VerticalOffset = 0;
			return;
		}
		
		Let WeaponSprite = ZMPlayer.PSprites;
		if(WeaponSprite == Null) { return; }
		
		//=========================================
		//Horizontal Sway
		
		if(CVar.GetCVar("zm_sway", Player).GetBool())
		{
			HorizontalSway += (CVar.GetCVar("zm_swaydirection", Player).GetBool() ? -1 : 1) *
						       ViewAngleDelta * CVar.GetCVar("zm_swayspeed", Player).GetFloat() / 10;
			Int SwayRange = CVar.GetCVar("zm_swayrange", Player).GetInt();
			HorizontalSway = clamp(HorizontalSway, -SwayRange, SwayRange);
			
			if(HorizontalSway)
			{
				Float Realign = min(abs(HorizontalSway), SwayRange - 1);
				HorizontalSway *= Realign / SwayRange * (abs(HorizontalSway) > BOB_MIN_REALIGN);
			}
			
			WeaponSprite.X = HorizontalSway;
		}
		
		//=========================================
		//Vertical offset
		
		if(CVar.GetCVar("zm_offset", Player).GetBool())
		{
			Int	OffsetRange = CVar.GetCVar("zm_offsetrange", Player).GetInt();
			
			if(InTheAir && !InTheAirNoOffset)
			{
				Float OffsetSpeed = CVar.GetCVar("zm_offsetspeed", Player).GetFloat();
				
				if(!CVar.GetCVar("zm_offsetdirection", Player).GetBool())
				{
					if(Vel.Z >= 0)
						VerticalOffset += OffsetSpeed * Vel.Z * (1. - abs(VerticalOffset) / OffsetRange);
					else
						VerticalOffset += OffsetSpeed * Vel.Z * max(abs(VerticalOffset) / OffsetRange, 1);
				}
				else
				{
					if(Vel.Z >= 0)
						VerticalOffset -= OffsetSpeed * Vel.Z * max(abs(VerticalOffset) / OffsetRange, 1);
					else
						VerticalOffset -= OffsetSpeed * Vel.Z * (1. - abs(VerticalOffset) / OffsetRange);
				}
				VerticalOffset = clamp(VerticalOffset, 0, OffsetRange);
			}
			else if(VerticalOffset)
			{
				Float Realign = min(abs(VerticalOffset), OffsetRange - 1);
				VerticalOffset *= Realign / OffsetRange * (abs(VerticalOffset) > BOB_MIN_REALIGN);
			}
			
			WeaponSprite.Y = VerticalOffset + 32;
		}
	}
	
	void GetBobMulti(double ticfrac) //bobbing range and smooth transitioning
	{
		if(DoBob)
		{
			Double BobRangeCandidate = zm_maxgroundspeed * MoveFactor;
			if(BobRangeCandidate == BobRange) { return; }
			
			if(BobRangeCandidate > BobRange)
				BobRange = min(BobRange + abs(OldTicFrac - ticfrac) * abs(BobRangeCandidate - BobRange) / zm_maxgroundspeed, BobRangeCandidate); //make transitions proportional to frame time for fps consistency
			else
				BobRange = max(BobRange - abs(OldTicFrac - ticfrac) * abs(BobRangeCandidate - BobRange) / zm_maxgroundspeed, BobRangeCandidate); //and make the transition proportional to the value difference
		}
		else if(BobRange)
		{
			BobRange = max(BobRange - abs(OldTicFrac - ticfrac), 0);
		}
		OldTicFrac = ticfrac;
	}
	
	Override Vector2 BobWeapon(double ticfrac)
	{
		if(!ZMPlayer) { return (0, 0); }
		
		let weapon = ZMPlayer.ReadyWeapon;
		if(weapon == null) { return (0, 0); }
		
		Vector2 r;
		GetBobMulti(ticfrac);
		int bobstyle = weapon.BobStyle;
		double RangeY = weapon.BobRangeY;
		if(weapon.bDontBob || !BobRange || !(ZMPlayer.WeaponState & WF_WEAPONBOBBING)) //I should add a variable to do this very cleanly but I don't wanna
		{
			BobRange = BobTime = 0;
			switch(bobstyle)
			{
			case Bob_Dusk:
				r.Y = zm_maxgroundspeed * RangeY;
				break;
				
			case Bob_Painkiller:
				r.Y = zm_maxgroundspeed * RangeY;
				break;
					
			case Bob_UT:
				r.Y = zm_maxgroundspeed * RangeY;
			}
			return r;
		}
		
		double BobSpeed = weapon.BobSpeed * 128;
		double bobx = weapon.BobRangeX * BobRange;
		double boby = RangeY * BobRange;
		Vector2 p1, p2;
		
		for(int i = 0; i < 2; i++)
		{
			double BobAngle = BobSpeed * ZMPlayer.GetWBobSpeed() * (BobTime + i - 1) * (360. / 8192.);
			
			switch(bobstyle)
			{
			case Bob_Normal:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * abs(sin(BobAngle));
				break;
			
			case Bob_Inverse:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
				
			case Bob_Alpha:
				r.X = bobx * sin(BobAngle);
				r.Y = boby * abs(sin(BobAngle));
				break;
			
			case Bob_InverseAlpha:
				r.X = bobx * sin(BobAngle);
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
			
			case Bob_Smooth:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. - (cos(BobAngle * 2))) / 2.f;
				break;
			
			case Bob_InverseSmooth:
				r.X = bobx * cos(BobAngle);
				r.Y = boby * (1. + (cos(BobAngle * 2))) / 2.f;
			
			case Bob_Build:
				r.X = 2. * bobx * cos(BobAngle);	
				r.Y = boby * (1. - abs(sin(BobAngle)));
				break;
			
			case Bob_Dusk:
				r.X = bobx * cos((BobAngle * 2.) / 3.);
				r.Y = boby * (cos(2.2 * BobAngle)) + zm_maxgroundspeed * RangeY;
				break;
			
			case Bob_Painkiller:
				r.X = bobx * cos(BobAngle);	
				r.Y = - boby * (1. - abs(sin(BobAngle))) + zm_maxgroundspeed * RangeY;
				break;
							
			case Bob_UT:
				r.X = 1.5 * bobx * cos(BobAngle);	
				r.Y = boby * sin(2. * BobAngle) + zm_maxgroundspeed * RangeY;
			}
			
			if (i == 0) p1 = r; else p2 = r;
		}
		
		return p1 * (1. - ticfrac) + p2 * ticfrac;
	}
}