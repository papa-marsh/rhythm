// sheets.jsx — beat detail editor, snooze picker, beat action sheet
// Exports: BeatDetailSheet, SnoozeSheet, BeatActionSheet

const { snoozeForGrace, graceFromFrequency, fmtDate, fmtRelative, addDays, TODAY, daysBetween } = window.RhythmData;

function FieldInput({ value, onChange, placeholder, multiline }) {
  const t = useTheme();
  const base = { width: '100%', border: 'none', outline: 'none', background: 'transparent', resize: 'none',
    fontFamily: SF, fontSize: 17, color: t.label, letterSpacing: -0.2, padding: '11px 16px', boxSizing: 'border-box' };
  return multiline
    ? <textarea value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} rows={3} style={{ ...base, lineHeight: '22px' }} />
    : <input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} style={base} />;
}

function Stepper({ value, onDec, onInc, min }) {
  const t = useTheme();
  const btn = (dir, fn, dis) => (
    <button onClick={dis ? undefined : fn} style={{
      width: 44, height: 30, border: 'none', cursor: dis ? 'default' : 'pointer', background: 'transparent',
      display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: dis ? 0.3 : 1,
    }}><Icon name={dir === '-' ? 'close' : 'plus'} size={dir === '-' ? 2 : 17} strokeWidth={2.4} color={t.label} />
      {dir === '-' && <div style={{ width: 13, height: 2, borderRadius: 2, background: t.label }} />}
    </button>
  );
  return (
    <div style={{ display: 'flex', background: t.fill, borderRadius: 8, overflow: 'hidden' }}>
      {btn('-', onDec, min != null && value <= min)}
      <div style={{ width: 0.5, background: t.sep }} />
      {btn('+', onInc)}
    </div>
  );
}

function StatusBanner({ beat }) {
  const t = useTheme();
  const u = window.RhythmData.urgencyOf(beat);
  let txt, color = t.tier[u.tier], right = null;
  if (u.snoozed) {
    txt = 'Snoozed'; color = t.orange; right = `back ${window.RhythmData.fmtRelative(beat.snoozedUntil)}`;
  } else if (u.tier === 'later') { txt = 'Not due yet'; right = window.RhythmData.fmtRelative(beat.due); }
  else if (u.tier === 'almost') { txt = 'Upcoming'; right = window.RhythmData.fmtRelative(beat.due); }
  else if (u.tier === 'due') { txt = 'Due today'; }
  else { txt = `${-u.off} ${-u.off === 1 ? 'day' : 'days'} overdue`; }
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '14px 16px 0', padding: '11px 14px', borderRadius: 12, background: hexA(color, t.dark ? 0.18 : 0.1) }}>
      <span style={{ width: 9, height: 9, borderRadius: 9, background: color }} />
      <span style={{ fontFamily: SF, fontSize: 14.5, fontWeight: 600, color }}>{txt}</span>
      {right && <><span style={{ flex: 1 }} /><span style={{ fontFamily: SF, fontSize: 14, color, opacity: 0.85 }}>{right}</span></>}
    </div>
  );
}

function EditRow({ label, children, last, onClick, sub }) {
  const t = useTheme();
  return (
    <div onClick={onClick} style={{ position: 'relative', padding: '0 16px', cursor: onClick ? 'pointer' : 'default' }}>
      <div style={{ display: 'flex', alignItems: 'center', minHeight: 46, gap: 12 }}>
        <div style={{ fontFamily: SF, fontSize: 17, color: t.label, flexShrink: 0 }}>{label}</div>
        <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 8 }}>{children}</div>
      </div>
      {sub}
      {!last && <div style={{ position: 'absolute', left: 16, right: 0, bottom: 0, height: 0.5, background: t.sep }} />}
    </div>
  );
}

