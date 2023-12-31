import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalizedPeerData
import TelegramStringFormatting
import NotificationSoundSelectionUI

public struct NotificationExceptionWrapper : Equatable {
    public let settings: TelegramPeerNotificationSettings
    public let date: TimeInterval?
    public let peer: EnginePeer
    
    public init(settings: TelegramPeerNotificationSettings, peer: EnginePeer, date: TimeInterval? = nil) {
        self.settings = settings
        self.date = date
        self.peer = peer
    }
    
    public static func ==(lhs: NotificationExceptionWrapper, rhs: NotificationExceptionWrapper) -> Bool {
        return lhs.settings == rhs.settings && lhs.date == rhs.date
    }
    
    public func withUpdatedSettings(_ settings: TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: settings, peer: self.peer, date: self.date)
    }
    
    public func updateSettings(_ f: (TelegramPeerNotificationSettings) -> TelegramPeerNotificationSettings) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: f(self.settings), peer: self.peer, date: self.date)
    }
    
    
    public func withUpdatedDate(_ date: TimeInterval) -> NotificationExceptionWrapper {
        return NotificationExceptionWrapper(settings: self.settings, peer: self.peer, date: date)
    }
}

public enum NotificationExceptionMode : Equatable {
    public enum Mode {
        case users
        case groups
        case channels
        case stories
    }
    
