// App shell, sidebar, window chrome, tweaks.
const { useState: useStateApp, useEffect: useEffectApp, useMemo: useMemoApp, useReducer } = React;

// ─── Tweaks default values ──────────────────────────
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "paper",
  "accentHue": 35,
  "density": "cozy",
  "heroFont": "Instrument Serif"
}/*EDITMODE-END*/;

// ─── Derive suggestions from live state ─────────────
function deriveSuggestions(processes, mac, cleanup) {
  const sugs = [];
  processes.forEach((p, i) => {
    if (p.cpu > 60 || p.mem > 1200) {
      sugs.push({
        id: 'crit-'+p.pid,
        title: `${p.name} is dominating the CPU`,
        detail: p.note + ' Consider quitting it to see an immediate jump in responsiveness.',
        severity: 'Critical',
        category: p.category==='browser'?'Process':p.category==='dev'?'Memory':'Process',
        actionLabel: p.safe ? 'Quit process' : null,
        metric: `${p.cpu.toFixed(0)}% CPU · ${fmtMB(p.mem)}`,
        pid: p.pid,
      });
    } else if (p.cpu > 15 || p.mem > 400) {
      sugs.push({
        id: 'warn-'+p.pid,
        title: `${p.name} is running warm`,
        detail: p.note,
        severity: 'Warning',
        category: p.category==='browser'?'Memory':p.category==='dev'?'Memory':'Process',
        actionLabel: p.safe ? 'Review' : null,
        metric: `${p.cpu.toFixed(0)}% CPU · ${fmtMB(p.mem)}`,
        pid: p.pid,
      });
    }
  });
  // disk suggestion from cleanup total
  const total = cleanup.reduce((a,c)=>a+c.bytes,0);
  if (total > 5_000_000_000) {
    sugs.push({
      id: 'disk-1',
      title: `${fmtBytes(total)} of cleanable space found`,
      detail: 'Caches, logs, Xcode DerivedData and old iOS backups are taking significant space. Run a scan from Cleanup.',
      severity: total > 30_000_000_000 ? 'Critical' : 'Warning',
      category: 'Disk',
      actionLabel: 'Open Cleanup',
      metric: fmtBytes(total),
    });
  }
  // thermal
  if (mac.thermal === 'hot') {
    sugs.push({
      id: 'therm-1',
      title: 'Your Mac is thermally throttled',
      detail: 'kernel_task is aggressively limiting CPU to cool the chassis. Move to a cooler surface and pause heavy work for 5 minutes.',
      severity: 'Critical',
      category: 'Thermal',
      actionLabel: null,
      metric: '104°F chassis',
    });
  }
  // info
  sugs.push({
    id: 'info-1',
    title: 'Chrome renderers add up',
    detail: 'Three renderer processes are currently active. ⇧Esc inside Chrome opens the built-in task manager to find the offenders.',
    severity: 'Info',
    category: 'Memory',
    actionLabel: 'See processes',
    metric: `3 renderers`,
  });
  // sort by severity
  const rank = { Critical: 0, Warning: 1, Info: 2 };
  return sugs.sort((a,b) => rank[a.severity] - rank[b.severity]).slice(0, 25);
}

// ─── Reducer ───────────────────────────────────────
function appReducer(state, action) {
  switch (action.type) {
    case 'nav':
      return { ...state, view: action.view, selectedSuggestionId: null };
    case 'kill': {
      const processes = state.processes.filter(p => p.pid !== action.pid);
      return { ...state, processes, suggestions: deriveSuggestions(processes, state.mac, state.cleanup), toast: `Process ${action.pid} quit.` };
    }
    case 'refresh': {
      // jitter cpu/mem a bit to simulate a new poll
      const processes = state.processes.map(p => ({
        ...p,
        cpu: Math.max(0, p.cpu * (0.85 + Math.random()*0.3)),
        mem: Math.max(0, p.mem * (0.95 + Math.random()*0.1)),
      }));
      return { ...state, processes, suggestions: deriveSuggestions(processes, state.mac, state.cleanup), toast: 'Processes refreshed.' };
    }
    case 'actOnSuggestion': {
      const s = state.suggestions.find(x => x.id===action.id);
      if (!s) return state;
      if (s.id === 'disk-1') return { ...state, view: 'cleanup' };
      if (s.id === 'info-1') return { ...state, view: 'processes' };
      if (s.pid) {
        const processes = state.processes.filter(p => p.pid !== s.pid);
        return { ...state, processes,
          suggestions: deriveSuggestions(processes, state.mac, state.cleanup),
          toast: `${s.title.split(' is')[0]} quit.` };
      }
      return { ...state, suggestions: state.suggestions.filter(x => x.id !== action.id) };
    }
    case 'dismissSuggestion':
      return { ...state, suggestions: state.suggestions.filter(s => s.id !== action.id) };
    case 'toast':
      return { ...state, toast: action.msg };
    case 'clearToast':
      return { ...state, toast: null };
    case 'tweak':
      return { ...state, tweaks: { ...state.tweaks, ...action.patch } };
    default:
      return state;
  }
}

