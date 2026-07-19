#!/usr/bin/env python3
"""
Simple VCD parser + digital waveform plotter (no external VCD dependency).
Usage: python3 vcd_plot.py <vcd_file> <output_png> <signal1> <signal2> ... [--window ns_start ns_end]
Signal names must match the human-readable names as declared in $var lines.
"""
import sys
import re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def parse_vcd(path, wanted_names):
    id_to_name = {}
    id_to_size = {}
    name_to_id = {}
    events = {}  # id -> list of (time, value_str)
    timescale = 1
    cur_time = 0

    with open(path, "r", errors="ignore") as f:
        in_header = True
        for line in f:
            line = line.strip()
            if line.startswith("$var"):
                parts = line.split()
                # $var wire 8 ! din $end   OR  $var reg 1 " clk $end
                size = int(parts[2])
                sid = parts[3]
                name = parts[4]
                id_to_size[sid] = size
                if name in wanted_names and name not in name_to_id:
                    name_to_id[name] = sid
                    id_to_name[sid] = name
                    events[sid] = []
            elif line.startswith("$enddefinitions"):
                in_header = False
            elif line.startswith("#"):
                cur_time = int(line[1:])
            elif line and not in_header:
                if line[0] in "01xXzZ":
                    val = line[0]
                    sid = line[1:]
                    if sid in events:
                        events[sid].append((cur_time, val))
                elif line[0] == "b":
                    m = re.match(r"b([01xXzZ]+)\s+(\S+)", line)
                    if m:
                        val = m.group(1)
                        sid = m.group(2)
                        if sid in events:
                            events[sid].append((cur_time, val))
    return events, id_to_name, name_to_id

def to_int(val):
    if 'x' in val.lower() or 'z' in val.lower():
        return None
    return int(val, 2) if len(val) > 1 else int(val)

def main():
    vcd_path = sys.argv[1]
    out_png = sys.argv[2]
    args = sys.argv[3:]
    window = None
    if "--window" in args:
        idx = args.index("--window")
        window = (int(args[idx+1]), int(args[idx+2]))
        signal_names = args[:idx]
    else:
        signal_names = args

    events, id_to_name, name_to_id = parse_vcd(vcd_path, set(signal_names))

    if window:
        for sid in list(events.keys()):
            filtered = [(t, v) for (t, v) in events[sid] if window[0] <= t <= window[1]]
            # keep last value before window start for continuity
            before = [(t, v) for (t, v) in events[sid] if t < window[0]]
            if before:
                filtered = [before[-1]] + filtered
            events[sid] = filtered

    missing = [s for s in signal_names if s not in name_to_id]
    if missing:
        print("WARNING: signals not found in VCD:", missing)
    signal_names = [s for s in signal_names if s in name_to_id]

    fig, axes = plt.subplots(len(signal_names), 1, figsize=(13, 1.3*len(signal_names)+1), sharex=True)
    if len(signal_names) == 1:
        axes = [axes]

    if window:
        max_time = window[1]
    else:
        max_time = 0
        for s in signal_names:
            sid = name_to_id[s]
            if events[sid]:
                max_time = max(max_time, events[sid][-1][0])

    for ax, s in zip(axes, signal_names):
        sid = name_to_id[s]
        pts = events[sid]
        if not pts:
            continue
        is_bus = any(len(v) > 1 for _, v in pts)
        times = [p[0] for p in pts] + [max_time]
        if is_bus:
            # bus: draw as text-labeled steps at mid-height
            vals = [to_int(p[1]) for p in pts]
            ax.step(times[:-1] + [max_time], vals + [vals[-1]], where='post', color='#2f7d6e', linewidth=1.4)
            for t, v in zip(times[:-1], vals):
                label = f"{v:02X}" if v is not None else "XX"
                ax.text(t, (max(vals+[1])*1.15 if vals else 1), label, fontsize=7,
                        ha='left', va='bottom', color='#1a4a40')
            ax.set_ylim(-0.5, (max(vals)+1)*1.4 if vals else 2)
        else:
            vals = [to_int(p[1]) or 0 for p in pts]
            step_t = times[:-1] + [max_time]
            step_v = vals + [vals[-1]]
            ax.step(step_t, step_v, where='post', color='#1f6fa8', linewidth=1.6)
            ax.set_ylim(-0.3, 1.3)
            ax.set_yticks([0, 1])
        ax.set_ylabel(s, rotation=0, ha='right', va='center', fontsize=10, color='#222')
        ax.grid(True, axis='x', linestyle=':', alpha=0.4)
        ax.set_xlim(window[0] if window else 0, max_time)

    axes[-1].set_xlabel("Time (simulation steps)")
    fig.suptitle("Waveform Preview — " + vcd_path.split("/")[-1], fontsize=12, fontweight='bold')
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.savefig(out_png, dpi=130)
    print("Saved waveform preview:", out_png)

if __name__ == "__main__":
    main()