    public static func == (lhs: NotificationExceptionMode, rhs: NotificationExceptionMode) -> Bool {
        switch lhs {
            case let .users(lhsValue):
                if case let .users(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
            case let .groups(lhsValue):
                if case let .groups(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
            case let .channels(lhsValue):
                if case let .channels(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
            case let .stories(lhsValue):
                if case let .stories(rhsValue) = rhs {
                    return lhsValue == rhsValue
                } else {
                    return false
                }
        }
    }
    
    public var mode: Mode {
        switch self {
            case .users:
                return .users
            case .groups:
                return .groups
            case .channels:
                return .channels
            case .stories:
                return .stories
        }
    }
    
    public var isEmpty: Bool {
        switch self {
            case let .users(value), let .groups(value), let .channels(value), let .stories(value):
                return value.isEmpty
        }
    }
    
    case users([EnginePeer.Id : NotificationExceptionWrapper])
    case groups([EnginePeer.Id : NotificationExceptionWrapper])
    case channels([EnginePeer.Id : NotificationExceptionWrapper])
    case stories([EnginePeer.Id : NotificationExceptionWrapper])
    
    public func withUpdatedPeerSound(_ peer: EnginePeer, _ sound: PeerMessageSound) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerMessageSound) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, sound in
            var values = values
            if let value = values[peerId] {
                switch sound {
                    case .default:
                        switch value.settings.muteState {
                        case .default:
                            values.removeValue(forKey: peerId)
                        default:
                            values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)}).withUpdatedDate(Date().timeIntervalSince1970)
                        }
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMessageSound(sound)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch sound {
                    case .default:
                        break
                    default:
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .default, messageSound: sound, displayPreviews: .default, storySettings: .default), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .groups(values):
            return .groups(apply(values, peer.id, sound))
        case let .users(values):
            return .users(apply(values, peer.id, sound))
        case let .channels(values):
            return .channels(apply(values, peer.id, sound))
        case .stories:
            return self
        }
    }
    
    public func withUpdatedPeerMuteInterval(_ peer: EnginePeer, _ muteInterval: Int32?) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerMuteState) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, muteState in
            var values = values
            if let value = values[peerId] {
                switch muteState {
                    case .default:
                        switch value.settings.messageSound {
                            case .default:
                                values.removeValue(forKey: peerId)
                            default:
                                values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)}).withUpdatedDate(Date().timeIntervalSince1970)
                        }
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedMuteState(muteState)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch muteState {
                    case .default:
                        break
                    default:
                        values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: .default, displayPreviews: .default, storySettings: .default), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        let muteState: PeerMuteState
        if let muteInterval = muteInterval {
            if muteInterval == 0 {
                muteState = .unmuted
            } else {
                let absoluteUntil: Int32
                if muteInterval == Int32.max {
                    absoluteUntil = Int32.max
                } else {
                    absoluteUntil = muteInterval
                }
                muteState = .muted(until: absoluteUntil)
            }
        } else {
            muteState = .default
        }
        switch self {
        case let .groups(values):
            return .groups(apply(values, peer.id, muteState))
        case let .users(values):
            return .users(apply(values, peer.id, muteState))
        case let .channels(values):
            return .channels(apply(values, peer.id, muteState))
        case .stories:
            return self
        }
    }
    
    public func withUpdatedPeerDisplayPreviews(_ peer: EnginePeer, _ displayPreviews: PeerNotificationDisplayPreviews) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerNotificationDisplayPreviews) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, displayPreviews in
            var values = values
            if let value = values[peerId] {
                switch displayPreviews {
                case .default:
                    switch value.settings.displayPreviews {
                    case .default:
                        values.removeValue(forKey: peerId)
                    default:
                        values[peerId] = value.updateSettings({$0.withUpdatedDisplayPreviews(displayPreviews)}).withUpdatedDate(Date().timeIntervalSince1970)
                    }
                default:
                    values[peerId] = value.updateSettings({$0.withUpdatedDisplayPreviews(displayPreviews)}).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch displayPreviews {
                case .default:
                    break
                default:
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: displayPreviews, storySettings: .default), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .groups(values):
            return .groups(apply(values, peer.id, displayPreviews))
        case let .users(values):
            return .users(apply(values, peer.id, displayPreviews))
        case let .channels(values):
            return .channels(apply(values, peer.id, displayPreviews))
        case .stories:
            return self
        }
    }
    
    public func withUpdatedPeerStoriesMuted(_ peer: EnginePeer, _ mute: PeerStoryNotificationSettings.Mute) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerStoryNotificationSettings.Mute) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, mute in
            var values = values
            if let value = values[peerId] {
                switch mute {
                case .default:
                    switch value.settings.storySettings.mute {
                    case .default:
                        //values.removeValue(forKey: peerId)
                        break
                    default:
                        values[peerId] = value.updateSettings({
                            var updatedSettings = $0.storySettings
                            updatedSettings.mute = mute
                            return $0.withUpdatedStorySettings(updatedSettings)
                        }).withUpdatedDate(Date().timeIntervalSince1970)
                    }
                default:
                    values[peerId] = value.updateSettings({
                        var updatedSettings = $0.storySettings
                        updatedSettings.mute = mute
                        return $0.withUpdatedStorySettings(updatedSettings)
                    }).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch mute {
                case .default:
                    break
                default:
                    var updatedSettings = PeerStoryNotificationSettings.default
                    updatedSettings.mute = mute
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: .default, storySettings: updatedSettings), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .stories(values):
            return .stories(apply(values, peer.id, mute))
        default:
            return self
        }
    }
    
    public func withUpdatedPeerStoriesHideSender(_ peer: EnginePeer, _ hideSender: PeerStoryNotificationSettings.HideSender) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerStoryNotificationSettings.HideSender) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, hideSender in
            var values = values
            if let value = values[peerId] {
                switch hideSender {
                case .default:
                    switch value.settings.storySettings.hideSender {
                    case .default:
                        //values.removeValue(forKey: peerId)
                        break
                    default:
                        values[peerId] = value.updateSettings({
                            var updatedSettings = $0.storySettings
                            updatedSettings.hideSender = hideSender
                            return $0.withUpdatedStorySettings(updatedSettings)
                        }).withUpdatedDate(Date().timeIntervalSince1970)
                    }
                default:
                    values[peerId] = value.updateSettings({
                        var updatedSettings = $0.storySettings
                        updatedSettings.hideSender = hideSender
                        return $0.withUpdatedStorySettings(updatedSettings)
                    }).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch hideSender {
                case .default:
                    break
                default:
                    var updatedSettings = PeerStoryNotificationSettings.default
                    updatedSettings.hideSender = hideSender
                    values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: .default, storySettings: updatedSettings), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .stories(values):
            return .stories(apply(values, peer.id, hideSender))
        default:
            return self
        }
    }
    
    public func withUpdatedPeerStorySound(_ peer: EnginePeer, _ sound: PeerMessageSound) -> NotificationExceptionMode {
        let apply:([EnginePeer.Id : NotificationExceptionWrapper], EnginePeer.Id, PeerMessageSound) -> [EnginePeer.Id : NotificationExceptionWrapper] = { values, peerId, sound in
            var values = values
            if let value = values[peerId] {
                switch sound {
                    case .default:
                        switch value.settings.storySettings.sound {
                        case .default:
                            //values.removeValue(forKey: peerId)
                            break
                        default:
                            values[peerId] = value.updateSettings({
                                var updatedSettings = $0.storySettings
                                updatedSettings.sound = sound
                                return $0.withUpdatedStorySettings(updatedSettings)
                            }).withUpdatedDate(Date().timeIntervalSince1970)
                        }
                    default:
                        values[peerId] = value.updateSettings({
                            var updatedSettings = $0.storySettings
                            updatedSettings.sound = sound
                            return $0.withUpdatedStorySettings(updatedSettings)
                        }).withUpdatedDate(Date().timeIntervalSince1970)
                }
            } else {
                switch sound {
                    case .default:
                        break
                    default:
                        var updatedSettings = PeerStoryNotificationSettings.default
                        updatedSettings.sound = sound
                        values[peerId] = NotificationExceptionWrapper(settings: TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: .default, storySettings: updatedSettings), peer: peer, date: Date().timeIntervalSince1970)
                }
            }
            return values
        }
        
        switch self {
        case let .stories(values):
            return .stories(apply(values, peer.id, sound))
        default:
            return self
        }
    }
    
    public func removeStoryPeerIfDefault(id: EnginePeer.Id) -> NotificationExceptionMode {
        switch self {
        case let .stories(values):
            if let settings = values[id]?.settings {
                if settings.storySettings == .default {
                    var values = values
                    values.removeValue(forKey: id)
                    return .stories(values)
                } else {
                    return .stories(values)
                }
            } else {
                return .stories(values)
            }
        default:
            return self
        }
    }
    
    public var peerIds: [EnginePeer.Id] {
        switch self {
        case let .users(settings), let .groups(settings), let .channels(settings), let .stories(settings):
            return settings.map { $0.key }
        }
    }
    
    public var settings: [EnginePeer.Id : NotificationExceptionWrapper] {
        switch self {
        case let .users(settings), let .groups(settings), let .channels(settings), let .stories(settings):
            return settings
        }
    }
}

