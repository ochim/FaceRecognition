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

class ViewController: UIViewController {

    private let originalImage = UIImage(named: "futago")
    //private let originalImage = UIImage(named: "usj")
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    private var contractedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetButton.isHidden = true
        // 縮小させる
        let s = CGSize(width: originalImage!.size.width*0.8, height: originalImage!.size.height*0.8)
        UIGraphicsBeginImageContextWithOptions(s, false, 0.0)
        originalImage?.draw(in: CGRect(origin: .zero, size: s))
        contractedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        self.imageView.image = contractedImage
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func reset(_ sender: Any) {
        self.imageView.image = contractedImage
    }
    
    @IBAction func filterImage(_ sender: Any) {
        
        self.imageView.image = mozaiku(image: contractedImage!, block: 10)
    }
    
    private func mozaiku(image: UIImage, block: CGFloat) -> UIImage {
        let ciPhoto = CIImage(cgImage: image.cgImage!)
        
        // フィルタの名前を指定する(今回はモザイク処理)
        let filter = CIFilter(name: "CIPixellate")
        // setValueで対象の画像、効果を指定する
        filter?.setValue(ciPhoto, forKey: kCIInputImageKey) // フィルタをかける対象の写真
        filter?.setValue(block, forKey: "inputScale")          // ブロックの大きさ
        
        // フィルタ処理のオブジェクト
        let filteredImage:CIImage = (filter?.outputImage)!
        // 矩形情報をセットしてレンダリング
        let ciContext:CIContext = CIContext(options: nil)
        let imageRef = ciContext.createCGImage(filteredImage, from: filteredImage.extent)
        // やっとUIImageに戻る
        // scaleは1.0 or 2.0
        let outputImage = UIImage(cgImage:imageRef!, scale:2.0, orientation:UIImageOrientation.up)
        return outputImage
    }
    
    @IBAction func faceDetection() {
        
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            var image = self.contractedImage
            for observation in request.results as! [VNFaceObservation] {
                image = self.drawFaceRectangle(image: image, observation: observation)
            }
            
            self.imageView.image = image
        }
        
        if let cgImage = self.contractedImage?.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
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
    
    @IBAction func fillFace() {
        
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            
            var image = self.contractedImage!
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
        
        if let cgImage = self.contractedImage?.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
        
    }
    
    @IBAction func faceMozaiku() {

        let request = VNDetectFaceRectanglesRequest { (request, error) in
            let image = self.contractedImage!
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
        
        if let cgImage = self.contractedImage?.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }

    }
}

extension UIImage {
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, scale)
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    func composite(image: UIImage, imageX: CGFloat, imageY: CGFloat) -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        
        let rect = CGRect(x: imageX,
                          y: imageY,
                          width: image.size.width,
                          height: image.size.height)
        image.draw(in: rect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
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

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //　撮影が完了時した時に呼ばれる
    func imagePickerController(_ imagePicker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.imageView.image = pickedImage
        }
        
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    // 撮影がキャンセルされた時に呼ばれる
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    // アルバムを表示
    @IBAction func showAlbum(_ sender : AnyObject) {
        let sourceType:UIImagePickerControllerSourceType = UIImagePickerControllerSourceType.photoLibrary
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary){
            
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = sourceType
            cameraPicker.delegate = self
            self.present(cameraPicker, animated: true, completion: nil)
        }
        else{
        }
    }
    
}


