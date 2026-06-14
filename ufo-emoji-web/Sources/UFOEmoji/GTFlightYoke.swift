//
//  GTFlightYoke ]|[ the Ultimate Precision Touch Screen Gaming Flight Stick
//
//  by GoodTime aka Todd Bruss (c) 2015 - 2026
//

import SpriteKit

protocol FlightYokeProtocol: AnyObject {
    func FlightYokePilot(velocity: CGVector?, zRotation: CGFloat?)
}
 

class GTFlightYoke: SKNode {
    
    deinit {
        //Should not De-Init until it quits
    }
    
    private var velocity = CGVector.zero
    private var runtimeLoop: CADisplayLink?
    private let ease : TimeInterval = 0.04
    private let anchor = CGPoint.zero
    private var thumbNode = SKSpriteNode()
    private var backgroundNode = SKSpriteNode()
    private let thumbSpring: TimeInterval = 0.08
    private let multiplier = CGFloat(10)
    private let dx = CGFloat(-0.003)
    private let play = CGFloat(2)
    private let zindex = CGFloat(1000)
    private let snapToPoint = CGFloat(16)
    private let zero = CGFloat(0.0)
    private let two = CGFloat(2.0)
    private var focus = false

    private weak var thumbImage : UIImage!
    private weak var bgImage : UIImage!
    
    func setThumbImage(_ image: UIImage?, sizeToFit: Bool) {
        if let img: UIImage = UIImage(named: "bg-stick") {
            thumbNode.texture = SKTexture(image: img)
            if sizeToFit {
                thumbNodeWidth = min(img.size.width, img.size.height)
            }
        }
    }
    
    func backgroundImage(_ image: UIImage?, sizeToFit: Bool) {
        if let img: UIImage = UIImage(named: "bg-joystick") {
            backgroundNode.texture = SKTexture(image: img)
            if sizeToFit {
                backgroundImageWidth = min(img.size.width, img.size.height)
            }
        }
    }
    
    private var backgroundImageWidth: CGFloat! {
        get { return backgroundNode.size.width }
        set { backgroundNode.size = CGSize(width: newValue, height: newValue) }
    }
    
    private var thumbNodeWidth: CGFloat! {
        get { return thumbNode.size.width }
        set { thumbNode.size = CGSize(width: newValue, height: newValue) }
    }
    
    private var thumbNodeRadius: CGFloat! {
        get { return (thumbNode.size.width / two) }
    }
    
    weak var delegate: FlightYokeProtocol! {
        didSet {
            velocity = CGVector.zero
            recenter()
            runtimeLoop = CADisplayLink(every: { [weak self] in self?.update() })
            runtimeLoop?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
        }
    }
    
    func update() {
        
        delegate?.FlightYokePilot(velocity: velocity, zRotation: CGFloat( velocity.dx / multiplier * dx ))
        
        if velocity != CGVector.zero {
            focus = true
        } else if focus {
            focus = false
            
            let easeOut: SKAction = SKAction.move(to: anchor, duration: thumbSpring)
            easeOut.timingMode = SKActionTimingMode.easeOut
            thumbNode.run(easeOut)
        }
    }
    
    convenience init(thumbImage: UIImage?) {
        self.init(thumbImage: thumbImage, bgImage: nil)
    }
    
    convenience init(bgImage: UIImage?) {
        self.init(thumbImage: nil, bgImage: bgImage)
    }
    
    convenience override init() {
        self.init(thumbImage: nil, bgImage: nil)
    }
    
    func startup() {
        setThumbImage(thumbImage, sizeToFit: true)
        backgroundImage(bgImage, sizeToFit: true)
        velocity = CGVector.zero
        
        addChild(backgroundNode)
        backgroundNode.isUserInteractionEnabled = false
        
        addChild(thumbNode)
        
        isUserInteractionEnabled = true
        thumbNode.zPosition = zindex
        thumbNode.isUserInteractionEnabled = false
    }
	
    func shutdown() {
        guard let runtime = runtimeLoop else { return }
        runtime.invalidate()
    }
    
    init(thumbImage: UIImage?, bgImage: UIImage?) {
        self.thumbImage = thumbImage
        self.bgImage = bgImage
        
        super.init()

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: recenter to zero
    func recenter() {
        if velocity != CGVector.zero && focus {
            velocity = CGVector.zero
        }
    }
    
    
    //MARK: Stick Moved (After)
    func stickMoved(location: CGPoint, snapToPoles: Bool = false) {
        
        //MARK: Clamp our max and min range of our joystick
        func clamp (_ f: CGFloat) -> CGFloat {
            min(max(f, -thumbNodeRadius), thumbNodeRadius)
        }
        
        //MARK: SnapToPoint (Up, Down, Left, Right)
        func snap (_ f: CGFloat, _ s: CGFloat ) -> CGFloat {
            f == -thumbNodeRadius || f == thumbNodeRadius
                && -snapToPoint...snapToPoint ~= s
                ? zero : s
        }
        
        //MARK: clampX and Y
        let clampX = clamp( floor(location.x) )
        let clampY = clamp( floor(location.y) )
        
        var moveToLocation = SKAction()
        
        if snapToPoles {
            let snapY = snap( clampX, clampY )
            let snapX = snap( clampY, clampX )
            
            velocity = CGVector(dx: snapX * multiplier, dy: ( snapY * multiplier ) / two )
            moveToLocation = SKAction.move(to: CGPoint( x: snapX, y: snapY ), duration: ease )
            
        } else {
            velocity = CGVector(dx: clampX * multiplier, dy: ( clampY * multiplier ) / two )
            moveToLocation = SKAction.move(to: CGPoint( x: clampX, y: clampY ), duration: ease )
        }
      
        
	
       
        moveToLocation.timingMode = .easeOut
        thumbNode.run( moveToLocation )
    }
    
    //MARK: Touches moved
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches as Set<UITouch>, with: event)
        
        if let location = touches.first?.location(in: self) {
            if location != CGPoint.zero  {
                 stickMoved(location: location)
            }
        }
    }
    
    //MARK: Touches ended
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if let location = touches.first?.location(in: self) {
            if location != CGPoint.zero  {
                recenter()
            }
        }
    }
}