private enum NotificationPeerExceptionSection: Int32 {
    case remove
    case switcher
    case displayPreviews
    case storyNotifications
    case soundCloud
    case soundModern
    case soundClassic
}

private enum NotificationPeerExceptionSwitcher: Hashable {
    case alwaysOn
    case alwaysOff
}

private enum NotificationPeerExceptionEntryId: Hashable {
    case remove
    case switcher(NotificationPeerExceptionSwitcher)
    case sound(PeerMessageSound.Id)
    case switcherHeader
    case displayPreviews(NotificationPeerExceptionSwitcher)
    case showSender(NotificationPeerExceptionSwitcher)
    case displayPreviewsHeader
    case storyNotifications(NotificationPeerExceptionSwitcher)
    case storyNotificationsHeader
    case soundModernHeader
    case soundClassicHeader
    case none
    case uploadSound
    case cloudHeader
    case cloudInfo
    case `default`
}

private final class NotificationPeerExceptionArguments  {
    let account: Account
    
    let selectSound: (PeerMessageSound) -> Void
    let selectMode: (NotificationPeerExceptionSwitcher) -> Void
    let selectDisplayPreviews: (NotificationPeerExceptionSwitcher) -> Void
    let selectStoriesMuted: (NotificationPeerExceptionSwitcher) -> Void
    let selectHideStoriesSender: (NotificationPeerExceptionSwitcher) -> Void
    let selectStorySound: (PeerMessageSound) -> Void
    let removeFromExceptions: () -> Void
    let complete: () -> Void
    let cancel: () -> Void
    let upload: () -> Void
    let deleteSound: (PeerMessageSound, String) -> Void
    
    init(
        account: Account,
        selectSound: @escaping(PeerMessageSound) -> Void,
        selectMode: @escaping(NotificationPeerExceptionSwitcher) -> Void,
        selectDisplayPreviews: @escaping (NotificationPeerExceptionSwitcher) -> Void,
        selectStoriesMuted: @escaping (NotificationPeerExceptionSwitcher) -> Void,
        selectHideStoriesSender: @escaping (NotificationPeerExceptionSwitcher) -> Void,
        selectStorySound: @escaping (PeerMessageSound) -> Void,
        removeFromExceptions: @escaping () -> Void,
        complete: @escaping() -> Void,
        cancel: @escaping() -> Void,
        upload: @escaping () -> Void,
        deleteSound: @escaping (PeerMessageSound, String) -> Void
    ) {
        self.account = account
        self.selectSound = selectSound
        self.selectMode = selectMode
        self.selectDisplayPreviews = selectDisplayPreviews
        self.selectStoriesMuted = selectStoriesMuted
        self.selectHideStoriesSender = selectHideStoriesSender
        self.selectStorySound = selectStorySound
        self.removeFromExceptions = removeFromExceptions
        self.complete = complete
        self.cancel = cancel
        self.upload = upload
        self.deleteSound = deleteSound
    }
}


private enum NotificationPeerExceptionEntry: ItemListNodeEntry {
    typealias ItemGenerationArguments = NotificationPeerExceptionArguments
    
