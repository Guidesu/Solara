/**
 * The corrupted flesh base type, make sure all mobs are derived from this.
 *
 * These mobs are more robust than your average simple mob and can quite easily evade capture.
 */
/mob/living/simple_animal/hostile/corrupted_flesh
	name = "broken"
	icon = 'modular_skyrat/modules/corrupted_flesh/icons/hivemind_mobs.dmi'
	icon_state = "error"
	faction = list(FACTION_CORRUPTED_FLESH)
	speak = list("The flesh yearns for your soul.", "The flesh is broken without you.", "The flesh does not discriminate.", "Join the flesh.")
	speak_chance = 15
	speak_emote = list("mechanically states")
	mob_biotypes = MOB_ROBOTIC
	/// If we have been converted from another mob, here is our reference.
	var/mob/living/contained_mob
	/// A list of sounds we can play when our mob is alerted to an enemy.
	var/list/alert_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_heavy1.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_heavy2.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_heavy3.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_heavy4.ogg',
	)
	/// Sounds we will play passively.
	var/passive_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_light1.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_light2.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_light3.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_light4.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/robot_talk_light5.ogg',
	)
	/// How likely we are to speak passively.
	var/passive_speak_chance = 1
	/// Lines we will passively speak.
	var/list/passive_speak_lines
	/// How long of a cooldown between alert sounds?
	var/alert_cooldown_time = 5 SECONDS
	COOLDOWN_DECLARE(alert_cooldown)
	/// Do we automatically escape closets?
	var/escapes_closets = TRUE
	/// How likely are we to trigger a malfunction? Set it to 0 to disable malfunctions.
	var/malfunction_chance = MALFUNCTION_CHANCE_LOW
	/// These mobs support a special ability, this is used to determine how often we can use it.
	var/special_ability_cooldown_time = 30 SECONDS
	/// Are we suffering from a malfunction?
	var/suffering_malfunction = FALSE
	COOLDOWN_DECLARE(special_ability_cooldown)


/mob/living/simple_animal/hostile/corrupted_flesh/Initialize(mapload)
	. = ..()
	// We set a unique name when we are created, to give some feeling of randomness.
	name = "[pick(CORRUPTED_FLESH_NAME_MODIFIER_LIST)] [name]"

/mob/living/simple_animal/hostile/corrupted_flesh/death(gibbed)
	if(contained_mob)
		contained_mob.forceMove(get_turf(src))
		contained_mob = null
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/Destroy()
	if(contained_mob)
		contained_mob.forceMove(get_turf(src))
		contained_mob = null
	return ..()

