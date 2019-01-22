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

    private let originalImage = UIImage(named: "futago")

    @IBOutlet weak var faceDetectButton: UIButton!
    @IBOutlet weak var fillFaceButton: UIButton!
    @IBOutlet weak var mozaikuButton: UIButton!
    @IBOutlet weak var faceMozaikuButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!

    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = originalImage
        
        faceDetectButton.rx.tap.subscribe(onNext: { _ in
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                var image = self.originalImage
                for observation in request.results as! [VNFaceObservation] {
                    image = self.drawFaceRectangle(image: image, observation: observation)
                }
                
                self.imageView.image = image
            }
            
            if let cgImage = self.originalImage?.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }

        }).disposed(by: disposeBag)
        
        fillFaceButton.rx.tap.subscribe(onNext: { _ in
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                
                var image = self.originalImage!
                for observation in request.results as! [VNFaceObservation] {
                    let rect = observation.boundingBox.converted(to: image.size)
                    
                    UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
                    let context = UIGraphicsGetCurrentContext()
                    image.draw(in: CGRect(origin: .zero, size: image.size))
                    context?.setFillColor(UIColor.black.cgColor)
                    context?.fill(rect)
                    let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    image = drawnImage!
                }
                self.imageView.image = image
            }
            
            if let cgImage = self.originalImage?.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }

        }).disposed(by: disposeBag)
        
        mozaikuButton.rx.tap.subscribe(onNext: { _ in
            self.imageView.image = self.mozaiku(image: self.originalImage!, block: 10)
        }).disposed(by: disposeBag)
        
        faceMozaikuButton.rx.tap.subscribe(onNext: { _ in
            let request = VNDetectFaceRectanglesRequest { (request, error) in
                let image = self.originalImage!
                let mi = self.mozaiku(image: image, block: 10)
                
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
            
            if let cgImage = self.originalImage?.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
            }

        }).disposed(by: disposeBag)
        
        resetButton.rx.tap.subscribe(onNext: { _ in
            self.imageView.image = self.originalImage
        }).disposed(by: disposeBag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    private func drawFaceRectangle(image: UIImage?, observation: VNFaceObservation) -> UIImage? {
        let imageSize = image!.size
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        image?.draw(in: CGRect(origin: .zero, size: imageSize))
        context?.setLineWidth(2.0)
        context?.setStrokeColor(UIColor.green.cgColor)
        context?.stroke(observation.boundingBox.converted(to: imageSize))
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return drawnImage
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