    case remove(index:Int32, theme: PresentationTheme, strings: PresentationStrings)
    case switcher(index:Int32, theme: PresentationTheme, strings: PresentationStrings, mode: NotificationPeerExceptionSwitcher, selected: Bool)
    case switcherHeader(index:Int32, theme: PresentationTheme, title: String)
    case displayPreviews(index:Int32, theme: PresentationTheme, strings: PresentationStrings, value: NotificationPeerExceptionSwitcher, selected: Bool)
    case showSender(index:Int32, theme: PresentationTheme, strings: PresentationStrings, value: NotificationPeerExceptionSwitcher, selected: Bool)
    case displayPreviewsHeader(index:Int32, theme: PresentationTheme, title: String)
    case storyNotifications(index:Int32, theme: PresentationTheme, strings: PresentationStrings, value: NotificationPeerExceptionSwitcher, selected: Bool)
    case storyNotificationsHeader(index:Int32, theme: PresentationTheme, title: String)
    case soundModernHeader(index:Int32, theme: PresentationTheme, title: String)
    case soundClassicHeader(index:Int32, theme: PresentationTheme, title: String)
    case none(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, selected: Bool)
    case `default`(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, selected: Bool)
    case sound(index:Int32, section: NotificationPeerExceptionSection, theme: PresentationTheme, text: String, sound: PeerMessageSound, selected: Bool, canBeDeleted: Bool)
    case cloudHeader(index: Int32, text: String)
    case uploadSound(index: Int32, text: String)
    case cloudInfo(index: Int32, text: String)
    
    var index: Int32 {
        switch self {
        case let .remove(index, _, _):
            return index
        case let .switcherHeader(index, _, _):
            return index
        case let .switcher(index, _, _, _, _):
            return index
        case let .displayPreviewsHeader(index, _, _):
            return index
        case let .displayPreviews(index, _, _, _, _):
            return index
        case let .showSender(index, _, _, _, _):
            return index
        case let .storyNotificationsHeader(index, _, _):
            return index
        case let .storyNotifications(index, _, _, _, _):
            return index
        case let .soundModernHeader(index, _, _):
            return index
        case let .soundClassicHeader(index, _, _):
            return index
        case let .none(index, _, _, _, _):
            return index
        case let .default(index, _, _, _, _):
            return index
        case let .sound(index, _, _, _, _, _, _):
            return index
        case let .cloudHeader(index, _):
            return index
        case let .cloudInfo(index, _):
            return index
        case let .uploadSound(index, _):
            return index
        }
    }
    
    var section: ItemListSectionId {
        switch self {
        case .remove:
            return NotificationPeerExceptionSection.remove.rawValue
        case .switcher, .switcherHeader:
            return NotificationPeerExceptionSection.switcher.rawValue
        case .displayPreviews, .displayPreviewsHeader, .showSender:
            return NotificationPeerExceptionSection.displayPreviews.rawValue
        case .storyNotifications, .storyNotificationsHeader:
            return NotificationPeerExceptionSection.storyNotifications.rawValue
        case .cloudInfo, .cloudHeader, .uploadSound:
            return NotificationPeerExceptionSection.soundCloud.rawValue
        case .soundModernHeader:
            return NotificationPeerExceptionSection.soundModern.rawValue
        case .soundClassicHeader:
            return NotificationPeerExceptionSection.soundClassic.rawValue
        case let .none(_, section, _, _, _):
            return section.rawValue
        case let .default(_, section, _, _, _):
            return section.rawValue
        case let .sound(_, section, _, _, _, _, _):
            return section.rawValue
        }
    }
    
    var stableId: NotificationPeerExceptionEntryId {
        switch self {
        case .remove:
            return .remove
        case let .switcher(_, _, _, mode, _):
            return .switcher(mode)
        case .switcherHeader:
            return .switcherHeader
        case let .displayPreviews(_, _, _, mode, _):
            return .displayPreviews(mode)
        case .displayPreviewsHeader:
            return .displayPreviewsHeader
        case let .showSender(_, _, _, mode, _):
            return .showSender(mode)
        case let .storyNotifications(_, _, _, mode, _):
            return .storyNotifications(mode)
        case .storyNotificationsHeader:
            return .storyNotificationsHeader
        case .soundModernHeader:
            return .soundModernHeader
        case .soundClassicHeader:
            return .soundClassicHeader
        case .none:
            return .none
        case .default:
            return .default
        case let .sound(_, _, _, _, sound, _, _):
            return .sound(sound.id)
        case .uploadSound:
            return .uploadSound
        case .cloudHeader:
            return .cloudHeader
        case .cloudInfo:
            return .cloudInfo
        }
    }