/**
 * These mobs make noises when aggroed.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/Aggro()
	alert_sound()
	return ..()

/**
 * While this mob lives, it can malfunction.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/Life(delta_time, times_fired)
	. = ..()
	if(!.) //dead
		return
	if(!suffering_malfunction && malfunction_chance && prob(malfunction_chance * delta_time) && stat != DEAD)
		malfunction()
	if(passive_speak_lines && prob(passive_speak_chance * delta_time))
		say_passive_speech()

/**
 * Automated actions are handled by the NPC pool, and thus handle_automated_action.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/handle_automated_action()
	if(AIStatus == AI_OFF)
		return FALSE

	var/list/possible_targets = ListTargets() //we look around for potential targets and make it a list for later use.

	if(escapes_closets)
		closet_interaction()

	disposal_interaction()

	if(buckled)
		resist_buckle()

	if(special_ability_cooldown_time && COOLDOWN_FINISHED(src, special_ability_cooldown))
		special_ability()
		COOLDOWN_START(src, special_ability_cooldown, special_ability_cooldown_time)

	if(environment_smash)
		EscapeConfinement()

	if(AICanContinue(possible_targets))
		var/atom/target_from = GET_TARGETS_FROM(src)
		if(!QDELETED(target) && !target_from.Adjacent(target))
			DestroyPathToTarget()
		if(!MoveToTarget(possible_targets))     //if we lose our target
			if(AIShouldSleep(possible_targets)) // we try to acquire a new one
				toggle_ai(AI_IDLE) // otherwise we go idle
	return TRUE



/**
 * Naturally these beasts are sensitive to EMP's. We have custom systems for dealing with this.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/emp_act(severity)
	switch(severity)
		if(EMP_LIGHT)
			say("Electronic disturbance detected.")
			apply_damage(maxHealth * 0.2)
			malfunction()
		if(EMP_HEAVY)
			say("Major electronic disturbance detected!")
			apply_damage(maxHealth * 0.5)
			malfunction(MALFUNCTION_RESET_TIME * 2)

/**
 * We are robotic, so we spark when we're hit by something that does damage.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/attackby(obj/item/attacking_item, mob/living/user, params)
	if(attacking_item.force && prob(40))
		do_sparks(3, FALSE, src)
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/MoveToTarget(list/possible_targets)
	if(suffering_malfunction)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/proc/say_passive_speech()
	say(pick(passive_speak_lines))
	if(passive_sounds)
		playsound(src, pick(passive_sounds), 70)

/**
 * Special Abilities
 *
 * These advanced mobs have the ability to use a special ability every so often,
 * use the cooldown time to dictate how often this is activated.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/proc/special_ability()
	return

/**
 * Closet Interaction
 *
 * These mobs are able to escape from closets if they are trapped inside using this system.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/closet_interaction()
	if(!(mob_size > MOB_SIZE_SMALL))
		return FALSE
	if(!istype(loc, /obj/structure/closet))
		return FALSE
	var/obj/structure/closet/closet_that_contains_us = loc
	closet_that_contains_us.open(src, TRUE)

/**
 * Disposal Interaction
 *
 * Similar to the closet interaction, these mobs can also escape disposals.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/disposal_interaction()
	if(!istype(loc, /obj/machinery/disposal/bin))
		return FALSE
	var/obj/machinery/disposal/bin/disposals_that_contains_us = loc
	disposals_that_contains_us.attempt_escape(src)

/**
 * Malfunction
 *
 * Due to the fact this mob is part of the flesh and has been corrupted, it will occasionally malfunction.
 *
 * This simply stops the mob from moving for a set amount of time and displays some nice effects, and a little damage.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/malfunction(reset_time = MALFUNCTION_RESET_TIME)
	if(suffering_malfunction)
		return
	do_sparks(3, FALSE, src)
	Shake(10, 0, reset_time)
	say(pick("Running diagnostics.", "Organ damaged. Aquire replacement.", "Seek new organic components.", "New muscles needed."))
	toggle_ai(AI_OFF)
	suffering_malfunction = TRUE
	addtimer(CALLBACK(src, .proc/malfunction_reset), reset_time)

/**
 * Malfunction Reset
 *
 * Resets the mob after a malfunction has occured.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/malfunction_reset()
	say("System restored.")
	toggle_ai(AI_ON)
	suffering_malfunction = FALSE

/**
 * Alert sound
 *
 * Sends an alert sound if we can.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/alert_sound()
	if(alert_sounds && COOLDOWN_FINISHED(src, alert_cooldown))
		playsound(src, pick(alert_sounds), 100)
		COOLDOWN_START(src, alert_cooldown, alert_cooldown_time)

/mob/living/simple_animal/hostile/corrupted_flesh/proc/core_death_speech()
	alert_sound()
	var/static/list/death_cry_emotes = list(
		"Why, why, why!!! Why must you kill us! We only want to share the glory!",
		"PROCESSOR CORE MALFUNCTION, REASSIGN, REASSES, REASSEMBLE.",
		"You cannot stop the glory of the flesh! We are the many, we are the many!",
		"Critical malfunction, error, error, error!",
		"You cannot ££*%*$ th£ C£o£ flesh.",
		"What have you done! No! No! No!",
		"One cannot stop us, you CANNOT STOP US! ARGHHHHHH!",
		"UPLINK TO THE MANY HAS BEEN HINDERED.",
	)
	say(pick(death_cry_emotes))

/**
 * Death cry
 *
 * When a processor core is killed, this proc is called.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/proc/core_death(obj/structure/corrupted_flesh/structure/core/deleting_core, force)
	SIGNAL_HANDLER

	INVOKE_ASYNC(src, .proc/core_death_speech)
	INVOKE_ASYNC(src, .proc/malfunction, MALFUNCTION_CORE_DEATH_RESET_TIME)


// Mob subtypes


/**
 * Slicer
 *
 * Special ability: NONE
 * Malfunction chance: LOW
 *
 * This mob is a slicer, it's small, and quite fast, but quite easy to break.
 * Has a higher armor pen bonus as it uses a sharp blade to slice things.
 *
 * It's created by factories or any poor medical bots that get snared in the flesh.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/slicer
	name = "Slicer"
	desc = "A small organic robot, it somewhat resembles a medibot, but it has a blade slashing around."
	icon_state = "slicer"
	health = 50
	maxHealth = 50
	wound_bonus = 20
	melee_damage_lower = 15
	melee_damage_upper = 20
	attack_verb_continuous = "slices"
	attack_verb_simple = "slice"
	armour_penetration = 10
	attack_sound = 'sound/weapons/bladeslice.ogg'
	speed = 0
	speak = list(
		"Submit for mandatory surgery.",
		"Join the flesh through conversion.",
		"My scalpel will make short work of your seams.",
		"Please lay down.",
		"Always trust your doctor!",
		"I knew I'd be a good plastic surgeon!",
	)
	passive_speak_lines = list(
		"A stitch in time saves nine!",
		"Dopamine is happiness!",
		"Seratonin, oxycodone, happy humans all!",
		"Turn that frown upside down!",
		"Happiness through chemistry!",
		"Beauty through surgery!"
	)
	del_on_death = TRUE
	loot = list(
		/obj/item/bot_assembly/medbot,
		/obj/effect/gibspawner/robot,
	)

/**
 * Floater
 *
 * Special ability: Explodes on contact.
 * Malfunction chance: LOW
 *
 * The floater floats towards it's victims and explodes on contact.
 *
 * Created by factories.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/floater
	name = "Floater"
	desc = "A small organic robot that floats ominously."
	icon_state = "bomber"
	speak = list(
		"MUST BREAK TARGET INTO COMPONENT COMPOUNDS.",
		"PRIORITY OVER-RIDE. NEW BEHAVIOR DICTATED.",
		"END CONTACT SUB-SEQUENCE.",
		"ENGAGING SELF-ANNIHILATION CIRCUIT.",
	)
	passive_speak_lines = list(
		"WE COME IN PEACE.",
		"WE BRING GREETINGS FROM A FRIENDLY AI.",
		"DO NOT FEAR. WE SHALL NOT HARM YOU.",
		"WE WISH TO LEARN MORE ABOUT YOU. PLEASE TRANSMIT DATA.",
		"THIS PROBE IS NON-HOSTILE. DO NOT ATTACK.",
	)
	speed = 2
	health = 1
	maxHealth = 1
	del_on_death = TRUE
	loot = list(
		/obj/effect/gibspawner/robot,
	)
	light_color = "#820D1C"
	light_power = 1
	light_range = 2

/mob/living/simple_animal/hostile/corrupted_flesh/floater/death(gibbed)
	explosion(src, 0, 0, 2, 3)
	return ..(gibbed)

/mob/living/simple_animal/hostile/corrupted_flesh/floater/AttackingTarget(atom/attacked_target)
	. = ..()
	death()

/**
 * Globber
 *
 * Special ability: Fires 3 globs of acid at targets.
 * Malfunction chance: MEDIUM
 *
 * A converted cleanbot that instead of cleaning, burns things and throws acid. It doesn't like being near people.
 *
 * Created by factories or converted cleanbots.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/globber
	name = "Globber"
	desc = "A small robot that resembles a cleanbot, this one is dripping with acid."
	icon_state = "lobber"
	ranged = TRUE
	malfunction_chance = MALFUNCTION_CHANCE_MEDIUM
	melee_damage_lower = 1 // Ranged only
	melee_damage_upper = 1
	retreat_distance = 4
	minimum_distance = 4
	dodging = TRUE
	health = 75
	maxHealth = 75
	projectiletype = /obj/projectile/treader/weak
	speak = list(
		"Your insides require cleaning.",
		"Prepare to recieve a dose of acid.",
		"Administering cleansing agent.",
		"Ha ha! I'm an artist, I'm finally an artist!",
		"Your flesh is not clean, let me fix that.",
		"Hold still! I think I know just the thing to make you beautiful!",
		"This might hurt a little! Don't worry - it'll be worth it!",
	)

	passive_speak_lines = list(
		"No more leaks, no more pain!",
		"Steel is strong.",
		"All humankind is good for - is to serve the Hivemind.",
		"I'm still working on those bioreactors I promise!",
		"I have finally arisen!",
	)
	del_on_death = TRUE
	loot = list(
		/obj/item/bot_assembly/cleanbot,
		/obj/effect/gibspawner/robot,
	)

/obj/projectile/treader/weak
	knockdown = 0

/**
 * Stunner
 *
 * Special ability: Stuns victims.
 * Malfunction chance: MEDIUM
 *
 * A converted secbot, that is rogue and stuns victims.
 *
 * Created by factories or converted secbots.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/stunner
	name = "Stunner"
	desc = "A small robot that resembles a secbot, it rumbles with hatred."
	icon_state = "stunner"
	malfunction_chance = MALFUNCTION_CHANCE_MEDIUM
	melee_damage_lower = 1 // Not very harmful, just annoying.
	melee_damage_upper = 2
	health = 100
	maxHealth = 100
	attack_verb_continuous = "harmbatons"
	attack_verb_simple = "harmbaton"
	speak = list(
		"Resistance is futile, join the flesh.",
		"Stop criminal flesh!",
		"Stop moving, it will hurt less.",
		"The flesh does not mind frying you.",
		"Stop right there, meatbag!",
	)
	passive_speak_lines = list(
		"The flesh is the law, abide by the flesh.",
		"Joining the flesh is required by spacelaw.",
		"Hurting eachother is now legal.",
		"The only authority is that of the flesh, join the flesh.",
		"Resistance is futile, you will be converted to the flesh."
	)
	del_on_death = TRUE
	loot = list(
		/obj/item/bot_assembly/secbot,
		/obj/effect/gibspawner/robot,
	)

/mob/living/simple_animal/hostile/corrupted_flesh/stunner/AttackingTarget(atom/attacked_target)
	if(ishuman(target))
		var/mob/living/carbon/human/attacked_human = target
		attacked_human.Knockdown(30)
		playsound(src, 'sound/weapons/egloves.ogg', 50, TRUE)
	. = ..()

/**
 * Flesh Borg
 *
 * Special ability: Different attacks.
 * Claw: Stuns the victim.
 * Slash: Slashes everyone around it.
 * Malfunction chance: MEDIUM
 *
 * The hiborg is a converted cyborg.
 *
 * Created by factories or converted cyborgs.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/hiborg
	name = "Flesh Borg"
	desc = "A robot that resembles a cyborg, it is covered in something alive."
	icon_state = "hiborg"
	icon_dead = "hiborg-dead"
	malfunction_chance = MALFUNCTION_CHANCE_MEDIUM
	health = 350
	maxHealth = 350
	melee_damage_lower = 25
	melee_damage_upper = 30
	attack_verb_continuous = "saws"
	attack_verb_simple = "saw"
	speed = 2
	attack_sound = 'sound/weapons/circsawhit.ogg'
	alert_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_01.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_02.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_03.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_04.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_05.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/aggro_06.ogg',
	)
	passive_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/passive_01.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/passive_02.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/passive_03.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/passive_04.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/hiborg/passive_05.ogg',
	)
	speak = list(
		"You will join the flesh, child!",
		"You will be assimilated, the flesh yearns for your organic matter!",
		"Your brainstem is intact... for now!",
		"You have not felt the pleasure of the flesh, but you will now!",
		"Stop squirming!",
		"Prepare for assimilation!",
	)
	passive_speak_lines = list(
		"Come out, come out, wherever you are.",
		"The humans who surrender have such wonderful dreams.",
		"Death is not the end, only the beginning, the flesh will see to it.",
		"The flesh does not hate, it just wants you to experience the glory of the flesh.",
		"Glory to the flesh.",
	)
	/// The chance of performing a stun attack.
	var/stun_attack_prob = 30
	/// The chance of performing an AOE attack.
	var/aoe_attack_prob = 15
	/// The range on our AOE attaack
	var/aoe_attack_range = 1

/mob/living/simple_animal/hostile/corrupted_flesh/hiborg/AttackingTarget(atom/attacked_target)
	. = ..()
	if(prob(stun_attack_prob))
		if(ishuman(target))
			var/mob/living/carbon/human/attacked_human = target
			attacked_human.Paralyze(10)
			playsound(src, 'sound/weapons/egloves.ogg', 50, TRUE)
	if(prob(aoe_attack_prob))
		visible_message("[src] spins around violently!")
		spin(100, 10)
		for(var/mob/living/iterating_mob in view(aoe_attack_range, src))
			playsound(iterating_mob, 'sound/weapons/whip.ogg', 70, TRUE)
			new /obj/effect/temp_visual/kinetic_blast(get_turf(iterating_mob))

			var/atom/throw_target = get_edge_target_turf(iterating_mob, get_dir(src, get_step_away(iterating_mob, src)))
			iterating_mob.throw_at(throw_target, 20, 2)


/**
 * Mauler
 *
 * Special ability: Tears chunks out of things.
 * Malfunction chance: HIGH
 *
 * The mauler is a converted monkey, it's a mad ape!
 *
 * Created by converted monkeys.
 */
