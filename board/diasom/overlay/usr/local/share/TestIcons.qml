import QtQuick 2.0
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import macro.tester 1.0

Item {
    property alias button_icon: button_icon
    property alias button_text: button_text

    property string font_color: "#969696"
    property string success_color: "#37A439"
    property string failed_color: "#E91E63"
    property string unknown_color: "#276BB0"
    property string warning_color: "#FF6F00"
    

    function setVisible(value) {
        if (value === true) {
            button_text.visible = true
        } else if( value == false) {
            button_text.visible = false
        }
    }
    
    Button {
        id: button_icon
        // text: "RUNNING"
        display: AbstractButton.IconOnly
        anchors.top: parent.top
        anchors.topMargin: 10

        icon.width: 50
        icon.height: 50
        icon.color: "transparent"

        Text {
            id: button_text
            text: "RUNNING"
            visible: false
            anchors.top: parent.top
            anchors.topMargin: 60
            color: failed_color

            SequentialAnimation on color {
                loops: Animation.Infinite
                PropertyAnimation { to: "white" }
                PropertyAnimation { to: "red" }
            }
        }

        background: Rectangle {
            id: button_icon_bg
            anchors.fill: parent
            color: "transparent"
        }
        onClicked: function() {
        }
            
    }
}
