import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display

final class StreamSheetComponent: CombinedComponent {
//    let color: UIColor
//    let leftItem: AnyComponent<Empty>?
    let topComponent: AnyComponent<Empty>?
//    let viewerCounter: AnyComponent<Empty>?
    let bottomButtonsRow: AnyComponent<Empty>?
    // TODO: sync
    let sheetHeight: CGFloat
    let topOffset: CGFloat
    let backgroundColor: UIColor
    let participantsCount: Int
    let bottomPadding: CGFloat
    
    init(
//        color: UIColor,
        topComponent: AnyComponent<Empty>,
        bottomButtonsRow: AnyComponent<Empty>,
        topOffset: CGFloat,
        sheetHeight: CGFloat,
        backgroundColor: UIColor,
        bottomPadding: CGFloat,
        participantsCount: Int
    ) {
//        self.leftItem = leftItem
        self.topComponent = topComponent
//        self.viewerCounter = AnyComponent(ViewerCountComponent(count: 0))
        self.bottomButtonsRow = bottomButtonsRow
        self.topOffset = topOffset
        self.sheetHeight = sheetHeight
        self.backgroundColor = backgroundColor
        self.bottomPadding = bottomPadding
        self.participantsCount = participantsCount
    }
    
    static func ==(lhs: StreamSheetComponent, rhs: StreamSheetComponent) -> Bool {
        if lhs.topComponent != rhs.topComponent {
            return false
        }
        if lhs.bottomButtonsRow != rhs.bottomButtonsRow {
            return false
        }
        if lhs.topOffset != rhs.topOffset {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.sheetHeight != rhs.sheetHeight {
            return false
        }
        if !lhs.backgroundColor.isEqual(rhs.backgroundColor) {
            return false
        }
        if lhs.bottomPadding != rhs.bottomPadding {
            return false
        }
        if lhs.participantsCount != rhs.participantsCount {
            return false
        }
        return true
    }
//
    final class View: UIView {
        var overlayComponentsFrames = [CGRect]()
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            for subframe in overlayComponentsFrames {
                if subframe.contains(point) { return true }
            }
            return false
        }
        
        func update(component: StreamSheetComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.backgroundColor = .purple.withAlphaComponent(0.6)
            return availableSize
        }
        
        override func draw(_ rect: CGRect) {
            super.draw(rect)
            
//            guard let context = UIGraphicsGetCurrentContext() else { return }
//            context.setFillColor(UIColor.red.cgColor)
//            overlayComponentsFrames.forEach { frame in
//                context.addRect(frame)
//                context.fillPath()
//            }
        }
    }
    
    func makeView() -> View {
        View()
    }
    
    public final class State: ComponentState {
        override init() {
            super.init()
        }
    }
    
    public func makeState() -> State {
        return State()
    }
    
    private weak var state: State?
//    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
//        view.isUserInteractionEnabled = false
//        return availableSize
//    }
    /*public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }*/
    
