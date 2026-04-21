// Cleanup, Startup Items, Suggestions views
const { useState: useStateV2, useEffect: useEffectV2, useMemo: useMemoV2, useRef: useRefV2 } = React;

// ─── Cleanup ──────────────────────────────────────────
function CleanupView({ state, dispatch }) {
  const [phase, setPhase] = useState('idle'); // idle | scanning | scanned | cleaning | done
  const [scanProgress, setScanProgress] = useState(0);
  const [scanningLabel, setScanningLabel] = useState('');
  const [dryRun, setDryRun] = useState(true);
  const [items, setItems] = useState(state.cleanup.map(c => ({...c, isSelected:true, scanned:false})));

  const selectedBytes = items.filter(i=>i.isSelected && i.scanned).reduce((a,i)=>a+i.bytes,0);
  const totalBytes = items.filter(i=>i.scanned).reduce((a,i)=>a+i.bytes,0);

  function startScan() {
    setPhase('scanning'); setScanProgress(0);
    setItems(items.map(i => ({...i, scanned:false})));
    let idx = 0;
    const step = () => {
      if (idx >= items.length) { setPhase('scanned'); setScanProgress(100); return; }
      const it = items[idx];
      setScanningLabel(it.path);
      setItems(prev => prev.map((p,k) => k===idx ? {...p, scanned:true} : p));
      setScanProgress(((idx+1)/items.length)*100);
      idx++;
      setTimeout(step, 420);
    };
    setTimeout(step, 300);
  }

  function startClean() {
    if (dryRun) {
      setPhase('done');
      return;
    }
    setPhase('cleaning'); setScanProgress(0);
    let i = 0;
    const sel = items.filter(x=>x.isSelected);
    const step = () => {
      if (i >= sel.length) { setPhase('done'); return; }
      setScanningLabel(sel[i].path);
      setScanProgress(((i+1)/sel.length)*100);
      i++;
      setTimeout(step, 300);
    };
    setTimeout(step, 300);
  }

  function reset() {
    setPhase('idle'); setScanProgress(0);
    setItems(items.map(i=>({...i, scanned:false, isSelected:true})));
  }

  const cats = ['User Cache','Logs','Xcode','iOS Backups','DNS Cache'];

  return (
    <div style={{padding:'clamp(20px, 3vw, 32px) clamp(20px, 3vw, 36px) 40px', display:'flex', flexDirection:'column', gap:20}}>
      <div>
        <Eyebrow>Cleanup</Eyebrow>
        <h1 style={{fontFamily:'var(--font-hero)', fontSize:'clamp(30px, 3.8vw, 52px)', lineHeight:1.2, margin:'8px 0 10px',
          fontWeight:400, letterSpacing:'-0.03em', textWrap:'balance'}}>
          {phase==='idle' && <>Reclaim <em style={{fontStyle:'italic', color:'var(--accent-strong)'}}>space</em> safely.</>}
          {phase==='scanning' && <>Scanning <em style={{fontStyle:'italic', color:'var(--accent-strong)'}}>your disk</em>…</>}
          {(phase==='scanned' || phase==='cleaning') && <><em style={{fontStyle:'italic', color:'var(--accent-strong)'}}>{fmtBytes(selectedBytes)}</em> ready to clean.</>}
          {phase==='done' && <>Cleaned <em style={{fontStyle:'italic', color:'var(--good-strong)'}}>{fmtBytes(selectedBytes)}</em>{dryRun && <span style={{color:'var(--ink-50)'}}> (dry run)</span>}.</>}
        </h1>
        <div style={{fontSize:13, color:'var(--ink-60)', maxWidth:560, lineHeight:1.55, marginBottom:14}}>
          Dry-run is on by default — MacOptimizer shows exactly what it would delete before it deletes anything.
        </div>
        <div style={{display:'flex', gap:10, alignItems:'center', flexWrap:'wrap'}}>
          <label style={{display:'inline-flex', alignItems:'center', gap:10, padding:'8px 12px',
            border:'1px solid var(--ink-10)', borderRadius:10, background:'var(--surface)'}}>
            <Toggle on={dryRun} onChange={setDryRun}/>
            <div>
              <div style={{fontSize:12, fontWeight:600, color:'var(--ink)'}}>Dry run</div>
              <div style={{fontSize:10.5, color:'var(--ink-50)'}}>Preview only</div>
            </div>
          </label>
          <div style={{flex:1}}/>
          {phase==='idle' && <Btn variant="primary" onClick={startScan}><Icon name="search" size={13}/>Scan</Btn>}
          {phase==='scanned' && <>
            <Btn variant="ghost" onClick={reset}>Cancel</Btn>
            <Btn variant="primary" onClick={startClean}><Icon name="trash" size={13}/>{dryRun?'Preview clean':'Clean now'}</Btn>
          </>}
          {phase==='done' && <Btn variant="primary" onClick={reset}><Icon name="refresh" size={13}/>Scan again</Btn>}
        </div>
      </div>

      {(phase==='scanning' || phase==='cleaning') && (
        <Card pad={18}>
          <div style={{display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:10}}>
            <div style={{fontSize:12, color:'var(--ink-60)', fontFamily:'var(--font-mono)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap', flex:1, marginRight:16}}>
              {phase==='scanning'?'Scanning':'Cleaning'} · {scanningLabel}
            </div>
            <div style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-60)'}}>{Math.round(scanProgress)}%</div>
          </div>
          <Bar value={scanProgress} height={6} hue="var(--accent)"/>
        </Card>
      )}

      {/* Big summary */}
      {(phase==='scanned' || phase==='done') && (
        <Card pad={24} style={{background:'var(--ink)', color:'var(--paper)', border:'1px solid var(--ink)'}}>
          <div style={{display:'grid', gridTemplateColumns:'auto 1fr auto', gap:30, alignItems:'center'}}>
            <div>
              <div style={{fontSize:10.5, letterSpacing:'0.14em', textTransform:'uppercase', opacity:0.5, fontWeight:700}}>
                {phase==='done'?'Reclaimed':'Can reclaim'}
              </div>
              <div style={{fontFamily:'var(--font-hero)', fontSize:88, lineHeight:0.9, letterSpacing:'-0.04em', marginTop:6, fontWeight:400}}>
                {fmtBytes(selectedBytes)}
              </div>
              <div style={{marginTop:10, fontSize:12, opacity:0.6, fontFamily:'var(--font-mono)'}}>
                of {fmtBytes(totalBytes)} found · {items.filter(i=>i.isSelected).length}/{items.length} items selected
              </div>
            </div>
            <div style={{display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:12}}>
              {cats.map(cat => {
                const catItems = items.filter(i=>i.category===cat);
                const catSize = catItems.reduce((a,i)=>a+i.bytes,0);
                const maxCat = Math.max(...cats.map(c=>items.filter(i=>i.category===c).reduce((a,i)=>a+i.bytes,0)));
                return (
                  <div key={cat}>
                    <div style={{height: 80, display:'flex', alignItems:'flex-end'}}>
                      <div style={{width:'100%',
                        height: `${Math.max(6, (catSize/maxCat)*100)}%`,
                        background:'var(--accent)', borderRadius: 2,
                        transition:'height 500ms ease'}}/>
                    </div>
                    <div style={{marginTop:8, fontSize:10, letterSpacing:'0.06em', textTransform:'uppercase', opacity:0.6, fontWeight:600}}>{cat}</div>
                    <div style={{fontFamily:'var(--font-mono)', fontSize:11.5, marginTop:2}}>{fmtBytes(catSize)}</div>
                  </div>
                );
              })}
            </div>
          </div>
        </Card>
      )}

      {/* Item list */}
      <Card pad={0}>
        <div style={{padding:'18px 22px 14px', display:'flex', alignItems:'center', justifyContent:'space-between', borderBottom:'1px solid var(--ink-5)'}}>
          <Eyebrow>Scan targets</Eyebrow>
          {phase==='scanned' && (
            <button onClick={()=>{
              const allSel = items.filter(i=>i.scanned).every(i=>i.isSelected);
              setItems(items.map(i=>i.scanned?{...i, isSelected:!allSel}:i));
            }} style={{border:'none', background:'none', fontSize:12, fontWeight:600, color:'var(--ink-60)', cursor:'pointer', fontFamily:'var(--font-ui)'}}>
              {items.filter(i=>i.scanned).every(i=>i.isSelected)?'Deselect all':'Select all'}
            </button>
          )}
        </div>
        {items.map((it, i) => (
          <div key={i} style={{display:'grid', gridTemplateColumns:'32px 1fr 120px 100px',
            gap:14, alignItems:'center', padding:'16px 22px', borderTop: i===0?'none':'1px solid var(--ink-5)'}}>
            <button disabled={!it.scanned || phase==='cleaning'} onClick={()=>{
              setItems(items.map((x,k)=>k===i?{...x, isSelected:!x.isSelected}:x));
            }} style={{
              width:20, height:20, borderRadius:6,
              border:`1.5px solid ${it.isSelected && it.scanned ? 'var(--accent)':'var(--ink-15)'}`,
              background: it.isSelected && it.scanned ? 'var(--accent)':'transparent',
              cursor: it.scanned?'pointer':'default', padding:0,
              display:'flex', alignItems:'center', justifyContent:'center',
              opacity: it.scanned?1:0.3,
            }}>
              {it.isSelected && it.scanned && <Icon name="check" size={12} style={{color:'var(--paper)'}} stroke={2.5}/>}
            </button>
            <div>
              <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:3}}>
                <span style={{fontSize:13.5, fontWeight:600, color:'var(--ink)'}}>{it.name}</span>
                <Chip tone="neutral" style={{fontSize:9.5}}>{it.category}</Chip>
              </div>
              <div style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-50)', marginBottom:3}}>{it.path}</div>
              <div style={{fontSize:12, color:'var(--ink-60)', lineHeight:1.4}}>{it.description}</div>
            </div>
            <div style={{fontFamily:'var(--font-hero)', fontSize:20, textAlign:'right',
              letterSpacing:'-0.02em', fontWeight:400,
              color: it.scanned?'var(--ink)':'var(--ink-30)'}}>
              {it.scanned ? fmtBytes(it.bytes) : '—'}
            </div>
            <div style={{textAlign:'right'}}>
              {!it.scanned && phase!=='scanning' && <span style={{fontSize:11, color:'var(--ink-40)', fontFamily:'var(--font-mono)'}}>unscanned</span>}
              {!it.scanned && phase==='scanning' && <span style={{fontSize:11, color:'var(--accent-strong)', fontFamily:'var(--font-mono)'}}>scanning…</span>}
              {it.scanned && phase==='done' && it.isSelected && <Chip tone="good"><Icon name="check" size={9}/>{dryRun?'Previewed':'Cleaned'}</Chip>}
              {it.scanned && (phase==='scanned' || (phase==='done' && !it.isSelected)) && <span style={{fontSize:11, color:'var(--ink-50)', fontFamily:'var(--font-mono)'}}>ready</span>}
            </div>
          </div>
        ))}
      </Card>
    </div>
  );
}

