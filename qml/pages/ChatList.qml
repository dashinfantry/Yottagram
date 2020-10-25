/*

This file is part of Yottagram.
Copyright 2020, Michał Szczepaniak <m.szczepaniak.000@gmail.com>

Yottagram is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Yottagram is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Yottagram. If not, see <http://www.gnu.org/licenses/>.

*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import SortFilterProxyModel 0.2
import org.nemomobile.dbus 2.0
import QtGraphicalEffects 1.0
import "../components"

Page {
    id: page

    allowedOrientations: Orientation.All
    property int currentChatList: 0

    DBusAdaptor {
        id: shareDBusInterface
        service: "com.verdanditeam.yottagram"
        path: "/"
        iface: "com.verdanditeam.yottagram"
        xml: '<interface name="com.verdanditeam.yottagram">
                          <method name="share"> <arg type="s" name="title" direction="in"/> <arg type="s" name="description" direction="in" /> </method>
                          <method name="openChat"> <arg type="x" name="chatId" direction="in" /> </method>
                          <method name="openApp" />
                      </interface>'

        function share(args) {
            console.log(args.title, args.description);
        }

        function openChat(chatId) {
            app.activate()
            var chat = chatList.openChat(chatId)
            if (typeof chat === "undefined" || !chat) return;
            if (pageStack.nextPage(page) !== null) pageStack.pop(pageStack.nextPage(page), PageStackAction.Immediate)
            pageStack.push(Qt.resolvedUrl("Chat.qml"), { chat: chat })
        }

        function openApp() {
            app.activate()
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Activating) searchField.focus = false
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: parent.height

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("About.qml"))
            }

            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("Settings.qml"))
            }

            MenuItem {
                visible: !authorization.isAuthorized
                text: qsTr("Log in")
                onClicked: pageStack.push(Qt.resolvedUrl("AuthorizationNumber.qml"))
            }

            MenuItem {
                text: page.currentChatList == 0 ? qsTr("Archived chats") : qsTr("Main chats")
                onClicked: page.currentChatList == 0 ? page.currentChatList = 1 : page.currentChatList = 0
                visible: false
            }
        }

        SearchField {
            id: searchField
            width: parent.width
            anchors.top: parent.top
            placeholderText: qsTr("Search")
            Keys.onReturnPressed: {
                if(searchField.text.length != 0) {
                    app.playlistModel.search(searchField.text)
                }
            }
        }

        SortFilterProxyModel {
            id: chatListProxyModel
            sourceModel: chatList
            sorters: [
                RoleSorter { roleName: "order"; sortOrder: Qt.DescendingOrder }
            ]
            filters: [
                ValueFilter {
                    roleName: "order"
                    value: false
                    inverted: true
                },
                ValueFilter {
                    roleName: "chatlist"
                    value: page.currentChatList
                },
                RegExpFilter {
                    roleName: "name"
                    pattern: "^" + searchField.text
                    caseSensitivity: Qt.CaseInsensitive
                    enabled: searchField.text !== ""
                }
            ]
        }

        SilicaListView {
            id: listView
            anchors.top: searchField.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            spacing: 0
            model: chatListProxyModel
            cacheBuffer: 0
            delegate: ListItem {
                contentHeight: Theme.itemSizeLarge

                menu: Component {
                    ContextMenu {
                        id: contextMenu
                        MenuItem {
                            text: qsTr("Set as read")
                            onClicked: {
                                chatList.markChatAsRead(id)
                            }
                        }

                        MenuItem {
                            text: qsTr("Delete chat")

                            onClicked: {
                                var list = chatList
                                var chatId = id
                                remorseAction("Deleting", function() {
                                    var chat = list.getChatAsVariant(chatId)
                                    chat.clearHistory(true)
                                    if (chat.getChatType() === "secret") chat.closeSecretChat()
                                })
                            }
                        }
                    }
                }

                Avatar {
                    id: avatar
                    userName: name
                    avatarPhoto: if (hasPhoto) photo
                    height: Theme.itemSizeLarge - Theme.paddingMedium*2
                    width: height
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.topMargin: Theme.paddingMedium
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: avatar.right
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: unread.visible ? unread.left : parent.right
                    anchors.rightMargin: Theme.paddingMedium

                    Row {
                        spacing: Theme.paddingSmall
                        width: parent.width

                        Icon {
                            id: secretChatIndicator
                            anchors.verticalCenter: parent.verticalCenter
                            source: "image://theme/icon-s-secure"
                            color: secretChatState === "pending" ? "yellow" : (secretChatState === "ready" ? "green" : "red")
                            visible: secretChatState !== ""
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isSelf ? qsTr("Saved messages") : name
                            truncationMode: TruncationMode.Fade
                            width: parent.width - (secretChatIndicator.visible ? (Theme.paddingSmall + secretChatIndicator.width) : 0)
                        }
                    }

                    Row {
                        width: parent.width
                        Label {
                            id: lastMessageAuthorLabel
                            text: lastMessageAuthor
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                            truncationMode: TruncationMode.Fade
                            width: Math.min(implicitWidth, Theme.itemSizeHuge)
                        }

                        Label {
                            text: lastMessage
                            maximumLineCount: 1
                            truncationMode: TruncationMode.Fade
                            clip: true
                            width: parent.width - lastMessageAuthorLabel.width
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                        }
                    }
                }

                Label {
                    id: unread
                    text: unreadCount
                    visible: unreadCount > 0

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingLarge
                }

                onClicked: {
                    var chat = chatList.openChat(id)
                    pageStack.push(Qt.resolvedUrl("Chat.qml"), { chat: chat })
                }
            }

//            delegate: ListItem {
//                id: listItem
//                contentHeight: Theme.itemSizeLarge
//                contentWidth: listView.width
//                width: contentWidth

//                Row {
//                    anchors.top: parent.top
//                    anchors.topMargin: Theme.paddingMedium
//                    anchors.left: avatar.right
//                    anchors.leftMargin: Theme.paddingLarge
//                    anchors.right: unread.visible ? unread.left : parent.right
//                    anchors.rightMargin: Theme.paddingMedium
//                    spacing: Theme.paddingSmall

//                    Icon {
//                        id: secretChatIndicator
//                        anchors.verticalCenter: parent.verticalCenter
//                        source: "image://theme/icon-s-secure"
//                        color: secretChatState === "pending" ? "yellow" : (secretChatState === "ready" ? "green" : "red")
//                        visible: secretChatState !== ""
//                    }

//                    Label {
//                        anchors.verticalCenter: parent.verticalCenter
//                        text: isSelf ? qsTr("Saved messages") : name
//                        truncationMode: TruncationMode.Fade
//                        width: parent.width - (secretChatIndicator.visible ? (Theme.paddingSmall + secretChatIndicator.width) : 0)
//                    }
//                }

//                Row {
//                    anchors.left: avatar.right
//                    anchors.leftMargin: Theme.paddingLarge
//                    anchors.right: unread.visible ? unread.left : parent.right
//                    anchors.rightMargin: Theme.paddingLarge
//                    anchors.bottom: parent.bottom
//                    anchors.bottomMargin: Theme.paddingMedium

//                    Label {
//                        id: lastMessageAuthorLabel
//                        text: lastMessageAuthor
//                        font.pixelSize: Theme.fontSizeSmall
//                        color: Theme.highlightColor
//                        truncationMode: TruncationMode.Fade
//                        width: Math.min(implicitWidth, Theme.itemSizeHuge)
//                    }

//                    Label {
//                        text: lastMessage
//                        maximumLineCount: 1
//                        truncationMode: TruncationMode.Fade
//                        clip: true
//                        width: parent.width - lastMessageAuthorLabel.width
//                        font.pixelSize: Theme.fontSizeSmall
//                        color: Theme.secondaryColor
//                    }
//                }

//            }
        }
    }
}
