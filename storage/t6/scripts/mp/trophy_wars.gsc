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

	set_dvar_if_unset( "trophy_system_reveal_delay_ms", 1500 );
	set_dvar_if_unset( "assassin_invis_base_restore_factor", 2.5 );
	set_dvar_if_unset( "assassin_invis_sprint_decay_factor", 2.5 );
	set_dvar_if_unset( "assassin_invis_crouch_restore_factor", 1.25 );
	set_dvar_if_unset( "assassin_invis_airborne_decay_factor", 2.0 );
	set_dvar_if_unset( "assassin_invis_decay_factor", 1.0 );
	set_dvar_if_unset( "assassin_invis_trophy_reveal_radius", 750 );
	set_dvar_if_unset( "assassin_invis_trophy_reveal_radius_max_decay", 10 );
	set_dvar_if_unset( "assassin_invis_player_nearby_reveal_radius", 187.5 );
	set_dvar_if_unset( "assassin_invis_player_nearby_reveal_radius_max_decay", 20 );
	set_dvar_if_unset( "assassin_assassinate_failure_cooldown", 15 );
	set_dvar_if_unset( "assassin_assassinate_success_cooldown", 8 );
	set_dvar_if_unset( "assassin_assassinate_reveal_cooldown", 10 );
	set_dvar_if_unset( "saboteur_dash_speed_multiplier", 4 );
	set_dvar_if_unset( "saboteur_dash_speed_cap", 500 );
	set_dvar_if_unset( "saboteur_dash_cooldown", 8 );
	set_dvar_if_unset( "saboteur_dash_strafe_factor", 0.9 ); 

	level thread on_player_connect();

	level waittill( "prematch_over" );
	wait 1;
	level.callbackplayerdamage_old2 = level.callbackplayerdamage;
	level.callbackplayerdamage = ::trophy_wars_player_damage;
	level.callbackplayerlaststand = ::trophy_wars_player_laststand;
}

trophy_wars_player_laststand( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime, deathanimduration )
{
    //self.health = 1;
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
			    vangles = self getPlayerAngles()[1];
        		pangles = eattacker getPlayerAngles()[1];
			    anglediff = angleclamp180( vangles - pangles );

				if ( eattacker.is_assassin && eattacker.assassin_vars[ "assassinate" ].cooldown == 0 && anglediff > -30 && anglediff < 70 )
				{
					idamage = self.maxhealth;
					eattacker.assassin_vars[ "assassinate" ].success = true;
					self thread watch_killed();
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
				if ( isDefined( eattacker ) && distance( eattacker.origin, self.origin ) > 300 )
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
		self.assassin_vars[ "assassinate" ].revealed_by_enemy = true;
		self notify( "assassin_assassinate_cd" );
		self notify( "revealed" );
	}
	
	self [[ level.callbackplayerdamage_old2 ]]( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, timeoffset, boneindex );
}

watch_killed()
{
	self waittill( "death" );
	self.assassinated_hud.alpha = 1;
	self.assassinated_hud fadeOverTime( 1.5 );
	self.assassinated_hud.alpha = 0;
	self.assassinated_hud.fontscale = 2.5;
	self.assassinated_hud changefontscaleovertime( 1.5 );
	self.assassinated_hud.fontscale = 3.5;
	wait 1.5;
}

on_player_connect()
{
	for (;;)
	{
		level waittill( "connected", player );
		player thread on_loadout_given();
		player thread dash_ability();
		
		player.dash_cooldown = false;

		player.is_assassin = false;
		player.assassinated_hud = player createfontstring( "objective", 2.5 );
		player.assassinated_hud setpoint( "CENTER", "CENTER", 0, 0 );
		player.assassinated_hud.alpha = 0;
		player.assassinated_hud.label = &"ASSASSINATED!";
		player.assassinated_hud.hidewheninmenu = true;
		player.assassinated_hud.color = ( 0.8, 0, 0 );
		player.assassin_vars = [];
		player.assassin_vars[ "assassinate" ] = spawnStruct();
		player.assassin_vars[ "assassinate" ].success = false;
		player.assassin_vars[ "assassinate" ].cooldown = 0;
		player.assassin_vars[ "assassinate" ].revealed_by_enemy = false;
		player.assassin_vars[ "assassinate" ].hud = spawnStruct();
		player.assassin_vars[ "assassinate" ].hud.timer = player createclienttimer( "objective", 1.5 );
		player.assassin_vars[ "assassinate" ].hud.timer.alpha = 0;
		player.assassin_vars[ "assassinate" ].hud.timer setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, 10 );
		player.assassin_vars[ "assassinate" ].hud.timer.hidewheninmenu = true;
		player.assassin_vars[ "assassinate" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "assassinate" ].hud.text.alpha = 0;
		player.assassin_vars[ "assassinate" ].hud.text.label = &"ASSASSINATE";
		player.assassin_vars[ "assassinate" ].hud.text setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, -10 );
		player.assassin_vars[ "assassinate" ].hud.text.hidewheninmenu = true;
		player.assassin_vars[ "invisibility" ] = spawnStruct();
		player.assassin_vars[ "invisibility" ].invisible = false;
		player.assassin_vars[ "invisibility" ].hud = spawnStruct();
		player.assassin_vars[ "invisibility" ].hud.bar = player createbar( ( 1, 1, 1 ), 55, 8, 0.8 );
		player.assassin_vars[ "invisibility" ].hud.bar seticonshader( "progress_bar_bg" );
		player.assassin_vars[ "invisibility" ].hud.bar hideelem();
		player.assassin_vars[ "invisibility" ].hud.bar setpoint( "BOTTOM", "BOTTOM", 0, 20 );
		player.assassin_vars[ "invisibility" ].hud.bar.hidewheninmenu = true;
		player.assassin_vars[ "invisibility" ].hud.text = player createfontstring( "objective", 1.5 );
		player.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
		player.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
		player.assassin_vars[ "invisibility" ].hud.text setpoint( "BOTTOM", "BOTTOM", 0, 10 );
		player.assassin_vars[ "invisibility" ].hud.text.hidewheninmenu = true;
		player.assassin_vars[ "invisibility" ].current = 50;
		player.saboteur_vars = [];
	}
}