function BeatDetailSheet({ open, beat, cadence, onClose, onComplete, onSkip, onSnoozeOpen, onSave, onDelete, onOpenCadence }) {
  const t = useTheme();
  const [draft, setDraft] = useState(beat);
  useEffect(() => { if (open && beat) setDraft(beat); }, [open, beat && beat.id]);
  const [showCal, setShowCal] = useState(false);
  const [showTime, setShowTime] = useState(false);
  if (!beat) return null;
  const d = draft || beat;
  const set = (patch) => setDraft({ ...d, ...patch });
  const linked = !!cadence;
  const notify = d.notify || (cadence && cadence.notify) || { almost: false, due: true, overdue: true, time: '9:00 AM' };
  const setNotify = (p) => set({ notify: { ...notify, ...p } });

  return (
    <Sheet open={open} onClose={onClose} maxHeight="94%" height="94%" title="Beat"
      rightAction={<NavBtn bold onClick={() => { onSave(d); onClose(); }}>Done</NavBtn>}>
      <StatusBanner beat={d} />

      {/* identity */}
      <Section first>
        <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '12px 16px' }}>
          <GlyphTile glyph={d.glyph} color={d.color} size={40} />
          <input value={d.name} onChange={e => set({ name: e.target.value })} style={{
            flex: 1, border: 'none', outline: 'none', background: 'transparent',
            fontFamily: SF, fontSize: 20, fontWeight: 600, color: t.label, letterSpacing: -0.3,
          }} />
        </div>
      </Section>

      {linked && (
        <Section>
          <Row left={<Icon name="repeat" size={20} color={t.accent} />} title="Part of cadence" value={cadence.name} onClick={() => { onClose(); onOpenCadence && onOpenCadence(cadence); }} />
        </Section>
      )}

      {window.RhythmData.isSnoozed(d) && (
        <Section>
          <Row left={<Icon name="snooze" size={20} color={t.orange} />} title="Snoozed"
            subtitle={`Back ${fmtRelative(d.snoozedUntil)} · originally due ${fmtDate(d.due)}`}
            accessory={<button onClick={() => set({ snoozedUntil: null })} style={{ border: 'none', background: 'none', cursor: 'pointer', fontFamily: SF, fontSize: 15, fontWeight: 500, color: t.accent }}>Resume</button>} />
        </Section>
      )}

      {/* schedule */}
      <Section header="Schedule" footer={linked ? `This beat follows “${cadence.name}”. Editing the due date here affects only this beat.` : null}>
        <EditRow label="Due date" onClick={() => setShowCal(s => !s)}
          sub={showCal && <div style={{ paddingBottom: 6 }}><MiniCalendar value={d.due} onChange={(dt) => set({ due: dt })} /></div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: showCal ? t.accent : t.label2 }}>{fmtDate(d.due, { absolute: true })}</span>
        </EditRow>
        <EditRow label="Grace period" last
          sub={<div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, padding: '0 0 9px', lineHeight: '17px' }}>
            {linked ? 'Inherited from the cadence’s frequency. ' : ''}Used for the main beat view, notification timing, and snooze length.
          </div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: t.label2, marginRight: 4 }}>{d.grace} {d.grace === 1 ? 'day' : 'days'}</span>
          <Stepper value={d.grace} min={0} onDec={() => set({ grace: Math.max(0, d.grace - 1) })} onInc={() => set({ grace: d.grace + 1 })} />
        </EditRow>
      </Section>

      {/* notifications */}
      <Section header="Notifications" footer="Overrides the cadence default for this beat only.">
        <EditRow label="Almost due"><Switch on={notify.almost} onChange={v => setNotify({ almost: v })} color={t.accent} /></EditRow>
        <EditRow label="Due"><Switch on={notify.due} onChange={v => setNotify({ due: v })} color={t.accent} /></EditRow>
        <EditRow label="Overdue"><Switch on={notify.overdue} onChange={v => setNotify({ overdue: v })} color={t.accent} /></EditRow>
        <EditRow label="Time" last onClick={() => setShowTime(s => !s)}
          sub={showTime && <TimePickerPanel value={notify.time} onChange={v => setNotify({ time: v })} />}>
          <span style={{ fontFamily: SF, fontSize: 17, color: showTime ? t.accent : t.label2 }}>{notify.time}</span>
        </EditRow>
      </Section>

      {/* notes */}
      <Section header="Notes">
        <FieldInput value={d.desc || ''} onChange={v => set({ desc: v })} placeholder="Add a note…" multiline />
      </Section>

      {/* actions */}
      <div style={{ padding: '22px 16px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <BigButton icon="check" onClick={() => { onComplete(); onClose(); }}>Complete beat</BigButton>
        <div style={{ display: 'flex', gap: 10 }}>
          <BigButton kind="tinted" icon="snooze" onClick={() => { onClose(); onSnoozeOpen(); }}>Snooze</BigButton>
          <BigButton kind="tinted" icon="skip" onClick={() => { onSkip(); onClose(); }}>Skip</BigButton>
        </div>
        {!linked && <BigButton kind="tinted" danger icon="trash2" onClick={() => { onDelete(); onClose(); }}>Delete beat</BigButton>}
      </div>
      <div style={{ height: 24 }} />
    </Sheet>
  );
}

