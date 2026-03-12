module app;

import ddbus.thin : Connection, Message, connectToBus, ObjectPath, busName, interfaceName;
import ddbus.router : MessageRouter, MessagePattern, registerRouter;

import notifier : Notifier;
import linkappender : appendLink;
import urlfilter : extractUrl;

import std.stdio : writeln, stderr;
import std.string : strip;
import std.typecons : Tuple;
import std.getopt;

@safe:

private immutable string gPasteDest = "org.gnome.GPaste";
private immutable string gPastePath = "/org/gnome/GPaste";
private immutable string gPasteIface = "org.gnome.GPaste2";
private immutable string gPasteSignal = "Update";
private immutable string gPasteGetItem = "GetElementAtIndex";

private Connection gBusConn;
private Notifier gNotifier;

void main(string[] args) @trusted
{
    string outputFile = "~/links.txt"; // default
    auto helpInfo = getopt(args, "path|p", "This refers to the output file path.", &outputFile);
    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("Information about the program.", helpInfo.options);
    }

    gBusConn = connectToBus();

    gNotifier = new Notifier(&gBusConn,
        (string url, bool accepted) @trusted {
        if (accepted)
        {
            if (!appendLink(url, outputFile))
                stderr.writeln("[cliplink] Failed to write: ", url);
            else
                writeln("[cliplink] Saved: ", url);
        }
        else
            writeln("[cliplink] Skipped: ", url);
    }
    );

    setupGPasteWatcher();

    import ddbus.bus : simpleMainLoop;

    simpleMainLoop(gBusConn);
}

private void setupGPasteWatcher() @trusted
{
    auto router = new MessageRouter();

    auto pastePattern = MessagePattern(
        ObjectPath(gPastePath),
        interfaceName(gPasteIface),
        gPasteSignal,
        true
    );

    router.setHandler!(void, string, string, ulong)(pastePattern,
        (string action, string target, ulong index) @trusted {
        if (action != "REPLACE" || target != "ALL")
            return;

        auto msg = Message(
            busName(gPasteDest),
            ObjectPath(gPastePath),
            interfaceName(gPasteIface),
            gPasteGetItem
        );
        msg.build(ulong(0));

        auto reply = gBusConn.sendWithReplyBlocking(msg);
        auto result = reply.readTuple!(Tuple!(string, string))();
        string content = result[1].strip();

        string url = extractUrl(content);
        if (url !is null)
            gNotifier.submit(url);
    }
    );

    auto actionPattern = MessagePattern(
        ObjectPath("/org/freedesktop/Notifications"),
        interfaceName("org.freedesktop.Notifications"),
        "ActionInvoked",
        true
    );

    router.setHandler!(void, uint, string)(actionPattern,
        (uint id, string action) @trusted {
        gNotifier.onActionInvoked(id, action);
    }
    );

    auto closedPattern = MessagePattern(
        ObjectPath("/org/freedesktop/Notifications"),
        interfaceName("org.freedesktop.Notifications"),
        "NotificationClosed",
        true
    );

    router.setHandler!(void, uint, uint)(closedPattern,
        (uint id, uint reason) @trusted {
        gNotifier.onNotificationClosed(id, reason);
    }
    );

    registerRouter(gBusConn, router);

    import ddbus.c_lib : dbus_bus_add_match, dbus_connection_flush;
    import std.string : toStringz;

    string pasteRule = "type='signal',interface='org.gnome.GPaste2',member='Update'";
    dbus_bus_add_match(gBusConn.conn, pasteRule.toStringz, null);
    dbus_connection_flush(gBusConn.conn);

    auto primeMsg = Message(
        busName(gPasteDest),
        ObjectPath(gPastePath),
        interfaceName(gPasteIface),
        gPasteGetItem
    );
    primeMsg.build(ulong(0));
    gBusConn.sendWithReplyBlocking(primeMsg);
}
