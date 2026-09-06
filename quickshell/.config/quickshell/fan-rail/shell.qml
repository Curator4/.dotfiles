import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool railOpen: false
    property bool pending: false
    property bool processStarted: false
    property int highlightedIndex: 0
    property bool userNavigated: false
    property string activeControl: ""
    property string failedControl: ""
    property string commandError: ""
    property var targetScreen: null

    property color paletteBackground: "#08090b"
    property color paletteForeground: "#b4bac2"
    property color paletteAccent: "#3e6fa8"
    property color paletteBlack: "#14161a"
    property color paletteRed: "#6473a8"
    property color paletteGreen: "#62a0b8"
    property color paletteYellow: "#8ca3cc"
    property color paletteBlue: "#3e6fa8"
    property color paletteMagenta: "#7078c0"
    property color paletteCyan: "#5b8fc7"
    property color paletteBrightBlack: "#3c4558"
    property color paletteBrightBlue: "#5b93d6"

    property var confirmedState: ({
            power: false,
            fault: null,
            mode: "straight",
            level: 1,
            speed: 1,
            horizontal_swing: false,
            vertical_swing: false,
            updated_at: null
        })

    readonly property string fanExecutable: "/home/curator/.local/bin/xiaomi-fan"
    readonly property int controlCount: 8

    function selectTargetScreen(): void {
        let selected = null;
        for (let index = 0; index < Quickshell.screens.length; index++) {
            if (Quickshell.screens[index].name === "DP-4") {
                selected = Quickshell.screens[index];
                break;
            }
        }
        targetScreen = selected;
    }

    function validColor(value): bool {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value);
    }

    function applyTheme(text): void {
        try {
            const next = JSON.parse(text);
            const required = ["background", "foreground", "accent", "black", "red", "green", "yellow", "blue", "magenta", "cyan", "bright_black", "bright_blue"];
            for (let index = 0; index < required.length; index++) {
                if (!validColor(next[required[index]]))
                    throw new Error("invalid palette field: " + required[index]);
            }

            paletteBackground = next.background;
            paletteForeground = next.foreground;
            paletteAccent = next.accent;
            paletteBlack = next.black;
            paletteRed = next.red;
            paletteGreen = next.green;
            paletteYellow = next.yellow;
            paletteBlue = next.blue;
            paletteMagenta = next.magenta;
            paletteCyan = next.cyan;
            paletteBrightBlack = next.bright_black;
            paletteBrightBlue = next.bright_blue;
            console.info("fan-rail: palette loaded");
        } catch (error) {
            console.warn("fan-rail: retaining previous palette:", error);
        }
    }

    function normalizedState(text): var {
        const parsed = JSON.parse(text);
        if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed))
            throw new Error("fan state is not an object");
        if (typeof parsed.power !== "boolean")
            throw new Error("fan state has invalid power");
        if (typeof parsed.level !== "number" || parsed.level % 1 !== 0 || parsed.level < 1 || parsed.level > 4)
            throw new Error("fan state has invalid level");
        if (typeof parsed.speed !== "number" || parsed.speed < 1 || parsed.speed > 100)
            throw new Error("fan state has invalid speed");
        if (parsed.mode !== "straight" && parsed.mode !== "natural")
            throw new Error("fan state has invalid mode");
        if (typeof parsed.horizontal_swing !== "boolean" || typeof parsed.vertical_swing !== "boolean")
            throw new Error("fan state has invalid swing values");
        if (typeof parsed.fault !== "number")
            throw new Error("fan state has invalid fault");

        return {
            power: parsed.power,
            fault: parsed.fault,
            mode: parsed.mode,
            level: parsed.level,
            speed: parsed.speed,
            horizontal_swing: parsed.horizontal_swing,
            vertical_swing: parsed.vertical_swing,
            updated_at: typeof parsed.updated_at === "number" ? parsed.updated_at : null
        };
    }

    function applyCachedState(text): void {
        try {
            confirmedState = normalizedState(text);
            if (failedControl === "cache") {
                failedControl = "";
                commandError = "";
            }
        } catch (error) {
            failedControl = "cache";
            commandError = "Cache read failed: " + String(error);
            console.warn("fan-rail:", commandError);
        }
    }

    function setRailOpen(nextOpen): void {
        userNavigated = false;
        if (nextOpen) {
            if (!railOpen)
                statusFile.reload();
            railOpen = true;
            Qt.callLater(() => movingRail.forceActiveFocus());
        } else {
            railOpen = false;
        }
    }

    function moveHighlight(offset): void {
        userNavigated = true;
        highlightedIndex = (highlightedIndex + offset + controlCount) % controlCount;
    }

    function activateHighlighted(): void {
        if (pending)
            return;

        switch (highlightedIndex) {
        case 0:
            requestPower();
            break;
        case 1:
        case 2:
        case 3:
        case 4:
            requestLevel(highlightedIndex);
            break;
        case 5:
            requestMode();
            break;
        case 6:
            requestSwing("horizontal", confirmedState.horizontal_swing);
            break;
        case 7:
            requestSwing("vertical", confirmedState.vertical_swing);
            break;
        }
    }

    function startCommand(control, arguments): void {
        if (pending)
            return;

        pending = true;
        processStarted = false;
        activeControl = control;
        failedControl = "";
        commandError = "";
        const command = [fanExecutable, "--json"].concat(arguments);
        console.info("fan-rail: launching", JSON.stringify(command));
        fanProcess.exec(command);
    }

    function requestPower(): void {
        startCommand("power", [confirmedState.power ? "off" : "on"]);
    }

    function requestLevel(level): void {
        startCommand("level-" + level, ["level", String(level)]);
    }

    function requestMode(): void {
        startCommand("mode", ["mode", confirmedState.mode === "straight" ? "natural" : "straight"]);
    }

    function requestSwing(axis, enabled): void {
        startCommand(axis, ["swing", axis, enabled ? "off" : "on"]);
    }

    function shortError(text, fallback): string {
        const clean = String(text || "").trim().replace(/\s+/g, " ");
        if (clean === "")
            return fallback;
        return clean.length > 140 ? clean.slice(0, 137) + "..." : clean;
    }

    function finishCommand(exitCode, standardOutput, standardError): void {
        const finishedControl = activeControl;
        if (exitCode !== 0) {
            failedControl = finishedControl;
            commandError = shortError(standardError, "Fan command failed with exit " + exitCode);
        } else {
            try {
                confirmedState = normalizedState(standardOutput);
                failedControl = "";
                commandError = "";
            } catch (error) {
                failedControl = finishedControl;
                commandError = "Invalid fan reply: " + shortError(String(error), "malformed JSON");
            }
        }

        pending = false;
        processStarted = false;
        activeControl = "";
    }

    function commandFailed(control): bool {
        return failedControl === control || failedControl === "cache";
    }

    function powerTip(): string {
        const next = confirmedState.power ? "off" : "on";
        return "Turn fan " + next + "  ·  xiaomi-fan --json " + next;
    }

    function modeTip(): string {
        const next = confirmedState.mode === "straight" ? "natural" : "straight";
        return "Straight = steady stream, natural = ebbing breeze\nUse " + next + " airflow  ·  xiaomi-fan --json mode " + next;
    }

    function swingTip(axis, enabled): string {
        const next = enabled ? "off" : "on";
        return (next === "on" ? "Start " : "Stop ") + axis + " swing  ·  xiaomi-fan --json swing " + axis + " " + next;
    }

    Component.onCompleted: {
        selectTargetScreen();
        applyTheme(themeFile.text());
        applyCachedState(statusFile.text());
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            root.selectTargetScreen();
        }
    }

    FileView {
        id: themeFile
        path: "/home/curator/.config/eww/theme-colors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyTheme(text())
        onLoadFailed: error => console.warn("fan-rail: palette load failed:", error)
    }

    FileView {
        id: statusFile
        path: "/home/curator/.local/state/xiaomi-fan/status.json"
        blockLoading: true
        onLoaded: root.applyCachedState(text())
        onLoadFailed: error => {
            root.failedControl = "cache";
            root.commandError = "Cache read failed: " + String(error);
        }
    }

    Process {
        id: fanProcess

        stdout: StdioCollector {
            id: standardOutput
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: standardError
            waitForEnd: true
        }

        onStarted: root.processStarted = true
        onExited: exitCode => {
            if (root.pending)
                root.finishCommand(exitCode, standardOutput.text, standardError.text);
        }
        onRunningChanged: {
            if (!running && root.pending && !root.processStarted) {
                root.failedControl = root.activeControl;
                root.commandError = "Unable to start fan command";
                root.pending = false;
                root.activeControl = "";
            }
        }
    }

    IpcHandler {
        target: "fan"

        function toggle(): void {
            root.setRailOpen(!root.railOpen);
        }
        function open(): void {
            root.setRailOpen(true);
        }
        function close(): void {
            root.setRailOpen(false);
        }
    }

    PanelWindow {
        id: panel

        screen: root.targetScreen
        visible: root.targetScreen !== null
        implicitWidth: 360
        color: "transparent"
        WlrLayershell.keyboardFocus: root.railOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusiveZone: 0
        aboveWindows: true
        surfaceFormat.opaque: false

        anchors {
            top: true
            right: true
            bottom: true
        }

        mask: Region {
            item: frame
            Region {
                item: spine
            }
        }

        Item {
            id: movingRail
            width: panel.width
            height: panel.height
            x: root.railOpen ? 0 : 96
            focus: root.railOpen

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    root.moveHighlight(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    root.moveHighlight(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (!event.isAutoRepeat)
                        root.activateHighlighted();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.setRailOpen(false);
                    event.accepted = true;
                }
            }

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: spine
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 3
                color: root.paletteAccent
            }

            ChamferFrame {
                id: frame
                width: implicitWidth
                height: implicitHeight
                x: panel.width - width - 7
                y: Math.round((panel.height - height) / 2)
                contentWidth: controls.implicitWidth
                contentHeight: controls.implicitHeight
                padding: 12
                accentColor: root.paletteAccent
                surfaceColor: root.paletteBackground
                innerBorderColor: root.paletteBrightBlack

                Column {
                    id: controls
                    x: frame.padding
                    y: frame.padding
                    width: implicitWidth
                    height: implicitHeight
                    spacing: 7

                    Item {
                        width: 56
                        height: 40

                        Shape {
                            id: fanCrest
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 27
                            height: 27
                            fillMode: Shape.PreserveAspectFit

                            // Font Awesome Free 6.7.2 "fan", CC BY 4.0.
                            // https://fontawesome.com/icons/fan
                            ShapePath {
                                fillColor: root.paletteAccent
                                strokeWidth: -1

                                PathSvg {
                                    path: "M258.6 0c-1.7 0-3.4 .1-5.1 .5C168 17 115.6 102.3 130.5 189.3c2.9 17 8.4 32.9 15.9 47.4L32 224l-2.6 0C13.2 224 0 237.2 0 253.4c0 1.7 .1 3.4 .5 5.1C17 344 102.3 396.4 189.3 381.5c17-2.9 32.9-8.4 47.4-15.9L224 480l0 2.6c0 16.2 13.2 29.4 29.4 29.4c1.7 0 3.4-.1 5.1-.5C344 495 396.4 409.7 381.5 322.7c-2.9-17-8.4-32.9-15.9-47.4L480 288l2.6 0c16.2 0 29.4-13.2 29.4-29.4c0-1.7-.1-3.4-.5-5.1C495 168 409.7 115.6 322.7 130.5c-17 2.9-32.9 8.4-47.4 15.9L288 32l0-2.6C288 13.2 274.8 0 258.6 0zM256 224a32 32 0 1 1 0 64 32 32 0 1 1 0-64z"
                                }
                            }
                        }

                        RotationAnimator {
                            id: fanIntro
                            target: fanCrest
                            from: 0
                            to: 360
                            duration: 650
                        }

                        RotationAnimator {
                            target: fanCrest
                            running: root.railOpen && root.confirmedState.power
                            from: 0
                            to: 360
                            duration: 2400 - root.confirmedState.level * 300
                            loops: Animation.Infinite
                        }

                        Connections {
                            target: root

                            function onRailOpenChanged(): void {
                                if (!root.railOpen) {
                                    fanIntro.stop();
                                    fanCrest.rotation = 0;
                                } else if (!root.confirmedState.power) {
                                    fanIntro.restart();
                                }
                            }

                            function onConfirmedStateChanged(): void {
                                if (root.railOpen && !root.confirmedState.power)
                                    fanIntro.restart();
                            }
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "FAN"
                            color: root.paletteForeground
                            opacity: 0.72
                            font.family: "JetBrains Mono"
                            font.pixelSize: 8
                            font.letterSpacing: 1.8
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                        }
                    }

                    FanButton {
                        iconName: "power"
                        label: "Power"
                        highlighted: root.railOpen && root.highlightedIndex === 0
                        keyboardHighlight: root.userNavigated
                        toolTipText: root.powerTip()
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.confirmedState.power ? root.paletteGreen : root.paletteRed
                        errorColor: root.paletteRed
                        selected: root.confirmedState.power
                        pending: root.pending && root.activeControl === "power"
                        failed: root.commandFailed("power")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 0
                        onInvoked: root.requestPower()
                    }

                    FanButton {
                        iconName: "level-1"
                        label: "Level 1"
                        highlighted: root.railOpen && root.highlightedIndex === 1
                        keyboardHighlight: root.userNavigated
                        toolTipText: "Quiet  ·  xiaomi-fan --json level 1"
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteAccent
                        errorColor: root.paletteRed
                        selected: root.confirmedState.level === 1
                        pending: root.pending && root.activeControl === "level-1"
                        failed: root.commandFailed("level-1")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 1
                        onInvoked: root.requestLevel(1)
                    }

                    FanButton {
                        iconName: "level-2"
                        label: "Level 2"
                        highlighted: root.railOpen && root.highlightedIndex === 2
                        keyboardHighlight: root.userNavigated
                        toolTipText: "Medium  ·  xiaomi-fan --json level 2"
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteAccent
                        errorColor: root.paletteRed
                        selected: root.confirmedState.level === 2
                        pending: root.pending && root.activeControl === "level-2"
                        failed: root.commandFailed("level-2")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 2
                        onInvoked: root.requestLevel(2)
                    }

                    FanButton {
                        iconName: "level-3"
                        label: "Level 3"
                        highlighted: root.railOpen && root.highlightedIndex === 3
                        keyboardHighlight: root.userNavigated
                        toolTipText: "Fast  ·  xiaomi-fan --json level 3"
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteAccent
                        errorColor: root.paletteRed
                        selected: root.confirmedState.level === 3
                        pending: root.pending && root.activeControl === "level-3"
                        failed: root.commandFailed("level-3")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 3
                        onInvoked: root.requestLevel(3)
                    }

                    FanButton {
                        iconName: "level-4"
                        label: "Level 4"
                        highlighted: root.railOpen && root.highlightedIndex === 4
                        keyboardHighlight: root.userNavigated
                        toolTipText: "Turbo  ·  xiaomi-fan --json level 4"
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteAccent
                        errorColor: root.paletteRed
                        selected: root.confirmedState.level === 4
                        pending: root.pending && root.activeControl === "level-4"
                        failed: root.commandFailed("level-4")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 4
                        onInvoked: root.requestLevel(4)
                    }

                    FanButton {
                        iconName: root.confirmedState.mode === "straight" ? "mode-straight" : "mode-natural"
                        label: "Airflow mode"
                        highlighted: root.railOpen && root.highlightedIndex === 5
                        keyboardHighlight: root.userNavigated
                        toolTipText: root.modeTip()
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteMagenta
                        errorColor: root.paletteRed
                        selected: root.confirmedState.mode === "natural"
                        pending: root.pending && root.activeControl === "mode"
                        failed: root.commandFailed("mode")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 5
                        onInvoked: root.requestMode()
                    }

                    FanButton {
                        iconName: "horizontal"
                        label: "Horizontal swing"
                        highlighted: root.railOpen && root.highlightedIndex === 6
                        keyboardHighlight: root.userNavigated
                        toolTipText: root.swingTip("horizontal", root.confirmedState.horizontal_swing)
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteCyan
                        errorColor: root.paletteRed
                        selected: root.confirmedState.horizontal_swing
                        pending: root.pending && root.activeControl === "horizontal"
                        failed: root.commandFailed("horizontal")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 6
                        onInvoked: root.requestSwing("horizontal", root.confirmedState.horizontal_swing)
                    }

                    FanButton {
                        iconName: "vertical"
                        label: "Vertical swing"
                        highlighted: root.railOpen && root.highlightedIndex === 7
                        keyboardHighlight: root.userNavigated
                        toolTipText: root.swingTip("vertical", root.confirmedState.vertical_swing)
                        errorMessage: root.commandError
                        surfaceColor: root.paletteBlack
                        foregroundColor: root.paletteForeground
                        mutedColor: root.paletteBrightBlack
                        accentColor: root.paletteBrightBlue
                        errorColor: root.paletteRed
                        selected: root.confirmedState.vertical_swing
                        pending: root.pending && root.activeControl === "vertical"
                        failed: root.commandFailed("vertical")
                        enabled: !root.pending
                        onHovered: root.highlightedIndex = 7
                        onInvoked: root.requestSwing("vertical", root.confirmedState.vertical_swing)
                    }
                }
            }
        }
    }
}
