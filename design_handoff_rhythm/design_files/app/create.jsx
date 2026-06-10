// create.jsx — create/edit cadence (3 form variants), quick beat, discovery, convert
// Exports: CreateCadenceSheet, CreateBeatSheet, CreateDiscoverySheet, ConvertDiscoverySheet, AddMenu

const CR = window.RhythmData;
const COLORS = ['#5E5CE6', '#34C759', '#FF9500', '#FF2D55', '#0A84FF', '#AF52DE', '#FFCC00', '#30D158', '#64D2FF', '#A2845E', '#FF6B35', '#8E8E93'];

const daysToNU = CR.daysToNU;
const nuToDays = CR.nuToDays;

const pickLastEmoji = (s) => {
  if (!s) return '';
  try {
    const seg = [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(s)];
    return seg.length ? seg[seg.length - 1].segment : s;
  } catch (e) { return [...s].slice(-2).join('') || s; }
};

function GlyphColorPicker({ color, glyph, onColor, onGlyph }) {
  const t = useTheme();
  const inputRef = React.useRef(null);
  return (
    <div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '16px 0 4px' }}>
        <button onClick={() => inputRef.current && inputRef.current.focus()} style={{
          width: 78, height: 78, borderRadius: 22, background: color, border: 'none', cursor: 'pointer', padding: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative',
          boxShadow: `0 3px 10px ${hexA(color, 0.4)}`,
        }}>
          <input ref={inputRef} value={glyph}
            onChange={e => onGlyph(pickLastEmoji(e.target.value) || glyph)}
            inputMode="text" aria-label="Emoji"
            style={{ width: '100%', height: '100%', border: 'none', outline: 'none', background: 'transparent',
              textAlign: 'center', fontSize: 42, lineHeight: 1, caretColor: 'rgba(255,255,255,0.7)', cursor: 'pointer' }} />
        </button>
        <div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, marginTop: 8 }}>Tap to pick an emoji</div>
      </div>
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', justifyContent: 'center', padding: '10px 16px 4px' }}>
        {COLORS.map(c => (
          <button key={c} onClick={() => onColor(c)} style={{
            width: 30, height: 30, borderRadius: 30, background: c, border: 'none', cursor: 'pointer',
            boxShadow: color === c ? `0 0 0 2.5px ${t.card}, 0 0 0 4.5px ${c}` : 'none',
          }} />
        ))}
      </div>
    </div>
  );
}

function FreqPicker({ n, unit, onN, onUnit }) {
  const t = useTheme();
  const days = nuToDays(n, unit);
  const grace = CR.graceFromFrequency(days);
  const presets = [{ l: 'Daily', d: 1 }, { l: 'Weekly', d: 7 }, { l: 'Monthly', d: 30 }, { l: 'Yearly', d: 365 }];
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, padding: '4px 0 14px' }}>
        {presets.map(p => {
          const on = days === p.d;
          return <button key={p.l} onClick={() => { const nu = daysToNU(p.d); onN(nu.n); onUnit(nu.unit); }} style={{
            flex: 1, border: 'none', borderRadius: 9, cursor: 'pointer', padding: '8px 4px',
            background: on ? t.accent : t.fill, color: on ? '#fff' : t.label, fontFamily: SF, fontSize: 13.5, fontWeight: 600,
          }}>{p.l}</button>;
        })}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, justifyContent: 'center', padding: '4px 0' }}>
        <span style={{ fontFamily: SF, fontSize: 16, color: t.label2 }}>Every</span>
        <Stepper value={n} min={1} onDec={() => onN(Math.max(1, n - 1))} onInc={() => onN(n + 1)} />
        <span style={{ fontFamily: SF, fontSize: 26, fontWeight: 700, color: t.label, minWidth: 30, textAlign: 'center' }}>{n}</span>
        <div style={{ width: 178 }}>
          <Segmented small options={[{ value: 'days', label: 'days' }, { value: 'weeks', label: 'wks' }, { value: 'months', label: 'mos' }, { value: 'years', label: 'yrs' }]} value={unit} onChange={onUnit} />
        </div>
      </div>
      <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 13.5, color: t.label2, padding: '12px 16px 2px' }}>
        Suggested grace period: <b style={{ color: t.accent, fontWeight: 600 }}>{grace} {grace === 1 ? 'day' : 'days'}</b>
      </div>
    </div>
  );
}

