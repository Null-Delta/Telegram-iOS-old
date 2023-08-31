//
//  ChatListContextAnimationInController.swift
//  ContextUI
//
//  Created by Rustam on 25.08.2023.
//

import Foundation
import Display
import UIKit
import ContextUI
import ChatListUI
import AvatarNode
import WallpaperBackgroundNode


extension UIView {
    var globalFrame: CGRect? {
        let rootView = UIApplication.shared.keyWindow?.rootViewController?.view
        return self.superview?.convert(self.frame, to: rootView)
    }
}

public class ChatListContextAnimationInController: ContextAnimationInControllerProtocol {
    public func animate(with contentNode: ContextContentNode, in controller: ContextControllerNode, source: ContextContentSource) {
        guard
            case let .controller(contentNodeController) = contentNode,
            let chatController = contentNodeController.controller as? ChatControllerImpl,
            case let .controller(sourceController) = source,
            let sourceNode = (sourceController.sourceNode as? ChatListItemNode)?.dublicateNode,
            let navigationBar = chatController.navigationBar,
            let chatBackgroundNode = chatController.chatDisplayNode.backgroundNode as? WallpaperBackgroundNodeImpl
        else {
            return
        }
        
        sourceNode.alpha = 1
                                
        let actionsContainerNode = controller.actionsContainerNode
        let contentContainerNode = controller.contentContainerNode
        
        let springDuration: Double = 0.52 * contextAnimationDurationFactor
        let springDamping: CGFloat = 110.0
        
        var titleOffset: CGPoint = .zero
        let currentScale = contentNodeController.transform.m11

        actionsContainerNode.layer.animateAlpha(
            from: 0.0,
            to: 1.0,
            duration: 0.2 * contextAnimationDurationFactor
        )
        
        actionsContainerNode.layer.animateSpring(
            from: 0.1 as NSNumber,
            to: 1.0 as NSNumber,
            keyPath: "transform.scale",
            duration: springDuration,
            initialVelocity: 0.0,
            damping: springDamping
        )
        
//        contentContainerNode.isLayoutLocked = true

        contentContainerNode.allowsGroupOpacity = true

        if let originalProjectedContentViewFrame = controller.originalProjectedContentViewFrame {
            let localSourceFrame = controller.view.convert(CGRect(origin: CGPoint(x: originalProjectedContentViewFrame.1.minX, y: originalProjectedContentViewFrame.1.minY), size: CGSize(width: originalProjectedContentViewFrame.1.width, height: originalProjectedContentViewFrame.1.height)), to: controller.scrollNode.view)

            let startFrame = localSourceFrame
            let endFrame = contentContainerNode.frame
            
            let chatItemScale = (localSourceFrame.width + 12) / localSourceFrame.width

            contentContainerNode.addSubnode(sourceNode)
            sourceNode.frame.origin = .zero
            sourceNode.separatorNode.alpha = 0
            
            var chatListTitleCenter = sourceNode.titleNode.view.globalFrame!.center
            chatListTitleCenter.x -= contentContainerNode.frame.minX
            chatListTitleCenter.x *= contextScale
            chatListTitleCenter.x += contentContainerNode.frame.minX
            chatListTitleCenter.y -= contentContainerNode.frame.minY
            chatListTitleCenter.y *= contextScale
            chatListTitleCenter.y += contentContainerNode.frame.minY

            let NavigationBarTitleCenter = navigationBar.titleView!.subviews[0].subviews[0].subviews[0].subviews[0].globalFrame!.center

            titleOffset = CGPoint(x: NavigationBarTitleCenter.x - chatListTitleCenter.x, y: NavigationBarTitleCenter.y - chatListTitleCenter.y)
            titleOffset.x /= contextScale
            titleOffset.y /= contextScale
            //MARK: - chat list item

            sourceNode.mainContentContainerNode.allowsGroupOpacity = true
            sourceNode.alpha = 0
            sourceNode.layer.animateAlpha(from: 1, to: 0, duration: springDuration / 3, removeOnCompletion: false)

            sourceNode.frame.origin.x -= (sourceNode.frame.width - startFrame.width) / 2
            sourceNode.frame.origin.y -= (sourceNode.frame.height - sourceNode.frame.height * contextScale) / 2
            sourceNode.layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DIdentity,
                    chatItemScale * contextScale,
                    chatItemScale * contextScale,
                    1
                ) as NSValue,
                to: CATransform3DScale(
                    CATransform3DIdentity,
                    contextScale,
                    contextScale,
                    1
                ) as NSValue,
                keyPath: "transform",
                duration: 0.1,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false
            )
                        
            sourceNode.backgroundNode.layer.animateSpring(
                from: sourceNode.backgroundNode.frame.size as NSValue,
                to: CGSize(
                    width: endFrame.width * (1 / contextScale),
                    height: navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)
                )
                     as NSValue,
                keyPath: "bounds.size",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.backgroundNode.layer.animateSpring(
                from: CGPoint.zero as NSValue,
                to: CGPoint(
                    x: -(sourceNode.backgroundNode.frame.width - endFrame.width * (1 / contextScale)) / 2,
                    y: -(sourceNode.backgroundNode.frame.height - navigationBar.backgroundNode.frame.height * currentScale * (1 / contextScale)) / 2
                ) as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.avatarContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to: CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1) as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.avatarContainerNode.layer.animateSpring(
                from: 0 as NSValue,
                to:  -sourceNode.avatarContainerNode.frame.height * 0.3  as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                removeOnCompletion: false,
                additive: true
            )
            
