pragma Singleton

import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    readonly property int maxNotifications: 10

    property var notifications: []

    readonly property int count: notifications.length


    function addNotification(notification) {

        // Avoid adding the same notification twice.
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === notification.id)
                return
        }

        const updated = notifications.slice()

        // Keep only 10 notifications.
        // Remove the oldest before adding a new one.
        while (updated.length >= maxNotifications) {
            const oldest = updated.shift()

            if (oldest)
                oldest.dismiss()
        }

        updated.push(notification)

        notifications = updated

        console.log(
            "[Notifications] Added:",
            notification.appName,
            "-",
            notification.summary,
            "Count:",
            notifications.length
        )
    }


    function removeNotification(notification) {

        const updated = []

        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id !== notification.id)
                updated.push(notifications[i])
        }

        notifications = updated
    }


    function dismissNotification(notification) {

        if (!notification)
            return

        removeNotification(notification)

        notification.dismiss()
    }


    function clearAll() {

        const currentNotifications = notifications.slice()

        // Clear our UI first.
        notifications = []

        // Then dismiss notifications from the server.
        for (let i = 0; i < currentNotifications.length; i++) {

            if (currentNotifications[i])
                currentNotifications[i].dismiss()
        }

        console.log("[Notifications] Cleared all notifications")
    }
}
