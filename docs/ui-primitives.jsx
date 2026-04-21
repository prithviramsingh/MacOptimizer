// Visual primitives for Mac Optimizer.
// Design language:
//   - Paper background (#F4EFE7) / graphite ink (#1A1A1C)
//   - Single accent: burnt-orange oklch(62% 0.17 35)
//   - Healthy: moss oklch(55% 0.09 150)
//   - Hero numerics in "Instrument Serif"
//   - UI in "Inter"
//   - Data in "JetBrains Mono"
// All tokens live on :root CSS vars (see index.html) so Tweaks can rewrite them.

const { useState, useEffect, useRef, useMemo, useLayoutEffect } = React;

// ─── formatters ────────────────────────────────────────────
const fmtBytes = (b) => {
  if (b < 1024) return b + ' B';
  const u = ['KB','MB','GB','TB']; let v = b/1024, i=0;
  while (v >= 1024 && i < u.length-1) { v/=1024; i++; }
  return (v>=100 ? v.toFixed(0) : v.toFixed(1)) + ' ' + u[i];
};
const fmtPct = (n) => (n >= 10 ? n.toFixed(0) : n.toFixed(1)) + '%';
const fmtMB  = (mb) => mb >= 1024 ? (mb/1024).toFixed(1)+' GB' : Math.round(mb)+' MB';
const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));
window.fmtBytes = fmtBytes; window.fmtPct = fmtPct; window.fmtMB = fmtMB;

// ─── a small set of monoline icons (stroke 1.5, 16px) ──────
const IconPaths = {
  gauge:    <><path d="M3 13a9 9 0 0118 0"/><path d="M12 13l4-4"/><circle cx="12" cy="13" r="1.2" fill="currentColor"/></>,
  cpu:      <><rect x="5" y="5" width="14" height="14" rx="2"/><rect x="8.5" y="8.5" width="7" height="7"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3"/></>,
  trash:    <><path d="M4 7h16"/><path d="M6 7l1 13a2 2 0 002 2h6a2 2 0 002-2l1-13"/><path d="M9 7V4a1 1 0 011-1h4a1 1 0 011 1v3"/></>,
  play:     <><circle cx="12" cy="12" r="9"/><path d="M10 8.5v7l6-3.5z" fill="currentColor"/></>,
  bulb:     <><path d="M9 18h6M10 21h4"/><path d="M8 14a5 5 0 118 0c-.7 1-2 2-2 4H10c0-2-1.3-3-2-4z"/></>,
  chevron:  <><path d="M9 6l6 6-6 6"/></>,
  close:    <><path d="M6 6l12 12M18 6L6 18"/></>,
  refresh:  <><path d="M3 12a9 9 0 0115-6.7L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 01-15 6.7L3 16"/><path d="M3 21v-5h5"/></>,
  search:   <><circle cx="11" cy="11" r="6"/><path d="M16 16l5 5"/></>,
  check:    <><path d="M5 12l5 5L20 7"/></>,
  bolt:     <><path d="M13 3L5 13h6l-1 8 8-10h-6l1-8z"/></>,
  thermo:   <><path d="M10 14V4a2 2 0 114 0v10a4 4 0 11-4 0z"/></>,
  disk:     <><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/></>,
  mem:      <><rect x="3" y="8" width="18" height="8" rx="1.5"/><path d="M7 11v2M11 11v2M15 11v2M19 11v2"/></>,
  dot:      <><circle cx="12" cy="12" r="3" fill="currentColor"/></>,
  kill:     <><circle cx="12" cy="12" r="9"/><path d="M8 8l8 8M16 8l-8 8"/></>,
  info:     <><circle cx="12" cy="12" r="9"/><path d="M12 8v.01M12 11v5"/></>,
  warning:  <><path d="M12 3l10 18H2L12 3z"/><path d="M12 10v4M12 17v.01" stroke="var(--paper)" /></>,
  critical: <><circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16v.01" stroke="var(--paper)"/></>,
  power:    <><path d="M12 3v8"/><path d="M6.4 7a8 8 0 1011.2 0"/></>,
  shield:   <><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3z"/></>,
  slider:   <><path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/></>,
  apple:    <><path d="M15.5 8.5c-1-.8-2.2-.5-3-.5-1-.1-2.2-.3-3 .3-1.7 1-2.7 3.2-2 5.7.3 1.2 1 2.4 1.7 3.3.6.8 1.3 1.7 2.3 1.7.9 0 1.2-.5 2.3-.5s1.4.5 2.3.5c1 0 1.7-.9 2.3-1.7.6-.8 1-1.7 1.2-2.1-.1 0-2.3-.9-2.4-3.5 0-2.1 1.8-3.1 1.9-3.1-1.2-1.6-2.7-1.8-3.6-1.8" fill="currentColor" stroke="none"/><path d="M13 5.5c.5-.7 1-1.6 1-2.5-.9 0-1.7.5-2.3 1.1-.5.6-1 1.5-.9 2.4.9 0 1.8-.4 2.2-1" fill="currentColor" stroke="none"/></>,
};
function Icon({ name, size = 16, style = {}, stroke = 1.5 }) {
  const p = IconPaths[name];
  if (!p) return null;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke="currentColor" strokeWidth={stroke}
      strokeLinecap="round" strokeLinejoin="round"
      style={{ display:'block', flexShrink:0, ...style }}>
      {p}
    </svg>
  );
}
window.Icon = Icon;

