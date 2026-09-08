#!/usr/bin/env python3
"""Read-only, content-free correlation of notification replies to sender PIDs.

This intentionally observes only Notify routing metadata and its uint return ID.
It never decodes notification arguments or writes provenance to disk.
"""
import argparse
import collections
import json
import sys
import time

PROTOCOL = 1
NOTIFICATIONS = "org.freedesktop.Notifications"
DBUS = "org.freedesktop.DBus"
MAX_PENDING = 128
PENDING_SECONDS = 8.0


def positive_int(value):
    try:
        value = int(value)
    except (TypeError, ValueError):
        return None
    return value if value > 0 else None


class Correlator:
    """Pure, bounded correlator; kept separate to make privacy behavior testable."""
    def __init__(self, pid_for_sender, now=time.monotonic):
        self.pid_for_sender = pid_for_sender
        self.now = now
        self.pending = collections.OrderedDict()

    def expire(self):
        cutoff = self.now() - PENDING_SECONDS
        while self.pending:
            key, (_, created) = next(iter(self.pending.items()))
            if created >= cutoff:
                break
            self.pending.pop(key)

    def observe_call(self, sender, serial):
        self.expire()
        if not sender or positive_int(serial) is None:
            return
        try:
            pid = positive_int(self.pid_for_sender(sender))
        except Exception:
            return
        if pid is None:
            return
        self.pending[(str(sender), int(serial))] = (pid, self.now())
        while len(self.pending) > MAX_PENDING:
            self.pending.popitem(last=False)

    def observe_return(self, destination, reply_serial, notification_id):
        self.expire()
        key = (str(destination or ""), positive_int(reply_serial))
        if key[1] is None:
            return None
        pending = self.pending.pop(key, None)
        identifier = positive_int(notification_id)
        if pending is None or identifier is None:
            return None
        return {"version": PROTOCOL, "event": "provenance",
                "notificationId": identifier, "pid": pending[0]}


def message_type(message):
    return message.get_type()


def first_uint_argument(message):
    try:
        arguments = message.get_args_list(byte_arrays=True)
    except Exception:
        return None
    return arguments[0] if len(arguments) == 1 else None


class Observer:
    def __init__(self):
        import dbus
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
        DBusGMainLoop(set_as_default=True)
        self.dbus = dbus
        self.GLib = GLib
        self.control = dbus.SessionBus(private=True)
        self.owner = self.current_owner()
        self.correlator = Correlator(self.sender_pid)
        self.monitor = dbus.SessionBus(private=True)
        self.monitor.add_message_filter(self.on_message)

    def current_owner(self):
        owner = self.control.call_blocking(DBUS, "/org/freedesktop/DBus", DBUS,
            "GetNameOwner", "s", (NOTIFICATIONS,))
        if not isinstance(owner, str) or not owner.startswith(":"):
            raise RuntimeError("notification service owner unavailable")
        return owner

    def sender_pid(self, unique_name):
        return self.control.call_blocking(DBUS, "/org/freedesktop/DBus", DBUS,
            "GetConnectionUnixProcessID", "s", (unique_name,))

    def start(self):
        rules = [
            "type='method_call',destination='%s',interface='%s',member='Notify'" %
                (NOTIFICATIONS, NOTIFICATIONS),
            "type='method_return',sender='%s'" % self.owner,
        ]
        self.monitor.call_blocking(DBUS, "/org/freedesktop/DBus",
            "org.freedesktop.DBus.Monitoring", "BecomeMonitor", "asu",
            (rules, 0))

    def on_message(self, _connection, message):
        # dbus.lowlevel constants are used only after import succeeds.
        if message_type(message) == self.dbus.lowlevel.MESSAGE_TYPE_METHOD_CALL:
            if (message.get_destination() == NOTIFICATIONS
                    and message.get_interface() == NOTIFICATIONS
                    and message.get_member() == "Notify"):
                self.correlator.observe_call(message.get_sender(), message.get_serial())
        elif message_type(message) == self.dbus.lowlevel.MESSAGE_TYPE_METHOD_RETURN:
            if message.get_sender() == self.owner:
                event = self.correlator.observe_return(message.get_destination(),
                    message.get_reply_serial(), first_uint_argument(message))
                if event is not None:
                    print(json.dumps(event, separators=(",", ":")), flush=True)
        # Monitoring connections are read-only and must never synthesize an
        # error reply for traffic they observed.
        return self.dbus.lowlevel.HANDLER_RESULT_HANDLED

    def run(self):
        self.start()
        self.GLib.timeout_add_seconds(1, self.expire)
        self.GLib.MainLoop().run()

    def expire(self):
        self.correlator.expire()
        return True


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--help", action="help")
    parser.parse_args()
    try:
        Observer().run()
    except Exception as error:
        # Diagnostics deliberately include no notification message data.
        print("notification provenance observer unavailable: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