    static func <(lhs: NotificationPeerExceptionEntry, rhs: NotificationPeerExceptionEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationPeerExceptionArguments
        switch self {
        case let .remove(_, _, strings):
            return ItemListActionItem(presentationData: presentationData, title: strings.Notification_Exceptions_RemoveFromExceptions, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.removeFromExceptions()
            })
        case let .switcher(_, _, strings, mode, selected):
            let title: String
            switch mode {
            case .alwaysOn:
                title = strings.Notification_Exceptions_AlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_AlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                 arguments.selectMode(mode)
            })
        case let .switcherHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .displayPreviews(_, _, strings, value, selected):
            let title: String
            switch value {
            case .alwaysOn:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectDisplayPreviews(value)
            })
        case let .showSender(_, _, strings, value, selected):
            let title: String
            switch value {
            case .alwaysOn:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectHideStoriesSender(value)
            })
        case let .cloudHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .cloudInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .uploadSound(_, text):
            let icon = PresentationResourcesItemList.uploadToneIcon(presentationData.theme)
            return ItemListCheckboxItem(presentationData: presentationData, icon: icon, iconSize: nil, iconPlacement: .check, title: text, style: .left, textColor: .accent, checked: false, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.upload()
            })
        case let .displayPreviewsHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .storyNotifications(_, _, strings, value, selected):
            let title: String
            switch value {
            case .alwaysOn:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOn
            case .alwaysOff:
                title = strings.Notification_Exceptions_MessagePreviewAlwaysOff
            }
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectStoriesMuted(value)
            })
        case let .storyNotificationsHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .soundModernHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .soundClassicHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .none(_, _, _, text, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: true, sectionId: self.section, action: {
                arguments.selectSound(.none)
            })
        case let .default(_, _, _, text, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectSound(.default)
            })
        case let .sound(_, _, _, text, sound, selected, canBeDeleted):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectSound(sound)
            }, deleteAction: canBeDeleted ? {
                arguments.deleteSound(sound, text)
            } : nil)
        }
    }
}


private func notificationPeerExceptionEntries(presentationData: PresentationData, peer: EnginePeer?, notificationSoundList: NotificationSoundList?, state: NotificationExceptionPeerState, isStories: Bool?) -> [NotificationPeerExceptionEntry] {
    let selectedSound = resolvedNotificationSound(sound: isStories == true ? state.selectedStoriesSound : state.selectedSound, notificationSoundList: notificationSoundList)
    
    var entries: [NotificationPeerExceptionEntry] = []
    
    var index: Int32 = 0
    
    if state.canRemove {
        entries.append(.remove(index: index, theme: presentationData.theme, strings: presentationData.strings))
        index += 1
    }
    
    if isStories == nil || isStories == false {
        entries.append(.switcherHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_NewException_NotificationHeader))
        index += 1
        
        entries.append(.switcher(index: index, theme: presentationData.theme, strings: presentationData.strings, mode: .alwaysOn, selected: state.mode == .alwaysOn))
        index += 1
        entries.append(.switcher(index: index, theme: presentationData.theme, strings: presentationData.strings, mode: .alwaysOff, selected:  state.mode == .alwaysOff))
        index += 1
        
        if state.mode != .alwaysOff {
            entries.append(.displayPreviewsHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_NewException_MessagePreviewHeader))
            index += 1
            entries.append(.displayPreviews(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOn, selected: state.displayPreviews == .alwaysOn))
            index += 1
            entries.append(.displayPreviews(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOff, selected: state.displayPreviews == .alwaysOff))
            index += 1
        }
    }
     
    if isStories == nil || isStories == true {
        if case .user = peer {
            entries.append(.storyNotificationsHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_StoriesHeader))
            index += 1
            entries.append(.storyNotifications(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOn, selected: state.storiesMuted == .alwaysOn))
            index += 1
            entries.append(.storyNotifications(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOff, selected: state.storiesMuted == .alwaysOff))
            index += 1
            
            if state.storiesMuted != .alwaysOff {
                entries.append(.displayPreviewsHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notification_Exceptions_StoriesDisplayAuthorName))
                index += 1
                entries.append(.showSender(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOn, selected: state.storiesHideSender == .alwaysOn))
                index += 1
                entries.append(.showSender(index: index, theme: presentationData.theme, strings: presentationData.strings, value: .alwaysOff, selected: state.storiesHideSender == .alwaysOff))
                index += 1
            }
        }
    }
    
    var displaySounds = true
    
    if isStories == true {
        if state.storiesMuted == .alwaysOff {
            displaySounds = false
        }
    }
    
    if displaySounds {
        let defaultSound = isStories == true ? state.defaultStoriesSound : state.defaultSound
        
        entries.append(.cloudHeader(index: index, text: presentationData.strings.Notifications_TelegramTones))
        index += 1
        
        index = 1000
        
        if let notificationSoundList = notificationSoundList {
            let cloudSounds = notificationSoundList.sounds.filter({ CloudSoundBuiltinCategory(id: $0.file.fileId.id) == nil })
            let modernSounds = notificationSoundList.sounds.filter({ CloudSoundBuiltinCategory(id: $0.file.fileId.id) == .modern })
            let classicSounds = notificationSoundList.sounds.filter({ CloudSoundBuiltinCategory(id: $0.file.fileId.id) == .classic })
            
            for listSound in cloudSounds {
                let sound: PeerMessageSound = .cloud(fileId: listSound.file.fileId.id)
                if state.removedSounds.contains(where: { $0.id == sound.id }) {
                    continue
                }
                entries.append(.sound(index: index, section: .soundCloud, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: selectedSound.id == sound.id, canBeDeleted: true))
                index += 1
            }
            
            index = 2000
            
            entries.append(.uploadSound(index: index, text: presentationData.strings.Notifications_UploadSound))
            index += 1
            entries.append(.cloudInfo(index: index, text: presentationData.strings.Notifications_MessageSoundInfo))
            index += 1
            
            entries.append(.soundModernHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notifications_AlertTones))
            
            index = 3000
            
            entries.append(.default(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: .default, default: defaultSound), selected: selectedSound == .default))
            index += 1

            entries.append(.none(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: .none), selected: selectedSound == .none))
            index += 1

            for i in 0 ..< modernSounds.count {
                let sound: PeerMessageSound = .cloud(fileId: modernSounds[i].file.fileId.id)
                entries.append(.sound(index: index, section: .soundModern, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: sound.id == selectedSound.id, canBeDeleted: false))
                index += 1
            }
            
            entries.append(.soundClassicHeader(index: index, theme: presentationData.theme, title: presentationData.strings.Notifications_ClassicTones))
            index += 1
            
            for i in 0 ..< classicSounds.count {
                let sound: PeerMessageSound = .cloud(fileId: classicSounds[i].file.fileId.id)
                entries.append(.sound(index: index, section: .soundClassic, theme: presentationData.theme, text: localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: sound), sound: sound, selected: sound.id == selectedSound.id, canBeDeleted: false))
                index += 1
            }
        }
    }
    
    return entries
}

