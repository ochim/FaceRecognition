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

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private var sampleImage: UIImage?
    
    @IBOutlet weak var selectImaageButton: UIButton!
    @IBOutlet weak var faceDetectButton: UIButton!
    @IBOutlet weak var fillFaceButton: UIButton!
    @IBOutlet weak var mozaikuButton: UIButton!
    @IBOutlet weak var faceMozaikuButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!

    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //
        selectImaageButton.rx.tap.asDriver().drive(onNext: { _ in
            let picker = UIImagePickerController()
            picker.delegate = self
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: {action in
                    picker.sourceType = .camera
                    self.present(picker, animated: true, completion: nil)
                }))
            }
            alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { action in
                picker.sourceType = .photoLibrary
                // on iPad we are required to present this as a popover
                if UIDevice.current.userInterfaceIdiom == .pad {
                    picker.modalPresentationStyle = .popover
                    picker.popoverPresentationController?.sourceView = self.view
                    picker.popoverPresentationController?.sourceRect = self.selectImaageButton.frame
                }
                self.present(picker, animated: true, completion: nil)
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
        fillFaceButton.rx.tap.asDriver().drive(onNext: { _ in
            guard let sampleImage = self.sampleImage else {
                return
            }

            let request = VNDetectFaceRectanglesRequest { (request, error) in
                
                var image = sampleImage
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
            
            if let cgImage = sampleImage.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
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

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        let s = CGSize(width: image.size.width, height: image.size.height)
        UIGraphicsBeginImageContextWithOptions(s, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: s))
        sampleImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.imageView.image = sampleImage
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
    
}

extension CGRect {
    func converted(to size: CGSize) -> CGRect {
        return CGRect(x: self.minX * size.width,
                      y: (1 - self.maxY) * size.height,
                      width: self.width * size.width,
                      height: self.height * size.height)
    }
}

