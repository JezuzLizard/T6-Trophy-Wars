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

	if ( isDefined( entity ) && isDefined( entity.ignoreme ) && entity.ignoreme )
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

	set_dvar_if_unset( "trophy_system_invis_reveal_radius_sq", 150000 );
	set_dvar_if_unset( "trophy_wars_assassin_invis_attack_reveal_fade_in_ticks", 80 );
	set_dvar_if_unset( "trophy_wars_assassin_invis_trophy_reveal_fade_in_ticks", 40 );
	set_dvar_if_unset( "trophy_wars_assassin_insta_kill_cooldown", 15 );
	set_dvar_if_unset( "trophy_system_reveal_delay_ms", 1500 );

	level thread on_player_connect();

	level waittill( "prematch_over" );
	wait 1;
	level.callbackplayerdamage_old2 = level.callbackplayerdamage;
	level.callbackplayerdamage = ::trophy_wars_player_damage;
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
			case "knife_mp":
			case "riotshield_mp":
			case "knife_ballistic_mp":
				if ( isDefined( eattacker ) && distanceSquared( eattacker.origin, self.origin ) > 10000 )
				{
					idamage = self.maxhealth;
				}
				else if ( eattacker.is_assassin && eattacker.assassin_vars[ "insta_kill" ].cooldown == 0 )
				{
					idamage = self.maxhealth;
					eattacker notify( "assassin_insta_kill" );
				}
				else
				{
					idamage = int( self.maxhealth / 2 ) + 1;
				}
				break;
			case "concussion_grenade_mp":
			case "proximity_grenade_aoe_mp":
			case "proximity_grenade_mp":
				idamage = int( self.maxhealth / 2 ) + 1;
				break;
			case "claymore_mp":
			case "satchel_charge_mp":
			case "sticky_grenade_mp":
				idamage = self.maxhealth;
				break;
		}
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
		player.assassin_vars[ "insta_kill" ] = spawnStruct();
		player.assassin_vars[ "insta_kill" ].cooldown = 0;
		player.assassin_vars[ "insta_kill" ].hud = spawnStruct();
		player.assassin_vars[ "insta_kill" ].hud.timer = player createclienttimer( "objective", 1.5 );
		player.assassin_vars[ "insta_kill" ].hud.timer.alpha = 0;
		player.assassin_vars[ "insta_kill" ].hud.timer setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, 10 );
		player.assassin_vars[ "insta_kill" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "insta_kill" ].hud.text.alpha = 0;
		player.assassin_vars[ "insta_kill" ].hud.text.label = &"INSTA KILL";
		player.assassin_vars[ "insta_kill" ].hud.text setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, -10 );
		player.assassin_vars[ "invisibility" ] = spawnStruct();
		player.assassin_vars[ "invisibility" ].hud = spawnStruct();
		player.assassin_vars[ "invisibility" ].hud.bar = player createbar( ( 1, 1, 1 ), 55, 8, 0.8 );
		player.assassin_vars[ "invisibility" ].hud.bar seticonshader( "progress_bar_bg" );
		player.assassin_vars[ "invisibility" ].hud.bar.alpha = 0;
		player.assassin_vars[ "invisibility" ].hud.bar setpoint( "BOTTOM", "BOTTOM", 0, 20 );
		player.assassin_vars[ "invisibility" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
		player.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
		player.assassin_vars[ "invisibility" ].hud.text setpoint( "BOTTOM", "BOTTOM", 0, 10 );
		player.assassin_vars[ "invisibility" ].revealed_attack = false;
		player.assassin_vars[ "invisibility" ].revealed_trophy = false;
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
			self.assassin_vars[ "invisibility" ].hud.bar updateBar( 1 );
			self.assassin_vars[ "insta_kill" ].hud.timer.alpha = 1;
			self.assassin_vars[ "insta_kill" ].hud.text.alpha = 1;
			self setPerk( "specialty_noname" );
			self change_player_visibility( true );
			self thread watch_invisibility();
			self thread watch_for_death();
			self thread watch_revealing();
			self thread watch_assasin_insta_kill_ability();
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
	self.assassin_vars[ "invisibility" ].revealed_attack = false;
	self.assassin_vars[ "invisibility" ].revealed_trophy = false;
	self.assassin_vars[ "insta_kill" ].cooldown = 0;
	self.assassin_vars[ "insta_kill" ].hud.timer.alpha = 0;
	self.assassin_vars[ "insta_kill" ].hud.text.alpha = 0;

	self change_player_visibility( false );
}

