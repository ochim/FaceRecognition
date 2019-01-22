//
//  UIImage+Extension.swift
//  FaceRecognition
//
//  Created by nijibox088 on 2019/01/22.
//  Copyright © 2019年 recruit. All rights reserved.
//

import UIKit

extension UIImage {
    // 切り抜き
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
    // 合成
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
