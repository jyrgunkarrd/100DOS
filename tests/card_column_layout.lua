return function()
    local L=require("src.ui.card_column_layout")
    local items={}
    for i=1,4 do items[i]={height=46,minimum=36} end
    local full=L.build(items,200,4,1)
    assert(#full.entries==4 and full.entries[2].y==50 and full.lastStart==1)
    local packed=L.build(items,160,4,1)
    assert(#packed.entries==4 and packed.entries[2].y<50 and packed.entries[2].y>=36 and packed.lastStart==1)
    items[5]={height=32,minimum=22}; items[6]={height=46,minimum=36}
    local overflow=L.build(items,160,4,100)
    assert(overflow.first>1 and overflow.first==overflow.lastStart)
    local last=overflow.entries[#overflow.entries]
    assert(last.index==6 and last.y+last.height<=160)
    assert(L.build({},160,4,99).first==1)
end
