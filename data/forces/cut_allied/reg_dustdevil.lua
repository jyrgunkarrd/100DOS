return

{

    id = "reg_dustdevil",
    name = "Dust Devil",
    strength = "regular",
    faction = "allied",
    card_display = {

        p1 = { "When an allied army containing this force engages and reduces an enemy army to 0 strength, gain 1 REDLINE bonus fate tile.\n\nThis effect does not stack." },

    },
    triggers = {
        {
            event = "after_engage",
            effect = "grant_bonus_fate",
            tile_id = "redline",
            amount = 1,
        },
    },
    tags = {

        "human",
        "vehicle",
        "reliable",
        "criminal",

    },
    move_audio = "motor", 

}