on_loadout_given()
{
	for (;;)
	{
		self waittill( "give_map" ); //giveloadout notify
		waittillframeend;
		self thread watch_for_death();
		self reset_assassin_vars();
		//self setPerk( "specialty_pistoldeath" );
		if ( self.class_num == level.classtoclassnum[ "CLASS_CQB" ] )
		{
			self.is_assassin = true;
			self.assassin_vars[ "invisibility" ].hud.bar showelem();
			self.assassin_vars[ "invisibility" ].hud.text.alpha = 1;
			self.assassin_vars[ "assassinate" ].hud.timer.alpha = 1;
			self.assassin_vars[ "assassinate" ].hud.text.alpha = 1;
			self set_player_visibility( true );
			self thread calculate_invisibility_value();
			self thread watch_attacking();
			self thread watch_assasin_assassinate_ability();
			self thread watch_weapon_pickup();
			self thread watch_inventory();
		}
		else if ( self.class_num == level.classtoclassnum[ "CLASS_LMG" ] )
		{
			self.is_saboteur = true;
			self.saboteur_vars[ "dash" ] = spawnStruct();
			self thread watch_double_tap_jump();
			self thread dash_ability();
		}
	}
}

reset_assassin_vars()
{
	self.is_assassin = false;

	self.assassin_vars[ "invisibility" ].hud.bar hideelem();
	self.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
	self.assassin_vars[ "invisibility" ].invisible = false;
	self.assassin_vars[ "invisibility" ].current = 0;
	self.assassin_vars[ "assassinate" ].success = false;
	self.assassin_vars[ "assassinate" ].cooldown = 0;
	self.assassin_vars[ "assassinate" ].revealed_by_enemy = false;
	self.assassin_vars[ "assassinate" ].hud.timer.alpha = 0;
	self.assassin_vars[ "assassinate" ].hud.text.alpha = 0;

	self set_player_visibility( false );
}

watch_for_death()
{
	self endon( "disconnect" );
	self endon( "changed_class" );

	self waittill( "death" );

	self.dash_cooldown = false;

	self reset_assassin_vars();
}

set_player_visibility( invisible )
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
	return ( ( -1 / pow( getDvarFloat( "assassin_invis_trophy_reveal_radius" ) / 10, 2 ) ) * pow( distance, 2 ) ) + getDvarFloat( "assassin_invis_trophy_reveal_radius_max_decay" ); 
}

calculate_player_reveal_decay( distance )
{
	return ( ( -1 / pow( getDvarFloat( "assassin_invis_player_nearby_reveal_radius" ) / 10, 2 ) ) * pow( distance, 2 ) ) + getDvarFloat( "assassin_invis_player_nearby_reveal_radius_max_decay" );
}