function SnoozeSheet({ open, beat, onClose, onPick }) {
  const t = useTheme();
  const [showCal, setShowCal] = useState(false);
  const [custom, setCustom] = useState(beat ? addDays(beat.due > TODAY ? beat.due : TODAY, 1) : TODAY);
  if (!beat) return null;
  const g = snoozeForGrace(beat.grace);
  const opts = [
    { label: 'Tomorrow', days: 1 },
    { label: `${g} ${g === 1 ? 'day' : 'days'} — matches grace`, days: g, primary: true },
    { label: 'In 3 days', days: 3 },
    { label: 'Next week', days: 7 },
  ].filter((o, i, a) => a.findIndex(x => x.days === o.days) === i);
  return (
    <Sheet open={open} onClose={onClose} title="Snooze" maxHeight="88%">
      <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, padding: '14px 20px 4px', lineHeight: '18px' }}>
        Push “{beat.name}” off your radar until later. Default matches its grace period.
      </div>
      <Section first>
        {opts.map((o, i) => {
          const date = addDays(TODAY, o.days);
          return <Row key={i} title={o.label} titleWeight={o.primary ? 600 : 400}
            left={<Icon name="snooze" size={20} color={t.accent} />}
            value={fmtDate(date)} accessory="none" last={i === opts.length - 1}
            onClick={() => { onPick(date); onClose(); }} />;
        })}
      </Section>
      <Section>
        <EditRow label="Pick a date" onClick={() => setShowCal(s => !s)}
          sub={showCal && <div style={{ paddingBottom: 4 }}>
            <MiniCalendar value={custom} onChange={setCustom} />
            <div style={{ padding: '0 0 12px' }}><BigButton onClick={() => { onPick(custom); onClose(); }}>Snooze until {fmtDate(custom)}</BigButton></div>
          </div>}>
          <span style={{ fontFamily: SF, fontSize: 17, color: t.accent }}>{showCal ? fmtDate(custom) : ''}</span>
        </EditRow>
      </Section>
      <div style={{ height: 20 }} />
    </Sheet>
  );
}

function BeatActionSheet({ open, beat, onClose, onComplete, onSnooze, onSkip, onEdit }) {
  const t = useTheme();
  if (!beat) return null;
  const header = (
    <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '14px 16px', justifyContent: 'center' }}>
      <GlyphTile glyph={beat.glyph} color={beat.color} size={28} />
      <span style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: t.label }}>{beat.name}</span>
    </div>
  );
  return (
    <ActionSheet open={open} onClose={onClose} header={header} actions={[
      { label: 'Complete', icon: 'check', bold: true, color: t.green, onClick: onComplete },
      { label: 'Snooze…', icon: 'snooze', onClick: onSnooze },
      { label: 'Skip this beat', icon: 'skip', onClick: onSkip },
      { label: 'Edit details…', icon: 'pencil', onClick: onEdit },
    ]} />
  );
}

Object.assign(window, { BeatDetailSheet, SnoozeSheet, BeatActionSheet, Stepper, FieldInput, EditRow });
