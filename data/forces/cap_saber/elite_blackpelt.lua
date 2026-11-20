return

{

    id = "elite_blackpelt",
    name = "Blackpelt Wardroid",
    strength = "elite",
    faction = "allied",
    card_display = {

        p1 = { "+1 to any battlefield talent test for every 2 WARDROID forces in this allied army, up to a maximum of +3. This effect does not stack." },

    },
    passives = {
        {
            id = "blackpelt_battlefield_support",
            label = "BLACKPELT",
            effect = "battlefield_test_bonus",
            count_tag = "wardroid",
            per = 2,
            bonus = 1,
            maximum = 3,
            stacking = "once_per_army",
        },
    },
    tags = {

        "wardroid",
        "digital",
        "armored",

    },
    move_audio = "mech", 

}
