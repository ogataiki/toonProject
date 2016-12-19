import UIKit
import GPUImage
import MobileCoreServices

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate {

    @IBOutlet weak var imageScrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var toolView: UIView!
    
    @IBOutlet weak var detailSlider: UISlider!
    
    @IBOutlet weak var edgeSwitch: UISwitch!
    @IBOutlet weak var edgeSlider: UISlider!
    
    @IBOutlet weak var levelSegmented: UISegmentedControl!
    
    @IBOutlet weak var imageSelectSeg: UISegmentedControl!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    let activityIndicatorView = UIActivityIndicatorView();

    let shaderFilter = GPUImageFilter(fragmentShaderFromFile: "toon");
    let gaussianFilter = GPUImageGaussianBlurFilter();

    var sourceImage: UIImage? = nil;
    var filteredImage: UIImage? = nil;
    var isEdge = false;
    
    var gpuImageVideoCamera: GPUImageVideoCamera? = nil;
    var gpuImageView: GPUImageView? = nil;
    var filter: GPUImageFilterGroup? = nil;
    var outputSize = CGSize.zero;
    
    var playingMovieURL: URL? = nil;
    var playingMovie: GPUImageMovie? = nil;
    var writtingMovie: GPUImageMovieWriter? = nil;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        toolView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8);
        
        imageScrollView.delegate = self;
        
        // imageViewのサイズがscrollView内に収まるように調整
        let size = imageView.frame.size;
        let wrate = imageScrollView.frame.width / size.width;
        let hrate = imageScrollView.frame.height / size.height;
        let rate = min(wrate, hrate, 1);
        imageView.frame.size = CGSize(width: size.width * rate, height: size.height * rate);
        imageScrollView.contentSize = imageView.frame.size;
        updateScrollInset();
        
        // imageViewと同サイズのプレビューを作成
        gpuImageVideoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPresetPhoto, cameraPosition: .back);
        
        let output = gpuImageVideoCamera!.captureSession.outputs[gpuImageVideoCamera!.captureSession.outputs.endIndex - 1] as! AVCaptureVideoDataOutput;
        let setting:NSDictionary = output.videoSettings as NSDictionary;
        outputSize.width  = CGFloat((setting["Width"] as! NSNumber).floatValue);
        outputSize.height = CGFloat((setting["Height"] as! NSNumber).floatValue);
        print(outputSize);
        
        resumePreview();

        
        
        levelSegmented.selectedSegmentIndex = 1;
        
        activityIndicatorView.frame = imageView.frame;
        activityIndicatorView.center = CGPoint(x: self.view.frame.size.width*0.5, y: imageView.center.y);
        activityIndicatorView.hidesWhenStopped = false;
        activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray;
        activityIndicatorView.color = UIColor.cyan;
        activityIndicatorView.hidesWhenStopped = true;
        activityIndicatorView.stopAnimating();
        self.view.addSubview(activityIndicatorView);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func menuEnabled(_ value: Bool) {
        detailSlider.isEnabled = value;
        edgeSwitch.isEnabled = value;
        edgeSlider.isEnabled = value;
        levelSegmented.isEnabled = value;
        imageSelectSeg.isEnabled = value;
        saveButton.isEnabled = value;
    }

    @IBAction func cameraAction(_ sender: UIBarButtonItem) {
        
        if activityIndicatorView.isAnimating {
            return;
        }

        let alert: UIAlertController = UIAlertController(title: "写真を選択"
            , message: nil
            , preferredStyle:  UIAlertControllerStyle.actionSheet);
        
        // Defaultボタン
/*
        let cameraAction: UIAlertAction = UIAlertAction(title: "カメラで写真撮影", style: UIAlertActionStyle.default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickImageFromCamera();
        })
        let movieAction: UIAlertAction = UIAlertAction(title: "カメラで動画撮影", style: UIAlertActionStyle.default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickMovieFromCamera();
        })
 */
        let libraryAction: UIAlertAction = UIAlertAction(title: "写真を選択", style: UIAlertActionStyle.default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickImageFromLibrary();
        })
        let libraryMovieAction: UIAlertAction = UIAlertAction(title: "動画を選択", style: UIAlertActionStyle.default, handler:{
            (action: UIAlertAction) -> Void in
            self.pickMovieFromLibrary();
        })
        
        // Cancelボタン
        let cancelAction: UIAlertAction = UIAlertAction(title: "cancel", style: UIAlertActionStyle.cancel, handler:{
            (action: UIAlertAction) -> Void in
        })
        
        alert.addAction(cancelAction);