// ─── Startup Items ──────────────────────────────────────
function StartupView({ state, dispatch }) {
  const [items, setItems] = useState(state.startup);
  const [scope, setScope] = useState('all');
  const visible = items.filter(i => scope==='all' ? true : i.scope.toLowerCase()===scope);
  const enabledCount = items.filter(i=>i.enabled).length;

  return (
    <div style={{padding:'clamp(20px, 3vw, 32px) clamp(20px, 3vw, 36px) 40px', display:'flex', flexDirection:'column', gap:20}}>
      <div>
        <Eyebrow>Startup items</Eyebrow>
        <h1 style={{fontFamily:'var(--font-hero)', fontSize:'clamp(28px, 3.4vw, 46px)', lineHeight:1.2, margin:'8px 0 10px', fontWeight:400, letterSpacing:'-0.03em', textWrap:'balance'}}>
          <em style={{fontStyle:'italic', color:'var(--accent-strong)'}}>{enabledCount}</em> of {items.length} launch at login.
        </h1>
        <div style={{fontSize:13, color:'var(--ink-60)', maxWidth:620, lineHeight:1.55, marginBottom:14}}>
          Fewer startup items means a faster boot. Toggle anything off — MacOptimizer runs <code style={{fontFamily:'var(--font-mono)', background:'var(--ink-5)', padding:'1px 5px', borderRadius:4, fontSize:12}}>launchctl unload</code> for you.
        </div>
        <div style={{display:'flex', border:'1px solid var(--ink-10)', borderRadius:8, overflow:'hidden', background:'var(--surface)', alignSelf:'flex-start', width:'fit-content'}}>
          {['all','user','system'].map(s=>(
            <button key={s} onClick={()=>setScope(s)} style={{
              border:'none', padding:'8px 16px', fontSize:12, fontWeight:600,
              background:scope===s?'var(--ink)':'transparent',
              color:scope===s?'var(--paper)':'var(--ink-60)',
              textTransform:'capitalize', cursor:'pointer', fontFamily:'var(--font-ui)',
            }}>{s}</button>
          ))}
        </div>
      </div>

      <Card pad={0}>
        {visible.map((it, i) => (
          <div key={it.label} style={{display:'grid', gridTemplateColumns:'auto 1fr auto auto',
            gap:18, alignItems:'center', padding:'16px 22px', borderTop: i===0?'none':'1px solid var(--ink-5)'}}>
            <div style={{width:36, height:36, borderRadius:10,
              background: it.enabled?'var(--accent-10)':'var(--ink-5)',
              color: it.enabled?'var(--accent-strong)':'var(--ink-50)',
              display:'flex', alignItems:'center', justifyContent:'center'}}>
              <Icon name="play" size={16}/>
            </div>
            <div style={{minWidth:0}}>
              <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:3}}>
                <span style={{fontSize:13.5, fontWeight:600, color:'var(--ink)', fontFamily:'var(--font-mono)'}}>{it.label}</span>
                <Chip tone={it.scope==='System'?'warn':'neutral'} style={{fontSize:9.5}}>{it.scope}</Chip>
              </div>
              <div style={{fontSize:11.5, color:'var(--ink-50)', fontFamily:'var(--font-mono)', marginBottom:3, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{it.path}</div>
              <div style={{fontSize:12, color:'var(--ink-60)', lineHeight:1.4}}>{it.why}</div>
            </div>
            <div style={{fontSize:11, color: it.enabled?'var(--accent-strong)':'var(--ink-50)',
              fontFamily:'var(--font-ui)', fontWeight:600, letterSpacing:'0.04em', textTransform:'uppercase'}}>
              {it.enabled?'Enabled':'Disabled'}
            </div>
            <Toggle on={it.enabled} onChange={v=>{
              setItems(items.map(x=>x.label===it.label?{...x, enabled:v}:x));
            }}/>
          </div>
        ))}
      </Card>
    </div>
  );
}

