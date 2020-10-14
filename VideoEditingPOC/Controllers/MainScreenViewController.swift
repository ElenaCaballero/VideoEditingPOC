//
//  MainScreenViewController.swift
//  VideoEditingPOC
//
//  Created by Elena Caballero on 5/9/20.
//  Copyright © 2020 Elena Caballero. All rights reserved.
//

import UIKit
import AVKit
import MobileCoreServices
import MediaPlayer

class MainScreenViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    enum SelectedAction : Int {
        case record
        case select
        case watch
        case upload
    }
    
    var selectedAction : SelectedAction = .record
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicatorView.isHidden = true
    }
    
    func startIndicator() {
        self.activityIndicatorView.isHidden = false
        self.activityIndicatorView.startAnimating()
        self.mainStackView.isHidden = true
    }
    
    func stopIndicator() {
        self.activityIndicatorView.isHidden = true
        self.activityIndicatorView.stopAnimating()
        self.mainStackView.isHidden = false
    }
    
    @IBAction func didSelectRecordVideoButton(_ sender: Any) {
        self.startIndicator()
        self.selectedAction = .record
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
    }
    
    @IBAction func didSelectSelectVideoButton(_ sender: Any) {
        self.startIndicator()
        self.selectedAction = .select
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
    
    @IBAction func didSelectWatchVideoButton(_ sender: Any) {
        self.startIndicator()
        self.selectedAction = .watch
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
    
    @IBAction func didSelectUploadVideoButton(_ sender: Any) {
        self.selectedAction = .upload
        
        let title = "Record or Select a video?"
        let message = "Choose whether you want to record or select a video from the gallery."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Record", style: .default, handler: { (action) in
            self.startIndicator()
            VideoHelper.startMediaBrowser(delegate: self, sourceType: .camera)
        }))
        alert.addAction(UIAlertAction(title: "Select", style: .default, handler: { (action) in
            self.startIndicator()
            VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
        }))
        alert.addAction(UIAlertAction(title: "Upload Test Video", style: .default, handler: { (action) in
            self.startIndicator()
            UploadToMux.uploadVideo(with: nil) { (success) in
                self.uploadTest(success: success)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.view.addSubview(UIView())
        self.present(alert, animated: true)
    }
    
    @objc func video(_ videoPath:String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
        self.stopIndicator()
        dismiss(animated: true, completion: nil)
        let title = (error == nil) ? "Success" : "Error"
        let message = (error == nil) ? "Video was saved" : "Video failed to save"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func uploadTest(success: Bool) {
        self.stopIndicator()
        let title = success ? "Success" : "Error"
        let message = success ? "Video was uploaded succesfully" : "Video failed to upload"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension MainScreenViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String, mediaType == (kUTTypeMovie as String), let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        switch selectedAction {
        case .record:
            dismiss(animated: true, completion: nil)
            /// EditVideo
            /// - Parameter url: URL of video that was recorded
            /// This method only initializes the UIVideoEditorController, this is a condensed version of the UIImagePickerController
            /// You can set a max duration for the trimming window
            /// This is quite quick and easy to use. Then you just implement the delegate methods. Only issues found here is that it saves the video twice :/ and
            /// its a class that has not been updated for a long time, not much information/documentation about it.
            VideoHelper.editVideo(with: url, delegate: self)
            self.stopIndicator()
        case .select:
            dismiss(animated: true, completion: nil)
            /// editVideoWithImagePicker
            /// - Parameter info: ImagePickerInfo dictionary
            /// On this method you have to basically obtain the start and end times of the trimmed video that you selected on the imagePicker
            /// Not sure if you can set a max duration for the trimming window, an option was not given to initialize this.
            /// Has a lot more steps to do the same this as the UIVideoEditorController, but I guess you are given more control?
            /// This method does fix both issues on the UIVideoEditorController, with the disadvantage of more code.
            VideoHelper.editVideoWithImagePicker(with: url, andInfo: info, delegate: self)
            self.stopIndicator()
        case .watch:
            dismiss(animated: true) {
                let player = AVPlayer(url: url)
                let vcPlayer = AVPlayerViewController()
                vcPlayer.player = player
                vcPlayer.modalPresentationStyle = .overFullScreen
                self.stopIndicator()
                self.present(vcPlayer, animated: true, completion: nil)
            }
        case .upload:
            dismiss(animated: true, completion: nil)
            UploadToMux.uploadVideo(with: info) { (success) in
                self.uploadTest(success: success)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        self.stopIndicator()
    }
    
}

extension MainScreenViewController: UIVideoEditorControllerDelegate {
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        guard UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(editedVideoPath) else { return }
        UISaveVideoAtPathToSavedPhotosAlbum(
            editedVideoPath,
            self,
            #selector(video(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }
    
    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        self.stopIndicator()
        dismiss(animated: true, completion: nil)
    }
    
    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        self.stopIndicator()
        dismiss(animated: true, completion: nil)
    }
}
