import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 640
    height: 480
    color: "#050505"

    readonly property color cPanel: "#0A0A0A"
    readonly property color cField: "#111111"
    readonly property color cFaint: "#1A1A1A"
    readonly property color cLine: "#333333"
    readonly property color cDim: "#8A8A8A"
    readonly property color cInk: "#C8C8C8"
    readonly property color cBright: "#F2F2F0"
    readonly property color cAmber: "#FFB000"
    readonly property color cRed: "#FF3B30"
    readonly property string mono: "JetBrains Mono"

    property int sessionIndex: sessionSelect.index

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            errorMessage.text = ""
        }
        function onLoginFailed() {
            passwordField.text = ""
            errorMessage.text = "AUTH // DENIED"
            errorTimer.restart()
        }
    }

    Timer {
        id: errorTimer
        interval: 3000
        onTriggered: errorMessage.text = ""
    }

    // Background: coldwire terrain
    Background {
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background)
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status == Image.Error) {
                source = ""
            }
        }
    }

    // flat darkening, no soft gradient
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.30)
    }

    // ── header: decode label + corner ticks ──
    Text {
        id: headerText
        x: 28
        y: 22
        font.family: root.mono
        font.pixelSize: 13
        font.letterSpacing: 2
        color: root.cBright
        property string target: "COLDWIRE // AUTH"
        property int revealed: 0
        text: target
        Timer {
            interval: 30
            running: true
            repeat: true
            property string glyphs: "!<>-_\\/[]{}=+*^?#________"
            onTriggered: {
                headerText.revealed++
                if (headerText.revealed >= headerText.target.length) {
                    headerText.text = headerText.target
                    stop()
                    return
                }
                var out = headerText.target.substring(0, headerText.revealed)
                for (var i = headerText.revealed; i < headerText.target.length; i++)
                    out += headerText.target[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)]
                headerText.text = out
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 28
        y: 22
        font.family: root.mono
        font.pixelSize: 11
        font.letterSpacing: 1.5
        color: root.cDim
        text: "NODE // " + sddm.hostName.toUpperCase()
    }

    Repeater {
        model: 4
        delegate: Item {
            readonly property bool onRight: index % 2 === 1
            readonly property bool onBottom: index > 1
            x: onRight ? root.width - 18 : 10
            y: onBottom ? root.height - 18 : 10
            Rectangle { width: 8; height: 1; color: root.cDim; y: onBottom ? 7 : 0 }
            Rectangle { width: 1; height: 8; color: root.cDim; x: onRight ? 7 : 0 }
        }
    }

    // ── clock ──
    Item {
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.10
        anchors.horizontalCenter: parent.horizontalCenter
        width: timeLabel.width
        height: timeLabel.height + dateLabel.height + 8

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cBright
            font.family: root.mono
            font.pixelSize: 76
            font.letterSpacing: 6
        }

        Text {
            id: dateLabel
            anchors.top: timeLabel.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 13
            font.letterSpacing: 2
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var now = new Date()
                timeLabel.text = Qt.formatTime(now, "HH:mm:ss")
                dateLabel.text = Qt.formatDate(now, "ddd dd MMM yyyy").toUpperCase()
            }
        }
    }

    // ── login panel ──
    Rectangle {
        id: loginPanel
        anchors.centerIn: parent
        width: 360
        height: loginColumn.height + 56
        radius: 0
        color: Qt.rgba(root.cPanel.r, root.cPanel.g, root.cPanel.b, 0.86)
        border.width: 1
        border.color: errorMessage.text ? root.cRed : root.cLine

        // corner ticks on the panel
        Repeater {
            model: 4
            delegate: Item {
                readonly property bool onRight: index % 2 === 1
                readonly property bool onBottom: index > 1
                x: onRight ? loginPanel.width - 10 : 4
                y: onBottom ? loginPanel.height - 10 : 4
                Rectangle { width: 6; height: 1; color: root.cDim; y: onBottom ? 5 : 0 }
                Rectangle { width: 1; height: 6; color: root.cDim; x: onRight ? 5 : 0 }
            }
        }

        Column {
            id: loginColumn
            anchors.centerIn: parent
            width: parent.width - 56
            spacing: 14

            Text {
                text: "OPERATOR //"
                color: root.cDim
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            // Username
            Rectangle {
                width: parent.width
                height: 42
                radius: 0
                color: root.cField
                border.width: 1
                border.color: userField.activeFocus ? root.cAmber : root.cFaint

                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.margins: 12
                    color: root.cInk
                    font.family: root.mono
                    font.pixelSize: 14
                    clip: true
                    text: userModel.lastUser
                    selectByMouse: true
                    selectionColor: root.cBright
                    selectedTextColor: "#050505"
                    verticalAlignment: TextInput.AlignVCenter

                    KeyNavigation.tab: passwordField

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "USERNAME"
                        color: root.cLine
                        font.family: root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 1.5
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            // Password
            Rectangle {
                width: parent.width
                height: 42
                radius: 0
                color: root.cField
                border.width: 1
                border.color: passwordField.activeFocus ? root.cAmber : root.cFaint

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 12
                    color: root.cInk
                    font.family: root.mono
                    font.pixelSize: 14
                    clip: true
                    echoMode: TextInput.Password
                    passwordCharacter: "▪"
                    selectByMouse: true
                    selectionColor: root.cBright
                    selectedTextColor: "#050505"
                    verticalAlignment: TextInput.AlignVCenter

                    KeyNavigation.backtab: userField
                    KeyNavigation.tab: loginButton

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(userField.text, passwordField.text, sessionIndex)
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ACCESS_KEY"
                        color: root.cLine
                        font.family: root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 1.5
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            // Error message
            Text {
                id: errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.cRed
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 2
                height: text ? implicitHeight : 0
            }

            // Login button
            Rectangle {
                id: loginButton
                width: parent.width
                height: 42
                radius: 0
                color: loginMouse.containsMouse || activeFocus ? "#FFC94D" : root.cAmber

                activeFocusOnTab: true

                Text {
                    anchors.centerIn: parent
                    text: "AUTHENTICATE"
                    color: "#050505"
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.login(userField.text, passwordField.text, sessionIndex)
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        sddm.login(userField.text, passwordField.text, sessionIndex)
                        event.accepted = true
                    }
                }
            }
        }
    }

    // ── bottom bar ──
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 22
        height: 40

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "SESSION //"
                color: root.cDim
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }

            ComboBox {
                id: sessionSelect
                width: 180
                anchors.verticalCenter: parent.verticalCenter
                model: sessionModel
                index: sessionModel.lastIndex
                font.pixelSize: 12
                color: root.cInk
                borderColor: root.cLine
                focusColor: root.cAmber
                hoverColor: root.cField
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Text {
                text: "⏻"
                color: powerOffMouse.containsMouse ? root.cAmber : root.cDim
                font.pixelSize: 18
                MouseArea {
                    id: powerOffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.powerOff()
                }
            }

            Text {
                text: "↻"
                color: rebootMouse.containsMouse ? root.cAmber : root.cDim
                font.pixelSize: 18
                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.reboot()
                }
            }

            Text {
                visible: sddm.canSuspend
                text: "⏾"
                color: suspendMouse.containsMouse ? root.cAmber : root.cDim
                font.pixelSize: 18
                MouseArea {
                    id: suspendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.suspend()
                }
            }
        }
    }

    Component.onCompleted: {
        if (userField.text === "")
            userField.focus = true
        else
            passwordField.focus = true
    }
}
