from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "scenes"
OUT.mkdir(exist_ok=True)
W, H = 1080, 1920
C = {
    "ink": "#1D1B18", "paper": "#F8F5EE", "surface": "#FFFDF8", "text": "#292824",
    "muted": "#77736A", "coral": "#E96B4C", "teal": "#3C8C82", "butter": "#FFE8A8",
    "sky": "#CFE8F6", "mint": "#CDEAD8", "blush": "#F4D5DF", "lavender": "#E1D9F2",
}
FONT = Path(r"C:\Windows\Fonts\segoeui.ttf")
BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")
SEMIBOLD = Path(r"C:\Windows\Fonts\seguisb.ttf")
logo = Image.open(ROOT / "assets" / "branding" / "jotcue_icon.png").convert("RGBA")

def font(size, bold=False, semibold=False):
    return ImageFont.truetype(str(BOLD if bold else SEMIBOLD if semibold else FONT), size)

def plate(dark=False):
    image = Image.new("RGB", (W, H), C["ink"] if dark else C["paper"])
    draw = ImageDraw.Draw(image)
    random.seed(14 if dark else 9)
    color = (255, 232, 168) if dark else (29, 27, 24)
    for _ in range(950):
        x, y = random.randrange(W), random.randrange(H)
        draw.point((x, y), fill=(*color, 18))
    return image, draw

def centered(draw, value, y, size, fill, bold=False):
    f = font(size, bold=bold)
    box = draw.textbbox((0, 0), value, font=f)
    draw.text(((W - (box[2] - box[0])) / 2, y), value, font=f, fill=fill)

def wrap(draw, value, box, size, fill, bold=False, spacing=12):
    x, y, width = box
    f = font(size, bold=bold)
    words, lines, line = value.split(), [], ""
    for word in words:
        test = f"{line} {word}".strip()
        if draw.textbbox((0, 0), test, font=f)[2] > width and line:
            lines.append(line); line = word
        else:
            line = test
    if line: lines.append(line)
    for item in lines:
        draw.text((x, y), item, font=f, fill=fill)
        y += size + spacing
    return y

def heading(draw, step, title, body, accent):
    if step:
        draw.rounded_rectangle((72, 82, 235, 140), 29, fill=accent)
        f = font(25, bold=True)
        draw.text((92, 98), step, font=f, fill=C["ink"])
    wrap(draw, title, (72, 200, 936), 74, C["text"], bold=True, spacing=8)
    wrap(draw, body, (74, 330, 900), 31, C["muted"], spacing=10)