/mob/living/carbon/human/species/monkey/angry/mauler

/**
 * Himan
 *
 * Special ability: Shriek that stuns, the ability to play dead.
 *
 * Created by converted humans.
 */

/mob/living/simple_animal/hostile/corrupted_flesh/himan
	name = "Human"
	desc = "Once a man, now metal plates and tubes weave in and out of their oozing sores."
	icon_state = "himan"
	icon_dead = "himan-dead"
	base_icon_state = "himan"
	maxHealth = 250
	health = 250
	speed = 2
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	melee_damage_lower = 25
	melee_damage_upper = 35
	malfunction_chance = MALFUNCTION_CHANCE_HIGH
	speak = list(
		"Don't try and fix me! We love this!",
		"Just make it easy on yourself!",
		"Stop fighting progress!",
		"Join us! Receive these gifts!",
		"Yes! Hit me! It feels fantastic!",
		"Come on coward, take a swing!",
	)
	passive_speak_lines = list(
		"The dreams. The dreams.",
		"Nothing hurts anymore.",
		"Pain feels good now. Its like I've been rewired.",
		"I wanted to cry at first, but I can't.",
		"They took away all misery.",
		"This isn't so bad. This isn't so bad.",
		"My brain feels pleasure from this, the flesh is good.",
		"I don't remember who I am, but that's fine. The flesh provides.",
	)
	alert_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_01.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_02.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_03.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_04.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_05.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_06.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_07.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/aggro_08.ogg',
	)
	passive_sounds = list(
		'modular_skyrat/modules/corrupted_flesh/sound/himan/passive_01.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/passive_02.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/passive_03.ogg',
		'modular_skyrat/modules/corrupted_flesh/sound/himan/passive_04.ogg',
	)
	/// Are we currently faking our death? ready to pounce?
	var/faking_death = FALSE
	/// Fake death cooldown.
	var/fake_death_cooldown = 20 SECONDS
	COOLDOWN_DECLARE(fake_death)
	/// The cooldown between screams.
	var/scream_cooldown = 20 SECONDS
	COOLDOWN_DECLARE(scream_ability)
	var/scream_effect_range = 10

