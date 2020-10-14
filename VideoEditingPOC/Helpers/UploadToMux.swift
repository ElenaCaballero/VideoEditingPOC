//
//  UploadToMux.swift
//  VideoEditingPOC
//
//  Created by Elena Caballero on 6/2/20.
//  Copyright © 2020 Elena Caballero. All rights reserved.
//

import AVFoundation
import Photos
import Alamofire

class UploadToMux {
    static let MUX_TOKEN_ID: String = "fe5360cc-5de8-4f15-bd7b-a95d7def942f"
    static let MUX_TOKEN_SECRET: String = "VHNxOYCQmHC2x2UXmODrrJHMzdUdgU87JAHUe8V0v2UG+dhndGmCXSQ1VDLpsgWeoCviL5ocqTF"
    
    static func uploadVideo(with info: [UIImagePickerController.InfoKey : Any]?, completion: @escaping ((Bool) -> Void)) {
        if let info = info, let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            print(videoURL)
            let asset = AVAsset(url: videoURL)
            let length = Float(asset.duration.value) / Float(asset.duration.timescale)
            // Selected time range that will be uploaded
            let editingEnd = UIImagePickerController.InfoKey(rawValue: "_UIImagePickerControllerVideoEditingEnd")
            let editingStart = UIImagePickerController.InfoKey(rawValue: "_UIImagePickerControllerVideoEditingStart")
            let start = info[editingStart] as? Float
            let end = info[editingEnd] as? Float
            
            let startTime = CMTime(seconds: Double(start ?? 0), preferredTimescale: 1000)
            let endTime = CMTime(seconds: Double(end ?? length), preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
            self.exportVideoToMP4(asset: asset, timeRange: timeRange) { (exportedVideoURL) in
                guard let tempURL = exportedVideoURL else {
                    completion(false)
                    print("ERROR: Unknown error. The exported video URL is nil.")
                    return
                }
                print("Temporary video successfully exported to: \(tempURL.absoluteString)")
                let muxURL = "https://api.mux.com/video/v1/uploads"
                let uuid = UUID().uuidString
                
                self.uploadToMux(to: muxURL, videoURL: tempURL, fileName: "vid-\(uuid).mp4", fieldName: "") { (response) in
                    guard let resp = response else {
                        completion(false)
                        print("ERROR: Empty or unrecognizable response from server.")
                        return
                    }

                    print("URL created. Data: \(resp)")
                    
                    if let uploadURL = resp["url"] as? String{
                        AF.upload(tempURL, to: uploadURL, method: .put).responseJSON { response in
                            if response.error != nil {
                                completion(true)
                            } else {
                                completion(false)
                            }
                            print("Response JSON: \(String(describing: response.value))")
                        }.responseDecodable(of: HTTPBinResponse.self) { response in
                            debugPrint("Response Decodable: \(response)")
                        }
                    }
                }
            }
        } else {
            let muxURL = "https://api.mux.com/video/v1/assets"
            guard let videoURL = URL(string: "https://www.dropbox.com/s/jyp3h9lrwgx0kkv/video.mp4?dl=0")  else {
                completion(false)
                debugPrint("URL not found")
                return
            }
            self.uploadTestToMux(to: muxURL, videoURL: videoURL) { (response) in
                guard let resp = response else {
                    print("ERROR: Empty or unrecognizable response from server.")
                    completion(false)
                    return
                }

                print("Video uploaded. RESPONSE: \(resp)")
                if resp["data"] != nil {
                    completion(true)
                } else if resp["error"] != nil {
                    completion(false)
                }
                
            }
        }
    }
    
    static private func exportVideoToMP4(asset: AVAsset, timeRange: CMTimeRange, completion: @escaping ((URL?) -> Void)) {
        let manager = FileManager.default
        
        let relativePath = "tempVideo.mp4"
        let outputFilePath = NSTemporaryDirectory() + relativePath
        print("Temp file path: \(outputFilePath)")
        // If there's any temp file from before at that path, delete it
        if manager.fileExists(atPath: outputFilePath) {
            do {
                try manager.removeItem(atPath: outputFilePath)
            }
            catch {
                print("ERROR: Can't remove temporary file from before. Cancelling export.")
                completion(nil)
                return
            }
        }
        // Export session setup
        let outputFileURL = URL(fileURLWithPath: outputFilePath)
        if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) {
            exportSession.outputURL = outputFileURL
            exportSession.outputFileType = .mp4
            exportSession.timeRange = timeRange
            
            exportSession.exportAsynchronously {
                // Hide the indicator for the export session
                switch exportSession.status {
                case .completed:
                    print("Video export completed.")
                    let saveVideoToPhotos = {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
                        }) { saved, error in
                            print("Result: \(saved) or error \(String(describing: error))")
                        }
                    }
                    
                    if PHPhotoLibrary.authorizationStatus() != .authorized {
                        PHPhotoLibrary.requestAuthorization { status in
                            if status == .authorized {
                                saveVideoToPhotos()
                            }
                        }
                    } else {
                        saveVideoToPhotos()
                    }
                    
                    completion(outputFileURL)
                    return
                case .failed:
                    print("ERROR: Video export failed. \(exportSession.error!.localizedDescription)")
                    completion(nil)
                    return
                case .cancelled:
                    print("Video export cancelled.")
                    completion(nil)
                    return
                default:
                    break
                }
            }
        } else {
            print("ERROR: Cannot create an AVAssetExportSession.")
            return
        }
    }
    
    struct HTTPBinResponse: Decodable { let url: String }
    
    static private func uploadToMux(to uploadAddress: String, videoURL: URL, fileName: String, fieldName: String, completion: @escaping (([String : Any]?) -> Void)) {
        let httpHeaders: HTTPHeaders = [.authorization(username: MUX_TOKEN_ID, password: MUX_TOKEN_SECRET)]
        let parameters : [String : Any] = ["new_asset_settings" : ["playback_policy": ["public"], "mp4_support": "standard"]]
        
        AF.request(uploadAddress, method: .post, parameters: parameters, headers: httpHeaders).responseJSON { response in
            print("Response POST JSON: \(String(describing: response.value))")
            if let value = response.value as? [String: AnyObject] {
                if let data = value["data"] as? [String: AnyObject] {
                    completion(data)
                }
            }
        }.responseDecodable(of: HTTPBinResponse.self) { response in
            debugPrint("Response Decodable: \(response)")
        }
    }
    
    static public func uploadTestToMux(to uploadAddress: String, videoURL: URL, completion: @escaping (([String : Any]?) -> Void)) {
        let httpHeaders: HTTPHeaders = [.authorization(username: MUX_TOKEN_ID, password: MUX_TOKEN_SECRET)]
        let parameters : [String : Any] = ["playback_policy": ["public"], "input": videoURL]

        AF.request(uploadAddress, method: .post, parameters: parameters, headers: httpHeaders).responseJSON { response in
            print("Response JSON: \(String(describing: response.value))")
            if let value = response.value as? [String: AnyObject] {
                completion(value)
            }
        }.responseDecodable(of: HTTPBinResponse.self) { response in
            debugPrint("Response Decodable: \(response)")
        }
    }
}
