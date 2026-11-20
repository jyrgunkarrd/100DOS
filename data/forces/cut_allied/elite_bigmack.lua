return

{

    id = "elite_bigmack",
    name = "Big Mack",
    strength = "elite",
    faction = "allied",
    card_display = {

        p1 = { "If you succeed at a battlefield maneuver test by 2 or more, this force deals 1 damage to an enemy army at its destination." },

    },
    triggers = {
        {
            event = "after_maneuver",
            minimum_margin = 2,
            effect = "army_damage",
            amount = 1,
            target = "random_destination_enemy_force",
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
