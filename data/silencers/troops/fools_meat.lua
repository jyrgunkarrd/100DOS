return

{

    id = "fools_meat",
    name = "Fool's Meat",
    card_type = "SILENCER",
    ongoing_fate = { "infiltration" },
    tags = { "wardroid", "our lord father", "infiltrator", "assassin" },
    health = 1,
    damage = 1,
    trauma = 1,
    talent_tests = {

        { id = "strike", kind = "strike", val = 3 },
        { id = "evade", kind = "evade", val = 2 },

    },
        card_display = {

        p1 = { "While this SILENCER is revealed, add an INFILTRATION tile to the Fate pool."},

    },
    sabotage = {

        "infected_intelligence",

    },
    atk_sfx = "pistol",
    defeat_sfx = "fem",
    card_bg = "silencer_bg",
    card_fg = "silencer_fg",

}