//        alert.addAction(cameraAction);
//        alert.addAction(movieAction);
        alert.addAction(libraryAction);
        alert.addAction(libraryMovieAction);
        
        present(alert, animated: true, completion: nil)
    }
    
    
    
    @IBAction func detailValueChange(_ sender: AnyObject) {
        if self.sourceImage != nil {
            execToonFilter();
        }
        else if self.playingMovie != nil && self.playingMovieURL != nil {
            execToonFilterMovie(self.playingMovieURL!);
        }
        else {
            stopPreview();
            resumePreview();
        }
    }

    @IBAction func edgeChange(_ sender: UISwitch) {
        if self.sourceImage != nil {
            execToonFilter();
        }
        else if self.playingMovie != nil && self.playingMovieURL != nil {
            execToonFilterMovie(self.playingMovieURL!);
        }
        else {
            stopPreview();
            resumePreview();
        }
    }
    
    @IBAction func edgeValueChange(_ sender: UISlider) {
        if self.sourceImage != nil {
            execToonFilter();
        }
        else if self.playingMovie != nil && self.playingMovieURL != nil {
            execToonFilterMovie(self.playingMovieURL!);
        }
        else {
            stopPreview();
            resumePreview();
        }
    }
    
    @IBAction func levelChange(_ sender: UISegmentedControl) {
        if self.sourceImage != nil {
            execToonFilter();
        }
        else if self.playingMovie != nil && self.playingMovieURL != nil {
            execToonFilterMovie(self.playingMovieURL!);
        }
        else {
            stopPreview();
            resumePreview();
        }
    }
    
    @IBAction func imageSourceChange(_ sender: UISegmentedControl) {
        if(sender.selectedSegmentIndex == 0) {
            if let source = sourceImage {
                self.imageView.image = source;
            }
        }
        else {
            if let out = self.filteredImage {
                self.imageView.image = out;
            }            
        }
    }
    
    @IBAction func saveAction(_ sender: UIBarButtonItem) {
        if let i = self.filteredImage {
            UIImageWriteToSavedPhotosAlbum(i, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil);
        }
    }
    func image(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        if error != nil {
            //プライバシー設定不許可など書き込み失敗時は -3310 (ALAssetsLibraryDataUnavailableError)
            print(error.code)
        }
        else {
            let alert: UIAlertController = UIAlertController(title: "画像を保存しました"
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
    
    func execToonFilter() {
        
        menuEnabled(false);
        activityIndicatorView.startAnimating()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.0));
        
        // バックグラウンドで処理すると途中で処理がおかしくなってへんな画像が生成されることがある。
        // フィルタかける
        if let origImage = self.sourceImage {
            
            // 撮影時の向き反映
            var image = origImage;
            
            // 処理速度向上のためサイズを縮小 & 撮影時の向きを反映
            let baseWidth: CGFloat = 1600;
            // 長い方の辺を見て比率を決める
            let ratio: CGFloat;
            if image.size.width >= image.size.height {
                ratio = baseWidth / image.size.width;
            }
            else {
                ratio = baseWidth / image.size.height;
            }
            let newSize = CGSize(width: (image.size.width * ratio), height: (image.size.height * ratio));
            UIGraphicsBeginImageContext(newSize);
            image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height));
            image = UIGraphicsGetImageFromCurrentImageContext()!;
            UIGraphicsEndImageContext();
            
            if let out = toonFilter(image.size).image(byFilteringImage: image) {
                self.filteredImage = out;
                self.imageSelectSeg.selectedSegmentIndex = 1;
                
                self.imageView.image = out;
                
                self.activityIndicatorView.stopAnimating();
                self.menuEnabled(true);
                return;
            }
            
            self.filteredImage = nil;
            self.imageView.image = image;
        }
        
        self.activityIndicatorView.stopAnimating();
        self.menuEnabled(true);
    }
    
    func execToonFilterMovie(_ url: URL) {
        
        menuEnabled(false);
        activityIndicatorView.startAnimating();
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.0));
        
        stopPreview();
        addGPUImageView();

        // 元動画取得
        playingMovie = GPUImageMovie(url: url);
        playingMovie!.playAtActualSpeed = true;
        
        let videoAsst = AVAsset(url: url);
        let clipVideoTrack = videoAsst.tracks(withMediaType: AVMediaTypeVideo)[0];
        let movieSize = clipVideoTrack.naturalSize;
        

        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true); //アプリからアクセスできるディレクトリを取得
        let documentsDirectory = paths[0];
        let newFilePath = "\(documentsDirectory)/newTemp.mp4";
        let movieURL = NSURL(fileURLWithPath: newFilePath);