function initialState(tweaks) {
  const processes = window.SEED_PROCESSES;
  const cleanup = window.SEED_CLEANUP;
  const mac = window.MAC;
  return {
    view: 'dashboard',
    processes,
    cleanup,
    startup: window.SEED_STARTUP,
    mac,
    suggestions: deriveSuggestions(processes, mac, cleanup),
    tweaks,
    toast: null,
  };
}

// ─── Sidebar ─────────────────────────────────────
const NAV = [
  { key: 'dashboard',   label: 'Dashboard',     icon: 'gauge' },
  { key: 'processes',   label: 'Processes',     icon: 'cpu' },
  { key: 'cleanup',     label: 'Cleanup',       icon: 'trash' },
  { key: 'startup',     label: 'Startup Items', icon: 'play' },
  { key: 'suggestions', label: 'Suggestions',   icon: 'bulb' },
];

function Sidebar({ state, dispatch }) {
  const { view, suggestions, processes } = state;
  const hogCount = processes.filter(p=>p.cpu>20||p.mem>500).length;
  const critCount = suggestions.filter(s=>s.severity==='Critical').length;

  const badges = {
    processes: hogCount>0 ? hogCount : null,
    suggestions: suggestions.length>0 ? suggestions.length : null,
  };

  const { mac } = state;
  const memPct = (mac.usedRamGB/mac.totalRamGB)*100;
  const diskPct = (mac.usedDiskGB/mac.totalDiskGB)*100;

  return (
    <aside style={{
      width: 232, flexShrink:0, background:'var(--sidebar)',
      borderRight:'1px solid var(--ink-8)',
      display:'flex', flexDirection:'column',
      position:'relative',
    }}>
      {/* brand placeholder */}
      <div style={{padding:'10px 20px 10px'}}>
      </div>

      {/* nav */}
      <nav style={{padding:'0 10px', display:'flex', flexDirection:'column', gap:2, flex:1}}>
        {NAV.map(n => {
          const sel = view===n.key;
          const badge = badges[n.key];
          const isCrit = n.key==='suggestions' && critCount>0;
          return (
            <button key={n.key} onClick={()=>dispatch({type:'nav', view:n.key})} style={{
              display:'flex', alignItems:'center', gap:10,
              padding:'9px 12px', borderRadius:9,
              border: 'none', textAlign:'left', cursor:'pointer',
              background: sel ? 'var(--ink)' : 'transparent',
              color: sel ? 'var(--paper)' : 'var(--ink-70)',
              fontSize: 13, fontWeight:600, letterSpacing:'-0.005em',
              fontFamily:'var(--font-ui)',
              transition:'background 140ms ease',
              position:'relative',
            }}>
              <Icon name={n.icon} size={15} stroke={1.7}/>
              <span style={{flex:1}}>{n.label}</span>
              {badge && (
                <span style={{
                  fontSize:10, fontFamily:'var(--font-mono)', fontWeight:700,
                  padding:'2px 6px', borderRadius:999,
                  background: sel ? 'var(--paper)' : isCrit?'oklch(55% 0.18 28)':'var(--accent)',
                  color: sel ? 'var(--ink)' : 'var(--paper)',
                  minWidth:18, textAlign:'center',
                }}>{badge}</span>
              )}
            </button>
          );
        })}
      </nav>

      {/* footer status */}
      <div style={{padding:'14px 18px 18px', borderTop:'1px solid var(--ink-8)', fontFamily:'var(--font-mono)'}}>
        <div style={{fontSize:9.5, color:'var(--ink-40)', fontWeight:500, marginBottom:10}}>v1.0.4</div>
        <MiniVital label="MEM" value={`${mac.usedRamGB.toFixed(1)}/${mac.totalRamGB}G`} pct={memPct}/>
        <div style={{height:10}}/>
        <MiniVital label="SSD" value={`${mac.usedDiskGB}/${mac.totalDiskGB}G`} pct={diskPct}/>
      </div>
    </aside>
  );
}

