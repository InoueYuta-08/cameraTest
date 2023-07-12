//
//  ViewController.swift
//  cameraTest
//
//  Created by 井上雄太 on 2023/06/05.
//

import UIKit
import ARKit
//音再生
import AVFoundation

class ViewController: UIViewController, ARSessionDelegate {
    
//    ボタン変数
    @IBOutlet weak var button: UIButton!
    
//    ラベル変数
    @IBOutlet weak var label: UILabel!
    
    
    var sceneView: ARSCNView!
    var device: AVCaptureDevice!
    var PreviewLayer: AVCaptureVideoPreviewLayer?
    var session = AVCaptureSession()
    
    var isHandDetectionEnabled: Bool = true
    
//    ボタンが押された時にマーカーを出すか出さないかフラグ
    var malkerFlag: Bool = false
//    画面が左に倒した時だけ反応するようにするフラグ
    var orientationFlag: Bool = false
    
//    花火音データ取得
    let hanabiData = NSDataAsset(name: "hanabi")!.data
    
//    花火音再生用オブジェクト
    var hanabiSound: AVAudioPlayer!
    
//    画質設定
    func setupCaptureSession() {
        session.sessionPreset = AVCaptureSession.Preset.cif352x288
    }
    
//    デバイス設定
    func setupDevice() {
        session = AVCaptureSession()
//        背面カメラ
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
//        背面カメラからキャプチャ入力生成
        guard let input = try? AVCaptureDeviceInput(device: device)
        else {
            print("例外発生")
            return
        }
        session.addInput(input)
        let output = AVCapturePhotoOutput()
        session.addOutput(output)
    }
    
//    カメラプレビューのセットアップ
    func setupPreview() {
        self.PreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.PreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.PreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.PreviewLayer?.frame = view.frame
        self.view.layer.insertSublayer(self.PreviewLayer!, at: 0)
    }
    
//    labelセットアップ
    func setupLabel() {
        let angle = 90 * CGFloat.pi / 180
        let trans = CGAffineTransform(rotationAngle: CGFloat(angle))
        label.transform = trans
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let screenWidth = UIScreen.main.bounds.width
//        let screenHeight = UIScreen.main.bounds.height
//        print(screenWidth, screenHeight)
        
//        labelセットアップ
        setupLabel()
        
//        セッション、デバイス、プレビューのセットアップ
        setupCaptureSession()
        setupDevice()
        setupPreview()
        
//        カメラセッション開始
        DispatchQueue.global().async {
            self.session.startRunning()
        }
        
//        ARセッションのセットアップと開始
        let configuration = ARBodyTrackingConfiguration()
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.session.delegate = self
        sceneView.session.run(configuration)
        view.addSubview(sceneView)
        
        view.bringSubviewToFront(button)
        view.bringSubviewToFront(label)
    }
    

