from pathlib import Path

app_path = Path(defines["app"])

format = "UDZO"
files = [str(app_path)]
symlinks = {"Applications": "/Applications"}
background = defines["background"]
window_rect = ((120, 120), (800, 500))
default_view = "icon-view"
show_status_bar = False
show_toolbar = False
show_tab_view = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 14
icon_locations = {
    app_path.name: (190, 260),
    "Applications": (610, 260),
}