function SchedCards({ value, onChange }) {
  const t = useTheme();
  const opts = [
    { v: 'completion', title: 'Relative', desc: 'Counts from when you finish. Best for mowing, haircuts — things that drift.', icon: 'check' },
    { v: 'dueDate', title: 'Fixed', desc: 'Hard schedule regardless of completion. Best for bills, trash day.', icon: 'calendar' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {opts.map(o => {
        const on = value === o.v;
        return (
          <button key={o.v} onClick={() => onChange(o.v)} style={{
            textAlign: 'left', border: `2px solid ${on ? t.accent : 'transparent'}`, cursor: 'pointer',
            background: t.card, borderRadius: 14, padding: '14px 15px', display: 'flex', gap: 13, alignItems: 'flex-start',
          }}>
            <div style={{ width: 38, height: 38, borderRadius: 11, background: on ? t.accent : t.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Icon name={o.icon} size={21} strokeWidth={2.2} color={on ? '#fff' : t.label2} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: SF, fontSize: 16.5, fontWeight: 600, color: t.label }}>{o.title}</div>
              <div style={{ fontFamily: SF, fontSize: 13, color: t.label2, marginTop: 3, lineHeight: '18px' }}>{o.desc}</div>
            </div>
            <div style={{ width: 22, height: 22, borderRadius: 22, border: `2px solid ${on ? t.accent : t.label3}`, background: on ? t.accent : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 2 }}>
              {on && <Icon name="check" size={13} strokeWidth={3} color="#fff" />}
            </div>
          </button>
        );
      })}
    </div>
  );
}

function buildDraft(initial) {
  const init = initial || {};
  const every = init.every || daysToNU(init.freq || 7);
  const freqDays = nuToDays(every.n, every.unit);
  const firstDue = init.firstDue || (init.beat && init.beat.due) || CR.dateFromOffset(Math.min(freqDays, 14));
  return {
    name: init.name || '', color: init.color || '#5E5CE6', glyph: init.glyph || '🔁',
    schedule: init.schedule || 'completion', n: every.n, unit: every.unit,
    grace: init.grace != null ? init.grace : CR.graceFromFrequency(freqDays), graceTouched: !!initial,
    firstDue,
    notify: init.notify || { almost: false, due: true, overdue: true, time: '9:00 AM' }, desc: init.desc || '',
  };
}
function useCadenceDraft(initial, seedKey) {
  const [d, setD] = useState(() => buildDraft(initial));
  useEffect(() => { setD(buildDraft(initial)); }, [seedKey]);
  const set = (p) => setD(prev => {
    const next = { ...prev, ...p };
    if (('n' in p || 'unit' in p) && !next.graceTouched) next.grace = CR.graceFromFrequency(nuToDays(next.n, next.unit));
    return next;
  });
  const build = () => {
    const freq = nuToDays(d.n, d.unit);
    return { name: d.name.trim() || 'Untitled', color: d.color, glyph: d.glyph, schedule: d.schedule,
      every: { n: d.n, unit: d.unit }, freq, grace: d.grace, notify: d.notify, desc: d.desc, firstDue: d.firstDue };
  };
  return [d, set, build];
}

// ── single-page form ──
function FormSingle({ d, set }) {
  const t = useTheme();
  const [showCal, setShowCal] = useState(false);
  return (
    <div>
      <Section first>
        <GlyphColorPicker color={d.color} glyph={d.glyph} onColor={c => set({ color: c })} onGlyph={g => set({ glyph: g })} />
        <div style={{ height: 0.5, background: t.sep, margin: '6px 16px 0' }} />
        <input value={d.name} onChange={e => set({ name: e.target.value })} placeholder="Cadence name"
          style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 17, color: t.label, padding: '13px 16px', boxSizing: 'border-box' }} />
      </Section>
      <Section header="Scheduling"><div style={{ padding: '12px 12px' }}><SchedCards value={d.schedule} onChange={v => set({ schedule: v })} /></div></Section>
      <Section header="Frequency"><div style={{ padding: '4px 16px 14px' }}><FreqPicker n={d.n} unit={d.unit} onN={v => set({ n: v })} onUnit={v => set({ unit: v })} /></div></Section>
      <Section header="Grace period" footer="How early a beat lands on your radar — and its snooze length.">
        <EditRow label="Grace period" last>
          <span style={{ fontFamily: SF, fontSize: 17, color: t.label2, marginRight: 4 }}>{d.grace} {d.grace === 1 ? 'day' : 'days'}</span>
          <Stepper value={d.grace} min={0} onDec={() => set({ grace: Math.max(0, d.grace - 1), graceTouched: true })} onInc={() => set({ grace: d.grace + 1, graceTouched: true })} />
        </EditRow>
      </Section>
      <Section header="First beat due">
        <EditRow label="Due" last onClick={() => setShowCal(s => !s)}
          sub={showCal && <div style={{ paddingBottom: 6 }}><MiniCalendar value={d.firstDue} onChange={dt => set({ firstDue: dt })} /></div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: showCal ? t.accent : t.label2 }}>{CR.fmtDate(d.firstDue, { absolute: true })}</span>
        </EditRow>
      </Section>
      <Section header="Notifications">
        <EditRow label="Almost due"><Switch on={d.notify.almost} onChange={v => set({ notify: { ...d.notify, almost: v } })} color={t.accent} /></EditRow>
        <EditRow label="Due"><Switch on={d.notify.due} onChange={v => set({ notify: { ...d.notify, due: v } })} color={t.accent} /></EditRow>
        <EditRow label="Overdue" last><Switch on={d.notify.overdue} onChange={v => set({ notify: { ...d.notify, overdue: v } })} color={t.accent} /></EditRow>
      </Section>
    </div>
  );
}

