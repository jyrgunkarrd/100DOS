return

{

    id = "elite_abrams",
    name = "M1 Abrams Tank",
    strength = "elite",
    faction = "allied",
    card_display = {

        p1 = { "A location with this force has +1 protection. This effect stacks up to 2 times and can exceed the normal protection cap." },

    },
    passives = {
        {
            id = "abrams_protection",
            label = "ABRAMS",
            effect = "location_protection_bonus",
            bonus = 1,
            maximum = 2,
            stacking = "per_force",
        },
    },
    tags = {

        "human",
        "vehicle",
        "armored",
        "wretched",

    },
    move_audio = "motor", 

}
