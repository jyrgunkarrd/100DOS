return

{

    id = "security_door",
    name = "Security Door",
    card_type = "BARRIER",
    blocks_explore = true,
    tags = { "lock", "door", "digital" },
    talent_tests = {

        { id = "force", kind = "interact", talent = "steel", val = 8 },
        { id = "unlock", kind = "interact", talent = "reason", val = 2 },

    },
    card_display = {

        p1 = { "While this Barrier is in play, this location cannot be Explored."},

    },
    card_bg = "none",
    card_fg = "none",

}
