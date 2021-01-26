//
//  ViewController.swift
//  iChunithmController
//
//  Created by Seru on 2021/01/01.
//

import UIKit
import Network
import LessUI

import Socket

class AppViewController: UIViewController {
	
	enum MessageSources: UInt8 {
		case game = 0
		case controller = 1
	}
	
	enum MessageTypes: UInt8 {
		case coin = 0
		case sliderPress = 1
		case sliderRelease = 2
		case ledSet = 3
		case cabinetTest = 4
		case cabinetService = 5
		case irBlocked = 6
		case irUnblocked = 7
	}
	
	enum IOType: UInt8 {
		case ir = 0
		case slider = 1
	}
	
	struct Message {
		var Source: UInt8
		var `Type`: UInt8
		var Target: UInt8
		var LedColorRed: UInt8
		var LedColorGreen: UInt8
		var LedColorBlue: UInt8
	}
	
	var destIP: String = "192.168."
	var destPort: String = "24864"
	var socket: Socket?
	var receiveSocket: Socket?
	
	var fingers: Int = 0
	
	var listeningData: Data = Data()
	
	let statusLabel: UILabel = UILabel()
	let buttonCoin: UIButton = UIButton()
	let buttonService: UIButton = UIButton()
	let buttonTest: UIButton = UIButton()
	let buttonIRToggle: UIButton = UIButton()
	
	var sliderContainer: UIView = UIView()
	var sliders: [UIView] = []
	var irs: [UIView] = []
	
	private var listenQueue: DispatchQueue?
	
	private var touchCoords: [UITouch:[Int]] = [:]
	private var sliderPresses: [Int: Bool] = [:]
	
	private var irTouchCoords: [UITouch:[Int]] = [:]
	private var irPresses: [Int: Bool] = [:]
	
	private var irAvailable: Bool = true

	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		statusLabel.style(size: 13, color: .black, bold: true, align: .left, lines: 0)
			.add(to: view)
			.text = "iChunithm"
		
