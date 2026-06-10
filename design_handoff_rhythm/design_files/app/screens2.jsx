// screens2.jsx — Discovery + Settings
// Exports: DiscoveryScreen, SettingsScreen

const SC2 = window.RhythmData;

function ProgressDots({ n, total = 2, color }) {
  const t = useTheme();
  return (
    <div style={{ display: 'flex', gap: 5 }}>
      {Array.from({ length: total }).map((_, i) => (
        <span key={i} style={{ width: 8, height: 8, borderRadius: 8, background: i < n ? color : t.fill, border: i < n ? 'none' : `1.5px solid ${t.label3}` }} />
      ))}
    </div>
  );
}

function DiscoveryCard({ disc, onLog, onConvert }) {
  const t = useTheme();
  const ready = disc.logs.length >= 2;
  const sorted = [...disc.logs].sort((a, b) => a - b);
  let suggested = null;
  if (ready) {
    let sum = 0; for (let i = 0; i < sorted.length - 1; i++) sum += SC2.daysBetween(sorted[i], sorted[i + 1]);
    suggested = Math.round(sum / (sorted.length - 1));
  }
  return (
    <div style={{ background: t.card, borderRadius: 16, margin: '0 16px 12px', overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px 12px' }}>
        <GlyphTile glyph={disc.glyph} color={disc.color} size={38} radius={11} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: t.label, letterSpacing: -0.2 }}>{disc.name}</div>
          <div style={{ fontFamily: SF, fontSize: 13, color: t.label2, marginTop: 2 }}>{disc.logs.length} of 2 logged</div>
        </div>
        <ProgressDots n={disc.logs.length} color={ready ? t.green : t.accent} />
      </div>

      {/* logged timeline */}
      <div style={{ padding: '0 16px 12px' }}>
        {sorted.length === 0 && <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, padding: '4px 0' }}>No occurrences logged yet. Log the next time you do it.</div>}
        {sorted.map((d, i) => {
          const interval = i > 0 ? SC2.daysBetween(sorted[i - 1], d) : null;
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '5px 0' }}>
              <span style={{ width: 8, height: 8, borderRadius: 8, background: ready ? t.green : t.accent }} />
              <span style={{ fontFamily: SF, fontSize: 14.5, color: t.label }}>{SC2.fmtDate(d, { absolute: true })}</span>
              {interval != null && <span style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, marginLeft: 'auto' }}>+{interval} days</span>}
            </div>
          );
        })}
      </div>

      {ready ? (
        <div style={{ borderTop: `0.5px solid ${t.sep}`, padding: 14, background: hexA(t.green, t.dark ? 0.1 : 0.05) }}>
          <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, marginBottom: 10 }}>
            Suggested frequency: <b style={{ color: t.label, fontWeight: 600 }}>about every {suggested} days</b>. Convert to lock it in.
          </div>
          <BigButton icon="arrowRight" onClick={() => onConvert(disc, suggested)}>Convert to cadence</BigButton>
        </div>
      ) : (
        <div style={{ borderTop: `0.5px solid ${t.sep}`, padding: 12 }}>
          <BigButton kind="tinted" icon="plus" onClick={() => onLog(disc)}>Log occurrence</BigButton>
        </div>
      )}
    </div>
  );
}

function DiscoveryScreen({ discoveries, onLog, onConvert, onAdd }) {
  const t = useTheme();
  return (
    <ScreenScaffold title="Discovery" subtitle="Find your rhythm" trailing={<PlusBtn onClick={onAdd} />}>
      <div style={{ margin: '8px 16px 18px', padding: '14px 16px', borderRadius: 14, background: hexA(t.accent, t.dark ? 0.16 : 0.09), display: 'flex', gap: 12 }}>
        <Icon name="discovery" size={22} color={t.accent} strokeWidth={1.9} style={{ marginTop: 1 }} />
        <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label, lineHeight: '19px', opacity: 0.9 }}>
          Don’t know how often something happens? Log it twice and Rhythm suggests a frequency — then converts it to a real cadence.
        </div>
      </div>
      {discoveries.map(d => <DiscoveryCard key={d.id} disc={d} onLog={onLog} onConvert={onConvert} />)}
      {discoveries.length === 0 && (
        <div style={{ textAlign: 'center', padding: '40px 30px', fontFamily: SF, color: t.label2, fontSize: 14.5 }}>No discoveries yet.</div>
      )}
      <div style={{ height: 8 }} />
    </ScreenScaffold>
  );
}