// ─── tiny button ──────────────────────────────────────────
function Btn({ children, variant='ghost', onClick, disabled, style, size='md', title }) {
  const [hover, setHover] = useState(false);
  const [down, setDown] = useState(false);
  const base = {
    display:'inline-flex', alignItems:'center', gap:8,
    fontFamily:'var(--font-ui)', fontSize: size==='sm'?12:13, fontWeight:600,
    letterSpacing: '-0.01em',
    padding: size==='sm' ? '5px 10px' : '7px 14px',
    borderRadius: 8, border:'1px solid transparent',
    cursor: disabled?'default':'pointer', userSelect:'none',
    transition:'transform 120ms ease, background 120ms ease, border-color 120ms ease',
    transform: down && !disabled ? 'translateY(1px)' : 'none',
    opacity: disabled?0.4:1, lineHeight:1,
  };
  const v = {
    primary: {
      background: hover?'var(--accent-strong)':'var(--accent)',
      color:'var(--paper)',
      borderColor: 'var(--accent-strong)',
      boxShadow: '0 1px 0 rgba(255,255,255,0.15) inset, 0 1px 2px rgba(0,0,0,0.1)',
    },
    solid: {
      background: hover?'var(--ink)':'#2a2a2d',
      color:'var(--paper)',
      borderColor:'var(--ink)',
    },
    ghost: {
      background: hover?'var(--ink-5)':'transparent',
      color:'var(--ink)',
      borderColor:'var(--ink-10)',
    },
    danger: {
      background: hover?'oklch(50% 0.18 28)':'transparent',
      color: hover?'var(--paper)':'oklch(50% 0.18 28)',
      borderColor:'oklch(50% 0.18 28 / 0.4)',
    },
    link: {
      background:'transparent', color:'var(--ink-60)',
      borderColor:'transparent', padding:0,
    }
  }[variant];
  return (
    <button title={title} disabled={disabled}
      onMouseEnter={()=>setHover(true)} onMouseLeave={()=>{setHover(false);setDown(false);}}
      onMouseDown={()=>setDown(true)} onMouseUp={()=>setDown(false)}
      onClick={disabled?undefined:onClick}
      style={{...base, ...v, ...style}}>
      {children}
    </button>
  );
}
window.Btn = Btn;

