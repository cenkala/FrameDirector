//
//  CameraCaptureService.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import AVFoundation
import UIKit

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((Error) -> Void)?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            onError?(error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            onError?(CameraCaptureService.CameraError.captureFailed)
            return
        }
        
        onPhotoCaptured?(image)
    }
}

@Observable
final class CameraCaptureService: NSObject {
    private let sessionQueue = DispatchQueue(label: "com.snapmotion.camera.session")
    private let photoCaptureDelegate = PhotoCaptureDelegate()
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    
    private(set) var isSessionRunning = false
    private(set) var flashMode: AVCaptureDevice.FlashMode = .off
    
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((Error) -> Void)?
    
    override init() {
        super.init()
        
        photoCaptureDelegate.onPhotoCaptured = { [weak self] image in
            Task { @MainActor [weak self] in
                self?.onPhotoCaptured?(image)
            }
        }
        
        photoCaptureDelegate.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.onError?(error)
            }
        }
    }
    
    func setupSession() async throws {
        struct SessionComponents {
            let session: AVCaptureSession
            let photoOutput: AVCapturePhotoOutput
        }
        
        try await ensureCameraAuthorization()
        
        let components: SessionComponents = try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    let session = AVCaptureSession()
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    
                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw CameraError.noCameraAvailable
                    }
                    
                    let videoInput = try AVCaptureDeviceInput(device: camera)
                    guard session.canAddInput(videoInput) else {
                        throw CameraError.cannotAddInput
                    }
                    session.addInput(videoInput)
                    
                    let photoOutput = AVCapturePhotoOutput()
                    guard session.canAddOutput(photoOutput) else {
                        throw CameraError.cannotAddOutput
                    }
                    session.addOutput(photoOutput)
                    
                    session.commitConfiguration()
                    
                    continuation.resume(returning: SessionComponents(
                        session: session,
                        photoOutput: photoOutput
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        await MainActor.run {
            self.captureSession = components.session
            self.photoOutput = components.photoOutput
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: components.session)
            previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer = previewLayer
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, let session = self.captureSession, !session.isRunning else { return }
            session.startRunning()
            let isRunning = session.isRunning
            Task { @MainActor [weak self] in
                self?.isSessionRunning = isRunning
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, let session = self.captureSession, session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = false
            }
        }
    }
    
    func capturePhoto() {
        let selectedFlashMode = flashMode
        Task { @MainActor [weak self] in
            guard let self, let photoOutput = self.photoOutput else { return }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = selectedFlashMode
            
            photoOutput.capturePhoto(with: settings, delegate: self.photoCaptureDelegate)
        }
    }
    
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }
    
    enum CameraError: LocalizedError {
        case notAuthorized
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput
        case captureFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return String(localized: "error.cameraPermission")
            case .noCameraAvailable:
                return String(localized: "error.camera.noAvailableCamera")
            case .cannotAddInput:
                return String(localized: "error.camera.cannotAddInput")
            case .cannotAddOutput:
                return String(localized: "error.camera.cannotAddOutput")
            case .captureFailed:
                return String(localized: "error.camera.captureFailed")
            }
        }
    }
    
    private func ensureCameraAuthorization() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await requestCameraAccess()
            if !granted {
                throw CameraError.notAuthorized
            }
        default:
            throw CameraError.notAuthorized
        }
    }
    
    private func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

