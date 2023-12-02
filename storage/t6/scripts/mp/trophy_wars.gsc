#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

main()
{
	replaceFunc( maps\mp\bots\_bot_combat::threat_should_ignore, ::threat_should_ignore_override );
}

threat_should_ignore_override( entity )
{
	ignore_time = self.bot.ignore_entity[entity getentitynumber()];

	if ( isdefined( ignore_time ) )
	{
		if ( gettime() < ignore_time )
			return true;
	}

	if ( isDefined( entity ) && isPlayer( entity ) && is_true( entity.is_assassin ) 
		&& is_true( entity.assassin_vars[ "invisibility" ].invisible ) )
	{
		return true;
	}

	return false;
}

init()
{
	level.trophy_systems = [];
	level.trophy_systems[ "allies" ] = [];
	level.trophy_systems[ "axis" ] = [];
	for ( i = 3; i < getGametypeSetting( "teamCount" ); i++ )
	{
		level.trophy_systems[ "team" + i ] = [];
	}

	set_dvar_if_unset( "trophy_system_invis_reveal_radius", 387 );
	set_dvar_if_unset( "trophy_wars_assassin_assassinate_cooldown", 15 );
	set_dvar_if_unset( "trophy_system_reveal_delay_ms", 1500 );
	set_dvar_if_unset( "assassin_invis_restore_factor", 2.5 );
	set_dvar_if_unset( "assassin_invis_decay_factor", 1.0 );

	level thread on_player_connect();

	level waittill( "prematch_over" );
	wait 1;
	level.callbackplayerdamage_old2 = level.callbackplayerdamage;
	level.callbackplayerdamage = ::trophy_wars_player_damage;
}

player_shield_facing_attacker( vdir, limit )
{
	orientation = self getplayerangles();
	forwardvec = anglestoforward( orientation );
	forwardvec2d = ( forwardvec[0], forwardvec[1], 0 );
	unitforwardvec2d = vectornormalize( forwardvec2d );
	tofaceevec = vdir * -1;
	tofaceevec2d = ( tofaceevec[0], tofaceevec[1], 0 );
	unittofaceevec2d = vectornormalize( tofaceevec2d );
	dotproduct = vectordot( unitforwardvec2d, unittofaceevec2d );
	return dotproduct > limit;
}

trophy_wars_player_damage( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, timeoffset, boneindex )
{
	if ( isDefined( sweapon ) )
	{
		switch ( sweapon )
		{
			case "trophy_system_mp":
				idamage = int( self.maxhealth / 2 ) + 1;
				break;
			case "knife_held_mp":
				if ( eattacker.is_assassin && eattacker.assassin_vars[ "assassinate" ].cooldown == 0 )
				{
					idamage = self.maxhealth;
				}
				else 
				{
					idamage = int( self.maxhealth / 2 ) + 1;
				}
				break;
			case "knife_mp":
			case "riotshield_mp":
				idamage = int( self.maxhealth / 2 ) + 1;
				break;
			case "knife_ballistic_mp":
				if ( isDefined( eattacker ) && distanceSquared( eattacker.origin, self.origin ) > 10000 )
				{
					idamage = self.maxhealth;
				}
				else
				{
					idamage = int( self.maxhealth / 2 ) + 1;
				}
				break;
			case "concussion_grenade_mp":
			case "proximity_grenade_aoe_mp":
				idamage = int( self.maxhealth / 2 ) + 1;
				break;
			case "claymore_mp":
			case "satchel_charge_mp":
			case "sticky_grenade_mp":
				idamage = self.maxhealth;
				break;
		}
	}

	if ( self.is_assassin )
	{
		self.assassin_vars[ "invisibility" ].current = -999;
	}
	
	self [[ level.callbackplayerdamage_old2 ]]( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, timeoffset, boneindex );
}

on_player_connect()
{
	for (;;)
	{
		level waittill( "connected", player );
		player thread on_player_spawned();

		player.is_assassin = false;
		player.assassin_vars = [];
		player.assassin_vars[ "assassinate" ] = spawnStruct();
		player.assassin_vars[ "assassinate" ].cooldown = 0;
		player.assassin_vars[ "assassinate" ].hud = spawnStruct();
		player.assassin_vars[ "assassinate" ].hud.timer = player createclienttimer( "objective", 1.5 );
		player.assassin_vars[ "assassinate" ].hud.timer.alpha = 0;
		player.assassin_vars[ "assassinate" ].hud.timer setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, 10 );
		player.assassin_vars[ "assassinate" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "assassinate" ].hud.text.alpha = 0;
		player.assassin_vars[ "assassinate" ].hud.text.label = &"ASSASSINATE";
		player.assassin_vars[ "assassinate" ].hud.text setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, -10 );
		player.assassin_vars[ "invisibility" ] = spawnStruct();
		player.assassin_vars[ "invisibility" ].invisible = false;
		player.assassin_vars[ "invisibility" ].hud = spawnStruct();
		player.assassin_vars[ "invisibility" ].hud.bar = player createbar( ( 1, 1, 1 ), 55, 8, 0.8 );
		player.assassin_vars[ "invisibility" ].hud.bar seticonshader( "progress_bar_bg" );
		player.assassin_vars[ "invisibility" ].hud.bar hideelem();
		player.assassin_vars[ "invisibility" ].hud.bar setpoint( "BOTTOM", "BOTTOM", 0, 20 );
		player.assassin_vars[ "invisibility" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
		player.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
		player.assassin_vars[ "invisibility" ].hud.text setpoint( "BOTTOM", "BOTTOM", 0, 10 );
		player.assassin_vars[ "invisibility" ].current = 50;
	}
}

