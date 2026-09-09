// Editorial region associations in the PDF's 100 dpi coordinate system.
// This profile contains geometry, never retyped textbook sentences. Glyphs,
// fonts, colours, cell borders and illustrations come from the source files.
const trial=require('../reader-semantic-trial/book.json');
const pages=new Map();
const page=(number,...regions)=>pages.set(number,{number,id:`page-${number}`,regions});
const region=(kind,rect,options={})=>({kind,rect,...options});
const figure=rect=>region('figure',rect);
const diagram=rect=>region('diagram',rect);
const conversation=(y0,y1,x1=780)=>region('conversation',[90,y0,x1,y1]);
const table=(rect,options={})=>region('table',rect,options);
const grid=(xs,ys,options={})=>region('cards',[Math.min(...xs.flat()),Math.min(...ys),Math.max(...xs.flat()),Math.max(...ys)],{xs,ys,...options});
const parallel=(rect,columns,options={})=>region('parallel',rect,{columns,...options});
const row=(rect,options={})=>region('image-row',rect,options);

page(1,region('cover',[90,90,762,1107],{bands:[[130,327,722,451],[285,482,718,620]],kicker:[109,111,445,152],publisher:[340,913,510,1091],background:'#c1e2ac'}));
page(3,region('cover',[90,90,770,1080],{bands:[[92,300,756,440],[263,477,756,639]],kicker:[90,105,770,175]}));
page(4,region('toc',[90,225,765,1085],{ys:[225,327,400,515,634,752,968,1085],targets:['classroom','greetings','introduction','places','shopping-1','time','calendar']}));
page(5,region('toc',[90,225,765,940],{ys:[225,374,491,609,727,846,940],targets:['shopping-2','restaurant','telephone','illness','hospital','kana-chart']}));
page(6,...Array.from({length:8},(_,i)=>row([95,241+i*94.4,760,241+(i+1)*94.4])));
page(7,...Array.from({length:9},(_,i)=>row([95,155+i*94.4,760,155+(i+1)*94.4],i===2||i===3?{split:445}:{})));
for(const n of [8,9,10])page(n,...(n===10?[[225,408],[421,634],[642,829],[836,1025]]:[[225,410],[420,613],[620,806],[817,1006]])
  .map(([y0,y1])=>region('greeting',[90,y0,760,y1],{portraitRight:156,sceneLeft:n===8&&y0===225?480:376})));
