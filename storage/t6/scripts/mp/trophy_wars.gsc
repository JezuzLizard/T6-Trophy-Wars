#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

#include maps\mp\_trophy_system;

main()
{
	replaceFunc( maps\mp\bots\_bot_combat::threat_should_ignore, ::threat_should_ignore_override );
	//replaceFunc( maps\mp\_trophy_system::ontrophysystemspawn, ::ontrophysystemspawn_override );
	//replaceFunc( maps\mp\_trophy_system::trophywatchhack, ::trophywatchhack_override );
	//replaceFunc( maps\mp\_trophy_system::trophyactive, ::trophyactive_override );
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

	scripts\mp\trophy_wars_classes\assassin::init_assassin_class();
	scripts\mp\trophy_wars_classes\saboteur::init_saboteur_class();

	level thread on_player_connect();

	level waittill( "prematch_over" );
	wait 1;
	level.callbackplayerdamage_old2 = level.callbackplayerdamage;
	level.callbackplayerdamage = ::trophy_wars_player_damage;
	level.callbackplayerlaststand = ::trophy_wars_player_laststand;
}

register_tw_class( class_name, class_override, class_num, class_player_init, class_player_reset, class_on_give_loadout )
{
	if ( !isDefined( level.tw_classes ) )
	{
		level.tw_classes = [];
		level.tw_class_num_to_class = [];
	}

	c = spawnStruct();

	c.class_name = class_name;
	c.class_override = class_override;
	c.class_num = class_num;
	c.init_func = class_player_init;
	c.reset_func = class_player_reset;
	c.loadout_func = class_on_give_loadout;

	level.tw_classes[ class_name ] = c;
	level.tw_class_num_to_class[ class_num + "" ] = c;
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

		foreach ( classa in level.tw_classes )
		{
			player [[ classa.init_func ]]();
		}
	}
}

on_loadout_given()
{
	for (;;)
	{
		self waittill( "give_map" ); //giveloadout notify
		waittillframeend;
		self thread watch_for_death();
		foreach ( classa in level.tw_classes )
		{
			self [[ classa.reset_func ]]();
		}

		self.tw_class = "none";
		classa = level.tw_class_num_to_class[ self.class_num + "" ];
		if ( isDefined( classa ) )
		{
			self [[ classa.loadout_func ]]();
		}
		//self setPerk( "specialty_pistoldeath" );
	}
}

watch_for_death()
{
	self endon( "disconnect" );
	self endon( "changed_class" );

	self waittill( "death" );

	foreach ( classa in level.tw_classes )
	{
		self [[ classa.reset_func ]]();
	}
}