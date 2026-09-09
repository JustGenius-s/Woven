// Count only source glyphs in fields actually used by the semantic renderer.
function renderedGlyphs(blocks) {
  const result=[];
  const text=value=>{
    if(!value)return;
    if(Array.isArray(value)){value.forEach(text);return;}
    if(value.kind==='ruby'){text(value.base);text(value.reading);return;}
    if(!value.synthetic&&value.sourceIndex!==undefined&&value.text?.trim())result.push(value);
  };
  const visit=b=>{
    if(!b)return;
    if(Array.isArray(b)){b.forEach(visit);return;}
    switch(b.kind) {
      case 'source-section':visit(b.blocks);break;
      case 'heading':text(b.glyphs);break;
      case 'paragraph':case 'colophon':text(b.rows);break;
      case 'conversation':for(const t of b.turns){text(t.speaker);text(t.lines);}visit(b.figures);break;
      case 'panel':for(const g of b.groups)for(const c of g.cells)text(c.glyphs);text(b.punctuation);break;
      case 'multi-panel':for(const r of b.rows){for(const g of r.groups)for(const c of g.cells)text(c.rows);text(r.outside);}break;
      case 'cards':for(const c of b.items){text(c.before);text(c.after);visit(c.picture);}break;
      case 'table':for(const c of b.rows.flat())text(c.rows);break;
      case 'parallel':for(const item of b.items)for(const r of item.rows){text(r.left);text(r.right);}break;
      case 'diagram':for(const l of b.labels)text(l.glyphs);break;
      case 'image-row':text(b.rows);visit(b.pictures);break;
      case 'paired-row':text(b.number);for(const i of b.items){text(i.rows);visit(i.pictures);}break;
      case 'greeting':for(const t of b.turns){text(t.rows);visit(t.picture);}visit(b.scene);break;
      case 'cover':visit(b.kicker);visit(b.bands);visit(b.publisher);break;
      case 'toc':for(const t of b.items){text(t.number);text(t.rows);text(t.page);}break;
      case 'callout-diagram':for(const i of b.items)text(i.rows);text(b.rows);visit(b.figure);break;
      case 'figure':case 'blank-area':break;
      default:throw new Error(`Unknown text ownership for ${b.kind}`);
    }
  };
  visit(blocks);return result;
}
module.exports={renderedGlyphs};
