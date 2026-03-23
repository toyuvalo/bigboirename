"""
BigBoiRename preview GUI — tkinter table of old → new names.
User can edit suggested names and check/uncheck before applying.
"""
import os
import tkinter as tk
from tkinter import ttk


# Catppuccin Mocha palette
BG       = "#1e1e2e"
BG_ALT   = "#181825"
SURFACE  = "#313244"
OVERLAY  = "#45475a"
TEXT     = "#cdd6f4"
SUBTEXT  = "#a6adc8"
MUTED    = "#6c7086"
BLUE     = "#89b4fa"
SKY      = "#74c7ec"
GREEN    = "#a6e3a1"
RED      = "#f38ba8"


def show_preview(folder_path, files, suggestions):
    """
    Show rename preview table.
    Returns dict {old_name: new_name} for checked rows, or None if cancelled.
    """
    result = {"action": None, "renames": {}}

    root = tk.Tk()
    root.title(f"BigBoiRename — {os.path.basename(folder_path)}")
    root.geometry("900x560")
    root.minsize(640, 320)
    root.configure(bg=BG)

    _apply_styles(root)

    # ── Header ────────────────────────────────────────────────────────────────
    hdr = tk.Frame(root, bg=BG, padx=14, pady=10)
    hdr.pack(fill=tk.X)
    tk.Label(hdr, text=folder_path, bg=BG, fg=MUTED, font=("Segoe UI", 8)).pack(side=tk.LEFT)
    tk.Label(hdr, text=f"{len(files)} files", bg=BG, fg=BLUE,
             font=("Segoe UI", 8, "bold")).pack(side=tk.RIGHT)

    # ── Column headers ────────────────────────────────────────────────────────
    col_hdr = tk.Frame(root, bg=SURFACE, padx=14, pady=5)
    col_hdr.pack(fill=tk.X)
    tk.Label(col_hdr, text="", bg=SURFACE, width=2).pack(side=tk.LEFT)
    tk.Label(col_hdr, text="Original Name", bg=SURFACE, fg=BLUE,
             font=("Segoe UI", 9, "bold"), width=36, anchor="w").pack(side=tk.LEFT, padx=(4, 0))
    tk.Label(col_hdr, text="→", bg=SURFACE, fg=MUTED, width=3).pack(side=tk.LEFT)
    tk.Label(col_hdr, text="Suggested Name  (editable)", bg=SURFACE, fg=BLUE,
             font=("Segoe UI", 9, "bold"), anchor="w").pack(side=tk.LEFT, padx=(4, 0))

    # ── Scrollable rows ───────────────────────────────────────────────────────
    outer = tk.Frame(root, bg=BG, padx=6)
    outer.pack(fill=tk.BOTH, expand=True)

    canvas = tk.Canvas(outer, bg=BG, highlightthickness=0)
    sb = ttk.Scrollbar(outer, orient="vertical", command=canvas.yview)
    inner = tk.Frame(canvas, bg=BG)

    inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    canvas_win = canvas.create_window((0, 0), window=inner, anchor="nw")
    canvas.configure(yscrollcommand=sb.set)

    # Stretch inner frame to canvas width
    canvas.bind("<Configure>", lambda e: canvas.itemconfig(canvas_win, width=e.width))

    canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
    sb.pack(side=tk.RIGHT, fill=tk.Y)
    canvas.bind("<MouseWheel>", lambda e: canvas.yview_scroll(int(-1 * (e.delta / 120)), "units"))

    rows = []  # (check_var, entry_var, original_name)

    for i, f in enumerate(files):
        original = f["name"]
        suggested = suggestions.get(original, original)
        row_bg = BG if i % 2 == 0 else BG_ALT

        row = tk.Frame(inner, bg=row_bg, pady=3)
        row.pack(fill=tk.X, padx=4)

        check_var = tk.BooleanVar(value=(suggested != original))
        cb = tk.Checkbutton(
            row, variable=check_var,
            bg=row_bg, fg=TEXT, selectcolor=SURFACE,
            activebackground=row_bg, activeforeground=TEXT,
            relief="flat", bd=0,
        )
        cb.pack(side=tk.LEFT, padx=(4, 2))

        type_color = {
            "video": "#cba6f7", "audio": GREEN,
            "image": SKY,       "text": TEXT,
            "other": MUTED,
        }.get(f["type"], MUTED)

        tk.Label(row, text=original, bg=row_bg, fg=SUBTEXT,
                 font=("Segoe UI", 9), width=36, anchor="w").pack(side=tk.LEFT)
        tk.Label(row, text="→", bg=row_bg, fg=MUTED,
                 font=("Segoe UI", 9), width=3).pack(side=tk.LEFT)

        entry_var = tk.StringVar(value=suggested)
        entry = tk.Entry(
            row, textvariable=entry_var,
            bg=SURFACE, fg=TEXT, insertbackground=TEXT,
            relief="flat", font=("Segoe UI", 9),
            width=44, bd=4,
        )
        entry.pack(side=tk.LEFT, padx=(2, 8))

        # Highlight changed vs unchanged
        def _update_color(var=entry_var, e=entry, orig=original):
            e.configure(fg=GREEN if var.get() != orig else SUBTEXT)
        entry_var.trace_add("write", lambda *a, fn=_update_color: fn())
        _update_color()

        # Auto-check on edit
        def _on_edit(var=entry_var, cv=check_var, orig=original):
            cv.set(var.get() != orig)
        entry_var.trace_add("write", lambda *a, fn=_on_edit: fn())

        rows.append((check_var, entry_var, original))

    # ── Bottom bar ────────────────────────────────────────────────────────────
    btm = tk.Frame(root, bg=SURFACE, padx=12, pady=8)
    btm.pack(fill=tk.X, side=tk.BOTTOM)

    status_var = tk.StringVar(value="Review names. Green = will rename. Uncheck to skip.")
    tk.Label(btm, textvariable=status_var, bg=SURFACE, fg=MUTED,
             font=("Segoe UI", 8)).pack(side=tk.LEFT)

    btn_frame = tk.Frame(btm, bg=SURFACE)
    btn_frame.pack(side=tk.RIGHT)

    def _select_all():
        for cv, ev, orig in rows:
            cv.set(True)

    def _deselect_all():
        for cv, ev, orig in rows:
            cv.set(False)

    def _cancel():
        result["action"] = "cancel"
        root.destroy()

    def _apply():
        renames = {}
        for cv, ev, orig in rows:
            if cv.get():
                new_name = ev.get().strip()
                if new_name and new_name != orig:
                    renames[orig] = new_name
        if not renames:
            status_var.set("Nothing checked — tick at least one file.")
            return
        result["action"] = "apply"
        result["renames"] = renames
        root.destroy()

    _btn(btn_frame, "Deselect All", _deselect_all, accent=False)
    _btn(btn_frame, "Select All",   _select_all,   accent=False)
    _btn(btn_frame, "Cancel",       _cancel,        accent=False)
    _btn(btn_frame, "Apply Selected", _apply,       accent=True)

    root.mainloop()

    if result["action"] == "apply":
        return result["renames"]
    return None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _apply_styles(root):
    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure("TScrollbar", background=SURFACE, troughcolor=BG,
                    arrowcolor=MUTED, borderwidth=0)


def _btn(parent, text, command, accent=False):
    bg = BLUE if accent else OVERLAY
    fg = BG if accent else TEXT
    hover = SKY if accent else SURFACE

    b = tk.Button(
        parent, text=text, command=command,
        bg=bg, fg=fg, activebackground=hover, activeforeground=fg,
        font=("Segoe UI", 9, "bold" if accent else "normal"),
        relief="flat", bd=0, padx=14, pady=5, cursor="hand2",
    )
    b.pack(side=tk.LEFT, padx=4)
    return b