// ─── toggle (switch) ─────────────────────────────────────
function Toggle({ on, onChange, disabled }) {
  return (
    <button disabled={disabled} onClick={()=>onChange(!on)} style={{
      width: 34, height: 20, padding: 2, border:'none',
      borderRadius: 999, cursor: disabled?'default':'pointer',
      background: on ? 'var(--accent)' : 'var(--ink-15)',
      transition: 'background 160ms ease',
      position:'relative', flexShrink:0, opacity: disabled?0.4:1,
    }}>
      <span style={{
        position:'absolute', top:2, left: on?16:2,
        width:16, height:16, borderRadius:'50%', background:'var(--paper)',
        transition: 'left 180ms cubic-bezier(.3,1.3,.6,1)',
        boxShadow:'0 1px 2px rgba(0,0,0,0.25)',
      }}/>
    </button>
  );
}
window.Toggle = Toggle;

// ─── sparkline ──────────────────────────────────────
function Sparkline({ values, width=120, height=32, stroke='var(--accent)', fill='var(--accent-10)' }) {
  if (!values || values.length<2) return <svg width={width} height={height}/>;
  const max = Math.max(...values, 1);
  const min = 0;
  const stepX = width/(values.length-1);
  const pts = values.map((v,i)=>[i*stepX, height - ((v-min)/(max-min||1))*(height-2) - 1]);
  const d = pts.map((p,i)=>(i?'L':'M')+p[0].toFixed(1)+' '+p[1].toFixed(1)).join(' ');
  const area = d + ` L ${width} ${height} L 0 ${height} Z`;
  return (
    <svg width={width} height={height} style={{display:'block'}}>
      <path d={area} fill={fill} />
      <path d={d} fill="none" stroke={stroke} strokeWidth="1.5" strokeLinejoin="round"/>
      <circle cx={pts[pts.length-1][0]} cy={pts[pts.length-1][1]} r="2" fill={stroke}/>
    </svg>
  );
}
window.Sparkline = Sparkline;

// ─── bar (compact usage bar) ───────────────────────────
function Bar({ value, max=100, hue, style, height=4, track='var(--ink-8)' }) {
  const pct = clamp((value/max)*100, 0, 100);
  const color = hue || 'var(--accent)';
  return (
    <div style={{width:'100%', height, background:track, borderRadius:999, overflow:'hidden', ...style}}>
      <div style={{width:pct+'%', height:'100%', background:color, borderRadius:999,
        transition:'width 400ms cubic-bezier(.2,.8,.2,1)'}} />
    </div>
  );
}
window.Bar = Bar;

// ─── ring dial (hero readout) ────────────────────────
function Ring({ value, size=220, stroke=10, label, sub, hue='var(--accent)' }) {
  const r = (size - stroke)/2;
  const c = 2*Math.PI*r;
  const pct = clamp(value,0,100);
  const offset = c - (pct/100)*c;
  return (
    <div style={{position:'relative', width:size, height:size}}>
      <svg width={size} height={size} style={{transform:'rotate(-90deg)'}}>
        <circle cx={size/2} cy={size/2} r={r} stroke="var(--ink-8)" strokeWidth={stroke} fill="none"/>
        <circle cx={size/2} cy={size/2} r={r} stroke={hue} strokeWidth={stroke} fill="none"
          strokeDasharray={c} strokeDashoffset={offset}
          strokeLinecap="round"
          style={{transition:'stroke-dashoffset 600ms cubic-bezier(.2,.8,.2,1)'}}/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'flex', flexDirection:'column',
        alignItems:'center', justifyContent:'center', textAlign:'center'}}>
        <div style={{fontFamily:'var(--font-hero)', fontSize: size*0.36, lineHeight:1,
          color:'var(--ink)', fontWeight:400, letterSpacing:'-0.04em'}}>
          {Math.round(pct)}<span style={{fontSize:size*0.14, color:'var(--ink-50)', marginLeft:2}}>%</span>
        </div>
        {label && <div style={{marginTop:6, fontSize:10, letterSpacing:'0.12em',
          fontFamily:'var(--font-ui)', textTransform:'uppercase', color:'var(--ink-50)', fontWeight:600}}>{label}</div>}
        {sub && <div style={{marginTop:2, fontSize:11, fontFamily:'var(--font-mono)', color:'var(--ink-60)'}}>{sub}</div>}
      </div>
    </div>
  );
}
window.Ring = Ring;

