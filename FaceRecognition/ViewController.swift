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

    private let originalImage = UIImage(named: "usj")
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.imageView.image = originalImage
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func reset(_ sender: Any) {
        self.imageView.image = originalImage
    }
    
    @IBAction func filterImage(_ sender: Any) {
        
        let ciPhoto = CIImage(cgImage: (self.imageView.image?.cgImage)!)
        
        // フィルタの名前を指定する(今回はモザイク処理)
        let filter = CIFilter(name: "CIPixellate")
        // setValueで対象の画像、効果を指定する
        filter?.setValue(ciPhoto, forKey: kCIInputImageKey) // フィルタをかける対象の写真
        filter?.setValue(10, forKey: "inputScale")          // ブロックの大きさ
        
        // フィルタ処理のオブジェクト
        let filteredImage:CIImage = (filter?.outputImage)!
        // 矩形情報をセットしてレンダリング
        let ciContext:CIContext = CIContext(options: nil)
        let imageRef = ciContext.createCGImage(filteredImage, from: filteredImage.extent)
        // やっとUIImageに戻る
        let outputImage = UIImage(cgImage:imageRef!, scale:1.0, orientation:UIImageOrientation.up)
        self.imageView.image = outputImage
    }
    
    @IBAction func faceDetection() {
        
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            var image = self.imageView.image
            for observation in request.results as! [VNFaceObservation] {
                image = self.drawFaceRectangle(image: image, observation: observation)
            }

            self.imageView.image = image
        }
        
        if let cgImage = self.imageView.image?.cgImage {
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

extension CGRect {
    func converted(to size: CGSize) -> CGRect {
        return CGRect(x: self.minX * size.width,
                      y: (1 - self.maxY) * size.height,
                      width: self.width * size.width,
                      height: self.height * size.height)
    }
}

