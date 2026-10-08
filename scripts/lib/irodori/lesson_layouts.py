"""Reviewed source regions for Starter L01 pages 4–18.

Coordinates are in PDF points. Text and image regions claim source characters via
Page.select; omitted/duplicate content is a build error, never silently appended.
"""
PAGE_TITLES = [
    '第 4 页 · 分别时的问候', '第 5 页 · 告别会话',
    '第 6 页 · 表达感谢', '第 7 页 · 表达道歉', '第 8 页 · 感谢与道歉会话',
    '第 9 页 · 信息表情', '第 10 页 · 发送表情',
    '第 11 页 · 听力脚本：问候', '第 12 页 · 听力脚本：告别与感谢',
    '第 13 页 · 听力脚本：感谢与道歉',
    '第 14 页 · 平假名与罗马字', '第 15 页 · 字体与输入法',
    '第 16 页 · 长音、促音与词汇', '第 17 页 · 日本生活：问候',
    '第 18 页 · 日本生活：すみません'
]


def wrap(content, cls):
    return '<div class="'+cls+'">'+content+'</div>'


def grid(cells, columns=2, cls='exercise'):
    rows=[]
    for offset in range(0,len(cells),columns):
        row=cells[offset:offset+columns]
        rows.append('<tr>'+''.join('<td style="width:'+str(100/columns)+'%">'+c+'</td>' for c in row)+
                    ('<td class="empty"></td>'*(columns-len(row)))+'</tr>')
    return '<table class="'+cls+'"><tbody>'+''.join(rows)+'</tbody></table>'


def section(p):
    # Original coloured heading/icon; the learning goal below remains live text.
    heading=p.picture((62,90,534,139),f'p{p.number}-section')
    goal=('<table class="goal-table"><tbody><tr><td class="icon">'+
          p.picture((62,139,107,168),f'p{p.number}-can-do')+'</td><td>'+
          p.text((107,139,540,169))+'</td></tr></tbody></table>')
    return wrap(heading+wrap(goal,'goal'),'keep')


def choices(p, rects):
    # The original grey speech panels hold answer choices; preserve their order.
    return ''.join(wrap(p.text(r,base_size=13),'choice keep') for r in rects)


def exercise(p, specs):
    cells=[]
    for i,(label,art) in enumerate(specs,1):
        cells.append(p.text(label,'exercise-label',inline_audio=True,base_size=14)+
                     p.picture(art,f'p{p.number}-exercise-{i}'))
    return grid(cells)


def dialogue(p,left,right,left_tail,right_tail,arrow,split_left=(),split_right=(),stacked=False):
    def box(rect,side,splits,tailrect):
        cuts=[rect[1],*splits,rect[3]]
        text=''.join(p.text((rect[0],lo,rect[2],hi),'variant' if i else '',base_size=15)
                     for i,(lo,hi) in enumerate(zip(cuts,cuts[1:])))
        tail=p.picture(tailrect,f'p{p.number}-tail-{side}-{int(rect[1])}')
        body='<td class="speech '+('reply' if side=='left' else '')+'">'+text+'</td>'
        tip='<td class="tail">'+tail+'</td>'
        return wrap('<table class="bubble"><tbody><tr>'+(tip+body if side=='left' else body+tip)+'</tr></tbody></table>',
                    '' if side=='left' else 'response')
    a=box(left,'left',split_left,left_tail);b=box(right,'right',split_right,right_tail)
    arrow_img=p.picture(arrow,f'p{p.number}-arrow-{int(left[1])}')
    if stacked:
        # Three long alternatives need full width to remain readable on a phone.
        return wrap(wrap(a,'prompt-bubble')+wrap(arrow_img,'stack-arrow')+wrap(b,'answer-bubble'),'dialogue-stack')
    return '<table class="dialogue-row"><tbody><tr><td class="speech-cell">'+a+'</td><td class="arrow-cell" style="vertical-align:top;padding-top:1.6em">'+arrow_img+'</td><td class="speech-cell">'+b+'</td></tr></tbody></table>'


def script_block(p,lo,hi):
    label=p.text((65,lo,150,hi),'script-label',inline_audio=True,base_size=14)
    # Each A/B/C turn keeps Japanese and its Roman reading together.
    starts=sorted({round(c['origin'][1],1) for c in p.chars
                   if 175<c['bbox'][0]<200 and lo<(c['bbox'][1]+c['bbox'][3])/2<hi and c['c'] in 'ＡＢＣ'})
    cuts=[lo]+[baseline-23 for baseline in starts[1:]]+[hi]
    turns=[p.text((175,y0,545,y1),'script-turn',base_size=12.75) for y0,y1 in zip(cuts,cuts[1:])]
    return wrap(wrap(label+turns[0],'keep')+''.join(wrap(turn,'keep') for turn in turns[1:]),'script-block')