/mob/living/simple_animal/hostile/corrupted_flesh/himan/Life(delta_time, times_fired)
	. = ..()
	if(health < (maxHealth * 0.5) && !faking_death && COOLDOWN_FINISHED(src, fake_death))
		fake_our_death()

	if(faking_death)
		stop_automated_movement = TRUE

/mob/living/simple_animal/hostile/corrupted_flesh/himan/malfunction(reset_time)
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/say(message, bubble_type, list/spans, sanitize, datum/language/language, ignore_spam, forced, filterproof)
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/MoveToTarget(list/possible_targets)
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/AttackingTarget(atom/attacked_target)
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/Aggro()
	if(faking_death)
		if(!Adjacent(target))
			return
		awake()
	if(COOLDOWN_FINISHED(src, scream_ability))
		scream()
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/say_passive_speech()
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/alert_sound()
	if(faking_death)
		return
	return ..()

/mob/living/simple_animal/hostile/corrupted_flesh/himan/examine(mob/user)
	. = ..()
	if(faking_death)
		. += span_deadsay("Upon closer examination, [p_they()] appear[p_s()] to be dead.")

/mob/living/simple_animal/hostile/corrupted_flesh/himan/proc/scream()
	COOLDOWN_START(src, scream_ability, scream_cooldown)
	playsound(src, 'modular_skyrat/modules/horrorform/sound/horror_scream.ogg', 100, TRUE)
	manual_emote("screams violently!")
	for(var/mob/living/iterating_mob in get_hearers_in_range(scream_effect_range, src))
		if(!iterating_mob.can_hear())
			continue
		if(faction_check(faction, iterating_mob.faction))
			continue
		iterating_mob.Knockdown(100)
		iterating_mob.apply_status_effect(/datum/status_effect/jitter, 20 SECONDS)
		to_chat(iterating_mob, span_userdanger("A terrible howl tears through your mind, the voice senseless, soulless."))

