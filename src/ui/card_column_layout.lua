-- Pure variable-height column layout. Only spacing changes, never card dimensions.
local Layout = {}
function Layout.build(items, available, gap, first)
    local n = #items
    if n == 0 then return { entries={},first=1,lastStart=1 } end
    local lastStart, used = n, items[n].height
    for i=n-1,1,-1 do
        if used+items[i].minimum > available then break end
        used,lastStart = used+items[i].minimum,i
    end
    first = math.max(1,math.min(first or 1,lastStart))
    local last, minimum = first,items[first].height
    while last<n do
        local nextMinimum = minimum-items[last].height+items[last].minimum+items[last+1].height
        if nextMinimum>available then break end
        minimum,last = nextMinimum,last+1
    end
    local full = items[last].height
    for i=first,last-1 do full=full+items[i].height+gap end
    local blend = full<=available and 1 or (full==minimum and 0 or math.max(0,(available-minimum)/(full-minimum)))
    local entries,y = {},0
    for i=first,last do
        local item = items[i]
        local step = i==last and item.height or math.floor(item.minimum+(item.height+gap-item.minimum)*blend)
        entries[#entries+1]={index=i,y=y,height=item.height,hitHeight=step}
        y=y+step
    end
    return {entries=entries,first=first,lastStart=lastStart}
end
return Layout