calculate_invisibility_value()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	const max_amount = 100;
	const min_amount = 0;
	for (;;)
	{
		wait 0.05;

		drain_percent_per_tick = 0;

		drain_percent_per_tick += getDvarFloat( "assassin_invis_decay_factor" );
		speed = length( self getVelocity() );

		growth_factor = getDvarFloat( "assassin_invis_base_restore_factor" );

		if ( !self isOnGround() )
		{
			growth_factor -= getDvarFloat( "assassin_invis_airborne_decay_factor" );
		}
		if ( self isSprinting() || self isPlayerSprinting() )
		{
			growth_factor -= getDvarFloat( "assassin_invis_sprint_decay_factor" );
		}
		else if ( self getStance() == "crouch" )
		{
			growth_factor += getDvarFloat( "assassin_invis_crouch_restore_factor" );
		}

		growth_percent_per_tick = ( speed / getDvarInt( "g_speed" ) ) * growth_factor;

		nearby_player_modifier = 0;

		foreach ( player in level.players )
		{
			if ( player.team != self.team )
			{
				nearby_player_factor = calculate_player_reveal_decay( distance( self.origin, player.origin ) );
				if ( nearby_player_factor > 0 )
				{
					nearby_player_modifier += nearby_player_factor;
				}
			}
		}

		if ( self revealing_attack_action() )
		{
			drain_percent_per_tick += 999;
		}

		trophy_modifier = calculate_trophy_reveal_decay( self distance_from_closest_trophy() );

		if ( trophy_modifier > 0 )
		{
			drain_percent_per_tick += trophy_modifier;
		}
		else
		{
			self.assassin_vars[ "invisibility" ].current += growth_percent_per_tick;
		}

		self.assassin_vars[ "invisibility" ].current -= drain_percent_per_tick;

		if ( self.assassin_vars[ "invisibility" ].current <= min_amount )
		{
			if ( trophy_modifier > 0 || nearby_player_modifier > 0 )
			{
				self.assassin_vars[ "assassinate" ].revealed_by_enemy = true;
				self notify( "assassin_assassinate_cd" );
				self notify( "revealed" );
			}
			self.assassin_vars[ "invisibility" ].current = min_amount;
			self set_player_visibility( false );
		}
		else if ( self.assassin_vars[ "invisibility" ].current >= max_amount)
		{
			self.assassin_vars[ "invisibility" ].current = max_amount;
			self set_player_visibility( true );
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
	self endon( "changed_class" );

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
		if ( self.assassin_vars[ "assassinate" ].success )
		{
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_success_cooldown" );
			self.assassin_vars[ "assassinate" ].success = false;
		}
		else if ( !self.assassin_vars[ "assassinate" ].revealed_by_enemy )
		{
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_failure_cooldown" );
		}
		else
		{
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_reveal_cooldown" );
			self.assassin_vars[ "assassinate" ].revealed_by_enemy = false;
		}

		cooldown_time = self.assassin_vars[ "assassinate" ].cooldown ;

		self.assassin_vars[ "assassinate" ].hud.timer setTimer( cooldown_time );

		event = self waittill_any_timeout( cooldown_time, "attacked", "revealed" );

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
	self endon( "changed_class" );

	for (;;)
	{
		self.assassin_vars[ "assassinate" ].hud.timer setText( "READY" );
		self.assassin_vars[ "assassinate" ].hud.timer.color = ( 0, 0.8, 0 );
		self.assassin_vars[ "assassinate" ].cooldown = 0;

		self waittill( "assassin_assassinate_cd" );

		self.assassin_vars[ "assassinate" ].hud.timer.color = ( 1, 1, 1 );

		self watch_assassinate_ability_cooldown();
	}
}

watch_weapon_pickup()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

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

watch_inventory()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	for (;;)
	{
		self waittill( "weapon_change", weapon );
		if ( maps\mp\killstreaks\_killstreaks::iskillstreakweapon( weapon ) )
		{
			self.assassin_vars[ "invisibility" ].current = -999;
			continue;
		}
		if ( isDefined( self.primaryloadoutweapon ) && weapon == self.primaryloadoutweapon 
			|| isDefined( self.secondaryloadoutweapon ) && weapon == self.secondaryloadoutweapon
			|| isDefined( self.grenadetypeprimary ) && weapon == self.grenadetypeprimary 
			|| isDefined( self.grenadetypesecondary ) && weapon == self.grenadetypesecondary )
		{
			continue;
			
		}

		self maps\mp\gametypes\_weapons::dropweapontoground( weapon );
	}
}

watch_double_tap_jump()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	self notifyOnPlayerCommand( "jump_pressed", "+gostand" );

	for (;;)
	{
		self waittill( "jump_pressed" );

		event = self waittill_any_timeout( 0.25, "jump_pressed" );

		if ( event == "timeout" )
		{
			continue;
		}

		self notify( "dash" );
	}
}

dash_cooldown()
{
	self endon( "disconnect" );
	self endon( "death" );

	self.dash_cooldown = true;

	cooldown_time = getDvarFloat( "saboteur_dash_cooldown" );

	for ( i = cooldown_time; i > 0; i++ )
	{
		wait 0.05;
	}

	self.dash_cooldown = false;
}

dash_ability()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	for (;;)
	{
		self waittill( "dash" );

		if ( self.dash_cooldown )
		{
			continue;
		}

		self thread dash_cooldown();

		v = self getVelocity();
		v = ( v[ 0 ], v[ 1 ], 0 );

		speed = length( v );

		dash_modifier = ( speed / getDvarInt( "g_speed" ) );

		v = v * dash_modifier * getDvarFloat( "saboteur_dash_speed_multiplier" );

		speed_cap = getDvarFloat( "saboteur_dash_speed_cap" );

		if ( length( v ) > speed_cap )
		{
			v = VectorNormalize( v );
			v *= speed_cap;
		}

		v = ( v[ 0 ], v[ 1 ] * getDvarFloat( "saboteur_dash_strafe_factor" ), 0 ); 

		self setVelocity( self getVelocity() + v );
	}
}