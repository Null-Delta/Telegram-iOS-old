import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import GalleryUI
import LegacyComponents
import LegacyMediaPickerUI
import SaveToCameraRoll
import OverlayStatusController
import PresentationDataUtils

public enum AvatarGalleryEntryId: Hashable {
    case topImage
    case image(MediaId)
    case resource(String)
}

public enum AvatarGalleryEntry: Equatable {
    case topImage([ImageRepresentationWithReference], [VideoRepresentationWithReference], Peer?, GalleryItemIndexData?, Data?, String?)
    case image(MediaId, TelegramMediaImageReference?, [ImageRepresentationWithReference], [VideoRepresentationWithReference], Peer?, Int32?, GalleryItemIndexData?, MessageId?, Data?, String?)
    
    public var id: AvatarGalleryEntryId {
        switch self {
        case let .topImage(representations, _, _, _, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.uniqueId)
            }
            return .topImage
        case let .image(id, _, representations, _, _, _, _, _, _, _):
            if let last = representations.last {
                return .resource(last.representation.resource.id.uniqueId)
            }
            return .image(id)
        }
    }
    
    public var peer: Peer? {
        switch self {
            case let .topImage(_, _, peer, _, _, _):
                return peer
            case let .image(_, _, _, _, peer, _, _, _, _, _):
                return peer
        }
    }
    
    public var representations: [ImageRepresentationWithReference] {
        switch self {
            case let .topImage(representations, _, _, _, _, _):
                return representations
            case let .image(_, _, representations, _, _, _, _, _, _, _):
                return representations
        }
    }
    
    public var immediateThumbnailData: Data? {
        switch self {
            case let .topImage(_, _, _, _, immediateThumbnailData, _):
                return immediateThumbnailData
            case let .image(_, _, _, _, _, _, _, _, immediateThumbnailData, _):
                return immediateThumbnailData
        }
    }
    
    public var videoRepresentations: [VideoRepresentationWithReference] {
        switch self {
            case let .topImage(_, videoRepresentations, _, _, _, _):
                return videoRepresentations
            case let .image(_, _, _, videoRepresentations, _, _, _, _, _, _):
                return videoRepresentations
        }
    }
    
    public var indexData: GalleryItemIndexData? {
        switch self {
            case let .topImage(_, _, _, indexData, _, _):
                return indexData
            case let .image(_, _, _, _, _, _, indexData, _, _, _):
                return indexData
        }
    }
    
    public static func ==(lhs: AvatarGalleryEntry, rhs: AvatarGalleryEntry) -> Bool {
        switch lhs {
            case let .topImage(lhsRepresentations, lhsVideoRepresentations, lhsPeer, lhsIndexData, lhsImmediateThumbnailData, lhsCategory):
                if case let .topImage(rhsRepresentations, rhsVideoRepresentations, rhsPeer, rhsIndexData, rhsImmediateThumbnailData, rhsCategory) = rhs, lhsRepresentations == rhsRepresentations, lhsVideoRepresentations == rhsVideoRepresentations, arePeersEqual(lhsPeer, rhsPeer), lhsIndexData == rhsIndexData, lhsImmediateThumbnailData == rhsImmediateThumbnailData, lhsCategory == rhsCategory {
                    return true
                } else {
                    return false
                }
            case let .image(lhsId, lhsImageReference, lhsRepresentations, lhsVideoRepresentations, lhsPeer, lhsDate, lhsIndexData, lhsMessageId, lhsImmediateThumbnailData, lhsCategory):
                if case let .image(rhsId, rhsImageReference, rhsRepresentations, rhsVideoRepresentations, rhsPeer, rhsDate, rhsIndexData, rhsMessageId, rhsImmediateThumbnailData, rhsCategory) = rhs, lhsId == rhsId, lhsImageReference == rhsImageReference, lhsRepresentations == rhsRepresentations, lhsVideoRepresentations == rhsVideoRepresentations, arePeersEqual(lhsPeer, rhsPeer), lhsDate == rhsDate, lhsIndexData == rhsIndexData, lhsMessageId == rhsMessageId, lhsImmediateThumbnailData == rhsImmediateThumbnailData, lhsCategory == rhsCategory {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class AvatarGalleryControllerPresentationArguments {
    let animated: Bool
    let transitionArguments: (AvatarGalleryEntry) -> GalleryTransitionArguments?
    
    public init(animated: Bool = true, transitionArguments: @escaping (AvatarGalleryEntry) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

public func normalizeEntries(_ entries: [AvatarGalleryEntry]) -> [AvatarGalleryEntry] {
       var updatedEntries: [AvatarGalleryEntry] = []
       let count: Int32 = Int32(entries.count)
       var index: Int32 = 0
       for entry in entries {
           let indexData = GalleryItemIndexData(position: index, totalCount: count)
           if case let .topImage(representations, videoRepresentations, peer, _, immediateThumbnailData, category) = entry {
               updatedEntries.append(.topImage(representations, videoRepresentations, peer, indexData, immediateThumbnailData, category))
           } else if case let .image(id, reference, representations, videoRepresentations, peer, date, _, messageId, immediateThumbnailData, category) = entry {
               updatedEntries.append(.image(id, reference, representations, videoRepresentations, peer, date, indexData, messageId, immediateThumbnailData, category))
           }
           index += 1
       }
       return updatedEntries
   }

public func initialAvatarGalleryEntries(account: Account, peer: Peer) -> Signal<[AvatarGalleryEntry], NoError> {
    var initialEntries: [AvatarGalleryEntry] = []
    if !peer.profileImageRepresentations.isEmpty, let peerReference = PeerReference(peer) {
        initialEntries.append(.topImage(peer.profileImageRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), [], peer, nil, nil, nil))
    }
    
    if peer is TelegramChannel || peer is TelegramGroup, let peerReference = PeerReference(peer) {
        return account.postbox.transaction { transaction in
            return transaction.getPeerCachedData(peerId: peer.id)
        } |> map { cachedData in
            var initialPhoto: TelegramMediaImage?
            if let cachedData = cachedData as? CachedGroupData, let photo = cachedData.photo {
                initialPhoto = photo
            }
            else if let cachedData = cachedData as? CachedChannelData, let photo = cachedData.photo {
                initialPhoto = photo
            }
            
            if let photo = initialPhoto {
                if photo.immediateThumbnailData == nil {
                    return initialEntries
                } else {
                    return [.image(photo.imageId, photo.reference, photo.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), photo.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, nil, nil, nil, photo.immediateThumbnailData, nil)]
                }
            } else {
                return []
            }
        }
    } else {
        return .single(initialEntries)
    }
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer) -> Signal<[AvatarGalleryEntry], NoError> {
    return initialAvatarGalleryEntries(account: account, peer: peer)
    |> mapToSignal { initialEntries in
        return .single(initialEntries)
        |> then(
            requestPeerPhotos(postbox: account.postbox, network: account.network, peerId: peer.id)
            |> map { photos -> [AvatarGalleryEntry] in
                var result: [AvatarGalleryEntry] = []
                if photos.isEmpty {
                    result = initialEntries
                } else if let peerReference = PeerReference(peer) {
                    var index: Int32 = 0
                    if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peer.id.namespace) {
                        var initialMediaIds = Set<MediaId>()
                        for entry in initialEntries {
                            if case let .image(image) = entry {
                                initialMediaIds.insert(image.0)
                            }
                        }
                        
                        var photosCount = photos.count
                        for i in 0 ..< photos.count {
                            let photo = photos[i]
                            if i == 0 && !initialMediaIds.contains(photo.image.imageId) {
                                photosCount += 1
                                for entry in initialEntries {
                                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                                    if case let .image(image) = entry {
                                        result.append(.image(image.0, image.1, image.2, image.3, image.4, nil, indexData, nil, image.8, nil))
                                        index += 1
                                    }
                                }
                            }
                            
                            let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                            result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                            index += 1
                        }
                    } else {
                        for photo in photos {
                            let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                            if result.isEmpty, let first = initialEntries.first {
                                result.append(.image(photo.image.imageId, photo.image.reference, first.representations, photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                            } else {
                                result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                            }
                            index += 1
                        }
                    }
                }
                return result
            }
        )
    }
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer, firstEntry: AvatarGalleryEntry) -> Signal<(Bool, [AvatarGalleryEntry]), NoError> {
    let initialEntries = [firstEntry]
    return Signal<(Bool, [AvatarGalleryEntry]), NoError>.single((false, initialEntries))
    |> then(
        requestPeerPhotos(postbox: account.postbox, network: account.network, peerId: peer.id)
        |> map { photos -> (Bool, [AvatarGalleryEntry]) in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = [firstEntry]
            if photos.isEmpty {
                result = initialEntries
            } else if let peerReference = PeerReference(peer) {
                var index: Int32 = 0
                
                if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peer.id.namespace) {
                    var initialMediaIds = Set<MediaId>()
                    for entry in initialEntries {
                        if case let .image(image) = entry {
                            initialMediaIds.insert(image.0)
                        }
                    }
                    
                    var photosCount = photos.count
                    for i in 0 ..< photos.count {
                        let photo = photos[i]
                        if i == 0 && !initialMediaIds.contains(photo.image.imageId) {
                            photosCount += 1
                            for entry in initialEntries {
                                let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                                if case let .image(image) = entry {
                                    result.append(.image(image.0, image.1, image.2, image.3, image.4, nil, indexData, nil, image.8, nil))
                                    index += 1
                                }
                            }
                        }
                        
                        let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photosCount))
                        result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                        index += 1
                    }
                } else {
                    for photo in photos {
                        let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                        if result.isEmpty, let first = initialEntries.first {
                            result.append(.image(photo.image.imageId, photo.image.reference, first.representations, photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                        } else {
                            result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), photo.image.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId, photo.image.immediateThumbnailData, nil))
                        }
                        index += 1
                    }
                }
            }
            return (true, result)
        }
    )
}