// ── card-style form ──
function FormCards({ d, set }) {
  const t = useTheme();
  const [showCal, setShowCal] = useState(false);
  const days = nuToDays(d.n, d.unit);
  return (
    <div style={{ padding: '4px 16px' }}>
      <div style={{ background: t.card, borderRadius: 18, padding: '6px 8px 16px', marginTop: 14 }}>
        <GlyphColorPicker color={d.color} glyph={d.glyph} onColor={c => set({ color: c })} onGlyph={g => set({ glyph: g })} />
        <input value={d.name} onChange={e => set({ name: e.target.value })} placeholder="Name this cadence" style={{
          width: '90%', border: 'none', outline: 'none', background: 'transparent', textAlign: 'center', margin: '4px auto 0', display: 'block',
          fontFamily: SF, fontSize: 22, fontWeight: 700, color: t.label, letterSpacing: -0.3,
        }} />
      </div>
      <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: t.label2, textTransform: 'uppercase', letterSpacing: 0.3, margin: '24px 4px 10px' }}>How is it scheduled?</div>
      <SchedCards value={d.schedule} onChange={v => set({ schedule: v })} />
      <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: t.label2, textTransform: 'uppercase', letterSpacing: 0.3, margin: '24px 4px 10px' }}>How often?</div>
      <div style={{ background: t.card, borderRadius: 18, padding: '16px 16px 18px' }}>
        <FreqPicker n={d.n} unit={d.unit} onN={v => set({ n: v })} onUnit={v => set({ unit: v })} />
        <div style={{ height: 0.5, background: t.sep, margin: '14px 0' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontFamily: SF, fontSize: 16, color: t.label }}>Grace period</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontFamily: SF, fontSize: 16, color: t.label2 }}>{d.grace}d</span>
            <Stepper value={d.grace} min={0} onDec={() => set({ grace: Math.max(0, d.grace - 1), graceTouched: true })} onInc={() => set({ grace: d.grace + 1, graceTouched: true })} />
          </div>
        </div>
      </div>
      <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: t.label2, textTransform: 'uppercase', letterSpacing: 0.3, margin: '24px 4px 10px' }}>First beat due</div>
      <div style={{ background: t.card, borderRadius: 18, overflow: 'hidden' }}>
        <EditRow label="Due date" last onClick={() => setShowCal(s => !s)}
          sub={showCal && <div style={{ paddingBottom: 6 }}><MiniCalendar value={d.firstDue} onChange={dt => set({ firstDue: dt })} /></div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: t.accent }}>{CR.fmtDate(d.firstDue, { absolute: true })}</span>
        </EditRow>
      </div>
      <div style={{ height: 8 }} />
    </div>
  );
}