def phone(draw, y=468, height=1240):
    x, width = 115, 850
    draw.rounded_rectangle((x + 10, y + 22, x + width + 10, y + height + 22), 68, fill="#D8D1C6")
    draw.rounded_rectangle((x, y, x + width, y + height), 68, fill=C["ink"])
    draw.rounded_rectangle((x + 12, y + 12, x + width - 12, y + height - 12), 56, fill=C["paper"])
    draw.rounded_rectangle((x + width // 2 - 66, y + 26, x + width // 2 + 66, y + 54), 14, fill=C["ink"])
    return x + 42, y + 82, width - 84, height - 124

def app_top(image, draw, screen, title="JotCue"):
    x, y, width, _ = screen
    icon = logo.resize((72, 72), Image.Resampling.LANCZOS)
    image.paste(icon, (x, y - 10), icon)
    draw.text((x + 88, y + 3), title, font=font(35, bold=True), fill=C["text"])
    draw.ellipse((x + width - 96, y + 3, x + width - 58, y + 41), outline=C["text"], width=5)
    draw.line((x + width - 67, y + 33, x + width - 46, y + 54), fill=C["text"], width=5)

def checkbox(draw, x, y, checked=False):
    draw.rounded_rectangle((x, y, x + 40, y + 40), 9, fill=C["teal"] if checked else C["surface"], outline=C["teal"] if checked else "#B7B1A6", width=3)
    if checked: draw.line((x + 10, y + 21, x + 18, y + 29, x + 31, y + 11), fill=C["surface"], width=5, joint="curve")

def save(image, number, name):
    image.save(OUT / f"{number:02d}-{name}.png", optimize=True)

# 1 — hook
image, draw = plate(True)
icon = logo.resize((320, 320), Image.Resampling.LANCZOS)
image.paste(icon, (380, 410), icon)
centered(draw, "JotCue", 810, 114, C["paper"], bold=True)
centered(draw, "Notes that know what comes next.", 950, 40, "#D7D0C4")
draw.rounded_rectangle((266, 1070, 814, 1142), 36, fill=C["butter"])
centered(draw, "NOTES  •  TASKS  •  REMINDERS", 1091, 25, C["ink"], bold=True)
centered(draw, "A calm place for busy thoughts.", 1660, 29, "#AFA79B")
save(image, 1, "meet-jotcue")

# 2 — tap + and write
image, draw = plate()
heading(draw, "STEP 1", "Start a note.", "Tap + and write like you normally do.", C["coral"])
s = phone(draw); app_top(image, draw, s)
x, y, width, height = s
draw.text((x, y + 120), "Good morning, Alex", font=font(40, bold=True), fill=C["text"])
draw.text((x, y + 176), "Capture ideas and never miss a thing.", font=font(25), fill=C["muted"])
draw.rounded_rectangle((x, y + 230, x + width, y + 320), 28, fill=C["surface"], outline="#E3DDD1", width=2)
draw.text((x + 64, y + 258), "Search notes", font=font(27), fill=C["muted"])
cards = [(x, y + 360, width * .48, 238, C["sky"], "Meeting notes", "Team sync on Monday"), (x + width * .52, y + 360, width * .48, 238, C["mint"], "Home reset", "Laundry and groceries"), (x, y + 630, width, 210, C["butter"], "Plan my week", "Call Mom at 6pm")]
for cx, cy, cw, ch, color, title, body in cards:
    draw.rounded_rectangle((cx, cy, cx + cw, cy + ch), 30, fill=color)
    draw.text((cx + 28, cy + 28), title, font=font(30, bold=True), fill=C["text"])
    wrap(draw, body, (cx + 28, cy + 86, cw - 56), 23, C["text"])
bx, by = x + width - 74, y + height - 94
draw.ellipse((bx - 57, by - 57, bx + 57, by + 57), fill=C["coral"])
draw.line((bx - 20, by, bx + 20, by), fill=C["ink"], width=7); draw.line((bx, by - 20, bx, by + 20), fill=C["ink"], width=7)
save(image, 2, "start-a-note")

# 3 — plan to tasks
image, draw = plate()
heading(draw, "STEP 2", "Make actions clear.", "Start a line with “- ”, or let JotCue structure a short plan.", C["mint"])
s = phone(draw, 505, 1210); app_top(image, draw, s, "New note")
x, y, width, height = s
draw.text((x, y + 120), "Weekend reset", font=font(46, bold=True), fill=C["text"])
draw.rounded_rectangle((x, y + 190, x + width, y + 510), 30, fill=C["surface"], outline="#E3DDD1", width=2)
steps = ["Book dentist appointment", "Pick up groceries", "Send trip dates to Maya"]
for i, item in enumerate(steps): draw.text((x + 32, y + 235 + i * 70), item, font=font(27), fill=C["text"])
draw.rounded_rectangle((x, y + 545, x + width, y + 700), 30, fill=C["mint"])
wrap(draw, "I found 3 plan steps. Turn them into tasks?", (x + 35, y + 580, 470), 25, C["text"], bold=True, spacing=8)
draw.rounded_rectangle((x + width - 205, y + 590, x + width - 30, y + 654), 32, fill=C["ink"])
draw.text((x + width - 178, y + 607), "Add tasks", font=font(23, bold=True), fill=C["paper"])
draw.rounded_rectangle((x, y + 740, x + width, y + 1035), 30, fill=C["surface"])
for i, item in enumerate(steps):
    checkbox(draw, x + 28, y + 785 + i * 76, checked=i == 0)
    draw.text((x + 88, y + 789 + i * 76), item, font=font(25, semibold=True), fill=C["muted"] if i == 0 else C["text"])
save(image, 3, "plans-to-tasks")

# 4 — natural reminder
image, draw = plate()
heading(draw, "STEP 3", "Add the cue.", "Write the time naturally, review the suggestion, then tap Add.", C["butter"])
s = phone(draw, 500, 1220); app_top(image, draw, s, "New note")
x, y, width, height = s
draw.text((x, y + 120), "Call Mom", font=font(46, bold=True), fill=C["text"])
draw.rounded_rectangle((x, y + 190, x + width, y + 520), 30, fill=C["surface"], outline="#E3DDD1", width=2)
wrap(draw, "Remind me to call Mom Monday at 6pm.", (x + 32, y + 240, width - 64), 31, C["text"], spacing=14)
draw.rounded_rectangle((x, y + 560, x + width, y + 738), 30, fill=C["butter"])
draw.polygon([(x + 50, y + 600), (x + 58, y + 620), (x + 78, y + 628), (x + 58, y + 636), (x + 50, y + 656), (x + 42, y + 636), (x + 22, y + 628), (x + 42, y + 620)], fill=C["ink"])
wrap(draw, "Add a reminder for Monday at 6:00 PM?", (x + 95, y + 600, 430), 25, C["text"], bold=True, spacing=8)
draw.rounded_rectangle((x + width - 170, y + 610, x + width - 32, y + 675), 32, fill=C["ink"])
draw.text((x + width - 126, y + 626), "Add", font=font(25, bold=True), fill=C["paper"])
draw.rounded_rectangle((x + 36, y + 805, x + width - 36, y + 960), 32, fill=C["ink"])
draw.line((x + 74, y + 885, x + 86, y + 897, x + 108, y + 867), fill=C["mint"], width=7, joint="curve")
draw.text((x + 138, y + 858), "Reminder set for 6:00 PM.", font=font(27, bold=True), fill=C["paper"])
save(image, 4, "add-the-cue")

# 5 — organize and offline
image, draw = plate()
heading(draw, "", "Find anything, fast.", "Pin favorites, search, or filter by category—even when you are offline.", C["sky"])
s = phone(draw, 450, 1280); app_top(image, draw, s)
x, y, width, height = s
draw.rounded_rectangle((x, y + 115, x + width, y + 208), 28, fill=C["surface"], outline=C["coral"], width=3)
draw.ellipse((x + 30, y + 138, x + 62, y + 170), outline=C["text"], width=4); draw.line((x + 56, y + 164, x + 73, y + 181), fill=C["text"], width=4); draw.text((x + 92, y + 141), "trip", font=font(29), fill=C["text"])
chips = [("All", C["ink"], C["paper"]), ("Work", C["sky"], C["text"]), ("Personal", C["blush"], C["text"]), ("Reminders", C["mint"], C["text"])]
cx = x
for label, fill, fg in chips:
    cw = 92 + len(label) * 9
    draw.rounded_rectangle((cx, y + 240, cx + cw, y + 300), 30, fill=fill)
    draw.text((cx + 22, y + 256), label, font=font(22, bold=True), fill=fg); cx += cw + 12
notes = [(C["sky"], "●  Pinned", "Weekend trip ideas", "Hotel • Museum • Train times"), (C["butter"], "●", "Book train tickets", "Reminder • Friday at 9:00 AM"), (C["mint"], "●", "Packing list", "4 of 7 tasks complete")]
for i, (color, flag, title, body) in enumerate(notes):
    cy = y + 340 + i * 245
    draw.rounded_rectangle((x, cy, x + width, cy + 215), 30, fill=color)
    draw.text((x + 28, cy + 25), flag, font=font(20, bold=True), fill=C["teal"] if i == 0 else C["muted"])
    draw.text((x + 28, cy + 78), title, font=font(31, bold=True), fill=C["text"])
    draw.text((x + 28, cy + 135), body, font=font(23), fill=C["muted"])
draw.rounded_rectangle((x + width - 250, y + height - 78, x + width, y + height - 20), 29, fill=C["ink"])
draw.text((x + width - 225, y + height - 62), "●  Available offline", font=font(20, bold=True), fill=C["paper"])
save(image, 5, "find-anything")

# 6 — CTA
image, draw = plate(True)
icon = logo.resize((310, 310), Image.Resampling.LANCZOS)
image.paste(icon, (385, 420), icon)
centered(draw, "JotCue", 850, 118, C["paper"], bold=True)
centered(draw, "Jot it down. We’ll cue the rest.", 1020, 42, "#D7D0C4")
draw.rounded_rectangle((160, 1200, 920, 1320), 38, fill=C["coral"])
centered(draw, "Start writing", 1232, 38, C["ink"], bold=True)
centered(draw, "Notes  •  Tasks  •  Smart reminders", 1410, 28, C["butter"], bold=True)
centered(draw, "Available across your devices.", 1690, 28, "#AFA79B")
save(image, 6, "start-writing")

print(f"Created 6 scene plates in {OUT}")