    static var body: Body {
        let background = Child(SheetBackgroundComponent.self)
//        let leftItem = Child(environment: Empty.self)
        let topItem = Child(environment: Empty.self)
        let viewerCounter = Child(ParticipantsComponent.self)
        let bottomButtonsRow = Child(environment: Empty.self)
//        let bottomButtons = Child(environment: Empty.self)
//        let rightItems = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
//        let centerItem = Child(environment: Empty.self)
        
        return { context in
            let availableWidth = context.availableSize.width
//            let sideInset: CGFloat = 16.0 + context.component.sideInset
            
            let contentHeight: CGFloat = 44.0
            let size = context.availableSize// CGSize(width: context.availableSize.width, height:44)// context.component.topInset + contentHeight)
            
            let background = background.update(component: SheetBackgroundComponent(color: context.component.backgroundColor), availableSize: CGSize(width: size.width, height: context.component.sheetHeight), transition: context.transition)
            
            let topItem = context.component.topComponent.flatMap { topItemComponent in
                return topItem.update(
                    component: topItemComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            
            let viewerCounter = viewerCounter.update(
                component: ParticipantsComponent(count: context.component.participantsCount),
                availableSize: CGSize(width: context.availableSize.width, height: 70),
                transition: context.transition
            )
            
            let bottomButtonsRow = context.component.bottomButtonsRow.flatMap { bottomButtonsRowComponent in
                return bottomButtonsRow.update(
                    component: bottomButtonsRowComponent,
                    availableSize: CGSize(width: availableWidth, height: contentHeight),
                    transition: context.transition
                )
            }
            
            let topOffset = context.component.topOffset
            
            context.add(background
                .position(CGPoint(x: size.width / 2.0, y: context.component.topOffset + context.component.sheetHeight / 2))
            )
            
            (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames = []
            context.view.backgroundColor = .clear
            
            if let topItem = topItem {
                context.add(topItem
                    .position(CGPoint(x: topItem.size.width / 2.0, y: topOffset + 32))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: topOffset, width: topItem.size.width, height: topItem.size.height))
            }
            let videoHeight = (availableWidth - 32) / 16 * 9
            let sheetHeight = context.component.sheetHeight
            let animatedParticipantsVisible = context.component.participantsCount != -1
            if true {
                context.add(viewerCounter
                    .position(CGPoint(x: context.availableSize.width / 2, y: topOffset + 50 + videoHeight + (sheetHeight - 69 - videoHeight - 50 - context.component.bottomPadding) / 2 - 12))
                    .opacity(animatedParticipantsVisible ? 1 : 0)
                )
            }
            
            if let bottomButtonsRow = bottomButtonsRow {
                context.add(bottomButtonsRow
                    .position(CGPoint(x: bottomButtonsRow.size.width / 2, y: context.component.sheetHeight - 50 / 2 + topOffset - context.component.bottomPadding))
                )
                (context.view as? StreamSheetComponent.View)?.overlayComponentsFrames.append(.init(x: 0, y: context.component.sheetHeight - 50 - 20 + topOffset - context.component.bottomPadding, width: bottomButtonsRow.size.width, height: bottomButtonsRow.size.height ))
            }
            
            return size
        }
    }
}

import TelegramPresentationData
import TelegramStringFormatting

private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xe4436c)

private let latePurple = UIColor(rgb: 0x974aa9)
private let latePink = UIColor(rgb: 0xf0436c)

final class SheetBackgroundComponent: Component {
    private let color: UIColor
    
    class View: UIView {
        private let backgroundView = UIView()
        
        func update(availableSize: CGSize, color: UIColor, transition: Transition) {
            if backgroundView.superview == nil {
                self.addSubview(backgroundView)
            }
            // To fix release animation
            let extraBottom: CGFloat = 500
            backgroundView.frame = .init(origin: .zero, size: .init(width: availableSize.width, height: availableSize.height + extraBottom))
            if backgroundView.backgroundColor != color {
                UIView.animate(withDuration: 0.4) { [self] in
                    backgroundView.backgroundColor = color
                }
            } else {
                backgroundView.backgroundColor = color
            }
            backgroundView.isUserInteractionEnabled = false
            backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            backgroundView.layer.cornerRadius = 16
            backgroundView.clipsToBounds = true
            backgroundView.layer.masksToBounds = true
        }
    }
    
    func makeView() -> View {
        View()
    }
    
    static func ==(lhs: SheetBackgroundComponent, rhs: SheetBackgroundComponent) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
//        if lhs.width != rhs.width {
//            return false
//        }
//        if lhs.height != rhs.height {
//            return false
//        }
        return true
    }
    
    public init(color: UIColor) {
        self.color = color
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        view.update(availableSize: availableSize, color: color, transition: transition)
        return availableSize
    }
}

final class ParticipantsComponent: Component {
    static func == (lhs: ParticipantsComponent, rhs: ParticipantsComponent) -> Bool {
        lhs.count == rhs.count
    }
    
    func makeView() -> View {
        View(frame: .zero)
    }
    
    func update(view: View, availableSize: CGSize, state: ComponentFlow.EmptyComponentState, environment: ComponentFlow.Environment<ComponentFlow.Empty>, transition: ComponentFlow.Transition) -> CGSize {
        view.counter.update(
            countString: count > 0 ? presentationStringsFormattedNumber(Int32(count), ",") : "",
            subtitle: count > 0 ? "watching" : "no viewers"
        )// environment.strings.LiveStream_NoViewers)
        return availableSize
    }
    
    private let count: Int
    
    init(count: Int) {
        self.count = count
    }
    
    final class View: UIView {
        let counter = AnimatedCountView()// VoiceChatTimerNode.init(strings: .init(), dateTimeFormat: .init())
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(counter)
            counter.clipsToBounds = false
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            self.counter.frame = self.bounds
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
}
