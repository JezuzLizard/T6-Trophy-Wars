#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

init_saboteur_class()
{
	set_dvar_if_unset( "saboteur_dash_speed_multiplier", 4 );
	set_dvar_if_unset( "saboteur_dash_speed_cap", 500 );
	set_dvar_if_unset( "saboteur_dash_cooldown_ticks", 160 );
	set_dvar_if_unset( "saboteur_dash_strafe_factor", 0.9 );

	scripts\mp\trophy_wars::register_tw_class( "saboteur", "CLASS_LMG", 13, ::player_init, ::player_reset, ::loadout );
}

player_init()
{
	self.is_saboteur = false;
	self.saboteur_vars = [];
	self.saboteur_vars[ "dash" ] = spawnStruct();
	self.saboteur_vars[ "dash" ].cooldown = 0;
	self.saboteur_vars[ "dash" ].hud = spawnStruct();
	self.saboteur_vars[ "dash" ].hud.timer = self createclienttimer( "objective", 1.5 );
	self.saboteur_vars[ "dash" ].hud.timer.alpha = 0;
	self.saboteur_vars[ "dash" ].hud.timer setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, 10 );
	self.saboteur_vars[ "dash" ].hud.timer.hidewheninmenu = true;
	self.saboteur_vars[ "dash" ].hud.text = self createfontstring( "objective", 1.5 );
	self.saboteur_vars[ "dash" ].hud.text.alpha = 0;
	self.saboteur_vars[ "dash" ].hud.text.label = &"DASH";
	self.saboteur_vars[ "dash" ].hud.text setpoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -30, -10 );
	self.saboteur_vars[ "dash" ].hud.text.hidewheninmenu = true;
}

player_reset()
{
	self.is_saboteur = false;

	self.saboteur_vars[ "dash" ].cooldown = 0;
	self.saboteur_vars[ "dash" ].hud.timer.alpha = 0;
	self.saboteur_vars[ "dash" ].hud.text.alpha = 0;
}

loadout()
{
	self.is_saboteur = true;

	self.saboteur_vars[ "dash" ].hud.timer.alpha = 1;
	self.saboteur_vars[ "dash" ].hud.text.alpha = 1;

	self thread watch_double_tap_jump();
	self thread watch_dash_usage();
	self thread watch_dash_ability_cd();
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
	self endon( "changed_class" );

	self.saboteur_vars[ "dash" ].cooldown = getDvarFloat( "saboteur_dash_cooldown_ticks" );

	self.saboteur_vars[ "dash" ].hud.timer setTimer( self.saboteur_vars[ "dash" ].cooldown / 20 );

	for ( i = self.saboteur_vars[ "dash" ].cooldown; i >= 0; i-- )
	{
		wait 0.05;
		self.saboteur_vars[ "dash" ].cooldown = i;
	}

	self.saboteur_vars[ "dash" ].cooldown = 0;
}

watch_dash_ability_cd()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	for (;;)
	{
		self.saboteur_vars[ "dash" ].hud.timer setText( "READY" );
		self.saboteur_vars[ "dash" ].hud.timer.color = ( 0, 0.8, 0 );
		self.saboteur_vars[ "dash" ].cooldown = 0;

		self waittill( "saboteur_dash_cd" );

		self.saboteur_vars[ "dash" ].hud.timer.color = ( 1, 1, 1 );

		self dash_cooldown();
	}
}

watch_dash_usage()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "changed_class" );

	for (;;)
	{
		self waittill( "dash" );

		if ( self.saboteur_vars[ "dash" ].cooldown > 0 )
		{
			continue;
		}

		if ( level.inprematchperiod )
		{
			continue;
		}

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

		self notify( "saboteur_dash_cd" );
	}
}