// ─── section title ─────────────────────────────────
function Eyebrow({ children, right, style }) {
  return (
    <div style={{display:'flex', alignItems:'baseline', gap:10, ...style}}>
      <div style={{flex:1, fontSize:10, letterSpacing:'0.14em', textTransform:'uppercase',
        color:'var(--ink-50)', fontWeight:700, fontFamily:'var(--font-ui)'}}>{children}</div>
      {right}
    </div>
  );
}
window.Eyebrow = Eyebrow;

// ─── card ─────────────────────────────────────────
function Card({ children, style, pad=20, hoverable, onClick }) {
  const [h, setH] = useState(false);
  return (
    <div onClick={onClick}
      onMouseEnter={()=>setH(true)} onMouseLeave={()=>setH(false)}
      style={{
      background:'var(--surface)', border:'1px solid var(--ink-8)',
      borderRadius: 14, padding: pad,
      boxShadow: h&&hoverable ? '0 4px 20px rgba(0,0,0,0.06)' : '0 1px 0 rgba(0,0,0,0.02)',
      transition:'box-shadow 160ms ease, border-color 160ms ease',
      borderColor: h&&hoverable ? 'var(--ink-15)' : 'var(--ink-8)',
      cursor: onClick?'pointer':'default',
      ...style
    }}>{children}</div>
  );
}
window.Card = Card;

// ─── severity chip ─────────────────────────────
function Chip({ children, tone='neutral', style }) {
  const tones = {
    neutral:  { bg:'var(--ink-5)',    fg:'var(--ink-70)',  bd:'var(--ink-10)' },
    accent:   { bg:'var(--accent-10)',fg:'var(--accent-strong)', bd:'var(--accent-20)' },
    good:     { bg:'var(--good-10)',  fg:'var(--good-strong)',   bd:'var(--good-20)' },
    warn:     { bg:'oklch(94% 0.08 80)',  fg:'oklch(42% 0.13 75)',   bd:'oklch(82% 0.12 80)' },
    danger:   { bg:'oklch(94% 0.06 25)',  fg:'oklch(45% 0.18 28)',   bd:'oklch(80% 0.12 28)' },
  }[tone];
  return (
    <span style={{
      display:'inline-flex', alignItems:'center', gap:5,
      padding:'3px 8px', borderRadius:999,
      background: tones.bg, color: tones.fg,
      border:`1px solid ${tones.bd}`,
      fontSize:10.5, fontWeight:600, letterSpacing:'0.04em',
      textTransform:'uppercase', fontFamily:'var(--font-ui)',
      lineHeight: 1.4, whiteSpace:'nowrap',
      ...style
    }}>{children}</span>
  );
}
window.Chip = Chip;

// ─── live 1Hz pulse hook ────────────────────────
function useLivePulse(intervalMs = 1000) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(()=>setTick(t=>t+1), intervalMs);
    return ()=>clearInterval(id);
  }, [intervalMs]);
  return tick;
}
window.useLivePulse = useLivePulse;

// jitter a value a bit, deterministically per key
function jitter(v, tick, key=0, amp=0.08) {
  const x = Math.sin(tick*1.13 + key*7.3) * 0.5 + Math.sin(tick*0.37 + key*3.1) * 0.5;
  return Math.max(0, v * (1 + x*amp));
}
window.jitter = jitter;

Object.assign(window, { Btn, Toggle, Sparkline, Bar, Ring, Eyebrow, Card, Chip, Icon, fmtBytes, fmtPct, fmtMB, jitter, useLivePulse });