// ─── Suggestions ──────────────────────────────────────
function SuggestionsView({ state, dispatch }) {
  const [filter, setFilter] = useState('all');
  const sugs = state.suggestions;
  const filtered = filter==='all'?sugs:sugs.filter(s=>s.severity.toLowerCase()===filter);

  const counts = {
    critical: sugs.filter(s=>s.severity==='Critical').length,
    warning:  sugs.filter(s=>s.severity==='Warning').length,
    info:     sugs.filter(s=>s.severity==='Info').length,
  };

  return (
    <div style={{padding:'clamp(20px, 3vw, 32px) clamp(20px, 3vw, 36px) 40px', display:'flex', flexDirection:'column', gap:20}}>
      <div>
        <Eyebrow>Suggestions</Eyebrow>
        <h1 style={{fontFamily:'var(--font-hero)', fontSize:'clamp(28px, 3.6vw, 48px)', lineHeight:1.2, margin:'8px 0 10px', fontWeight:400, letterSpacing:'-0.03em', textWrap:'balance'}}>
          {sugs.length>0 ? <><em style={{fontStyle:'italic', color:'var(--accent-strong)'}}>{sugs.length}</em> fix{sugs.length===1?'':'es'} ranked by impact.</> : <>All clear. <em style={{fontStyle:'italic', color:'var(--good-strong)'}}>Nothing to fix.</em></>}
        </h1>
        <div style={{fontSize:13, color:'var(--ink-60)', maxWidth:620, lineHeight:1.55, marginBottom:14}}>
          Each card is a specific action tied to a real process or condition on your Mac right now. Tap a card to act on it.
        </div>
        <div style={{display:'flex', gap:8, flexWrap:'wrap'}}>
          {[
            ['all',    'All', sugs.length, 'neutral'],
            ['critical','Critical', counts.critical, 'danger'],
            ['warning', 'Warning',  counts.warning,  'warn'],
            ['info',    'Info',     counts.info,     'neutral'],
          ].map(([key, label, n, tone]) => (
            <button key={key} onClick={()=>setFilter(key)} style={{
              border:`1px solid ${filter===key?'var(--ink)':'var(--ink-10)'}`,
              background: filter===key?'var(--ink)':'var(--surface)',
              color: filter===key?'var(--paper)':'var(--ink-70)',
              padding:'7px 13px', borderRadius:9, cursor:'pointer',
              fontSize:12, fontWeight:600, fontFamily:'var(--font-ui)',
              display:'inline-flex', alignItems:'center', gap:7,
            }}>
              {label} <span style={{
                fontFamily:'var(--font-mono)', fontSize:11,
                opacity: filter===key?0.7:0.5
              }}>{n}</span>
            </button>
          ))}
        </div>
      </div>

      {filtered.length===0 && (
        <Card pad={60} style={{textAlign:'center'}}>
          <div style={{display:'inline-flex', width:56, height:56, borderRadius:'50%',
            background:'var(--good-10)', color:'var(--good-strong)',
            alignItems:'center', justifyContent:'center', marginBottom:16}}>
            <Icon name="check" size={24} stroke={2.2}/>
          </div>
          <div style={{fontFamily:'var(--font-hero)', fontSize:28, letterSpacing:'-0.02em'}}>Nothing to flag.</div>
          <div style={{marginTop:8, color:'var(--ink-60)', fontSize:14}}>We'll surface cards here the moment something drifts.</div>
        </Card>
      )}

      <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fill, minmax(360px, 1fr))', gap:14}}>
        {filtered.map(s => {
          const sevTone = s.severity==='Critical'?'danger':s.severity==='Warning'?'warn':'neutral';
          const sevColor = s.severity==='Critical'?'oklch(55% 0.18 28)':s.severity==='Warning'?'oklch(70% 0.14 75)':'var(--ink-40)';
          const sevIcon = s.severity==='Critical'?'critical':s.severity==='Warning'?'warning':'info';
          return (
            <Card key={s.id} pad={0} hoverable style={{overflow:'hidden', display:'flex', flexDirection:'column'}}>
              <div style={{height:4, background: sevColor}}/>
              <div style={{padding:'18px 20px 14px', flex:1, display:'flex', flexDirection:'column', gap:10}}>
                <div style={{display:'flex', alignItems:'center', gap:8, justifyContent:'space-between'}}>
                  <div style={{display:'flex', gap:6, alignItems:'center'}}>
                    <Chip tone={sevTone}>
                      <Icon name={sevIcon} size={10}/>{s.severity}
                    </Chip>
                    <Chip tone="neutral">{s.category}</Chip>
                  </div>
                  {s.metric && <span style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-50)'}}>{s.metric}</span>}
                </div>
                <div style={{fontSize:16, fontWeight:600, color:'var(--ink)', lineHeight:1.3, letterSpacing:'-0.01em'}}>{s.title}</div>
                <div style={{fontSize:13, color:'var(--ink-60)', lineHeight:1.55, flex:1}}>{s.detail}</div>
                <div style={{display:'flex', gap:8, marginTop:6}}>
                  {s.actionLabel && <Btn variant="solid" size="sm" onClick={()=>dispatch({type:'actOnSuggestion', id:s.id})}>
                    <Icon name="bolt" size={12}/>{s.actionLabel}
                  </Btn>}
                  <Btn variant="ghost" size="sm" onClick={()=>dispatch({type:'dismissSuggestion', id:s.id})}>Dismiss</Btn>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}

Object.assign(window, { CleanupView, StartupView, SuggestionsView });
