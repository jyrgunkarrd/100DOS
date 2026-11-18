return

{

    id = "catburglar",
    name = "CATBURGLAR",
    cost = 1,
    card_type = "ASSET",
    asset_slots = 3,
    tags = { "human", "criminal" },
    health = 1,
    defiance = 2,
    methods = {

        { type = "shadow", qty = 3 },

    },
    talents = {

        { type = "passion", qty = 1 },
        { type = "fire", qty = 1 },

    },
    card_display = {

        p1 = { "[exhaust]EXHAUST[/exhaust] : +1 to any test opposed by the [tag]LOCK[/tag] tag."},
        p2 = { "[retask]RETASK[/retask] : This Asset's Agent gains \n+2 [talent]FIRE[/talent]."},
        p3 = { "[expend]EXPEND[/expend] : Explore this Location."}, 

    },
    card_bg = "thief_bg",
    card_fg = "thief_fg",

}
