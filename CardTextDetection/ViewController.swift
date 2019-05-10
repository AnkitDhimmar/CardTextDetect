//
//  ViewController.swift
//  CardTextDetection
//
//  Created by Ankit on 09/05/19.
//  Copyright © 2019 DAC. All rights reserved.
//

import UIKit

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var session = AVCaptureSession()
    var requests = [VNRequest]()
    
    var faces: [VNFaceObservation]?
    var cards: [VNRectangleObservation]?
    var words: [VNTextObservation]?
    
    lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
        let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
        rectDetectRequest.maximumObservations = 2
        rectDetectRequest.minimumConfidence = 0.9
        rectDetectRequest.minimumAspectRatio = 0.2
        return rectDetectRequest
    }()
    
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
    lazy var textRequest: VNDetectTextRectanglesRequest = {
        let textDetect = VNDetectTextRectanglesRequest(completionHandler: self.detectTextHandler)
        textDetect.reportCharacterBoxes = true
        return textDetect
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startLiveVideo()
        startTextDetection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startLiveVideo() {
        //1
        session.sessionPreset = AVCaptureSession.Preset.photo
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        //2
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        //3
        let imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = imageView.bounds
        imageView.layer.addSublayer(imageLayer)
        
        session.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        imageView.layer.sublayers?[0].frame = imageView.bounds
    }
    
    func startTextDetection() {
        requests = [textRequest, rectangleDetectionRequest, faceDetectionRequest]
    }
    
    func handleDetectedFaces(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print("Face Detection Error: \(nsError)")
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            let results = request?.results as? [VNFaceObservation]
            if results?.count ?? 0 > 0 {
                self.faces = results
                self.showCard()
            }
            else {
                self.faces?.removeAll()
            }
        }
    }
    
    func handleDetectedRectangles(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            print("Rectangle Detection Error: \(nsError)")
            return
        }
        // Since handlers are executing on a background thread, explicitly send draw calls to the main thread.
        DispatchQueue.main.async {
            let results = request?.results as? [VNRectangleObservation]
            if results?.count ?? 0 > 0 {
                self.cards = results
                self.showCard()
            }
            else {
                self.cards?.removeAll()
            }
        }
    }
    
    func detectTextHandler(request: VNRequest, error: Error?) {
        if let nsError = error as NSError? {
            print("Rectangle Detection Error: \(nsError)")
            return
        }
        // Since handlers are executing on a background thread, explicitly send draw calls to the main thread.
        DispatchQueue.main.async {
            let results = request.results as? [VNTextObservation]
            if results?.count ?? 0 > 0 {
                self.words = results
                self.showCard()
            }
            else {
                self.words?.removeAll()
            }
        }
    }
    
    func showCard() {
        
        if let faces = faces, let cards = cards {
            
            self.imageView.layer.sublayers?.removeSubrange(1...)
            
            for card in cards {
                for face in faces {
                    if card.boundingBox.contains(face.boundingBox) {
                        let transform = CGAffineTransform.identity
                            .scaledBy(x: 1, y: -1)
                            .translatedBy(x: 0, y: -self.imageView.frame.height)
                            .scaledBy(x: self.imageView.frame.width, y: self.imageView.frame.height)
                        
                        let convertedTopLeft = card.topLeft.applying(transform)
                        let convertedTopRight = card.topRight.applying(transform)
                        let convertedBottomLeft = card.bottomLeft.applying(transform)
                        let convertedBottomRight = card.bottomRight.applying(transform)
                        
                        //print("====================")
                        //print(convertedTopLeft)
                        //print(convertedTopRight)
                        //print(convertedBottomLeft)
                        //print(convertedBottomRight)
                        //print("====================")
                        
                        let line = CAShapeLayer()
                        let linePath = UIBezierPath()
                        linePath.move(to: convertedTopLeft)
                        linePath.addLine(to: convertedTopRight)
                        linePath.addLine(to: convertedBottomRight)
                        linePath.addLine(to: convertedBottomLeft)
                        linePath.addLine(to: convertedTopLeft)
                        line.path = linePath.cgPath
                        if abs(convertedTopRight.y - convertedTopLeft.y) > 20 {
                            line.strokeColor = UIColor.red.cgColor
                        } else {
                            line.strokeColor = UIColor.green.cgColor
                        }
                        line.lineWidth = 4
                        line.fillColor = UIColor.clear.cgColor
                        line.lineJoin = CAShapeLayerLineJoin.round
                        self.imageView.layer.addSublayer(line)
                        
                        // Show rectangle to face
                        //self.draw(faces: [face], onImageWithBounds: imageView.bounds)
                        
                        for word in self.words ?? [] {
                            if card.boundingBox.contains(word.boundingBox) {
                                self.highlightWord(box: word)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {
            return
        }
        
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX * imageView.frame.size.width
        let yCord = (1 - minY) * imageView.frame.size.height
        let width = (minX - maxX) * imageView.frame.size.width
        let height = (minY - maxY) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.blue.cgColor
        
        imageView.layer.addSublayer(outline)
    }
    
    func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in faces {
            let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
            
            // Add to pathLayer on top of image.
            imageView.layer.addSublayer(faceLayer)
        }
        CATransaction.commit()
    }
    
    func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    
    func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 5
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
}