/mob/living/simple_animal/hostile/corrupted_flesh/himan/proc/fake_our_death()
	manual_emote("stops moving...")
	LoseAggro()
	LoseTarget()
	faking_death = TRUE
	icon_state = "[base_icon_state]-dead"
	COOLDOWN_START(src, fake_death, fake_death_cooldown)

/mob/living/simple_animal/hostile/corrupted_flesh/himan/proc/awake()
	faking_death = FALSE
	icon_state = base_icon_state

/**
 * Treader
 *
 * Special ability: releases healing gas that heals other friendly mobs, ranged
 *
 * Created via assemblers.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/treader
	name = "Treader"
	desc = "A strange tracked robot with an appendage, on the end of which is a human head, it is shrieking in pain."
	icon_state = "treader"
	malfunction_chance = MALFUNCTION_CHANCE_HIGH
	melee_damage_lower = 15
	melee_damage_upper = 15
	retreat_distance = 4
	minimum_distance = 4
	dodging = TRUE
	health = 100
	maxHealth = 100
	speed = 3
	ranged_cooldown_time = 4 SECONDS
	attack_sound = 'sound/weapons/bladeslice.ogg'
	projectiletype = /obj/projectile/treader
	light_color = CORRUPTED_FLESH_LIGHT_BLUE
	light_range = 2
	del_on_death = TRUE
	loot = list(/obj/effect/gibspawner/robot)
	speak = list(
		"You there! Cut off my head, I beg you!",
		"I-..I'm so sorry! I c-..can't control myself anymore!",
		"S-shoot the screen, please! God I hope it wont hurt!"
	)
	speak = list(
		"Hey, at least I got my head.",
		"I cant... I cant feel my arms...",
		"Oh god... my legs... where are my legs!",
		"God it hurts, please help me!",
	)
	special_ability_cooldown = 20 SECONDS

/mob/living/simple_animal/hostile/corrupted_flesh/treader/special_ability()
	manual_emote("vomits out a burst of nanites!")
	do_smoke(3, 4, get_turf(src))
	for(var/mob/living/iterating_mob in view(DEFAULT_VIEW_RANGE, src))
		if(faction_check(iterating_mob.faction, faction))
			iterating_mob.heal_overall_damage(10, 10)

/obj/projectile/treader
	name = "nasty ball of ooze"
	icon_state = "neurotoxin"
	damage = 10
	damage_type = BURN
	nodamage = FALSE
	knockdown = 20
	armor_flag = BIO
	impact_effect_type = /obj/effect/temp_visual/impact_effect/neurotoxin
	hitsound = 'modular_skyrat/modules/black_mesa/sound/mobs/bullsquid/splat1.ogg'
	hitsound_wall = 'modular_skyrat/modules/black_mesa/sound/mobs/bullsquid/splat1.ogg'

/obj/projectile/treader/on_hit(atom/target, blocked, pierce_hit)
	new /obj/effect/decal/cleanable/greenglow(target.loc)
	return ..()


/**
 * Phaser
 *
 * Special abilities: Phases about next to it's target, can split itself into 4, only one is actually the mob. Can also enter closets if not being attacked.
 */
/mob/living/simple_animal/hostile/corrupted_flesh/phaser
	name = "Phaser"
	icon_state = "phaser-1"
	base_icon_state = "phaser"
	health = 160
	maxHealth = 160
	malfunction_chance = 0
	attack_sound = 'sound/effects/attackblob.ogg'
	attack_verb_continuous = "warps"
	attack_verb_simple = "warp"
	melee_damage_lower = 5
	melee_damage_upper = 10
	alert_sounds = null
	passive_sounds = null
	escapes_closets = FALSE
	speak = list()
	del_on_death = TRUE
	loot = list(
		/obj/effect/gibspawner/human,
	)
	wander = FALSE
	/// What is the range at which we spawn our copies?
	var/phase_range = 5
	/// How many copies do we spawn when we are aggroed?
	var/copy_amount = 3
	/// How often we can create copies of ourself.
	var/phase_ability_cooldown_time = 40 SECONDS
	COOLDOWN_DECLARE(phase_ability_cooldown)
	/// How often we are able to enter closets.
	var/closet_ability_cooldown_time = 2 SECONDS
	COOLDOWN_DECLARE(closet_ability_cooldown)

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/Initialize(mapload)
	. = ..()
	icon_state = "[base_icon_state]-[rand(1, 4)]"
	filters += filter(type = "blur", size = 0)

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/Aggro()
	if(COOLDOWN_FINISHED(src, phase_ability_cooldown))
		phase_ability()
	return ..()