// なぜか動かない...
//        self.writtingMovie = GPUImageMovieWriter(movieURL: movieURL as URL!, size: movieSize, fileType:AVFileTypeMPEG4, outputSettings:nil)!; //保存する動画のサイズ
        if let write = self.writtingMovie {
            write.assetWriter.movieFragmentInterval = kCMTimeInvalid; //これ書かないと動作が不安定になります
            write.shouldPassthroughAudio = true;
            write.encodingLiveVideo = true;
        }
        
        self.filter = toonFilter(movieSize);
        filter!.addTarget(gpuImageView);
        
        playingMovie!.addTarget(filter);
        if let write = self.writtingMovie {
            filter!.addTarget(write);
        }
        
        playingMovieURL = url;
        
        //再生時
        playingMovie!.startProcessing();
        if let write = self.writtingMovie {
            write.startRecording();
        }
        
        self.activityIndicatorView.stopAnimating();
        self.menuEnabled(true);
        
        _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(ViewController.movieProgress), userInfo: nil, repeats: false);
    }
    
    func movieProgress() {
        if let movie = playingMovie {
            //規定のレンダリング時間に達するまでは0.5秒に一度進捗を監視する
            if(movie.progress >= 1){
                
                if self.writtingMovie != nil {
                    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true); //アプリからアクセスできるディレクトリを取得
                    let documentsDirectory = paths[0];
                    let newFilePath = "\(documentsDirectory)/newTemp.mp4";
                    UISaveVideoAtPathToSavedPhotosAlbum(newFilePath, self, #selector(ViewController.movieSavingFinish), nil)
                }

                stopPreview();
                
            }else{
                _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(ViewController.movieProgress), userInfo: nil, repeats: false);
            }
        }
    }
    
    func movieSavingFinish(filePath: String!, didFinishSavingWithError: NSError, contextInfo:UnsafeRawPointer) {
        if let error = didFinishSavingWithError as NSError? {
            print("error")
        }
        else{
            print("success!")
        }
    }
    
    func toonFilter(_ size: CGSize) -> GPUImageFilterGroup {
        
        let gaussian = GPUImageGaussianBlurFilter();
        gaussian.blurRadiusInPixels = CGFloat(detailSlider.value);

        let toonShader = GPUImageFilter(fragmentShaderFromFile: "toon");
        toonShader?.setFloat(GLfloat(size.width), forUniformName: "imageWidth");
        toonShader?.setFloat(GLfloat(size.height), forUniformName: "imageHeight");
        toonShader?.setFloat(GLfloat((self.edgeSwitch.isOn) ? 1.0 : 0.0), forUniformName: "edge");
        toonShader?.setFloat(GLfloat(self.edgeSlider.value), forUniformName: "edgeValue");
        toonShader?.setFloat(GLfloat(self.levelSegmented.selectedSegmentIndex), forUniformName: "levelValue");
        
        let group = GPUImageFilterGroup();
        group.addFilter(gaussian);
        group.addFilter(toonShader);
        group.initialFilters = [gaussian];
        group.terminalFilter = toonShader;
        gaussian.addTarget(toonShader);
        
        group.forceProcessing(at: size);

        return group;
    }
    
    func toonFilterGpuImageView(_ gpuimageview: GPUImageView) -> GPUImageFilterGroup {
        
        let group = toonFilter(gpuimageview.frame.size);
        group.addTarget(gpuimageview);

        return group;
    }

    func stopPreview() {
        if self.gpuImageView != nil {
            self.gpuImageVideoCamera!.stopCapture();
            self.gpuImageVideoCamera!.removeAllTargets();
            if self.filter != nil {
                self.filter!.removeAllTargets();
                self.filter = nil;
            }
            self.gpuImageView!.removeFromSuperview();
            self.gpuImageView = nil;
        }
        if self.playingMovie != nil {
            self.playingMovie?.removeAllTargets();
            self.playingMovie = nil;
        }
        if self.filter != nil {
            self.filter!.removeAllTargets();
            self.filter = nil;
        }
        if self.writtingMovie != nil {
        }
    }
    func addGPUImageView() {
        var viewSize = CGSize.zero;
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            self.gpuImageVideoCamera!.outputImageOrientation = .portrait;
            viewSize.width = imageView.frame.size.width;
            viewSize.height = imageView.frame.size.height;
        case .portraitUpsideDown:
            self.gpuImageVideoCamera!.outputImageOrientation = .portraitUpsideDown;
            viewSize.width = imageView.frame.size.width;
            viewSize.height = imageView.frame.size.height;
        case .landscapeLeft:
            self.gpuImageVideoCamera!.outputImageOrientation = .landscapeLeft;
            viewSize.width = imageView.frame.size.width;
            viewSize.height = imageView.frame.size.height;
        case .landscapeRight:
            self.gpuImageVideoCamera!.outputImageOrientation = .landscapeRight;
            viewSize.width = imageView.frame.size.width;
            viewSize.height = imageView.frame.size.height;
        case.unknown:
            self.gpuImageVideoCamera!.outputImageOrientation = .unknown;
            viewSize.width = imageView.frame.size.width;
            viewSize.height = imageView.frame.size.height;
        }
        
        self.gpuImageView = GPUImageView(frame: CGRect(x: 0,y: 0,width: viewSize.width,height: viewSize.height));
        self.gpuImageView!.fillMode = kGPUImageFillModePreserveAspectRatio;
        self.imageView.addSubview(self.gpuImageView!);
    }
    func resumePreview() {

        addGPUImageView();
        
        self.filter = self.toonFilter(self.outputSize);
        self.gpuImageVideoCamera!.addTarget(self.filter);
        self.filter!.addTarget(self.gpuImageView);
        self.gpuImageVideoCamera!.startCapture();
    }
    
    // 写真を撮ってそれを選択
    func pickImageFromCamera() {

        stopPreview();
        
        let vc = self.storyboard?.instantiateViewController(withIdentifier: "GPUPhotoCameraVC") as! GPUPhotoCameraVC;
        vc.parentVC = self;
        vc.blurRadiusInPixels = CGFloat(detailSlider.value);
        vc.edge = GLfloat((self.edgeSwitch.isOn) ? 1.0 : 0.0);
        vc.edgeValue = GLfloat(self.edgeSlider.value);
        vc.levelValue = GLfloat(self.levelSegmented.selectedSegmentIndex);
        vc.gpuImageVideoCamera = gpuImageVideoCamera;
        vc.outputSize = outputSize;
        self.present(vc, animated: true, completion: nil);        
    }

    func pickMovieFromCamera() {
        
        stopPreview();

    }

    // ライブラリから写真を選択する
    func pickImageFromLibrary() {

        stopPreview();
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            let controller = UIImagePickerController();
            controller.delegate = self;
            controller.sourceType = UIImagePickerControllerSourceType.photoLibrary;
            self.present(controller, animated: true, completion: nil);
        }
    }
    
    // ライブラリから動画を選択する
    func pickMovieFromLibrary() {
        
        stopPreview();
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            let controller = UIImagePickerController()
            controller.delegate = self
            controller.sourceType = UIImagePickerControllerSourceType.photoLibrary
            controller.mediaTypes = [kUTTypeMovie as String];
            controller.allowsEditing = false;
            self.present(controller, animated: true, completion: nil)
        }
    }

    
    // 写真を選択した時に呼ばれる
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        picker.dismiss(animated: true, completion: nil);

        let mediaType: CFString = info[UIImagePickerControllerMediaType] as! CFString;
        if mediaType == kUTTypeMovie {
            
            let url = info[UIImagePickerControllerMediaURL] as! URL;
            execToonFilterMovie(url);
        }
        
        if info[UIImagePickerControllerOriginalImage] != nil {
            
            // ソースイメージ更新
            self.sourceImage = info[UIImagePickerControllerOriginalImage] as? UIImage;
            
            // フィルタかける
            execToonFilter();
        }
    }
    
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // ズームのために要指定
        if imageView.image != nil {
            return imageView;
        }
        else if gpuImageView != nil {
            return gpuImageView!;
        }
        return imageView;
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // ズームのタイミングでcontentInsetを更新
        updateScrollInset()
    }
    
    fileprivate func updateScrollInset() {
        // imageViewの大きさからcontentInsetを再計算
        // なお、0を下回らないようにする
        let frame: CGRect;
        if imageView.image != nil {
            frame = imageView.frame;
        }
        else if gpuImageView != nil {
            frame = gpuImageView!.frame;
        }
        else {
            frame = imageView.frame;
        }
        imageScrollView.contentInset = UIEdgeInsetsMake(
            max((imageScrollView.frame.height - frame.height)/2, 0),
            max((imageScrollView.frame.width - frame.width)/2, 0),
            0,
            0
        );
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransition(to: size, with: coordinator);
        
        coordinator.animate(alongsideTransition: { context in
            self.stopPreview();
            self.resumePreview();
        }, completion: nil);
    }
}

