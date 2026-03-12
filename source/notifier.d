module notifier;

import ddbus.thin : Connection, Message, ObjectPath, busName, interfaceName, DBusAny, Variant, variant;

import std.datetime : MonoTime;

@safe:

private immutable string notifyDest = "org.freedesktop.Notifications";
private immutable string notifyPath = "/org/freedesktop/Notifications";
private immutable string notifyIface = "org.freedesktop.Notifications";

alias OnChoice = void delegate(string url, bool accepted) @safe;

final class Notifier
{
private:
    string[] queue;
    bool notificationOpen;
    OnChoice onChoice;
    Connection* conn;
    string activeUrl;
    MonoTime lastSignalTime;
    bool actionHandled;
    uint activeId;

public:
    this(Connection* dbusConn, OnChoice callback)
    {
        conn = dbusConn;
        onChoice = callback;
    }

    void submit(string url)
    {
        auto now = MonoTime.currTime;
        if ((now - lastSignalTime).total!"msecs" < 500 && queue.length > 0 && queue[$ - 1] == url)
            return;
        lastSignalTime = now;

        queue ~= url;
        if (!notificationOpen)
            showNext();
    }

    void onActionInvoked(uint id, string action) @trusted
    {
        if (id != activeId)
            return;

        actionHandled = true;

        auto closeMsg = Message(
            busName(notifyDest),
            ObjectPath(notifyPath),
            interfaceName(notifyIface),
            "CloseNotification"
        );
        closeMsg.build(id);
        (*conn).sendBlocking(closeMsg);

        notificationClosed(action == "save");
    }

    void onNotificationClosed(uint id, uint reason) @trusted
    {
        if (id != activeId)
            return;

        if (reason == 2 && !actionHandled)
            notificationClosed(false);

        actionHandled = false;
    }

private:
    void showNext()
    {
        if (queue.length == 0)
            return;

        activeUrl = queue[0];
        queue = queue[1 .. $];
        notificationOpen = true;
        actionHandled = false;
        sendNotification(activeUrl);
    }

    void sendNotification(string url) @trusted
    {
        auto msg = Message(
            busName(notifyDest),
            ObjectPath(notifyPath),
            interfaceName(notifyIface),
            "Notify"
        );

        string[] actions = ["save", "Save", "dismiss", "Dismiss"];
        Variant!DBusAny[string] hints;
        hints["urgency"] = variant(DBusAny(ubyte(2)));

        msg.build(
            "cliplink",
            uint(0),
            "edit-copy",
            "Save link?",
            url,
            actions,
            hints,
            int(0)
        );

        auto reply = (*conn).sendWithReplyBlocking(msg);
        activeId = reply.read!uint();
    }

    void notificationClosed(bool accepted)
    {
        notificationOpen = false;
        onChoice(activeUrl, accepted);
        showNext();
    }
}
