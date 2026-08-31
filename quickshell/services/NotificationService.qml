pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property int maxNotifications: 10

    // Each entry is a stable JS snapshot:
    //
    // {
    //     id,
    //     appName,
    //     summary,
    //     body,
    //     appIcon,
    //     notification
    // }
    //
    // `notification` is the real Quickshell Notification object and is
    // only used when we need to dismiss it.
    property var notifications: []

    // The notification currently used by the Dynamic Island pill.
    property var latestNotification: null

    // Incremented whenever a notification is accepted.
    property int notificationSerial: 0

    readonly property int count: notifications.length


    function cleanValue(value) {
        if (value === undefined || value === null)
            return ""

        return String(value)
    }


    function makeSnapshot(notification) {
        return {
            id: notification.id,

            appName:
                cleanValue(notification.appName),

            summary:
                cleanValue(notification.summary),

            body:
                cleanValue(notification.body),

            appIcon:
                cleanValue(notification.appIcon),

            notification:
                notification
        }
    }


    function addNotification(notification) {
        if (!notification)
            return

        // Avoid duplicates.
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === notification.id)
                return
        }

        const updated = notifications.slice()

        // Maximum 10 notifications.
        while (updated.length >= maxNotifications) {
            const oldest = updated.shift()

            if (oldest
                && oldest.notification
                && typeof oldest.notification.dismiss === "function") {

                oldest.notification.dismiss()
            }
        }

        const snapshot = makeSnapshot(notification)

        updated.push(snapshot)

        notifications = updated
        latestNotification = snapshot

        notificationSerial += 1

        console.log(
            "[Notifications] Added:",
            snapshot.appName,
            "|",
            snapshot.summary,
            "|",
            snapshot.body,
            "Count:",
            notifications.length
        )
    }


    function removeNotification(notification) {
        if (!notification)
            return

        const notificationId = notification.id
        const updated = []

        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id !== notificationId)
                updated.push(notifications[i])
        }

        notifications = updated

        if (latestNotification
            && latestNotification.id === notificationId) {

            latestNotification =
                notifications.length > 0
                ? notifications[notifications.length - 1]
                : null
        }

        console.log(
            "[Notifications] Removed:",
            notificationId,
            "Remaining:",
            notifications.length
        )
    }


    function dismissNotification(notification) {
        if (!notification)
            return

        console.log(
            "[Notifications] Dismissing:",
            notification.id
        )

        // Remove immediately from our UI.
        removeNotification(notification)

        // Then dismiss the actual DBus notification.
        if (notification.notification
            && typeof notification.notification.dismiss === "function") {

            notification.notification.dismiss()
        }
    }


    function clearAll() {
        const currentNotifications = notifications.slice()

        // Clear UI immediately.
        notifications = []
        latestNotification = null

        // Then dismiss actual notifications.
        for (let i = 0; i < currentNotifications.length; i++) {
            const item = currentNotifications[i]

            if (item
                && item.notification
                && typeof item.notification.dismiss === "function") {

                item.notification.dismiss()
            }
        }

        console.log("[Notifications] Cleared all notifications")
    }
}