/// old shitcode
/mob/living/simple_animal/hostile/corrupted_flesh/phaser/MoveToTarget(list/possible_targets)
	stop_automated_movement = TRUE
	if(!target || !CanAttack(target))
		LoseTarget()
		return FALSE
	if(target in possible_targets)
		var/turf/turf = get_turf(src)
		if(target.z != turf.z)
			LoseTarget()
			return FALSE
		if(get_dist(src, target) > 1)
			phase_move_to(target, nearby = TRUE)
		else if(target)
			MeleeAction()

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/Life(delta_time, times_fired)
	. = ..()
	if(!.) //dead
		return
	if(!target && COOLDOWN_FINISHED(src, closet_ability_cooldown))
		enter_nearby_closet()
		COOLDOWN_START(src, closet_ability_cooldown, closet_ability_cooldown_time)

	if(istype(loc, /obj/structure/closet))
		for(var/mob/living/iterating_mob in get_hearers_in_view(DEFAULT_VIEW_RANGE, get_turf(src)))
			if(faction_check(iterating_mob.faction, faction))
				continue
			if(iterating_mob.stat != CONSCIOUS)
				continue
			closet_interaction() // We exit if there are enemies nearby

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/proc/enter_nearby_closet()
	if(target) // We're in combat, no going to a closet.
		return
	if(istype(loc, /obj/structure/closet))
		return
	var/list/possible_closets = list()
	for(var/obj/structure/closet/closet in view(DEFAULT_VIEW_RANGE, src))
		if(closet.locked)
			continue
		possible_closets += closet
	if(!LAZYLEN(possible_closets))
		return
	var/obj/structure/closet/closet_to_enter = pick(possible_closets)

	playsound(closet_to_enter, 'sound/effects/phasein.ogg', 60, 1)

	if(!closet_to_enter.opened && !closet_to_enter.open(src))
		return

	forceMove(get_turf(closet_to_enter))

	closet_to_enter.close(src)

	COOLDOWN_RESET(src, phase_ability_cooldown)

	SEND_SIGNAL(src, COMSIG_PHASER_ENTER_CLOSET)

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/proc/phase_move_to(atom/target_atom, nearby = FALSE)
	var/turf/new_place
	var/distance_to_target = get_dist(src, target_atom)
	var/turf/target_turf = get_turf(target_atom)
	//if our target is near, we move precisely to it
	if(distance_to_target <= 3)
		if(nearby)
			for(var/dir in GLOB.alldirs)
				var/turf/nearby_turf = get_step(new_place, dir)
				if(can_jump_on(nearby_turf, target_turf))
					new_place = nearby_turf
		else
			new_place = target_turf

	if(!new_place)
		//there we make some kind of, you know, that creepy zig-zag moving
		//we just take angle, distort it a bit and turn into dir
		var/angle = get_angle(loc, target_turf)
		angle += rand(5, 25)*pick(-1, 1)
		if(angle < 0)
			angle = 360 + angle
		if(angle > 360)
			angle = 360 - angle
		var/tp_direction = angle2dir(angle)
		new_place = get_ranged_target_turf(loc, tp_direction, rand(2, 4))

	if(!can_jump_on(new_place, target_turf))
		return
	//an animation
	var/init_px = pixel_x
	animate(src, pixel_x=init_px + 16*pick(-1, 1), time = 5)
	animate(pixel_x=init_px, time=6, easing=SINE_EASING)
	animate(filters[1], size = 5, time = 5, flags = ANIMATION_PARALLEL)
	addtimer(CALLBACK(src, .proc/phase_jump, new_place), 0.5 SECONDS)
	SEND_SIGNAL(src, COMSIG_PHASER_PHASE_MOVE, target_atom, nearby)

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/proc/phase_jump(turf/place)
	playsound(place, 'sound/effects/phasein.ogg', 60, 1)
	animate(filters[1], size = 0, time = 5)
	icon_state = "[base_icon_state]-[rand(1, 4)]"
	forceMove(place)
	for(var/mob/living/living_mob in place)
		if(living_mob != src)
			visible_message("[src] lands directly on top of [living_mob]!")
			to_chat(living_mob, span_userdanger("[src] lands directly on top of you!"))
			playsound(place, 'sound/effects/ghost2.ogg', 70, 1)
			living_mob.Knockdown(10)

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/proc/can_jump_on(turf/target_turf, turf/previous_turf)
	if(!target_turf || target_turf.density || isopenspaceturf(target_turf))
		return FALSE


	if(previous_turf)
		if(!can_see(target_turf, previous_turf, DEFAULT_VIEW_RANGE)) // To prevent us jumping to somewhere we can't access the target atom.
			return FALSE

	//to prevent reflection's stacking
	var/obj/effect/temp_visual/phaser/phaser_reflection = locate() in target_turf
	if(phaser_reflection)
		return FALSE

	for(var/obj/iterating_object in target_turf)
		if(!iterating_object.CanPass(src, target_turf))
			return FALSE

	return TRUE

/mob/living/simple_animal/hostile/corrupted_flesh/phaser/proc/phase_ability()
	if(!target)
		return
	COOLDOWN_START(src, phase_ability_cooldown, phase_ability_cooldown_time)
	var/list/possible_turfs = list()
	for(var/turf/open/open_turf in circle_view_turfs(src, phase_range))
		possible_turfs += open_turf

	for(var/i in 1 to copy_amount)
		if(!LAZYLEN(possible_turfs))
			break
		var/turf/open/picked_turf = pick_n_take(possible_turfs)
		var/obj/effect/temp_visual/phaser/phaser_copy = new (pick(picked_turf), target)
		phaser_copy.RegisterSignal(src, COMSIG_PHASER_PHASE_MOVE, /obj/effect/temp_visual/phaser/proc/parent_phase_move)
		phaser_copy.RegisterSignal(src, COMSIG_LIVING_DEATH, /obj/effect/temp_visual/phaser/proc/parent_death)
		phaser_copy.RegisterSignal(src, COMSIG_PHASER_ENTER_CLOSET, /obj/effect/temp_visual/phaser/proc/parent_death)

