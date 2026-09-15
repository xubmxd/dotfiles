import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: dataRoot

    property var playersList: Mpris.players.values
    property var activePlayer: resolveActivePlayer()

    function hasValidMetadata(player) {
        if (!player) return false;
        // Ensure the player is exposing an actual track title
        return player.trackTitle !== undefined && player.trackTitle !== null && player.trackTitle.trim() !== "";
    }

    readonly property bool hasTrack: activePlayer !== null && hasValidMetadata(activePlayer)
    readonly property bool isPlaying: activePlayer !== null && activePlayer.playbackState === 1
    
    // UI strings safely fall back, but do not trigger hasTrack
    readonly property string trackTitle: hasTrack ? activePlayer.trackTitle : "Unknown Track"
    readonly property string trackArtist: (activePlayer && activePlayer.trackArtist && activePlayer.trackArtist.trim() !== "") ? activePlayer.trackArtist : "Unknown Artist"
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    
    property real trackProgress: 0
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"

    function resolveActivePlayer() {
        if (!playersList || playersList.length === 0) return null;

        // 1. Prioritize playing players that have valid metadata
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].playbackState === 1 && hasValidMetadata(playersList[i])) {
                return playersList[i];
            }
        }

        // 2. Fallback to paused players that have valid metadata
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].playbackState === 2 && hasValidMetadata(playersList[i])) {
                return playersList[i];
            }
        }

        // We explicitly do not fallback to empty controllable players 
        // to prevent idle browsers from holding the Dynamic Island open.
        return null;
    }

    // --- THE FIX ---
    // Automatically detect if the player is emitting seconds, milliseconds, or microseconds
    function toSeconds(rawValue) {
        const v = Number(rawValue) || 0;
        if (v <= 0) return 0;
        if (v < 10000) return v;                   // It's in Seconds
        if (v < 10000000) return v / 1000;         // It's in Milliseconds
        return v / 1000000;                        // It's in Microseconds
    }

    function formatTime(rawValue) {
        const totalSeconds = Math.max(0, Math.floor(toSeconds(rawValue)));
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = Math.floor(totalSeconds % 60);
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    function syncProgress() {
        if (!activePlayer || !hasTrack) {
            trackProgress = 0;
            timePlayed = "0:00";
            timeTotal = "0:00";
            return;
        }

        const currentPos = Number(activePlayer.position) || 0;
        const totalLength = Number(activePlayer.length) || 0;

        if (totalLength > 0) {
            // The division works perfectly regardless of unit, as long as both match
            trackProgress = Math.max(0, Math.min(1, currentPos / totalLength));
            timePlayed = formatTime(currentPos);
            timeTotal = formatTime(totalLength);
        } else {
            trackProgress = 0;
            timePlayed = formatTime(currentPos);
            timeTotal = "0:00";
        }
    }

    property Timer progressPoller: Timer {
        interval: 500
        running: dataRoot.isPlaying
        repeat: true
        onTriggered: dataRoot.syncProgress()
    }

    onActivePlayerChanged: syncProgress()
}
