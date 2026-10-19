"""Keyboard checklist and review screen for the Linux installer."""
import textwrap


def toggle_component(selected, name, normalize):
    selected = set(selected)
    if name in selected:
        selected.remove(name)
        if name == 'desktop':
            selected.difference_update({'shortcuts', 'clipboard', 'quicksettings', 'prescript'})
        elif name == 'shortcuts':
            selected.discard('clipboard')
    else:
        selected.add(name)
    return normalize(selected) if selected else selected


def _terminal(callback):
    try:
        import curses
    except ImportError as error:
        raise ValueError('The keyboard installer needs Python curses on Linux. Use a Linux terminal.') from error

    def start(screen):
        try:
            curses.curs_set(0)
        except curses.error:
            pass
        curses.set_escdelay(30)
        screen.keypad(True)
        color = curses.A_BOLD
        if curses.has_colors():
            curses.start_color()
            try:
                curses.use_default_colors()
                curses.init_pair(1, curses.COLOR_CYAN, -1)
            except curses.error:
                curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)
            color = curses.color_pair(1)
        return callback(screen, curses, color)

    try:
        return curses.wrapper(start)
    except curses.error as error:
        raise ValueError('Open setup in a normal Linux terminal (Konsole); it needs keyboard and screen access.') from error


def _write(screen, row, text, style=0):
    height, width = screen.getmaxyx()
    if 0 <= row < height and width > 1:
        screen.addnstr(row, 1, text, width - 2, style)


def choose_components(components, defaults, normalize):
    names = list(components)

    def show(screen, curses, color):
        selected = normalize(set(defaults)) if defaults else set()
        focus = 0
        note = ''
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            if height < 12 or width < 48:
                _write(screen, 0, 'Enlarge the terminal (48 columns / 12 rows).', color)
                _write(screen, 2, 'Esc: cancel')
            else:
                _write(screen, 1, 'THE INDEX / INSTALL', color | curses.A_BOLD)
                _write(screen, 3, 'Up/Down: move   Space: select   Enter: review   Esc: cancel', color)
                rows = min(len(names), height - 10)
                top = max(0, min(focus - rows + 1, len(names) - rows))
                for offset, name in enumerate(names[top:top + rows]):
                    label = components[name].split(':', 1)[0]
                    line = f' [{"x" if name in selected else " "}] {label}'
                    style = color | curses.A_REVERSE if top + offset == focus else color
                    _write(screen, 5 + offset, line.ljust(width - 2), style)
                description = components[names[focus]].split(':', 1)[-1].strip()
                for offset, line in enumerate(textwrap.wrap(description, width - 4)[:2]):
                    _write(screen, height - 4 + offset, line)
                _write(screen, height - 1, note or f'{len(selected)} components selected', color)
            screen.refresh()
            key = screen.get_wch()
            if key in ('\x1b', 'q', 'Q'):
                return None
            if height < 12 or width < 48:
                continue
            if key in (curses.KEY_UP, 'k'):
                focus = (focus - 1) % len(names)
            elif key in (curses.KEY_DOWN, 'j'):
                focus = (focus + 1) % len(names)
            elif key == curses.KEY_HOME:
                focus = 0
            elif key == curses.KEY_END:
                focus = len(names) - 1
            elif key == ' ':
                selected = toggle_component(selected, names[focus], normalize)
                note = 'Required desktop features are selected together.'
            elif key in ('\n', '\r', curses.KEY_ENTER):
                if selected:
                    return selected
                note = 'Select at least one component with Space.'
    return _terminal(show)


def prepare_media(describe):
    """Pause before installation so users can supply optional personal media."""
    def show(screen, curses, color):
        offset = 0
        media = describe()
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            if height < 12 or width < 48:
                _write(screen, 0, 'Enlarge the terminal (48 columns / 12 rows).', color)
                _write(screen, 2, 'Esc: cancel')
                key = screen.get_wch()
                if key in ('\x1b', 'q', 'Q'):
                    return False
                continue
            lines = [wrapped for line in media
                     for wrapped in (textwrap.wrap(line, width - 4) or [''])]
            count = height - 7
            offset = min(offset, max(0, len(lines) - count))
            _write(screen, 1, 'THE INDEX / OPTIONAL VIDEO AND MUSIC', color | curses.A_BOLD)
            for row, line in enumerate(lines[offset:offset + count], 3):
                _write(screen, row, line)
            _write(screen, height - 3, 'Enter: continue   R: recheck   Esc: cancel', color | curses.A_BOLD)
            _write(screen, height - 2, 'Up/Down: scroll   Both files are optional.', color)
            screen.refresh()
            key = screen.get_wch()
            if key in ('\n', '\r', curses.KEY_ENTER):
                return True
            if key in ('\x1b', 'q', 'Q'):
                return False
            if key in ('r', 'R'):
                media = describe()
            elif key in (curses.KEY_DOWN, 'j'):
                offset = min(offset + 1, max(0, len(lines) - count))
            elif key in (curses.KEY_UP, 'k'):
                offset = max(0, offset - 1)
    return _terminal(show)


def confirm_install(components, selected, packages, manager, no_packages, video=None, media=None):
    def show(screen, curses, color):
        offset = 0
        while True:
            screen.erase()
            height, width = screen.getmaxyx()
            if height < 10 or width < 48:
                _write(screen, 0, 'Enlarge the terminal to review installation.', color)
                _write(screen, 2, 'Esc: cancel')
                key = screen.get_wch()
                if key in ('\x1b', 'q', 'Q'):
                    return False
                continue
            lines = []
            for name, label in components.items():
                if name in selected:
                    lines.extend(textwrap.wrap('[x] ' + label, width - 4))
            lines += ['', 'Dependencies (' + ('already installed' if no_packages else manager) + '):']
            lines.extend(textwrap.wrap(', '.join(packages), width - 4))
            if video:
                lines += ['', *textwrap.wrap('Intro video: ' + str(video), width - 4)]
            if media:
                lines += ['', 'Optional video and music:']
                for line in media:
                    lines.extend(textwrap.wrap(line, width - 4) or [''])
            lines += ['', 'Your current cursor stays active.']
            count = height - 7
            offset = min(offset, max(0, len(lines) - count))
            _write(screen, 1, 'THE INDEX / REVIEW INSTALLATION', color | curses.A_BOLD)
            for row, line in enumerate(lines[offset:offset + count], 3):
                _write(screen, row, line)
            _write(screen, height - 2, 'Enter: INSTALL   Esc: cancel   Up/Down: scroll', color | curses.A_BOLD)
            screen.refresh()
            key = screen.get_wch()
            if key in ('\n', '\r', curses.KEY_ENTER):
                return True
            if key in ('\x1b', 'q', 'Q'):
                return False
            if key in (curses.KEY_DOWN, 'j'):
                offset = min(offset + 1, max(0, len(lines) - count))
            elif key in (curses.KEY_UP, 'k'):
                offset = max(0, offset - 1)
    return _terminal(show)