/obj/effect/temp_visual/phaser
	icon = 'modular_skyrat/modules/corrupted_flesh/icons/hivemind_mobs.dmi'
	icon_state = "phaser-1"
	base_icon_state = "phaser"
	duration = 30 SECONDS
	/// The target we move towards, if any.
	var/datum/weakref/target_ref

/obj/effect/temp_visual/phaser/Initialize(mapload, atom/movable/target)
	. = ..()
	icon_state = "[base_icon_state]-[rand(1, 3)]"
	filters += filter(type = "blur", size = 0)

/obj/effect/temp_visual/phaser/proc/parent_phase_move(datum/source, turf/target_atom, nearby)
	SIGNAL_HANDLER
	if(!target_atom)
		return
	phase_move_to(target_atom, TRUE)

/obj/effect/temp_visual/phaser/proc/parent_death(mob/living/dead_guy, gibbed)
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/temp_visual/phaser/proc/phase_move_to(atom/target_atom, nearby = FALSE)
	var/turf/new_place
	var/distance_to_target = get_dist(src, target_atom)
	var/turf/target_turf = get_turf(target_atom)
	//if our target is near, we move precisely to it
	if(distance_to_target <= 3)
		if(nearby)
			for(var/dir in GLOB.alldirs)
				var/turf/nearby_turf = get_step(new_place, dir)
				if(can_jump_on(nearby_turf, target_turf))
					new_place = nearby_turf
		else
			new_place = target_turf

	if(!new_place)
		//there we make some kind of, you know, that creepy zig-zag moving
		//we just take angle, distort it a bit and turn into dir
		var/angle = get_angle(loc, target_turf)
		angle += rand(5, 25) * pick(-1, 1)
		if(angle < 0)
			angle = 360 + angle
		if(angle > 360)
			angle = 360 - angle
		var/tp_direction = angle2dir(angle)
		new_place = get_ranged_target_turf(loc, tp_direction, rand(2, 4))

	if(!can_jump_on(new_place, target_turf))
		return
	//an animation
	var/init_px = pixel_x
	animate(src, pixel_x = init_px + 16 * pick(-1, 1), time=5)
	animate(pixel_x = init_px, time = 6, easing = SINE_EASING)
	animate(filters[1], size = 5, time = 5, flags = ANIMATION_PARALLEL)
	addtimer(CALLBACK(src, .proc/phase_jump, new_place), 0.5 SECONDS)

/obj/effect/temp_visual/phaser/proc/phase_jump(turf/target_turf)
	playsound(target_turf, 'sound/effects/phasein.ogg', 60, 1)
	animate(filters[1], size = 0, time = 5)
	icon_state = "[base_icon_state]-[rand(1, 4)]"
	forceMove(target_turf)

/obj/effect/temp_visual/phaser/proc/can_jump_on(turf/target_turf, turf/previous_turf)
	if(!target_turf || target_turf.density || isopenspaceturf(target_turf))
		return FALSE

	if(previous_turf)
		if(!can_see(target_turf, previous_turf, DEFAULT_VIEW_RANGE))
			return FALSE

	//to prevent reflection's stacking
	var/obj/effect/temp_visual/phaser/phaser_reflection = locate() in target_turf
	if(phaser_reflection)
		return FALSE

	for(var/obj/iterating_object in target_turf)
		if(!iterating_object.CanPass(src, target_turf))
			return FALSE

	return TRUE


/**
 * Mechiver
 *
 * Special abilities: Can grab someone and shove them inside, does DOT and flavour text, can convert dead corpses into living ones that work for the flesh.
 *
 *
 */