function SettingsSeg({ label, options, value, onChange, footer }) {
  const t = useTheme();
  return (
    <div style={{ padding: '12px 16px' }}>
      <div style={{ fontFamily: SF, fontSize: 13, color: t.label2, marginBottom: 9 }}>{label}</div>
      <Segmented options={options} value={value} onChange={onChange} />
      {footer && <div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, marginTop: 9, lineHeight: '17px' }}>{footer}</div>}
    </div>
  );
}

function SettingsScreen({ settings, setSettings, appearance, onSetAppearance }) {
  const t = useTheme();
  const [showTime, setShowTime] = useState(false);
  const s = settings;
  const upd = (p) => setSettings({ ...s, ...p });
  const updN = (p) => setSettings({ ...s, notify: { ...s.notify, ...p } });
  return (
    <ScreenScaffold title="Settings">
      <Section first header="Appearance">
        <SettingsSeg label="Theme" value={appearance}
          options={[{ value: 'light', label: 'Light' }, { value: 'dark', label: 'Dark' }, { value: 'system', label: 'System' }]}
          onChange={onSetAppearance} footer="System follows your device’s appearance." />
      </Section>

      <Section>
        <EditRow label="Show emojis" last sub={<div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, padding: '0 0 9px' }}>Display emojis next to beats and cadences.</div>}>
          <Switch on={s.showEmoji !== false} onChange={v => upd({ showEmoji: v })} color={t.accent} />
        </EditRow>
      </Section>

      <Section header="New cadence defaults">
        <SettingsSeg label="Scheduling"
          options={[{ value: 'completion', label: 'Relative' }, { value: 'dueDate', label: 'Fixed' }]}
          value={s.defaultSchedule} onChange={v => upd({ defaultSchedule: v })}
          footer="“Relative” counts from when you finish (haircut). “Fixed” keeps a hard schedule (utility bill)." />
      </Section>

      <Section header="Default notifications" footer="Applied to new cadences. Each cadence and beat can override these.">
        <EditRow label="Almost due"><Switch on={s.notify.almost} onChange={v => updN({ almost: v })} color={t.accent} /></EditRow>
        <EditRow label="Due"><Switch on={s.notify.due} onChange={v => updN({ due: v })} color={t.accent} /></EditRow>
        <EditRow label="Overdue"><Switch on={s.notify.overdue} onChange={v => updN({ overdue: v })} color={t.accent} /></EditRow>
        <EditRow label="Default time" last onClick={() => setShowTime(v => !v)}
          sub={showTime && <TimePickerPanel value={s.notify.time} onChange={v => updN({ time: v })} />}>
          <span style={{ fontFamily: SF, fontSize: 17, color: showTime ? t.accent : t.label2 }}>{s.notify.time}</span>
        </EditRow>
      </Section>

      <Section header="Alerts">
        <EditRow label="Sound"><Switch on={s.sound} onChange={v => upd({ sound: v })} /></EditRow>
        <EditRow label="Vibrate" last><Switch on={s.vibrate} onChange={v => upd({ vibrate: v })} /></EditRow>
      </Section>

      <Section header="About" footer="Beats are due on a day, never a time. Notification time only controls when the reminder is delivered.">
        <Row title="Version" value="1.0 (Rhythm)" accessory="none" last />
      </Section>
      <div style={{ height: 10 }} />
    </ScreenScaffold>
  );
}

Object.assign(window, { DiscoveryScreen, SettingsScreen, DiscoveryCard, ProgressDots });