on_player_spawned()
{
	for (;;)
	{
		self waittill( "spawned_player" );
		if ( self hasPerk( "specialty_gpsjammer" ) )
		{
			self.is_assassin = true;
			self.assassin_vars[ "invisibility" ].hud.bar showelem();
			self.assassin_vars[ "invisibility" ].hud.text.alpha = 1;
			self.assassin_vars[ "assassinate" ].hud.timer.alpha = 1;
			self.assassin_vars[ "assassinate" ].hud.text.alpha = 1;
			self setPerk( "specialty_noname" );
			self change_player_visibility( true );
			self thread calculate_invisibility_value();
			self thread watch_for_death();
			self thread watch_attacking();
			self thread watch_assasin_assassinate_ability();
			self thread watch_weapon_pickup();
		}
	}
}

watch_for_death()
{
	self endon( "disconnect" );
	self waittill( "death" );

	self.is_assassin = false;

	self.assassin_vars[ "invisibility" ].hud.bar hideelem();
	self.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
	self.assassin_vars[ "invisibility" ].invisible = false;
	self.assassin_vars[ "invisibility" ].current = 0;
	self.assassin_vars[ "assassinate" ].cooldown = 0;
	self.assassin_vars[ "assassinate" ].hud.timer.alpha = 0;
	self.assassin_vars[ "assassinate" ].hud.text.alpha = 0;

	self change_player_visibility( false );
}

change_player_visibility( invisible )
{
	players = getPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isDefined( players[ i ] ) && isDefined( players[ i ].team ) && players[ i ].team != self.team )
		{
			if ( invisible )
			{
				self setInvisibleToPlayer( players[ i ] );
			}
			else
			{
				self setVisibleToPlayer( players[ i ] );
			}
		}
	}
	if ( invisible )
	{
		self.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
		self.assassin_vars[ "invisibility" ].hud.text.color = ( 0, 0.8, 0 );
	}
	else
	{
		self.assassin_vars[ "invisibility" ].hud.text.label = &"VISIBLE";
		self.assassin_vars[ "invisibility" ].hud.text.color = ( 0.8, 0, 0 );
	}

	self.assassin_vars[ "invisibility" ].invisible = invisible;
}

calculate_trophy_reveal_decay( distance )
{
	const max_decay = 100;
	
	return ( ( -1 / pow( getDvarInt( "trophy_system_invis_reveal_radius" ) / 10, 2 ) ) * pow( distance, 2 ) ) + max_decay; 
}

calculate_invisibility_value()
{
	self endon( "disconnect" );
	self endon( "death" );

	const max_amount = 100;
	const min_amount = 0;
	for (;;)
	{
		wait 0.05;

		drain_percent_per_tick = 0;

		drain_percent_per_tick += getDvarFloat( "assassin_invis_decay_factor" );
		speed = length( self getVelocity() );

		growth_percent_per_tick = (speed / getDvarInt( "g_speed" )) * getDvarFloat( "assassin_invis_restore_factor" );

		if ( self revealing_attack_action() )
		{
			drain_percent_per_tick += 999;
		}

		trophy_modifier = calculate_trophy_reveal_decay( self distance_from_closest_trophy() );

		if ( trophy_modifier > 0 )
		{
			drain_percent_per_tick += trophy_modifier;
		}

		self.assassin_vars[ "invisibility" ].current += growth_percent_per_tick;

		self.assassin_vars[ "invisibility" ].current -= drain_percent_per_tick;

		if ( self.assassin_vars[ "invisibility" ].current <= min_amount )
		{
			self.assassin_vars[ "invisibility" ].current = min_amount;
			self change_player_visibility( false );
		}
		else if ( self.assassin_vars[ "invisibility" ].current >= max_amount)
		{
			self.assassin_vars[ "invisibility" ].current = max_amount;
			self change_player_visibility( true );
		}

		self.assassin_vars[ "invisibility" ].hud.bar updateBar( self.assassin_vars[ "invisibility" ].current / max_amount );
	}
}