change_player_visibility( invisible )
{
	players = getPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isDefined( players[ i ] ) && isDefined( players[ i ].team ) && players[ i ].team != self.team 
			&& !players[ i ].is_assassin )
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
		self.ignoreme = true;
		self.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
	}
	else
	{
		self.ignoreme = false;
		self.assassin_vars[ "invisibility" ].hud.text.label = &"NOT INVISIBLE";
	}
}

fade_out_invisible_player( player )
{
	for ( i = 0; i > 0; i-- )
	{
		wait 0.05;
		player.assassin_vars[ "invisibility" ].hud.bar updateBar( i / 15 );
	}
}

fade_in_invisible_player( player, time )
{
	self endon( "death" );
	self endon( "revealed" );
	for ( i = 0; i < time; i++ )
	{
		wait 0.05;
		player.assassin_vars[ "invisibility" ].hud.bar updateBar( i / time );
	}
}

try_going_invisible_again()
{
	for ( ;; )
	{
		if ( self.assassin_vars[ "invisibility" ].revealed_attack )
		{
			time = getDvarInt( "trophy_wars_assassin_invis_attack_reveal_fade_in_ticks" );
		}
		else if ( self.assassin_vars[ "invisibility" ].revealed_trophy )
		{
			time = getDvarInt( "trophy_wars_assassin_invis_trophy_reveal_fade_in_ticks" );
		}
		else
		{
			time = 1;
		}

		self.assassin_vars[ "invisibility" ].revealed_attack = false;
		self.assassin_vars[ "invisibility" ].revealed_trophy = false;
		
		self thread fade_in_invisible_player( self, time );
		event = self waittill_any_timeout( time / 20, "revealed" );

		if ( event == "timeout" )
		{
			break;
		}

		self.assassin_vars[ "invisibility" ].hud.bar updateBar( 0.01 );
	}
}

update_invisibilty( time )
{
	self change_player_visibility( false );

	self try_going_invisible_again();

	self change_player_visibility( true );
}

watch_invisibility()
{
	self endon( "disconnect" );
	self endon( "death" );

	for (;;)
	{
		wait 0.05;

		if ( self.assassin_vars[ "invisibility" ].revealed_attack || self.assassin_vars[ "invisibility" ].revealed_trophy )
		{
			self update_invisibilty();
		}
	}
}

revealing_attack_action()
{
	should_reveal = self secondaryoffhandbuttonpressed() && isDefined( self.grenadetypesecondary ) && self getWeaponAmmoStock( self.grenadetypesecondary ) > 0 
			|| self fragbuttonpressed() && isDefined( self.grenadetypeprimary ) && self getWeaponAmmoStock( self.grenadetypeprimary ) > 0 
			|| self meleebuttonpressed() || self attackbuttonpressed();
	
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

revealed_by_trophy_system()
{
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
			if ( isDefined( trophies[ j ] ) && distancesquared( trophies[ j ].origin, self.origin ) < getDvarInt( "trophy_system_invis_reveal_radius_sq" )
				&& trophies[ j ].spawn_time < (getTime() + getDvarInt( "trophy_system_reveal_delay_ms" )) )
			{
				return true;
			}
		}
	}

	return false;
}

watch_revealing()
{
	self endon( "disconnect" );
	self endon( "death" );
	for (;;)
	{
		wait 0.05;

		if ( self revealing_attack_action() )
		{
			self.assassin_vars[ "invisibility" ].revealed_attack = true;

			self notify( "revealed" );
		}
		else if ( self revealed_by_trophy_system() )
		{
			self.assassin_vars[ "invisibility" ].revealed_trophy = true;

			self notify( "revealed" );
		}
	}
}

watch_assasin_insta_kill_ability()
{
	self endon( "disconnect" );
	self endon( "death" );

	for (;;)
	{
		self.assassin_vars[ "insta_kill" ].hud.timer setText( "READY" );
		self.assassin_vars[ "insta_kill" ].cooldown = 0;

		self waittill( "assassin_insta_kill" );

		self.assassin_vars[ "insta_kill" ].cooldown = getDvarInt( "trophy_wars_assassin_insta_kill_cooldown" );

		cooldown_time = self.assassin_vars[ "insta_kill" ].cooldown;

		self.assassin_vars[ "insta_kill" ].hud.timer setTimer( cooldown_time );

		for ( i = cooldown_time; i > 0; i-- )
		{
			wait 1;
			self.assassin_vars[ "insta_kill" ].cooldown--;
		}
	}
}