// ── wizard form ──
const WIZ_STEPS = ['Name', 'Schedule', 'Frequency', 'Timing', 'Alerts'];
function FormWizard({ d, set, step, setStep }) {
  const t = useTheme();
  const [showCal, setShowCal] = useState(false);
  const pct = (step + 1) / WIZ_STEPS.length;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ padding: '14px 20px 6px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: t.accent }}>Step {step + 1} of {WIZ_STEPS.length}</span>
          <span style={{ fontFamily: SF, fontSize: 13, color: t.label2 }}>{WIZ_STEPS[step]}</span>
        </div>
        <div style={{ height: 5, borderRadius: 5, background: t.fill, overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: t.accent, borderRadius: 5, transition: 'width .3s' }} />
        </div>
      </div>
      <div style={{ flex: 1, padding: '8px 4px 0' }}>
        {step === 0 && <div>
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 20, fontWeight: 700, color: t.label, margin: '14px 0 2px' }}>What recurs?</div>
          <GlyphColorPicker color={d.color} glyph={d.glyph} onColor={c => set({ color: c })} onGlyph={g => set({ glyph: g })} />
          <div style={{ padding: '6px 16px' }}>
            <div style={{ background: t.card, borderRadius: 12 }}>
              <input value={d.name} onChange={e => set({ name: e.target.value })} placeholder="Cadence name" autoFocus
                style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 17, color: t.label, padding: '13px 16px', boxSizing: 'border-box', textAlign: 'center' }} />
            </div>
          </div>
        </div>}
        {step === 1 && <div style={{ padding: '0 16px' }}>
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 20, fontWeight: 700, color: t.label, margin: '14px 0 18px' }}>How is it scheduled?</div>
          <SchedCards value={d.schedule} onChange={v => set({ schedule: v })} />
        </div>}
        {step === 2 && <div style={{ padding: '0 20px' }}>
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 20, fontWeight: 700, color: t.label, margin: '14px 0 18px' }}>How often?</div>
          <FreqPicker n={d.n} unit={d.unit} onN={v => set({ n: v })} onUnit={v => set({ unit: v })} />
        </div>}
        {step === 3 && <div style={{ padding: '0 16px' }}>
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 20, fontWeight: 700, color: t.label, margin: '14px 0 18px' }}>Timing</div>
          <div style={{ background: t.card, borderRadius: 12, overflow: 'hidden', marginBottom: 16 }}>
            <EditRow label="Grace period"
              sub={<div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, padding: '0 0 9px' }}>When a beat lands on your radar, and its snooze length.</div>}>
              <span style={{ fontFamily: SF, fontSize: 17, color: t.label2, marginRight: 4 }}>{d.grace}d</span>
              <Stepper value={d.grace} min={0} onDec={() => set({ grace: Math.max(0, d.grace - 1), graceTouched: true })} onInc={() => set({ grace: d.grace + 1, graceTouched: true })} />
            </EditRow>
            <EditRow label="First beat due" last onClick={() => setShowCal(s => !s)}
              sub={showCal && <div style={{ paddingBottom: 6 }}><MiniCalendar value={d.firstDue} onChange={dt => set({ firstDue: dt })} /></div>}>
              <span style={{ fontFamily: SF, fontSize: 17, color: showCal ? t.accent : t.label2 }}>{CR.fmtDate(d.firstDue, { absolute: true })}</span>
            </EditRow>
          </div>
        </div>}
        {step === 4 && <div style={{ padding: '0 16px' }}>
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 20, fontWeight: 700, color: t.label, margin: '14px 0 18px' }}>When should we nudge you?</div>
          <div style={{ background: t.card, borderRadius: 12, overflow: 'hidden' }}>
            <EditRow label="Almost due"><Switch on={d.notify.almost} onChange={v => set({ notify: { ...d.notify, almost: v } })} color={t.accent} /></EditRow>
            <EditRow label="Due"><Switch on={d.notify.due} onChange={v => set({ notify: { ...d.notify, due: v } })} color={t.accent} /></EditRow>
            <EditRow label="Overdue" last><Switch on={d.notify.overdue} onChange={v => set({ notify: { ...d.notify, overdue: v } })} color={t.accent} /></EditRow>
          </div>
        </div>}
      </div>
    </div>
  );
}

