import QtQuick 2.0
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import macro.tester 1.0

Item {
    width: 600
    height: 32

    property int resultValue: 0
    property string title: "test"
    property alias restart: restart

    property string font_color: "#969696"
    property string success_color: "#37A439"
    property string failed_color: "#E91E63"
    property string unknown_color: "#276BB0"
    property string warning_color: "#FF6F00"

    function setValue(value) {
        if (value === "undefined") {
            return
        }

        if (value === Tester.Success) {
            result.text = qsTr("Успешно")
            result.color = success_color
        } else if (value === Tester.Failed){
            result.text = qsTr("Неудача")
            result.color = failed_color
        } else if (value === Tester.Error){
            result.text = qsTr("Ошибка")
            result.color = warning_color
        } else if (value === Tester.Progress){
            result.text = qsTr("Выполняется")
            result.color = unknown_color
        } else if (value === Tester.NotTested) {
            result.text = qsTr("Неизвестно")
            result.color = unknown_color
        } else if (value === Tester.Manual) {
            result.text = qsTr("Выполнено")
            result.color = success_color
        }
    }

    RowLayout {
        id: content_row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Layout.fillWidth: true

        Text {
            id: name

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 200
            Layout.preferredWidth: 250
            Layout.maximumWidth: 300

            font.pixelSize: 14
            font.bold: true
            font.family: "Inter"

            color: font_color

            text: title
        }

        Text {
            id: result

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 100
            Layout.preferredWidth: 150
            Layout.maximumWidth: 200

            font.pixelSize: 14
            font.bold: true
            font.family: "Inter"

            color: font_color

            text: qsTr("Не проверено")
        }

        Button {
            id: restart
            visible: true

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            Layout.minimumWidth: 100
            Layout.preferredWidth: 150
            Layout.maximumWidth: 200

            font.pixelSize: 14
            font.bold: true
            font.family: "Inter"

            background: Rectangle {
                id: buttonBackground

                width: parent.width
                height: parent.height

                radius: 8

                border.width: 2
                border.color: font_color

                color: unknown_color
            }

            onClicked: function() {
                buttonBackground.color = "#9C27B0"
            }

            text: qsTr("Запустить")
        }
    }
}
