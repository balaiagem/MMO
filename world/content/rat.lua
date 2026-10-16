local monsterType = Game.createMonsterType("Rat")

monsterType:register({
	name = "Rat",
	description = "a small rat",
	experience = 10,
	-- The local 8.60 DAT maps the official rat sprite to outfit slot 2.
	outfit = { lookType = 2 },
	health = 1,
	maxHealth = 1,
	race = "blood",
	speed = 67,
	manaCost = 0,
	flags = {
		attackable = true,
		hostile = true,
		pushable = true,
		staticAttackChance = 90,
		targetDistance = 1,
		runHealth = 5,
	},
	attacks = {
		{ name = "melee", interval = 2000, chance = 100, minDamage = 0, maxDamage = -8 },
	},
	defenses = { defense = 0, armor = 1 },
})