function CreateCadenceSheet({ open, mode, initial, onClose, onSubmit }) {
  const t = useTheme();
  const [resetKey, setResetKey] = useState(0);
  const [d, set, build] = useCadenceDraft(initial, resetKey);
  const [step, setStep] = useState(0);
  useEffect(() => { if (open) { setStep(0); setResetKey(k => k + 1); } }, [open]);
  const editing = mode === 'edit';
  const isWizard = (mode || 'single') === 'wizard' && !editing;
  const lastStep = step === WIZ_STEPS.length - 1;

  const right = isWizard
    ? (lastStep ? <NavBtn bold onClick={() => { onSubmit(build(), editing); onClose(); }}>{editing ? 'Save' : 'Add'}</NavBtn>
      : <NavBtn bold onClick={() => setStep(s => s + 1)}>Next</NavBtn>)
    : <NavBtn bold onClick={() => { onSubmit(build(), editing); onClose(); }} disabled={!d.name.trim()}>{editing ? 'Save' : 'Add'}</NavBtn>;
  const left = isWizard && step > 0 ? <NavBtn onClick={() => setStep(s => s - 1)}>Back</NavBtn> : <NavBtn onClick={onClose}>Cancel</NavBtn>;

  return (
    <Sheet open={open} onClose={onClose} height="94%" maxHeight="94%"
      title={editing ? 'Edit cadence' : 'New cadence'} leftAction={left} rightAction={right}>
      <div key={resetKey} style={{ height: isWizard ? '100%' : 'auto' }}>
        {isWizard ? <FormWizard d={d} set={set} step={step} setStep={setStep} />
          : (mode === 'cards' || (editing && initial && initial.__formStyle === 'cards')) ? <FormCards d={d} set={set} />
            : <FormSingle d={d} set={set} />}
      </div>
    </Sheet>
  );
}

function CreateBeatSheet({ open, onClose, onSubmit }) {
  const t = useTheme();
  const [d, setD] = useState(null);
  const [showCal, setShowCal] = useState(false);
  useEffect(() => {
    if (open) { setShowCal(false); setD({ name: '', color: '#0A84FF', glyph: '🚩', due: CR.dateFromOffset(7), grace: CR.graceFromFrequency(7), graceTouched: false }); }
  }, [open]);
  if (!d) return null;
  const set = (p) => setD(prev => {
    const next = { ...prev, ...p };
    if ('due' in p && !next.graceTouched) next.grace = CR.graceFromFrequency(Math.max(1, CR.daysBetween(CR.TODAY, next.due)));
    return next;
  });
  return (
    <Sheet open={open} onClose={onClose} height="90%" maxHeight="90%" title="Quick beat"
      rightAction={<NavBtn bold disabled={!d.name.trim()} onClick={() => { onSubmit(d); onClose(); }}>Add</NavBtn>}>
      <Section first>
        <GlyphColorPicker color={d.color} glyph={d.glyph} onColor={c => set({ color: c })} onGlyph={g => set({ glyph: g })} />
        <div style={{ height: 0.5, background: t.sep, margin: '6px 16px 0' }} />
        <input value={d.name} onChange={e => set({ name: e.target.value })} placeholder="What needs doing?"
          style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 17, color: t.label, padding: '13px 16px', boxSizing: 'border-box' }} />
      </Section>
      <Section header="Due" footer="A standalone beat isn’t tied to a cadence, so set its grace period yourself.">
        <EditRow label="Due date" onClick={() => setShowCal(s => !s)}
          sub={showCal && <div style={{ paddingBottom: 6 }}><MiniCalendar value={d.due} onChange={dt => set({ due: dt })} /></div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: showCal ? t.accent : t.label2 }}>{CR.fmtDate(d.due, { absolute: true })}</span>
        </EditRow>
        <EditRow label="Grace period" last>
          <span style={{ fontFamily: SF, fontSize: 17, color: t.label2, marginRight: 4 }}>{d.grace}d</span>
          <Stepper value={d.grace} min={0} onDec={() => set({ grace: Math.max(0, d.grace - 1), graceTouched: true })} onInc={() => set({ grace: d.grace + 1, graceTouched: true })} />
        </EditRow>
      </Section>
      <div style={{ height: 16 }} />
    </Sheet>
  );
}

