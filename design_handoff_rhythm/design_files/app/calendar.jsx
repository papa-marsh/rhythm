// calendar.jsx — compact month calendar (graphical date picker)
// Exports: MiniCalendar

function MiniCalendar({ value, onChange }) {
  const t = useTheme();
  const { TODAY, startOfDay, MONTHS, daysBetween } = window.RhythmData;
  const sel = startOfDay(value);
  const [view, setView] = useState(new Date(sel.getFullYear(), sel.getMonth(), 1));
  const y = view.getFullYear(), m = view.getMonth();
  const first = new Date(y, m, 1);
  const startDow = first.getDay();
  const daysIn = new Date(y, m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < startDow; i++) cells.push(null);
  for (let d = 1; d <= daysIn; d++) cells.push(d);

  const shift = (n) => setView(new Date(y, m + n, 1));
  const W = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  return (
    <div style={{ padding: '4px 6px 10px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 10px 10px' }}>
        <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: t.label }}>{MONTHS[m]} {y}</div>
        <div style={{ display: 'flex', gap: 22 }}>
          <button onClick={() => shift(-1)} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 2 }}><Icon name="back" size={20} strokeWidth={2.6} color={t.accent} /></button>
          <button onClick={() => shift(1)} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 2 }}><Icon name="chevron" size={20} strokeWidth={2.6} color={t.accent} /></button>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 2, padding: '0 6px' }}>
        {W.map((w, i) => <div key={'w' + i} style={{ textAlign: 'center', fontFamily: SF, fontSize: 12, fontWeight: 600, color: t.label2, paddingBottom: 4 }}>{w}</div>)}
        {cells.map((d, i) => {
          if (!d) return <div key={i} />;
          const date = new Date(y, m, d);
          const isSel = daysBetween(date, sel) === 0;
          const isToday = daysBetween(date, TODAY) === 0;
          return (
            <button key={i} onClick={() => onChange(startOfDay(date))} style={{
              aspectRatio: '1', border: 'none', cursor: 'pointer', borderRadius: 999,
              background: isSel ? t.accent : 'transparent',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: SF, fontSize: 17, fontWeight: isSel || isToday ? 600 : 400,
              color: isSel ? '#fff' : isToday ? t.accent : t.label,
            }}>{d}</button>
          );
        })}
      </div>
    </div>
  );
}

window.MiniCalendar = MiniCalendar;