def kana_table(p,xs,ys,header=True,row_label=True,base=15):
    rows=[]
    for row,(y0,y1) in enumerate(zip(ys,ys[1:])):
        cells=[]
        for col,(x0,x1) in enumerate(zip(xs,xs[1:])):
            shaded=(header and row==0) or (row_label and col==0)
            content='' if header and row_label and row==0 and col==0 else p.text((x0,y0,x1,y1),ruby=False,base_size=base)
            cells.append('<td'+(' class="kana-heading"' if shaded else '')+'>'+content+'</td>')
        rows.append('<tr>'+''.join(cells)+'</tr>')
    return '<table class="kana"><tbody>'+''.join(rows)+'</tbody></table>'


def remaining_page(p):
    n=p.number;t=p.text;pic=p.picture
    out=[wrap(pic((28,23,567,63),f'p{n}-header'),'header')]
    def instruction(lo,hi):return t((55,lo,545,hi),'instruction')
    if n==4:
        out += [section(p),instruction(180,219),instruction(220,258),instruction(259,299)]
        out.append(exercise(p,[((77,303,298,327),(78,327,298,460)),((298,303,519,327),(298,327,519,460)),
                               ((77,460,298,482),(78,482,298,616)),((298,460,519,482),(298,482,519,616))]))
        out.append(choices(p,[(105,635,250,680),(267,635,395,680),(401,635,520,680),
                              (105,689,255,735),(267,689,415,735),(105,745,255,790),(267,745,415,790)]))
    elif n==5:
        out += [instruction(80,137),instruction(163,200)]
        specs=[((200,231),(140,244,275,329),(330,268,450,354),(285,309)),
               ((374,403),(140,414,280,459),(330,440,450,482),()),
               ((503,531),(140,544,280,587),(330,569,450,611),())]
        for (lo,hi),a,b,splits in specs:
            delta=a[1]-244
            # Tips/arrow have the same source geometry in all three rows.
            out.append(wrap(instruction(lo,hi)+dialogue(p,a,b,(115,249+delta,137,264+delta),
                (460,273+delta,481,288+delta),(289,273+delta,321,287+delta),
                split_left=splits[:1],split_right=splits[1:]),'keep'))
        out += [instruction(633,672),instruction(675,714),instruction(715,754),instruction(755,796)]
    elif n==6:
        out += [section(p),instruction(180,219),instruction(220,259),t((55,270,545,297),'subhead'),instruction(298,335)]
        out.append(exercise(p,[((62,341,219,365),(63,365,218,509)),((219,341,376,365),(219,365,376,509)),
                               ((376,341,534,365),(376,365,534,509)),((62,509,219,534),(63,534,219,678)),
                               ((219,509,376,534),(219,534,376,678))]))
        out.append(choices(p,[(160,691,310,734),(367,691,465,734),(160,745,310,791),(367,745,465,791)]))
    elif n==7:
        out.append(instruction(80,119))
        entries=[(73,135,135,175),(135,135,198,175),(198,135,540,175),
                 (73,175,140,213),(140,175,224,213),(224,175,540,213),(73,213,540,251)]
        out.append(wrap(''.join(wrap(t(rect,base_size=13),'vocab-entry keep') for rect in entries),'vocabulary'))
        out += [instruction(268,328),t((55,339,545,367),'subhead'),instruction(368,404)]
        out.append(exercise(p,[((62,410,219,434),(63,434,219,581)),((219,410,376,434),(219,434,376,581)),((376,410,534,434),(376,434,534,581))]))
        out.append(choices(p,[(187,595,280,641),(342,595,419,641)]))
        out += [instruction(656,696),wrap(t((73,711,540,754),base_size=13),'vocabulary')]
    elif n==8:
        out += [instruction(80,138),instruction(163,199),instruction(200,225)]
        out.append(dialogue(p,(145,240,199,280),(250,286,455,416),(120,241,140,255),(467,290,488,306),(207,270,239,285),
                            split_right=(330,375),stacked=True))
        out.append(instruction(431,460))
        out.append(wrap(dialogue(p,(145,470,199,514),(250,518,330,558),(120,475,140,490),(341,523,360,538),(207,501,239,516)),'keep'))
        out += [instruction(590,631),instruction(632,672),instruction(674,713),instruction(715,754)]
    elif n==9:
        out += [section(p),instruction(180,219),instruction(220,277),
                wrap(pic((378,222,524,339),'p9-person'),'small-illustration'),instruction(350,392)]
        out.append(grid([t((x,lo,x+155,mid),'instruction')+pic((x+8,mid,x+154,hi),f'p9-stamp-{i}')
                         for i,(x,lo,mid,hi) in enumerate([(90,395,412,594),(351,395,412,594),(90,599,617,797),(351,599,617,797)],1)],cls='cards'))
    elif n==10:
        out += [instruction(80,117),instruction(118,157)]
        out += [instruction(lo,hi) for lo,hi in [(158,183),(183,207),(207,231),(231,256)]]
        out.append(pic((120,279,475,560),'p10-stamps'))
    elif n in (11,12,13):
        if n==11:
            out.append(pic((62,80,211,110),'p11-script-heading'))
            out.append(t((65,126,540,159),'band',ruby=False))
            out += [script_block(p,lo,hi) for lo,hi in [(169,265),(279,376),(389,487),(500,597)]]
            out += [t((65,613,540,646),'band'),script_block(p,656,753)]
        elif n==12:
            out += [script_block(p,lo,hi) for lo,hi in [(101,199),(207,354),(367,465)]]
            out += [t((65,480,540,514),'band',ruby=False),script_block(p,523,577),script_block(p,585,688)]
        else:out += [script_block(p,lo,hi) for lo,hi in [(101,245),(256,354),(367,465),(474,576),(588,687),(699,752)]]
    elif n==14:
        out += [pic((63,64,335,105),'p14-title'),instruction(122,160)]
        left=[71,100,137,174,211,248,285];right=[328,357,394,431,468,505,542]
        ys=[173,194.5]+[194.5+i*32.6 for i in range(1,11)]
        # Four source tables are stacked at phone width; every row remains a row.
        out.append(t((60,169,98,190),'track'))
        out.append(kana_table(p,left,ys))
        out.append(wrap(t((291,484,328,521),ruby=False,base_size=15),'syllabic-n keep'))
        out.append(t((320,169,351,190),'track'))
        out.append(kana_table(p,right,[173,194.5,227.1,259.7,292.3,324.9,357.5,390.1,422.7]))
        out.append(t((60,526,98,543),'track'))
        out.append(kana_table(p,[71,100,150,224,285],[528,549]+[549+i*32.6 for i in range(1,8)]))
        out.append(t((320,526,351,543),'track'))
        out.append(kana_table(p,[328,357,409,482,542],[528,549,581.6,614.2,646.8,679.1,711.7,744.3]))
        out.append(t((325,748,540,783),'instruction'))
    elif n==15:
        out.append(instruction(94,131))
        for x in (62.4,329.2):
            out.append(t((x-4,133,x+228,171),'instruction'))
            xs=[x+i*34.02 for i in range(6)];ys=[178.9+i*34.02 for i in range(11)]
            out.append(kana_table(p,xs,ys,False,False,base=18))
            out.append(wrap(t((x+170.1,484,x+204.2,522),ruby=False,base_size=18),'syllabic-n keep'))
        note=[t((105,539,490,570),'instruction')]
        note += [t((105,lo,490,hi),'instruction') for lo,hi in [(571,608),(612,647),(647,673),(675,712),(712,737)]]
        out.append(wrap(''.join(note),'input-note'))
    elif n==16:
        out += [instruction(94,131),instruction(132,161)]
        cells=[]
        for i,(x,lo,mid,hi) in enumerate([(62,162,197,257),(180,162,197,257),(297,162,197,257),
                                        (62,257,292,354),(180,257,292,354),(297,257,292,354),(415,257,292,354)],1):
            cells.append(t((x,lo,x+117,mid),base_size=15)+pic((x,mid,x+117,hi),f'p16-long-{i}'))
        out.append(grid(cells,cls='word-cards'))
        out += [instruction(354,389),instruction(389,429),instruction(438,469)]
        out.append(grid([t((x,470,x+117,504),base_size=15)+pic((x,504,x+117,572),f'p16-short-{i}')
                         for i,x in enumerate((62,180,297,415),1)],cls='word-cards'))
        out.append(instruction(577,617))
        # Read the numbered left column before the right column.
        out += [t((85,620,280,724),'instruction',base_size=12),t((294,620,540,699),'instruction',base_size=12),instruction(743,782)]
    elif n==17:
        out += [wrap(pic((59,61,148,123),'p17-tips'),'tips-badge'),t((60,134,540,162),'culture-title',base_size=12)]
        out.append(pic((341,147,533,276),'p17-bow-photo'))
        for lo,hi in [(175,217.5),(217.5,244),(244,288)]:out.append(t((60,lo,335,hi),'prose',ruby=False,base_size=8,flow=True))
        out.append(pic((341,283,533,412),'p17-office-photo'))
        for lo,hi in [(294,349),(349,412.5),(412.5,468)]:out.append(t((60,lo,540,hi),'prose japanese-prose',ruby=False,base_size=8,flow=True))
        out.append(wrap(pic((70,379,182,520),'p17-greeting-art'),'small-illustration'))
        out += [t((60,550,540,578),'culture-title',base_size=12),pic((61,587,282,735),'p17-school-photo'),
                t((290,590,540,680),'prose',ruby=False,base_size=8,flow=True),
                t((60,683,540,781),'prose japanese-prose',ruby=False,base_size=8,flow=True)]
    elif n==18:
        out += [t((60,91,545,124),'culture-title',base_size=12),pic((343,142,534,275),'p18-train-photo')]
        for lo,hi in [(135,165),(165,219),(219,246),(246,301)]:out.append(t((60,lo,335,hi),'prose',ruby=False,base_size=8,flow=True))
        for lo,hi in [(309,337.5),(337.5,375.5),(375.5,401),(401,431)]:out.append(t((60,lo,540,hi),'prose japanese-prose',ruby=False,base_size=8,flow=True))
    else:raise ValueError(f'No reviewed layout for page {n}')
    return out