function CreateDiscoverySheet({ open, onClose, onSubmit }) {
  const t = useTheme();
  const [d, setD] = useState(null);
  const [logToday, setLogToday] = useState(true);
  useEffect(() => { if (open) { setLogToday(true); setD({ name: '', color: '#64D2FF', glyph: '🎯' }); } }, [open]);
  if (!d) return null;
  return (
    <Sheet open={open} onClose={onClose} height="86%" maxHeight="86%" title="Start a discovery"
      rightAction={<NavBtn bold disabled={!d.name.trim()} onClick={() => { onSubmit(d, logToday); onClose(); }}>Start</NavBtn>}>
      <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, padding: '14px 20px 0', lineHeight: '19px' }}>
        For things you do on no known schedule. Log it twice and Rhythm suggests a frequency.
      </div>
      <Section first>
        <GlyphColorPicker color={d.color} glyph={d.glyph} onColor={c => setD({ ...d, color: c })} onGlyph={g => setD({ ...d, glyph: g })} />
        <div style={{ height: 0.5, background: t.sep, margin: '6px 16px 0' }} />
        <input value={d.name} onChange={e => setD({ ...d, name: e.target.value })} placeholder="e.g. Change fridge water filter"
          style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 17, color: t.label, padding: '13px 16px', boxSizing: 'border-box' }} />
      </Section>
      <Section footer="You can also start with zero and log the first occurrence next time you do it.">
        <EditRow label="Log first occurrence" last><Switch on={logToday} onChange={setLogToday} color={t.accent} /></EditRow>
      </Section>
      <div style={{ height: 16 }} />
    </Sheet>
  );
}

function ConvertDiscoverySheet({ open, disc, suggested, onClose, onSubmit }) {
  const t = useTheme();
  const nu = daysToNU(suggested || 30);
  const [d, setD] = useState(null);
  useEffect(() => { if (open && disc) setD({ name: disc.name, color: disc.color, glyph: disc.glyph, schedule: 'completion', n: nu.n, unit: nu.unit, grace: CR.graceFromFrequency(suggested || 30) }); }, [open, disc && disc.id]);
  if (!disc || !d) return null;
  const freq = nuToDays(d.n, d.unit);
  return (
    <Sheet open={open} onClose={onClose} height="90%" maxHeight="90%" title="Convert to cadence"
      rightAction={<NavBtn bold onClick={() => { onSubmit(disc, { name: d.name.trim() || disc.name, color: d.color, glyph: d.glyph, schedule: d.schedule, every: { n: d.n, unit: d.unit }, freq, grace: CR.graceFromFrequency(freq), notify: { almost: false, due: true, overdue: true, time: '9:00 AM' }, desc: '', firstDue: CR.dateFromOffset(freq) }); onClose(); }}>Create</NavBtn>}>
      <div style={{ margin: '16px', padding: '14px 16px', borderRadius: 14, background: hexA(t.green, t.dark ? 0.14 : 0.08), display: 'flex', gap: 11, alignItems: 'center' }}>
        <Icon name="sparkles" size={22} color={t.green} />
        <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label, lineHeight: '19px' }}>
          Based on {disc.logs.length} logged occurrences, Rhythm suggests <b style={{ fontWeight: 600 }}>every {suggested} days</b>. Adjust if you like.
        </div>
      </div>
      <Section>
        <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '12px 16px' }}>
          <GlyphTile glyph={d.glyph} color={d.color} size={40} />
          <input value={d.name} onChange={e => setD({ ...d, name: e.target.value })} style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 18, fontWeight: 600, color: t.label }} />
        </div>
      </Section>
      <Section header="Scheduling"><div style={{ padding: 12 }}><SchedCards value={d.schedule} onChange={v => setD({ ...d, schedule: v })} /></div></Section>
      <Section header="Suggested frequency"><div style={{ padding: '4px 16px 14px' }}>
        <FreqPicker n={d.n} unit={d.unit} onN={v => setD({ ...d, n: v, grace: CR.graceFromFrequency(nuToDays(v, d.unit)) })} onUnit={v => setD({ ...d, unit: v, grace: CR.graceFromFrequency(nuToDays(d.n, v)) })} />
      </div></Section>
      <div style={{ height: 16 }} />
    </Sheet>
  );
}

function AddMenu({ open, onClose, onCadence, onBeat, onDiscovery }) {
  return (
    <ActionSheet open={open} onClose={onClose} title="ADD TO RHYTHM" actions={[
      { label: 'Cadence', icon: 'repeat', bold: true, onClick: onCadence },
      { label: 'Beat', icon: 'flag', onClick: onBeat },
      { label: 'Discovery', icon: 'target', onClick: onDiscovery },
    ]} />
  );
}

Object.assign(window, { CreateCadenceSheet, CreateBeatSheet, CreateDiscoverySheet, ConvertDiscoverySheet, AddMenu });
