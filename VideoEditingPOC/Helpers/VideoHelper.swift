//
//  VideoHelper.swift
//  VideoEditingPOC
//
//  Created by Elena Caballero on 5/11/20.
//  Copyright © 2020 Elena Caballero. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import Photos

class VideoHelper {
    static func startMediaBrowser(delegate: UIViewController & UINavigationControllerDelegate & UIImagePickerControllerDelegate, sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        
        let mediaUI = UIImagePickerController()
        mediaUI.sourceType = sourceType
        mediaUI.mediaTypes = [kUTTypeMovie as String]
        mediaUI.allowsEditing = sourceType == .camera ? false : true
        mediaUI.delegate = delegate
        mediaUI.modalPresentationStyle = .overFullScreen
        delegate.present(mediaUI, animated: true, completion: nil)
    }
    
    //MARK: - Using UIVideoEditorController
    static func editVideo(with url: URL, delegate: UIViewController & UINavigationControllerDelegate & UIVideoEditorControllerDelegate) {
        let path = url.path
        guard UIVideoEditorController.canEditVideo(atPath: path) else {
            print("Can't edit this video")
            return
        }
        
        let editor = UIVideoEditorController()
        editor.delegate = delegate
        editor.videoPath = path
        editor.videoMaximumDuration = 5.0
        editor.videoQuality = .typeMedium
        
        editor.modalPresentationStyle = .overFullScreen
        delegate.present(editor, animated: true, completion: nil)
    }
    
    //MARK: - Using UIImagePickerController
    static func editVideoWithImagePicker(with url: URL, andInfo info: [UIImagePickerController.InfoKey : Any], delegate: UIViewController & UINavigationControllerDelegate & UIImagePickerControllerDelegate) {
        let manager = FileManager.default

        let asset = AVAsset(url: url)
        let length = Float(asset.duration.value) / Float(asset.duration.timescale)
        if let url = info[.mediaURL] as? URL {
            print("[VIDEO] url \(url)")
        }
        
        let editingEnd = UIImagePickerController.InfoKey(rawValue: "_UIImagePickerControllerVideoEditingEnd")
        let editingStart = UIImagePickerController.InfoKey(rawValue: "_UIImagePickerControllerVideoEditingStart")
        let start = info[editingStart] as? Float
        let end = info[editingEnd] as? Float
        
        let startTime = CMTime(seconds: Double(start ?? 0), preferredTimescale: 1000)
        let endTime = CMTime(seconds: Double(end ?? length), preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        guard let documentDirectory = manager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        var outputURL = documentDirectory.appendingPathComponent("output")
        do {
            try manager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
            outputURL = outputURL.appendingPathComponent("output.mp4")
        } catch let error {
            print(error)
        }

        //Remove existing file
        _ = try? manager.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.timeRange = timeRange
        exportSession.exportAsynchronously{
            DispatchQueue.main.async {
                self.exportDidFinish(exportSession, delegate: delegate)
            }
        }
    }
    
    static private func exportDidFinish(_ session: AVAssetExportSession, delegate: UIViewController & UINavigationControllerDelegate & UIImagePickerControllerDelegate) {
        guard session.status == AVAssetExportSession.Status.completed, let outputURL = session.outputURL else {
            return
        }
        
        let saveVideoToPhotos = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
            }) { saved, error in
                let success = saved && (error == nil)
                let title = success ? "Success" : "Error"
                let message = success ? "Video saved" : "Failed to save video"
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                delegate.present(alert, animated: true, completion: nil)
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
    }
}
