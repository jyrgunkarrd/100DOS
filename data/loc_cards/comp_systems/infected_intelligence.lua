return

{

    id = "infected_intelligence",
    name = "Infected Intelligence",
    card_type = "SABOTAGE",
    ongoing_fate = { "autofail" },
    tags = { "software", "virus", "digital" },
    talent_tests = {

        { id = "force", kind = "interact", talent = "steel", val = 8 },
        { id = "unlock", kind = "interact", talent = "reason", val = 2 },

    },
    card_display = {

        p1 = { "While this Sabotage is revealed, add a Glory tile to the Fate pool."},

    },
    card_bg = "none",
    card_fg = "none",

}