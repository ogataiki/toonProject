import UIKit
import GPUImage
import MobileCoreServices

class GPUPhotoCameraVC: UIViewController, UINavigationControllerDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var toolbarView: UIToolbar!
    
    var parentVC: ViewController? = nil;
    
    var blurRadiusInPixels: CGFloat = 0;
    var imageWidth: GLfloat = 0;
    var imageHeight: GLfloat = 0;
    var edge: GLfloat = 0;
    var edgeValue: GLfloat = 0;
    var levelValue: GLfloat = 0;
    var filter: GPUImageFilterGroup? = nil;
    
    var gpuImageVideoCamera: GPUImageVideoCamera? = nil;
    var gpuImageView: GPUImageView? = nil;
    
    var outputSize = CGSize.zero;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if gpuImageVideoCamera == nil {
            gpuImageVideoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPresetPhoto, cameraPosition: .back);
            
            let output = gpuImageVideoCamera!.captureSession.outputs[gpuImageVideoCamera!.captureSession.outputs.endIndex - 1] as! AVCaptureVideoDataOutput;
            let setting:NSDictionary = output.videoSettings as NSDictionary;
            outputSize.width  = CGFloat((setting["Width"] as! NSNumber).floatValue);
            outputSize.height = CGFloat((setting["Height"] as! NSNumber).floatValue);
        }

        resumePreview();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func toonFilter(_ size: CGSize) -> GPUImageFilterGroup {
        
        let gaussian = GPUImageGaussianBlurFilter();
        gaussian.blurRadiusInPixels = blurRadiusInPixels;
        
        let toonShader = GPUImageFilter(fragmentShaderFromFile: "toon");
        toonShader?.setFloat(GLfloat(size.width), forUniformName: "imageWidth");
        toonShader?.setFloat(GLfloat(size.height), forUniformName: "imageHeight");
        toonShader?.setFloat(edge, forUniformName: "edge");
        toonShader?.setFloat(edgeValue, forUniformName: "edgeValue");
        toonShader?.setFloat(levelValue, forUniformName: "levelValue");
        
        let group = GPUImageFilterGroup();
        group.addFilter(gaussian);
        group.addFilter(toonShader);
        group.initialFilters = [gaussian];
        group.terminalFilter = toonShader;
        gaussian.addTarget(toonShader);
        
        group.forceProcessing(at: size);
        
        return group;
    }
    
    func stopPreview() -> Bool {
        let ret = (self.gpuImageView != nil);
        if ret {
            self.gpuImageVideoCamera!.stopCapture();
            self.gpuImageVideoCamera!.removeAllTargets();
            self.filter!.removeAllTargets();
            self.gpuImageView!.removeFromSuperview();
        }
        return ret;
    }
    func resumePreview() {
        
        self.gpuImageView = GPUImageView(frame: CGRect(x: 0,y: 0,width: self.imageView.frame.size.width,height: self.imageView.frame.size.height));
        self.gpuImageView!.fillMode = kGPUImageFillModePreserveAspectRatio;
        self.imageView.addSubview(self.gpuImageView!);
        
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            self.gpuImageVideoCamera!.outputImageOrientation = .portrait;
        case .portraitUpsideDown:
            self.gpuImageVideoCamera!.outputImageOrientation = .portraitUpsideDown;
        case .landscapeLeft:
            self.gpuImageVideoCamera!.outputImageOrientation = .landscapeLeft;
        case .landscapeRight:
            self.gpuImageVideoCamera!.outputImageOrientation = .landscapeRight;
        case.unknown:
            self.gpuImageVideoCamera!.outputImageOrientation = .unknown;
        }
        
        self.filter = self.toonFilter(self.outputSize);
        self.gpuImageVideoCamera!.addTarget(self.filter);
        self.filter!.addTarget(self.gpuImageView);        
        self.gpuImageVideoCamera!.startCapture();
    }


    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        stopPreview();
        self.dismiss(animated: true) {
            if self.parentVC != nil {
                self.parentVC?.resumePreview();
            }
        }
    }
    
    @IBAction func saveAction(_ sender: UIBarButtonItem) {
        
        if filter != nil {
            if let i = filter!.imageFromCurrentFramebuffer() {
                UIImageWriteToSavedPhotosAlbum(i, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil);
            }
        }
    }
    
    func image(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            //プライバシー設定不許可など書き込み失敗時は -3310 (ALAssetsLibraryDataUnavailableError)
            print(error.code)
        }
        else {
            let alert: UIAlertController = UIAlertController(title: "撮影した画像を保存しました"
                , message: nil
                , preferredStyle:  UIAlertControllerStyle.alert);
            // Defaultボタン
            let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{
                (action: UIAlertAction) -> Void in
            })
            alert.addAction(okAction);
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransition(to: size, with: coordinator);

        coordinator.animate(alongsideTransition: { context in
            //self.stopPreview();
            self.resumePreview();
        }, completion: nil);
    }
}