		// Setup buttons
		buttonCoin.style(color: .white, background: UIColor(rgb: 0x333333), radius: 2, title: "COIN", size: 13, bold: false)
			.regist(to: self, act: #selector(coinTouchHandler), for: .touchUpInside)
			.add(to: view)
		buttonService.style(color: .white, background: UIColor(rgb: 0x333333), radius: 2, title: "SERVICE", size: 13, bold: false)
			.regist(to: self, act: #selector(serviceTouchHandler), for: .touchUpInside)
			.add(to: view)
		buttonTest.style(color: .white, background: UIColor(rgb: 0x333333), radius: 2, title: "TEST", size: 13, bold: false)
			.regist(to: self, act: #selector(testTouchHandler), for: .touchUpInside)
			.add(to: view)
		buttonIRToggle.style(color: .white, background: UIColor(rgb: 0x333333), radius: 2, title: "IR ON", size: 13, bold: false)
			.regist(to: self, act: #selector(irTouchHandler), for: .touchUpInside)
			.add(to: view)
		
		sliderContainer.back(UIColor(rgb: 0xCCCCCC))
			.add(to: view)
		
		
		for _: Int in 0 ..< 16 {
			let v: UIView = UIView()
			
			v.add(to: view).back(.black)
			sliders += [v]
		}
		for i: Int in 0 ..< 6 {
			let v: UIView = UIView()
			
			v.add(to: view).back(UIColor(rgb: 0x333333))
			v.alpha = 0.2 * CGFloat(i)
			irs += [v]
		}
		
		back(.white)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		requestConnect()
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		buttonCoin.set(x: w - 48 - 8, y: 12, w: 48, h: 42)
		buttonService.set(x: buttonCoin.x - 64 - 8, y: 12, w: 64, h: 42)
		buttonTest.set(x: buttonService.x - 48 - 8, y: 12, w: 48, h: 42)
		buttonIRToggle.set(x: buttonTest.x - 86 - 8, y: 12, w: 86, h: 42)
		
		let sliderSize: CGFloat = 480
		sliderContainer.set(x: 0, y: h - sliderSize - 4, w: w, h: sliderSize)
		
		let blockSize: CGFloat = w / 16
		for i: Int in 0 ..< sliders.count {
			sliders[i].set(x: blockSize * CGFloat(i), y: sliderContainer.y + 4, w: blockSize, h: sliderSize)
		}
		
		let irsSize: CGFloat = 420
		let irBlockSize: CGFloat = irsSize / 6
		for i: Int in 0 ..< irs.count {
			irs[i].set(x: 0, y: sliderContainer.y - irsSize + (irBlockSize * CGFloat(i)),
						   w: w, h: irBlockSize)
			
		}
		
	}
	
	override var prefersStatusBarHidden: Bool {
		return true
	}
	
	override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
		return .top
	}
	
	override var prefersHomeIndicatorAutoHidden: Bool {
		return true
	}
	
}


extension AppViewController {
	
	private func requestConnect(force: Bool = false) {
		if socket != nil && !force { return }
		
		let alert = UIAlertController(title: "Connect to server",
									  message: "Make sure chunithm is running, and Chunithm-vcontroller (chuniio.dll) installed",
									  preferredStyle: .alert)
		let ok = UIAlertAction(title: "Connect", style: .default) { (ok) in
			let ip: String = alert.textFields?[0].text ?? ""
			let port: String = alert.textFields?[1].text ?? ""
			
			self.setupClient(with: ip, port)
			
		}

		let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (cancel) in }

		alert.addAction(cancel)
		alert.addAction(ok)
		alert.addTextField { textField in
			textField.text = self.destIP
			textField.placeholder = "IP"
		}
		alert.addTextField { textField in
			textField.text = self.destPort
			textField.placeholder = "Port"
		}
		
		self.present(alert, animated: true, completion: nil)
	}
	
	private func setupClient(with ip: String, _ port: String) {
		destIP = ip
		destPort = port
		
		socket = try? Socket.create(family: .inet, type: .datagram, proto: .udp)
		receiveSocket = try? Socket.create(family: .inet, type: .datagram, proto: .udp)
		
		listenQueue = DispatchQueue.global(qos: .userInteractive)
		guard let dQueue = listenQueue else {
			return
		}
		dQueue.async {
			var keepRunning = true
			
			_ = try? self.socket?.listen(on: Int(self.destPort) ?? 0)
			repeat {
				var d: Data = Data()
				_ = try? self.socket?.readDatagram(into: &d)
				
				if d.count == 6 {
					let msg: Message = Message(Source: d[0], Type: d[1], Target: d[2], LedColorRed: d[3], LedColorGreen: d[4], LedColorBlue: d[5])
					
					switch msg.Source {
					case MessageSources.game.rawValue:
						self.parse(message: msg)
					default: break
					}
				}
				
			} while keepRunning
		}
		
	}
	
	private func parse(message msg: Message) {
		DispatchQueue.main.async {
			switch msg.Type {
			case MessageTypes.ledSet.rawValue:
				self.updateSliderLED(with: msg)
			default: break
			}
		}
	}
	
	private func updateSliderLED(with msg: Message) {
		//print("Update LED", msg.Target, msg.LedColorRed, msg.LedColorGreen, msg.LedColorBlue)
		
		for i: Int in 0 ..< sliders.count {
			if 15 - i == msg.Target {
				sliders[i].back(UIColor(r: Int(msg.LedColorRed),
										g: Int(msg.LedColorGreen),
										b: Int(msg.LedColorBlue), a: 1))
			}
		}
	}
	
	private func updateStatus(to text: String) {
		DispatchQueue.main.async {
			self.statusLabel.text = text
			self.statusLabel.prefix()
			
			self.statusLabel.set(x: 12, y: 12, w: self.statusLabel.w, h: self.statusLabel.h)
		}
	}
	
}

extension AppViewController {
	
	@objc private func coinTouchHandler(sender: UIButton) {
		_ = try? socket?.write(from: buildData(source: .controller, type: .coin),
							   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
	}
	
	@objc private func serviceTouchHandler(sender: UIButton) {
		_ = try? socket?.write(from: buildData(source: .controller, type: .cabinetService),
							   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
	}
	
	@objc private func testTouchHandler(sender: UIButton) {
		_ = try? socket?.write(from: buildData(source: .controller, type: .cabinetTest),
							   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
	}
	@objc private func irTouchHandler(sender: UIButton) {
		irAvailable = !irAvailable
		sender.setTitle(irAvailable ? "IR ON" : "IR OFF", for: .normal)
	}
	
	
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		touches.forEach { t in
			let point: CGPoint = t.location(in: view)
			touchCoords[t] = findSliders(with: point)
			irTouchCoords[t] = findIRs(with: point)
		}
		fingers += touches.count
		updateSliders()
		updateIRs()
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		touches.forEach { t in
			let point: CGPoint = t.location(in: view)
			touchCoords[t] = findSliders(with: point)
			irTouchCoords[t] = findIRs(with: point)
		}
		
		updateSliders()
		updateIRs()
	}
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		touches.forEach { t in
			touchCoords[t] = nil
			irTouchCoords[t] = nil
		}
		
		fingers -= touches.count
		if fingers <= 0 {
			fingers = 0
			touchCoords.removeAll()
			irTouchCoords.removeAll()
			
			sliderPresses.removeAll()
			irPresses.removeAll()
		}
		
		updateSliders()
		updateIRs()
	}
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		touchesEnded(touches, with: event)
	}

	
}

extension AppViewController {
	