private struct NotificationExceptionPeerState : Equatable {
    var canRemove: Bool
    var selectedSound: PeerMessageSound
    var mode: NotificationPeerExceptionSwitcher
    var defaultSound: PeerMessageSound
    var displayPreviews: NotificationPeerExceptionSwitcher
    var defaultStoriesSound: PeerMessageSound
    var storiesMuted: NotificationPeerExceptionSwitcher
    var selectedStoriesSound: PeerMessageSound
    var storiesHideSender: NotificationPeerExceptionSwitcher
    var removedSounds: [PeerMessageSound]
    
    init(canRemove: Bool, notifications: TelegramPeerNotificationSettings? = nil) {
        self.canRemove = canRemove
        
        if let notifications = notifications {
            self.selectedSound = notifications.messageSound
            switch notifications.muteState {
            case let .muted(until) where until >= Int32.max - 1:
                self.mode = .alwaysOff
            default:
                self.mode = .alwaysOn
            }
            self.displayPreviews = notifications.displayPreviews == .hide ? .alwaysOff : .alwaysOn
            self.storiesMuted = notifications.storySettings.mute == .muted ? .alwaysOff : .alwaysOn
            self.selectedStoriesSound = notifications.storySettings.sound
            self.storiesHideSender = notifications.storySettings.hideSender == .hide ? .alwaysOff : .alwaysOn
        } else {
            self.selectedSound = .default
            self.mode = .alwaysOn
            self.displayPreviews = .alwaysOn
            self.storiesMuted = PeerStoryNotificationSettings.default.mute == .muted ? .alwaysOff : .alwaysOn
            self.selectedStoriesSound = PeerStoryNotificationSettings.default.sound
            self.storiesHideSender = PeerStoryNotificationSettings.default.hideSender == .hide ? .alwaysOff : .alwaysOn
        }
      
        self.defaultSound = .default
        self.defaultStoriesSound = .default
        self.removedSounds = []
    }
    
