return

{

    id = "elite_synthvor",
    name = "Synthetic Pazervore",
    strength = "elite",
    faction = "enemy",
    triggers = {
        {
            event = "before_engage",
            effect = "remove_and_reinforce",
            target_strength = "elite",
            add_force = "reg_synthwasp",
            stacking = "once_per_army",
        },
    },
    card_display = {

        p1 = { "When an allied army containing an Elite force makes a battlefield engagement test against this enemy army, before drawing a fate tile, remove 1 Elite force from the allied army and add 1 SYNTHETIC DEVILWASP to this enemy army. This effect does not stack." },

    },
    tags = {

        "wardroid",
        "digital",
        "armored",

    },

}