	private func updateSliders() {
		var availables: [Int] = []
		var nonAvailables: [Int] = Array(0 ..< 16)
		
		touchCoords.forEach { k, v in
			v.forEach { i in
				if availables.firstIndex(of: i) == nil { availables += [i] }
			}
		}
		availables.forEach { i in
			if let re = nonAvailables.firstIndex(of: i) {
				nonAvailables.remove(at: re)
			}
		}
		
		for i: Int in 0 ..< availables.count {
			sliderPresses[availables[i]] = true
			
			_ = try? socket?.write(from: buildData(source: .controller, type: .sliderPress, target: UInt8(15 - availables[i])),
								   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
		}
		
		for i: Int in 0 ..< nonAvailables.count {
			sliderPresses[nonAvailables[i]] = nil
			
			_ = try? socket?.write(from: buildData(source: .controller, type: .sliderRelease, target: UInt8(15 - nonAvailables[i])),
								   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
		}
	}
	
	private func updateIRs() {
		if !irAvailable { return }
		
		var availables: [Int] = []
		var nonAvailables: [Int] = Array(0 ..< 6)
		
		irTouchCoords.forEach { k, v in
			v.forEach { i in
				if availables.firstIndex(of: i) == nil { availables += [i] }
			}
		}
		availables.forEach { i in
			if let re = nonAvailables.firstIndex(of: i) {
				nonAvailables.remove(at: re)
			}
		}
		
		for i: Int in 0 ..< availables.count {
			irPresses[availables[i]] = true
			
			_ = try? socket?.write(from: buildData(source: .controller, type: .irBlocked, target: UInt8(5 - availables[i])),
								   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
		}
		
		for i: Int in 0 ..< nonAvailables.count {
			irPresses[nonAvailables[i]] = nil
			
			_ = try? socket?.write(from: buildData(source: .controller, type: .irUnblocked, target: UInt8(5 - nonAvailables[i])),
								   to: Socket.createAddress(for: destIP, on: Int32(destPort)!)!)
		}
	}
	
	private func findSliders(with point: CGPoint) -> [Int] {
		var nearestViews: [Int] = []
		
		for i: Int in 0 ..< sliders.count {
			let b: CGRect = CGRect(x: sliders[i].x - 12, y: sliders[i].y - 12,
								   w: sliders[i].w + 24, h: sliders[i].h + 24)
			
			if point.x >= b.minX && point.x <= b.maxX && point.y >= b.minY && point.y <= b.maxY {
				nearestViews += [i]
			}
		}
		
		return nearestViews
	}
	
	private func findIRs(with point: CGPoint) -> [Int] {
		var nearestViews: [Int] = []
		
		for i: Int in 0 ..< irs.count {
			let b: CGRect = CGRect(x: irs[i].x - 12, y: irs[i].y - 12,
								   w: irs[i].w + 24, h: irs[i].h + 24)
			
			if point.x >= b.minX && point.x <= b.maxX && point.y >= b.minY && point.y <= b.maxY {
				nearestViews += [i]
			}
		}
		
		return nearestViews
	}
		
	private func buildData(source: MessageSources, type: MessageTypes, target: UInt8 = 0) -> Data {
		var datas: Message = Message(
			Source: source.rawValue,
			Type: type.rawValue,
			Target: target,
			LedColorRed: 0, LedColorGreen: 0, LedColorBlue: 0
		)
		
		return Data(bytes: &datas, count: MemoryLayout<Message>.size)
	}
	
}

extension AppViewController: UIGestureRecognizerDelegate {
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
}
//
//extension AppViewController: GCDAsyncUdpSocketDelegate {
//
//	func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
//		updateStatus(to: "Successfully connected to game")
//	}
//	func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
//		print(error)
//		updateStatus(to: "Socket closed: \(error?.localizedDescription ?? "-")")
//	}
//	func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
//		print(data.count, data.first, data.last)
//	}
//
//
//}