    init(
        canRemove: Bool,
        selectedSound: PeerMessageSound,
        mode: NotificationPeerExceptionSwitcher,
        defaultSound: PeerMessageSound,
        displayPreviews: NotificationPeerExceptionSwitcher,
        defaultStoriesSound: PeerMessageSound,
        storiesMuted: NotificationPeerExceptionSwitcher,
        selectedStoriesSound: PeerMessageSound,
        storiesHideSender: NotificationPeerExceptionSwitcher,
        removedSounds: [PeerMessageSound]
    ) {
        self.canRemove = canRemove
        self.selectedSound = selectedSound
        self.mode = mode
        self.defaultSound = defaultSound
        self.displayPreviews = displayPreviews
        self.defaultStoriesSound = defaultStoriesSound
        self.storiesMuted = storiesMuted
        self.selectedStoriesSound = selectedStoriesSound
        self.storiesHideSender = storiesHideSender
        self.removedSounds = removedSounds
    }
}

public func notificationPeerExceptionController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    customTitle: String? = nil,
    threadId: Int64?,
    isStories: Bool?,
    canRemove: Bool,
    defaultSound: PeerMessageSound,
    defaultStoriesSound: PeerMessageSound,
    edit: Bool = false,
    updatePeerSound: @escaping(EnginePeer.Id, PeerMessageSound) -> Void,
    updatePeerNotificationInterval: @escaping(EnginePeer.Id, Int32?) -> Void,
    updatePeerDisplayPreviews: @escaping(EnginePeer.Id, PeerNotificationDisplayPreviews) -> Void,
    updatePeerStoriesMuted: @escaping(EnginePeer.Id, PeerStoryNotificationSettings.Mute) -> Void,
    updatePeerStoriesHideSender: @escaping (EnginePeer.Id, PeerStoryNotificationSettings.HideSender) -> Void,
    updatePeerStorySound: @escaping (EnginePeer.Id, PeerMessageSound) -> Void,
    removePeerFromExceptions: @escaping () -> Void,
    modifiedPeer: @escaping () -> Void
) -> ViewController {
    let initialState = NotificationExceptionPeerState(canRemove: false)
    let statePromise = Promise(initialState)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NotificationExceptionPeerState) -> NotificationExceptionPeerState) -> Void = { f in
        statePromise.set(.single(stateValue.modify { f($0) }))
    }
    
    var completeImpl: (() -> Void)?
    var removeFromExceptionsImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    let playSoundDisposable = MetaDisposable()
    var presentFilePicker: (() -> Void)?
    var deleteSoundImpl: ((PeerMessageSound, String) -> Void)?
    
    let soundActionDisposable = MetaDisposable()

    let arguments = NotificationPeerExceptionArguments(account: context.account, selectSound: { sound in
        if isStories == true {
            updateState { state in
                let _ = (context.engine.peers.notificationSoundList()
                |> take(1)
                |> deliverOnMainQueue).start(next: { notificationSoundList in
                    playSoundDisposable.set(playSound(context: context, notificationSoundList: notificationSoundList, sound: sound, defaultSound: state.defaultStoriesSound).start())
                })
                
                var state = state
                state.selectedStoriesSound = sound
                return state
            }
        } else {
            updateState { state in
                let _ = (context.engine.peers.notificationSoundList()
                         |> take(1)
                         |> deliverOnMainQueue).start(next: { notificationSoundList in
                    playSoundDisposable.set(playSound(context: context, notificationSoundList: notificationSoundList, sound: sound, defaultSound: state.defaultSound).start())
                })
                
                var state = state
                state.selectedSound = sound
                return state
            }
        }
    }, selectMode: { mode in
        updateState { state in
            var state = state
            state.mode = mode
            return state
        }
    }, selectDisplayPreviews: { value in
        updateState { state in
            var state = state
            state.displayPreviews = value
            return state
        }
    }, selectStoriesMuted: { value in
        updateState { state in
            var state = state
            state.storiesMuted = value
            return state
        }
    }, selectHideStoriesSender: { value in
        updateState { state in
            var state = state
            state.storiesHideSender = value
            return state
        }
    }, selectStorySound: { sound in
        updateState { state in
            let _ = (context.engine.peers.notificationSoundList()
            |> take(1)
            |> deliverOnMainQueue).start(next: { notificationSoundList in
                playSoundDisposable.set(playSound(context: context, notificationSoundList: notificationSoundList, sound: sound, defaultSound: state.defaultStoriesSound).start())
            })
            
            var state = state
            state.selectedStoriesSound = sound
            return state
        }
    }, removeFromExceptions: {
        removeFromExceptionsImpl?()
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    }, upload: {
        presentFilePicker?()
    }, deleteSound: { sound, title in
        deleteSoundImpl?(sound, title)
    })
    
    statePromise.set(context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peer.id),
        EngineDataOptional(threadId.flatMap { TelegramEngine.EngineData.Item.Peer.ThreadNotificationSettings(id: peer.id, threadId: $0) }),
        TelegramEngine.EngineData.Item.NotificationSettings.Global()
    )
    |> map { peerNotificationSettings, threadNotificationSettings, globalNotificationSettings -> NotificationExceptionPeerState in
        let effectiveSettings = threadNotificationSettings ?? peerNotificationSettings
        
        var state = NotificationExceptionPeerState(canRemove: canRemove, notifications: effectiveSettings._asNotificationSettings())
        state.defaultSound = defaultSound
        state.defaultStoriesSound = defaultStoriesSound
        let _ = stateValue.swap(state)
        return state
    })
    
    let previousSoundIds = Atomic<Set<Int64>>(value: Set())
    
    let signal = combineLatest(queue: .mainQueue(), (updatedPresentationData?.signal ?? context.sharedContext.presentationData), context.engine.peers.notificationSoundList(), statePromise.get() |> distinctUntilChanged)
    |> map { presentationData, notificationSoundList, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            arguments.cancel()
        })
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(state.canRemove || edit ? presentationData.strings.Common_Done : presentationData.strings.Notification_Exceptions_Add), style: .bold, enabled: true, action: {
            arguments.complete()
        })
        
        var updatedSoundIds = Set<Int64>()
        if let notificationSoundList = notificationSoundList {
            for sound in notificationSoundList.sounds {
                if state.removedSounds.contains(.cloud(fileId: sound.file.fileId.id)) {
                    continue
                }
                updatedSoundIds.insert(sound.file.fileId.id)
            }
        }
        
        var animated = false
        if previousSoundIds.swap(updatedSoundIds) != updatedSoundIds {
            animated = true
        }
        
        let titleString: String
        if let customTitle = customTitle {
            titleString = customTitle
        } else {
            titleString = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(titleString), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: notificationPeerExceptionEntries(presentationData: presentationData, peer: peer, notificationSoundList: notificationSoundList, state: state, isStories: isStories), style: .blocks, animateChanges: animated)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal |> afterDisposed {
        playSoundDisposable.dispose()
        soundActionDisposable.dispose()
    })

    controller.enableInteractiveDismiss = true
    
    completeImpl = { [weak controller] in
        controller?.dismiss()
        modifiedPeer()
        
        let _ = (context.engine.peers.notificationSoundList()
        |> take(1)
        |> deliverOnMainQueue).start(next: { notificationSoundList in
            updateState { state in
                if isStories == nil || isStories == false {
                    updatePeerSound(peer.id, resolvedNotificationSound(sound: state.selectedSound, notificationSoundList: notificationSoundList))
                    updatePeerNotificationInterval(peer.id, state.mode == .alwaysOn ? 0 : Int32.max)
                    updatePeerDisplayPreviews(peer.id, state.displayPreviews == .alwaysOn ? .show : .hide)
                }
                if isStories == nil || isStories == true {
                    updatePeerStoriesMuted(peer.id, state.storiesMuted == .alwaysOn ? .unmuted : .muted)
                    updatePeerStoriesHideSender(peer.id, state.storiesHideSender == .alwaysOn ? .show : .hide)
                    updatePeerStorySound(peer.id, resolvedNotificationSound(sound: state.selectedStoriesSound, notificationSoundList: notificationSoundList))
                }
                return state
            }
        })
    }
    
    removeFromExceptionsImpl = { [weak controller] in
        controller?.dismiss()
        removePeerFromExceptions()
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    presentFilePicker = { [weak controller] in
        guard let controller = controller else {
            return
        }
        presentCustomNotificationSoundFilePicker(context: context, controller: controller, disposable: soundActionDisposable)
    }
    
    deleteSoundImpl = { [weak controller] sound, title in
        guard let controller = controller else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.PeerInfo_DeleteToneTitle, text: presentationData.strings.PeerInfo_DeleteToneText(title).string, actions: [
            TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                updateState { state in
                    var state = state
                    
                    state.removedSounds.append(sound)
                    if state.selectedSound.id == sound.id {
                        state.selectedSound = defaultCloudPeerNotificationSound
                    }
                    
                    return state
                }
                switch sound {
                case let .cloud(id):
                    soundActionDisposable.set((context.engine.peers.deleteNotificationSound(fileId: id)
                    |> deliverOnMainQueue).start(completed: {
                    }))
                default:
                    break
                }
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {
            })
        ], parseMarkdown: true), in: .window(.root))
    }

    return controller
}
