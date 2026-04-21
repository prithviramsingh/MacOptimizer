// Dashboard & Processes views
const { useState: useStateV1, useEffect: useEffectV1, useMemo: useMemoV1, useRef: useRefV1 } = React;

// ─── Dashboard ──────────────────────────────────────────
function DashboardView({ state, dispatch }) {
  const tick = useLivePulse(1000);
  const procs = state.processes;

  // animated aggregate CPU — jittered around a target
  const totalCPU = useMemo(() => {
    const sum = procs.reduce((a,p)=>a + jitter(p.cpu, tick, p.pid), 0);
    return clamp(sum / state.mac.cores * 0.9, 2, 98);
  }, [procs, tick, state.mac.cores]);

  // cpu history (30 samples)
  const cpuHistoryRef = useRef([]);
  useEffect(() => {
    cpuHistoryRef.current = [...cpuHistoryRef.current, totalCPU].slice(-40);
  }, [totalCPU]);

  const memPct = (state.mac.usedRamGB / state.mac.totalRamGB)*100;
  const diskPct = (state.mac.usedDiskGB / state.mac.totalDiskGB)*100;

  const top = [...procs].sort((a,b)=>b.cpu - a.cpu).slice(0,5);

  const sugs = state.suggestions;
  const crit = sugs.filter(s=>s.severity==='Critical').length;
  const warn = sugs.filter(s=>s.severity==='Warning').length;
  const info = sugs.filter(s=>s.severity==='Info').length;

  const health = crit>0 ? 'critical' : warn>1 ? 'warn' : 'good';
  const healthLabel = { critical:'Needs attention', warn:'Watch list', good:'All clear' }[health];
  const healthTone = { critical:'danger', warn:'warn', good:'good' }[health];

  return (
    <div style={{padding:'clamp(20px, 3vw, 32px) clamp(20px, 3vw, 36px) 40px', display:'flex', flexDirection:'column', gap:24}}>
      {/* Hero strip */}
      <div>
        <div style={{fontSize:11, letterSpacing:'0.16em', textTransform:'uppercase',
          color:'var(--ink-50)', fontWeight:700, marginBottom:12,
          display:'flex', alignItems:'center', justifyContent:'space-between', gap:12, flexWrap:'wrap'}}>
          <span style={{display:'inline-flex', alignItems:'center', gap:8}}>
            <span style={{width:6, height:6, borderRadius:'50%', background: health==='good'?'var(--good)':health==='warn'?'oklch(70% 0.14 75)':'oklch(55% 0.18 28)',
              boxShadow:`0 0 0 4px ${health==='good'?'var(--good-10)':'oklch(70% 0.14 75 / 0.2)'}`,
              animation:'pulse 1.6s ease-in-out infinite'}}/>
            Live · {new Date().toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})} · Polling every 5s
          </span>
          <Chip tone={healthTone}>
            <Icon name={health==='good'?'check':health==='warn'?'warning':'critical'} size={11}/>
            {healthLabel}
          </Chip>
        </div>
        <h1 style={{fontFamily:'var(--font-hero)', fontSize:'clamp(30px, 3.8vw, 52px)', lineHeight:1.2,
          margin:'0 0 14px', letterSpacing:'-0.03em', fontWeight:400, color:'var(--ink)', textWrap:'balance',
          paddingBottom:4}}>
          Your Mac is <em style={{fontStyle:'italic',
            color: health==='good'?'var(--good-strong)':'var(--accent-strong)'}}>{
            health==='good' ? 'running clean' : health==='warn' ? 'feeling the heat' : 'overworked right now'
          }</em>.
        </h1>
        <div style={{display:'flex', justifyContent:'space-between', gap:20, flexWrap:'wrap', alignItems:'flex-end'}}>
          <div style={{fontSize:13.5, color:'var(--ink-60)', maxWidth:620,
            lineHeight:1.55, fontFamily:'var(--font-ui)', flex:'1 1 320px'}}>
            {crit>0 ? `${crit} critical issue${crit>1?'s':''} waiting for a decision. ` : ''}
            {warn>0 ? `${warn} warning${warn>1?'s':''} worth a look. ` : ''}
            {crit===0 && warn===0 ? 'Nothing to do — we\'ll ping you if that changes.' : 'Jump into Suggestions to take action.'}
          </div>
          <div style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-50)', textAlign:'right', lineHeight:1.6, flexShrink:0}}>
            <div>{state.mac.hostname} · {state.mac.osVersion}</div>
            <div>{state.mac.model} · uptime {state.mac.uptimeDays}d {state.mac.uptimeHours}h</div>
          </div>
        </div>
      </div>

      {/* Vitals */}
      <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(220px, 1fr))', gap:16}}>
        {/* CPU — hero */}
        <Card pad={22} style={{position:'relative', overflow:'hidden'}}>
          <Eyebrow right={<span style={{fontFamily:'var(--font-mono)', fontSize:10, color:'var(--ink-50)'}}>{state.mac.cores}c</span>}>CPU</Eyebrow>
          <div style={{display:'flex', alignItems:'center', gap:16, marginTop:10, flexWrap:'wrap'}}>
            <Ring value={totalCPU} size={112} stroke={8} label="load" hue="var(--accent)"/>
            <div style={{flex:'1 1 140px', minWidth:0}}>
              <div style={{fontSize:10, color:'var(--ink-50)', marginBottom:6, letterSpacing:'0.08em', textTransform:'uppercase', fontWeight:600}}>Last 40s</div>
              <Sparkline values={cpuHistoryRef.current} width={160} height={46}/>
              <div style={{marginTop:8, display:'flex', gap:12,
                fontFamily:'var(--font-mono)', fontSize:10.5, color:'var(--ink-60)'}}>
                <span>pk {Math.max(0, ...cpuHistoryRef.current).toFixed(0)}%</span>
                <span>avg {(cpuHistoryRef.current.reduce((a,b)=>a+b,0)/(cpuHistoryRef.current.length||1)).toFixed(0)}%</span>
              </div>
            </div>
          </div>
        </Card>

        {/* Memory */}
        <VitalCard
          eyebrow="Memory"
          value={state.mac.usedRamGB.toFixed(1)}
          unit={`/${state.mac.totalRamGB} GB`}
          footer={`${memPct.toFixed(0)}% in use · ${(state.mac.totalRamGB-state.mac.usedRamGB).toFixed(1)} GB free`}
          bar={memPct}
          hue="var(--accent)"
        />

        {/* Disk */}
        <VitalCard
          eyebrow="Disk"
          value={state.mac.usedDiskGB}
          unit={`/${state.mac.totalDiskGB} GB`}
          footer={`${(state.mac.totalDiskGB-state.mac.usedDiskGB)} GB free on Macintosh HD`}
          bar={diskPct}
          hue="var(--good)"
        />

        {/* Thermal / battery */}
        <Card pad={22}>
          <Eyebrow>System</Eyebrow>
          <div style={{marginTop:14, display:'flex', flexDirection:'column', gap:14}}>
            <MiniStat icon="thermo" label="Thermal" value={state.mac.thermal==='warm'?'Warm':state.mac.thermal==='hot'?'Hot':'Nominal'}
              tone={state.mac.thermal==='hot'?'danger':state.mac.thermal==='warm'?'warn':'good'}/>
            <MiniStat icon="power" label="Battery"
              value={`${state.mac.battery}% ${state.mac.charging?'· charging':''}`}
              tone={state.mac.battery<20?'danger':'neutral'}/>
            <MiniStat icon="cpu" label="Processes" value={`${procs.length} running`} tone="neutral"/>
          </div>
        </Card>
      </div>

      {/* Top consumers + suggestions preview */}
      <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit, minmax(340px, 1fr))', gap:16}}>
        <Card pad={0}>
          <div style={{padding:'18px 22px 12px', display:'flex', alignItems:'baseline', justifyContent:'space-between'}}>
            <div>
              <Eyebrow>Top consumers · right now</Eyebrow>
            </div>
            <button onClick={()=>dispatch({type:'nav', view:'processes'})}
              style={{border:'none', background:'none', color:'var(--ink-60)', fontSize:12, cursor:'pointer', fontFamily:'var(--font-ui)', fontWeight:600, display:'inline-flex', alignItems:'center', gap:4}}>
              All processes <Icon name="chevron" size={12}/>
            </button>
          </div>
          <div>
            {top.map((p,i)=>{
              const liveCpu = jitter(p.cpu, tick, p.pid);
              const mx = Math.max(...top.map(q=>q.cpu));
              return (
                <div key={p.pid} style={{display:'grid',
                  gridTemplateColumns:'16px 1fr 72px 100px 52px',
                  gap:14, alignItems:'center',
                  padding:'12px 22px',
                  borderTop:'1px solid var(--ink-5)',
                }}>
                  <span style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-40)'}}>{String(i+1).padStart(2,'0')}</span>
                  <div style={{minWidth:0}}>
                    <div style={{fontSize:13, color:'var(--ink)', fontWeight:500, whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</div>
                    <div style={{fontFamily:'var(--font-mono)', fontSize:10.5, color:'var(--ink-50)', marginTop:2}}>pid {p.pid} · {p.user}</div>
                  </div>
                  <div style={{fontFamily:'var(--font-mono)', fontSize:11, color:'var(--ink-60)', textAlign:'right'}}>{fmtMB(p.mem)}</div>
                  <Bar value={liveCpu} max={mx*1.1} hue={liveCpu>30?'var(--accent)':'var(--ink-40)'}/>
                  <div style={{fontFamily:'var(--font-hero)', fontSize:18, letterSpacing:'-0.02em',
                    color: liveCpu>30?'var(--accent-strong)':'var(--ink)', textAlign:'right', fontWeight:400}}>
                    {liveCpu.toFixed(1)}<span style={{fontSize:10, color:'var(--ink-40)'}}>%</span>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>

        <Card pad={0}>
          <div style={{padding:'18px 22px 12px', display:'flex', alignItems:'baseline', justifyContent:'space-between'}}>
            <Eyebrow>Attention</Eyebrow>
            <button onClick={()=>dispatch({type:'nav', view:'suggestions'})}
              style={{border:'none', background:'none', color:'var(--ink-60)', fontSize:12, cursor:'pointer', fontFamily:'var(--font-ui)', fontWeight:600, display:'inline-flex', alignItems:'center', gap:4}}>
              {sugs.length} suggestion{sugs.length===1?'':'s'} <Icon name="chevron" size={12}/>
            </button>
          </div>
          {sugs.length===0 && (
            <div style={{padding:'30px 22px 24px', textAlign:'center', color:'var(--ink-50)', fontSize:13}}>
              <Icon name="check" size={22} style={{margin:'0 auto 10px', color:'var(--good-strong)'}}/>
              Nothing to flag. Nice.
            </div>
          )}
          {sugs.slice(0,4).map((s,i)=>(
            <div key={s.id} style={{display:'flex', gap:12, alignItems:'flex-start', padding:'14px 22px',
              borderTop: i===0?'1px solid var(--ink-5)':'1px solid var(--ink-5)'}}>
              <div style={{width:8, height:8, borderRadius:'50%', marginTop:6,
                background: s.severity==='Critical'?'oklch(55% 0.18 28)':s.severity==='Warning'?'oklch(70% 0.14 75)':'var(--ink-40)'}}/>
              <div style={{minWidth:0, flex:1}}>
                <div style={{fontSize:13, fontWeight:600, color:'var(--ink)', lineHeight:1.35}}>{s.title}</div>
                <div style={{fontSize:12, color:'var(--ink-60)', marginTop:3, lineHeight:1.5}}>{s.detail}</div>
              </div>
            </div>
          ))}
          <div style={{display:'flex', gap:14, padding:'14px 22px', borderTop:'1px solid var(--ink-5)',
            fontFamily:'var(--font-mono)', fontSize:10.5, color:'var(--ink-50)'}}>
            <span>{crit} critical</span><span>·</span>
            <span>{warn} warning</span><span>·</span>
            <span>{info} info</span>
          </div>
        </Card>
      </div>

      <style>{`@keyframes pulse {
        0%,100% { opacity: 1; transform: scale(1); }
        50% { opacity: 0.4; transform: scale(1.4); }
      }`}</style>
    </div>
  );
}

function VitalCard({ eyebrow, value, unit, footer, bar, hue }) {
  return (
    <Card pad={22}>
      <Eyebrow>{eyebrow}</Eyebrow>
      <div style={{marginTop:16, display:'flex', alignItems:'baseline', gap:6}}>
        <div style={{fontFamily:'var(--font-hero)', fontSize:48, letterSpacing:'-0.035em',
          color:'var(--ink)', lineHeight:1, fontWeight:400}}>{value}</div>
        <div style={{fontFamily:'var(--font-mono)', fontSize:12, color:'var(--ink-50)'}}>{unit}</div>
      </div>
      <div style={{marginTop:14}}>
        <Bar value={bar} hue={hue} height={4}/>
      </div>
      <div style={{marginTop:10, fontSize:11.5, color:'var(--ink-60)', fontFamily:'var(--font-ui)'}}>{footer}</div>
    </Card>
  );
}

function MiniStat({ icon, label, value, tone }) {
  const color = tone==='good' ? 'var(--good-strong)' :
                tone==='warn' ? 'oklch(45% 0.14 75)' :
                tone==='danger' ? 'oklch(50% 0.18 28)' : 'var(--ink)';
  return (
    <div style={{display:'flex', alignItems:'center', gap:10}}>
      <div style={{width:28, height:28, borderRadius:8, background:'var(--ink-5)',
        display:'flex', alignItems:'center', justifyContent:'center', color:'var(--ink-60)'}}>
        <Icon name={icon} size={14}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase',
          color:'var(--ink-50)', fontWeight:600}}>{label}</div>
        <div style={{fontSize:13, fontWeight:600, color, marginTop:1}}>{value}</div>
      </div>
    </div>
  );
}

// ─── Processes ──────────────────────────────────────────
function ProcessesView({ state, dispatch }) {
  const tick = useLivePulse(1500);
  const [sort, setSort] = useState({ key: 'cpu', dir: -1 });
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('all'); // all | hogs | user | system
  const [selectedPid, setSelectedPid] = useState(null);

  const live = useMemo(() => state.processes.map(p => ({
    ...p,
    liveCpu: jitter(p.cpu, tick, p.pid, 0.14),
    liveMem: jitter(p.mem, tick, p.pid, 0.02),
  })), [state.processes, tick]);

  const filtered = useMemo(() => {
    let arr = live;
    if (query.trim()) {
      const q = query.toLowerCase();
      arr = arr.filter(p => p.name.toLowerCase().includes(q) || String(p.pid).includes(q));
    }
    if (filter === 'hogs') arr = arr.filter(p => p.liveCpu>20 || p.liveMem>500);
    if (filter === 'user') arr = arr.filter(p => p.user !== 'root' && p.user !== 'windowserver');
    if (filter === 'system') arr = arr.filter(p => p.user === 'root' || p.user === 'windowserver');
    const { key, dir } = sort;
    const k = key === 'cpu' ? 'liveCpu' : key === 'mem' ? 'liveMem' : key;
    arr = [...arr].sort((a,b) => {
      if (typeof a[k] === 'number') return (a[k]-b[k])*dir;
      return String(a[k]).localeCompare(String(b[k]))*dir;
    });
    return arr;
  }, [live, query, filter, sort]);

  const selected = filtered.find(p => p.pid === selectedPid);
  const header = (label, key, align='left') => (
    <button onClick={() => setSort(s => s.key===key ? {key, dir:-s.dir} : {key, dir: -1})}
      style={{border:'none', background:'none', padding:'0', cursor:'pointer',
        fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase', fontWeight:700,
        color: sort.key===key ? 'var(--ink)' : 'var(--ink-50)',
        fontFamily:'var(--font-ui)', display:'inline-flex', gap:3, alignItems:'center',
        justifyContent: align==='right'?'flex-end':'flex-start', width:'100%'}}>
      {label}
      {sort.key===key && <span style={{fontSize:9}}>{sort.dir===-1?'↓':'↑'}</span>}
    </button>
  );

  const hogCount = live.filter(p => p.liveCpu>20 || p.liveMem>500).length;

  return (
    <div style={{padding:'clamp(20px, 3vw, 32px) clamp(20px, 3vw, 36px) 40px', display:'flex', flexDirection:'column', gap:18, minHeight:'100%'}}>
      <div>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:12, flexWrap:'wrap', marginBottom:10}}>
          <div style={{fontSize:10, letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:700}}>Processes · live</div>
          <Btn variant="ghost" size="sm" onClick={()=>dispatch({type:'refresh'})}><Icon name="refresh" size={12}/>Refresh</Btn>
        </div>
        <h1 style={{fontFamily:'var(--font-hero)', fontSize:'clamp(28px, 3.4vw, 44px)', lineHeight:1.2, margin:'0 0 10px', fontWeight:400, letterSpacing:'-0.03em', textWrap:'balance'}}>
          {state.processes.length} running <span style={{color:'var(--ink-40)'}}>·</span> <span style={{color:hogCount>0?'var(--accent-strong)':'var(--good-strong)', fontStyle:'italic'}}>{hogCount} hog{hogCount===1?'':'s'}</span>
        </h1>
        <div style={{fontSize:13, color:'var(--ink-60)', maxWidth:560, lineHeight:1.5, marginBottom:14}}>
          Any process above 20% CPU or 500 MB RAM is flagged. Click a row to see what it does and what to try.
        </div>
        <div style={{display:'flex', gap:8, alignItems:'center', flexWrap:'wrap'}}>
          <div style={{position:'relative', flex:'1 1 200px', minWidth:180, maxWidth:280}}>
            <Icon name="search" size={14} style={{position:'absolute', left:10, top:'50%', transform:'translateY(-50%)', color:'var(--ink-40)'}}/>
            <input value={query} onChange={e=>setQuery(e.target.value)}
              placeholder="Filter by name or pid"
              style={{border:'1px solid var(--ink-10)', background:'var(--surface)', padding:'8px 12px 8px 32px',
                borderRadius:8, fontSize:13, fontFamily:'var(--font-ui)', color:'var(--ink)',
                width:'100%', outline:'none'}}/>
          </div>
          <div style={{display:'flex', border:'1px solid var(--ink-10)', borderRadius:8, overflow:'hidden', background:'var(--surface)'}}>
            {['all','hogs','user','system'].map(f => (
              <button key={f} onClick={()=>setFilter(f)} style={{
                border:'none', padding:'7px 12px', fontSize:12, fontWeight:600,
                background: filter===f?'var(--ink)':'transparent',
                color: filter===f?'var(--paper)':'var(--ink-60)',
                textTransform:'capitalize', cursor:'pointer', fontFamily:'var(--font-ui)'
              }}>{f}</button>
            ))}
          </div>
        </div>
      </div>

      <div style={{display:'grid', gridTemplateColumns: selected ? '1fr 320px' : '1fr', gap:16, alignItems:'start', flex:1}}>
        <Card pad={0} style={{overflow:'hidden'}}>
          <div style={{display:'grid', gridTemplateColumns:'minmax(180px, 2.2fr) 56px 74px 78px minmax(80px, 1fr) 24px',
            padding:'14px 20px', borderBottom:'1px solid var(--ink-8)', gap:12,
            background:'var(--surface-deep)'}}>
            {header('Process', 'name')}
            {header('PID', 'pid', 'right')}
            {header('Mem', 'mem', 'right')}
            {header('CPU', 'cpu', 'right')}
            <span style={{fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:700, fontFamily:'var(--font-ui)'}}>Load</span>
            <span/>
          </div>
          <div style={{maxHeight:560, overflow:'auto'}}>
            {filtered.map(p => {
              const hog = p.liveCpu>20 || p.liveMem>500;
              const isSel = p.pid===selectedPid;
              return (
                <div key={p.pid} onClick={()=>setSelectedPid(isSel?null:p.pid)}
                  style={{display:'grid', gridTemplateColumns:'minmax(180px, 2.2fr) 56px 74px 78px minmax(80px, 1fr) 24px',
                    padding:'12px 20px', borderBottom:'1px solid var(--ink-5)', gap:12,
                    alignItems:'center', cursor:'pointer',
                    background: isSel?'var(--accent-5)':'transparent',
                    transition:'background 120ms ease'}}>
                  <div style={{display:'flex', alignItems:'center', gap:10, minWidth:0}}>
                    <div style={{width:6, height:6, borderRadius:'50%',
                      background: hog?'var(--accent)':'var(--ink-20)',
                      boxShadow: hog?'0 0 0 3px var(--accent-10)':'none'}}/>
                    <span style={{fontSize:13, fontWeight:500, color:'var(--ink)', whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis'}}>{p.name}</span>
                    {hog && <Chip tone="accent" style={{padding:'1px 6px', fontSize:9}}>hog</Chip>}
                  </div>
                  <span style={{fontFamily:'var(--font-mono)', fontSize:11.5, color:'var(--ink-50)', textAlign:'right'}}>{p.pid}</span>
                  <span style={{fontFamily:'var(--font-mono)', fontSize:11.5, color:'var(--ink-60)', textAlign:'right'}}>{fmtMB(p.liveMem)}</span>
                  <span style={{fontFamily:'var(--font-hero)', fontSize:18, letterSpacing:'-0.02em', textAlign:'right',
                    color: p.liveCpu>30?'var(--accent-strong)':p.liveCpu>10?'var(--ink)':'var(--ink-60)', fontWeight:400}}>
                    {p.liveCpu.toFixed(1)}<span style={{fontSize:10, color:'var(--ink-40)'}}>%</span>
                  </span>
                  <Bar value={p.liveCpu} max={80} hue={p.liveCpu>30?'var(--accent)':'var(--ink-30)'}/>
                  <Icon name="chevron" size={12} style={{color:'var(--ink-30)',
                    transform: isSel?'rotate(90deg)':'none', transition:'transform 180ms'}}/>
                </div>
              );
            })}
            {filtered.length===0 && (
              <div style={{padding:60, textAlign:'center', color:'var(--ink-50)', fontSize:13}}>
                No processes match your filter.
              </div>
            )}
          </div>
        </Card>

        {selected && (
          <Card pad={0} style={{position:'sticky', top:16, overflow:'hidden'}}>
            <div style={{padding:'20px 22px 16px', borderBottom:'1px solid var(--ink-5)'}}>
              <div style={{display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap:8}}>
                <div style={{minWidth:0, flex:1}}>
                  <div style={{fontFamily:'var(--font-mono)', fontSize:10.5, color:'var(--ink-50)', marginBottom:4}}>pid {selected.pid} · {selected.user}</div>
                  <div style={{fontSize:17, fontWeight:600, letterSpacing:'-0.01em', color:'var(--ink)', wordBreak:'break-all', lineHeight:1.25}}>{selected.name}</div>
                </div>
                <button onClick={()=>setSelectedPid(null)} style={{border:'none', background:'var(--ink-5)', width:24, height:24, borderRadius:6, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', color:'var(--ink-60)'}}>
                  <Icon name="close" size={12}/>
                </button>
              </div>
            </div>
            <div style={{padding:'18px 22px', borderBottom:'1px solid var(--ink-5)', display:'grid', gridTemplateColumns:'1fr 1fr', gap:14}}>
              <div>
                <div style={{fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:700, marginBottom:4}}>CPU</div>
                <div style={{fontFamily:'var(--font-hero)', fontSize:32, letterSpacing:'-0.03em', color:selected.liveCpu>30?'var(--accent-strong)':'var(--ink)', fontWeight:400, lineHeight:1}}>
                  {selected.liveCpu.toFixed(1)}<span style={{fontSize:14, color:'var(--ink-40)'}}>%</span>
                </div>
              </div>
              <div>
                <div style={{fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:700, marginBottom:4}}>Memory</div>
                <div style={{fontFamily:'var(--font-hero)', fontSize:32, letterSpacing:'-0.03em', color:'var(--ink)', fontWeight:400, lineHeight:1}}>
                  {fmtMB(selected.liveMem)}
                </div>
              </div>
            </div>
            <div style={{padding:'18px 22px', borderBottom:'1px solid var(--ink-5)'}}>
              <div style={{fontSize:10, letterSpacing:'0.12em', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:700, marginBottom:6}}>What this does</div>
              <div style={{fontSize:13, color:'var(--ink-70)', lineHeight:1.55}}>{selected.note || 'No notes for this process.'}</div>
            </div>
            <div style={{padding:'16px 22px', display:'flex', gap:8}}>
              {selected.safe ? (
                <Btn variant="danger" onClick={()=>dispatch({type:'kill', pid:selected.pid})}>
                  <Icon name="kill" size={13}/>Quit process
                </Btn>
              ) : (
                <div style={{fontSize:11.5, color:'var(--ink-50)', fontStyle:'italic', lineHeight:1.5}}>
                  System process — not killable from MacOptimizer.
                </div>
              )}
              <div style={{flex:1}}/>
              <Btn variant="ghost" onClick={()=>dispatch({type:'nav', view:'suggestions'})}>
                Fix ideas
              </Btn>
            </div>
          </Card>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { DashboardView, ProcessesView });
