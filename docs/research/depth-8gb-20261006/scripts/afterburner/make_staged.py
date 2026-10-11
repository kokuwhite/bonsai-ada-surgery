"""Build staged.cfg from the live Afterburner profile file: slots 1..4 rewritten, slot 5 (stock) kept as it is.

python make_staged.py "1:power=123,fan=85,core=0" "2:power=123,fan=85,core=50" ...
power = PowerLimit %, fan = fixed fan % (FanMode=0), core / mem = offsets in MHz. VFCurve is blanked on rewritten
slots so the flat core offset applies (an empty field leaves that setting untouched).
"""
import re
import sys

LIVE = r"C:\Program Files (x86)\MSI Afterburner\Profiles\VEN_10DE&DEV_1F47&SUBSYS_13AD10DE&REV_A1&BUS_9&DEV_0&FN_0.cfg"
OUT = r"C:\bonsai\8gb\afterburner\staged.cfg"

text = open(LIVE, encoding="utf-8").read()
sections = re.split(r"(?m)^(?=\[)", text)
by_name = {s.split("]")[0].strip("[\n"): s for s in sections if s.startswith("[")}

for spec in sys.argv[1:]:
    slot, kv = spec.split(":", 1)
    opts = dict(p.split("=") for p in kv.split(","))
    fields = {
        "Format": "2",
        "PowerLimit": opts.get("power", "100"),
        "ThermalLimit": "",
        "ThermalPrioritize": "0",
        "CoreClkBoost": str(int(opts.get("core", "0")) * 1000),
        "VFCurve": "",
        "MemClkBoost": str(int(opts.get("mem", "0")) * 1000),
        "FanMode": "0" if "fan" in opts else "1",
        "FanSpeed": opts.get("fan", "41"),
        "FanMode2": "",
        "FanSpeed2": "",
    }
    by_name[f"Profile{slot}"] = f"[Profile{slot}]\n" + "".join(f"{k}={v}\n" for k, v in fields.items())

order = ["Startup"] + [f"Profile{i}" for i in range(1, 6)]
with open(OUT, "w", encoding="utf-8", newline="\r\n") as f:
    for name in order:
        if name in by_name:
            f.write(by_name[name].rstrip("\r\n").replace("\r\n", "\n") + "\n")
print("wrote", OUT)
for name in order[1:]:
    s = by_name.get(name, "")
    print(name, re.findall(r"(PowerLimit|CoreClkBoost|MemClkBoost|FanMode|FanSpeed)=(\S*)", s))