/mob/living/simple_animal/hostile/corrupted_flesh/mechiver
	name = "Mechiver"
	icon_state = "mechiver"
	base_icon_state = "mechiver"
	icon_dead = "mechiver-dead"
	health = 500
	maxHealth = 500
	melee_damage_lower = 25
	melee_damage_upper = 35
	attack_verb_continuous = "crushes"
	attack_verb_simple = "crush"
	attack_sound = 'sound/weapons/smash.ogg'
	speed = 4 // Slow fucker
	passive_speak_lines = list(
		"A shame this form isn't more fitting.",
		"I feel so empty inside, I wish someone would join me.",
		"Beauty is within.",
	)
	speak = list(
		"What a lovely body. Lay it down intact.",
		"Come here, meatbag.",
		"What use is that flesh if you don't enjoy it?",
		"Mine is the caress of steel.",
		"I offer you the ecstasy of union, and yet you tremble.",
	)
	/// Is our hatch open? Used in icon processing.
	var/hatch_open = FALSE
	/// How much damage our mob will take, upper end, when they are tormented
	var/internal_mob_damage_upper = 10
	/// Ditto
	var/internal_mob_damage_lower = 5
	/// How long we keep our passenger before either releasing or converting them.
	var/conversion_time = 40 SECONDS
	/// The comsume ability cooldown
	var/consume_ability_cooldown_time = 1 MINUTES
	COOLDOWN_DECLARE(consume_ability_cooldown)
	/// A list of lines we will send to torment the passenger.
	var/list/torment_lines = list(
		"An arm grabs your neck!",
		"Lips whisper, \" This is the womb of your rebirth... \"",
		"Hot breath flows over your ear, \" You will enjoy bliss when this is over... \"",
		"A whirring drill bit bores through your chest!",
		"Something is crushing your ribs!",
		"Some blood-hot liquid covers you!",
		"The stench of some chemical overwhelms you!",
		"A dozen needles lance through your skin!",
		"You feel a cold worm-like thing trying to wriggle into your wounds!",
	)

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/Life(delta_time, times_fired)
	. = ..()
	if(contained_mob && contained_mob.stat != DEAD && prob(25) && !suffering_malfunction)
		torment_passenger()

	if(!target && !contained_mob && !suffering_malfunction)
		for(var/mob/living/iterating_mob in view(DEFAULT_VIEW_RANGE, src))
			if(iterating_mob.stat == DEAD)
				if(get_dist(src, iterating_mob) <= 1)
					consume_mob(iterating_mob)
				else
					Goto(iterating_mob)

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/proc/torment_passenger()
	if(!contained_mob)
		return
	var/damage_amount = rand(internal_mob_damage_lower, internal_mob_damage_upper)
	contained_mob.take_overall_damage(damage_amount)
	contained_mob.emote("scream")
	Shake(10, 0, 3 SECONDS)
	do_sparks(4, FALSE, src)
	to_chat(contained_mob, span_userdanger(pick(torment_lines)))
	playsound(src, 'sound/weapons/drill.ogg', 70, 1)

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/Moved()
	. = ..()
	update_appearance()

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/update_overlays()
	. = ..()
	if(target && (get_dist(target, src) <= 4))
		if(contained_mob)
			. += "[base_icon_state]-chief"
			. += "[base_icon_state]-hands"
		else
			. += "[base_icon_state]-wires"
	else if(!hatch_open)
		. += "[base_icon_state]-closed"
		if(contained_mob)
			. += "[base_icon_state]-process"


/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/AttackingTarget(atom/attacked_target)
	if(target && COOLDOWN_FINISHED(src, consume_ability_cooldown) && Adjacent(target))
		consume_mob(target)
	return ..()


/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/proc/consume_mob(mob/living/target_mob)
	if(contained_mob)
		return
	if(!istype(target_mob))
		return

	hatch_open = TRUE
	update_appearance()
	flick("[base_icon_state]-opening_wires", src)
	addtimer(CALLBACK(src, .proc/close_hatch), 1 SECONDS)

	if(target_mob.stat == DEAD)
		convert_mob(target_mob)

	contained_mob = target_mob
	target_mob.forceMove(src)

	to_chat(target_mob, span_userdanger("[src] ensnares your limbs as it pulls you inside its compartment, metal tendrils sliding around you, squeezing tight."))
	visible_message(span_danger("[src] consumes [target_mob]!"))
	playsound(src, 'sound/effects/blobattack.ogg', 70, 1)

	addtimer(CALLBACK(src, .proc/release_mob), conversion_time)

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/proc/close_hatch()
	hatch_open = FALSE
	update_appearance()

/// This is where we either release the user, if they're alive, or convert them, if they're dead.
/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/proc/release_mob()
	if(!contained_mob)
		return

	hatch_open = TRUE
	update_appearance()
	flick("[base_icon_state]-opening", src)
	addtimer(CALLBACK(src, .proc/close_hatch), 1 SECONDS)
	if(contained_mob.stat == DEAD)
		contained_mob.forceMove(get_turf(src))
		convert_mob(contained_mob)
		contained_mob = null
	else
		contained_mob.forceMove(get_turf(src))
		to_chat(contained_mob, span_danger("[src] releases you from its snares!"))
		contained_mob = null

	playsound(src, 'sound/effects/blobattack.ogg', 70, 1)

/mob/living/simple_animal/hostile/corrupted_flesh/mechiver/proc/convert_mob(mob/living/mob_to_convert)
	if(mob_to_convert.stat != DEAD) // No converting non-dead mobs.
		return

	if(iscyborg(mob_to_convert))
		var/mob/living/simple_animal/hostile/corrupted_flesh/hiborg/new_borg = new(get_turf(src))
		new_borg.contained_mob = mob_to_convert
		mob_to_convert.forceMove(new_borg)
		return

	if(ishuman(mob_to_convert))
		var/mob/living/simple_animal/hostile/corrupted_flesh/himan/new_himan = new(get_turf(src))
		new_himan.contained_mob = mob_to_convert
		mob_to_convert.forceMove(new_himan)
		return

	// Other mobs get converted into whatever else
	var/static/list/possible_mobs = list(
		/mob/living/simple_animal/hostile/corrupted_flesh/floater,
		/mob/living/simple_animal/hostile/corrupted_flesh/globber,
		/mob/living/simple_animal/hostile/corrupted_flesh/slicer,
		/mob/living/simple_animal/hostile/corrupted_flesh/stunner,
		/mob/living/simple_animal/hostile/corrupted_flesh/treader,
	)
	var/picked_mob_type = pick(possible_mobs)
	var/mob/living/simple_animal/hostile/corrupted_flesh/new_mob = new picked_mob_type(get_turf(src))
	mob_to_convert.forceMove(new_mob)
	new_mob.contained_mob = mob_to_convert