public class AvatarGalleryController: ViewController, StandalonePresentableController {
    public enum SourceCorners {
        case none
        case round(Bool)
        case roundRect(CGFloat)
    }
    
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let sourceCorners: SourceCorners
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    private let animatedIn = ValuePromise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private var adjustedForInitialPreviewingLayout = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [AvatarGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemRightBarButtonItems = Promise<[UIBarButtonItem]?>(nil)
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    public var openAvatarSetup: ((@escaping () -> Void) -> Void)?
    public var avatarPhotoEditCompletion: ((UIImage) -> Void)?
    public var avatarVideoEditCompletion: ((UIImage, URL, TGVideoEditAdjustments?) -> Void)?
    
    public var removedEntry: ((AvatarGalleryEntry) -> Void)?
    
    private let _hiddenMedia = Promise<AvatarGalleryEntry?>(nil)
    public var hiddenMedia: Signal<AvatarGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    
    private let editDisposable = MetaDisposable ()
    
    public init(context: AccountContext, peer: Peer, sourceCorners: SourceCorners = .round(true), remoteEntries: Promise<[AvatarGalleryEntry]>? = nil, skipInitial: Bool = false, centralEntryIndex: Int? = nil, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, synchronousLoad: Bool = false) {
        self.context = context
        self.peer = peer
        self.sourceCorners = sourceCorners
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.replaceRootController = replaceRootController
        
        self.centralEntryIndex = centralEntryIndex
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let remoteEntriesSignal: Signal<[AvatarGalleryEntry], NoError>
        if let remoteEntries = remoteEntries {
            remoteEntriesSignal = remoteEntries.get()
        } else {
            remoteEntriesSignal = fetchedAvatarGalleryEntries(account: context.account, peer: peer)
        }
        
        let entriesSignal: Signal<[AvatarGalleryEntry], NoError> = skipInitial ? remoteEntriesSignal : (initialAvatarGalleryEntries(account: context.account, peer: peer) |> then(remoteEntriesSignal))
        
        let presentationData = self.presentationData
        
        let semaphore: DispatchSemaphore?
        if synchronousLoad {
            semaphore = DispatchSemaphore(value: 0)
        } else {
            semaphore = nil
        }
        
        let syncResult = Atomic<(Bool, (() -> Void)?)>(value: (false, nil))
        
        self.disposable.set(combineLatest(entriesSignal, self.animatedIn.get()).start(next: { [weak self] entries, animatedIn in
            let f: () -> Void = {
                if let strongSelf = self, animatedIn {
                    let isFirstTime = strongSelf.entries.isEmpty
                    
                    var entries = entries
                    if !isFirstTime, let updated = entries.first, case let .image(image) = updated, !image.3.isEmpty, let previous = strongSelf.entries.first, case let .topImage(topImage) = previous {
                        let firstEntry = AvatarGalleryEntry.image(image.0, image.1, topImage.0, image.3, image.4, image.5, image.6, image.7, image.8, image.9)
                        entries.remove(at: 0)
                        entries.insert(firstEntry, at: 0)
                    }
                    
                    strongSelf.entries = entries
                    if strongSelf.centralEntryIndex == nil {
                        strongSelf.centralEntryIndex = 0
                    }
                    if strongSelf.isViewLoaded {
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ entry in PeerAvatarImageGalleryItem(context: context, peer: peer, presentationData: presentationData, entry: entry, sourceCorners: sourceCorners, delete: strongSelf.canDelete ? {
                            self?.deleteEntry(entry)
                            } : nil, setMain: { [weak self] in
                                self?.setMainEntry(entry)
                            }, edit: { [weak self] in
                                self?.editEntry(entry)
                        })
                        }), centralItemIndex: strongSelf.centralEntryIndex, synchronous: !isFirstTime)
                        
                        let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                            strongSelf?.didSetReady = true
                        }
                        strongSelf._ready.set(ready |> map { true })
                    }
                }
            }
            
            var process = false
            let _ = syncResult.modify { processed, _ in
                if !processed {
                    return (processed, f)
                }
                process = true
                return (true, nil)
            }
            semaphore?.signal()
            if process {
                Queue.mainQueue().async {
                    f()
                }
            }
        }))
        
        if let semaphore = semaphore {
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0)
        }
        
        var syncResultApply: (() -> Void)?
        let _ = syncResult.modify { processed, f in
            syncResultApply = f
            return (true, nil)
        }
        
        syncResultApply?()
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            if let strongSelf = self {
                strongSelf.navigationItem.setTitle(title, animated: strongSelf.navigationItem.title?.isEmpty ?? true)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemRightBarButtonItems.get().start(next: { [weak self] rightBarButtonItems in
            self?.navigationItem.rightBarButtonItems = rightBarButtonItems
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
        self.editDisposable.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismissImmediately() {
        self._hiddenMedia.set(.single(nil))
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    private func dismiss(forceAway: Bool) {
        self.animatedIn.set(false)
        
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                var sourceHasRoundCorners = false
                if case .round = self.sourceCorners {
                    sourceHasRoundCorners = true
                }
                if (centralItemNode.index == 0 || !sourceHasRoundCorners), let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.pager.updateOnReplacement = true
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                    var sourceHasRoundCorners = false
                    if case .round = strongSelf.sourceCorners {
                        sourceHasRoundCorners = true
                    }
                    if centralItemNode.index != 0 && sourceHasRoundCorners {
                        return nil
                    }
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let presentationData = self.presentationData
        self.galleryNode.pager.replaceItems(self.entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] in
            self?.deleteEntry(entry)
        } : nil, setMain: { [weak self] in
            self?.setMainEntry(entry)
        }, edit: { [weak self] in
            self?.editEntry(entry)
        }) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: AvatarGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemRightBarButtonItems.set(node.rightBarButtonItems())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemRightBarButtonItems.set(centralItemNode.rightBarButtonItems())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                if presentationArguments.animated {
                    self.animatedIn.set(false)
                    centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
                        self.animatedIn.set(true)
                    })
                }
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        if !self.isPresentedInPreviewingContext() {
            self.galleryNode.setControlsHidden(false, animated: false)
            if let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                if presentationArguments.animated {
                    self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
                }
            }
        }
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
            return itemSize.aspectFitted(layout.size)
        } else {
            return nil
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
        
        if !self.adjustedForInitialPreviewingLayout && self.isPresentedInPreviewingContext() {
            self.adjustedForInitialPreviewingLayout = true
            self.galleryNode.setControlsHidden(true, animated: false)
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
                self.preferredContentSize = itemSize.aspectFitted(self.view.bounds.size)
                self.containerLayoutUpdated(ContainerViewLayout(size: self.preferredContentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                centralItemNode.activateAsInitial()
            }
        }
    }
    
    private var canDelete: Bool {
        let canDelete: Bool
        if self.peer.id == self.context.account.peerId {
            canDelete = true
        } else if let group = self.peer as? TelegramGroup {
            switch group.role {
                case .creator, .admin:
                    canDelete = true
                case .member:
                    canDelete = false
            }
        } else if let channel = self.peer as? TelegramChannel {
            canDelete = channel.hasPermission(.changeInfo)
        } else {
            canDelete = false
        }
        return canDelete
    }
    
    private func replaceEntries(_ entries: [AvatarGalleryEntry]) {
        self.galleryNode.currentThumbnailContainerNode?.updateSynchronously = true
        self.galleryNode.pager.replaceItems(entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: self.peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] in
            self?.deleteEntry(entry)
        } : nil, setMain: { [weak self] in
            self?.setMainEntry(entry)
        }, edit: { [weak self] in
            self?.editEntry(entry)
        }) }), centralItemIndex: 0, synchronous: true)
        self.entries = entries
        self.galleryNode.currentThumbnailContainerNode?.updateSynchronously = false
    }
    
    private func setMainEntry(_ rawEntry: AvatarGalleryEntry) {
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }
        
        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                } else {
                }
            case let .image(_, reference, _, _, _, _, _, _, _, _):
                if self.peer.id == self.context.account.peerId, let peerReference = PeerReference(self.peer) {
                    if let reference = reference {
                        let _ = (updatePeerPhotoExisting(network: self.context.account.network, reference: reference)
                        |> deliverOnMainQueue).start(next: { [weak self] photo in
                            if let strongSelf = self, let photo = photo, let firstEntry = strongSelf.entries.first, case let .image(image) = firstEntry {
                                let updatedEntry = AvatarGalleryEntry.image(photo.imageId, photo.reference, photo.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), photo.videoRepresentations.map({ VideoRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatarList(peer: peerReference, resource: $0.resource)) }), strongSelf.peer, image.5, image.6, image.7, photo.immediateThumbnailData, image.9)
                                
                                for (lhs, rhs) in zip(firstEntry.representations, updatedEntry.representations) {
                                    if lhs.representation.dimensions == rhs.representation.dimensions {
                                        strongSelf.context.account.postbox.mediaBox.copyResourceData(from: lhs.representation.resource.id, to: rhs.representation.resource.id, synchronous: true)
                                    }
                                }
                                for (lhs, rhs) in zip(firstEntry.videoRepresentations, updatedEntry.videoRepresentations) {
                                    if lhs.representation.dimensions == rhs.representation.dimensions {
                                        strongSelf.context.account.postbox.mediaBox.copyResourceData(from: lhs.representation.resource.id, to: rhs.representation.resource.id, synchronous: true)
                                    }
                                }
                                
                                var entries = strongSelf.entries
                                entries.remove(at: 0)
                                entries.insert(updatedEntry, at: 0)
                                strongSelf.replaceEntries(normalizeEntries(entries))
                                if let firstEntry = strongSelf.entries.first {
                                    strongSelf._hiddenMedia.set(.single(firstEntry))
                                }
                            }
                        })
                    }

                    if let index = self.entries.firstIndex(of: entry) {
                        var entries = self.entries
                        
                        let previousFirstEntry = entries.first
                        entries.remove(at: index)
                        entries.remove(at: 0)
                        entries.insert(entry, at: 0)
                        if let previousFirstEntry = previousFirstEntry {
                            entries.insert(previousFirstEntry, at: index)
                        }
                                              
                        self.replaceEntries(normalizeEntries(entries))
                        if let firstEntry = self.entries.first {
                            self._hiddenMedia.set(.single(firstEntry))
                        }
                    }
                }
        }
    }
    
    private func editEntry(_ rawEntry: AvatarGalleryEntry) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak actionSheet] in
            actionSheet?.dismissAnimated()
        }
        
        var items: [ActionSheetItem] = []
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.Settings_SetNewProfilePhotoOrVideo, color: .accent, action: { [weak self] in
            dismissAction()
            self?.openAvatarSetup?({ [weak self] in
                self?.dismissImmediately()
            })
        }))
        
        if self.peer.id == self.context.account.peerId, let position = rawEntry.indexData?.position, position > 0 {
            let title: String
            if let _ = rawEntry.videoRepresentations.last {
                title = self.presentationData.strings.ProfilePhoto_SetMainVideo
            } else {
                title = self.presentationData.strings.ProfilePhoto_SetMainPhoto
            }
            items.append(ActionSheetButtonItem(title: title, color: .accent, action: { [weak self] in
                dismissAction()
                self?.setMainEntry(rawEntry)
            }))
        }
        
        let deleteTitle: String
        if let _ = rawEntry.videoRepresentations.last {
            deleteTitle = self.presentationData.strings.Settings_RemoveVideo
        } else {
            deleteTitle = self.presentationData.strings.GroupInfo_SetGroupPhotoDelete
        }
        items.append(ActionSheetButtonItem(title: deleteTitle, color: .destructive, action: { [weak self] in
            dismissAction()
            self?.deleteEntry(rawEntry)
        }))
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.view.endEditing(true)
        self.present(actionSheet, in: .window(.root))
    }
    
    private func deleteEntry(_ rawEntry: AvatarGalleryEntry) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let proceed = {
            var entry = rawEntry
            if case .topImage = entry, !self.entries.isEmpty {
                entry = self.entries[0]
            }
            
            self.removedEntry?(rawEntry)
            
            var focusOnItem: Int?
            var updatedEntries = self.entries
            var replaceItems = false
            var dismiss = false
            
            switch entry {
                case .topImage:
                    if self.peer.id == self.context.account.peerId {
                    } else {
                        if entry == self.entries.first {
                            let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                            dismiss = true
                        } else {
                            if let index = self.entries.firstIndex(of: entry) {
                                self.entries.remove(at: index)
                                self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1, synchronous: false))
                            }
                        }
                }
                case let .image(_, reference, _, _, _, _, _, messageId, _, _):
                    if self.peer.id == self.context.account.peerId {
                        if let reference = reference {
                            let _ = removeAccountPhoto(network: self.context.account.network, reference: reference).start()
                        }
                        if entry == self.entries.first {
                            dismiss = true
                        } else {
                            if let index = self.entries.firstIndex(of: entry) {
                                replaceItems = true
                                updatedEntries.remove(at: index)
                                focusOnItem = index - 1
                            }
                        }
                    } else {
                        if let messageId = messageId {
                            let _ = deleteMessagesInteractively(account: self.context.account, messageIds: [messageId], type: .forEveryone).start()
                        }
                        
                        if entry == self.entries.first {
                            let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                            dismiss = true
                        } else {
                            if let index = self.entries.firstIndex(of: entry) {
                                replaceItems = true
                                updatedEntries.remove(at: index)
                                focusOnItem = index - 1
                            }
                        }
                    }
            }
            
            if replaceItems {
                updatedEntries = normalizeEntries(updatedEntries)
                self.galleryNode.pager.replaceItems(updatedEntries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: self.peer, presentationData: presentationData, entry: entry, sourceCorners: self.sourceCorners, delete: self.canDelete ? { [weak self] in
                    self?.deleteEntry(entry)
                } : nil, setMain: { [weak self] in
                    self?.setMainEntry(entry)
                }, edit: { [weak self] in
                    self?.editEntry(entry)
                }) }), centralItemIndex: focusOnItem, synchronous: true)
                self.entries = updatedEntries
            }
            if dismiss {
                self._hiddenMedia.set(.single(nil))
                Queue.mainQueue().after(0.2) {
                    self.dismiss(forceAway: true)
                }
            } else {
                if let firstEntry = self.entries.first {
                    self._hiddenMedia.set(.single(firstEntry))
                }
            }
        }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let items: [ActionSheetItem] = [
            ActionSheetButtonItem(title: presentationData.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                proceed()
            })
        ]
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.present(actionSheet, in: .window(.root))
    }
}
