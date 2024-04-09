import QtQuick 2.0
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    width: 100
    height: 10
    property string font_color: "#969696"
    property string success_color: "#37A439"
    property string failed_color: "#E91E63"
    property string unknown_color: "#276BB0"
    property string warning_color: "#FF6F00"
    property string inner_text

    RowLayout {
        // anchors.horizontalCenter: parent.horizontalCenter
        // anchors.verticalCenter: parent.verticalCenter
        
        anchors.left: parent.left
        anchors.leftMargin: 10

        anchors.top: parent.top
        anchors.topMargin: 10

        Label {
            id: info_cpu;
            font.pixelSize: 10
            font.bold: true
            font.family: "Inter"
            color: font_color
            text: inner_text
            // Text {
            //     id: buttonText
            //     anchors.centerIn: parent
                
            // }
        }
    }
    
}
