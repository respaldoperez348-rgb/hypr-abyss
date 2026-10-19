#!/usr/bin/env python3
import subprocess, json, sys, os

MUTE_FILE = '/dev/shm/notif_muted'
DND_FILE = '/dev/shm/dnd_active'

def is_muted():
    if os.path.exists(MUTE_FILE) or os.path.exists(DND_FILE):
        return True
    try:
        return subprocess.check_output(['dunstctl', 'is-paused'], text=True, stderr=subprocess.DEVNULL).strip() == 'true'
    except Exception:
        return False

def get_notifications():
    try:
        out = subprocess.check_output(['dunstctl', 'history'], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(out)
        notifications = []
        raw_list = data.get('data', [[]])[0]
        for item in raw_list:
            nid = item.get('id', {}).get('data', 0)
            appname = item.get('appname', {}).get('data', 'Sistema')
            summary = item.get('summary', {}).get('data', '')
            if appname in ('Volume', 'Brightness') or summary.startswith(('Volume:', 'Brightness:')):
                continue
            body = item.get('body', {}).get('data', '')
            icon = item.get('icon_path', {}).get('data', '')
            short_body = body.split('\n')[0] if body else ''
            if len(short_body) > 55:
                short_body = short_body[:52] + '...'
            notifications.append({
                'id': nid,
                'appname': appname,
                'summary': summary,
                'body': short_body,
                'full_body': body,
                'icon': icon
            })
        
        return {'dnd': is_muted(), 'notifications': notifications}
    except Exception:
        return {'dnd': is_muted(), 'notifications': []}

def clear_all():
    subprocess.run(['dunstctl', 'history-clear'], stderr=subprocess.DEVNULL)
    subprocess.run(['dunstctl', 'close-all'], stderr=subprocess.DEVNULL)
    subprocess.run(['pkill', '-f', 'message-new-instant'], stderr=subprocess.DEVNULL)

def dismiss(nid):
    subprocess.run(['dunstctl', 'history-rm', str(nid)], stderr=subprocess.DEVNULL)
    subprocess.run(['dunstctl', 'close', str(nid)], stderr=subprocess.DEVNULL)
    subprocess.run(['pkill', '-f', 'message-new-instant'], stderr=subprocess.DEVNULL)

def toggle_dnd():
    if is_muted():
        if os.path.exists(MUTE_FILE):
            os.remove(MUTE_FILE)
        if os.path.exists(DND_FILE):
            os.remove(DND_FILE)
        subprocess.run(['dunstctl', 'set-paused', 'false'], stderr=subprocess.DEVNULL)
        return False
    else:
        with open(MUTE_FILE, 'w') as f:
            f.write('1\n')
        with open(DND_FILE, 'w') as f:
            f.write('1\n')
        subprocess.run(['pkill', '-f', 'message-new-instant'], stderr=subprocess.DEVNULL)
        subprocess.run(['dunstctl', 'set-paused', 'true'], stderr=subprocess.DEVNULL)
        return True

if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'list'
    if cmd == 'clear':
        clear_all()
        print(json.dumps({'success': True, 'notifications': []}))
    elif cmd == 'dismiss':
        if len(sys.argv) > 2:
            dismiss(sys.argv[2])
        print(json.dumps(get_notifications()))
    elif cmd == 'toggle_dnd':
        toggle_dnd()
        print(json.dumps(get_notifications()))
    else:
        print(json.dumps(get_notifications()))
