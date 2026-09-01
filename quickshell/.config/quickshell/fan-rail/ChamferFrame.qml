import QtQuick

Item {
    id: root

    property real contentWidth: 0
    property real contentHeight: 0
    property real padding: 12
    property real chamfer: 11
    property color accentColor: "#3e6fa8"
    property color surfaceColor: "#101216"
    property color innerBorderColor: "#3c4558"

    implicitWidth: contentWidth + padding * 2
    implicitHeight: contentHeight + padding * 2

    function paintFrame(): void {
        frameCanvas.requestPaint();
    }

    onWidthChanged: paintFrame()
    onHeightChanged: paintFrame()
    onAccentColorChanged: paintFrame()
    onSurfaceColorChanged: paintFrame()
    onInnerBorderColorChanged: paintFrame()
    onChamferChanged: paintFrame()

    Canvas {
        id: frameCanvas
        anchors.fill: parent
        antialiasing: true

        function polygon(context, inset): void {
            const left = inset;
            const top = inset;
            const right = width - inset;
            const bottom = height - inset;
            const cut = Math.min(root.chamfer, (right - left) / 3, (bottom - top) / 3);

            context.beginPath();
            context.moveTo(left + cut, top);
            context.lineTo(right, top);
            context.lineTo(right, bottom);
            context.lineTo(left + cut, bottom);
            context.lineTo(left, bottom - cut);
            context.lineTo(left, top + cut);
            context.closePath();
        }

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);

            polygon(context, 1);
            context.fillStyle = root.surfaceColor;
            context.fill();
            context.lineWidth = 2;
            context.strokeStyle = root.accentColor;
            context.stroke();

            polygon(context, 4);
            context.lineWidth = 1;
            context.strokeStyle = root.innerBorderColor;
            context.stroke();
        }
    }
}
