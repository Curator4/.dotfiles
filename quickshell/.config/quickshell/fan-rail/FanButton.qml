import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string iconName: ""
    property string label: ""
    property string toolTipText: ""
    property string errorMessage: ""
    property color surfaceColor: "#14161a"
    property color foregroundColor: "#b4bac2"
    property color mutedColor: "#3c4558"
    property color accentColor: "#3e6fa8"
    property color errorColor: "#6473a8"
    property bool selected: false
    property bool highlighted: false
    property bool pending: false
    property bool failed: false

    signal invoked
    signal hovered

    implicitWidth: 56
    implicitHeight: 56
    opacity: enabled || pending ? 1 : 0.38
    scale: pointer.pressed ? 0.96 : (pointer.containsMouse || highlighted) && enabled ? 1.045 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 140
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutCubic
        }
    }

    function mix(first, second, amount): color {
        return Qt.rgba(first.r + (second.r - first.r) * amount, first.g + (second.g - first.g) * amount, first.b + (second.b - first.b) * amount, first.a + (second.a - first.a) * amount);
    }

    function repaint(): void {
        face.requestPaint();
        glyphCanvas.requestPaint();
        spinnerCanvas.requestPaint();
    }

    onSelectedChanged: repaint()
    onHighlightedChanged: repaint()
    onPendingChanged: repaint()
    onEnabledChanged: repaint()
    onSurfaceColorChanged: repaint()
    onForegroundColorChanged: repaint()
    onMutedColorChanged: repaint()
    onAccentColorChanged: repaint()
    onIconNameChanged: repaint()

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            const cut = 7;
            const inset = 1;
            const right = width - inset;
            const bottom = height - inset;
            const emphasized = root.selected || root.highlighted || pointer.containsMouse;
            const fill = root.mix(root.surfaceColor, root.accentColor, root.selected ? 0.26 : root.highlighted ? 0.18 : pointer.containsMouse ? 0.14 : 0.035);
            const border = root.highlighted ? root.mix(root.foregroundColor, root.accentColor, 0.2) : root.mix(root.mutedColor, root.accentColor, emphasized ? 0.78 : 0.42);

            context.clearRect(0, 0, width, height);
            context.beginPath();
            context.moveTo(inset + cut, inset);
            context.lineTo(right - cut, inset);
            context.lineTo(right, inset + cut);
            context.lineTo(right, bottom - cut);
            context.lineTo(right - cut, bottom);
            context.lineTo(inset + cut, bottom);
            context.lineTo(inset, bottom - cut);
            context.lineTo(inset, inset + cut);
            context.closePath();
            context.fillStyle = fill;
            context.fill();
            context.lineWidth = root.highlighted ? 2.4 : root.selected ? 1.8 : 1.2;
            context.strokeStyle = border;
            context.stroke();

            if (root.selected) {
                context.globalAlpha = 0.48;
                context.lineWidth = 1;
                context.strokeStyle = root.foregroundColor;
                context.stroke();
                context.globalAlpha = 1;
            }
        }
    }

    Item {
        id: glyphLayer
        anchors.centerIn: parent
        width: 26
        height: 26
        opacity: root.pending ? 0.16 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconName.startsWith("level-")
            text: root.iconName.slice(-1)
            color: root.mix(root.foregroundColor, root.accentColor, root.selected ? 0.25 : 0.54)
            font.family: "JetBrains Mono"
            font.pixelSize: 25
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Canvas {
            id: glyphCanvas
            anchors.fill: parent
            visible: !root.iconName.startsWith("level-")
            antialiasing: true

            function line(context, x1, y1, x2, y2): void {
                context.moveTo(x1, y1);
                context.lineTo(x2, y2);
            }

            onPaint: {
                const context = getContext("2d");
                const color = root.mix(root.foregroundColor, root.accentColor, root.selected ? 0.24 : 0.58);
                context.clearRect(0, 0, width, height);
                context.beginPath();
                context.strokeStyle = color;
                context.lineWidth = 2.1;
                context.lineCap = "round";
                context.lineJoin = "round";

                if (root.iconName === "power") {
                    line(context, 13, 3, 13, 13);
                    context.moveTo(8, 6);
                    context.arc(13, 14, 9, -2.18, -0.96, true);
                    context.moveTo(8, 6);
                    context.arc(13, 14, 9, -2.18, -0.96, false);
                } else if (root.iconName === "mode-straight") {
                    for (let y = 7; y <= 19; y += 6) {
                        line(context, 3, y, 22, y);
                        line(context, 18, y - 3, 22, y);
                        line(context, 18, y + 3, 22, y);
                    }
                } else if (root.iconName === "mode-natural") {
                    for (let y = 7; y <= 19; y += 6) {
                        context.moveTo(3, y);
                        context.bezierCurveTo(7, y - 5, 10, y + 5, 14, y);
                        context.bezierCurveTo(18, y - 5, 20, y + 2, 23, y);
                    }
                } else if (root.iconName === "horizontal") {
                    line(context, 3, 13, 23, 13);
                    line(context, 3, 13, 7, 9);
                    line(context, 3, 13, 7, 17);
                    line(context, 23, 13, 19, 9);
                    line(context, 23, 13, 19, 17);
                    context.moveTo(9, 7);
                    context.arc(13, 13, 6, -2.2, 1.05, false);
                } else if (root.iconName === "vertical") {
                    line(context, 13, 3, 13, 23);
                    line(context, 13, 3, 9, 7);
                    line(context, 13, 3, 17, 7);
                    line(context, 13, 23, 9, 19);
                    line(context, 13, 23, 17, 19);
                    context.moveTo(7, 9);
                    context.arc(13, 13, 6, -2.2, 1.05, false);
                }

                context.stroke();
            }
        }
    }

    Rectangle {
        width: 3
        height: 18
        radius: 1.5
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        visible: root.highlighted
        color: root.foregroundColor
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 7
        visible: root.selected && !root.pending
        color: root.accentColor
        border.width: 1
        border.color: root.foregroundColor
    }

    Item {
        id: spinner
        anchors.centerIn: parent
        width: 25
        height: 25
        visible: root.pending

        Canvas {
            id: spinnerCanvas
            anchors.fill: parent
            antialiasing: true
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.beginPath();
                context.arc(width / 2, height / 2, 9.5, -Math.PI * 0.2, Math.PI * 1.35, false);
                context.lineWidth = 2.4;
                context.lineCap = "round";
                context.strokeStyle = root.accentColor;
                context.stroke();
            }
        }

        RotationAnimator on rotation {
            running: root.pending
            from: 0
            to: 360
            duration: 720
            loops: Animation.Infinite
        }
    }

    Rectangle {
        width: 7
        height: 7
        radius: 3.5
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        visible: root.failed
        color: root.errorColor
        border.width: 1
        border.color: root.foregroundColor
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.BusyCursor
        onContainsMouseChanged: root.repaint()
        onEntered: root.hovered()
        onClicked: root.invoked()
    }

    ToolTip {
        id: tip
        visible: pointer.containsMouse
        delay: 320
        timeout: 7000
        x: -implicitWidth - 14
        y: Math.round((root.height - implicitHeight) / 2)
        padding: 9

        contentItem: Text {
            text: root.failed && root.errorMessage !== "" ? root.toolTipText + "\n" + root.errorMessage : root.toolTipText
            color: root.foregroundColor
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            lineHeight: 1.2
            wrapMode: Text.Wrap
        }

        background: Rectangle {
            color: root.mix(root.surfaceColor, root.mutedColor, 0.12)
            border.width: 1
            border.color: root.failed ? root.errorColor : root.mutedColor
            radius: 5
        }
    }
}
