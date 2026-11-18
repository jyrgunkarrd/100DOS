return

{

    id = "blast_door",
    name = "Blast Door",
    card_type = "SYSTEM",
    on_resolve = { security = 4 },
    tags = { "lock", "door", "digital" },
    talent_tests = {

        { id = "force", kind = "interact", talent = "steel", val = 8 },
        { id = "unlock", kind = "interact", talent = "reason", val = 2 },

    },
    card_display = {

        p1 = { "When this System is resolved, gain 4 JACL Security, up to its cap."},

    },
    card_bg = "none",
    card_fg = "none",

}