revealing_attack_action()
{
	should_reveal = self secondaryoffhandbuttonpressed() && isDefined( self.grenadetypesecondary ) && self getWeaponAmmoStock( self.grenadetypesecondary ) > 0 
			|| self fragbuttonpressed() && isDefined( self.grenadetypeprimary ) && self getWeaponAmmoStock( self.grenadetypeprimary ) > 0;
	
	if ( should_reveal )
	{
		return true;
	}

	if ( !self actionslotfourbuttonpressed() )
	{
		return false;
	}

	currentkillstreak = 0;

	for ( killstreaknum = 0; killstreaknum < level.maxkillstreaks; killstreaknum++ )
	{
		killstreakindex = maps\mp\gametypes\_class::getkillstreakindex( self.class_num, killstreaknum );

		if ( isdefined( killstreakindex ) && killstreakindex > 0 )
		{
			assert( isdefined( level.tbl_killstreakdata[killstreakindex] ), "KillStreak #:" + killstreakindex + "'s data is undefined" );

			if ( isdefined( level.tbl_killstreakdata[killstreakindex] ) )
			{
				self.killstreak[currentkillstreak] = level.tbl_killstreakdata[killstreakindex];

				if ( isdefined( level.usingmomentum ) && level.usingmomentum )
				{
					killstreaktype = maps\mp\killstreaks\_killstreaks::getkillstreakbymenuname( self.killstreak[currentkillstreak] );

					if ( isdefined( killstreaktype ) )
					{
						weapon = maps\mp\killstreaks\_killstreaks::getkillstreakweapon( killstreaktype );

						return self getWeaponAmmoStock( weapon ) > 0;
					}
				}
			}
		}
	}

	return false;
}

distance_from_closest_trophy()
{
	closest = 2147000000;
	trophy_teams = getArrayKeys( level.trophy_systems );
	for ( i = 0; i < trophy_teams.size; i++ )
	{
		if ( trophy_teams[ i ] == self.team )
		{
			continue;
		}
		trophies = level.trophy_systems[ trophy_teams[ i ] ];
		if ( !isDefined( trophies ) )
		{
			continue;
		}
		
		for ( j = 0; j < trophies.size; j++ )
		{
			if ( !isDefined( trophies[ j ] ) || !isDefined( trophies[ j ].spawn_time ) )
			{
				continue;
			}
			if ( getTime() < trophies[ j ].spawn_time + getDvarInt( "trophy_system_reveal_delay_ms" ) )
			{
				continue;
			}
			distance_from_trophy = distance( trophies[ j ].origin, self.origin );
			if ( distance_from_trophy < closest )
			{
				closest = distance_from_trophy;
			}
		}
	}

	return closest;
}

watch_attacking()
{
	self endon( "disconnect" );
	self endon( "death" );

	for (;;)
	{
		self waittill_either( "weapon_fired", "weapon_melee" );

		self.assassin_vars[ "invisibility" ].current = -999;

		waittillframeend;
		self notify( "attacked" );
		self notify( "assassin_assassinate_cd" );
	}
}

watch_assassinate_ability_cooldown()
{
	for (;;)
	{
		cooldown_time = self.assassin_vars[ "assassinate" ].cooldown;

		self.assassin_vars[ "assassinate" ].hud.timer setTimer( cooldown_time );

		event = self waittill_any_timeout( cooldown_time, "attacked" );

		if ( event == "timeout" )
		{
			break;
		}
	}
}

watch_assasin_assassinate_ability()
{
	self endon( "disconnect" );
	self endon( "death" );

	for (;;)
	{
		self.assassin_vars[ "assassinate" ].hud.timer setText( "READY" );
		self.assassin_vars[ "assassinate" ].hud.timer.color = ( 0, 0.8, 0 );
		self.assassin_vars[ "assassinate" ].cooldown = 0;

		self waittill( "assassin_assassinate_cd" );

		self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "trophy_wars_assassin_assassinate_cooldown" );

		self.assassin_vars[ "assassinate" ].hud.timer.color = ( 1, 1, 1 );

		self watch_assassinate_ability_cooldown();
	}
}

watch_weapon_pickup()
{
	self endon( "disconnect" );
	self endon( "death" );
	first = true;
	weapon = undefined;
	for (;;)
	{
		if ( first )
		{
			weapon = self getCurrentWeapon();
			first = false;
		}
		else 
		{
			self waittill( "weapon_change", weapon );
		}
		if ( weapon == "none" )
		{
			continue;
		}
		self setBlockWeaponPickup( weapon, true );
	}
}