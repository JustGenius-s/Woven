(() => {
  const reading=document.getElementById('reading'),chapter=window.WovenChapter.id;
  let initialized=false,timer=0,settingsGeneration=0,pendingPosition=null;
  const candidates=[...reading.querySelectorAll('h1,h2,p,figure,table,.command,.grammar-panel,.sentence-panel,.book-diagram')];
  candidates.forEach((el,index)=>el.dataset.readingAnchor='r'+index);
  const maxScroll=()=>Math.max(0,document.documentElement.scrollHeight-innerHeight);
  function snapshot(){
    const visible=candidates.map(el=>({el,rect:el.getBoundingClientRect()})).filter(item=>item.rect.height>0);
    const item=visible.sort((a,b)=>Math.abs(a.rect.top)-Math.abs(b.rect.top))[0];
    return item?{anchor:item.el.dataset.readingAnchor,offset:-item.rect.top/Math.max(1,item.rect.height)}:{anchor:'',offset:0};
  }
  function restore(position){
    if(position.anchor==='end'){scrollTo(0,maxScroll());return;}
    const id=position.anchor;
    const element=candidates.find(el=>el.dataset.readingAnchor===id)||document.getElementById(id);
    if(element){const rect=element.getBoundingClientRect();scrollTo(0,rect.top+scrollY+(Number(position.offset)||0)*rect.height);}
    else scrollTo(0,0);
  }
  function report(){
    if(!initialized)return;
    const position=snapshot();
    window.ReaderHost?.report(chapter,position.anchor,position.offset,scrollY<=2,scrollY>=maxScroll()-2);
  }
  const frame=()=>new Promise(resolve=>requestAnimationFrame(resolve));
  async function settle(){
    await document.fonts.ready;
    window.dispatchEvent(new Event('woven-reader-style'));
    await frame();await frame();
  }
  function setStyle(style){
    reading.style.fontSize=Math.max(16,Math.min(40,Number(style.fontSize)||22))+'px';
    reading.style.lineHeight=Math.max(1.2,Math.min(2.4,Number(style.lineHeight)||1.7));
  }
  window.WovenReader={
    async initialize(options){
      initialized=false;setStyle(options);
      await Promise.all([...document.images].map(img=>img.decode?.().catch(()=>{})));
      await settle();restore({anchor:options.anchor||'',offset:options.offset||0});
      initialized=true;window.ReaderHost?.ready(chapter);report();
    },
    async settings(style){
      const generation=++settingsGeneration;
      if(!pendingPosition)pendingPosition=snapshot();
      initialized=false;setStyle(style);
      await settle();if(generation!==settingsGeneration)return;
      restore(pendingPosition);pendingPosition=null;initialized=true;report();
    },
    flip(direction){
      if(!initialized)return;
      const next=direction>0;
      if((next&&scrollY>=maxScroll()-2)||(!next&&scrollY<=2))window.ReaderHost?.turn(chapter,next?1:-1);
      else {scrollBy(0,(next?1:-1)*Math.max(1,innerHeight-parseFloat(getComputedStyle(reading).fontSize)*2));report();}
    },
    report
  };
  addEventListener('scroll',()=>{clearTimeout(timer);timer=setTimeout(report,120);},{passive:true});
  addEventListener('pagehide',report);
  document.addEventListener('visibilitychange',()=>{if(document.hidden)report();});
  document.addEventListener('click',event=>{
    const link=event.target.closest?.('a[href]');if(!link)return;
    const url=new URL(link.getAttribute('href'),location.href);
    if(url.protocol!=='file:') {event.preventDefault();return;}
    const target=url.pathname.split('/').at(-1).replace(/\.(xhtml|html)$/,'');
    event.preventDefault();report();
    if(target===chapter){document.getElementById(decodeURIComponent(url.hash.slice(1)))?.scrollIntoView();report();}
    else window.ReaderHost?.jump(target,decodeURIComponent(url.hash.slice(1)));
  });
})();