    override func viewWillAppear(_ animated: Bool) {
        //    画面をスリープさせない
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
//        画面の向きが変わった時に発動
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
//    画面の向きが横かどうか判定
    @objc func orientationDidChange() {
        let currentOrientation = UIDevice.current.orientation
            switch currentOrientation {
            case .landscapeLeft:
                print("横向き")
                orientationFlag = true
                label.isHidden = true
            default:
                print("その他の向き")
                orientationFlag = false
                label.isHidden = false
            }
    }
    
//    パーティクル設定
    func particle(x:CGFloat, y:CGFloat) {
//        作成したパーティクルのファイル名
        let emitterNode = SKEmitterNode(fileNamed: "firework")!
        emitterNode.position = CGPoint(x: x, y: view.bounds.height - y)
        let skScene = SKScene(size: sceneView.bounds.size)
        skScene.backgroundColor = .clear
        skScene.addChild(emitterNode)
        
        sceneView.overlaySKScene = skScene
        
        let showAction = SKAction.run {
            self.sceneView.overlaySKScene?.isHidden = false
        }
        
        let hideAction = SKAction.run {
            self.sceneView.overlaySKScene?.isHidden = true
        }

//        何秒で存在自体を消すか
        let waitAction = SKAction.wait(forDuration: 3)
        let sequenceAction = SKAction.sequence([showAction, waitAction, hideAction])
        
        skScene.run(sequenceAction)
    }

//    ARセッションのデリゲートメソッド
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        手の検出が有効でない場合はこれ以降の処理を行わない
        guard isHandDetectionEnabled else {
            return
        }
        
//        画面の向きが左横になってない場合はこれ以降処理を行わない
        guard orientationFlag else {
            return
        }
        
        for anchor in anchors {
            // BodyAnchorにキャストできない場合はスキップ
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            guard let currentFrame = sceneView.session.currentFrame else { return }

//            右手の検出
            guard let rightHandTransform = bodyAnchor.skeleton.modelTransform(for: .rightHand) else { continue }
            let rightHandTrans = bodyAnchor.transform * rightHandTransform
            let rightHandCurrentPosition = rightHandTrans.columns.3
            let rightHandCurrentPosition3D = SIMD3<Float>(rightHandCurrentPosition.x, rightHandCurrentPosition.y, rightHandCurrentPosition.z)
            let rightHandScreenPosition = currentFrame.camera.projectPoint(rightHandCurrentPosition3D, orientation: UIInterfaceOrientation.portrait, viewportSize: sceneView.bounds.size)
            
//            頭の検出
            guard let headTransform = bodyAnchor.skeleton.modelTransform(for: .head) else { continue }
            let headTrans = bodyAnchor.transform * headTransform
            let headCurrentPosition = headTrans.columns.3
            let headCurrentPosition3D = SIMD3<Float>(headCurrentPosition.x, headCurrentPosition.y, headCurrentPosition.z)
            let headscreenPosition = currentFrame.camera.projectPoint(headCurrentPosition3D, orientation: UIInterfaceOrientation.portrait, viewportSize: sceneView.bounds.size)
            
//            右手のx座標が頭のx座標よりも大きくなったら花火バーン（その後、3秒何もしない）
            if rightHandScreenPosition.x > headscreenPosition.x {
                isHandDetectionEnabled = false
                
                // パーティクルを表示する処理
                particle(x: rightHandScreenPosition.x, y: rightHandScreenPosition.y)
                
//                音出す処理
                playHnabi()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.isHandDetectionEnabled = true
                }
            }
            
//            ボタンが押されたらマーカーが出るか切り替える
            if malkerFlag {
    //            手の位置にsquare作成
                rightHandCreateSquare(positionX: rightHandScreenPosition.x, positionY: rightHandScreenPosition.y)
    //            頭の位置にsquare作成
                headCreateSquare(positionX: headscreenPosition.x, positionY: headscreenPosition.y)

//                print("X: \(CGFloat(rightHandScreenPosition.x))")
//                print("Y: \(CGFloat(rightHandScreenPosition.y))")
//
//                print("X head: \(CGFloat(headscreenPosition.x))")
//                print("Y head: \(CGFloat(headscreenPosition.y))")
            }
        }
    }
    
//    花火音再生
    func playHnabi() {
        do {
            hanabiSound = try AVAudioPlayer(data: hanabiData)
            hanabiSound.play()
        } catch {
            print("再生に失敗")
        }
    }
    
    @IBAction func markerButton(_ sender: UIButton) {
        malkerFlag = !malkerFlag
    }
    
    
    
//    ーーーーーーーーーーーーーーーーーーデバッグ用 手、頭の位置ーーーーーーーーーーーーーーーーーー
//    手の位置を表示するsquare作成
    func rightHandCreateSquare(positionX: Double, positionY: Double) {
        let markerView = UIImageView(frame: CGRect(x: positionX, y: positionY, width: 10, height: 10))
        markerView.backgroundColor = UIColor.red
        self.sceneView.addSubview(markerView)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) {
            timer in markerView.removeFromSuperview()
        }
    }
    
//    頭の位置を表示するsquare作成
    func headCreateSquare(positionX: Double, positionY: Double) {
        let markerView = UIImageView(frame: CGRect(x: positionX, y: positionY, width: 10, height: 10))
        markerView.backgroundColor = UIColor.blue
        self.sceneView.addSubview(markerView)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) {
            timer in markerView.removeFromSuperview()
        }
    }
}