function MiniVital({ label, value, pct }) {
  return (
    <div>
      <div style={{display:'flex', justifyContent:'space-between', fontSize:10, color:'var(--ink-50)', letterSpacing:'0.1em', fontWeight:700, marginBottom:4}}>
        <span>{label}</span><span style={{color:'var(--ink-70)'}}>{value}</span>
      </div>
      <Bar value={pct} height={3} hue={pct>80?'var(--accent)':'var(--ink-40)'} track="var(--ink-8)"/>
    </div>
  );
}

// ─── Tweaks panel ───────────────────────────────
function TweaksPanel({ state, dispatch, onClose }) {
  const { tweaks } = state;
  return (
    <div style={{
      position:'absolute', right:20, bottom:20, width:300, zIndex:100,
      background:'var(--ink)', color:'var(--paper)', borderRadius:14,
      boxShadow:'0 20px 48px rgba(0,0,0,0.25), 0 0 0 1px rgba(255,255,255,0.06) inset',
      padding:18, fontFamily:'var(--font-ui)',
    }}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:14}}>
        <div style={{display:'flex', alignItems:'center', gap:8}}>
          <Icon name="slider" size={14}/>
          <div style={{fontSize:13, fontWeight:700, letterSpacing:'-0.01em'}}>Tweaks</div>
        </div>
        <button onClick={onClose} style={{background:'rgba(255,255,255,0.08)', border:'none', width:24, height:24, borderRadius:6, color:'var(--paper)', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center'}}>
          <Icon name="close" size={12}/>
        </button>
      </div>

      <TweakRow label="Theme">
        <Segmented value={tweaks.theme} options={[['paper','Paper'],['dark','Graphite']]}
          onChange={v=>dispatch({type:'tweak', patch:{theme:v}})}/>
      </TweakRow>

      <TweakRow label={`Accent · ${Math.round(tweaks.accentHue)}°`}>
        <input type="range" min="0" max="360" value={tweaks.accentHue}
          onChange={e=>dispatch({type:'tweak', patch:{accentHue: +e.target.value}})}
          style={{width:'100%', accentColor:'var(--accent)'}}/>
        <div style={{display:'flex', gap:4, marginTop:6}}>
          {[35, 20, 160, 220, 280, 320].map(h => (
            <button key={h} onClick={()=>dispatch({type:'tweak', patch:{accentHue:h}})}
              style={{width:22, height:22, borderRadius:'50%', border: tweaks.accentHue===h?'2px solid var(--paper)':'2px solid transparent',
                background:`oklch(62% 0.17 ${h})`, cursor:'pointer', padding:0}}/>
          ))}
        </div>
      </TweakRow>

      <TweakRow label="Density">
        <Segmented value={tweaks.density} options={[['comfortable','Comfy'],['cozy','Cozy'],['compact','Dense']]}
          onChange={v=>dispatch({type:'tweak', patch:{density:v}})}/>
      </TweakRow>

      <TweakRow label="Display face">
        <Segmented value={tweaks.heroFont} options={[
          ['Instrument Serif','Serif'],
          ['Space Grotesk','Grotesk'],
          ['JetBrains Mono','Mono'],
        ]}
          onChange={v=>dispatch({type:'tweak', patch:{heroFont:v}})}/>
      </TweakRow>

      <div style={{marginTop:6, fontSize:11, color:'rgba(255,255,255,0.45)', lineHeight:1.4}}>
        Try different hues — the whole app retints. Dark mode swaps paper for graphite.
      </div>
    </div>
  );
}

function TweakRow({ label, children }) {
  return (
    <div style={{marginBottom:14}}>
      <div style={{fontSize:10, letterSpacing:'0.14em', textTransform:'uppercase', opacity:0.55, fontWeight:700, marginBottom:7}}>{label}</div>
      {children}
    </div>
  );
}

function Segmented({ value, options, onChange }) {
  return (
    <div style={{display:'flex', background:'rgba(255,255,255,0.06)', padding:3, borderRadius:7}}>
      {options.map(([v,l])=>(
        <button key={v} onClick={()=>onChange(v)} style={{
          flex:1, border:'none', padding:'6px 8px', borderRadius:5, cursor:'pointer',
          background: value===v?'var(--paper)':'transparent',
          color: value===v?'var(--ink)':'rgba(255,255,255,0.7)',
          fontSize:11.5, fontWeight:600, fontFamily:'var(--font-ui)',
          transition:'all 140ms ease',
        }}>{l}</button>
      ))}
    </div>
  );
}

