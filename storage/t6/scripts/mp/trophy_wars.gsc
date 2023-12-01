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
	level thread on_player_connect();
}

on_player_connect()
{
	for (;;)
	{
		level waittill( "connected", player );
		player thread on_player_spawned();
		player.invisibility_bar = player createbar( ( 1, 1, 1 ), 55, 8, 0.8 );
		player.invisibility_bar seticonshader( "progress_bar_bg" );
		player.invisibility_bar setpoint( "BOTTOM", "BOTTOM", 0, 20 );
		player.invisibility_bar.alpha = 0;
		player.invisibility_text = player createfontstring( "objective", 1.5 );
		player.invisibility_text.alpha = 0;
		player.invisibility_text.label = &"INVISIBLE";
		player.invisibility_text setpoint( "BOTTOM", "BOTTOM", 0, 10 );
		player.revealed_attack = false;
		player.revealed_trophy = false;
	}
}

on_player_spawned()
{
	for (;;)
	{
		self waittill( "spawned_player" );
		if ( self hasPerk( "specialty_gpsjammer" ) )
		{
			self.invisibility_bar showelem();
			self.invisibility_text.alpha = 1;
			self.invisibility_bar updateBar( 1 );
			self setPerk( "specialty_noname" );
			self change_player_visibility( true );
			self thread watch_invisibility();
			self thread watch_for_death();
			self thread watch_revealing();
		}
	}
}

watch_for_death()
{
	self endon( "disconnect" );
	self waittill( "death" );

	self.invisibility_bar hideelem();
	self.invisibility_text.alpha = 0;

	self change_player_visibility( false );
}

change_player_visibility( invisible )
{
	players = getPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( players[ i ].team != self.team )
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
		self.invisibility_text.label = &"INVISIBLE";
	}
	else
	{
		self.ignoreme = false;
		self.invisibility_text.label = &"NOT INVISIBLE";
	}
}

fade_out_invisible_player( player )
{
	for ( i = 0; i >= 0; i-- )
	{
		wait 0.05;
		player.invisibility_bar updateBar( i / 15 );
	}
}

fade_in_invisible_player( player, time )
{
	self endon( "death" );
	self endon( "revealed" );
	for ( i = 0; i < time; i++ )
	{
		wait 0.05;
		player.invisibility_bar updateBar( i / time );
	}
}

try_going_invisible_again()
{
	for ( ;; )
	{
		if ( self.revealed_attack )
		{
			time = getDvarIntDefault( "trophy_wars_invisibilty_attack_reveal_fade_in_ticks", 80 );
		}
		else if ( self.revealed_trophy )
		{
			time = getDvarIntDefault( "trophy_wars_invisibilty_trophy_reveal_fade_in_ticks", 40 );
		}
		else
		{
			time = 1;
		}

		self.revealed_attack = false;
		self.revealed_trophy = false;
		
		self thread fade_in_invisible_player( self, time );
		event = self waittill_any_timeout( time / 20, "revealed" );

		if ( event == "timeout" )
		{
			break;
		}

		self.invisibility_bar updateBar( 0.01 );
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

		if ( self.revealed_attack || self.revealed_trophy )
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
			if ( isDefined( trophies[ j ] ) && distancesquared( trophies[ j ].origin, self.origin ) < getDvarIntDefault( "trophy_system_reveal_radius_sq", 150000 ) )
			{
				return true;;
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
			self.revealed_attack = true;

			self notify( "revealed" );
		}
		else if ( self revealed_by_trophy_system() )
		{
			self.revealed_trophy = true;

			self notify( "revealed" );
		}
	}
}