            sourceNode.mainContentContainerNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:   CATransform3DTranslate(CATransform3DIdentity, titleOffset.x, titleOffset.y, 0)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            sourceNode.titleNode.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            sourceNode.credibilityIconView?.layer.animateSpring(
                from: CATransform3DIdentity as NSValue,
                to:  CATransform3DScale(CATransform3DIdentity, currentScale / contextScale, currentScale / contextScale, 1)  as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )

            //MARK: - background
            
            chatBackgroundNode.layer.animateSpring(
                from: CGSize(
                    width: startFrame.width * (1 / currentScale),
                    height: startFrame.height * (1 / currentScale)
                ) as NSValue,
                to: CGSize(
                    width: endFrame.width * (1 / currentScale),
                    height: endFrame.height * (1 / currentScale)
                ) as NSValue,
                keyPath: "bounds.size",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            chatBackgroundNode.layer.animateSpring(
                from: CGPoint(
                    x: (startFrame.width - endFrame.width) / 2 * (1 / currentScale),
                    y: (startFrame.height - endFrame.height) / 2 * (1 / currentScale)
                ) as NSValue,
                to: CGPoint.zero as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            chatBackgroundNode.updateLayout(
                size: CGSize(
                    width: startFrame.width * (1 / currentScale),
                    height: startFrame.height * (1 / currentScale)
                        ),
                displayMode: .aspectFill,
                transition: .immediate
            )
            chatBackgroundNode.updateLayout(
                size: CGSize(
                    width: endFrame.width * (1 / currentScale),
                    height: endFrame.height * (1 / currentScale)
                        ),
                displayMode: .aspectFill,
                transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
            )
                        
            chatBackgroundNode.isLayoutBlocked = true

            //MARK: - container
            
            contentContainerNode.layer.animateSpring(
                from: startFrame.size as NSValue,
                to: endFrame.size as NSValue,
                keyPath: "bounds.size",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )

            contentContainerNode.layer.animateSpring(
                from: 0 as NSNumber,
                to: 14 as NSNumber,
                keyPath: "cornerRadius",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            contentContainerNode.layer.animateSpring(
                from: CGPoint(
                    x: startFrame.midX - endFrame.midX,
                    y: startFrame.midY - endFrame.midY
                ) as NSValue,
                to: CGPoint.zero as NSValue,
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true,
                completion: { [weak controller] _ in
                    controller?.animatedIn = true
                    contentContainerNode.isLayoutLocked = false
                    chatBackgroundNode.isLayoutBlocked = false
                }
            )
            
            
            //MARK: - messages

            chatController.chatDisplayNode.historyNodeContainer.layer.animateSpring(
                from: (startFrame.width - endFrame.width) / 2 as NSNumber,
                to: 0 as NSNumber,
                keyPath: "position.x",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
            
            //MARK: - navigation
            
            switch controller.source {
            case let .controller(controller):
                controller.animatedIn()
            default:
                break
            }
            
            let oldSize = navigationBar.backgroundNode.frame.size
            navigationBar.backgroundNode.update(size: CGSize(width: startFrame.width * (1 / currentScale), height: startFrame.height * (1 / currentScale)), transition: .immediate)
            navigationBar.backgroundNode.update(size: CGSize(width: endFrame.width * (1 / currentScale), height: oldSize.height), transition: .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0)))
            navigationBar.stripeNode.layer.animateSpring(
                from: oldSize.height - startFrame.height * (1 / currentScale) as NSValue,
                to: 0 as NSValue,
                keyPath: "position.y",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )
            navigationBar.titleView!.subviews[0].subviews[0].layer.animateSpring(
                from: CATransform3DScale(
                    CATransform3DTranslate(
                        CATransform3DIdentity,
                        -titleOffset.x * (1 / (currentScale / contextScale)),
                        -titleOffset.y * (1 / (currentScale / contextScale)),
                        0
                    ),
                    1 / (currentScale / contextScale),
                    1 / (currentScale / contextScale),
                    1
                )
                 as NSValue,
                to:  CATransform3DScale(
                    CATransform3DIdentity,
                    1,
                    1,
                    1
                )as NSValue,
                keyPath: "transform",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping
            )

            chatController.chatTitleView?.titleFont = Font.medium(floor(sourceNode.item!.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            chatController.chatTitleView?.titleContent = chatController.chatTitleView?.titleContent
                                        
            controller.actionsContainerNode.layer.animateSpring(
                from: NSValue(cgPoint: CGPoint(x: localSourceFrame.center.x - controller.actionsContainerNode.position.x, y: localSourceFrame.center.y - controller.actionsContainerNode.position.y)),
                to: NSValue(cgPoint: CGPoint()),
                keyPath: "position",
                duration: springDuration,
                initialVelocity: 0.0,
                damping: springDamping,
                additive: true
            )
        }
        
        contextScale = contentNodeController.transform.m11
    }
    
    public init() { }
}