// ─── Apply tweaks to :root ────────────────────────
function applyTweaks(tweaks) {
  const root = document.documentElement;
  const h = tweaks.accentHue;
  root.style.setProperty('--accent',        `oklch(62% 0.17 ${h})`);
  root.style.setProperty('--accent-strong', `oklch(48% 0.17 ${h})`);
  root.style.setProperty('--accent-5',      `oklch(96% 0.03 ${h})`);
  root.style.setProperty('--accent-10',     `oklch(92% 0.06 ${h})`);
  root.style.setProperty('--accent-20',     `oklch(85% 0.10 ${h})`);

  if (tweaks.theme === 'dark') {
    root.style.setProperty('--paper',       '#1a1b1c');
    root.style.setProperty('--surface',     '#232426');
    root.style.setProperty('--surface-deep','#1e1f21');
    root.style.setProperty('--sidebar',     '#17181a');
    root.style.setProperty('--ink',         '#f0ebe2');
    root.style.setProperty('--ink-5',       'rgba(240,235,226,0.05)');
    root.style.setProperty('--ink-8',       'rgba(240,235,226,0.08)');
    root.style.setProperty('--ink-10',      'rgba(240,235,226,0.12)');
    root.style.setProperty('--ink-15',      'rgba(240,235,226,0.18)');
    root.style.setProperty('--ink-20',      'rgba(240,235,226,0.24)');
    root.style.setProperty('--ink-30',      'rgba(240,235,226,0.34)');
    root.style.setProperty('--ink-40',      'rgba(240,235,226,0.42)');
    root.style.setProperty('--ink-50',      'rgba(240,235,226,0.52)');
    root.style.setProperty('--ink-60',      'rgba(240,235,226,0.64)');
    root.style.setProperty('--ink-70',      'rgba(240,235,226,0.76)');
  } else {
    root.style.setProperty('--paper',       '#F4EFE7');
    root.style.setProperty('--surface',     '#FBF8F2');
    root.style.setProperty('--surface-deep','#EEE8DD');
    root.style.setProperty('--sidebar',     '#EDE7DB');
    root.style.setProperty('--ink',         '#1A1A1C');
    root.style.setProperty('--ink-5',       'rgba(26,26,28,0.04)');
    root.style.setProperty('--ink-8',       'rgba(26,26,28,0.08)');
    root.style.setProperty('--ink-10',      'rgba(26,26,28,0.10)');
    root.style.setProperty('--ink-15',      'rgba(26,26,28,0.15)');
    root.style.setProperty('--ink-20',      'rgba(26,26,28,0.20)');
    root.style.setProperty('--ink-30',      'rgba(26,26,28,0.30)');
    root.style.setProperty('--ink-40',      'rgba(26,26,28,0.40)');
    root.style.setProperty('--ink-50',      'rgba(26,26,28,0.50)');
    root.style.setProperty('--ink-60',      'rgba(26,26,28,0.60)');
    root.style.setProperty('--ink-70',      'rgba(26,26,28,0.74)');
  }
  root.style.setProperty('--good',        'oklch(55% 0.09 150)');
  root.style.setProperty('--good-strong', 'oklch(40% 0.09 150)');
  root.style.setProperty('--good-10',     'oklch(92% 0.04 150)');
  root.style.setProperty('--good-20',     'oklch(85% 0.07 150)');

  const heroFontMap = {
    'Instrument Serif': '"Instrument Serif", Georgia, serif',
    'Space Grotesk':    '"Space Grotesk", "Inter", system-ui, sans-serif',
    'JetBrains Mono':   '"JetBrains Mono", ui-monospace, monospace',
  };
  root.style.setProperty('--font-hero', heroFontMap[tweaks.heroFont] || heroFontMap['Instrument Serif']);
  root.style.setProperty('--font-ui',   '"Inter", system-ui, -apple-system, sans-serif');
  root.style.setProperty('--font-mono', '"JetBrains Mono", ui-monospace, SFMono-Regular, monospace');
}

// ─── Toast ──────────────────────────────────
function Toast({ msg, onDone }) {
  useEffect(() => {
    if (!msg) return;
    const id = setTimeout(onDone, 2400);
    return () => clearTimeout(id);
  }, [msg]);
  if (!msg) return null;
  return (
    <div style={{
      position:'absolute', bottom:22, left:'50%', transform:'translateX(-50%)',
      background:'var(--ink)', color:'var(--paper)',
      padding:'10px 18px', borderRadius:999, fontSize:13, fontWeight:600,
      boxShadow:'0 10px 30px rgba(0,0,0,0.25)', zIndex:80,
      display:'inline-flex', alignItems:'center', gap:10,
      fontFamily:'var(--font-ui)',
      animation:'toastIn 240ms cubic-bezier(.2,1,.3,1)',
    }}>
      <Icon name="check" size={13}/>{msg}
      <style>{`@keyframes toastIn {
        from { opacity:0; transform: translate(-50%, 10px); }
        to { opacity:1; transform: translate(-50%, 0); }
      }`}</style>
    </div>
  );
}

