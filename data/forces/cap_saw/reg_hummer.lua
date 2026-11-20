return

{

    id = "reg_hmmvv",
    portrait = "reg_hummer",
    name = "M1 HMMWV",
    strength = "regular",
    faction = "allied",
    card_display = {

        p1 = { "+1 to battlefield maneuver tests made by this allied army.\n\nThis effect stacks." },

    },
    passives = {
        {
            id = "hmmwv_maneuver_support",
            label = "HMMWV",
            effect = "battlefield_test_bonus",
            action = "maneuver",
            bonus = 1,
            stacking = "per_force",
        },
    },
    tags = {

        "human",
        "vehicle",
        "reliable",
        "wretched",

    },
    move_audio = "motor", 

}
