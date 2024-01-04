#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

init_assassin_class()
{
	set_dvar_if_unset( "assassin_invis_base_restore_factor", 2.5 );
	set_dvar_if_unset( "assassin_invis_sprint_decay_factor", 2.5 );
	set_dvar_if_unset( "assassin_invis_crouch_restore_factor", 1.25 );
	set_dvar_if_unset( "assassin_invis_airborne_decay_factor", 2.0 );
	set_dvar_if_unset( "assassin_invis_decay_factor", 1.0 );
	set_dvar_if_unset( "assassin_invis_trophy_reveal_radius", 750 );
	set_dvar_if_unset( "assassin_invis_trophy_reveal_radius_max_decay", 10 );
	set_dvar_if_unset( "assassin_invis_trophy_nearby_reveal_delay_ms", 1500 );
	set_dvar_if_unset( "assassin_invis_player_nearby_reveal_radius", 187.5 );
	set_dvar_if_unset( "assassin_invis_player_nearby_reveal_radius_max_decay", 20 );
	set_dvar_if_unset( "assassin_assassinate_failure_cooldown_ticks", 300 );
	set_dvar_if_unset( "assassin_assassinate_success_cooldown_ticks", 160 );
	set_dvar_if_unset( "assassin_assassinate_reveal_cooldown_ticks", 200 );

	scripts\mp\trophy_wars::register_tw_class( "assassin", "CLASS_CQB", 11, ::player_init, ::player_reset, ::loadout );

	scripts\mp\trophy_wars::register_bot_callbacks( ::bot_lose_invisible_players, undefined, undefined );
}

player_init()
{
	self.is_assassin = false;
	self.assassinated_hud = self createfontstring( "objective", 2.5 );
	self.assassinated_hud setpoint( "CENTER", "CENTER", 0, 0 );
	self.assassinated_hud.alpha = 0;
	self.assassinated_hud.label = &"ASSASSINATED!";
	self.assassinated_hud.hidewheninmenu = true;
	self.assassinated_hud.color = ( 0.8, 0, 0 );
	self.assassin_vars = [];
	self.assassin_vars[ "assassinate" ] = spawnStruct();
	self.assassin_vars[ "assassinate" ].success = false;
	self.assassin_vars[ "assassinate" ].cooldown = 0;
	self.assassin_vars[ "assassinate" ].revealed_by_enemy = false;
	self.assassin_vars[ "assassinate" ].hud = spawnStruct();
	self.assassin_vars[ "assassinate" ].hud.timer = self createclienttimer( "objective", 1.5 );
	self.assassin_vars[ "assassinate" ].hud.timer.alpha = 0;
	self.assassin_vars[ "assassinate" ].hud.timer setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, 10 );
	self.assassin_vars[ "assassinate" ].hud.timer.hidewheninmenu = true;
	self.assassin_vars[ "assassinate" ].hud.text = self createfontstring( "objective", 1.5 );
	self.assassin_vars[ "assassinate" ].hud.text.alpha = 0;
	self.assassin_vars[ "assassinate" ].hud.text.label = &"ASSASSINATE";
	self.assassin_vars[ "assassinate" ].hud.text setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, -10 );
	self.assassin_vars[ "assassinate" ].hud.text.hidewheninmenu = true;
	self.assassin_vars[ "invisibility" ] = spawnStruct();
	self.assassin_vars[ "invisibility" ].invisible = false;
	self.assassin_vars[ "invisibility" ].hud = spawnStruct();
	self.assassin_vars[ "invisibility" ].hud.bar = self createbar( ( 1, 1, 1 ), 55, 8, 0.8 );
	self.assassin_vars[ "invisibility" ].hud.bar seticonshader( "progress_bar_bg" );
	self.assassin_vars[ "invisibility" ].hud.bar hideelem();
	self.assassin_vars[ "invisibility" ].hud.bar setpoint( "BOTTOM", "BOTTOM", 0, 20 );
	self.assassin_vars[ "invisibility" ].hud.bar.hidewheninmenu = true;
	self.assassin_vars[ "invisibility" ].hud.text = self createfontstring( "objective", 1.5 );
	self.assassin_vars[ "invisibility" ].hud.text.alpha = 0;
	self.assassin_vars[ "invisibility" ].hud.text.label = &"INVISIBLE";
	self.assassin_vars[ "invisibility" ].hud.text setpoint( "BOTTOM", "BOTTOM", 0, 10 );
	self.assassin_vars[ "invisibility" ].hud.text.hidewheninmenu = true;
	self.assassin_vars[ "invisibility" ].current = 50;
}

player_reset()
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

loadout()
{
	self.tw_class = "assassin";
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

calculate_special_reveal_decay( distance, base, y_intercept )
{
	return ( ( -1 / pow( base / 10, 2 ) ) * pow( distance, 2 ) ) + y_intercept;
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
		if ( !self isTestClient() && ( self isSprinting() || self isPlayerSprinting() ) )
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
				nearby_player_factor = calculate_special_reveal_decay( distance( self.origin, player.origin ), getDvarFloat( "assassin_invis_player_nearby_reveal_radius" ), getDvarFloat( "assassin_invis_player_nearby_reveal_radius_max_decay" ) );
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

		trophy_modifier = calculate_special_reveal_decay( self distance_from_closest_trophy(), getDvarFloat( "assassin_invis_trophy_reveal_radius" ), getDvarFloat( "assassin_invis_trophy_reveal_radius_max_decay" ) );

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
			if ( getTime() < trophies[ j ].spawn_time + getDvarInt( "assassin_invis_trophy_nearby_reveal_delay_ms" ) )
			{
				continue;
			}
			if ( !bullettracepassed( trophies[ j ].origin, self.origin + vectorscale( ( 0, 0, 1 ), 29.0 ), 0, trophies[ j ] ) ) 
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
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_success_cooldown_ticks" );
			self.assassin_vars[ "assassinate" ].success = false;
		}
		else if ( !self.assassin_vars[ "assassinate" ].revealed_by_enemy )
		{
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_failure_cooldown_ticks" );
		}
		else
		{
			self.assassin_vars[ "assassinate" ].cooldown = getDvarInt( "assassin_assassinate_reveal_cooldown_ticks" );
			self.assassin_vars[ "assassinate" ].revealed_by_enemy = false;
		}

		cooldown_time = self.assassin_vars[ "assassinate" ].cooldown ;

		self.assassin_vars[ "assassinate" ].hud.timer setTimer( cooldown_time / 20 );

		event = self waittill_any_timeout( cooldown_time / 20, "attacked", "revealed" );

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

bot_lose_invisible_players()
{
	self endon( "disconnect" );

	while ( !isDefined( self.bot ) )
	{
		wait 0.05;
	}

	for (;;)
	{
		wait 0.05;
		if ( !isDefined( self.bot.threat.entity ) )
		{
			continue;
		}
		if ( !isPlayer( self.bot.threat.entity ) )
		{
			continue;
		}

		player = self.bot.threat.entity;

		if ( !player.is_assassin )
		{
			continue;
		}

		if ( !player.assassin_vars[ "invisibility" ].invisible )
		{
			continue;
		}

		self maps\mp\bots\_bot_combat::bot_clear_enemy();
	}
}