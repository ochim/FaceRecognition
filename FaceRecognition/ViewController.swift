//
//  ViewController.swift
//  FaceRecognition
//
//  Created by nijibox088 on 2018/08/01.
//  Copyright © 2018年 recruit. All rights reserved.
//

import UIKit
import Vision
import CoreImage
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    private var sampleImage: UIImage?
    
    @IBOutlet weak var selectImaageButton: UIButton!
    @IBOutlet weak var faceDetectButton: UIButton!
    @IBOutlet weak var faceLandmarksButton: UIButton!
    @IBOutlet weak var mozaikuButton: UIButton!
    @IBOutlet weak var faceMozaikuButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!

    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //
        selectImaageButton.rx.tap.asDriver().drive(onNext: { _ in
            let picker = UIImagePickerController()
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: {action in
                    self.launchPhotoPicker(.camera)
                }))
            }
            alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { action in
                // on iPad we are required to present this as a popover
                if UIDevice.current.userInterfaceIdiom == .pad {
                    picker.modalPresentationStyle = .popover
                    picker.popoverPresentationController?.sourceView = self.view
                    picker.popoverPresentationController?.sourceRect = self.selectImaageButton.frame
                }
                self.launchPhotoPicker(.photoLibrary)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            // on iPad this is a popover
            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = self.selectImaageButton.frame
            
            self.present(alert, animated: true, completion: nil)

        }).disposed(by: disposeBag)
        
        //
        faceDetectButton.rx.tap.asDriver().drive(onNext: { _ in
            guard let sampleImage = self.sampleImage else {
                return
            }
            
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                var image = sampleImage
                for observation in request.results as! [VNFaceObservation] {
                    image = self.drawFaceRectangle(image: image, observation: observation)
                }

                self.imageView.image = image
            }

            if let cgImage = sampleImage.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }

        }).disposed(by: disposeBag)
        
        //
        faceLandmarksButton.rx.tap.asDriver().drive(onNext: { _ in
            guard let sampleImage = self.sampleImage else {
                return
            }

            var orientation:Int32 = 0
            
            // detect image orientation, we need it to be accurate for the face detection to work
            switch sampleImage.imageOrientation {
            case .up:
                orientation = 1
            case .right:
                orientation = 6
            case .down:
                orientation = 3
            case .left:
                orientation = 8
            default:
                orientation = 1
            }
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleFaceFeatures)
            let requestHandler = VNImageRequestHandler(cgImage: sampleImage.cgImage!, orientation: CGImagePropertyOrientation(rawValue: CGImagePropertyOrientation.RawValue(orientation))! ,options: [:])
            do {
                try requestHandler.perform([faceLandmarksRequest])
            } catch {
                print(error)
            }

        }).disposed(by: disposeBag)
        
        //
        mozaikuButton.rx.tap.asDriver().drive(onNext: { _ in
            guard let sampleImage = self.sampleImage else {
                return
            }
            self.imageView.image = self.mozaiku(image: sampleImage, block: 20)
            
        }).disposed(by: disposeBag)
        
        //
        faceMozaikuButton.rx.tap.asDriver().drive(onNext: { _ in
            guard let sampleImage = self.sampleImage else {
                return
            }
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                let image = sampleImage
                let mi = self.mozaiku(image: image, block: 20)
                
                var tmp: UIImage? = nil
                for observation in request.results as! [VNFaceObservation] {
                    let rect = observation.boundingBox.converted(to: image.size)
                    let ci = mi.cropping(to: rect)
                    if tmp == nil {
                        tmp = image.composite(image: ci!, imageX: rect.origin.x, imageY: rect.origin.y)
                    } else {
                        tmp = tmp!.composite(image: ci!, imageX: rect.origin.x, imageY: rect.origin.y)
                    }
                }
                self.imageView.image = tmp
            }
            
            if let cgImage = sampleImage.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }

        }).disposed(by: disposeBag)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // UIImagePickerControllerの起動と選択した画像の処理
    private func launchPhotoPicker(_ type: UIImagePickerController.SourceType) {
        UIImagePickerController.rx.createWithParent(self) { picker in
                picker.sourceType = type
                picker.allowsEditing = false
            }
            .flatMap { $0.rx.didFinishPickingMediaWithInfo }
            .take(1)
            .map { info in
                let image = info[UIImagePickerControllerOriginalImage] as! UIImage
                let s = CGSize(width: image.size.width, height: image.size.height)
                UIGraphicsBeginImageContextWithOptions(s, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: s))
                self.sampleImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return self.sampleImage!
            }
            .bind(to: self.imageView.rx.image)
            .disposed(by: disposeBag)
    }

    private func mozaiku(image: UIImage, block: CGFloat) -> UIImage {
        let ciPhoto = CIImage(cgImage: image.cgImage!)
        
        // フィルタの名前を指定する(モザイク処理)
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(ciPhoto, forKey: kCIInputImageKey)
        filter?.setValue(block, forKey: "inputScale")      // ブロックの大きさ
        
        let filteredImage:CIImage = (filter?.outputImage)!
        let ciContext:CIContext = CIContext(options: nil)
        let imageRef = ciContext.createCGImage(filteredImage, from: filteredImage.extent)
        
        // scaleに注意
        let outputImage = UIImage(cgImage:imageRef!, scale:UIScreen.main.scale, orientation:UIImageOrientation.up)
        return outputImage
    }
    
    private func drawFaceRectangle(image: UIImage, observation: VNFaceObservation) -> UIImage {
        let imageSize = image.size
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        context?.setLineWidth(2.0)
        context?.setStrokeColor(UIColor.green.cgColor)
        context?.stroke(observation.boundingBox.converted(to: imageSize))
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return drawnImage!
    }
    
    // 目印判定の後処理
    func handleFaceFeatures(request: VNRequest, errror: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else {
            fatalError("unexpected result type!")
        }
        
        guard let sampleImage = self.sampleImage else {
            return
        }
        
        let s = CGSize(width: sampleImage.size.width, height: sampleImage.size.height)
        UIGraphicsBeginImageContextWithOptions(s, false, 0.0)
        sampleImage.draw(in: CGRect(origin: .zero, size: s))
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        for face in observations {
            image = addFaceLandmarksToImage(face, image!)
        }
        self.imageView.image = image
    }
    
    func addFaceLandmarksToImage(_ face: VNFaceObservation, _ baseImage: UIImage) -> UIImage {

        let lineWidth: CGFloat = 2.0
        
        UIGraphicsBeginImageContextWithOptions(baseImage.size, true, 0.0)
        let context = UIGraphicsGetCurrentContext()
        
        // draw the image
        baseImage.draw(in: CGRect(x: 0, y: 0, width: baseImage.size.width, height: baseImage.size.height))

        context?.translateBy(x: 0, y: baseImage.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        // draw the face rect
        let w = face.boundingBox.size.width * baseImage.size.width
        let h = face.boundingBox.size.height * baseImage.size.height
        let x = face.boundingBox.origin.x * baseImage.size.width
        let y = face.boundingBox.origin.y * baseImage.size.height
        let faceRect = CGRect(x: x, y: y, width: w, height: h)
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        context?.setLineWidth(lineWidth)
        context?.addRect(faceRect)
        context?.drawPath(using: .stroke)
        context?.restoreGState()
        
        // face contour
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.faceContour {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // outer lips
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.outerLips {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // inner lips
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.innerLips {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // left eye
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.leftEye {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // right eye
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.rightEye {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // left pupil
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.leftPupil {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // right pupil
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.rightPupil {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // left eyebrow
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.leftEyebrow {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // right eyebrow
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.rightEyebrow {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // nose
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.nose {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.closePath()
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // nose crest
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.noseCrest {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // median line
        context?.saveGState()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        if let landmark = face.landmarks?.medianLine {
            for i in 0...landmark.pointCount - 1 { // last point is 0,0
                let point = landmark.normalizedPoints[i] //.point(at: i)
                if i == 0 {
                    context?.move(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                } else {
                    context?.addLine(to: CGPoint(x: x + CGFloat(point.x) * w, y: y + CGFloat(point.y) * h))
                }
            }
        }
        context?.setLineWidth(lineWidth)
        context?.drawPath(using: .stroke)
        context?.saveGState()
        
        // get the final image
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // end drawing context
        UIGraphicsEndImageContext()
        
        return finalImage!
    }
    
}

extension CGRect {
    func converted(to size: CGSize) -> CGRect {
        return CGRect(x: self.minX * size.width,
                      y: (1 - self.maxY) * size.height,
                      width: self.width * size.width,
                      height: self.height * size.height)
    }
}