// ─── App ────────────────────────────────────
function App() {
  const [state, dispatch] = useReducer(appReducer, null, () => initialState(TWEAK_DEFAULTS));
  const [showTweaks, setShowTweaks] = useState(false);

  useEffect(() => { applyTweaks(state.tweaks); }, [state.tweaks]);

  // Edit-mode protocol
  useEffect(() => {
    const handler = (e) => {
      if (!e.data || typeof e.data !== 'object') return;
      if (e.data.type === '__activate_edit_mode') setShowTweaks(true);
      if (e.data.type === '__deactivate_edit_mode') setShowTweaks(false);
    };
    window.addEventListener('message', handler);
    window.parent.postMessage({ type: '__edit_mode_available' }, '*');
    return () => window.removeEventListener('message', handler);
  }, []);

  // persist tweaks to host
  const firstRun = React.useRef(true);
  useEffect(() => {
    if (firstRun.current) { firstRun.current=false; return; }
    window.parent.postMessage({type:'__edit_mode_set_keys', edits: state.tweaks}, '*');
  }, [state.tweaks]);

  // restore last view
  useEffect(() => {
    const saved = localStorage.getItem('macopt-view');
    if (saved) dispatch({type:'nav', view: saved});
  }, []);
  useEffect(() => { localStorage.setItem('macopt-view', state.view); }, [state.view]);

  const densityPad = {
    comfortable: 40, cozy: 28, compact: 18,
  }[state.tweaks.density] || 28;

  const titleMap = {
    dashboard: 'Dashboard',
    processes: 'Processes',
    cleanup: 'Cleanup',
    startup: 'Startup Items',
    suggestions: 'Suggestions',
  };

  return (
    <div style={{minHeight:'100vh', background:'var(--paper)', color:'var(--ink)',
      display:'flex', alignItems:'center', justifyContent:'center', padding:'min(4vw, 32px)',
      fontFamily:'var(--font-ui)'}}>
      <div data-screen-label="MacOptimizer" style={{
        width: 'min(1320px, 100%)', height: 'min(860px, calc(100vh - 40px))',
        minHeight: 560,
        borderRadius: 18, overflow:'hidden',
        background:'var(--paper)',
        display:'flex', position:'relative',
        boxShadow:'0 1px 0 rgba(0,0,0,0.04), 0 30px 80px -20px rgba(0,0,0,0.35), 0 0 0 1px rgba(0,0,0,0.08)',
      }}>
        <Sidebar state={state} dispatch={dispatch}/>

        <main style={{flex:1, display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
          {/* toolbar */}
          <div style={{
            height:38, flexShrink:0, display:'flex', alignItems:'center',
            padding:'0 20px', borderBottom:'1px solid var(--ink-8)',
            background:'var(--paper)', gap:12,
          }}>
            <div style={{fontSize:12.5, fontWeight:600, color:'var(--ink)', fontFamily:'var(--font-ui)'}}>{titleMap[state.view]}</div>
            <div style={{flex:1}}/>
            <button onClick={()=>setShowTweaks(v=>!v)} style={{
              border:'1px solid var(--ink-10)', background:'var(--surface)',
              padding:'5px 12px', borderRadius:7, cursor:'pointer',
              fontSize:11.5, fontWeight:600, color:'var(--ink-70)',
              display:'inline-flex', alignItems:'center', gap:6, fontFamily:'var(--font-ui)',
            }}>
              <Icon name="slider" size={12}/>Tweaks
            </button>
          </div>

          <div style={{flex:1, overflow:'auto', background:'var(--paper)'}}>
            {state.view==='dashboard' && <DashboardView state={state} dispatch={dispatch}/>}
            {state.view==='processes' && <ProcessesView state={state} dispatch={dispatch}/>}
            {state.view==='cleanup' && <CleanupView state={state} dispatch={dispatch}/>}
            {state.view==='startup' && <StartupView state={state} dispatch={dispatch}/>}
            {state.view==='suggestions' && <SuggestionsView state={state} dispatch={dispatch}/>}
          </div>

          {showTweaks && <TweaksPanel state={state} dispatch={dispatch} onClose={()=>setShowTweaks(false)}/>}
          <Toast msg={state.toast} onDone={()=>dispatch({type:'clearToast'})}/>
        </main>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