for(const p of trial.pages){page(p.number,...p.regions.map(r=>({...r,approved:true})));pages.get(p.number).id=p.id;}
page(12,conversation(340,571,550),figure([552,314,734,513]),figure([106,665,746,1032]));
page(13,grid([94,316,541,759],[203,381,550,728,898,1074]));
page(14,conversation(338,660));
page(15,conversation(340,539),grid([94,315,538,761],[545,743]));
page(16,diagram([124,174,730,622]),grid([[125,299],[343,516],[555,730]],[643,857,1080]));
page(18,diagram([91,60,752,470]),grid([90,427,765],[592,852,1100],{diagrams:true}));
page(19,conversation(337,550),figure([153,570,739,1048]));
page(20,diagram([72,145,771,1090]));
page(21,conversation(338,678),figure([217,677,608,889]),grid([79,305,536,767],[889,1070],{diagrams:true}));
page(22);
page(23,parallel([89,244,765,840],[89,306,524,765],{splits:[164,391,616]}),parallel([89,842,765,1090],[89,306,524,765],{splits:[177,403,650]}));
page(24,grid([97,317,540,755],[610,766,912,1070]));
page(25,conversation(340,550,458),figure([460,396,694,650]));
page(26,conversation(335,551),figure([424,520,756,738]));
page(27,parallel([88,184,538,485],[88,298,538],{splits:[172,381]}),diagram([540,178,729,530]),parallel([89,580,770,933],[89,280,534,770],{splits:[144,341,597]}));
page(28,grid([130,450,753],[319,591,846,1090]));
page(29,grid([91,425,764],[150,383,618,851,1094],{border:true}));
page(30,...Array.from({length:9},(_,i)=>row([90,179+i*87.2,770,179+(i+1)*87.2],{imageRects:[
  [125,190+i*86.65,195,265+i*86.65],
  [[453,182,582,279],[620,262,750,361],[480,365,645,429],[585,428,757,526],[461,535,622,605],[601,603,756,700],[478,685,629,779],[603,779,760,877],[475,875,622,965]][i]
],routine:true})));
page(31,...Array.from({length:8},(_,i)=>row([90,170+i*79,770,170+(i+1)*79],{imageRects:[[98,178+i*78.7,167,247+i*78.7]],routine:true})));
for(const n of [32,33,34])page(n,grid(n===34?[91,316,539,765]:[88,313,537,762],[167,398,628,858,1093],{border:true,count:n===34?11:12}));
page(35,conversation(340,570));
page(36,grid([89,314,537,764],[197,447,684,933]));
page(37,conversation(320,687,490),figure([493,430,724,623]));
page(38,table([85,152,765,399]),table([133,470,718,660]),figure([223,693,629,1095]));
page(39,conversation(225,370),table([86,467,760,1009],{calendar:true}));
page(40,parallel([86,235,770,540],[86,290,491,770],{splits:[174,375,584],border:true}),parallel([86,646,768,1009],[86,425,768],{splits:[219,556],border:true}));
page(41,parallel([85,233,768,510],[85,425,768],{splits:[249,577],border:true}),grid([92,425,762],[532,813,1082],{border:true}));
page(42,conversation(335,608),conversation(709,917),figure([232,915,568,1100]));
page(43,grid([97,331,563,754],[689,883],{border:true}),grid([213,447,637],[896,1086],{border:true}));
page(44,diagram([91,186,766,720]),table([90,919,768,1018]));
for(const n of [45,46,47])page(n,grid([[88,406],[438,760]],[148,372,599,825,1053],{border:true}));
page(48,conversation(335,550),figure([214,646,622,1025]));
page(49,conversation(335,624));
page(50,conversation(216,550),figure([258,545,608,812]),grid([98,269,437,602,764],[851,1065]));
page(51,parallel([88,704,770,982],[88,332,553,770],{splits:[152,372,593],border:true}));
page(52,grid([95,266,433,600,770],[262,502,751],{border:true}),grid([95,266,433,600,770],[809,1064],{border:true}));
page(53,grid([79,250,417,584,759],[109,350,590,830,1090],{border:true}));
page(54,conversation(310,883),figure([534,671,760,908]));
page(55,conversation(177,710),figure([476,712,724,867]));
page(56,grid([108,425,733],[151,469]),diagram([93,545,771,1072]));
page(57,grid([[95,424],[428,762]],[239,636,1056],{diagrams:true}));
page(58,row([108,158,768,358]),row([108,372,768,590]),region('paragraph',[90,673,770,1015],{writing:true}));
page(59,conversation(336,706,494),figure([494,531,720,760]));
page(60,grid([[88,417],[422,758]],[237,505,750,999],{border:true}));
page(61,diagram([88,151,426,472]),diagram([428,151,764,309]),diagram([428,309,764,472]),grid([[88,426],[428,764]],[575,1044],{diagrams:true}));
page(62,conversation(330,592,512),figure([514,365,743,590]),conversation(606,886,538),figure([540,691,762,915]),conversation(890,1098));
page(63,grid([[88,425],[427,768]],[511,776,1043],{border:true}));
page(64,grid([[88,425],[427,768]],[237,507,771,1033],{border:true}));
page(65,conversation(330,742,514),figure([514,402,764,614]),diagram([542,628,738,834]),region('callout-diagram',[92,833,763,1066],{imageRect:[132,924,755,1028]}));
page(66,grid([94,428,765],[238,504,758,1030],{border:true}));
page(67,region('blank-area',[90,170,765,1100]));
page(68,table([95,238,770,1078],{removeEmptyColumns:true,compact:true}));
page(69,table([78,240,767,1082],{removeEmptyColumns:true,compact:true}));
page(70,table([85,204,766,510],{writing:true}),table([85,558,766,864],{writing:true}),table([85,912,766,1100],{writing:true}));
page(71,figure([80,84,771,1066]));
page(72,region('colophon',[90,490,770,1100]));

const chapters=[
  ['cover','封面',1,1],['title-page','扉页',3,3],['contents','もくじ',4,5],
  ['classroom','01 きょうしつの ことば',6,7],['greetings','02 あいさつ',8,10],
  ['introduction','03 じこしょうかい',11,14],['places','04 ばしょをきく',15,18],
  ['shopping-1','05 デパート・スーパーで（1）',19,24],['time','06 じかんをきく',25,34],
  ['calendar','07 カレンダー',35,41],['shopping-2','08 デパート・スーパーで（2）',42,47],
  ['restaurant','09 レストランで',48,53],['telephone','10 でんわをかける',54,58],
  ['illness','11 びょうき',59,61],['hospital','12 びょういんで',62,66],['notes','メモ',67,67],
  ['kana-chart','ごじゅうおん ひょう',68,69],['writing','名前・住所・国・地域',70,70],
  ['hamamatsu-map','浜松市の地図',71,71],['colophon','奥付',72,72]
].map(([id,title,first,last])=>({id,title,navTitle:title,startPage:first,pages:Array.from({length:last-first+1},(_,i)=>first+i)}));

module.exports={schemaVersion:2,title:'やらまいか日本語',fixedEpub:trial.fixedEpub,pdfSha256:trial.pdfSha256,
  referenceDpi:100,omitFonts:trial.omitFonts,application:{revision:2},chapters,pages:[...pages.values()].sort((a,b)=>a.number-b.number)};
